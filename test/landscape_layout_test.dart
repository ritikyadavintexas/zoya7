import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zoya7_gold/app/landscape.dart';
import 'package:zoya7_gold/app/nav.dart';
import 'package:zoya7_gold/app/screens/chat.dart';
import 'package:zoya7_gold/app/screens/game.dart';
import 'package:zoya7_gold/app/screens/games.dart';
import 'package:zoya7_gold/app/screens/onboarding.dart';
import 'package:zoya7_gold/app/screens/profile.dart';
import 'package:zoya7_gold/app/screens/promotions.dart';
import 'package:zoya7_gold/app/screens/shell.dart';
import 'package:zoya7_gold/app/screens/wallet.dart';
import 'package:zoya7_gold/app/state.dart';

/// Every page must fit a landscape phone without overflowing — from a small
/// iPhone SE up to a large Android — and still fit when the browser hands us a
/// portrait window (the app is then drawn turned sideways).
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

  const sizes = {
    'iPhone SE landscape': Size(667, 375),
    'iPhone 14 landscape': Size(844, 390),
    'large Android landscape': Size(915, 412),
    'portrait window (turned)': Size(390, 844),
  };

  final pages = <String, Widget Function()>{
    'splash': () => const SplashScreen(),
    'welcome': () => const WelcomeScreen(),
    'log in': () => const LoginScreen(),
    'sign up': () => const LoginScreen(signup: true),
    'forgot password': () => const ForgotPasswordScreen(),
    'offline': () => const OfflineScreen(),
    'lobby': () => MainShell(),
    'games': () => MainShell(initial: AppTab.games),
    'promotions': () => MainShell(initial: AppTab.promotions),
    'wallet': () => MainShell(initial: AppTab.wallet),
    'profile': () => MainShell(initial: AppTab.profile),
    'daily bonus': () => const DailyBonusDialog(),
    'slots race': () => const LeaderboardScreen(),
    'checkout': () => const CheckoutScreen(),
    'purchase success': () => PurchaseSuccessScreen(pack: coinPacks[2]),
    'edit profile': () => const EditProfileScreen(),
    'vip': () => const VipScreen(),
    'settings': () => const SettingsScreen(),
    'notifications': () => const NotificationsScreen(),
    'legal': () => const LegalScreen(doc: 'rules'),
    'chat': () => const ChatScreen(),
    'support chat': () => const ChatScreen(room: 'support'),
    'coming soon': () => const ComingSoonScreen(gameId: 'blackjack'),
    'gold game': () => const GoldScreen(),
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

  for (final MapEntry(key: sizeName, value: size) in sizes.entries) {
    group(sizeName, () {
      for (final MapEntry(key: name, value: page) in pages.entries) {
        testWidgets('$name fits', (tester) async {
          await show(tester, size, page());
          expectFits(tester);
          // Leave the page so its timers stop before the test ends.
          await tester.pumpWidget(const SizedBox());
        });
      }

      testWidgets('wallet redeem and history fit', (tester) async {
        await show(tester, size, MainShell(initial: AppTab.wallet));
        for (final tab in ['redeem', 'history']) {
          (shellKey.currentState! as TabHost).setTab(AppTab.wallet, walletTab: tab);
          await tester.pump(const Duration(milliseconds: 300));
          expectFits(tester);
        }
        await tester.pumpWidget(const SizedBox());
      });
    });
  }

  testWidgets('a portrait window draws the app turned sideways', (tester) async {
    await show(tester, const Size(390, 844), const SettingsScreen());
    final box = tester.renderObject<RenderBox>(find.byType(SettingsScreen));
    expect(box.size, const Size(844, 390));
    await tester.pumpWidget(const SizedBox());
  });
}
