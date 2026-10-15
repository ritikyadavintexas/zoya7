import 'package:flutter/material.dart';

import '../../games/gold/gold_game.dart';
import '../nav.dart';
import '../state.dart';

/// Classic 777 (Gold) — the slot, hosted inside the (landscape) app.
class GoldScreen extends StatelessWidget {
  const GoldScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
    return Scaffold(
      backgroundColor: const Color(0xFF1A0F04),
      resizeToAvoidBottomInset: false,
      body: GoldGame(
        initialGc: s.gc,
        initialSc: s.sc,
        onExitToLobby: () => Nav.back(context),
        onBuyCoins: (_) => Nav.tab(AppTab.wallet, walletTab: 'buy'),
        onOpenPlayLimits: () => Nav.push(R.settings),
      ),
    );
  }
}
