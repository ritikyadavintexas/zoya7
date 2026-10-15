import 'package:flutter/material.dart';

import '../nav.dart';
import '../widgets.dart';
import 'games.dart';
import 'lobby.dart';
import 'profile.dart';
import 'promotions.dart';
import 'wallet.dart';

/// The five bottom-nav pages, kept alive so scroll positions and tab state survive.
class MainShell extends StatefulWidget {
  MainShell({this.initial = AppTab.home}) : super(key: shellKey);
  final AppTab initial;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> implements TabHost {
  late AppTab tab = widget.initial;
  final _walletKey = GlobalKey<WalletPageState>();

  @override
  void setTab(AppTab t, {String? walletTab}) {
    setState(() => tab = t);
    if (walletTab != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _walletKey.currentState?.showTab(walletTab));
    }
  }

  @override
  Widget build(BuildContext context) {
    final showFab = tab == AppTab.home || tab == AppTab.games || tab == AppTab.promotions;
    return PopScope(
      canPop: tab == AppTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setTab(AppTab.home);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0806),
        resizeToAvoidBottomInset: false,
        body: Stack(children: [
          Positioned.fill(
            child: IndexedStack(index: tab.index, children: [
              const LobbyPage(),
              const GamesPage(),
              const PromotionsPage(),
              WalletPage(key: _walletKey),
              const ProfilePage(),
            ]),
          ),
          if (showFab)
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: const Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(padding: EdgeInsets.only(right: 16, bottom: 16), child: ChatFab()),
                  ),
                ),
              ),
            ),
        ]),
        bottomNavigationBar: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: BottomNav(active: tab, onTap: (t) => setTab(t)),
          ),
        ),
      ),
    );
  }
}
