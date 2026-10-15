import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/landscape.dart';
import 'app/nav.dart';
import 'app/screens/chat.dart';
import 'app/screens/game.dart';
import 'app/screens/games.dart';
import 'app/screens/onboarding.dart';
import 'app/screens/profile.dart';
import 'app/screens/promotions.dart';
import 'app/screens/shell.dart';
import 'app/screens/wallet.dart';
import 'app/state.dart';
import 'app/theme.dart';
import 'app/web_safe_area.dart';

/// Set by CI (`--dart-define=BUILD_SHA=…`) so you can tell which build is on your phone.
const _buildSha = String.fromEnvironment('BUILD_SHA');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The whole app is landscape. Browsers can't lock it, so ForceLandscape turns it there.
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  runApp(Zoya7App(state: AppState()));
}

class Zoya7App extends StatelessWidget {
  const Zoya7App({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Zoya7',
        debugShowCheckedModeBanner: false,
        navigatorKey: Nav.navigatorKey,
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          scaffoldBackgroundColor: Z.ink,
          colorScheme: const ColorScheme.dark(primary: Z.gold, surface: Z.ink),
          pageTransitionsTheme: const PageTransitionsTheme(builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          }),
        ),
        initialRoute: R.splash,
        onGenerateRoute: _route,
        builder: (context, child) => WebSafeArea(
          child: ForceLandscape(
            child: Stack(children: [
              child!,
              if (_buildSha.isNotEmpty)
                const Positioned(
                  left: 8,
                  bottom: 2,
                  child: IgnorePointer(
                    child: Text('build $_buildSha',
                        style: TextStyle(fontSize: 10, color: Color(0x66FFF4D6), decoration: TextDecoration.none)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  static Route<dynamic> _route(RouteSettings s) {
    final arg = s.arguments;
    Widget page;
    switch (s.name) {
      case R.splash:
        page = const SplashScreen();
      case R.welcome:
        page = const WelcomeScreen();
      case R.login:
        page = const LoginScreen();
      case R.signup:
        page = const LoginScreen(signup: true);
      case R.forgot:
        page = const ForgotPasswordScreen();
      case R.home:
        page = const HomeScreen();
      case R.games:
        page = const GamesPage();
      case R.promotions:
        page = const PromotionsPage();
      case R.wallet:
        page = WalletPage(initialTab: arg is String ? arg : 'buy');
      case R.profile:
        page = const ProfilePage();
      case R.gold:
        page = const GoldScreen();
      case R.chat:
        page = ChatScreen(room: arg is String ? arg : 'community');
      case R.notifications:
        page = const NotificationsScreen();
      case R.settings:
        page = const SettingsScreen();
      case R.vip:
        page = const VipScreen();
      case R.checkout:
        page = const CheckoutScreen();
      case R.purchaseSuccess:
        final (CoinPack, int) a = arg is (CoinPack, int) ? arg : (coinPacks[2], 0);
        page = PurchaseSuccessScreen(pack: a.$1, bonusGc: a.$2);
      case R.editProfile:
        page = const EditProfileScreen();
      case R.leaderboard:
        page = const LeaderboardScreen();
      case R.legal:
        page = LegalScreen(doc: arg is String ? arg : 'terms');
      case R.comingSoon:
        page = ComingSoonScreen(gameId: arg is String ? arg : 'megareels');
      case R.offline:
        page = const OfflineScreen();
      case R.dailyBonus:
        return PageRouteBuilder<void>(
          settings: s,
          opaque: false,
          barrierDismissible: false,
          transitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (_, __, ___) => const DailyBonusDialog(),
          transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        );
      default:
        page = const HomeScreen();
    }
    if (s.name == R.splash || s.name == R.welcome || s.name == R.home) {
      return PageRouteBuilder<void>(
        settings: s,
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      );
    }
    return MaterialPageRoute<void>(settings: s, builder: (_) => page);
  }
}
