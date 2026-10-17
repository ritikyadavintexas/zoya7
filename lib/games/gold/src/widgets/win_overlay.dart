import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../assets.dart';
import '../controller.dart';
import '../math.dart';
import '../style.dart';
import 'fx.dart';

/// Big / Super / Mega / Jackpot celebration.
class WinOverlay extends StatefulWidget {
  const WinOverlay({super.key, required this.c, required this.tier});
  final GoldController c;
  final WinTier tier;

  @override
  State<WinOverlay> createState() => _WinOverlayState();
}

class _WinOverlayState extends State<WinOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _rays =
      AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();

  static const _bannerSize = {
    WinTier.big: (770.0, 474.0),
    WinTier.superWin: (786.0, 464.0),
    WinTier.mega: (640.0, 490.0),
    WinTier.jackpot: (682.0, 494.0),
  };
  static const _names = {
    WinTier.big: 'Big win',
    WinTier.superWin: 'Super win',
    WinTier.mega: 'Mega win',
    WinTier.jackpot: 'Jackpot',
  };

  @override
  void dispose() {
    _rays.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final tier = widget.tier;
    final size = _bannerSize[tier]!;
    final amount = c.overlayAmount();
    const center = Alignment(0, -.16); // 50% 42%

    return Semantics(
      scopesRoute: true,
      label: _names[tier],
      child: Stack(children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFF140A02))),
        // repeating-conic-gradient rays (slowly turning)
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _rays,
            builder: (_, __) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: SweepGradient(
                  center: center,
                  startAngle: 0,
                  endAngle: 16 * math.pi / 180,
                  tileMode: TileMode.repeated,
                  colors: [GC.a(255, 200, 80, .14), GC.a(255, 200, 80, .14), GC.a(0, 0, 0, 0), GC.a(0, 0, 0, 0)],
                  stops: const [0, .5, .5, 1],
                  transform: GradientRotation(-math.pi / 2 + _rays.value * 2 * math.pi),
                ),
              ),
            ),
          ),
        ),
        // radial-gradient(circle at 50% 42%, rgba(120,70,10,.55) 0%, rgba(20,10,2,.9) 60%)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: center,
                radius: 1146 / 1080,
                colors: [GC.a(120, 70, 10, .55), GC.a(20, 10, 2, .9)],
                stops: const [0, .6],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: .4, end: 1),
                duration: const Duration(milliseconds: 750),
                curve: Curves.elasticOut,
                builder: (_, s, child) => Transform.scale(scale: s, child: child),
                child: Img(GoldAssets.winBanner(tier), w: size.$1, h: size.$2),
              ),
              if (tier == WinTier.jackpot) ...[
                const SizedBox(height: 6),
                Text(
                  c.jackpotHitName,
                  style: lilita(40,
                      color: GC.jackpotColors[c.jackpotHitTier]!,
                      letterSpacingEm: .08,
                      shadows: [ts(0, 3, 0, GC.bgDeep)]),
                ),
              ],
              const SizedBox(height: 6),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: amount),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      fmtAmount(v, c.mode),
                      style: lilita(116, height: 1.05, shadows: [
                        ts(0, 5, 0, GC.goldShadow),
                        ts(0, 0, 30, GC.a(255, 200, 80, .75)),
                      ]),
                    ),
                    if (c.mode == Currency.gc) ...[
                      const SizedBox(width: 16),
                      Text(curLabel(c.mode),
                          style: lilita(50, color: GC.goldLabel, shadows: [ts(0, 3, 0, GC.goldShadow)])),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6 + 18),
              _collect(c),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _collect(GoldController c) => Tap(
        onTap: c.collect,
        label: 'Collect',
        child: Container(
          width: 380,
          height: 116,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: GC.goldRim,
            borderRadius: BorderRadius.circular(60),
            boxShadow: [bs(0, 10, 26, GC.a(0, 0, 0, .55)), bs(0, 0, 30, GC.a(255, 190, 60, .4))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(56),
            child: Stack(fit: StackFit.expand, children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: ellipseFarthestCorner(
                    cx: .5,
                    cy: .22,
                    colors: const [Color(0xFF5FD35A), Color(0xFF1F9A24), Color(0xFF0B5A12)],
                    stops: const [0, .45, 1],
                  ),
                ),
              ),
              // inset 0 6px 14px white .25 / inset 0 -8px 18px black .35
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [GC.a(255, 255, 255, .25), GC.a(255, 255, 255, 0), GC.a(0, 0, 0, 0), GC.a(0, 0, 0, .35)],
                    stops: const [0, .22, .72, 1],
                  ),
                ),
              ),
              Center(
                child: Text('COLLECT',
                    style: lilita(52,
                        color: const Color(0xFFFFE27A),
                        letterSpacingEm: .04,
                        shadows: [ts(0, 3, 0, const Color(0xFF0B3D0E))])),
              ),
            ]),
          ),
        ),
      );
}
