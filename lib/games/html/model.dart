/// Games made outside the app (HTML5 canvas games, docs/GAME_PROMPT.md),
/// uploaded from the admin panel and played in a frame. The app draws every
/// result from the game's pay table; the game only shows it.
library;

import 'dart:math';

/// One way a round can end, and what it pays (× the bet; 0 = no win).
class Outcome {
  const Outcome({required this.id, this.label = '', required this.multiplier, this.share = 1});

  final String id;
  final String label;
  final double multiplier;

  /// This win's part of the payback, relative to the game's other wins
  /// (all 1 = every win pays back the same share). Ignored for no-win outcomes.
  final double share;

  bool get wins => multiplier > 0;

  Map<String, Object> toJson() => {'id': id, 'l': label, 'x': multiplier, if (share != 1) 's': share};

  static Outcome fromJson(Map<String, dynamic> j) => Outcome(
        id: j['id'] as String,
        label: j['l'] as String? ?? '',
        multiplier: (j['x'] as num).toDouble(),
        share: (j['s'] as num?)?.toDouble() ?? 1,
      );
}

/// A kind of bet the game offers (most have one: "main"), with its own pay table.
class BetOption {
  const BetOption({required this.id, this.label = '', required this.outcomes});
  final String id;
  final String label;
  final List<Outcome> outcomes;

  Map<String, Object> toJson() => {'id': id, 'l': label, 'o': [for (final o in outcomes) o.toJson()]};

  static BetOption fromJson(Map<String, dynamic> j) => BetOption(
        id: j['id'] as String,
        label: j['l'] as String? ?? '',
        outcomes: [for (final o in j['o'] as List) Outcome.fromJson(Map<String, dynamic>.from(o as Map))],
      );
}

/// The chances that make a pay table pay back exactly [rtp] of what's bet.
///
/// The rule, the same for every game: each win gets its share of the payback
/// (equal unless the game asks otherwise), so a 30× win comes 15 times less
/// often than a 2× win; whatever chance is left is a no-win, split evenly
/// between the no-win outcomes. Returns null when the wins can't pay back that
/// much (they'd have to come more than [maxHitRate] of the time).
List<double>? chancesFor(List<Outcome> outcomes, double rtp, {double maxHitRate = .95}) {
  final wins = outcomes.where((o) => o.wins).toList();
  final losses = outcomes.where((o) => !o.wins).length;
  if (wins.isEmpty || losses == 0) return null;
  final shares = wins.fold<double>(0, (a, o) => a + o.share);
  final p = [for (final o in outcomes) o.wins ? rtp * (o.share / shares) / o.multiplier : 0.0];
  final hit = p.fold<double>(0, (a, x) => a + x);
  if (hit > maxHitRate) return null;
  for (var i = 0; i < outcomes.length; i++) {
    if (!outcomes[i].wins) p[i] = (1 - hit) / losses;
  }
  return p;
}

/// Picks an outcome with [chances] (which add up to 1).
int drawOutcome(List<double> chances, Random random) {
  var r = random.nextDouble();
  for (var i = 0; i < chances.length; i++) {
    r -= chances[i];
    if (r < 0) return i;
  }
  return chances.lastIndexWhere((c) => c > 0);
}

/// Bet steps from [min] to [max]: 1, 2 and 5 of each power of ten, plus the limits.
List<double> betSteps(double min, double max) {
  final steps = <double>{min};
  for (var e = -2; e <= 7; e++) {
    for (final m in const [1, 2, 5]) {
      final v = double.parse((m * pow(10, e)).toStringAsFixed(2));
      if (v > min && v < max) steps.add(v);
    }
  }
  steps.add(max);
  return steps.toList()..sort();
}

/// What the back office keeps about an uploaded game.
class HtmlGame {
  HtmlGame({
    required this.name,
    this.cat = 'INSTANT',
    this.blurb = '',
    this.credits = '',
    required this.version,
    required this.options,
    this.live = false,
    this.uploaded = 0,
  });

  final String name;

  /// Lobby filter: SLOTS, TABLE or INSTANT.
  final String cat;
  final String blurb;
  final String credits;

  /// Each upload is a new version in its own folder (web/games/<id>/<version>/).
  final int version;
  final List<BetOption> options;

  /// Published and reachable (the site has been rebuilt with it).
  bool live;

  /// When it was uploaded (ms since 1970).
  final int uploaded;

  /// The game's folder on the site, relative to the site's root.
  String folder(String id) => 'games/$id/$version';

  Map<String, Object> toJson() => {
        'n': name,
        'c': cat,
        if (blurb.isNotEmpty) 'b': blurb,
        if (credits.isNotEmpty) 'cr': credits,
        'v': version,
        'op': [for (final o in options) o.toJson()],
        'live': live,
        'up': uploaded,
      };

  static HtmlGame fromJson(Map<String, dynamic> j) => HtmlGame(
        name: j['n'] as String,
        cat: j['c'] as String? ?? 'INSTANT',
        blurb: j['b'] as String? ?? '',
        credits: j['cr'] as String? ?? '',
        version: (j['v'] as num).toInt(),
        options: [for (final o in j['op'] as List) BetOption.fromJson(Map<String, dynamic>.from(o as Map))],
        live: j['live'] as bool? ?? false,
        uploaded: (j['up'] as num?)?.toInt() ?? 0,
      );
}
