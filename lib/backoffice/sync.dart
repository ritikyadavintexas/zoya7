import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'casino.dart';
import 'net.dart';
import 'storage.dart';

/// The shared database every device uses. A build can point elsewhere with
/// `--dart-define=DB_URL=…` (the repo variable ZOYA7_DB_URL).
const defaultDbUrl = 'https://lilly-55024-default-rtdb.firebaseio.com';
const _buildDbUrl = String.fromEnvironment('DB_URL');
const buildDbUrl = _buildDbUrl == '' ? defaultDbUrl : _buildDbUrl;

enum SyncState { off, connecting, live, offline }

/// Keeps a [Casino] in step with a Firebase Realtime Database over its REST
/// API: every few seconds it reads the database, merges it with this device's
/// changes record by record (players, ledger lines, play, games, settings…),
/// and writes back what this device changed.
///
/// Merging is three-way against the last copy both sides agreed on, so two
/// devices changing different records never lose each other's work, and
/// balances are never stored — they're worked out from the ledger — so money
/// can't be overwritten.
class CasinoSync extends ChangeNotifier {
  CasinoSync(
    this.casino, {
    this.transport = httpRequest,
    this.every = const Duration(seconds: 4),
    this.autoSync = true,
    this.storagePrefix = 'zoya7.db',
  }) {
    casino.onLocalChange = _localChange;
  }

  final Casino casino;
  final Future<({int status, String body})> Function(String method, String url, [String? body]) transport;
  final Duration every;

  /// Poll and push on timers (off in tests, which call [syncNow]).
  final bool autoSync;
  final String storagePrefix;

  String get _syncedKey => '$storagePrefix.synced';
  String get _dirtyKey => '$storagePrefix.dirty';

  SyncState state = SyncState.off;
  String? url;
  String? error;
  DateTime? lastSync;

  /// The records as both sides last agreed (path → JSON text).
  Map<String, String> _base = {};

  /// Paths changed here and not yet written (survives a reload).
  final _dirty = <String, int>{};

  Timer? _poll;
  Timer? _push;
  bool _busy = false;
  bool _again = false;

  /// The database every device uses: built in, not chosen per device.
  static String configuredUrl() => buildDbUrl;

  /// Turn "https://x.firebaseio.com/" (or a console link) into the REST base.
  static String? normalize(String input) {
    var u = input.trim();
    if (u.isEmpty) return null;
    if (!u.startsWith('http')) u = 'https://$u';
    final uri = Uri.tryParse(u);
    if (uri == null || uri.host.isEmpty) return null;
    // Plain http only for a database on this computer (testing).
    final local = uri.host == 'localhost' || uri.host == '127.0.0.1';
    return Uri(scheme: local && uri.scheme == 'http' ? 'http' : 'https', host: uri.host, port: local && uri.hasPort ? uri.port : null)
        .toString();
  }

  String get _root => '$url/zoya7.json';

  /// Start syncing with the built-in database.
  void start() => connect(configuredUrl());

  /// Sync with [databaseUrl].
  Future<void> connect(String databaseUrl) async {
    final u = normalize(databaseUrl);
    if (u == null) {
      error = 'That doesn’t look like a database URL';
      notifyListeners();
      return;
    }
    if (u != url) {
      url = u;
      // A different database: start from what it holds.
      final synced = loadSaved(_syncedKey);
      _base = {};
      _dirty.clear();
      if (synced == u) _restoreDirty();
    }
    state = SyncState.connecting;
    error = null;
    notifyListeners();
    _poll?.cancel();
    if (autoSync) _poll = Timer.periodic(every, (_) => syncNow());
    await syncNow();
  }

  /// Stop syncing; this device keeps its copy.
  void _localChange() {
    if (url == null) return;
    // Note what changed now (so a reload before the write still knows).
    final now = casino.now.millisecondsSinceEpoch;
    final local = _texts(casino.toRecords());
    for (final e in local.entries) {
      if (_base[e.key] != e.value) _dirty.putIfAbsent(e.key, () => now);
    }
    for (final p in _base.keys) {
      if (!local.containsKey(p)) _dirty.putIfAbsent(p, () => now);
    }
    _saveDirty();
    _push?.cancel();
    if (autoSync) _push = Timer(const Duration(milliseconds: 400), syncNow);
  }

  static Map<String, String> _texts(Map<String, Map<String, dynamic>> records) =>
      {for (final e in records.entries) e.key: jsonEncode(_canonical(e.value))};

