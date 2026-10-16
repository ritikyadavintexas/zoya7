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
import 'app/web_env.dart';
import 'app/web_safe_area.dart';
import 'backoffice/auth.dart';
import 'backoffice/casino.dart';
import 'backoffice/sync.dart';

/// Set by CI (`--dart-define=BUILD_SHA=…`) so you can tell which build is on your phone.
const _buildSha = String.fromEnvironment('BUILD_SHA');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // …/admin/ is the separate admin app (its own home-screen icon); the older
  // …/#/admin link opens the panel too.
  final adminApp = pageApp() == 'admin';
  Nav.adminMode.value = adminApp || (kIsWeb && (Uri.base.fragment.startsWith('/admin') || Uri.base.queryParameters.containsKey('admin')));
  if (!Nav.adminMode.value) await _lockLandscape();
  // Nothing is kept on the device: everything comes from the database.
  final casino = Casino.empty();
  final sync = CasinoSync(casino, auth: FirebaseAuthApi())..start();
  // The game picks up the player signed in here before; the admin panel its staff member.
  final playerId = Nav.adminMode.value ? null : sync.resumePlayer();
  runApp(Zoya7Root(state: AppState(casino: casino, playerId: playerId, sync: sync), sync: sync, adminApp: adminApp));
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
  const Zoya7Root({super.key, required this.state, this.sync, this.adminApp = false});
  final AppState state;
  final CasinoSync? sync;

  /// Opened as the separate admin app: no way into the game from it.
  final bool adminApp;

  @override
  State<Zoya7Root> createState() => _Zoya7RootState();
}

class _Zoya7RootState extends State<Zoya7Root> {
  /// Coming back from the admin panel goes straight to the lobby.
  var _startAt = R.splash;

  @override
  void initState() {
    super.initState();
    Nav.adminMode.addListener(_showAdminInAddressBar);
    _showAdminInAddressBar();
  }

  @override
  void dispose() {
    Nav.adminMode.removeListener(_showAdminInAddressBar);
    super.dispose();
  }

  /// Keep …/#/admin in the address bar while the panel is open, so a refresh
  /// or a bookmark opens the panel again (the panel's own pages would
  /// otherwise rewrite it to the game's address).
  void _showAdminInAddressBar() {
    if (!kIsWeb || widget.adminApp || !Nav.adminMode.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Nav.adminMode.value) SystemNavigator.routeInformationUpdated(uri: Uri(path: '/admin'), replace: true);
    });
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: Nav.adminMode,
        builder: (context, admin, _) => admin
            ? AdminApp(
                casino: widget.state.casino,
                sync: widget.sync,
                onExit: widget.adminApp
                    ? null
                    : () {
                        // Back to syncing as the player signed in on this device.
                        widget.sync?.resumePlayer();
                        _startAt = widget.state.playerId == null ? R.splash : R.home;
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
        onGenerateInitialRoutes: (name) => !state.signedIn
            ? [_route(const RouteSettings(name: R.splash))]
            : name == R.splash || name.startsWith('/admin') || startAt != R.splash
            ? [_route(RouteSettings(name: startAt))]
            : [
                _route(const RouteSettings(name: R.home)),
                if (name != R.home) _route(RouteSettings(name: name)),
              ],
        onGenerateRoute: _route,
        builder: (context, child) => WebSafeArea(
          child: _SessionGuard(
            state: state,
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
        page = const LoginScreen();
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
      case final name? when name.startsWith('/admin'):
        // …/#/admin typed or followed while the game is already open: switch
        // to the panel (at start-up main() catches it).
        WidgetsBinding.instance.addPostFrameCallback((_) => Nav.adminMode.value = true);
        page = const ColoredBox(color: Z.ink);
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

/// When the back office closes or removes the account being played, go to
/// the log-in page (which says why).
class _SessionGuard extends StatefulWidget {
  const _SessionGuard({required this.state, required this.child});
  final AppState state;
  final Widget child;

  @override
  State<_SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<_SessionGuard> {
  late bool _wasIn = widget.state.signedIn;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_check);
  }

  @override
  void dispose() {
    widget.state.removeListener(_check);
    super.dispose();
  }

  void _check() {
    final inNow = widget.state.signedIn;
    if (_wasIn && !inNow && widget.state.kickedOut != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Nav.navigatorKey.currentState != null && !widget.state.signedIn) Nav.reset(R.login);
      });
    }
    _wasIn = inNow;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
