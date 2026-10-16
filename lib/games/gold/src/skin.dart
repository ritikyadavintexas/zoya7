import 'package:flutter/widgets.dart';

import 'assets.dart';
import 'math.dart';
import 'style.dart';

/// How a slot on the Gold engine looks. Classic 777 and Fruit Spin share the
/// reels, pays and jackpots ([GoldRules]); a skin only swaps the artwork and
/// colours, so each symbol keeps its pay.
class SlotSkin {
  const SlotSkin({required this.name, required this.background, this.art = const {}, this.labels = const {}, this.reelFrame});

  final String name;

  /// Page glow, centre to edge.
  final List<Color> background;

  /// Symbol artwork that differs from Classic 777's.
  final Map<Sym, String> art;

  /// What a symbol is called (screen readers).
  final Map<Sym, String> labels;
  final String? reelFrame;

  String symbol(Sym s) => art[s] ?? GoldAssets.symbol(s);
  String label(Sym s) => labels[s] ?? s.name;
  String get frame => reelFrame ?? GoldAssets.reelFrame;
  List<String> get assets => [for (final s in Sym.values) symbol(s), frame];

  static const classic = SlotSkin(name: 'Classic 777', background: [GC.bgHot, GC.bgMid, GC.bgDeep]);

  static const _fruit = 'assets/games/fruit';

  /// All fruit (plus the bell and diamond of its lobby art) on emerald green.
  static const fruit = SlotSkin(
    name: 'Fruit Spin',
    background: [Color(0xFF2E8B3E), Color(0xFF0E4A20), Color(0xFF03180A)],
    reelFrame: '$_fruit/reel_frame.png',
    art: {
      Sym.seven: '$_fruit/sym_grapes.png',
      Sym.diamond: '$_fruit/sym_strawberry.png',
      Sym.crown: '$_fruit/sym_pineapple.png',
      Sym.bar: '$_fruit/sym_apple.png',
      Sym.star: 'assets/games/gold/sym_diamond.png',
    },
    labels: {Sym.seven: 'grapes', Sym.diamond: 'strawberry', Sym.crown: 'pineapple', Sym.bar: 'apple', Sym.star: 'diamond'},
  );

  /// The skin of the game being played (Classic 777 outside a game).
  static SlotSkin of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SkinScope>()?.skin ?? classic;
}

class SkinScope extends InheritedWidget {
  const SkinScope({super.key, required this.skin, required super.child});
  final SlotSkin skin;

  @override
  bool updateShouldNotify(SkinScope old) => old.skin != skin;
}
