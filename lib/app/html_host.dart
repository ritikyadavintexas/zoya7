import 'dart:math';

import '../backoffice/casino.dart';
import '../games/gold/src/math.dart' show Currency;
import '../games/html/model.dart';
import 'state.dart';

/// What the screen should do after a message from the game.
enum HostAction { none, ready, exit, buyCoins }

/// The app's side of the Zoya7 game bridge (assets/sdk/zoya7-bridge.js). The
/// game asks; this answers: the session, and each round, which this draws from
/// the game's pay table at the RTP set in the admin panel, then books (bet
/// taken, win paid) before the game is told what to show.
class HtmlGameHost {
  HtmlGameHost({required this.gameId, required this.app, Random? random, DateTime Function()? clock})
      : _random = random ?? Random.secure(),
        _clock = clock ?? DateTime.now;

  static const version = 1;

  final String gameId;
  final AppState app;
  final Random _random;
  final DateTime Function() _clock;
  int _rounds = 0;
  DateTime? _lastPlay;
  Map<String, double>? _sentBalances;

  GameConfig get _cfg => app.casino.config(gameId);

  static String label(Currency c) => c == Currency.gc ? 'GC' : 'DC';
  static Currency? currency(Object? label) => switch (label) { 'GC' => Currency.gc, 'DC' => Currency.sc, _ => null };

  List<double> bets(Currency c) => c == Currency.gc ? betSteps(_cfg.minGc, _cfg.maxGc) : betSteps(_cfg.minSc, _cfg.maxSc);

  Map<String, double> balances() => {'GC': app.gc, 'DC': app.sc};

  /// Answers one message from the game. Returns the reply to send back (null:
  /// nothing to send) and what the screen should do.
  (Map<String, Object?>?, HostAction) handle(Object? data) {
    if (data is! Map || data['zoya7'] != version) return (null, HostAction.none);
    final id = data['id'];
    final body = data['data'] is Map ? Map<String, Object?>.from(data['data'] as Map) : const <String, Object?>{};
    Map<String, Object?> reply(Map<String, Object?> d) => {'zoya7': version, 're': id, 'data': d};
    Map<String, Object?> error(String code, String message) =>
        {'zoya7': version, 're': id, 'error': {'code': code, 'message': message}};
    switch (data['type']) {
      case 'init':
        final s = session();
        return (s == null ? error('closed', 'This game isn’t available') : reply(s), HostAction.none);
      case 'play':
        final (result, code, message) = play(body);
        return (result != null ? reply(result) : error(code!, message!), HostAction.none);
      case 'ready':
        return (null, HostAction.ready);
      case 'exit':
        return (null, HostAction.exit);
      case 'buy':
        return (null, HostAction.buyCoins);
    }
    return (null, HostAction.none);
  }

  /// What the game gets from Zoya7.init().
  Map<String, Object?>? session() {
    final h = _cfg.html;
    if (h == null) return null;
    final options = <Map<String, Object?>>[];
    for (final o in h.options) {
      final p = chancesFor(o.outcomes, _cfg.targetRtp);
      if (p == null) return null;
      options.add({
        'id': o.id,
        'label': o.label.isEmpty ? o.id : o.label,
        'outcomes': [
          for (final (i, x) in o.outcomes.indexed) {'id': x.id, 'label': x.label.isEmpty ? x.id : x.label, 'multiplier': x.multiplier, 'chance': p[i]},
        ],
      });
    }
    final gc = bets(Currency.gc), dc = bets(Currency.sc);
    _sentBalances = balances();
    return {
      'demo': false,
      'currency': 'GC',
      'balances': _sentBalances,
      'bets': {'GC': gc, 'DC': dc},
      'bet': {'GC': gc.first, 'DC': dc.first},
      'options': options,
      'rtp': _cfg.targetRtp,
      'sound': soundSettings(),
      'player': {'name': app.name},
      'reducedMotion': false,
    };
  }

  Map<String, bool> soundSettings() => {'effects': app.settings['sound'] ?? true, 'music': app.settings['music'] ?? true};

  /// One round: (result, null, null) or (null, error code, message).
  (Map<String, Object?>?, String?, String?) play(Map<String, Object?> req) {
    final cfg = _cfg;
    final h = cfg.html;
    if (h == null || cfg.status != GameStatus.live || app.casino.settings.maintenance) {
      return (null, 'closed', 'The game is closed for now');
    }
    if (app.player == null) return (null, 'signedout', 'Sign in to play');
    final now = _clock();
    if (_lastPlay != null && now.difference(_lastPlay!) < const Duration(milliseconds: 250)) {
      return (null, 'busy', 'One round at a time');
    }
    final option = h.options.where((o) => o.id == (req['option'] ?? h.options.first.id)).firstOrNull;
    if (option == null) return (null, 'option', 'No bet option "${req['option']}"');
    final c = currency(req['currency']);
    if (c == null) return (null, 'currency', 'Currency is GC or DC');
    final bet = (req['bet'] as num?)?.toDouble();
    if (bet == null || !bets(c).any((b) => (b - bet).abs() < 1e-9)) return (null, 'bet', 'Pick one of the bets offered');
    if ((c == Currency.gc ? app.gc : app.sc) < bet - 1e-9) return (null, 'balance', 'Not enough ${label(c)}');
    final chances = chancesFor(option.outcomes, cfg.targetRtp);
    if (chances == null) return (null, 'closed', 'The game is closed for now');

    final pick = option.outcomes[drawOutcome(chances, _random)];
    final raw = bet * pick.multiplier;
    final win = c == Currency.gc ? raw.roundToDouble() : (raw * 100).roundToDouble() / 100;
    app.recordRound(gameId, c, bet, win);
    _lastPlay = now;
    _sentBalances = balances();
    return (
      {
        'round': '${now.millisecondsSinceEpoch}-${++_rounds}',
        'option': option.id,
        'outcome': pick.id,
        'label': pick.label.isEmpty ? pick.id : pick.label,
        'multiplier': pick.multiplier,
        'currency': label(c),
        'bet': bet,
        'win': win,
        'balances': _sentBalances,
      },
      null,
      null
    );
  }

  /// A 'balance' event when the coins changed outside the game (a coin in, say).
  Map<String, Object?>? balanceEvent() {
    final b = balances();
    if (_sentBalances == null) return null; // the game hasn't started yet
    if (b['GC'] == _sentBalances!['GC'] && b['DC'] == _sentBalances!['DC']) return null;
    _sentBalances = b;
    return event('balance', b);
  }

  static Map<String, Object?> event(String name, [Map<String, Object?> data = const {}]) =>
      {'zoya7': version, 'event': name, 'data': data};
}
