import 'dart:math';

import 'package:flutter/foundation.dart';

import '../app/assets.dart' show games;
import '../games/blackjack/engine.dart' show BjRules;
import '../games/gold/src/math.dart';
import 'slot_math.dart';

/// The casino's back office: player accounts, the coin ledger, each game's
/// settings and math, and the play records the reports are built from.
///
/// Coins only: coins have no cash value. Staff put coins on an account
/// (coin in) and take them off (coin out); no money is recorded or paid out.
///
/// The player app and the admin panel share one [Casino]. Nothing is kept on
/// the device: it starts empty and holds what the database (the server) sends
/// ([CasinoSync]), only while the app is open.

enum PlayerStatus { active, suspended, banned }

/// Stored by index, so the order never changes.
enum TxnType { start, coinIn, coinOut, bonus, adjust }

/// live: playable · maintenance: shown, can't be opened · hidden: not in the lobby.
enum GameStatus { live, maintenance, hidden }

enum StaffRole { owner, manager, cashier }

/// What kind of math a game has (decides its math screen).
enum GameKind { goldSlot, slot, blackjack, roulette, plinko }

GameKind kindOf(String gameId) => switch (gameId) {
      'classic777' || 'fruitspin' => GameKind.goldSlot,
      'blackjack' => GameKind.blackjack,
      'roulette' => GameKind.roulette,
      'plinko' => GameKind.plinko,
      _ => GameKind.slot,
    };

String statusName(Enum e) => switch (e) {
      TxnType.start => 'Starting amount',
      TxnType.coinIn => 'Coin in',
      TxnType.coinOut => 'Coin out',
      TxnType.bonus => 'Bonus',
      TxnType.adjust => 'Adjustment',
      _ => '${e.name[0].toUpperCase()}${e.name.substring(1)}',
    };

