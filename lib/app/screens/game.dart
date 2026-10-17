import 'package:flutter/material.dart';

import '../../games/gold/gold_game.dart';
import '../nav.dart';
import '../state.dart';

/// Classic 777 / Fruit Spin / Phoenix Ruby (the Gold slot), hosted inside the (landscape)
/// app. Reel math and bet range come from the back office; every spin moves
/// the app's balance and is recorded for the reports.
class GoldScreen extends StatelessWidget {
  const GoldScreen({super.key, this.gameId = 'classic777'});
  final String gameId;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
    final cfg = s.casino.config(gameId);
    return Scaffold(
      backgroundColor: SlotSkin.forGame(gameId).background.last,
      resizeToAvoidBottomInset: false,
      body: GoldGame(
        outcomes: _Recorded(gameId, s, LocalGoldMath(weights: cfg.weights)),
        initialGc: s.gc,
        initialSc: s.sc,
        minBetIdx: cfg.minIdx,
        maxBetIdx: cfg.maxIdx,
        onExitToLobby: () => Nav.back(context),
        onBuyCoins: (_) => Nav.tab(AppTab.wallet, walletTab: 'buy'),
        onOpenPlayLimits: () => Nav.push(R.settings),
        skin: SlotSkin.forGame(gameId),
      ),
    );
  }
}

/// Passes spins through to the math and books each one.
class _Recorded implements GoldOutcomeSource {
  _Recorded(this.gameId, this.s, this.math);
  final String gameId;
  final AppState s;
  final GoldOutcomeSource math;

  @override
  Sym fillerSymbol() => math.fillerSymbol();

  @override
  Future<GoldSpinOutcome> spin({
    required double bet,
    required Currency currency,
    required Map<JackpotTier, double> jackpots,
  }) async {
    final o = await math.spin(bet: bet, currency: currency, jackpots: jackpots);
    s.recordRound(gameId, currency, bet, o.win);
    return o;
  }
}
