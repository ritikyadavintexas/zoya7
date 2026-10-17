import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zoya7_gold/games/blackjack/blackjack_game.dart';
import 'package:zoya7_gold/games/blackjack/engine.dart';
import 'package:zoya7_gold/games/gold/src/math.dart' show Currency;

class _Wallet implements BlackjackWallet {
  final b = {Currency.gc: 125000.0, Currency.sc: 250.5};
  @override
  double balance(Currency c) => b[c]!;
  @override
  void add(Currency c, double amount) => b[c] = b[c]! + amount;
}

PlayingCard c(String s) {
  final rank = switch (s.substring(0, s.length - 1)) {
    'A' => 1,
    'T' => 10,
    'J' => 11,
    'Q' => 12,
    'K' => 13,
    final n => int.parse(n),
  };
  final suit = switch (s[s.length - 1]) { 's' => Suit.spades, 'h' => Suit.hearts, 'd' => Suit.diamonds, _ => Suit.clubs };
  return PlayingCard(rank, suit);
}

Shoe stacked(String cards) => Shoe.stacked(cards.split(' ').map(c).toList());

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    for (final f in Directory('test/fonts').listSync().whereType<File>()) {
      final family = f.uri.pathSegments.last.replaceAll('.ttf', '');
      await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
    }
  });

  Future<_Wallet> open(WidgetTester tester, String cards, {Size size = const Size(844, 390)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final w = _Wallet();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: BlackjackGame(wallet: w, shoe: stacked(cards), pace: const Duration(milliseconds: 10))),
    ));
    await tester.pump();
    return w;
  }

  Future<void> tap(WidgetTester tester, String label) async {
    // Labels may carry the button's text after them.
    await tester.tap(find.bySemanticsLabel(RegExp('^${RegExp.escape(label)}(\$|\n)')).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('bet, deal, double down and win: the wallet pays out', (tester) async {
    final w = await open(tester, '6s 6d 5h Tc Ks 9c');
    await tap(tester, 'Add 5K GC chip');
    expect(find.text('5,000 GC'), findsOneWidget);
    await tap(tester, 'DEAL');
    expect(w.b[Currency.gc], 120000);
    await tap(tester, 'DOUBLE');
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('YOU WIN +10,000 GC'), findsOneWidget);
    expect(w.b[Currency.gc], 135000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('insurance prompt, then split into two hands', (tester) async {
    final w = await open(tester, '8s Ad 8h 6c 3s Kd Tc');
    await tap(tester, 'Add 1K GC chip');
    await tap(tester, 'DEAL');
    expect(find.text('Dealer shows an Ace — insurance?'), findsOneWidget);
    await tap(tester, 'NO THANKS');
    await tap(tester, 'SPLIT');
    expect(find.text('HAND 1'), findsOneWidget);
    expect(find.text('HAND 2'), findsOneWidget);
    expect(w.b[Currency.gc], 123000);
    await tap(tester, 'STAND'); // 8+3 = 11
    await tap(tester, 'STAND'); // 8+K = 18
    await tester.pump(const Duration(seconds: 1)); // dealer A+6 = soft 17, stands
    expect(find.text('LOSE'), findsOneWidget);
    expect(find.text('WIN'), findsOneWidget);
    expect(w.b[Currency.gc], 125000); // lost 1K, won 1K
    expect(tester.takeException(), isNull);
  });

  testWidgets('DC table and a blackjack paying 3 to 2', (tester) async {
    final w = await open(tester, 'As 9d Kh 7c');
    await tap(tester, 'Play with DC');
    await tap(tester, 'Add 5 DC chip');
    await tap(tester, 'DEAL');
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('BLACKJACK! +7.50'), findsOneWidget);
    expect(w.b[Currency.sc], 258.0);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(568, 320), Size(844, 390), Size(1180, 820)]) {
    testWidgets('a four-hand split fits at $size', (tester) async {
      // Each split's first hand is dealt another 8, so it can split again.
      await open(tester, '8s 9d 8h 7c 8c 2s 8d 3s 4s 5s', size: size);
      await tap(tester, 'Add 500 GC chip');
      await tap(tester, 'DEAL');
      await tap(tester, 'SPLIT');
      await tap(tester, 'SPLIT');
      await tap(tester, 'SPLIT');
      expect(find.text('HAND 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
