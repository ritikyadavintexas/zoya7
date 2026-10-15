import 'package:flutter/material.dart';

import '../assets.dart';
import '../controller.dart';
import '../style.dart';
import 'fx.dart';

/// Bottom controls: bet, max bet, auto, win meter, spin/stop.
class GoldFooter extends StatelessWidget {
  const GoldFooter({super.key, required this.c});
  final GoldController c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 6, 40, 24),
      child: Row(
        children: [
          _betPanel(),
          const SizedBox(width: 22),
          Tap(
            onTap: c.busy ? null : c.maxBet,
            label: 'Max bet',
            child: const Img(GoldAssets.maxBet, w: 213, h: 138),
          ),
          const SizedBox(width: 22),
          _autoButton(),
          const SizedBox(width: 22),
          Expanded(child: _winMeter()),
          const SizedBox(width: 22),
          SizedBox(
            width: 380,
            height: 170,
            child: c.busy
                ? Tap(
                    onTap: c.hasPending ? c.stop : null,
                    label: 'Stop',
                    child: const Center(child: Img(GoldAssets.stop, w: 340, h: 138)),
                  )
                : Tap(onTap: c.spin, label: 'Spin', child: const Img(GoldAssets.spin, w: 380, h: 170)),
          ),
        ],
      ),
    );
  }

  Widget _betPanel() {
    const w = 542.0, h = 138.0;
    return SizedBox(
      width: w,
      height: h,
      child: Stack(children: [
        const Img(GoldAssets.betPanel, w: w, h: h),
        Positioned(
          left: w * .03,
          top: h * .12,
          width: w * .19,
          height: h * .76,
          child: Tap(onTap: c.busy ? null : c.betDown, label: 'Decrease bet', child: const SizedBox.expand()),
        ),
        Positioned(
          left: w * .24,
          right: w * .24,
          top: h * .42,
          bottom: h * .17,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(fmtAmount(c.bet, c.mode), style: lilita(40, shadows: goldGlow())),
                  const SizedBox(width: 8),
                  Text(curLabel(c.mode), style: rubik(18, weight: FontWeight.w700, color: GC.goldLabel)),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: w * .03,
          top: h * .12,
          width: w * .19,
          height: h * .76,
          child: Tap(onTap: c.busy ? null : c.betUp, label: 'Increase bet', child: const SizedBox.expand()),
        ),
      ]),
    );
  }

  Widget _autoButton() => Tap(
        onTap: c.toggleAuto,
        label: 'Auto spin',
        toggled: c.auto,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: c.auto ? 1 : 0),
          duration: const Duration(milliseconds: 200),
          builder: (_, v, child) => DropGlow(
            color: GC.a(120, 255, 120, .85),
            blur: 16,
            opacity: v,
            child: ColorFiltered(
              colorFilter: ColorFilter.matrix(saturateBrightness(1, 1 + .15 * v)),
              child: child,
            ),
          ),
          child: const Img(GoldAssets.auto, w: 243, h: 137),
        ),
      );

  Widget _winMeter() => GoldRim(
        radius: 24,
        shadows: [bs(0, 8, 22, GC.a(0, 0, 0, .5))],
        fill: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0C0805), Color(0xFF24180C)],
        ),
        child: SizedBox(
          height: 112,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('WIN', style: lilita(22, color: GC.goldLabel, letterSpacingEm: .14)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  fmtAmount(c.win, c.mode),
                  maxLines: 1,
                  style: lilita(50, height: 1, shadows: [
                    ts(0, 3, 0, GC.goldShadow),
                    ts(0, 0, 14, GC.a(255, 200, 80, .55)),
                  ]),
                ),
              ),
              const SizedBox(height: 2),
              Text(c.winNote, style: rubik(15, color: GC.note), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}
