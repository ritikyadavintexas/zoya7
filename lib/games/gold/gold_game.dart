/// Zoya7 — the Gold slot engine, dressed as Classic 777 or Fruit Spin ([SlotSkin]).
///
/// Drop [GoldGame] into any route. It renders the 1920×1080 design and scales
/// it to fit the screen (phone, tablet or desktop), keeping the design exact.
library;

import 'package:flutter/material.dart';

import 'src/assets.dart';
import 'src/controller.dart';
import 'src/math.dart';
import 'src/skin.dart';
import 'src/style.dart';
import 'src/widgets/footer.dart';
import 'src/widgets/fx.dart';
import 'src/widgets/header.dart';
import 'src/widgets/modals.dart';
import 'src/widgets/reels.dart';
import 'src/widgets/side_panels.dart';
import 'src/widgets/win_overlay.dart';

export 'src/controller.dart' show GoldAudio, GoldPanel, ChatMessage, GoldController;
export 'src/math.dart';
export 'src/skin.dart' show SlotSkin;

class GoldGame extends StatefulWidget {
  const GoldGame({
    super.key,
    this.outcomes,
    this.audio,
    this.initialGc = 1250000,
    this.initialSc = 125.5,
    this.currency = Currency.gc,
    this.previewOverlay,
    this.previewPanel = GoldPanel.none,
    this.onExitToLobby,
    this.onBuyCoins,
    this.onOpenPlayLimits,
    this.minBetIdx = 0,
    this.maxBetIdx = GoldRules.maxBetIndex,
    this.skin = SlotSkin.classic,
    this.sfx = true,
    this.music = true,
    this.gc = true,
  });

  /// Gold Coins on (the owner can switch them off: then DC only).
  final bool gc;

  /// The player's Sound effects and Music settings when the game opens.
  final bool sfx;
  final bool music;

  /// Classic 777 or Fruit Spin.
  final SlotSkin skin;

  /// Bet steps offered (indexes into [GoldRules.bets]).
  final int minBetIdx;
  final int maxBetIdx;

  /// Spin results. Plug your server math engine in here; defaults to [LocalGoldMath].
  final GoldOutcomeSource? outcomes;
  final GoldAudio? audio;
  final double initialGc;
  final double initialSc;
  final Currency currency;

  /// Open a design state directly (matches the design boards:
  /// Big/Super/Mega/Jackpot win, Paytable, Settings, Not enough coins).
  final WinTier? previewOverlay;
  final GoldPanel previewPanel;

  /// Back arrow and "EXIT TO LOBBY". Defaults to popping the route.
  final VoidCallback? onExitToLobby;

  /// "+" on a balance bar and "BUY COINS".
  final ValueChanged<Currency>? onBuyCoins;

  /// "PLAY LIMITS" in settings.
  final VoidCallback? onOpenPlayLimits;

  @override
  State<GoldGame> createState() => _GoldGameState();
}

class _GoldGameState extends State<GoldGame> {
  late final GoldController c = GoldController(
    outcomes: widget.outcomes,
    audio: widget.audio,
    initialGc: widget.initialGc,
    initialSc: widget.initialSc,
    currency: widget.currency,
    previewOverlay: widget.previewOverlay,
    previewPanel: widget.previewPanel,
    minBetIdx: widget.minBetIdx,
    maxBetIdx: widget.maxBetIdx,
    sfx: widget.sfx,
    music: widget.music,
    gcAllowed: widget.gc,
  );

  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      for (final a in {...GoldAssets.all, ...widget.skin.assets}) {
        precacheImage(AssetImage(a), context);
      }
    }
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  void _exit() {
    if (widget.onExitToLobby != null) {
      widget.onExitToLobby!();
    } else {
      Navigator.maybePop(context);
    }
  }

  void _buy(Currency cur) => widget.onBuyCoins?.call(cur);

  @override
  Widget build(BuildContext context) {
    // The page background spans the whole screen so letterboxing on 4:3 iPads
    // and tall phones blends into the design's radial glow.
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: ellipseGradient(
          cx: .5,
          cy: .48,
          rx: .72,
          ry: .62,
          colors: widget.skin.background,
          stops: const [0, .52, 1],
        ),
        image: widget.skin.backgroundImage == null
            ? null
            : DecorationImage(image: AssetImage(widget.skin.backgroundImage!), fit: BoxFit.cover),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                // Match the screen's shape: the header and footer spread across
                // the extra width of a 19.5:9 phone instead of leaving bands.
                width: (kDesignH * box.maxWidth / box.maxHeight).clamp(kDesignW, kDesignMaxW),
                height: kDesignH,
                child: SkinScope(
                  skin: widget.skin,
                  child: DefaultTextStyle(
                    style: rubik(16),
                    child: ListenableBuilder(listenable: c, builder: (context, _) => _canvas()),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _canvas() {
    return Stack(children: [
      Column(children: [
        GoldHeader(c: c, onBack: _exit, onGetMore: _buy),
        SizedBox(
          height: 656,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const JackpotCombos(),
                const SizedBox(width: 22),
                GoldReels(c: c),
                const SizedBox(width: 22),
                LinePays(onFullPaytable: c.openPaytable),
              ],
            ),
          ),
        ),
        Expanded(child: GoldFooter(c: c)),
      ]),
      if (c.panel == GoldPanel.paytable)
        Positioned.fill(child: ModalScrim(opacity: .82, label: 'Paytable', child: PaytableModal(c: c))),
      if (c.panel == GoldPanel.settings)
        Positioned.fill(
          child: ModalScrim(
            opacity: .82,
            label: 'Game settings',
            child: SettingsModal(
              c: c,
              onPlayLimits: widget.onOpenPlayLimits ?? () {},
              onExit: _exit,
            ),
          ),
        ),
      if (c.panel == GoldPanel.noCoins)
        Positioned.fill(
          child: ModalScrim(
            opacity: .84,
            label: 'Not enough coins',
            child: NoCoinsModal(c: c, onBuy: () => _buy(c.mode)),
          ),
        ),
      if (c.overlay != null) Positioned.fill(child: WinOverlay(key: ValueKey(c.overlay), c: c, tier: c.overlay!)),
    ]);
  }
}
