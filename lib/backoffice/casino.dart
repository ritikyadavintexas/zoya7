import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../app/assets.dart' show games;
import '../games/blackjack/engine.dart' show BjRules;
import '../games/gold/src/math.dart';
import 'slot_math.dart';
import 'storage.dart';

/// The casino's back office: player accounts, the cash ledger, each game's
/// settings and math, and the play records the reports are built from.
///
/// The player app and the admin panel share one [Casino]. Without a server
/// it lives on the device (the browser's storage on the web); swap
/// [loadSaved]/[save] for API calls to run it for real.

enum PlayerStatus { active, suspended, banned }

enum TxnType { start, cashIn, cashOut, bonus, adjust }

enum TxnStatus { pending, approved, rejected }

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
      TxnType.cashIn => 'Cash in',
      TxnType.cashOut => 'Cash out',
      TxnType.bonus => 'Bonus',
      TxnType.adjust => 'Adjustment',
      _ => '${e.name[0].toUpperCase()}${e.name.substring(1)}',
    };

class Player {
  Player({
    required this.id,
    required this.username,
    required this.password,
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
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? created;

  final String id;
  String username;
  String password;
  String name;
  String phone;
  String email;
  String note;
  PlayerStatus status;
  double gc;
  double sc;

  /// Credited when the account was made.
  double startGc;
  double startSc;
  final DateTime created;
  final String createdBy;
  DateTime lastSeen;

  Map<String, Object> toJson() => {
        'id': id,
        'u': username,
        'pw': password,
        'n': name,
        'ph': phone,
        'em': email,
        'no': note,
        'st': status.index,
        'gc': gc,
        'sc': sc,
        'sgc': startGc,
        'ssc': startSc,
        'c': created.millisecondsSinceEpoch,
        'by': createdBy,
        'ls': lastSeen.millisecondsSinceEpoch,
      };

  static Player fromJson(Map<String, dynamic> j) => Player(
        id: j['id'] as String,
        username: j['u'] as String,
        password: j['pw'] as String,
        name: j['n'] as String,
        phone: j['ph'] as String? ?? '',
        email: j['em'] as String? ?? '',
        note: j['no'] as String? ?? '',
        status: PlayerStatus.values[j['st'] as int],
        gc: (j['gc'] as num).toDouble(),
        sc: (j['sc'] as num).toDouble(),
        startGc: (j['sgc'] as num).toDouble(),
        startSc: (j['ssc'] as num).toDouble(),
        created: DateTime.fromMillisecondsSinceEpoch(j['c'] as int),
        createdBy: j['by'] as String? ?? '',
        lastSeen: DateTime.fromMillisecondsSinceEpoch(j['ls'] as int),
      );
}

/// One line of the cash ledger. [gc]/[sc] are what the player's balance
/// moved by (negative for a cash out); [usd] is the money that changed hands.
class Txn {
  Txn({
    required this.id,
    required this.playerId,
    required this.type,
    required this.at,
    this.usd = 0,
    this.gc = 0,
    this.sc = 0,
    this.method = '',
    this.status = TxnStatus.approved,
    this.by = '',
    this.note = '',
    this.settledBy,
    this.settledAt,
  });

  final String id;
  final String playerId;
  final TxnType type;
  final DateTime at;
  final double usd;
  final double gc;
  final double sc;
  final String method;
  TxnStatus status;
  final String by;
  String note;

  /// Who paid (or turned down) a cash out, and when.
  String? settledBy;
  DateTime? settledAt;

  /// A rejected cash out was refunded, so it moved nothing.
  bool get counts => status != TxnStatus.rejected;

  Map<String, Object> toJson() => {
        'id': id,
        'p': playerId,
        't': type.index,
        'at': at.millisecondsSinceEpoch,
        'usd': usd,
        'gc': gc,
        'sc': sc,
        'm': method,
        's': status.index,
        'by': by,
        'no': note,
        if (settledBy != null) 'sb': settledBy!,
        if (settledAt != null) 'sa': settledAt!.millisecondsSinceEpoch,
      };

  static Txn fromJson(Map<String, dynamic> j) => Txn(
        id: j['id'] as String,
        playerId: j['p'] as String,
        type: TxnType.values[j['t'] as int],
        at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
        usd: (j['usd'] as num).toDouble(),
        gc: (j['gc'] as num).toDouble(),
        sc: (j['sc'] as num).toDouble(),
        method: j['m'] as String? ?? '',
        status: TxnStatus.values[j['s'] as int],
        by: j['by'] as String? ?? '',
        note: j['no'] as String? ?? '',
        settledBy: j['sb'] as String?,
        settledAt: j['sa'] == null ? null : DateTime.fromMillisecondsSinceEpoch(j['sa'] as int),
      );
}

/// A cashier's shift at the drawer: the starting amount they counted in, and
/// what they counted out at the end.
class Shift {
  Shift({required this.id, required this.staff, required this.start, required this.startAmount, this.end, this.counted});
  final String id;
  final String staff;
  final DateTime start;
  final double startAmount;
  DateTime? end;
  double? counted;

  bool get open => end == null;

  Map<String, Object> toJson() => {
        'id': id,
        's': staff,
        'st': start.millisecondsSinceEpoch,
        'a': startAmount,
        if (end != null) 'e': end!.millisecondsSinceEpoch,
        if (counted != null) 'c': counted!,
      };

  static Shift fromJson(Map<String, dynamic> j) => Shift(
        id: j['id'] as String,
        staff: j['s'] as String,
        start: DateTime.fromMillisecondsSinceEpoch(j['st'] as int),
        startAmount: (j['a'] as num).toDouble(),
        end: j['e'] == null ? null : DateTime.fromMillisecondsSinceEpoch(j['e'] as int),
        counted: (j['c'] as num?)?.toDouble(),
      );
}

/// Money a shift handled: everything, and the cash that went through the drawer.
class ShiftSummary {
  ShiftSummary(this.shift);
  final Shift shift;
  double cashIn = 0, cashOut = 0, drawerIn = 0, drawerOut = 0;
  int ins = 0, outs = 0;

  /// What should be in the drawer: starting amount + cash taken − cash paid.
  double get expected => shift.startAmount + drawerIn - drawerOut;
  double? get difference => shift.counted == null ? null : shift.counted! - expected;
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

  double get netGc => winGc - wGc;
  double get netSc => winSc - wSc;

  List<Object> toJson() => [day, gameId, playerId, rounds, wGc, winGc, wSc, winSc];

  static Play fromJson(List<dynamic> j) => Play(j[0] as int, j[1] as String, j[2] as String)
    ..rounds = j[3] as int
    ..wGc = (j[4] as num).toDouble()
    ..winGc = (j[5] as num).toDouble()
    ..wSc = (j[6] as num).toDouble()
    ..winSc = (j[7] as num).toDouble();
}

class Staff {
  Staff(this.name, this.role, this.pin);
  String name;
  StaffRole role;
  String pin;

  bool get canManage => role != StaffRole.cashier;
  bool get isOwner => role == StaffRole.owner;

  Map<String, Object> toJson() => {'n': name, 'r': role.index, 'p': pin};
  static Staff fromJson(Map<String, dynamic> j) => Staff(j['n'] as String, StaffRole.values[j['r'] as int], j['p'] as String);
}

class AuditEntry {
  AuditEntry(this.at, this.by, this.action);
  final DateTime at;
  final String by;
  final String action;

  List<Object> toJson() => [at.millisecondsSinceEpoch, by, action];
  static AuditEntry fromJson(List<dynamic> j) =>
      AuditEntry(DateTime.fromMillisecondsSinceEpoch(j[0] as int), j[1] as String, j[2] as String);
}

class CasinoSettings {
  /// Starting amount every new player ID gets.
  double newPlayerGc = 50000;
  double newPlayerSc = 2;

  /// What $1 of cash in buys.
  double gcPerDollar = 10000;
  double scPerDollar = 1;

  /// Extra on every cash in (percent).
  double cashInBonusPct = 0;

  /// $ value of 1 SC at cash out.
  double usdPerSc = 1;
  double minCashOut = 50;
  double maxCashInPerDay = 1000;
  double maxCashOutPerDay = 2000;

  /// Cash outs up to this many SC are approved without review (0 = review all).
  double autoApproveUnder = 0;

  bool registrationOpen = true;
  bool dailyBonus = true;

  /// Every game closed to players, with [maintenanceMessage].
  bool maintenance = false;
  String maintenanceMessage = 'We’re upgrading the games. Back soon!';

  Map<String, Object> toJson() => {
        'ngc': newPlayerGc,
        'nsc': newPlayerSc,
        'gpd': gcPerDollar,
        'spd': scPerDollar,
        'bon': cashInBonusPct,
        'ups': usdPerSc,
        'mco': minCashOut,
        'mci': maxCashInPerDay,
        'mcd': maxCashOutPerDay,
        'aau': autoApproveUnder,
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
      ..gcPerDollar = d('gpd', s.gcPerDollar)
      ..scPerDollar = d('spd', s.scPerDollar)
      ..cashInBonusPct = d('bon', s.cashInBonusPct)
      ..usdPerSc = d('ups', s.usdPerSc)
      ..minCashOut = d('mco', s.minCashOut)
      ..maxCashInPerDay = d('mci', s.maxCashInPerDay)
      ..maxCashOutPerDay = d('mcd', s.maxCashOutPerDay)
      ..autoApproveUnder = d('aau', s.autoApproveUnder)
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

/// Money and coins for one span: the starting amount, what came in and went
/// out, and what's left — per game and per player.
class Report {
  Report(this.period);
  final Period period;

  /// Players' balances when the period started / ended.
  double openGc = 0, openSc = 0, closeGc = 0, closeSc = 0;

  double cashInUsd = 0, cashInGc = 0, cashInSc = 0;
  int cashIns = 0;
  double cashOutUsd = 0, cashOutSc = 0;
  int cashOuts = 0;
  double pendingUsd = 0;
  int pending = 0;
  double startGc = 0, startSc = 0, bonusGc = 0, bonusSc = 0, adjustGc = 0, adjustSc = 0;
  int newPlayers = 0;
  final active = <String>{};

  final games = <String, GameReport>{};
  final players = <String, PlayerReport>{};

  double get netCash => cashInUsd - cashOutUsd;
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

  /// What the game actually paid back (SC play, else GC).
  double? get actualRtp => wSc > 0 ? winSc / wSc : (wGc > 0 ? winGc / wGc : null);
}

class PlayerReport {
  PlayerReport(this.playerId);
  final String playerId;
  double openSc = 0, closeSc = 0, openGc = 0, closeGc = 0;
  double cashInUsd = 0, cashOutUsd = 0, wSc = 0, winSc = 0;
  double get netCash => cashInUsd - cashOutUsd;
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
  Casino._({this.persist = false, DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  static const storageKey = 'zoya7.backoffice.v1';

  /// The demo player the app on this device plays as.
  static const meId = 'Z7-100123';

  /// Save every change to this device's storage.
  final bool persist;
  final DateTime Function() clock;

  final players = <Player>[];
  final txns = <Txn>[];
  final configs = <String, GameConfig>{};
  final plays = <String, Play>{};
  final staff = <Staff>[];
  final audit = <AuditEntry>[];
  final shifts = <Shift>[];
  var settings = CasinoSettings();
  String featured = 'classic777';
  int _nextPlayer = 100124;
  int _nextTxn = 1;

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

  Player get me => player(meId)!;

  GameConfig config(String gameId) => configs.putIfAbsent(gameId, () => GameConfig(id: gameId));

  GameStatus statusOf(String gameId) => config(gameId).status;

  /// Can a player open this game right now?
  bool isOpen(String gameId) => !settings.maintenance && statusOf(gameId) == GameStatus.live;

  List<Txn> txnsOf(String playerId) => [
        for (final t in txns.reversed)
          if (t.playerId == playerId) t,
      ];

  List<Txn> get pendingCashOuts => [
        for (final t in txns.reversed)
          if (t.type == TxnType.cashOut && t.status == TxnStatus.pending) t,
      ];

  bool usernameTaken(String u, {String? except}) =>
      players.any((p) => p.id != except && p.username.toLowerCase() == u.trim().toLowerCase());

  int get online => players.where((p) => now.difference(p.lastSeen).inMinutes < 15).length;

  /// Lifetime cash in of a player ($).
  double cashInTotal(String playerId) => txns
      .where((t) => t.playerId == playerId && t.type == TxnType.cashIn)
      .fold(0, (a, t) => a + t.usd);

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
    String? password,
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
      id: 'Z7-${_nextPlayer++}',
      username: u,
      password: (password == null || password.isEmpty) ? newPassword() : password,
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
    if (count < 1 || count > 500) throw CasinoError('Make between 1 and 500 at a time');
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
      p.username = username.trim();
    }
    if (name != null) p.name = name.trim();
    if (phone != null) p.phone = phone.trim();
    if (email != null) p.email = email.trim();
    if (note != null) p.note = note.trim();
    _log('Edited player ${p.username}');
    _changed();
  }

  String resetPassword(Player p) {
    p.password = newPassword();
    _log('Reset password of ${p.username}');
    _changed();
    return p.password;
  }

  void setPlayerStatus(Player p, PlayerStatus s) {
    p.status = s;
    _log('${statusName(s)} ${p.username}');
    _changed();
  }

  void deletePlayer(Player p) {
    if (p.id == meId) throw CasinoError('The demo player can’t be deleted');
    players.remove(p);
    _log('Deleted player ${p.username} (${p.id})');
    _changed();
  }

  // ── Cash ───────────────────────────────────────────────────────────────────
  double _todayUsd(Player p, TxnType type) {
    final d = dayOf(now);
    return txns
        .where((t) => t.playerId == p.id && t.type == type && t.counts && dayOf(t.at) == d)
        .fold(0, (a, t) => a + t.usd);
  }

  /// Coins [usd] buys at the current rates and cash-in bonus.
  ({double gc, double sc}) coinsFor(double usd, {double? bonusPct}) {
    final k = 1 + (bonusPct ?? settings.cashInBonusPct) / 100;
    return (gc: (usd * settings.gcPerDollar * k).roundToDouble(), sc: _r2(usd * settings.scPerDollar * k));
  }

  /// Load a player's account: they paid [usd]; coins go on their balance.
  Txn cashIn(Player p, double usd, {String method = 'Cash App', double? bonusPct, String note = '', bool checkLimit = true}) {
    if (usd <= 0) throw CasinoError('Enter an amount');
    if (p.status != PlayerStatus.active) throw CasinoError('${p.username} is ${p.status.name}');
    if (checkLimit && _todayUsd(p, TxnType.cashIn) + usd > settings.maxCashInPerDay) {
      throw CasinoError('Over the daily cash-in limit of \$${settings.maxCashInPerDay.toStringAsFixed(0)}');
    }
    final c = coinsFor(usd, bonusPct: bonusPct);
    final t = _post(Txn(
        id: _txnId(), playerId: p.id, type: TxnType.cashIn, at: now, usd: usd, gc: c.gc, sc: c.sc, method: method, by: actor, note: note));
    _log('Cash in \$${usd.toStringAsFixed(2)} → ${p.username}');
    _changed();
    return t;
  }

  /// A coin package bought in the app's store.
  Txn purchase(Player p, double usd, {required double gc, required double sc, String note = ''}) {
    final t = _post(Txn(
        id: _txnId(), playerId: p.id, type: TxnType.cashIn, at: now, usd: usd, gc: gc, sc: sc, method: 'Card', by: 'Store', note: note));
    _changed();
    return t;
  }

  /// Pay a player out: [sc] comes off their balance now; the money is paid
  /// when the cash out is approved ([review] = false approves at once).
  Txn cashOut(Player p, double sc, {String method = 'Cash App', bool review = true, String note = ''}) {
    if (sc <= 0) throw CasinoError('Enter an amount');
    if (sc > p.sc + 1e-9) throw CasinoError('${p.username} has only ${_r2(p.sc).toStringAsFixed(2)} SC');
    if (review && sc < settings.minCashOut) {
      throw CasinoError('Minimum cash out is ${settings.minCashOut.toStringAsFixed(0)} SC');
    }
    final usd = _r2(sc * settings.usdPerSc);
    if (_todayUsd(p, TxnType.cashOut) + usd > settings.maxCashOutPerDay) {
      throw CasinoError('Over the daily cash-out limit of \$${settings.maxCashOutPerDay.toStringAsFixed(0)}');
    }
    final auto = !review || (settings.autoApproveUnder > 0 && sc <= settings.autoApproveUnder);
    final t = _post(Txn(
      id: _txnId(),
      playerId: p.id,
      type: TxnType.cashOut,
      at: now,
      usd: usd,
      sc: -sc,
      method: method,
      status: auto ? TxnStatus.approved : TxnStatus.pending,
      by: review ? (admin == null ? 'Player' : actor) : actor,
      note: note,
      settledBy: auto ? actor : null,
      settledAt: auto ? now : null,
    ));
    _log('Cash out ${sc.toStringAsFixed(2)} SC ← ${p.username}${auto ? '' : ' (pending)'}');
    _changed();
    return t;
  }

  void approve(Txn t) {
    if (t.status != TxnStatus.pending) return;
    t
      ..status = TxnStatus.approved
      ..settledBy = actor
      ..settledAt = now;
    _log('Approved cash out ${t.id} (\$${t.usd.toStringAsFixed(2)})');
    _changed();
  }

  /// Turn a cash out down and give the SC back.
  void reject(Txn t, {String reason = ''}) {
    if (t.status != TxnStatus.pending) return;
    t
      ..status = TxnStatus.rejected
      ..settledBy = actor
      ..settledAt = now;
    if (reason.isNotEmpty) t.note = reason;
    final p = player(t.playerId);
    if (p != null) {
      p.gc -= t.gc;
      p.sc = _r2(p.sc - t.sc);
    }
    _log('Rejected cash out ${t.id}${reason.isEmpty ? '' : ': $reason'}');
    _changed();
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
    final pl = player(playerId);
    if (pl != null && when.isAfter(pl.lastSeen)) pl.lastSeen = when;
    _changed(notify: at == null);
  }

  // ── Settings & staff ───────────────────────────────────────────────────────
  void updateSettings(String what, void Function(CasinoSettings s) change) {
    change(settings);
    _log('Settings: $what');
    _changed();
  }

  Staff? signIn(String pin) {
    for (final s in staff) {
      if (s.pin == pin) {
        admin = s;
        _log('Signed in');
        _changed();
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

  void addStaff(String name, StaffRole role, String pin) {
    if (name.trim().isEmpty) throw CasinoError('Enter a name');
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) throw CasinoError('PIN is 4 digits');
    if (staff.any((s) => s.pin == pin)) throw CasinoError('That PIN is in use');
    staff.add(Staff(name.trim(), role, pin));
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

  /// Start over with the demo data (and clear this device's saved copy).
  void resetDemo() {
    final fresh = Casino.demo(now: now);
    _adopt(fresh);
    _log('Reset to demo data');
    _changed();
  }

  // ── Drawer shifts ──────────────────────────────────────────────────────────
  Shift? get myShift => shifts.where((s) => s.open && s.staff == actor).firstOrNull;

  Shift startShift(double startAmount) {
    if (admin == null) throw CasinoError('Sign in first');
    if (myShift != null) throw CasinoError('Your shift is already open');
    if (startAmount < 0) throw CasinoError('Enter the starting amount');
    final s = Shift(id: 'S${shifts.length + 1}', staff: actor, start: now, startAmount: startAmount);
    shifts.add(s);
    _log('Started shift with \$${startAmount.toStringAsFixed(2)} in the drawer');
    _changed();
    return s;
  }

  void closeShift(Shift s, double counted) {
    if (!s.open) return;
    s
      ..end = now
      ..counted = counted;
    final d = summary(s).difference!;
    _log('Closed shift: counted \$${counted.toStringAsFixed(2)}'
        '${d.abs() < .005 ? ', balanced' : ', ${d > 0 ? 'over' : 'short'} \$${d.abs().toStringAsFixed(2)}'}');
    _changed();
  }

  ShiftSummary summary(Shift s) {
    final r = ShiftSummary(s);
    final end = s.end ?? now;
    bool inShift(DateTime? t) => t != null && !t.isBefore(s.start) && !t.isAfter(end);
    for (final t in txns) {
      if (t.type == TxnType.cashIn && t.by == s.staff && inShift(t.at)) {
        r.ins++;
        r.cashIn += t.usd;
        if (t.method == 'Cash') r.drawerIn += t.usd;
      } else if (t.type == TxnType.cashOut && t.status == TxnStatus.approved && t.settledBy == s.staff && inShift(t.settledAt)) {
        r.outs++;
        r.cashOut += t.usd;
        if (t.method == 'Cash') r.drawerOut += t.usd;
      }
    }
    return r;
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
      if (pr == null || !t.counts) continue;
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
        case TxnType.cashIn:
          r.cashIns++;
          r.cashInUsd += t.usd;
          r.cashInGc += t.gc;
          r.cashInSc += t.sc;
          pr?.cashInUsd += t.usd;
        case TxnType.cashOut:
          if (t.status == TxnStatus.approved) {
            r.cashOuts++;
            r.cashOutUsd += t.usd;
            pr?.cashOutUsd += t.usd;
          } else if (t.status == TxnStatus.pending) {
            r.pending++;
            r.pendingUsd += t.usd;
          }
          if (t.counts) r.cashOutSc -= t.sc;
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

  /// Cash in and out per day for the last [days] days (oldest first).
  List<({DateTime day, double cashIn, double cashOut})> daily(int days) {
    final today = dayOf(now);
    final cin = List<double>.filled(days, 0), cout = List<double>.filled(days, 0);
    for (final t in txns) {
      final i = days - 1 - (today - dayOf(t.at));
      if (i < 0 || i >= days) continue;
      if (t.type == TxnType.cashIn) cin[i] += t.usd;
      if (t.type == TxnType.cashOut && t.status == TxnStatus.approved) cout[i] += t.usd;
    }
    return [
      for (var i = 0; i < days; i++) (day: dayStart(today - days + 1 + i), cashIn: cin[i], cashOut: cout[i]),
    ];
  }

  /// One report as CSV (summary, then games, then players).
  String reportCsv(Report r) {
    String f(double v) => v.toStringAsFixed(2);
    final b = StringBuffer()
      ..writeln('Zoya7 report,${r.period.label},${r.period.from.toIso8601String().substring(0, 10)},'
          '${r.period.to.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10)}')
      ..writeln('Starting amount SC,${f(r.openSc)}')
      ..writeln('Starting amount GC,${f(r.openGc)}')
      ..writeln('Cash in USD,${f(r.cashInUsd)}')
      ..writeln('Cash ins,${r.cashIns}')
      ..writeln('Cash out USD,${f(r.cashOutUsd)}')
      ..writeln('Cash outs,${r.cashOuts}')
      ..writeln('Pending cash out USD,${f(r.pendingUsd)}')
      ..writeln('Net cash USD,${f(r.netCash)}')
      ..writeln('Bonus SC,${f(r.bonusSc)}')
      ..writeln('Wagered SC,${f(r.wageredSc)}')
      ..writeln('Won SC,${f(r.wonSc)}')
      ..writeln('Hold SC,${f(r.ggrSc)}')
      ..writeln('Ending amount SC,${f(r.closeSc)}')
      ..writeln('Ending amount GC,${f(r.closeGc)}')
      ..writeln()
      ..writeln('Game,Status,Rounds,Players,Wagered SC,Won SC,Hold SC,Wagered GC,Won GC,Actual RTP,Theoretical RTP');
    for (final g in games) {
      final gr = r.games[g.id] ?? GameReport(g.id);
      final c = config(g.id);
      b.writeln('${g.name},${statusName(c.status)},${gr.rounds},${gr.players.length},${f(gr.wSc)},${f(gr.winSc)},'
          '${f(gr.ggrSc)},${f(gr.wGc)},${f(gr.winGc)},'
          '${gr.actualRtp == null ? '' : (gr.actualRtp! * 100).toStringAsFixed(2)},${(c.rtp * 100).toStringAsFixed(2)}');
    }
    b
      ..writeln()
      ..writeln('Player ID,Username,Starting SC,Cash in USD,Cash out USD,Net USD,Wagered SC,Won SC,Ending SC');
    for (final p in players) {
      final pr = r.players[p.id]!;
      b.writeln('${p.id},${p.username},${f(pr.openSc)},${f(pr.cashInUsd)},${f(pr.cashOutUsd)},${f(pr.netCash)},'
          '${f(pr.wSc)},${f(pr.winSc)},${f(pr.closeSc)}');
    }
    return b.toString();
  }

  // ── Internals ──────────────────────────────────────────────────────────────
  String _txnId() => 'T${(_nextTxn++).toString().padLeft(6, '0')}';

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

  /// Coins moved by play in the player app (balance only; the round itself
  /// goes through [recordRound]).
  void moveMine({double gc = 0, double sc = 0}) {
    me.gc += gc;
    me.sc = _r2(me.sc + sc);
    me.lastSeen = now;
    _changed();
  }

  void _changed({bool notify = true}) {
    if (persist) save(storageKey, jsonEncode(toJson()));
    if (notify) notifyListeners();
  }

  static String _gameName(String id) => games.firstWhere((g) => g.id == id, orElse: () => games.first).name;

  static String _coins(double gc, double sc) =>
      [if (gc != 0) '${gc.toStringAsFixed(0)} GC', if (sc != 0) '${sc.toStringAsFixed(2)} SC'].join(' + ');

  Map<String, Object> toJson() => {
        'v': 1,
        'players': [for (final p in players) p.toJson()],
        'txns': [for (final t in txns) t.toJson()],
        'games': [for (final c in configs.values) c.toJson()],
        'plays': [for (final p in plays.values) p.toJson()],
        'staff': [for (final s in staff) s.toJson()],
        'audit': [for (final a in audit.length > 500 ? audit.sublist(audit.length - 500) : audit) a.toJson()],
        'shifts': [for (final s in shifts) s.toJson()],
        'settings': settings.toJson(),
        'featured': featured,
        'np': _nextPlayer,
        'nt': _nextTxn,
      };

  static Casino fromJson(Map<String, dynamic> j, {bool persist = false}) {
    final c = Casino._(persist: persist);
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
    c.staff.addAll([for (final s in j['staff'] as List) Staff.fromJson(s as Map<String, dynamic>)]);
    c.audit.addAll([for (final a in j['audit'] as List) AuditEntry.fromJson(a as List)]);
    c.shifts.addAll([for (final s in j['shifts'] as List? ?? const []) Shift.fromJson(s as Map<String, dynamic>)]);
    c.settings = CasinoSettings.fromJson(j['settings'] as Map<String, dynamic>);
    c.featured = j['featured'] as String? ?? 'classic777';
    c._nextPlayer = j['np'] as int;
    c._nextTxn = j['nt'] as int;
    if (c.player(meId) == null) throw const FormatException('no demo player');
    return c;
  }

  void _adopt(Casino o) {
    players
      ..clear()
      ..addAll(o.players);
    txns
      ..clear()
      ..addAll(o.txns);
    configs
      ..clear()
      ..addAll(o.configs);
    plays
      ..clear()
      ..addAll(o.plays);
    final keep = admin;
    staff
      ..clear()
      ..addAll(o.staff);
    audit
      ..clear()
      ..addAll(o.audit);
    shifts
      ..clear()
      ..addAll(o.shifts);
    settings = o.settings;
    featured = o.featured;
    _nextPlayer = o._nextPlayer;
    _nextTxn = o._nextTxn;
    admin = keep == null ? null : staff.where((s) => s.pin == keep.pin).firstOrNull ?? staff.first;
  }

  /// This device's saved back office, or fresh demo data.
  static Casino load() {
    final saved = loadSaved(storageKey);
    if (saved != null) {
      try {
        return fromJson(jsonDecode(saved) as Map<String, dynamic>, persist: true);
      } catch (_) {
        clearSaved(storageKey);
      }
    }
    final c = Casino.demo();
    final p = Casino._(persist: true).._adopt(c);
    return p;
  }

  /// A month of believable history: 24 players cashing in, playing and
  /// cashing out, so every screen and report has something to show.
  factory Casino.demo({DateTime? now, DateTime Function()? clock}) {
    final at = now ?? clock?.call() ?? DateTime.now();
    final c = Casino._(clock: clock ?? (now == null ? null : () => now));
    final r = Random(7);
    c.staff.addAll([Staff('Owner', StaffRole.owner, '1234'), Staff('Maya', StaffRole.manager, '2580'), Staff('Leo', StaffRole.cashier, '1111')]);

    c.configs.addAll({
      'classic777': GameConfig(id: 'classic777', weights: SlotMath.solve(.95), badge: 'HOT'),
      'fruitspin': GameConfig(id: 'fruitspin', weights: SlotMath.solve(.94)),
      'blackjack': GameConfig(id: 'blackjack', badge: 'NEW'),
      'roulette': GameConfig(id: 'roulette', minGc: 100, maxGc: 100000, minSc: .1, maxSc: 100),
      'plinko': GameConfig(id: 'plinko', targetRtp: .97, minGc: 100, maxGc: 50000, minSc: .1, maxSc: 50),
      'megareels': GameConfig(id: 'megareels', targetRtp: .955),
    });

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
    const methods = ['Cash App', 'Cash App', 'Cash App', 'Card', 'Cash', 'Bank'];
    final playable = ['classic777', 'fruitspin', 'blackjack'];

    final created = <String, int>{};
    for (final (i, (u, n)) in names.indexed) {
      final ago = i < 8 ? 40 + r.nextInt(50) : r.nextInt(30);
      final p = Player(
        id: 'Z7-${100100 + i}',
        username: u,
        password: c.newPassword(r),
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
        id: meId, username: 'player123', password: 'zoya7demo', name: 'Player123', created: when(60), createdBy: 'App', note: 'Plays from this device');
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
          final usd = <double>[10, 20, 25, 50, 50, 100, 200][r.nextInt(7)];
          final t = when(ago);
          final m = methods[r.nextInt(methods.length)];
          events.add((t, () {
            final k = c.coinsFor(usd);
            c._post(Txn(id: c._txnId(), playerId: p.id, type: TxnType.cashIn, at: t, usd: usd, gc: k.gc, sc: k.sc, method: m, by: by));
          }));
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
        if (r.nextDouble() < .16) {
          final t = when(ago);
          final m = methods[r.nextInt(methods.length)];
          final roll = r.nextDouble();
          events.add((t, () {
            if (p.sc < 50) return;
            final sc = (p.sc * (.5 + r.nextDouble() * .4)).floorToDouble();
            final status = ago <= 1 ? TxnStatus.pending : (roll < .06 ? TxnStatus.rejected : TxnStatus.approved);
            c._post(Txn(
                id: c._txnId(), playerId: p.id, type: TxnType.cashOut, at: t, usd: sc, sc: -sc, method: m, status: TxnStatus.approved, by: status == TxnStatus.pending ? 'Player' : by));
            c.txns.last
              ..settledBy = status == TxnStatus.pending ? null : by
              ..settledAt = status == TxnStatus.pending ? null : t.add(Duration(minutes: 5 + r.nextInt(90)));
            if (status != TxnStatus.approved) {
              c.txns.last.status = status;
              if (status == TxnStatus.rejected) {
                p.sc = _r2(p.sc + sc);
                c.txns.last.note = 'Details didn’t match';
              }
            }
          }));
        }
      }
    }

    // This device's player: two coin packs, bonuses, a pending redemption,
    // and play that ends on the balances the app starts with.
    final meEvents = <Txn>[
      Txn(id: '', playerId: meId, type: TxnType.cashIn, at: when(9), usd: 24.99, gc: 300000, sc: 25, method: 'Card', by: 'Store', note: '300K GC package'),
      Txn(id: '', playerId: meId, type: TxnType.cashIn, at: when(1), usd: 9.99, gc: 120000, sc: 10, method: 'Card', by: 'Store', note: '120K GC package'),
      Txn(id: '', playerId: meId, type: TxnType.bonus, at: when(6), gc: 10000, by: 'System', note: 'Referral bonus'),
      Txn(id: '', playerId: meId, type: TxnType.cashOut, at: when(4), usd: 50, sc: -50, method: 'Bank', status: TxnStatus.pending, by: 'Player'),
    ];
    const startGc = 50000.0, startSc = 100.0;
    final netGc = 125000 - startGc - meEvents.fold<double>(0, (a, t) => a + t.gc);
    final netSc = 250.5 - startSc - meEvents.fold<double>(0, (a, t) => a + t.sc);
    events.add((me.created, () => c._post(Txn(id: c._txnId(), playerId: meId, type: TxnType.start, at: me.created, gc: startGc, sc: startSc, by: 'App'))));
    for (final t in meEvents) {
      events.add((t.at, () => c._post(Txn(id: c._txnId(), playerId: meId, type: t.type, at: t.at, usd: t.usd, gc: t.gc, sc: t.sc, method: t.method, status: t.status, by: t.by, note: t.note))));
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
    // Rounding in the split above: land exactly on the app's balances.
    me.gc = 125000;
    me.sc = 250.5;
    me.lastSeen = at;
    c.txns.sort((a, b) => a.at.compareTo(b.at));

    for (final (ago, by, what) in const [
      (12, 'Owner', 'Classic 777: RTP set to 95.00%'),
      (8, 'Maya', 'Blackjack: added to the lobby'),
      (3, 'Owner', 'Settings: starting amount 50,000 GC + 2 SC'),
    ]) {
      c.audit.add(AuditEntry(when(ago), by, what));
    }
    // Yesterday's closed shifts at the drawer.
    final y = today.subtract(const Duration(days: 1));
    for (final (i, (who, startH, endH, float)) in const [('Leo', 9, 17, 200.0), ('Maya', 17, 23, 300.0)].indexed) {
      final sh = Shift(id: 'S${i + 1}', staff: who, start: y.add(Duration(hours: startH)), startAmount: float, end: y.add(Duration(hours: endH)));
      c.shifts.add(sh);
      final sum = c.summary(sh);
      sh.counted = i == 0 ? sum.expected : sum.expected - 5;
    }
    c.audit.sort((a, b) => a.at.compareTo(b.at));
    return c;
  }
}

double _r2(double v) => (v * 100).roundToDouble() / 100;
