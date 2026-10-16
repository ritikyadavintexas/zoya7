import 'package:flutter/material.dart';

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
    final wallet = _AppWallet(s);
    return Scaffold(
        backgroundColor: const Color(0xFF06200F),
        resizeToAvoidBottomInset: false,
        body: BlackjackGame(
          wallet: wallet,
          rules: cfg.bj,
          limits: {Currency.gc: (cfg.minGc, cfg.maxGc), Currency.sc: (cfg.minSc, cfg.maxSc)},
          onSettled: (c, staked, returned) => wallet.settle(c, staked, returned),
          onExit: () => Nav.back(context),
          onBuyCoins: (_) => Nav.tab(AppTab.wallet, walletTab: 'buy'),
        ),
      );
  }
}

/// Bets are held here while a hand is in play; when it settles the round is
/// booked to the back office (which moves the balance) and the hold clears.
class _AppWallet implements BlackjackWallet {
  _AppWallet(this.s);
  final AppState s;
  final _held = {Currency.gc: 0.0, Currency.sc: 0.0};

  @override
  double balance(Currency c) => (c == Currency.gc ? s.gc : s.sc) + _held[c]!;

  @override
  void add(Currency c, double amount) => _held[c] = _held[c]! + amount;

  void settle(Currency c, double staked, double returned) {
    s.recordRound('blackjack', c, staked, returned);
    _held[c] = _held[c]! - (returned - staked);
    if (_held[c]!.abs() < 1e-6) _held[c] = 0;
  }
}
