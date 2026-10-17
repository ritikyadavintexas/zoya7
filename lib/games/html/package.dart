import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'model.dart';

/// An uploaded game's zip, read and checked against docs/GAME_PROMPT.md.
class GamePackage {
  GamePackage._(this.id, this.game, this.files, this.errors, this.warnings);

  /// Empty when the zip has no readable game.json.
  final String id;
  final HtmlGame? game;

  /// What goes on the site, by path inside the game's folder.
  final Map<String, Uint8List> files;

  /// Each one stops the upload.
  final List<String> errors;

  /// Worth knowing, but the game can go in.
  final List<String> warnings;

  bool get ok => errors.isEmpty && game != null;
  int get bytes => files.values.fold(0, (a, f) => a + f.length);

  static const maxZip = 40 << 20, maxFile = 20 << 20, maxTotal = 80 << 20, maxFiles = 600;

  /// Folders the game doesn't need to run (left out of the upload).
  static const _skipDirs = {'mockups', 'tools', 'tests', 'test', 'docs', 'node_modules', '.git', '__MACOSX', 'source'};
  static const _types = {
    'html', 'htm', 'js', 'mjs', 'css', 'json', 'md', 'txt', 'png', 'jpg', 'jpeg', 'webp', 'gif', 'svg', 'ico', //
    'ogg', 'oga', 'mp3', 'wav', 'm4a', 'aac', 'webm', 'mp4', 'woff', 'woff2', 'ttf', 'otf',
  };
  static const _text = {'html', 'htm', 'js', 'mjs', 'css'};

  /// The ids of the games built into the app.
  static const reserved = {'classic777', 'fruitspin', 'phoenixruby', 'blackjack', 'roulette', 'plinko', 'megareels'};

  static final _id = RegExp(r'^[a-z][a-z0-9]{2,23}$');
  static final _key = RegExp(r'^[a-z0-9_-]{1,32}$');
  static final _banned = RegExp(r'\$|\bcash\b|\bmoney\b|\bredeem|\bwithdraw|\bdollars?\b|\breal[- ]money', caseSensitive: false);
  static final _external = RegExp(
      r'''(?:src|href)\s*=\s*["']\s*(?:https?:)?//(?!www\.w3\.org)|@import\s+(?:url\()?\s*["']?(?:https?:)?//|url\(\s*["']?(?:https?:)?//(?!www\.w3\.org)|(?:fetch|import)\s*\(\s*["'`](?:https?:)?//|new\s+(?:WebSocket|EventSource)\s*\(''',
      caseSensitive: false);

