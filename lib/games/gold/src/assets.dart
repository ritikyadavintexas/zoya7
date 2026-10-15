import 'math.dart';

/// Every image used by the Gold design, exported 1:1 from the Zoya7 design file.
class GoldAssets {
  GoldAssets._();
  static const _p = 'assets/games/gold';

  static const back = '$_p/btn_back.png';
  static const balanceGc = '$_p/balance_gc.png';
  static const balanceSc = '$_p/balance_sc.png';
  static const reelFrame = '$_p/reel_frame.png';
  static const betPanel = '$_p/bet_panel.png';
  static const maxBet = '$_p/btn_max_bet.png';
  static const auto = '$_p/btn_auto.png';
  static const spin = '$_p/btn_spin.png';
  static const stop = '$_p/btn_stop.png';

  static String jackpot(JackpotTier t) => '$_p/jp_${t.name}.png';
  static String symbol(Sym s) => '$_p/sym_${s.name}.png';

  static String winBanner(WinTier t) => switch (t) {
        WinTier.big => '$_p/win_big.png',
        WinTier.superWin => '$_p/win_super.png',
        WinTier.mega => '$_p/win_mega.png',
        WinTier.jackpot => '$_p/win_jackpot.png',
      };

  static List<String> get all => [
        back, balanceGc, balanceSc, reelFrame, betPanel, maxBet, auto, spin, stop,
        ...JackpotTier.values.map(jackpot),
        ...Sym.values.map(symbol),
        ...WinTier.values.map(winBanner),
      ];
}
