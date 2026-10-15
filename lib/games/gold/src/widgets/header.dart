import 'package:flutter/material.dart';

import '../assets.dart';
import '../controller.dart';
import '../icons.dart';
import '../math.dart';
import '../style.dart';
import 'fx.dart';

class GoldHeader extends StatelessWidget {
  const GoldHeader({
    super.key,
    required this.c,
    required this.onBack,
    required this.onGetMore,
  });

  final GoldController c;
  final VoidCallback onBack;
  final ValueChanged<Currency> onGetMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 206,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 22, 40, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _leftCluster(),
            const SizedBox(width: 24),
            _JackpotMeters(c: c),
            const SizedBox(width: 24),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BalanceBar(
                  asset: GoldAssets.balanceGc,
                  imgH: 94,
                  textInset: .31,
                  active: c.mode == Currency.gc,
                  amount: fmtAmount(c.gc, Currency.gc),
                  label: 'Play with Gold Coins',
                  onPick: () => c.pickCurrency(Currency.gc),
                  onMore: () => onGetMore(Currency.gc),
                  moreLabel: 'Get more Gold Coins',
                ),
                const SizedBox(height: 10),
                _BalanceBar(
                  asset: GoldAssets.balanceSc,
                  imgH: 89,
                  textInset: .30,
                  active: c.mode == Currency.sc,
                  amount: fmtAmount(c.sc, Currency.sc),
                  label: 'Play with Sweeps Coins',
                  onPick: () => c.pickCurrency(Currency.sc),
                  onMore: () => onGetMore(Currency.sc),
                  moreLabel: 'Get more Sweeps Coins',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _leftCluster() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tap(onTap: onBack, label: 'Back to lobby', child: const Img(GoldAssets.back, w: 128, h: 112)),
          const SizedBox(width: 16),
          // Chat
          Tap(
            onTap: c.openChat,
            label: 'Open table chat',
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: GC.goldRim,
                    boxShadow: [bs(0, 6, 16, GC.a(0, 0, 0, .5)), bs(0, 0, 18, GC.a(255, 170, 40, .35))],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: circleGradient(
                        cx: .5,
                        cy: .3,
                        colors: const [Color(0xFFFF4A4A), Color(0xFFD0101C), Color(0xFF7A0309)],
                        stops: const [0, .45, 1],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: GoldIcons.chat(44),
                  ),
                ),
                if (!c.chatSeen)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 32),
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: GC.green,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: GC.bgDeep, width: 3),
                      ),
                      alignment: Alignment.center,
                      child: Text('${c.chatUnread}',
                          style: rubik(16, weight: FontWeight.w700, color: const Color(0xFF062E14), height: 1)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Settings
          Tap(
            onTap: c.openSettings,
            label: 'Game settings',
            child: Container(
              width: 80,
              height: 80,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: GC.goldRim,
                boxShadow: [bs(0, 6, 16, GC.a(0, 0, 0, .5))],
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: circleGradient(
                    cx: .5,
                    cy: .3,
                    colors: const [Color(0xFF3A2A14), Color(0xFF120C06)],
                  ),
                ),
                alignment: Alignment.center,
                child: GoldIcons.gear(38),
              ),
            ),
          ),
        ],
      );
}

class _JackpotMeters extends StatelessWidget {
  const _JackpotMeters({required this.c});
  final GoldController c;

  // width, height, label inset (l/r), top, bottom, font size — from the design.
  static const _spec = {
    JackpotTier.mega: (243.0, 176.0, .09, .63, .08, 27.0),
    JackpotTier.major: (232.0, 175.0, .09, .63, .08, 26.0),
    JackpotTier.minor: (216.0, 159.0, .10, .61, .08, 25.0),
    JackpotTier.mini: (205.0, 154.0, .10, .60, .09, 24.0),
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Jackpots',
      child: ValueListenableBuilder<int>(
        valueListenable: c.tick,
        builder: (_, __, ___) {
          final jp = c.jackpots();
          final children = <Widget>[];
          for (final t in JackpotTier.values) {
            final s = _spec[t]!;
            if (children.isNotEmpty) children.add(const SizedBox(width: 18));
            children.add(SizedBox(
              width: s.$1,
              height: s.$2,
              child: Stack(children: [
                Positioned.fill(
                  child: Semantics(
                    label: '${t.name} jackpot',
                    child: Image.asset(GoldAssets.jackpot(t), fit: BoxFit.fill, filterQuality: FilterQuality.medium),
                  ),
                ),
                Positioned(
                  left: s.$1 * s.$3,
                  right: s.$1 * s.$3,
                  top: s.$2 * s.$4,
                  bottom: s.$2 * s.$5,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(fmtAmount(jp[t]!, c.mode), maxLines: 1, style: lilita(s.$6, shadows: goldGlow())),
                    ),
                  ),
                ),
              ]),
            ));
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: children);
        },
      ),
    );
  }
}

class _BalanceBar extends StatelessWidget {
  const _BalanceBar({
    required this.asset,
    required this.imgH,
    required this.textInset,
    required this.active,
    required this.amount,
    required this.label,
    required this.onPick,
    required this.onMore,
    required this.moreLabel,
  });

  final String asset;
  final double imgH;
  final double textInset;
  final bool active;
  final String amount;
  final String label;
  final VoidCallback onPick;
  final VoidCallback onMore;
  final String moreLabel;

  static final _off = saturateBrightness(.6, .7);
  static final _on = saturateBrightness(1, 1);

  @override
  Widget build(BuildContext context) {
    const w = 440.0;
    final bar = SizedBox(
      width: w,
      height: imgH,
      child: Stack(children: [
        Img(asset, w: w, h: imgH),
        Positioned(
          left: 0,
          top: 0,
          width: w * .8,
          height: imgH,
          child: Tap(
            onTap: onPick,
            label: label,
            selected: active,
            pressScale: 1,
            child: Padding(
              padding: EdgeInsets.only(left: w * textInset),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(amount, maxLines: 1, style: lilita(32, shadows: goldGlow())),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: w * .01,
          top: imgH * .08,
          width: w * .17,
          height: imgH * .84,
          child: Tap(onTap: onMore, label: moreLabel, child: const SizedBox.expand()),
        ),
      ]),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(end: active ? 1 : 0),
      duration: const Duration(milliseconds: 200),
      builder: (_, v, child) => DropGlow(
        color: GC.a(255, 200, 70, .85),
        blur: 14,
        opacity: v,
        child: ColorFiltered(colorFilter: ColorFilter.matrix(lerpMatrix(_off, _on, v)), child: child),
      ),
      child: bar,
    );
  }
}
