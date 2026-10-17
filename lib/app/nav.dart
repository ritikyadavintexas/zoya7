import 'package:flutter/material.dart';

/// Route names — one per artboard in the design.
class R {
  static const splash = '/';
  static const welcome = '/welcome';
  static const login = '/login';
  static const signup = '/signup';
  static const forgot = '/forgot-password';
  static const home = '/home';
  static const games = '/games';
  static const promotions = '/promotions';
  static const wallet = '/wallet';
  static const profile = '/profile';
  static const gold = '/gold';
  static const blackjack = '/blackjack';

  /// An uploaded game (argument: its id).
  static const htmlGame = '/play';
  static const notifications = '/notifications';
  static const settings = '/settings';
  static const vip = '/vip';
  static const checkout = '/checkout';
  static const purchaseSuccess = '/purchase-success';
  static const editProfile = '/edit-profile';
  static const leaderboard = '/leaderboard';
  static const legal = '/legal';
  static const comingSoon = '/coming-soon';
  static const dailyBonus = '/daily-bonus';
  static const offline = '/offline';
}

/// The main sections. Home is the lobby; the others open over it
/// (from the HUD and the options menu).
enum AppTab { home, games, promotions, wallet, profile }

class Nav {
  static final navigatorKey = GlobalKey<NavigatorState>();

  /// The admin panel is on screen instead of the game (see main.dart).
  static final adminMode = ValueNotifier<bool>(false);

  static NavigatorState get _nav => navigatorKey.currentState!;

  /// Open a section: back to the lobby, then the section's page on top of
  /// it (the wallet on [walletTab] — 'buy' or 'history').
  static void tab(AppTab tab, {String? walletTab}) {
    var home = false;
    _nav.popUntil((r) {
      if (r.settings.name == R.home) home = true;
      return home || r.isFirst;
    });
    if (!home) _nav.pushNamedAndRemoveUntil(R.home, (_) => false);
    switch (tab) {
      case AppTab.home:
        break;
      case AppTab.games:
        _nav.pushNamed(R.games);
      case AppTab.promotions:
        _nav.pushNamed(R.promotions);
      case AppTab.wallet:
        _nav.pushNamed(R.wallet, arguments: walletTab);
      case AppTab.profile:
        _nav.pushNamed(R.profile);
    }
  }

  static Future<T?> push<T>(String route, [Object? args]) => _nav.pushNamed<T>(route, arguments: args);

  static void replace(String route, [Object? args]) => _nav.pushReplacementNamed(route, arguments: args);

  /// Start over at [route] with nothing behind it (log out, finish onboarding).
  static void reset(String route, [Object? args]) =>
      _nav.pushNamedAndRemoveUntil(route, (_) => false, arguments: args);

  /// Back, or to the lobby when there's nothing to go back to.
  static void back([BuildContext? _]) {
    if (_nav.canPop()) {
      _nav.pop();
    } else {
      tab(AppTab.home);
    }
  }

  /// Open the lobby and show the daily-bonus popup over it.
  static void homeWithBonus() {
    _nav.pushNamedAndRemoveUntil(R.home, (_) => false);
    _nav.pushNamed(R.dailyBonus);
  }
}
