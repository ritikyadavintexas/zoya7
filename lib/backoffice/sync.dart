import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'auth.dart';
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
///
/// With [auth], the device syncs as whoever is signed in: staff read
/// everything and write what their role allows; a player reads and writes
/// only their own records (the database rules enforce the same). Without
/// [auth] (tests) it reads and writes everything.
class CasinoSync extends ChangeNotifier {
  CasinoSync(
    this.casino, {
    this.transport = httpRequest,
    this.auth,
    this.every = const Duration(seconds: 4),
    this.autoSync = true,
    this.storagePrefix = 'zoya7.db',
  }) {
    casino.onLocalChange = _localChange;
  }

  final Casino casino;
  final Future<({int status, String body})> Function(String method, String url, [String? body]) transport;
  final FirebaseAuthApi? auth;
  final Duration every;

  /// Poll and push on timers (off in tests, which call [syncNow]).
  final bool autoSync;
  final String storagePrefix;

  String get _staffKey => '$storagePrefix.staff';
  String get _playerKey => '$storagePrefix.player';

  SyncState state = SyncState.off;
  String? url;
  String? error;
  DateTime? lastSync;

  /// Who this device syncs as (with [auth]); [playerId] set for a player.
  AuthSession? session;
  String? playerId;

  /// The records as both sides last agreed (path → JSON text).
  Map<String, String> _base = {};

  /// [_base] holds a real agreed copy (not just "nothing yet").
  bool _haveBase = false;

  /// The database has answered since this device signed in (until then the
  /// back office is empty, not "no such player").
  bool get ready => _haveBase;

  /// Paths changed here and not yet written (until the database has them).
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

  // ── Who ────────────────────────────────────────────────────────────────────
  bool get _open => auth == null;
  bool get signedIn => _open || session != null;

  /// The signed-in staff member's role, from the database's staff list.
  StaffRole? _role(Map<String, ({String text, int up})> remote) {
    final s = session;
    if (s == null || playerId != null) return null;
    final t = remote['staff/${s.uid}']?.text;
    if (t != null) return StaffRole.values[(jsonDecode(t) as Map)['r'] as int];
    return casino.staff.where((x) => x.uid == s.uid).firstOrNull?.role;
  }

  /// Sync as this staff member from now on (kept on this device).
  Future<void> useStaff(AuthSession s) async {
    save(_staffKey, jsonEncode(s.toJson()));
    _switch(s, null);
    await _restart();
  }

  /// Sync as this player from now on (kept on this device).
  Future<void> usePlayer(AuthSession s, String id) async {
    save(_playerKey, jsonEncode({...s.toJson(), 'p': id}));
    _switch(s, id);
    await _restart();
  }

  /// Pick up the staff member signed in on this device before, if any.
  Future<bool> resumeStaff() async {
    final s = AuthSession.fromJson(_load(_staffKey));
    if (s == null) return false;
    _switch(s, null);
    await _restart();
    return true;
  }

  /// Pick up the player signed in on this device before; their player ID.
  String? resumePlayer() {
    final j = _load(_playerKey);
    final s = AuthSession.fromJson(j);
    if (s == null || (j as Map)['p'] is! String) return null;
    _switch(s, j['p'] as String);
    unawaited(_restart());
    return playerId;
  }

  /// Forget who is signed in here (staff or player) and stop syncing.
  void signOut({bool staff = false}) {
    clearSaved(staff ? _staffKey : _playerKey);
    _switch(null, null);
    _poll?.cancel();
    state = SyncState.off;
    notifyListeners();
  }

