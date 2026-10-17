import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zoya7_gold/app/assets.dart';
import 'package:zoya7_gold/app/landscape.dart';
import 'package:zoya7_gold/app/nav.dart';
import 'package:zoya7_gold/app/screens/blackjack.dart';
import 'package:zoya7_gold/app/screens/game.dart';
import 'package:zoya7_gold/app/screens/games.dart';
import 'package:zoya7_gold/app/screens/html_game.dart';
import 'package:zoya7_gold/app/screens/onboarding.dart';
import 'package:zoya7_gold/app/screens/profile.dart';
import 'package:zoya7_gold/app/screens/promotions.dart';
import 'package:zoya7_gold/app/screens/shell.dart';
import 'package:zoya7_gold/app/screens/wallet.dart';
import 'package:zoya7_gold/app/state.dart';
import 'package:zoya7_gold/app/widgets.dart';

/// Every page must lay itself out at every landscape screen size from the
/// smallest phone (568×320) up to a tablet, with nothing overflowing, and the
/// layouts must actually change with the room they get (columns, panes).
void main() {
  // Lay text out with the app's real fonts (test/fonts, named the way
  // google_fonts names its families) — the test font's square glyphs are far
  // wider and would report overflows a phone never shows.
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    for (final f in Directory('test/fonts').listSync().whereType<File>()) {
      final family = f.uri.pathSegments.last.replaceAll('.ttf', '');
      await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
    }
  });

  // Real landscape screens (logical px), smallest to largest.
  const sizes = {
    'iPhone SE (1st gen)': Size(568, 320),
    'small Android': Size(640, 360),
    'iPhone 8': Size(667, 375),
    'iPhone 8 Plus': Size(736, 414),
    'Galaxy S20': Size(800, 360),
    'iPhone 14': Size(844, 390),
    'Pixel 7': Size(915, 412),
    'iPhone 15 Pro Max': Size(932, 430),
    'small tablet': Size(1024, 600),
    'iPad': Size(1180, 820),
    'large tablet': Size(1366, 1024),
  };

  final pages = <String, Widget Function()>{
    'splash': () => const SplashScreen(),
    'welcome': () => const WelcomeScreen(),
    'log in': () => const LoginScreen(),
    'forgot password': () => const ForgotPasswordScreen(),
    'offline': () => const OfflineScreen(),
    'lobby': () => const HomeScreen(),
    'games': () => const GamesPage(),
    'promotions': () => const PromotionsPage(),
    'wallet': () => const WalletPage(),
    'profile': () => const ProfilePage(),
    'daily bonus': () => const DailyBonusDialog(),
    'slots race': () => const LeaderboardScreen(),
    'checkout': () => const CheckoutScreen(),
    'purchase success': () => PurchaseSuccessScreen(pack: coinPacks[2]),
    'edit profile': () => const EditProfileScreen(),
    'vip': () => const VipScreen(),
    'settings': () => const SettingsScreen(),
    'notifications': () => const NotificationsScreen(),
    'legal': () => const LegalScreen(doc: 'rules'),
    'coming soon': () => const ComingSoonScreen(gameId: 'blackjack'),
    'gold game': () => const GoldScreen(),
    'fruit spin': () => const GoldScreen(gameId: 'fruitspin'),
    'phoenix ruby': () => const GoldScreen(gameId: 'phoenixruby'),
    'blackjack': () => const BlackjackScreen(),
    'uploaded game': () => const HtmlGameScreen(gameId: 'lanterns'),
  };

  // Full reports (which widget overflowed, where, by how much) for failures.
  final reports = <String>[];

  void expectFits(WidgetTester tester) {
    final e = tester.takeException();
    expect(e, isNull, reason: reports.join('\n'));
  }

  Future<void> show(WidgetTester tester, Size size, Widget page) async {
    reports.clear();
    final onError = FlutterError.onError;
    FlutterError.onError = (d) {
      reports.add(d.toString());
      onError?.call(d);
    };
    addTearDown(() => FlutterError.onError = onError);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope(
      state: AppState(),
      child: MaterialApp(
        navigatorKey: Nav.navigatorKey,
        builder: (context, child) => ForceLandscape(child: child!),
        home: page,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 700));
  }

  // Only these may scroll vertically: a conversation and long documents.
  const mayScroll = {'legal'};

  /// Vertical scrollables on screen that actually have something to scroll.
  List<double> verticalOverflow(WidgetTester tester) => [
        for (final e in find.byType(Scrollable).hitTestable().evaluate())
          if (((e as StatefulElement).state as ScrollableState).position case final p
              when p.axis == Axis.vertical && p.maxScrollExtent > .5)
            p.maxScrollExtent,
      ];

  for (final MapEntry(key: sizeName, value: size) in sizes.entries) {
    group(sizeName, () {
      for (final MapEntry(key: name, value: page) in pages.entries) {
        testWidgets('$name fits', (tester) async {
          await show(tester, size, page());
          expectFits(tester);
          // Phones (and up) show the whole page without vertical scrolling.
          if (!mayScroll.contains(name) && size.width >= 568 && size.width > size.height) {
            expect(verticalOverflow(tester), isEmpty, reason: '$name scrolls vertically at $size');
          }
          // Leave the page so its timers stop before the test ends.
          await tester.pumpWidget(const SizedBox());
        });
      }

      for (final tab in ['buy', 'history']) {
        testWidgets('wallet $tab fits', (tester) async {
          await show(tester, size, WalletPage(initialTab: tab));
          expectFits(tester);
          await tester.pumpWidget(const SizedBox());
        });
      }

      testWidgets('jackpots popup fits', (tester) async {
        await show(tester, size, const HomeScreen());
        await tester.tap(find.bySemanticsLabel(RegExp('^Jackpots')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('JACKPOTS'), findsWidgets);
        expectFits(tester);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('avatar picker fits', (tester) async {
        await show(tester, size, const EditProfileScreen());
        await tester.tap(find.bySemanticsLabel('Change avatar'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('CHOOSE AVATAR'), findsOneWidget);
        expectFits(tester);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('options menu fits', (tester) async {
        await show(tester, size, const HomeScreen());
        await tester.tap(find.bySemanticsLabel('Menu'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('All games'), findsOneWidget);
        expectFits(tester);
        await tester.pumpWidget(const SizedBox());
      });
    });
  }

  int verticalLists(WidgetTester tester) => find
      .byType(Scrollable)
      .hitTestable()
      .evaluate()
      .where((e) => ((e as StatefulElement).state as ScrollableState).position.axis == Axis.vertical)
      .length;

  /// Number of distinct x positions among the widgets [finder] finds.
  int columns(WidgetTester tester, Finder finder) =>
      finder.evaluate().map((e) => tester.getTopLeft(find.byWidget(e.widget)).dx.round()).toSet().length;

  testWidgets('the games grid shows every game without scrolling, using the columns the space needs', (tester) async {
    final cols = <int>[];
    for (final size in const [Size(568, 320), Size(844, 390), Size(1366, 1024)]) {
      await show(tester, size, const GamesPage());
      final screen = Offset.zero & size;
      final tiles = find.byType(RoundImage).evaluate().map((e) => tester.getRect(find.byWidget(e.widget)));
      expect(tiles.where((r) => screen.intersect(r) == r), hasLength(games.length), reason: 'all games on screen at $size');
      cols.add(columns(tester, find.byType(RoundImage)));
      await tester.pumpWidget(const SizedBox());
    }
    // Short phone: more, smaller columns; tall tablet: fewer, bigger tiles.
    expect(cols.first, greaterThan(cols.last));
  });

  testWidgets('two-pane pages fall back to one column when the main pane would be too narrow', (tester) async {
    // A 500px-wide window: the side pane would leave the main pane < 300px → one list.
    await show(tester, const Size(500, 320), const EditProfileScreen());
    expect(verticalLists(tester), 1);
    await tester.pumpWidget(const SizedBox());
    // 844 wide: both panes fit → two lists side by side.
    await show(tester, const Size(844, 390), const EditProfileScreen());
    expect(verticalLists(tester), 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('log in: the boxes sit above a landscape phone keyboard, and Return goes on', (tester) async {
    // An iPhone on its side: the keyboard and its bar cover the lower ~250 px.
    await show(tester, const Size(844, 390), const LoginScreen());
    for (final f in find.byType(TextField).evaluate()) {
      expect(tester.getRect(find.byWidget(f.widget)).bottom, lessThan(390 - 250));
    }
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.map((f) => f.textInputAction), [TextInputAction.next, TextInputAction.go]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the Gold table widens with the screen instead of leaving side bands', (tester) async {
    await show(tester, const Size(844, 390), const GoldScreen());
    final table = tester.getSize(find.byType(FittedBox).first);
    expect(table.width, closeTo(844, 1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('held upright, the game is drawn turned, in landscape at once; sideways it is plain, where it left off', (tester) async {
    await show(tester, const Size(390, 844), const SettingsScreen());
    expectFits(tester);
    expect(tester.widget<RotatedBox>(find.byType(RotatedBox).first).quarterTurns, 1);
    expect(tester.getSize(find.byType(SettingsScreen)), const Size(844, 390), reason: 'laid out in landscape');
    final page = tester.state(find.byType(SettingsScreen));

    tester.view.physicalSize = const Size(844, 390);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<RotatedBox>(find.byType(RotatedBox).first).quarterTurns, 0);
    expect(tester.getSize(find.byType(SettingsScreen)), const Size(844, 390));
    expect(tester.state(find.byType(SettingsScreen)), same(page), reason: 'the page is kept, not rebuilt');
    await tester.pumpWidget(const SizedBox());
  });
}
