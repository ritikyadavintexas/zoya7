import 'package:flutter/material.dart';

/// Route names — one per artboard in the design.
class R {
  static const splash = '/';
  static const welcome = '/welcome';
  static const login = '/login';
  static const signup = '/signup';
  static const forgot = '/forgot-password';
  static const home = '/home';
  static const gold = '/gold';
  static const chat = '/chat';
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

/// The five bottom-nav tabs.
enum AppTab { home, games, promotions, wallet, profile }

/// Lets pages switch the bottom-nav tab of the main shell.
abstract class TabHost {
  void setTab(AppTab tab, {String? walletTab});
}

final shellKey = GlobalKey();

class Nav {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static NavigatorState get _nav => navigatorKey.currentState!;

  /// Go to a bottom-nav tab: back to the shell if it's open, otherwise start it.
  static void tab(AppTab tab, {String? walletTab}) {
    final host = shellKey.currentState;
    if (host != null && host.mounted && host is TabHost) {
      _nav.popUntil((r) => r.settings.name == R.home);
      (host as TabHost).setTab(tab, walletTab: walletTab);
    } else {
      _nav.pushNamedAndRemoveUntil(R.home, (_) => false, arguments: tab);
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
    _nav.pushNamedAndRemoveUntil(R.home, (_) => false, arguments: AppTab.home);
    _nav.pushNamed(R.dailyBonus);
  }
}
