import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zoya7_gold/admin/admin_app.dart';
import 'package:zoya7_gold/admin/coins.dart';
import 'package:zoya7_gold/admin/games.dart' show showBetLimits;
import 'package:zoya7_gold/admin/players.dart';
import 'package:zoya7_gold/app/assets.dart';
import 'package:zoya7_gold/app/landscape.dart';
import 'package:zoya7_gold/app/nav.dart';
import 'package:zoya7_gold/app/screens/lobby.dart';
import 'package:zoya7_gold/app/state.dart';
import 'package:zoya7_gold/backoffice/casino.dart';

/// The admin panel at desktop, tablet and phone sizes (portrait first, and a
/// phone on its side): every page lays out with nothing overflowing, a phone
/// gets the basic four tabs, a desktop the full sidebar.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    for (final f in Directory('test/fonts').listSync().whereType<File>()) {
      final family = f.uri.pathSegments.last.replaceAll('.ttf', '');
      await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
    }
  });

  const sizes = {
    'desktop 1440': Size(1440, 900),
    'laptop 1280': Size(1280, 800),
    'small desktop 960': Size(960, 700),
    'tablet portrait': Size(820, 1180),
    'iPhone 14': Size(390, 844),
    'small Android': Size(360, 640),
    'iPhone SE (1st gen)': Size(320, 568),
    'phone on its side': Size(844, 390),
  };
  final now = DateTime(2026, 10, 16, 18, 30);

  final reports = <String>[];
  void expectFits(WidgetTester tester, String what) {
    final e = tester.takeException();
    expect(e, isNull, reason: '$what\n${reports.join('\n')}');
  }

  Future<Casino> show(WidgetTester tester, Size size, {Section section = Section.dashboard, String? pin = '1234', Casino? casino}) async {
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
    final c = casino ?? Casino.demo(now: now);
    if (pin != null) c.signIn(pin);
    await tester.pumpWidget(AdminApp(casino: c, initialSection: section));
    await tester.pump(const Duration(milliseconds: 300));
    return c;
  }

  Future<void> clear(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    group(name, () {
      final desktop = size.width >= 900;

      testWidgets('PIN screen fits', (tester) async {
        await show(tester, size, pin: null);
        expect(find.text('Enter your PIN'), findsOneWidget);
        expectFits(tester, 'PIN');
        await clear(tester);
      });

      for (final section in desktop ? Section.values : const [Section.dashboard, Section.players, Section.coins, Section.games]) {
        testWidgets('${section.label} fits', (tester) async {
          await show(tester, size, section: section);
          expectFits(tester, section.label);
          // Scroll to the bottom of the page to lay all of it out.
          final scroll = find.byType(Scrollable).hitTestable();
          if (scroll.evaluate().isNotEmpty) {
            await tester.drag(scroll.first, const Offset(0, -4000));
            await tester.pump(const Duration(milliseconds: 300));
            expectFits(tester, '${section.label} (scrolled)');
          }
          await clear(tester);
        });
      }

      if (!desktop) {
        testWidgets('coins tab: history fits', (tester) async {
          await show(tester, size, section: Section.coins);
          for (final tab in ['History']) {
            await tester.tap(find.textContaining(tab).first);
            await tester.pump(const Duration(milliseconds: 300));
            expectFits(tester, tab);
          }
          await clear(tester);
        });
      }

      testWidgets('forms fit', (tester) async {
        final c = await show(tester, size, section: Section.players);
        final ctx = tester.element(find.byType(AdminShell));
        final forms = <String, Future<void> Function()>{
          'new player': () => showCreatePlayer(ctx),
          'coin in': () => showCoinIn(ctx, player: c.player('Z7-100101')),
          'coin out': () => showCoinOut(ctx, player: c.player('Z7-100101')),
          'bonus': () => showCredit(ctx, c.player('Z7-100101')!, TxnType.bonus),
          'adjust': () => showCredit(ctx, c.player('Z7-100101')!, TxnType.adjust),
          if (desktop) 'bulk create': () => showBulkCreate(ctx),
          if (desktop) 'bet limits': () => showBetLimits(ctx, games.first),
          if (desktop) 'table bet limits': () => showBetLimits(ctx, gameById('blackjack')),
        };
        for (final MapEntry(key: what, value: open) in forms.entries) {
          open();
          await tester.pump(const Duration(milliseconds: 500));
          expectFits(tester, what);
          Navigator.of(tester.element(find.byType(AdminShell))).pop();
          await tester.pump(const Duration(milliseconds: 500));
        }
        await clear(tester);
      });

      testWidgets('player profile fits', (tester) async {
        await show(tester, size, section: Section.players);
        await tester.enterText(find.byType(TextField).first, 'lina');
        await tester.pump();
        await tester.tap(find.text('luckylina').first);
        await tester.pumpAndSettle();
        expect(find.text('Lina Park'), findsWidgets);
        expectFits(tester, 'profile');
        await clear(tester);
      });
    });
  }

  testWidgets('a wrong PIN is refused; the right one opens the panel', (tester) async {
    final c = await show(tester, const Size(390, 844), pin: null);
    for (final d in ['9', '9', '9', '9']) {
      await tester.tap(find.text(d).first);
    }
    await tester.pump();
    expect(find.text('Wrong PIN — try again'), findsOneWidget);
    for (final d in ['2', '5', '8', '0']) {
      await tester.tap(find.text(d).first);
    }
    await tester.pumpAndSettle();
    expect(c.admin?.name, 'Maya');
    expect(find.text('Today'), findsOneWidget);
    await clear(tester);
  });

  testWidgets('a phone gets four tabs; a desktop the full sidebar', (tester) async {
    await show(tester, const Size(390, 844));
    for (final t in ['Home', 'Players', 'Coins', 'Games']) {
      expect(find.bySemanticsLabel(RegExp('^$t(\$|\n)')), findsWidgets, reason: t);
    }
    expect(find.text('Game math'), findsNothing);
    await clear(tester);
    await show(tester, const Size(1440, 900));
    for (final s in Section.values) {
      expect(find.text(s.label), findsWidgets, reason: s.label);
    }
    await clear(tester);
  });

  testWidgets('a cashier only sees home, players and coins', (tester) async {
    await show(tester, const Size(1440, 900), pin: '1111');
    expect(find.text('Coin in / out'), findsWidgets);
    expect(find.text('Reports'), findsNothing);
    expect(find.text('Settings'), findsNothing);
    await clear(tester);
  });

  testWidgets('creating a player ID shows the login to hand over', (tester) async {
    final c = await show(tester, const Size(390, 844), section: Section.players);
    await tester.tap(find.text('New player ID'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, c.suggestUsername()), 'counter7');
    await tester.ensureVisible(find.text('Create player ID'));
    await tester.pump();
    await tester.tap(find.text('Create player ID'));
    await tester.pumpAndSettle();
    expect(find.text('Player ID created'), findsOneWidget);
    final p = c.players.last;
    expect(p.username, 'counter7');
    expect(find.text(p.password), findsOneWidget);
    expect(p.sc, c.settings.newPlayerSc);
    await clear(tester);
  });

  testWidgets('the phone coin pad gives a player coins and takes them off', (tester) async {
    final c = await show(tester, const Size(390, 844), section: Section.coins);
    await tester.tap(find.text('Choose player'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'lina');
    await tester.pump();
    await tester.tap(find.text('luckylina'));
    await tester.pumpAndSettle();
    final p = c.player('Z7-100100')!;
    final before = p.sc;
    for (final d in ['2', '5']) {
      await tester.tap(find.text(d).last);
    }
    await tester.pump();
    expect(find.text('25 SC'), findsOneWidget);
    await tester.tap(find.text('Coin in').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coin in').last); // confirm
    await tester.pumpAndSettle();
    expect(p.sc, closeTo(before + 25, .001));
    expect(c.txns.last.type, TxnType.coinIn);

    // Let the toast go so it doesn't cover the pad.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    for (final d in ['1', '0']) {
      await tester.tap(find.text(d).last);
    }
    await tester.pump();
    await tester.tap(find.text('Coin out').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coin out').last); // confirm
    await tester.pumpAndSettle();
    expect(p.sc, closeTo(before + 15, .001));
    expect(c.txns.last.type, TxnType.coinOut);
    await clear(tester);
  });

  testWidgets('switching a game off in the admin panel closes it in the lobby', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = AppState(casino: Casino.demo(now: now));
    Future<void> lobby() async {
      await tester.pumpWidget(AppScope(
        state: s,
        child: MaterialApp(
          navigatorKey: Nav.navigatorKey,
          builder: (context, child) => ForceLandscape(child: child!),
          home: const Scaffold(body: LobbyPage()),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
    }

    await lobby();
    expect(find.bySemanticsLabel(RegExp('^Roulette — ')), findsOneWidget);
    s.casino.setGameStatus('blackjack', GameStatus.maintenance);
    s.casino.setGameStatus('roulette', GameStatus.hidden);
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('^Roulette — ')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('^Blackjack — under maintenance(\$|\n)')), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('^Blackjack — under maintenance(\$|\n)')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Blackjack is under maintenance. Back soon!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