  static Object? _load(String key) {
    final raw = loadSaved(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  void _switch(AuthSession? s, String? player) {
    session = s;
    playerId = player;
    _base = {};
    _haveBase = false;
  }

  Future<void> _restart() async {
    if (url == null) return connect(configuredUrl());
    _poll?.cancel();
    if (autoSync) _poll = Timer.periodic(every, (_) => syncNow());
    await syncNow();
  }

  /// What this device reads: everything (staff), or a player's own records.
  List<String> get _scopes {
    if (_open || (session != null && playerId == null)) return const [''];
    final p = playerId;
    if (session == null || p == null) return const [];
    return ['players/$p', 'txns/$p', 'plays/$p', 'seen/$p', 'games', 'meta'];
  }

  bool _inScope(String path, List<String> scopes) =>
      scopes.any((s) => s.isEmpty || path == s || path.startsWith('$s/'));

  /// May this device write [text] (null: remove) at [path]? Mirrors the rules.
  bool _canWrite(String path, String? text, StaffRole? role) {
    if (_open) return true;
    final p = playerId;
    if (p != null) {
      if (text == null) return false;
      if (path == 'seen/$p' || path.startsWith('plays/$p/')) return true;
      if (path.startsWith('txns/$p/') && !_base.containsKey(path)) {
        final t = jsonDecode(text) as Map;
        final gc = (t['gc'] as num?) ?? 0, sc = (t['sc'] as num?) ?? 0;
        return t['t'] == TxnType.bonus.index && t['p'] == p && sc == 0 && gc > 0 && gc <= 25000;
      }
      return false;
    }
    return switch (role) {
      StaffRole.owner => true,
      StaffRole.manager => !path.startsWith('staff/'),
      StaffRole.cashier => !path.startsWith('staff/') && !path.startsWith('games/') && !path.startsWith('meta/'),
      null => false,
    };
  }

  Future<String> _query() async {
    final a = auth, s = session;
    if (a == null || s == null) return '';
    final token = await a.token(s);
    // The refresh token can change; keep the newest.
    final key = playerId == null ? _staffKey : _playerKey;
    save(key, jsonEncode({...s.toJson(), if (playerId != null) 'p': playerId!}));
    return '?auth=${Uri.encodeQueryComponent(token)}';
  }

  String _at(String path, String query) => '$url/zoya7${path.isEmpty ? '' : '/$path'}.json$query';

  // ── Connecting ─────────────────────────────────────────────────────────────
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
      _base = {};
      _haveBase = false;
      _dirty.clear();
    }
    state = signedIn ? SyncState.connecting : SyncState.off;
    error = null;
    notifyListeners();
    _poll?.cancel();
    if (autoSync) _poll = Timer.periodic(every, (_) => syncNow());
    await syncNow();
  }

  void _localChange() {
    if (url == null) return;
    // Note what changed now (sent with the next write).
    final now = casino.now.millisecondsSinceEpoch;
    final local = _texts(casino.toRecords());
    for (final e in local.entries) {
      if (_base[e.key] != e.value) _dirty.putIfAbsent(e.key, () => now);
    }
    for (final p in _base.keys) {
      if (!local.containsKey(p)) _dirty.putIfAbsent(p, () => now);
    }
    _push?.cancel();
    if (autoSync) _push = Timer(const Duration(milliseconds: 400), syncNow);
  }

  static Map<String, String> _texts(Map<String, Map<String, dynamic>> records) =>
      {for (final e in records.entries) e.key: jsonEncode(_canonical(e.value))};

