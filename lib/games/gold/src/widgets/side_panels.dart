import 'package:flutter/material.dart';

import '../assets.dart';
import '../icons.dart';
import '../math.dart';
import '../style.dart';
import 'fx.dart';

TextStyle jackpotLabel(JackpotTier t, double size) =>
    lilita(size, color: GC.jackpotColors[t]!, shadows: [ts(0, 2, 0, GC.jackpotShadows[t]!)]);

const jackpotOrder = [
  (Sym.seven, JackpotTier.mega),
  (Sym.diamond, JackpotTier.major),
  (Sym.crown, JackpotTier.minor),
  (Sym.bar, JackpotTier.mini),
];

const linePayOrder = [Sym.star, Sym.bell, Sym.melon, Sym.plum, Sym.orange, Sym.lemon, Sym.cherry];

/// Left rail: JACKPOT COMBOS.
class JackpotCombos extends StatelessWidget {
  const JackpotCombos({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (final (sym, tier) in jackpotOrder) {
      rows
        ..add(const SizedBox(height: 12))
        ..add(Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: GC.a(255, 214, 120, .07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: GC.a(255, 214, 120, .18)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Img(GoldAssets.symbol(sym), w: 44, h: 44, fit: BoxFit.contain),
                ],
              ]),
              Text(tier.name.toUpperCase(), style: jackpotLabel(tier, 26)),
            ],
          ),
        ));
    }
    return Semantics(
      label: 'Jackpot combinations',
      child: GoldRim(
        width: 316,
        radius: 22,
        shadows: [bs(0, 10, 26, GC.a(0, 0, 0, .5))],
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('JACKPOT COMBOS',
                textAlign: TextAlign.center, style: lilita(26, color: GC.goldTitle, letterSpacingEm: .06)),
            ...rows,
            const SizedBox(height: 12),
            Text('Three on the payline wins the jackpot', textAlign: TextAlign.center, style: rubik(15, color: GC.note)),
          ],
        ),
      ),
    );
  }
}

/// Right rail: LINE PAYS.
class LinePays extends StatelessWidget {
  const LinePays({super.key, required this.onFullPaytable});
  final VoidCallback onFullPaytable;

  Widget _row(Sym s, String pay, {bool two = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Img(GoldAssets.symbol(s), w: 38, h: 38, fit: BoxFit.contain),
              const SizedBox(width: 2),
              Img(GoldAssets.symbol(s), w: 38, h: 38, fit: BoxFit.contain),
              const SizedBox(width: 2),
              Visibility(
                visible: !two,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Img(GoldAssets.symbol(s), w: 38, h: 38, fit: BoxFit.contain),
              ),
            ]),
            Text(pay, style: lilita(26, shadows: [ts(0, 2, 0, GC.goldShadow)])),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      for (final s in linePayOrder) _row(s, '${GoldRules.linePays[s]}×'),
      _row(Sym.cherry, '${GoldRules.twoCherryPay}×', two: true),
    ];
    return Semantics(
      label: 'Line pays',
      child: GoldRim(
        width: 316,
        radius: 22,
        shadows: [bs(0, 10, 26, GC.a(0, 0, 0, .5))],
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('LINE PAYS',
                  textAlign: TextAlign.center, style: lilita(26, color: GC.goldTitle, letterSpacingEm: .06)),
            ),
            for (final r in rows) ...[const SizedBox(height: 5), r],
            const SizedBox(height: 5 + 8),
            Tap(
              onTap: onFullPaytable,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: GC.panelTop,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: GC.btnBorder, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GoldIcons.info(22),
                    const SizedBox(width: 10),
                    Text('FULL PAYTABLE', style: lilita(20, color: GC.goldTitle, letterSpacingEm: .06)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
