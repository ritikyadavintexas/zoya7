import 'package:flutter/material.dart';

import '../nav.dart';
import '../widgets.dart';
import 'games.dart';
import 'lobby.dart';
import 'profile.dart';
import 'promotions.dart';
import 'wallet.dart';

/// The five side-nav pages, kept alive so scroll positions and tab state survive.
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
    return PopScope(
      canPop: tab == AppTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setTab(AppTab.home);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0806),
        resizeToAvoidBottomInset: false,
        body: Row(children: [
          SideNav(active: tab, onTap: (t) => setTab(t)),
          Expanded(
            // The rail already keeps clear of the left notch.
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: true,
              child: IndexedStack(index: tab.index, children: [
                const LobbyPage(),
                const GamesPage(),
                const PromotionsPage(),
                WalletPage(key: _walletKey),
                const ProfilePage(),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