  // ── Syncing ────────────────────────────────────────────────────────────────
  /// Read the database, merge, write back this device's changes.
  Future<void> syncNow() async {
    if (url == null) return;
    final scopes = _scopes;
    if (scopes.isEmpty) {
      if (state != SyncState.off) {
        state = SyncState.off;
        notifyListeners();
      }
      return;
    }
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      final q = await _query();
      final remote = <String, ({String text, int up})>{};
      for (final s in scopes) {
        final res = await transport('GET', _at(s, q));
        if (res.status == 401 || res.status == 403) throw 'This account can’t open the database (check the database rules)';
        if (res.status != 200) throw 'The database answered ${res.status}';
        _flatten(s, jsonDecode(res.body), remote);
      }
      final role = _role(remote);
      final local = {
        for (final e in _texts(casino.toRecords()).entries)
          if (_inScope(e.key, scopes)) e.key: e.value,
      };
      final merged = <String, String>{};
      final upload = <String, String?>{};

      // Nothing agreed yet since start-up: only changes made here count as
      // local (an empty database gets this device's copy).
      final fill = !_haveBase && remote.isEmpty;
      final paths = {...local.keys, ...remote.keys, ..._base.keys.where((p) => _inScope(p, scopes))};
      for (final p in paths) {
        final l = local[p], r = remote[p]?.text, b = _base[p];
        final localChanged = _dirty.containsKey(p) || fill || (_haveBase && l != b);
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
        // A change this device may not make doesn't stick.
        if (m != r && !_canWrite(p, m, role)) m = r;
        if (m != null) merged[p] = m;
        if (m != r) upload[p] = m;
      }

      if (upload.isNotEmpty) {
        final stamp = casino.now.millisecondsSinceEpoch;
        final body = {
          for (final e in upload.entries)
            e.key: e.value == null ? null : {...(jsonDecode(e.value!) as Map<String, dynamic>), '_up': stamp},
        };
        final w = await transport('PATCH', _at('', q), jsonEncode(body));
        if (w.status == 401 || w.status == 403) {
          // Refused by the rules: keep what the database has.
          for (final p in upload.keys) {
            final r = remote[p]?.text;
            r == null ? merged.remove(p) : merged[p] = r;
          }
          error = 'Some changes weren’t allowed and were undone';
        } else if (w.status != 200) {
          throw 'The database refused the write (${w.status})';
        } else {
          error = null;
        }
      } else {
        error = null;
      }

      _base = merged;
      _haveBase = true;
      _dirty.clear();
      if (!mapEquals(local, merged) || local.length != casino.toRecords().length) {
        casino.loadRecords({for (final e in merged.entries) e.key: jsonDecode(e.value) as Map<String, dynamic>});
      }
      state = SyncState.live;
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

  /// How deep each kind of record sits: txns/<player>/<id> and
  /// plays/<player>/<day|game>; everything else is <kind>/<id>.
  static int _depth(String kind) => kind == 'txns' || kind == 'plays' ? 3 : 2;

  /// The tree read at [path] → path → (record text without the sync stamp, stamp).
  static void _flatten(String path, Object? tree, Map<String, ({String text, int up})> out) {
    final segs = path.isEmpty ? const <String>[] : path.split('/');
    if (segs.isNotEmpty && segs.length >= _depth(segs.first)) {
      if (segs.length == _depth(segs.first) && tree is Map) {
        final rec = Map<String, dynamic>.from(tree);
        final up = (rec.remove('_up') as num?)?.toInt() ?? 0;
        out[path] = (text: jsonEncode(_canonical(rec)), up: up);
      }
      return;
    }
    final children = tree is Map
        ? tree.entries.map((e) => MapEntry('${e.key}', e.value))
        : tree is List
            ? [for (var i = 0; i < tree.length; i++) MapEntry('$i', tree[i])]
            : const <MapEntry<String, dynamic>>[];
    for (final c in children) {
      if (c.value == null) continue;
      _flatten(path.isEmpty ? c.key : '$path/${c.key}', c.value, out);
    }
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

  /// The email a player ID or username signs in with (null: no such player).
  Future<String?> loginEmail(String who) async {
    final res = await transport('GET', _at('logins/${Casino.loginKey(who)}', ''));
    if (res.status != 200) throw 'Can’t reach the server — check the connection';
    final j = jsonDecode(res.body);
    return j is Map ? j['e'] as String? : null;
  }

  /// The player ID a signed-in account belongs to.
  Future<String?> playerOf(AuthSession s) async {
    final a = auth;
    final q = a == null ? '' : '?auth=${Uri.encodeQueryComponent(await a.token(s))}';
    final res = await transport('GET', _at('uids/${s.uid}', q));
    if (res.status != 200) return null;
    final j = jsonDecode(res.body);
    return j is Map ? j['p'] as String? : null;
  }

  @override
  void dispose() {
    _poll?.cancel();
    _push?.cancel();
    if (casino.onLocalChange == _localChange) casino.onLocalChange = null;
    super.dispose();
  }
}