class Player {
  Player({
    required this.id,
    required this.username,
    required this.name,
    required this.created,
    this.phone = '',
    this.email = '',
    this.note = '',
    this.status = PlayerStatus.active,
    this.gc = 0,
    this.sc = 0,
    this.startGc = 0,
    this.startSc = 0,
    this.createdBy = '',
    this.loginGen = 0,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? created;

  final String id;
  String username;
  String name;
  String phone;
  String email;
  String note;
  PlayerStatus status;

  /// Balances and last seen are worked out from the ledger and play records
  /// ([Casino.recompute]), so two devices can never overwrite each other's money.
  double gc;
  double sc;

  /// Credited when the account was made.
  double startGc;
  double startSc;
  final DateTime created;
  final String createdBy;
  DateTime lastSeen;

  /// How many times the password was reset (each reset is a new sign-in
  /// account, see [playerEmail]). Passwords themselves are never stored here.
  int loginGen;

  Map<String, Object> toJson() => {
        'id': id,
        'u': username,
        'n': name,
        'ph': phone,
        'em': email,
        'no': note,
        'st': status.index,
        'sgc': startGc,
        'ssc': startSc,
        'c': created.millisecondsSinceEpoch,
        'by': createdBy,
        'lg': loginGen,
      };

  static Player fromJson(Map<String, dynamic> j) => Player(
        id: j['id'] as String,
        username: j['u'] as String,
        name: j['n'] as String,
        phone: j['ph'] as String? ?? '',
        email: j['em'] as String? ?? '',
        note: j['no'] as String? ?? '',
        status: PlayerStatus.values[j['st'] as int],
        startGc: (j['sgc'] as num).toDouble(),
        startSc: (j['ssc'] as num).toDouble(),
        created: DateTime.fromMillisecondsSinceEpoch(j['c'] as int),
        createdBy: j['by'] as String? ?? '',
        loginGen: (j['lg'] as num?)?.toInt() ?? 0,
      );
}

/// One line of the coin ledger: what the player's balance moved by
/// (negative for a coin out).
class Txn {
  Txn({
    required this.id,
    required this.playerId,
    required this.type,
    required this.at,
    this.gc = 0,
    this.sc = 0,
    this.by = '',
    this.note = '',
  });

  final String id;
  final String playerId;
  final TxnType type;
  final DateTime at;
  final double gc;
  final double sc;
  final String by;
  final String note;

  Map<String, Object> toJson() => {
        'id': id,
        'p': playerId,
        't': type.index,
        'at': at.millisecondsSinceEpoch,
        'gc': gc,
        'sc': sc,
        'by': by,
        'no': note,
      };

  static Txn fromJson(Map<String, dynamic> j) {
    // Older records: a turned-down request ('s' 2) moved nothing.
    final none = j['s'] == 2;
    return Txn(
      id: j['id'] as String,
      playerId: j['p'] as String,
      type: TxnType.values[j['t'] as int],
      at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
      gc: none ? 0 : (j['gc'] as num).toDouble(),
      sc: none ? 0 : (j['sc'] as num).toDouble(),
      by: j['by'] as String? ?? '',
      note: j['no'] as String? ?? '',
    );
  }
}

/// A game's settings and math.
class GameConfig {
  GameConfig({
    required this.id,
    this.status = GameStatus.live,
    this.weights,
    this.minIdx = 0,
    this.maxIdx = GoldRules.maxBetIndex,
    this.bj = const BjRules(),
    this.minGc = 500,
    this.maxGc = 250000,
    this.minSc = .5,
    this.maxSc = 250,
    this.wheel = 'european',
    this.risk = 'medium',
    this.targetRtp = .96,
    this.badge = '',
  });

  final String id;
  GameStatus status;

  /// Gold slots: reel weights (stops per symbol).
  Map<Sym, double>? weights;

  /// Gold slots: the bet steps offered (indexes into [GoldRules.bets]).
  int minIdx;
  int maxIdx;

  /// Blackjack rules.
  BjRules bj;

  /// Table games: bet limits per currency.
  double minGc, maxGc, minSc, maxSc;

  /// Roulette: 'european' (single zero) or 'american' (double zero).
  String wheel;

  /// Plinko: 'low', 'medium' or 'high'.
  String risk;

  /// Games without an engine yet (and Plinko): the RTP their math is built to.
  double targetRtp;

  /// Lobby ribbon: '', 'NEW' or 'HOT'.
  String badge;

  GameKind get kind => kindOf(id);

  /// Theoretical return to player of the current settings.
  double get rtp => switch (kind) {
        GameKind.goldSlot => SlotMath(weights ?? LocalGoldMath.defaultWeights).rtp,
        GameKind.blackjack => 1 - bj.houseEdge,
        GameKind.roulette => wheel == 'american' ? 1 - 2 / 38 : 1 - 1 / 37,
        _ => targetRtp,
      };

  double get houseEdge => 1 - rtp;

  Map<String, Object> toJson() => {
        'id': id,
        'st': status.index,
        if (weights != null) 'w': {for (final e in weights!.entries) e.key.name: e.value},
        'mi': minIdx,
        'ma': maxIdx,
        'bj': bj.toJson(),
        'lim': [minGc, maxGc, minSc, maxSc],
        'wh': wheel,
        'rk': risk,
        'rtp': targetRtp,
        'bd': badge,
      };

  static GameConfig fromJson(Map<String, dynamic> j) {
    final lim = (j['lim'] as List).map((e) => (e as num).toDouble()).toList();
    final w = j['w'] as Map<String, dynamic>?;
    return GameConfig(
      id: j['id'] as String,
      status: GameStatus.values[j['st'] as int],
      weights: w == null ? null : {for (final s in Sym.values) s: (w[s.name] as num?)?.toDouble() ?? 1},
      minIdx: j['mi'] as int,
      maxIdx: j['ma'] as int,
      bj: BjRules.fromJson(j['bj'] as Map<String, dynamic>),
      minGc: lim[0],
      maxGc: lim[1],
      minSc: lim[2],
      maxSc: lim[3],
      wheel: j['wh'] as String,
      risk: j['rk'] as String,
      targetRtp: (j['rtp'] as num).toDouble(),
      badge: j['bd'] as String? ?? '',
    );
  }
}

/// One player's play of one game on one day.
class Play {
  Play(this.day, this.gameId, this.playerId);
  final int day;
  final String gameId;
  final String playerId;
  int rounds = 0;
  double wGc = 0, winGc = 0, wSc = 0, winSc = 0;

  /// When the last round was played (ms since epoch).
  int last = 0;

  double get netGc => winGc - wGc;
  double get netSc => winSc - wSc;

  List<Object> toJson() => [day, gameId, playerId, rounds, wGc, winGc, wSc, winSc, last];

  static Play fromJson(List<dynamic> j) => Play(j[0] as int, j[1] as String, j[2] as String)
    ..rounds = (j[3] as num).toInt()
    ..wGc = (j[4] as num).toDouble()
    ..winGc = (j[5] as num).toDouble()
    ..wSc = (j[6] as num).toDouble()
    ..winSc = (j[7] as num).toDouble()
    ..last = j.length > 8 ? (j[8] as num).toInt() : 0;
}

/// Someone who signs in to the admin panel, by their Firebase account [uid].
class Staff {
  Staff(this.uid, this.name, this.role, {this.username = ''});
  final String uid;
  String name;
  StaffRole role;

  /// What they sign in with.
  String username;

  bool get canManage => role != StaffRole.cashier;
  bool get isOwner => role == StaffRole.owner;

  Map<String, Object> toJson() => {'n': name, 'r': role.index, 'u': username};
  static Staff fromJson(String uid, Map<String, dynamic> j) =>
      Staff(uid, j['n'] as String, StaffRole.values[j['r'] as int], username: j['u'] as String? ?? '');
}

class AuditEntry {
  AuditEntry(this.at, this.by, this.action);
  final DateTime at;
  final String by;
  final String action;

  /// Stable key for syncing (time + a hash of who and what).
  String get key => '${at.millisecondsSinceEpoch}_${fnv('$by|$action')}';

  List<Object> toJson() => [at.millisecondsSinceEpoch, by, action];
  static AuditEntry fromJson(List<dynamic> j) =>
      AuditEntry(DateTime.fromMillisecondsSinceEpoch((j[0] as num).toInt()), j[1] as String, j[2] as String);
}

/// 32-bit FNV-1a, as 8 hex digits (same on every platform, unlike hashCode).
String fnv(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

class CasinoSettings {
  /// Starting amount every new player ID gets.
  double newPlayerGc = 50000;
  double newPlayerSc = 2;

  /// Most DC one player can be given by coin in in a day.
  double maxCoinInPerDay = 1000;

  bool registrationOpen = true;
  bool dailyBonus = true;

  /// Every game closed to players, with [maintenanceMessage].
  bool maintenance = false;
  String maintenanceMessage = 'We’re upgrading the games. Back soon!';

  Map<String, Object> toJson() => {
        'ngc': newPlayerGc,
        'nsc': newPlayerSc,
        'cid': maxCoinInPerDay,
        'reg': registrationOpen,
        'db': dailyBonus,
        'mt': maintenance,
        'mm': maintenanceMessage,
      };

  static CasinoSettings fromJson(Map<String, dynamic> j) {
    double d(String k, double v) => (j[k] as num?)?.toDouble() ?? v;
    final s = CasinoSettings();
    return s
      ..newPlayerGc = d('ngc', s.newPlayerGc)
      ..newPlayerSc = d('nsc', s.newPlayerSc)
      ..maxCoinInPerDay = d('cid', s.maxCoinInPerDay)
      ..registrationOpen = j['reg'] as bool? ?? true
      ..dailyBonus = j['db'] as bool? ?? true
      ..maintenance = j['mt'] as bool? ?? false
      ..maintenanceMessage = j['mm'] as String? ?? s.maintenanceMessage;
  }
}

/// A span of whole days for reports: [from] (inclusive) to [to] (exclusive).
class Period {
  const Period(this.label, this.from, this.to);
  final String label;
  final DateTime from;
  final DateTime to;

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  static List<Period> standard(DateTime now) {
    final today = _day(now);
    final tomorrow = today.add(const Duration(days: 1));
    return [
      Period('Today', today, tomorrow),
      Period('Yesterday', today.subtract(const Duration(days: 1)), today),
      Period('7 days', today.subtract(const Duration(days: 6)), tomorrow),
      Period('30 days', today.subtract(const Duration(days: 29)), tomorrow),
      Period('This month', DateTime(now.year, now.month), tomorrow),
      Period('All time', DateTime(2000), tomorrow),
    ];
  }
}

/// Coins for one span: the starting amount, what came in and went out, and
/// what's left — per game and per player.
class Report {
  Report(this.period);
  final Period period;

  /// Players' balances when the period started / ended.
  double openGc = 0, openSc = 0, closeGc = 0, closeSc = 0;

  double coinInGc = 0, coinInSc = 0;
  int coinIns = 0;
  double coinOutGc = 0, coinOutSc = 0;
  int coinOuts = 0;
  double startGc = 0, startSc = 0, bonusGc = 0, bonusSc = 0, adjustGc = 0, adjustSc = 0;
  int newPlayers = 0;
  final active = <String>{};

  final games = <String, GameReport>{};
  final players = <String, PlayerReport>{};

  /// DC given by coin in minus taken by coin out.
  double get netSc => coinInSc - coinOutSc;
  double get wageredSc => games.values.fold(0, (a, g) => a + g.wSc);
  double get wonSc => games.values.fold(0, (a, g) => a + g.winSc);
  double get wageredGc => games.values.fold(0, (a, g) => a + g.wGc);
  double get wonGc => games.values.fold(0, (a, g) => a + g.winGc);
  double get ggrSc => wageredSc - wonSc;
  int get rounds => games.values.fold(0, (a, g) => a + g.rounds);
}

class GameReport {
  GameReport(this.gameId);
  final String gameId;
  int rounds = 0;
  final players = <String>{};
  double wGc = 0, winGc = 0, wSc = 0, winSc = 0;
  double get ggrSc => wSc - winSc;
  double get ggrGc => wGc - winGc;

  /// What the game actually paid back (DC play, else GC).
  double? get actualRtp => wSc > 0 ? winSc / wSc : (wGc > 0 ? winGc / wGc : null);
}

class PlayerReport {
  PlayerReport(this.playerId);
  final String playerId;
  double openSc = 0, closeSc = 0, openGc = 0, closeGc = 0;
  double coinInSc = 0, coinOutSc = 0, wSc = 0, winSc = 0;
  double get netSc => coinInSc - coinOutSc;
}

class CasinoError implements Exception {
  CasinoError(this.message);
  final String message;
  @override
  String toString() => message;
}

int dayOf(DateTime t) => DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

DateTime dayStart(int day) {
  final u = DateTime.fromMillisecondsSinceEpoch(day * Duration.millisecondsPerDay, isUtc: true);
  return DateTime(u.year, u.month, u.day);
}

class Casino extends ChangeNotifier {
  Casino._({DateTime Function()? clock}) : clock = clock ?? DateTime.now;


  /// The demo account (tests and previews).
  static const meId = 'Z7-100123';

  final DateTime Function() clock;

  final players = <Player>[];
  final txns = <Txn>[];
  final configs = <String, GameConfig>{};
  final plays = <String, Play>{};
  final staff = <Staff>[];
  final audit = <AuditEntry>[];
  var settings = CasinoSettings();
  String featured = 'classic777';

  /// Sign-in lookups: player ID or username ([loginKey]) → the account's
  /// email and player ID; and Firebase account → player ID.
  final logins = <String, ({String email, String playerId})>{};
  final uids = <String, String>{};

  /// When each player last opened the game (ms since epoch).
  final seen = <String, int>{};

  /// Seeding: skip the full balance pass after every change.
  bool _batch = false;

  /// Told about every local change (the database sync pushes it).
  VoidCallback? onLocalChange;

  /// Who is signed in to the admin panel (stamped on the ledger and audit log).
  Staff? admin;
  String get actor => admin?.name ?? 'System';

  DateTime get now => clock();

  // ── Lookup ─────────────────────────────────────────────────────────────────
  Player? player(String id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// The demo account.
  Player get me => player(meId)!;

  /// How a player ID or username is kept in [logins] (Firebase keys can't
  /// hold a dot).
  static String loginKey(String who) => who.trim().toLowerCase().replaceAll('.', ',');

  /// The player a Firebase account belongs to.
  Player? playerForUid(String uid) => uids[uid] == null ? null : player(uids[uid]!);

  /// Why a player can't play right now, or null.
  static String? blocked(Player p) => switch (p.status) {
        PlayerStatus.active => null,
        PlayerStatus.banned => 'This account is closed',
        PlayerStatus.suspended => 'This account is on hold — talk to your cashier',
      };

  /// Tie [p] to its sign-in account (a new one after a password reset).
  void linkLogin(Player p, String uid, String email, {int generation = 0}) {
    uids.removeWhere((_, id) => id == p.id);
    uids[uid] = p.id;
    logins.removeWhere((_, l) => l.playerId == p.id);
    for (final k in {loginKey(p.id), loginKey(p.username)}) {
      logins[k] = (email: email, playerId: p.id);
    }
    p.loginGen = generation;
    if (generation > 0) _log('Reset password of ${p.username}');
    _changed();
  }

  /// The player has the game open.
  void touchSeen(String playerId) {
    seen[playerId] = now.millisecondsSinceEpoch;
    _changed();
  }

  GameConfig config(String gameId) => configs.putIfAbsent(gameId, () => GameConfig(id: gameId));

  GameStatus statusOf(String gameId) => config(gameId).status;

  /// Can a player open this game right now?
  bool isOpen(String gameId) => !settings.maintenance && statusOf(gameId) == GameStatus.live;

  List<Txn> txnsOf(String playerId) => [
        for (final t in txns.reversed)
          if (t.playerId == playerId) t,
      ];

  bool usernameTaken(String u, {String? except}) =>
      players.any((p) => p.id != except && p.username.toLowerCase() == u.trim().toLowerCase());

  int get online => players.where((p) => now.difference(p.lastSeen).inMinutes < 15).length;

  /// DC a player has been given by coin in, all time.
  double coinInTotal(String playerId) => txns
      .where((t) => t.playerId == playerId && t.type == TxnType.coinIn)
      .fold(0, (a, t) => a + t.sc);

  // ── Players ────────────────────────────────────────────────────────────────
  static const _pwChars = 'abcdefghjkmnpqrstuvwxyz23456789';
  final _rng = Random();

  String newPassword([Random? r]) => String.fromCharCodes(
      List.generate(8, (_) => _pwChars.codeUnitAt((r ?? _rng).nextInt(_pwChars.length))));

  String suggestUsername() {
    var n = players.length + 1;
    while (usernameTaken('player$n')) {
      n++;
    }
    return 'player$n';
  }

  /// Make a new player ID with its starting amount (defaults from settings).
  Player createPlayer({
    required String username,
    String? name,
    String phone = '',
    String email = '',
    String note = '',
    double? startGc,
    double? startSc,
    DateTime? at,
    bool log = true,
  }) {
    final u = username.trim();
    if (u.length < 3) throw CasinoError('Username needs at least 3 characters');
    if (!RegExp(r'^[A-Za-z0-9_.]+$').hasMatch(u)) throw CasinoError('Use letters, numbers, _ and . only');
    if (usernameTaken(u)) throw CasinoError('“$u” is taken');
    final when = at ?? now;
    final p = Player(
      id: _newPlayerId(),
      username: u,
      name: (name == null || name.trim().isEmpty) ? u : name.trim(),
      phone: phone,
      email: email,
      note: note,
      created: when,
      createdBy: actor,
      startGc: startGc ?? settings.newPlayerGc,
      startSc: startSc ?? settings.newPlayerSc,
    );
    players.add(p);
    _post(Txn(id: _txnId(), playerId: p.id, type: TxnType.start, at: when, gc: p.startGc, sc: p.startSc, by: actor));
    if (log) _log('Created player ${p.username} (${p.id})');
    _changed();
    return p;
  }

  /// Make [count] IDs named [prefix]001, [prefix]002… (skipping taken names).
  List<Player> bulkCreate(int count, String prefix, {double? startGc, double? startSc}) {
    if (count < 1 || count > 50) throw CasinoError('Make between 1 and 50 at a time');
    final made = <Player>[];
    var n = 1;
    while (made.length < count) {
      final u = '$prefix${n.toString().padLeft(3, '0')}';
      n++;
      if (usernameTaken(u)) continue;
      made.add(createPlayer(username: u, startGc: startGc, startSc: startSc, log: false));
    }
    _log('Bulk-created $count players ($prefix…)');
    _changed();
    return made;
  }

  void updatePlayer(Player p, {String? name, String? username, String? phone, String? email, String? note}) {
    if (username != null && username.trim() != p.username) {
      if (usernameTaken(username, except: p.id)) throw CasinoError('“${username.trim()}” is taken');
      final login = logins.remove(loginKey(p.username));
      p.username = username.trim();
      if (login != null) logins[loginKey(p.username)] = login;
    }
    if (name != null) p.name = name.trim();
    if (phone != null) p.phone = phone.trim();
    if (email != null) p.email = email.trim();
    if (note != null) p.note = note.trim();
    _log('Edited player ${p.username}');
    _changed();
  }

  void setPlayerStatus(Player p, PlayerStatus s) {
    p.status = s;
    _log('${statusName(s)} ${p.username}');
    _changed();
  }

  void deletePlayer(Player p) {
    players.remove(p);
    logins.removeWhere((_, l) => l.playerId == p.id);
    uids.removeWhere((_, id) => id == p.id);
    _log('Deleted player ${p.username} (${p.id})');
    _changed();
  }

  // ── Coins ──────────────────────────────────────────────────────────────────
  double _todaySc(Player p, TxnType type) {
    final d = dayOf(now);
    return txns.where((t) => t.playerId == p.id && t.type == type && dayOf(t.at) == d).fold(0, (a, t) => a + t.sc.abs());
  }

  /// Put coins on a player's account.
  Txn coinIn(Player p, {double gc = 0, double sc = 0, String note = '', bool checkLimit = true}) {
    if (gc < 0 || sc < 0 || (gc == 0 && sc == 0)) throw CasinoError('Enter an amount');
    if (p.status != PlayerStatus.active) throw CasinoError('${p.username} is ${p.status.name}');
    if (checkLimit && _todaySc(p, TxnType.coinIn) + sc > settings.maxCoinInPerDay + 1e-9) {
      throw CasinoError('Over the daily coin-in limit of ${settings.maxCoinInPerDay.toStringAsFixed(0)} DC');
    }
    final t = _post(Txn(id: _txnId(), playerId: p.id, type: TxnType.coinIn, at: now, gc: gc.roundToDouble(), sc: _r2(sc), by: actor, note: note));
    _log('Coin in ${_coins(t.gc, t.sc)} → ${p.username}');
    _changed();
    return t;
  }

  /// A coin package from the app's store.
  Txn purchase(Player p, {required double gc, required double sc, String note = ''}) {
    final t = _post(Txn(id: _txnId(), playerId: p.id, type: TxnType.coinIn, at: now, gc: gc, sc: sc, by: 'Store', note: note));
    _changed();
    return t;
  }

  /// Take coins off a player's account.
  Txn coinOut(Player p, {double gc = 0, double sc = 0, String note = ''}) {
    if (gc < 0 || sc < 0 || (gc == 0 && sc == 0)) throw CasinoError('Enter an amount');
    if (sc > p.sc + 1e-9) throw CasinoError('${p.username} has only ${_r2(p.sc).toStringAsFixed(2)} DC');
    if (gc > p.gc) throw CasinoError('${p.username} has only ${p.gc.toStringAsFixed(0)} GC');
    final t = _post(Txn(id: _txnId(), playerId: p.id, type: TxnType.coinOut, at: now, gc: -gc.roundToDouble(), sc: -_r2(sc), by: actor, note: note));
    _log('Coin out ${_coins(gc, sc)} ← ${p.username}');
    _changed();
    return t;
  }

  /// Free coins (promos, comps) or a correction (either sign).
  Txn credit(Player p, {double gc = 0, double sc = 0, TxnType type = TxnType.bonus, String note = ''}) {
    if (gc == 0 && sc == 0) throw CasinoError('Enter an amount');
    if (p.gc + gc < 0 || p.sc + sc < -1e-9) throw CasinoError('That would take the balance below zero');
    final t = _post(Txn(id: _txnId(), playerId: p.id, type: type, at: now, gc: gc, sc: sc, by: actor, note: note));
    _log('${statusName(type)} ${_coins(gc, sc)} → ${p.username}${note.isEmpty ? '' : ' ($note)'}');
    _changed();
    return t;
  }

  // ── Games ──────────────────────────────────────────────────────────────────
  void setGameStatus(String gameId, GameStatus s) {
    config(gameId).status = s;
    _log('${_gameName(gameId)}: ${statusName(s)}');
    _changed();
  }

  void setFeatured(String gameId) {
    featured = gameId;
    _log('Featured ${_gameName(gameId)} in the lobby');
    _changed();
  }

  /// Change a game's settings; [what] goes in the audit log.
  void updateGame(String gameId, String what, void Function(GameConfig c) change) {
    change(config(gameId));
    _log('${_gameName(gameId)}: $what');
    _changed();
  }

  /// Record a finished round (or several) of play.
  void recordRound(String gameId, String playerId, Currency c, double staked, double returned, {int rounds = 1, DateTime? at}) {
    final when = at ?? now;
    final day = dayOf(when);
    final p = plays.putIfAbsent('$day|$gameId|$playerId', () => Play(day, gameId, playerId));
    p.rounds += rounds;
    if (c == Currency.gc) {
      p.wGc += staked;
      p.winGc += returned;
    } else {
      p.wSc = _r2(p.wSc + staked);
      p.winSc = _r2(p.winSc + returned);
    }
    p.last = max(p.last, when.millisecondsSinceEpoch);
    _changed(notify: at == null);
  }

  // ── Settings & staff ───────────────────────────────────────────────────────
  void updateSettings(String what, void Function(CasinoSettings s) change) {
    change(settings);
    _log('Settings: $what');
    _changed();
  }

  /// Open the admin panel as the staff member with Firebase account [uid].
  Staff? signIn(String uid, {bool log = true}) {
    for (final s in staff) {
      if (s.uid == uid) {
        admin = s;
        if (log) {
          _log('Signed in');
          _changed();
        } else {
          notifyListeners();
        }
        return s;
      }
    }
    return null;
  }

  void signOut() {
    if (admin == null) return;
    _log('Signed out');
    admin = null;
    _changed();
  }

  /// Give the Firebase account [uid] a role in the admin panel.
  void addStaff(String uid, String name, StaffRole role, {String username = ''}) {
    if (name.trim().isEmpty) throw CasinoError('Enter a name');
    if (staff.any((s) => s.uid == uid)) throw CasinoError('Already on the staff');
    staff.add(Staff(uid, name.trim(), role, username: username.trim().toLowerCase()));
    _log('Added ${role.name} ${name.trim()}');
    _changed();
  }

  void removeStaff(Staff s) {
    if (s == admin) throw CasinoError('You can’t remove yourself');
    if (s.isOwner && staff.where((x) => x.isOwner).length == 1) throw CasinoError('Keep at least one owner');
    staff.remove(s);
    _log('Removed ${s.role.name} ${s.name}');
    _changed();
  }

  /// Remove every player, the ledger and play records — a clean start
  /// for real use. Staff, settings and game setup stay.
  void clearAll() {
    players.clear();
    txns.clear();
    plays.clear();
    seen.clear();
    logins.clear();
    uids.clear();
    _log('Cleared all players and the ledger');
    _changed();
  }

  // ── Reports ────────────────────────────────────────────────────────────────
  Report report(Period period) {
    final r = Report(period);
    final from = period.from, to = period.to;
    final fromDay = dayOf(from), toDay = dayOf(to);
    bool inP(DateTime t) => !t.isBefore(from) && t.isBefore(to);

    // Balances now, rolled back over everything after each edge.
    for (final p in players) {
      r.players[p.id] = PlayerReport(p.id)
        ..openGc = p.gc
        ..openSc = p.sc
        ..closeGc = p.gc
        ..closeSc = p.sc;
    }
    for (final t in txns) {
      final pr = r.players[t.playerId];
      if (pr == null) continue;
      if (!t.at.isBefore(from)) {
        pr.openGc -= t.gc;
        pr.openSc -= t.sc;
      }
      if (!t.at.isBefore(to)) {
        pr.closeGc -= t.gc;
        pr.closeSc -= t.sc;
      }
    }
    for (final pl in plays.values) {
      final pr = r.players[pl.playerId];
      if (pr == null) continue;
      if (pl.day >= fromDay) {
        pr.openGc -= pl.netGc;
        pr.openSc -= pl.netSc;
      }
      if (pl.day >= toDay) {
        pr.closeGc -= pl.netGc;
        pr.closeSc -= pl.netSc;
      }
    }

    for (final t in txns) {
      if (!inP(t.at)) continue;
      final pr = r.players[t.playerId];
      switch (t.type) {
        case TxnType.coinIn:
          r.coinIns++;
          r.coinInGc += t.gc;
          r.coinInSc += t.sc;
          pr?.coinInSc += t.sc;
        case TxnType.coinOut:
          r.coinOuts++;
          r.coinOutGc -= t.gc;
          r.coinOutSc -= t.sc;
          pr?.coinOutSc -= t.sc;
        case TxnType.start:
          r.newPlayers++;
          r.startGc += t.gc;
          r.startSc += t.sc;
        case TxnType.bonus:
          r.bonusGc += t.gc;
          r.bonusSc += t.sc;
        case TxnType.adjust:
          r.adjustGc += t.gc;
          r.adjustSc += t.sc;
      }
    }
    for (final pl in plays.values) {
      if (pl.day < fromDay || pl.day >= toDay) continue;
      final g = r.games.putIfAbsent(pl.gameId, () => GameReport(pl.gameId));
      g.rounds += pl.rounds;
      g.players.add(pl.playerId);
      g.wGc += pl.wGc;
      g.winGc += pl.winGc;
      g.wSc += pl.wSc;
      g.winSc += pl.winSc;
      r.active.add(pl.playerId);
      final pr = r.players[pl.playerId];
      pr?.wSc += pl.wSc;
      pr?.winSc += pl.winSc;
    }
    for (final pr in r.players.values) {
      r.openGc += pr.openGc;
      r.openSc += pr.openSc;
      r.closeGc += pr.closeGc;
      r.closeSc += pr.closeSc;
    }
    return r;
  }

  /// DC in and out per day for the last [days] days (oldest first).
  List<({DateTime day, double coinIn, double coinOut})> daily(int days) {
    final today = dayOf(now);
    final cin = List<double>.filled(days, 0), cout = List<double>.filled(days, 0);
    for (final t in txns) {
      final i = days - 1 - (today - dayOf(t.at));
      if (i < 0 || i >= days) continue;
      if (t.type == TxnType.coinIn) cin[i] += t.sc;
      if (t.type == TxnType.coinOut) cout[i] -= t.sc;
    }
    return [
      for (var i = 0; i < days; i++) (day: dayStart(today - days + 1 + i), coinIn: cin[i], coinOut: cout[i]),
    ];
  }

  /// One report as CSV (summary, then games, then players).
  String reportCsv(Report r) {
    String f(double v) => v.toStringAsFixed(2);
    final b = StringBuffer()
      ..writeln('Zoya7 report,${r.period.label},${r.period.from.toIso8601String().substring(0, 10)},'
          '${r.period.to.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10)}')
      ..writeln('Starting amount DC,${f(r.openSc)}')
      ..writeln('Starting amount GC,${f(r.openGc)}')
      ..writeln('Coin in DC,${f(r.coinInSc)}')
      ..writeln('Coin in GC,${f(r.coinInGc)}')
      ..writeln('Coin ins,${r.coinIns}')
      ..writeln('Coin out DC,${f(r.coinOutSc)}')
      ..writeln('Coin out GC,${f(r.coinOutGc)}')
      ..writeln('Coin outs,${r.coinOuts}')
      ..writeln('Net coin in DC,${f(r.netSc)}')
      ..writeln('Bonus DC,${f(r.bonusSc)}')
      ..writeln('Wagered DC,${f(r.wageredSc)}')
      ..writeln('Won DC,${f(r.wonSc)}')
      ..writeln('Hold DC,${f(r.ggrSc)}')
      ..writeln('Ending amount DC,${f(r.closeSc)}')
      ..writeln('Ending amount GC,${f(r.closeGc)}')
      ..writeln()
      ..writeln('Game,Status,Rounds,Players,Wagered DC,Won DC,Hold DC,Wagered GC,Won GC,Actual RTP,Theoretical RTP');
    for (final g in games) {
      final gr = r.games[g.id] ?? GameReport(g.id);
      final c = config(g.id);
      b.writeln('${g.name},${statusName(c.status)},${gr.rounds},${gr.players.length},${f(gr.wSc)},${f(gr.winSc)},'
          '${f(gr.ggrSc)},${f(gr.wGc)},${f(gr.winGc)},'
          '${gr.actualRtp == null ? '' : (gr.actualRtp! * 100).toStringAsFixed(2)},${(c.rtp * 100).toStringAsFixed(2)}');
    }
    b
      ..writeln()
      ..writeln('Player ID,Username,Starting DC,Coin in DC,Coin out DC,Net DC,Wagered DC,Won DC,Ending DC');
    for (final p in players) {
      final pr = r.players[p.id]!;
      b.writeln('${p.id},${p.username},${f(pr.openSc)},${f(pr.coinInSc)},${f(pr.coinOutSc)},${f(pr.netSc)},'
          '${f(pr.wSc)},${f(pr.winSc)},${f(pr.closeSc)}');
    }
    return b.toString();
  }

  // ── Internals ──────────────────────────────────────────────────────────────
  /// Unique across devices: time, then random letters.
  String _txnId() =>
      'T${now.millisecondsSinceEpoch.toRadixString(36)}${List.generate(4, (_) => _idChars[_rng.nextInt(_idChars.length)]).join()}';
  static const _idChars = 'abcdefghijklmnopqrstuvwxyz0123456789';

  /// Z7- and six digits nobody has.
  String _newPlayerId() {
    while (true) {
      final id = 'Z7-${100000 + _rng.nextInt(900000)}';
      if (player(id) == null) return id;
    }
  }

  /// Work every balance and last-seen out again from the ledger and play.
  void recompute() {
    final byId = {for (final p in players) p.id: p};
    for (final p in players) {
      p
        ..gc = 0
        ..sc = 0
        ..lastSeen = p.created;
    }
    void saw(Player p, DateTime t) {
      if (t.isAfter(p.lastSeen)) p.lastSeen = t;
    }

    for (final t in txns) {
      final p = byId[t.playerId];
      if (p == null) continue;
      p.gc += t.gc;
      p.sc += t.sc;
      saw(p, t.at);
    }
    for (final pl in plays.values) {
      final p = byId[pl.playerId];
      if (p == null) continue;
      p.gc += pl.netGc;
      p.sc += pl.netSc;
      if (pl.last > 0) saw(p, DateTime.fromMillisecondsSinceEpoch(pl.last));
    }
    for (final e in seen.entries) {
      final p = byId[e.key];
      if (p != null) saw(p, DateTime.fromMillisecondsSinceEpoch(e.value));
    }
    for (final p in players) {
      p
        ..gc = p.gc.roundToDouble()
        ..sc = _r2(p.sc);
    }
  }

  Txn _post(Txn t) {
    txns.add(t);
    final p = player(t.playerId);
    if (p != null) {
      p.gc += t.gc;
      p.sc = _r2(p.sc + t.sc);
      if (t.at.isAfter(p.lastSeen)) p.lastSeen = t.at;
    }
    return t;
  }

  void _log(String action) => audit.add(AuditEntry(now, actor, action));

  void _changed({bool notify = true}) {
    if (_batch) return;
    recompute();
    onLocalChange?.call();
    if (notify) notifyListeners();
  }

  // ── Records, for the database ──────────────────────────────────────────────
  /// Everything as separate records keyed by path ("players/Z7-123456"), so
  /// devices can sync record by record.
  Map<String, Map<String, dynamic>> toRecords() => {
        for (final p in players) 'players/${p.id}': p.toJson(),
        for (final t in txns) 'txns/${t.playerId}/${t.id}': t.toJson(),
        for (final c in configs.values) 'games/${c.id}': c.toJson(),
        for (final pl in plays.values) 'plays/${pl.playerId}/${pl.day}|${pl.gameId}': {'p': pl.toJson()},
        for (final a in audit.length > 500 ? audit.sublist(audit.length - 500) : audit) 'audit/${a.key}': {'a': a.toJson()},
        for (final e in seen.entries) 'seen/${e.key}': {'t': e.value},
        'meta/settings': {...settings.toJson(), 'featured': featured},
        for (final st in staff) 'staff/${st.uid}': st.toJson(),
        for (final e in logins.entries) 'logins/${e.key}': {'e': e.value.email, 'p': e.value.playerId},
        for (final e in uids.entries) 'uids/${e.key}': {'p': e.value},
      };

  /// Replace everything with [records] (what [toRecords] makes).
  void loadRecords(Map<String, Map<String, dynamic>> records) {
    players.clear();
    txns.clear();
    plays.clear();
    audit.clear();
    seen.clear();
    staff.clear();
    logins.clear();
    uids.clear();
    for (final MapEntry(key: path, value: j) in records.entries) {
      final slash = path.indexOf('/');
      final kind = path.substring(0, slash), key = path.substring(slash + 1);
      try {
        switch (kind) {
          case 'players':
            players.add(Player.fromJson(j));
          case 'txns':
            txns.add(Txn.fromJson(j));
          case 'games':
            configs[key] = GameConfig.fromJson(j);
          case 'plays':
            final pl = Play.fromJson(j['p'] as List);
            plays['${pl.day}|${pl.gameId}|${pl.playerId}'] = pl;
          case 'audit':
            audit.add(AuditEntry.fromJson(j['a'] as List));
          case 'seen':
            seen[key] = (j['t'] as num).toInt();
          case 'meta' when key == 'settings':
            settings = CasinoSettings.fromJson(j);
            featured = j['featured'] as String? ?? featured;
          case 'staff':
            staff.add(Staff.fromJson(key, j));
          case 'logins':
            logins[key] = (email: j['e'] as String, playerId: j['p'] as String);
          case 'uids':
            uids[key] = j['p'] as String;
        }
      } catch (_) {
        // A record this version can't read is skipped, not fatal.
      }
    }
    players.sort((a, b) => a.created.compareTo(b.created));
    txns.sort((a, b) => a.at.compareTo(b.at));
    audit.sort((a, b) => a.at.compareTo(b.at));
    if (admin != null) admin = staff.where((x) => x.uid == admin!.uid).firstOrNull;
    recompute();
    notifyListeners();
  }

  static String _gameName(String id) => games.firstWhere((g) => g.id == id, orElse: () => games.first).name;

  static String _coins(double gc, double sc) =>
      [if (gc != 0) '${gc.toStringAsFixed(0)} GC', if (sc != 0) '${sc.toStringAsFixed(2)} DC'].join(' + ');

  Map<String, Object> toJson() => {
        'v': 1,
        'players': [for (final p in players) p.toJson()],
        'txns': [for (final t in txns) t.toJson()],
        'games': [for (final c in configs.values) c.toJson()],
        'plays': [for (final p in plays.values) p.toJson()],
        'staff': {for (final s in staff) s.uid: s.toJson()},
        'logins': {for (final e in logins.entries) e.key: {'e': e.value.email, 'p': e.value.playerId}},
        'uids': uids,
        'audit': [for (final a in audit.length > 500 ? audit.sublist(audit.length - 500) : audit) a.toJson()],
        'seen': seen,
        'settings': settings.toJson(),
        'featured': featured,
      };

  static Casino fromJson(Map<String, dynamic> j) {
    final c = Casino._();
    c.players.addAll([for (final p in j['players'] as List) Player.fromJson(p as Map<String, dynamic>)]);
    c.txns.addAll([for (final t in j['txns'] as List) Txn.fromJson(t as Map<String, dynamic>)]);
    for (final g in j['games'] as List) {
      final cfg = GameConfig.fromJson(g as Map<String, dynamic>);
      c.configs[cfg.id] = cfg;
    }
    for (final p in j['plays'] as List) {
      final pl = Play.fromJson(p as List);
      c.plays['${pl.day}|${pl.gameId}|${pl.playerId}'] = pl;
    }
    for (final e in (j['staff'] as Map).entries) {
      c.staff.add(Staff.fromJson(e.key as String, (e.value as Map).cast<String, dynamic>()));
    }
    for (final e in (j['logins'] as Map? ?? const {}).entries) {
      final l = e.value as Map;
      c.logins[e.key as String] = (email: l['e'] as String, playerId: l['p'] as String);
    }
    for (final e in (j['uids'] as Map? ?? const {}).entries) {
      c.uids[e.key as String] = e.value as String;
    }
    c.audit.addAll([for (final a in j['audit'] as List) AuditEntry.fromJson(a as List)]);
    c.settings = CasinoSettings.fromJson(j['settings'] as Map<String, dynamic>);
    c.featured = j['featured'] as String? ?? 'classic777';
    for (final e in (j['seen'] as Map? ?? const {}).entries) {
      c.seen[e.key as String] = (e.value as num).toInt();
    }
    c.recompute();
    return c;
  }

  /// Before the database has answered: no players, the games' starting setup.
  factory Casino.empty() => Casino._()..configs.addAll(_startingGames());

  /// How the games start out (until staff change them).
  static Map<String, GameConfig> _startingGames() => {
        'classic777': GameConfig(id: 'classic777', weights: SlotMath.solve(.95), badge: 'HOT'),
        'fruitspin': GameConfig(id: 'fruitspin', weights: SlotMath.solve(.94)),
        'blackjack': GameConfig(id: 'blackjack', badge: 'NEW'),
        'roulette': GameConfig(id: 'roulette', minGc: 100, maxGc: 100000, minSc: .1, maxSc: 100),
        'plinko': GameConfig(id: 'plinko', targetRtp: .97, minGc: 100, maxGc: 50000, minSc: .1, maxSc: 50),
        'megareels': GameConfig(id: 'megareels', targetRtp: .955),
      };

  /// A month of believable history: 24 players given coins, playing and
  /// having coins taken off, so every screen and report has something to show.
  factory Casino.demo({DateTime? now, DateTime Function()? clock}) {
    final at = now ?? clock?.call() ?? DateTime.now();
    final c = Casino._(clock: clock ?? (now == null ? null : () => now)).._batch = true;
    final r = Random(7);
    c.staff.addAll([
      Staff('owner', 'Owner', StaffRole.owner, username: 'owner'),
      Staff('maya', 'Maya', StaffRole.manager, username: 'maya'),
      Staff('leo', 'Leo', StaffRole.cashier, username: 'leo'),
    ]);

    c.configs.addAll(_startingGames());

    final today = DateTime(at.year, at.month, at.day);
    DateTime when(int daysAgo) {
      final d = today.subtract(Duration(days: daysAgo));
      // 9am–11pm, never in the future.
      final t = d.add(Duration(minutes: 540 + r.nextInt(840)));
      return t.isAfter(at) ? at.subtract(Duration(minutes: 1 + r.nextInt(50))) : t;
    }

    const names = [
      ('luckylina', 'Lina Park'), ('spinking', 'Marcus Hill'), ('rubyrose', 'Rose Alvarez'), ('goldrush77', 'Dev Patel'),
      ('acehigh', 'Andre Cole'), ('neonfox', 'Jules Moreau'), ('jackpotjay', 'Jay Brooks'), ('queenofspins', 'Tasha Reid'),
      ('midas', 'Omar Haddad'), ('cherrybomb', 'Kim Nguyen'), ('vegasvic', 'Victor Lane'), ('silverado', 'Sam Ortiz'),
      ('moonshot', 'Priya Shah'), ('tigerluck', 'Leo Tan'), ('diamondd', 'Dana White'), ('royalflush', 'Rui Costa'),
      ('pixelpete', 'Pete Novak'), ('sunnyspins', 'Sunny Bell'), ('kingkong21', 'Kofi Mensah'), ('starla', 'Starla James'),
      ('bigbankbo', 'Bo Fischer'), ('clover', 'Clara Ryan'), ('hotstreak', 'Hugo Silva'),
    ];
    const staffNames = ['Owner', 'Maya', 'Leo'];
    final playable = ['classic777', 'fruitspin', 'blackjack'];

    final created = <String, int>{};
    for (final (i, (u, n)) in names.indexed) {
      final ago = i < 8 ? 40 + r.nextInt(50) : r.nextInt(30);
      final p = Player(
        id: 'Z7-${100100 + i}',
        username: u,
        name: n,
        phone: '(555) ${200 + r.nextInt(700)}-${1000 + r.nextInt(9000)}',
        created: when(ago),
        createdBy: staffNames[r.nextInt(3)],
        startGc: 50000,
        startSc: 2,
      );
      if (i == 9) p.status = PlayerStatus.suspended;
      if (i == 16) p.status = PlayerStatus.banned;
      c.players.add(p);
      created[p.id] = ago;
    }
    final me = Player(
        id: meId, username: 'player123', name: 'Player123', created: when(60), createdBy: 'App', note: 'Plays from this device');
    c.players.add(me);

    // Everyone's history, oldest first, so txn ids run in time order.
    final events = <(DateTime, void Function())>[];
    for (final p in c.players.where((p) => p.id != meId)) {
      events.add((p.created, () => c._post(Txn(id: c._txnId(), playerId: p.id, type: TxnType.start, at: p.created, gc: p.startGc, sc: p.startSc, by: p.createdBy))));
    }
    for (var ago = 29; ago >= 0; ago--) {
      for (final p in c.players) {
        if (p.id == meId || created[p.id]! < ago || p.status == PlayerStatus.banned && ago < 10) continue;
        if (r.nextDouble() > .55) continue;
        final by = staffNames[1 + r.nextInt(2)];
        if (r.nextDouble() < .38) {
          final sc = <double>[10, 20, 25, 50, 50, 100, 200][r.nextInt(7)];
          final t = when(ago);
          events.add((t, () => c._post(Txn(id: c._txnId(), playerId: p.id, type: TxnType.coinIn, at: t, gc: sc * 10000, sc: sc, by: by))));
        }
        for (final g in (playable.toList()..shuffle(r)).take(1 + r.nextInt(2))) {
          final t = when(ago);
          final rounds = 20 + r.nextInt(140);
          final rtp = c.config(g).rtp;
          final betSc = [.2, .5, 1.0, 2.0][r.nextInt(4)];
          final betGc = <double>[1000, 2500, 5000, 10000][r.nextInt(4)];
          final luckSc = .55 + r.nextDouble() * .9, luckGc = .55 + r.nextDouble() * .9;
          events.add((t, () {
            final wSc = min(rounds * betSc, (p.sc * 10).floorToDouble() / 10);
            if (wSc >= 1) {
              final win = (wSc * rtp * luckSc * 100).roundToDouble() / 100;
              c.recordRound(g, p.id, Currency.sc, wSc, win, rounds: rounds, at: t);
              p.sc = _r2(p.sc + win - wSc);
            }
            final wGc = min(rounds * betGc, p.gc);
            if (wGc >= 1000) {
              final win = (wGc * rtp * luckGc).roundToDouble();
              c.recordRound(g, p.id, Currency.gc, wGc, win, rounds: rounds, at: t);
              p.gc += win - wGc;
            }
          }));
        }
        if (r.nextDouble() < .5) {
          final t = when(ago);
          final gc = <double>[1000, 2000, 3000, 5000, 7000, 10000][r.nextInt(6)];
          events.add((t, () => c._post(Txn(id: c._txnId(), playerId: p.id, type: TxnType.bonus, at: t, gc: gc, by: 'System', note: 'Daily bonus'))));
        }
        if (r.nextDouble() < .1) {
          final t = when(ago);
          events.add((t, () {
            if (p.sc < 50) return;
            final sc = (p.sc * (.3 + r.nextDouble() * .4)).floorToDouble();
            c._post(Txn(id: c._txnId(), playerId: p.id, type: TxnType.coinOut, at: t, sc: -sc, by: by));
          }));
        }
      }
    }

    // This device's player: two coin packs, a bonus, and play that ends on
    // the balances the app starts with.
    final meEvents = <Txn>[
      Txn(id: '', playerId: meId, type: TxnType.coinIn, at: when(9), gc: 300000, sc: 25, by: 'Store', note: '300K GC package'),
      Txn(id: '', playerId: meId, type: TxnType.coinIn, at: when(1), gc: 120000, sc: 10, by: 'Store', note: '120K GC package'),
      Txn(id: '', playerId: meId, type: TxnType.bonus, at: when(6), gc: 10000, by: 'System', note: 'Referral bonus'),
    ];
    const startGc = 50000.0, startSc = 100.0;
    final netGc = 125000 - startGc - meEvents.fold<double>(0, (a, t) => a + t.gc);
    final netSc = 250.5 - startSc - meEvents.fold<double>(0, (a, t) => a + t.sc);
    events.add((me.created, () => c._post(Txn(id: c._txnId(), playerId: meId, type: TxnType.start, at: me.created, gc: startGc, sc: startSc, by: 'App'))));
    for (final t in meEvents) {
      events.add((t.at, () => c._post(Txn(id: c._txnId(), playerId: meId, type: t.type, at: t.at, gc: t.gc, sc: t.sc, by: t.by, note: t.note))));
    }
    for (final (i, ago) in const [8, 5, 3, 1, 0].indexed) {
      final t = when(ago);
      final g = playable[i % 3];
      events.add((t, () {
        final ng = netGc / 5, ns = _r2(netSc / 5);
        const wGc = 200000.0, wSc = 60.0;
        c.recordRound(g, meId, Currency.gc, wGc, wGc + ng, rounds: 40, at: t);
        c.recordRound(g, meId, Currency.sc, wSc, _r2(wSc + ns), rounds: 30, at: t);
        me.gc += ng;
        me.sc = _r2(me.sc + ns);
      }));
    }

    events.sort((a, b) => a.$1.compareTo(b.$1));
    for (final e in events) {
      e.$2();
    }
    c.seen[meId] = at.millisecondsSinceEpoch;
    c.txns.sort((a, b) => a.at.compareTo(b.at));

    for (final (ago, by, what) in const [
      (12, 'Owner', 'Classic 777: RTP set to 95.00%'),
      (8, 'Maya', 'Blackjack: added to the lobby'),
      (3, 'Owner', 'Settings: starting amount 50,000 GC + 2 DC'),
    ]) {
      c.audit.add(AuditEntry(when(ago), by, what));
    }
    c.audit.sort((a, b) => a.at.compareTo(b.at));
    c._batch = false;
    c.recompute();
    return c;
  }
}

double _r2(double v) => (v * 100).roundToDouble() / 100;
