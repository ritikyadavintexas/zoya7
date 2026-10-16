import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin/admin_app.dart';
import 'app/landscape.dart';
import 'app/nav.dart';
import 'app/screens/blackjack.dart';
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
import 'backoffice/casino.dart';

/// Set by CI (`--dart-define=BUILD_SHA=…`) so you can tell which build is on your phone.
const _buildSha = String.fromEnvironment('BUILD_SHA');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // …/#/admin (or ?admin) opens the admin panel instead of the game.
  Nav.adminMode.value = kIsWeb && (Uri.base.fragment.startsWith('/admin') || Uri.base.queryParameters.containsKey('admin'));
  if (!Nav.adminMode.value) await _lockLandscape();
  runApp(Zoya7Root(state: AppState(casino: Casino.load())));
}

/// The game is landscape. Browsers can't lock it, so ForceLandscape turns it there.
Future<void> _lockLandscape() async {
  if (kIsWeb) return;
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}

/// The game, or the admin panel (portrait, Cash App style) over the same
/// back office.
class Zoya7Root extends StatefulWidget {
  const Zoya7Root({super.key, required this.state});
  final AppState state;

  @override
  State<Zoya7Root> createState() => _Zoya7RootState();
}

class _Zoya7RootState extends State<Zoya7Root> {
  /// Coming back from the admin panel goes straight to the lobby.
  var _startAt = R.splash;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: Nav.adminMode,
        builder: (context, admin, _) => admin
            ? AdminApp(
                casino: widget.state.casino,
                onExit: () {
                  _startAt = R.home;
                  _lockLandscape();
                  Nav.adminMode.value = false;
                },
              )
            : Zoya7App(state: widget.state, startAt: _startAt),
      );
}

class Zoya7App extends StatelessWidget {
  const Zoya7App({super.key, required this.state, this.startAt = R.splash});
  final AppState state;
  final String startAt;

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
        initialRoute: startAt,
        // A link to a page (…/#/wallet) opens it over the lobby; the admin
        // panel's link and a return from the panel start at [startAt].
        onGenerateInitialRoutes: (name) => name == R.splash || name.startsWith('/admin') || startAt != R.splash
            ? [_route(RouteSettings(name: startAt))]
            : [
                _route(const RouteSettings(name: R.home)),
                if (name != R.home) _route(RouteSettings(name: name)),
              ],
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
        page = GoldScreen(gameId: arg is String ? arg : 'classic777');
      case R.blackjack:
        page = const BlackjackScreen();
      case R.chat:
        page = ChatScreen(room: arg is String ? arg : 'community');
      case R.notifications:
        page = const NotificationsScreen();
      case R.settings:
        page = SettingsScreen(section: arg is String ? arg : 'gameplay');
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