  /// Read the database, merge, write back this device's changes.
  Future<void> syncNow() async {
    if (url == null) return;
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      final res = await transport('GET', _root);
      if (res.status != 200) throw 'The database answered ${res.status}${res.status == 401 ? ' (check its rules allow reading and writing)' : ''}';
      final remote = _flatten(jsonDecode(res.body));
      final firstTime = loadSaved(_syncedKey) != url;
      final local = _texts(casino.toRecords());
      final merged = <String, String>{};
      final upload = <String, String?>{};

      if (firstTime && remote.isNotEmpty) {
        // Joining a database that's already in use: take what it holds.
        merged.addAll(remote.map((k, v) => MapEntry(k, v.text)));
      } else {
        final paths = {...local.keys, ...remote.keys, ..._base.keys};
        for (final p in paths) {
          final l = local[p], r = remote[p]?.text, b = _base[p];
          final localChanged = _dirty.containsKey(p) || l != b;
          String? m;
          if (l == r) {
            m = l;
          } else if (!localChanged) {
            m = r; // only the database changed
          } else if (r == b) {
            m = l; // only this device changed
          } else {
            m = _resolve(p, l, r, _dirty[p] ?? casino.now.millisecondsSinceEpoch, remote[p]?.up ?? 0);
          }
          if (m != null) merged[p] = m;
          if (m != r) upload[p] = m;
        }
      }

      if (upload.isNotEmpty) {
        final stamp = casino.now.millisecondsSinceEpoch;
        final body = {
          for (final e in upload.entries)
            e.key: e.value == null ? null : {...(jsonDecode(e.value!) as Map<String, dynamic>), '_up': stamp},
        };
        final w = await transport('PATCH', _root, jsonEncode(body));
        if (w.status != 200) throw 'The database refused the write (${w.status})';
      }

      _base = merged;
      _dirty.clear();
      _saveDirty();
      save(_syncedKey, url!);
      if (!mapEquals(local, merged)) {
        casino.loadRecords({for (final e in merged.entries) e.key: jsonDecode(e.value) as Map<String, dynamic>});
      }
      state = SyncState.live;
      error = null;
      lastSync = casino.now;
    } catch (e) {
      state = SyncState.offline;
      error = '$e';
    } finally {
      _busy = false;
      notifyListeners();
    }
    if (_again) {
      _again = false;
      unawaited(syncNow());
    }
  }

  /// Both sides changed the same record: play records keep the one with more
  /// rounds; otherwise the later change wins (a change beats a removal).
  String? _resolve(String path, String? local, String? remote, int localAt, int remoteAt) {
    if (local == null) return remote;
    if (remote == null) return local;
    if (path.startsWith('plays/')) {
      int rounds(String t) => (((jsonDecode(t) as Map)['p'] as List)[3] as num).toInt();
      return rounds(local) >= rounds(remote) ? local : remote;
    }
    return localAt >= remoteAt ? local : remote;
  }

  /// Firebase's tree → path → (record text without the sync stamp, stamp).
  static Map<String, ({String text, int up})> _flatten(Object? tree) {
    final out = <String, ({String text, int up})>{};
    if (tree is! Map) return out;
    for (final kind in tree.entries) {
      final group = kind.value;
      final items = group is Map
          ? group.entries.map((e) => MapEntry('${e.key}', e.value))
          : group is List
              ? [for (var i = 0; i < group.length; i++) MapEntry('$i', group[i])]
              : const <MapEntry<String, dynamic>>[];
      for (final it in items) {
        if (it.value is! Map) continue;
        final rec = Map<String, dynamic>.from(it.value as Map);
        final up = (rec.remove('_up') as num?)?.toInt() ?? 0;
        out['${kind.key}/${it.key}'] = (text: jsonEncode(_canonical(rec)), up: up);
      }
    }
    return out;
  }

  /// One spelling per record, whoever wrote it: keys sorted, whole numbers
  /// as integers (Firebase and the web hand 2.0 back as 2).
  static Map<String, dynamic> _canonical(Map<String, dynamic> rec) => _canon(rec) as Map<String, dynamic>;

  static Object? _canon(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => '$k').toList()..sort();
      return <String, dynamic>{for (final k in keys) k: _canon(v[k])};
    }
    if (v is List) return [for (final x in v) _canon(x)];
    if (v is double && v == v.truncateToDouble() && v.abs() < 9e15) return v.toInt();
    return v;
  }

  void _saveDirty() {
    if (url == null) return;
    save(_dirtyKey, jsonEncode({'url': url, 'paths': _dirty}));
  }

  void _restoreDirty() {
    final raw = loadSaved(_dirtyKey);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['url'] != url) return;
      for (final e in (j['paths'] as Map).entries) {
        _dirty[e.key as String] = (e.value as num).toInt();
      }
    } catch (_) {}
  }

  /// Write this device's whole copy over the database (owner's "upload").
  Future<void> uploadAll() async {
    if (url == null) return;
    final recs = casino.toRecords();
    final tree = <String, Map<String, dynamic>>{};
    final stamp = casino.now.millisecondsSinceEpoch;
    for (final e in recs.entries) {
      final slash = e.key.indexOf('/');
      tree.putIfAbsent(e.key.substring(0, slash), () => {})[e.key.substring(slash + 1)] = {...e.value, '_up': stamp};
    }
    final w = await transport('PUT', _root, jsonEncode(tree));
    if (w.status != 200) throw 'The database refused the upload (${w.status})';
    _base = _texts(recs);
    _dirty.clear();
    _saveDirty();
    save(_syncedKey, url!);
    lastSync = casino.now;
    state = SyncState.live;
    notifyListeners();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _push?.cancel();
    if (casino.onLocalChange == _localChange) casino.onLocalChange = null;
    super.dispose();
  }
}
