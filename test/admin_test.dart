import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zoya7_gold/admin/admin_app.dart';
import 'package:zoya7_gold/admin/coins.dart';
import 'package:zoya7_gold/admin/games.dart' show showBetLimits;
import 'package:zoya7_gold/admin/kit.dart' show K, lockAdmin;
import 'package:zoya7_gold/admin/players.dart';
import 'package:zoya7_gold/app/assets.dart';
import 'package:zoya7_gold/app/landscape.dart';
import 'package:zoya7_gold/app/nav.dart';
import 'package:zoya7_gold/app/screens/lobby.dart';
import 'package:zoya7_gold/app/state.dart';
import 'package:zoya7_gold/app/web_safe_area.dart' show debugKeyboard;
import 'package:zoya7_gold/backoffice/auth.dart';
import 'package:zoya7_gold/backoffice/casino.dart';
import 'package:zoya7_gold/backoffice/sync.dart';

import 'fake_firebase.dart';

/// The admin panel at desktop, tablet and phone sizes (portrait first, and a
/// phone on its side): every page lays out with nothing overflowing, a phone
/// gets four tabs and More, a desktop the full sidebar.
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

  Future<Casino> show(WidgetTester tester, Size size, {Section section = Section.dashboard, String? uid = 'owner', Casino? casino, CasinoSync? sync}) async {
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
    if (uid != null) c.signIn(uid);
    await tester.pumpWidget(AdminApp(casino: c, sync: sync, initialSection: section));
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

      testWidgets('sign-in screen fits', (tester) async {
        await show(tester, size, uid: null);
        expect(find.text('Continue'), findsWidgets);
        expectFits(tester, 'sign in');
        await clear(tester);
      });

      for (final (uid, sections) in [
        ('owner', Section.values),
        ('maya', const [Section.dashboard, Section.team, Section.players]),
        ('leo', const [Section.dashboard, Section.players, Section.coins, Section.team]),
      ]) {
        for (final section in sections) {
        testWidgets('${section.label} fits${uid == 'owner' ? '' : ' ($uid)'}', (tester) async {
          await show(tester, size, section: section, uid: uid);
          expectFits(tester, '${section.label} ($uid)');
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
      }

      if (!desktop) {
        testWidgets('coins tab: history fits', (tester) async {
          await show(tester, size, section: Section.coins, uid: 'leo');
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

  testWidgets('staff sign in with username and password; a wrong password or a non-staff account is refused', (tester) async {
    final db = FakeFirebase();
    final auth = FirebaseAuthApi(post: db.post);
    final owner = await auth.signUp(staffEmail('bhanu2357'), 'secret77');
    await auth.signUp(staffEmail('stranger'), 'secret77');
    db.tree = {
      'staff': {
        owner.uid: {'n': 'Bhanu', 'r': 0, 'u': 'bhanu2357'},
      },
    };
    final c = Casino.empty();
    final sync = CasinoSync(c, transport: db.call, auth: FirebaseAuthApi(post: db.post), autoSync: false, storagePrefix: 'admin.test');
    await sync.connect(FakeFirebase.host);
    await show(tester, const Size(390, 844), uid: null, casino: c, sync: sync);
    // A KField's label sits above its text box.
    Future<void> type(String label, String text) => tester.enterText(
        find.descendant(of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first, matching: find.byType(TextField)),
        text);
    Future<void> press(String label) async {
      await tester.ensureVisible(find.text(label).last);
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    expect(find.textContaining('First time'), findsNothing);
    await type('Username', 'stranger');
    await type('Password', 'secret77');
    await press('Continue');
    expect(c.admin, isNull);

    await type('Username', 'bhanu2357');
    await type('Password', 'wrong-one');
    await press('Continue');
    expect(find.text('Wrong username or password'), findsOneWidget);
    await type('Password', 'secret77');
    await press('Continue');
    expect(c.admin?.name, 'Bhanu');
    expect(find.text('Today'), findsOneWidget);

    lockAdmin(c, sync);
    await tester.pumpAndSettle();
    expect(c.admin, isNull);
    expect(find.text('Continue'), findsWidgets);
    await clear(tester);
  });

  testWidgets('under an iPhone status bar the strip is the panel’s light grey and pages start below it', (tester) async {
    tester.view.padding = const FakeViewPadding(top: 47);
    addTearDown(tester.view.resetPadding);
    await show(tester, const Size(390, 844), uid: null);
    final band = tester.widget<ColoredBox>(find.descendant(of: find.byType(StatusBand), matching: find.byType(ColoredBox)).first);
    expect(band.color, K.bg);
    expect(tester.getTopLeft(find.byType(SignInGate)).dy, 47);
    await clear(tester);
  });

  testWidgets('sign-in boxes sit above an upright phone keyboard, and Return goes on', (tester) async {
    tester.view.padding = const FakeViewPadding(top: 47);
    addTearDown(tester.view.resetPadding);
    await show(tester, const Size(390, 844), uid: null);
    // The iPhone keyboard and its bar cover the lower ~400 px.
    for (final f in find.byType(TextField).evaluate()) {
      expect(tester.getRect(find.byWidget(f.widget)).bottom, lessThan(844 - 400));
    }
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.map((f) => f.textInputAction), [TextInputAction.next, TextInputAction.go]);
    await clear(tester);
  });

  testWidgets('with the phone keyboard up, a sheet’s field stays in view above it', (tester) async {
    addTearDown(() => debugKeyboard.value = 0);
    await show(tester, const Size(390, 844), section: Section.team);
    await tester.tap(find.text('Give').first);
    await tester.pumpAndSettle();
    final note = find.byType(TextField).last;
    await tester.tap(note);
    await tester.pump();
    debugKeyboard.value = 380; // an iPhone keyboard and its bar
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getRect(note).bottom, lessThanOrEqualTo(844 - 380));
    expect(tester.getRect(note).top, greaterThanOrEqualTo(0));
    debugKeyboard.value = 0;
    await tester.pumpAndSettle();
    await clear(tester);
  });

  testWidgets('a phone gets four tabs and More (everything else, each page fitting); a desktop the full sidebar', (tester) async {
    await show(tester, const Size(390, 844));
    for (final t in ['Home', 'Players', 'Coins', 'Team', 'More']) {
      expect(find.bySemanticsLabel(RegExp('^$t(\$|\n)')), findsWidgets, reason: t);
    }
    expect(find.text('Game math'), findsNothing);
    for (final s in [Section.games, Section.reports, Section.math, Section.settings]) {
      await tester.tap(find.bySemanticsLabel(RegExp('^(More|${Section.values.map((x) => x.tab).join('|')})(\$|\n)')).last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, s.label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: s.label);
      expect(find.bySemanticsLabel(RegExp('^${s.tab}(\$|\n)')), findsWidgets, reason: 'the More tab shows ${s.label}');
    }
    await clear(tester);
    await show(tester, const Size(1440, 900));
    for (final s in Section.values) {
      expect(find.text(s.label), findsWidgets, reason: s.label);
    }
    await clear(tester);
  });

  testWidgets('an agent sees home, their players, coin in / out and referrals; an executive their team', (tester) async {
    await show(tester, const Size(1440, 900), uid: 'leo');
    expect(find.text('Coin in / out'), findsWidgets);
    expect(find.text('Team'), findsWidgets);
    for (final t in ['Reports', 'Settings', 'Games', 'Game math']) {
      expect(find.text(t), findsNothing, reason: t);
    }
    await clear(tester);
    await show(tester, const Size(1440, 900), uid: 'maya', section: Section.team);
    expect(find.text('Leo'), findsWidgets);
    expect(find.text('Give'), findsWidgets);
    expect(find.text('Coin in / out'), findsNothing);
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
    expect(find.text('Copy the password now — it can’t be shown again'), findsOneWidget);
    expect(c.uids.values, contains(p.id));
    expect(p.sc, c.settings.newPlayerSc);
    await clear(tester);
  });

  testWidgets('the phone coin pad gives a player coins and takes them off, from the agent’s points', (tester) async {
    final demo = Casino.demo(now: now);
    demo.player('Z7-100100')!.agent = 'leo';
    final c = await show(tester, const Size(390, 844), section: Section.coins, uid: 'leo', casino: demo);
    final leo = c.staffBy('leo')!;
    final points = leo.sc;
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
    expect(find.text('25 DC'), findsOneWidget);
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
    expect(leo.sc, closeTo(points - 15, .001));
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