  /// Reads a zip. [maxRtp]: the highest payback the admin panel allows (the
  /// pay table must be able to reach it).
  static GamePackage read(Uint8List zip, {double maxRtp = .99}) {
    final errors = <String>[], warnings = <String>[];
    GamePackage fail(String e) => GamePackage._('', null, const {}, [e], warnings);
    if (zip.length > maxZip) return fail('The zip is ${_mb(zip.length)}; the limit is ${_mb(maxZip)}.');
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zip);
    } catch (_) {
      return fail('This isn’t a zip file (or it’s damaged).');
    }

    // Paths, without a folder that wraps everything.
    final entries = <String, ArchiveFile>{};
    for (final f in archive.files) {
      if (!f.isFile) continue;
      final p = f.name.replaceAll('\\', '/');
      final parts = p.split('/');
      if (p.startsWith('/') || parts.contains('..') || parts.any((s) => s.isEmpty && s != parts.last)) {
        return fail('Unsafe path in the zip: $p');
      }
      if (parts.any((s) => s.startsWith('.') || s == '__MACOSX') || parts.last.isEmpty) continue;
      entries[p] = f;
    }
    if (entries.isEmpty) return fail('The zip is empty.');
    final firstParts = entries.keys.map((p) => p.split('/')).toList();
    final wrapped = firstParts.every((p) => p.length > 1 && p.first == firstParts.first.first) && !entries.containsKey('game.json');
    String inner(String p) => wrapped ? p.substring(p.indexOf('/') + 1) : p;

    final files = <String, Uint8List>{};
    final skipped = <String>{};
    var total = 0;
    for (final MapEntry(key: path, value: f) in entries.entries) {
      final p = inner(path);
      final top = p.contains('/') ? p.substring(0, p.indexOf('/')) : '';
      final ext = p.contains('.') ? p.substring(p.lastIndexOf('.') + 1).toLowerCase() : '';
      if (_skipDirs.contains(top)) {
        skipped.add('$top/');
        continue;
      }
      if (!_types.contains(ext)) {
        skipped.add(p);
        continue;
      }
      final bytes = f.readBytes();
      if (bytes == null) continue;
      if (bytes.length > maxFile) {
        errors.add('$p is ${_mb(bytes.length)}; each file can be at most ${_mb(maxFile)}.');
        continue;
      }
      total += bytes.length;
      files[p] = bytes;
    }
    if (skipped.isNotEmpty) warnings.add('Left out (not needed to play): ${(skipped.toList()..sort()).take(8).join(', ')}${skipped.length > 8 ? '…' : ''}');
    if (files.length > maxFiles) errors.add('${files.length} files; the limit is $maxFiles.');
    if (total > maxTotal) errors.add('The game is ${_mb(total)}; the limit is ${_mb(maxTotal)}.');

    // game.json
    final manifestBytes = files['game.json'];
    if (manifestBytes == null) return GamePackage._('', null, files, [...errors, 'No game.json at the top of the game folder.'], warnings);
    Map<String, dynamic> j;
    try {
      j = Map<String, dynamic>.from(jsonDecode(utf8.decode(manifestBytes)) as Map);
    } catch (e) {
      return GamePackage._('', null, files, [...errors, 'game.json isn’t valid JSON.'], warnings);
    }
    final id = '${j['id'] ?? ''}';
    if (j['zoya7'] != 1) errors.add('game.json needs "zoya7": 1 (made with docs/GAME_PROMPT.md).');
    if (!_id.hasMatch(id)) {
      errors.add('game.json id "$id": 3–24 lowercase letters and digits, starting with a letter (no spaces or hyphens).');
    } else if (reserved.contains(id)) {
      errors.add('The id "$id" is a built-in game’s; pick another.');
    }
    final name = '${j['name'] ?? ''}'.trim();
    if (name.isEmpty || name.length > 18) errors.add('game.json name: 1–18 characters (it has to fit the lobby tile).');
    final cat = '${j['category'] ?? 'INSTANT'}'.toUpperCase();
    if (!const {'SLOTS', 'TABLE', 'INSTANT'}.contains(cat)) errors.add('game.json category: SLOTS, TABLE or INSTANT.');
    final blurb = '${j['description'] ?? ''}'.trim();
    if (blurb.length > 160) errors.add('game.json description: at most 160 characters.');
    final credits = '${j['credits'] ?? ''}'.trim();
    if (credits.isEmpty) warnings.add('game.json has no credits (who made the art and sound, and the licence).');
    if (_banned.hasMatch('$name $blurb')) errors.add('The name or description uses money wording ("\$", cash, money, redeem, withdraw).');

    final options = <BetOption>[];
    final rawOptions = j['options'];
    if (rawOptions is! List || rawOptions.isEmpty || rawOptions.length > 6) {
      errors.add('game.json options: a list of 1–6 bet options, each with its outcomes.');
    } else {
      final optionIds = <String>{};
      for (final (i, raw) in rawOptions.indexed) {
        if (raw is! Map) {
          errors.add('options[$i] isn’t an object.');
          continue;
        }
        final oid = '${raw['id'] ?? ''}';
        final where = 'option "$oid"';
        if (!_key.hasMatch(oid) || !optionIds.add(oid)) errors.add('options[$i] id: unique, lowercase letters, digits, "_" or "-".');
        final outs = <Outcome>[];
        final rawOuts = raw['outcomes'];
        if (rawOuts is! List || rawOuts.length < 2 || rawOuts.length > 40) {
          errors.add('$where: 2–40 outcomes.');
          continue;
        }
        final outIds = <String>{};
        for (final (k, o) in rawOuts.indexed) {
          final oId = o is Map ? '${o['id'] ?? ''}' : '';
          final x = o is Map ? o['multiplier'] : null;
          final share = o is Map ? (o['share'] ?? 1) : 1;
          final label = o is Map ? '${o['label'] ?? ''}' : '';
          if (!_key.hasMatch(oId) || !outIds.add(oId)) errors.add('$where outcome $k: a unique id (lowercase letters, digits, "_" or "-").');
          if (x is! num || x < 0 || x > 5000 || (x > 0 && x < .1)) {
            errors.add('$where outcome "$oId": multiplier 0 (no win) or 0.1–5000.');
            continue;
          }
          if (share is! num || share <= 0 || share > 100) errors.add('$where outcome "$oId": share is a number above 0 (1 = the usual).');
          if (_banned.hasMatch(label)) errors.add('$where outcome "$oId": no money wording in the label.');
          outs.add(Outcome(id: oId, label: label, multiplier: x.toDouble(), share: share is num && share > 0 ? share.toDouble() : 1));
        }
        if (!outs.any((o) => !o.wins)) errors.add('$where: needs an outcome with multiplier 0 (no win).');
        if (!outs.any((o) => o.wins)) errors.add('$where: needs at least one win.');
        if (outs.any((o) => o.wins) && outs.any((o) => !o.wins) && chancesFor(outs, maxRtp) == null) {
          errors.add('$where: these multipliers are too small to pay back ${(maxRtp * 100).round()}% — the wins would have to come almost every round. Add bigger wins.');
        }
        options.add(BetOption(id: oid, label: '${raw['label'] ?? ''}', outcomes: outs));
      }
    }

    // The game's files
    final index = files['index.html'];
    if (index == null) {
      errors.add('No index.html at the top of the game folder.');
    } else if (!utf8.decode(index, allowMalformed: true).contains('zoya7-bridge.js')) {
      errors.add('index.html must load zoya7-bridge.js (before the game’s own scripts).');
    }
    _image(files, 'lobby/icon.png', errors, square: true);
    final code = StringBuffer();
    _image(files, 'lobby/tile.png', errors, square: false);
    for (final MapEntry(key: p, value: b) in files.entries) {
      final ext = p.substring(p.lastIndexOf('.') + 1).toLowerCase();
      if (!_text.contains(ext)) continue;
      final text = utf8.decode(b, allowMalformed: true);
      final m = _external.firstMatch(text);
      if (m != null) errors.add('$p loads something from the internet (“${m.group(0)!.trim()}”); a game must carry all its own files.');
      code.write(text);
    }
    // The game has to use the bridge: start, play through it, and lead back to the lobby.
    for (final call in const ['Zoya7.init', 'Zoya7.play', 'Zoya7.exit']) {
      if (!code.toString().contains(call)) errors.add('The game never calls $call() (docs/GAME_PROMPT.md, “The bridge”).');
    }
    if (!code.toString().contains('Zoya7.ready')) warnings.add('The game never calls Zoya7.ready(); the app lifts its loading screen shortly after the game starts instead.');

    final game = errors.isEmpty
        ? HtmlGame(name: name, cat: cat, blurb: blurb, credits: credits, version: 0, options: options)
        : null;
    return GamePackage._(id, game, files, errors, warnings);
  }

  static void _image(Map<String, Uint8List> files, String path, List<String> errors, {required bool square}) {
    final b = files[path];
    final size = b == null ? null : pngSize(b);
    if (size == null) {
      errors.add('$path is missing (PNG).');
      return;
    }
    final (w, h) = size;
    if (square && (w != h || w < 256)) errors.add('$path must be square, at least 256 × 256 (is $w × $h).');
    if (!square && (w < 600 || w / h < 1.5 || w / h > 2.2)) errors.add('$path must be wide (about 880 × 472; is $w × $h).');
  }

  /// Width and height of a PNG, or null if it isn't one.
  static (int, int)? pngSize(Uint8List b) {
    const sig = [137, 80, 78, 71, 13, 10, 26, 10];
    if (b.length < 24) return null;
    for (var i = 0; i < 8; i++) {
      if (b[i] != sig[i]) return null;
    }
    final d = ByteData.sublistView(b);
    return (d.getUint32(16), d.getUint32(20));
  }

  static String _mb(int bytes) => '${(bytes / (1 << 20)).toStringAsFixed(1)} MB';
}
