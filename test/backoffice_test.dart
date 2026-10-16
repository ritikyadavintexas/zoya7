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
      expect(c.txns.where((t) => t.type == TxnType.coinIn).length, greaterThan(50));
      expect(c.txns.where((t) => t.type == TxnType.coinOut), isNotEmpty);
    });

    test('every report balances: starting amount + coin in − coin out ± play = ending amount', () {
      final c = demo();
      for (final p in Period.standard(now)) {
        final r = c.report(p);
        final sc = r.openSc + r.coinInSc + r.startSc + r.bonusSc + r.adjustSc - r.coinOutSc + (r.wonSc - r.wageredSc);
        final gc = r.openGc + r.coinInGc + r.startGc + r.bonusGc + r.adjustGc - r.coinOutGc + (r.wonGc - r.wageredGc);
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
      expect(back.report(Period.standard(now)[3]).coinInSc, c.report(Period.standard(now)[3]).coinInSc);
    });
  });

  group('players and coins', () {
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

    test('coin in adds coins, up to the daily limit', () {
      final c = demo();
      final p = c.createPlayer(username: 'loaded', startGc: 0, startSc: 0);
      c.updateSettings('limit', (s) => s.maxCoinInPerDay = 100);
      final t = c.coinIn(p, sc: 60, gc: 600000, note: 'Promo');
      expect((p.sc, p.gc), (60, 600000));
      expect((t.type, t.by, t.note), (TxnType.coinIn, 'Owner', 'Promo'));
      expect(() => c.coinIn(p, sc: 50), throwsA(isA<CasinoError>())); // over 100 SC today
      expect(() => c.coinIn(p), throwsA(isA<CasinoError>())); // nothing to add
      c.setPlayerStatus(p, PlayerStatus.suspended);
      expect(() => c.coinIn(p, sc: 1), throwsA(isA<CasinoError>()));
    });

    test('coin out takes coins off at once, never below zero', () {
      final c = demo();
      final p = c.createPlayer(username: 'spender', startGc: 1000, startSc: 300);
      c.coinOut(p, sc: 120, gc: 400);
      expect((p.sc, p.gc), (180, 600));
      expect(() => c.coinOut(p, sc: 500), throwsA(isA<CasinoError>()));
      expect(() => c.coinOut(p, gc: 601), throwsA(isA<CasinoError>()));
      final r = c.report(Period.standard(now).first);
      expect(r.coinOutSc, greaterThanOrEqualTo(120));
      expect(r.players[p.id]!.coinOutSc, 120);
      expect(r.players[p.id]!.netSc, -120);
    });

    test('older ledger lines with money fields still load; a turned-down one moves nothing', () {
      final t = Txn.fromJson({'id': 'T1', 'p': 'Z7-1', 't': 2, 'at': 0, 'usd': 50, 'gc': 0, 'sc': -50, 'm': 'Bank', 's': 2});
      expect((t.type, t.sc), (TxnType.coinOut, 0));
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
