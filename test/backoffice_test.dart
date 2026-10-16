import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zoya7_gold/backoffice/casino.dart';
import 'package:zoya7_gold/backoffice/slot_math.dart';
import 'package:zoya7_gold/games/blackjack/engine.dart';
import 'package:zoya7_gold/games/gold/src/math.dart';

void main() {
  final now = DateTime(2026, 10, 16, 18, 30);
  Casino demo() => Casino.demo(now: now)..signIn('1234');

  group('demo data', () {
    test('has players, history and the app player on its starting balances', () {
      final c = demo();
      expect(c.players.length, 24);
      expect(c.me.gc, 125000);
      expect(c.me.sc, 250.5);
      expect(c.players.every((p) => p.sc >= 0 && p.gc >= 0), isTrue);
      expect(c.txns.where((t) => t.type == TxnType.cashIn).length, greaterThan(50));
      expect(c.pendingCashOuts, isNotEmpty);
    });

    test('every report balances: starting amount + money in − money out ± play = ending amount', () {
      final c = demo();
      for (final p in Period.standard(now)) {
        final r = c.report(p);
        final sc = r.openSc + r.cashInSc + r.startSc + r.bonusSc + r.adjustSc - r.cashOutSc + (r.wonSc - r.wageredSc);
        final gc = r.openGc + r.cashInGc + r.startGc + r.bonusGc + r.adjustGc + (r.wonGc - r.wageredGc);
        expect(sc, closeTo(r.closeSc, .05), reason: p.label);
        expect(gc, closeTo(r.closeGc, 1), reason: p.label);
      }
      final all = c.report(Period.standard(now).last);
      expect(all.openSc, closeTo(0, .01));
      expect(all.closeSc, closeTo(c.players.fold<double>(0, (a, p) => a + p.sc), .01));
    });

    test('survives a save and load', () {
      final c = demo();
      final back = Casino.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(back.players.length, c.players.length);
      expect(back.txns.length, c.txns.length);
      expect(back.config('classic777').rtp, closeTo(c.config('classic777').rtp, 1e-9));
      expect(back.report(Period.standard(now)[3]).cashInUsd, c.report(Period.standard(now)[3]).cashInUsd);
    });
  });

  group('players and cash', () {
    test('a new player ID gets the starting amount from settings', () {
      final c = demo();
      c.updateSettings('start', (s) => s
        ..newPlayerGc = 20000
        ..newPlayerSc = 5);
      final p = c.createPlayer(username: 'newbie');
      expect(p.id, startsWith('Z7-'));
      expect(p.password.length, 8);
      expect((p.gc, p.sc), (20000, 5));
      expect(c.txnsOf(p.id).single.type, TxnType.start);
      expect(() => c.createPlayer(username: 'NEWBIE'), throwsA(isA<CasinoError>()));
      expect(c.audit.last.by, 'Owner');
    });

    test('bulk create skips taken names', () {
      final c = demo();
      c.createPlayer(username: 'shop002');
      final made = c.bulkCreate(3, 'shop');
      expect(made.map((p) => p.username), ['shop001', 'shop003', 'shop004']);
    });

    test('cash in buys coins at the set rate and bonus', () {
      final c = demo();
      final p = c.createPlayer(username: 'payer', startGc: 0, startSc: 0);
      c.updateSettings('bonus', (s) => s.cashInBonusPct = 10);
      c.cashIn(p, 20, method: 'Cash');
      expect(p.sc, 22);
      expect(p.gc, 220000);
      expect(() => c.cashIn(p, 5000), throwsA(isA<CasinoError>()));
    });

    test('cash out holds SC until approved; rejecting gives it back', () {
      final c = demo();
      final p = c.createPlayer(username: 'winner', startGc: 0, startSc: 300);
      final t = c.cashOut(p, 100);
      expect(t.status, TxnStatus.pending);
      expect(p.sc, 200);
      c.reject(t, reason: 'ID check');
      expect(p.sc, 300);
      final t2 = c.cashOut(p, 120);
      c.approve(t2);
      expect(t2.settledBy, 'Owner');
      expect(p.sc, 180);
      expect(() => c.cashOut(p, 20), throwsA(isA<CasinoError>())); // under the minimum
      expect(() => c.cashOut(p, 500), throwsA(isA<CasinoError>())); // more than they have
    });

    test('a shift expects its starting amount plus cash in minus cash out', () {
      final c = demo();
      final p = c.createPlayer(username: 'drawer', startGc: 0, startSc: 500);
      final s = c.startShift(150);
      c.cashIn(p, 40, method: 'Cash');
      c.cashIn(p, 25, method: 'Cash App');
      c.cashOut(p, 60, method: 'Cash', review: false);
      final sum = c.summary(s);
      expect(sum.cashIn, 65);
      expect(sum.drawerIn, 40);
      expect(sum.drawerOut, 60);
      expect(sum.expected, 130);
      c.closeShift(s, 125);
      expect(c.summary(s).difference, -5);
    });
  });

  group('math', () {
    test('the slot solver hits the target RTP', () {
      for (final target in [.85, .9, .95, .97]) {
        final w = SlotMath.solve(target);
        expect(SlotMath(w).rtp, closeTo(target, .002), reason: '$target');
      }
    });

    test('simulated spins agree with the computed RTP', () {
      final w = SlotMath.solve(.95);
      final math = LocalGoldMath(weights: w, random: Random(3));
      var paid = 0.0;
      const n = 200000;
      final noJackpots = {for (final t in JackpotTier.values) t: 0.0};
      for (var i = 0; i < n; i++) {
        final grid = [for (var r = 0; r < 3; r++) [math.fillerSymbol(), math.fillerSymbol(), math.fillerSymbol()]];
        paid += GoldRules.evaluate(grid, 1, noJackpots).win;
      }
      expect(paid / n, closeTo(SlotMath(w).rtp, .02));
    });

    test('blackjack rules change the house edge the expected way', () {
      const base = BjRules();
      expect(base.houseEdge, closeTo(.0042, 1e-6));
      expect(base.copyWith(blackjackPays: 1.2).houseEdge, greaterThan(base.houseEdge + .013));
      expect(base.copyWith(hitSoft17: true).houseEdge, greaterThan(base.houseEdge));
      expect(base.copyWith(decks: 1).houseEdge, lessThan(base.houseEdge));
    });
  });
}
