import 'dart:math';

enum Currency { gc, sc }

enum Sym { seven, diamond, crown, bar, star, bell, melon, plum, orange, lemon, cherry }

enum JackpotTier { mega, major, minor, mini }

enum WinTier { big, superWin, mega, jackpot }

/// Static rules of Gold (from the design's paytable).
class GoldRules {
  GoldRules._();

  /// Three of these on the payline → line pay (× total bet).
  static const Map<Sym, int> linePays = {
    Sym.star: 30, Sym.bell: 20, Sym.melon: 15, Sym.plum: 10,
    Sym.orange: 8, Sym.lemon: 6, Sym.cherry: 5,
  };

  /// Any two cherries on the payline.
  static const int twoCherryPay = 2;

  /// Three of these on the payline → that jackpot.
  static const Map<Sym, JackpotTier> jackpotSymbols = {
    Sym.seven: JackpotTier.mega, Sym.diamond: JackpotTier.major,
    Sym.crown: JackpotTier.minor, Sym.bar: JackpotTier.mini,
  };

  static const Map<Currency, List<double>> bets = {
    Currency.gc: [1000, 2500, 5000, 10000, 25000, 50000, 100000],
    Currency.sc: [0.2, 0.5, 1, 2, 5, 10, 20],
  };

  static const int maxBetIndex = 6;

  /// Celebration tier by multiplier (design: ≥10 big, ≥20 super, ≥30 mega).
  static WinTier? tierFor(int multiplier, JackpotTier? jackpot) {
    if (jackpot != null) return WinTier.jackpot;
    if (multiplier >= 30) return WinTier.mega;
    if (multiplier >= 20) return WinTier.superWin;
    if (multiplier >= 10) return WinTier.big;
    return null;
  }

  /// Evaluates the middle payline. [grid] is 3 reels × 3 rows (row 1 = payline).
  static GoldSpinOutcome evaluate(
    List<List<Sym>> grid,
    double bet,
    Map<JackpotTier, double> jackpots,
  ) {
    final mid = grid.map((c) => c[1]).toList();
    final three = mid[0] == mid[1] && mid[1] == mid[2];
    int mult = 0;
    JackpotTier? jp;
    double win;
    if (three && jackpotSymbols.containsKey(mid[0])) {
      jp = jackpotSymbols[mid[0]];
      win = round2(jackpots[jp]!);
      mult = (win / bet).round();
    } else {
      if (three) {
        mult = linePays[mid[0]] ?? 0;
      } else if (mid.where((s) => s == Sym.cherry).length >= 2) {
        mult = twoCherryPay;
      }
      win = round2(bet * mult);
    }
    return GoldSpinOutcome(grid: grid, win: win, multiplier: mult, jackpot: jp);
  }
}

double round2(double v) => (v * 100).roundToDouble() / 100;

class GoldSpinOutcome {
  const GoldSpinOutcome({
    required this.grid,
    required this.win,
    required this.multiplier,
    this.jackpot,
  });

  final List<List<Sym>> grid;
  final double win;
  final int multiplier;
  final JackpotTier? jackpot;
}

/// Where spin results come from.
///
/// Zoya7's shared-RTP math engine should implement this on the server and the
/// client should only render what it returns. [LocalGoldMath] exists for
/// offline development and design review.
abstract class GoldOutcomeSource {
  Future<GoldSpinOutcome> spin({
    required double bet,
    required Currency currency,
    required Map<JackpotTier, double> jackpots,
  });

  /// Random symbol used for blur filler while reels spin (visual only).
  Sym fillerSymbol();
}

/// The design prototype's reel math (independent weighted reels).
/// Line-pay RTP of these weights is ≈22.8% — placeholder only.
class LocalGoldMath implements GoldOutcomeSource {
  LocalGoldMath({Random? random, Map<Sym, double>? weights})
      : _rng = random ?? Random(),
        weights = weights ?? defaultWeights;

  static const Map<Sym, double> defaultWeights = {
    Sym.seven: 1, Sym.diamond: 1.5, Sym.crown: 2, Sym.bar: 3, Sym.star: 3,
    Sym.bell: 4, Sym.melon: 4, Sym.plum: 5, Sym.orange: 5, Sym.lemon: 6,
    Sym.cherry: 6,
  };

  final Random _rng;
  final Map<Sym, double> weights;

  Sym _draw() {
    final total = weights.values.fold<double>(0, (a, b) => a + b);
    var r = _rng.nextDouble() * total;
    for (final e in weights.entries) {
      r -= e.value;
      if (r < 0) return e.key;
    }
    return Sym.cherry;
  }

  List<Sym> _column() => [_draw(), _draw(), _draw()];

  @override
  Sym fillerSymbol() => _draw();

  @override
  Future<GoldSpinOutcome> spin({
    required double bet,
    required Currency currency,
    required Map<JackpotTier, double> jackpots,
  }) async {
    final grid = [_column(), _column(), _column()];
    return GoldRules.evaluate(grid, bet, jackpots);
  }
}
