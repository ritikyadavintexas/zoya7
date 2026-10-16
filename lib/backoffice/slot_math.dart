import 'dart:math';

import '../games/gold/src/math.dart';

/// Exact math of the Gold slot's reels: three independent reels with the same
/// symbol weights, paid on the middle line ([GoldRules.evaluate]).
class SlotMath {
  SlotMath(this.weights) : _total = weights.values.fold(0.0, (a, b) => a + b);

  final Map<Sym, double> weights;
  final double _total;

  double p(Sym s) => _total <= 0 ? 0 : (weights[s] ?? 0) / _total;

  /// Return to player of the line pays (progressive jackpots excluded — they
  /// pay a meter, not a multiple of the bet).
  double get rtp {
    var r = 0.0;
    for (final e in GoldRules.linePays.entries) {
      r += e.value * pow(p(e.key), 3);
    }
    final c = p(Sym.cherry);
    r += GoldRules.twoCherryPay * 3 * c * c * (1 - c);
    return r;
  }

  /// Chance a spin pays anything (line win or jackpot).
  double get hitRate {
    var h = 0.0;
    for (final s in Sym.values) {
      h += pow(p(s), 3);
    }
    final c = p(Sym.cherry);
    return h + 3 * c * c * (1 - c);
  }

  /// Chance of a jackpot tier on one spin.
  double jackpotChance(JackpotTier t) =>
      pow(p(GoldRules.jackpotSymbols.entries.firstWhere((e) => e.value == t).key), 3).toDouble();

  /// Share of RTP from each pay (for the breakdown table).
  Map<String, double> get breakdown {
    final c = p(Sym.cherry);
    return {
      for (final e in GoldRules.linePays.entries) '3 × ${e.key.name}': e.value * pow(p(e.key), 3).toDouble(),
      '2 × cherry': GoldRules.twoCherryPay * 3 * c * c * (1 - c),
    };
  }

  /// Reel weights (about 1000 whole stops) whose RTP is as close as possible
  /// to [target]. Below the base RTP the paying symbols are thinned against
  /// the jackpot-only symbols; above it the paying symbols tilt toward the
  /// higher pays while the jackpot symbols keep their share of the reel (so
  /// jackpot odds don't collapse as the RTP goes up).
  static Map<Sym, double> solve(double target, {Map<Sym, double> base = LocalGoldMath.defaultWeights}) {
    final lineTotal = GoldRules.linePays.keys.fold<double>(0, (a, s) => a + base[s]!);
    Map<Sym, double> family(double k, double tilt) {
      final tilted = {for (final s in GoldRules.linePays.keys) s: base[s]! * pow(GoldRules.linePays[s]!, tilt)};
      final sum = tilted.values.fold<double>(0, (a, b) => a + b);
      return {
        for (final s in Sym.values) s: GoldRules.linePays.containsKey(s) ? tilted[s]! / sum * lineTotal * k : base[s]!,
      };
    }

    final below = target < SlotMath(base).rtp;
    // Thin with k in (0, 1], or tilt in [0, 6].
    var lo = below ? log(1e-4) : 0.0, hi = below ? 0.0 : 6.0;
    Map<Sym, double> at(double x) => below ? family(exp(x), 0) : family(1, x);
    for (var i = 0; i < 80; i++) {
      final mid = (lo + hi) / 2;
      if (SlotMath(at(mid)).rtp < target) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final w = at((lo + hi) / 2);
    final total = w.values.fold(0.0, (a, b) => a + b);
    // Whole reel stops, at least one each so every symbol can show…
    final stops = {for (final e in w.entries) e.key: max(1.0, (e.value / total * 1000).roundToDouble())};
    // …then nudge single stops while that brings the RTP closer to the target.
    for (var i = 0; i < 200; i++) {
      var best = (SlotMath(stops).rtp - target).abs();
      (Sym, double)? move;
      for (final sym in GoldRules.linePays.keys) {
        for (final d in const [-1.0, 1.0]) {
          if (stops[sym]! + d < 1) continue;
          final err = (SlotMath({...stops, sym: stops[sym]! + d}).rtp - target).abs();
          if (err < best - 1e-12) {
            best = err;
            move = (sym, d);
          }
        }
      }
      if (move == null) break;
      stops[move.$1] = stops[move.$1]! + move.$2;
    }
    return stops;
  }
}
