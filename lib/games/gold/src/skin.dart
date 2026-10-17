import 'package:flutter/widgets.dart';

import 'assets.dart';
import 'math.dart';
import 'style.dart';

/// How a slot on the Gold engine looks. Classic 777, Fruit Spin and Phoenix
/// Ruby share the reels, pays and jackpots ([GoldRules]); a skin only swaps the
/// artwork, colours and where its frame's reel windows are, so each symbol
/// keeps its pay. Each has its own music and sound effects, and may swap the
/// buttons, jackpot plaques and win banners too (docs/GAME.md).
class SlotSkin {
  const SlotSkin({
    required this.name,
    required this.background,
    this.art = const {},
    this.labels = const {},
    this.reelFrame,
    this.reelCols = const [(11.1, 24.6), (37.8, 24.4), (64.3, 24.7)],
    this.reelTop = .25,
    this.reelHeight = .573,
    this.sounds = 'assets/games/gold/sounds',
    this.musicLoop = 30,
    this.extraSounds = const {},
    this.backgroundImage,
    this.overrides = const {},
  });

  final String name;

  /// Page glow, centre to edge.
  final List<Color> background;

  /// Symbol artwork that differs from Classic 777's.
  final Map<Sym, String> art;

  /// What a symbol is called (screen readers).
  final Map<Sym, String> labels;
  final String? reelFrame;

  /// The frame's three reel windows: left edge and width (% of the frame's
  /// width), and their top and height (share of its height). The payline runs
  /// across the middle.
  final List<(double, double)> reelCols;
  final double reelTop, reelHeight;

  /// Folder of the game's sounds: `music` (.mp3 and .ogg, [musicLoop] seconds
  /// long), `spin`, `reel_stop`, `win_small`, `win_big`, `jackpot`, and any of
  /// [extraSounds] (`button`, `collect`), all .mp3.
  final String sounds;
  final double musicLoop;
  final Set<String> extraSounds;

  /// Full-screen backdrop, over the [background] glow.
  final String? backgroundImage;

  /// The skin's own versions of Classic 777's buttons, jackpot plaques and win
  /// banners, by [GoldAssets] path.
  final Map<String, String> overrides;

  String symbol(Sym s) => art[s] ?? GoldAssets.symbol(s);
  String label(Sym s) => labels[s] ?? s.name;
  String get frame => reelFrame ?? GoldAssets.reelFrame;
  String asset(String goldAsset) => overrides[goldAsset] ?? goldAsset;
  String sound(String name) => '$sounds/$name.mp3';
  List<String> get effects => [for (final n in ['spin', 'reel_stop', 'win_small', 'win_big', 'jackpot', ...extraSounds]) sound(n)];
  List<String> get assets => [
        for (final s in Sym.values) symbol(s),
        frame,
        if (backgroundImage != null) backgroundImage!,
        ...overrides.values,
      ];

  static const classic = SlotSkin(name: 'Classic 777', background: [GC.bgHot, GC.bgMid, GC.bgDeep]);

  static const _fruit = 'assets/games/fruit';

  /// All fruit (plus the bell and diamond of its lobby art) on emerald green.
  static const fruit = SlotSkin(
    name: 'Fruit Spin',
    background: [Color(0xFF2E8B3E), Color(0xFF0E4A20), Color(0xFF03180A)],
    reelFrame: '$_fruit/reel_frame.png',
    sounds: '$_fruit/sounds',
    musicLoop: 1512000 / 44100,
    art: {
      Sym.seven: '$_fruit/sym_grapes.png',
      Sym.diamond: '$_fruit/sym_strawberry.png',
      Sym.crown: '$_fruit/sym_pineapple.png',
      Sym.bar: '$_fruit/sym_apple.png',
      Sym.star: 'assets/games/gold/sym_diamond.png',
    },
    labels: {Sym.seven: 'grapes', Sym.diamond: 'strawberry', Sym.crown: 'pineapple', Sym.bar: 'apple', Sym.star: 'diamond'},
  );

  static const _phoenix = 'assets/games/phoenix';

  /// Phoenix Ruby: fire gems and the phoenix on crimson, in its own ember frame.
  static const phoenix = SlotSkin(
    name: 'Phoenix Ruby',
    background: [Color(0xFF8A2A12), Color(0xFF3D0B12), Color(0xFF120408)],
    reelFrame: '$_phoenix/reel_frame.png',
    reelCols: [(10.6, 24.3), (38.2, 23.6), (65.2, 24.3)],
    reelTop: .155,
    reelHeight: .63,
    sounds: '$_phoenix/sounds',
    musicLoop: 1840696 / 44100,
    art: {
      Sym.seven: '$_phoenix/sym_seven.png',
      Sym.diamond: '$_phoenix/sym_phoenix.png',
      Sym.crown: '$_phoenix/sym_crown.png',
      Sym.bar: '$_phoenix/sym_coin.png',
      Sym.star: '$_phoenix/sym_ruby.png',
      Sym.bell: '$_phoenix/sym_sun.png',
      Sym.melon: '$_phoenix/sym_star.png',
      Sym.plum: '$_phoenix/sym_lotus.png',
      Sym.orange: '$_phoenix/sym_feather.png',
      Sym.lemon: '$_phoenix/sym_amber.png',
      Sym.cherry: '$_phoenix/sym_amethyst.png',
    },
    labels: {
      Sym.seven: 'golden seven',
      Sym.diamond: 'phoenix crest',
      Sym.crown: 'ember crown',
      Sym.bar: 'phoenix coin',
      Sym.star: 'ruby',
      Sym.bell: 'sun orb',
      Sym.melon: 'ember star',
      Sym.plum: 'fire lotus',
      Sym.orange: 'phoenix feather',
      Sym.lemon: 'amber',
      Sym.cherry: 'amethyst',
    },
  );

  /// The look of each slot game, by its id.
  static SlotSkin forGame(String gameId) => switch (gameId) {
        'fruitspin' => fruit,
        'phoenixruby' => phoenix,
        _ => classic,
      };

  /// The skin of the game being played (Classic 777 outside a game).
  static SlotSkin of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SkinScope>()?.skin ?? classic;
}

class SkinScope extends InheritedWidget {
  const SkinScope({super.key, required this.skin, required super.child});
  final SlotSkin skin;

  @override
  bool updateShouldNotify(SkinScope old) => old.skin != skin;
}
