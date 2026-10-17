import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zoya7_gold/games/gold/src/math.dart';
import 'package:zoya7_gold/games/gold/src/skin.dart';

void main() {
  const jp = {
    JackpotTier.mega: 5000000.0,
    JackpotTier.major: 500000.0,
    JackpotTier.minor: 50000.0,
    JackpotTier.mini: 10000.0,
  };
  List<List<Sym>> line(Sym a, Sym b, Sym c) => [
        [Sym.lemon, a, Sym.plum],
        [Sym.lemon, b, Sym.plum],
        [Sym.lemon, c, Sym.plum],
      ];

  test('three stars pay 30x', () {
    final o = GoldRules.evaluate(line(Sym.star, Sym.star, Sym.star), 1000, jp);
    expect(o.multiplier, 30);
    expect(o.win, 30000);
    expect(GoldRules.tierFor(o.multiplier, o.jackpot), WinTier.mega);
  });

  test('two cherries pay 2x', () {
    final o = GoldRules.evaluate(line(Sym.cherry, Sym.bell, Sym.cherry), 5000, jp);
    expect(o.win, 10000);
    expect(GoldRules.tierFor(o.multiplier, o.jackpot), isNull);
  });

  test('three sevens hit the mega jackpot', () {
    final o = GoldRules.evaluate(line(Sym.seven, Sym.seven, Sym.seven), 5000, jp);
    expect(o.jackpot, JackpotTier.mega);
    expect(o.win, 5000000);
  });

  test('no match pays nothing', () {
    final o = GoldRules.evaluate(line(Sym.bell, Sym.plum, Sym.star), 5000, jp);
    expect(o.win, 0);
  });

  test('Fruit Spin shows fruit where Classic 777 shows 7, BAR, crown and star; every image exists', () {
    for (final skin in [SlotSkin.classic, SlotSkin.fruit, SlotSkin.phoenix]) {
      for (final a in skin.assets) {
        expect(File(a).existsSync(), isTrue, reason: '${skin.name}: $a');
      }
    }
    for (final s in [Sym.seven, Sym.bar, Sym.crown, Sym.star]) {
      expect(SlotSkin.fruit.symbol(s), isNot(SlotSkin.classic.symbol(s)));
    }
    expect(SlotSkin.fruit.frame, isNot(SlotSkin.classic.frame));
    expect(Sym.values.map(SlotSkin.fruit.symbol).toSet(), hasLength(Sym.values.length));
  });

  test('Phoenix Ruby has its own art for all 11 symbols and its own frame', () {
    expect(SlotSkin.forGame('phoenixruby'), same(SlotSkin.phoenix));
    expect(Sym.values.map(SlotSkin.phoenix.symbol).toSet(), hasLength(Sym.values.length));
    expect(Sym.values.every((s) => SlotSkin.phoenix.symbol(s).startsWith('assets/games/phoenix/')), isTrue);
    expect(SlotSkin.phoenix.reelCols, hasLength(3));
  });
}
