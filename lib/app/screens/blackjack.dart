import 'package:flutter/material.dart';

import '../../backoffice/casino.dart';
import '../../games/blackjack/blackjack_game.dart';
import '../../games/gold/src/math.dart' show Currency;
import '../nav.dart';
import '../state.dart';

/// The Blackjack table, playing with the app's GC / SC balances, with the
/// rules and limits set in the back office.
class BlackjackScreen extends StatelessWidget {
  const BlackjackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
    final cfg = s.casino.config('blackjack');
    return Scaffold(
        backgroundColor: const Color(0xFF06200F),
        resizeToAvoidBottomInset: false,
        body: BlackjackGame(
          wallet: _AppWallet(s),
          rules: cfg.bj,
          limits: {Currency.gc: (cfg.minGc, cfg.maxGc), Currency.sc: (cfg.minSc, cfg.maxSc)},
          onSettled: (c, staked, returned) => s.casino.recordRound('blackjack', Casino.meId, c, staked, returned),
          onExit: () => Nav.back(context),
          onBuyCoins: (_) => Nav.tab(AppTab.wallet, walletTab: 'buy'),
        ),
      );
  }
}

class _AppWallet implements BlackjackWallet {
  _AppWallet(this.s);
  final AppState s;

  @override
  double balance(Currency c) => c == Currency.gc ? s.gc : s.sc;

  @override
  void add(Currency c, double amount) => c == Currency.gc ? s.adjust(gc: amount) : s.adjust(sc: amount);
}
