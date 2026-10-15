import 'package:flutter/material.dart';

import '../assets.dart';
import '../controller.dart';
import '../math.dart';
import '../style.dart';
import 'fx.dart';
import 'side_panels.dart';

/// Gold-rimmed modal card with the design's close button.
class _ModalCard extends StatelessWidget {
  const _ModalCard({
    required this.width,
    required this.glow,
    required this.padding,
    required this.onClose,
    required this.closeLabel,
    required this.child,
  });

  final double width;
  final Color glow;
  final EdgeInsets padding;
  final VoidCallback onClose;
  final String closeLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: GC.goldRim,
          borderRadius: BorderRadius.circular(36),
          boxShadow: [bs(0, 30, 80, GC.a(0, 0, 0, .7))],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(31),
            gradient: ellipseGradient(
              cx: .5, cy: 0, rx: .8, ry: .6,
              colors: [glow, GC.panelBottom],
              stops: const [0, .75],
            ),
          ),
          child: Stack(children: [
            Padding(padding: padding, child: child),
            Positioned(
              right: 24,
              top: 24,
              child: CloseButtonRound(onTap: onClose, label: closeLabel),
            ),
          ]),
        ),
      );
}

TextStyle _h2(double size, [double ls = .06]) =>
    lilita(size, color: GC.goldTitle, letterSpacingEm: ls, shadows: [ts(0, 4, 0, GC.goldShadow)]);

TextStyle _h3() => lilita(30, color: GC.goldLabel, letterSpacingEm: .06);

// ── Paytable ─────────────────────────────────────────────────────────────────
class PaytableModal extends StatelessWidget {
  const PaytableModal({super.key, required this.c});
  final GoldController c;

  Widget _payItem(Sym s, String count, String pay) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: GC.a(255, 214, 120, .05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GC.a(255, 214, 120, .15)),
        ),
        child: Row(children: [
          Img(GoldAssets.symbol(s), w: 62, h: 62, fit: BoxFit.contain),
          const SizedBox(width: 14),
          Text(count, style: rubik(18, color: GC.muted)),
          const Spacer(),
          Text(pay, style: lilita(30)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final s in linePayOrder) _payItem(s, '×3', '${GoldRules.linePays[s]}× bet'),
      _payItem(Sym.cherry, 'any ×2', '${GoldRules.twoCherryPay}× bet'),
    ];
    final grid = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      if (i > 0) grid.add(const SizedBox(height: 10));
      grid.add(Row(children: [
        Expanded(child: items[i]),
        const SizedBox(width: 10),
        Expanded(child: i + 1 < items.length ? items[i + 1] : const SizedBox()),
      ]));
    }

    return _ModalCard(
      width: 1300,
      glow: const Color(0xFF3A2209),
      padding: const EdgeInsets.fromLTRB(44, 34, 44, 36),
      onClose: c.closePanel,
      closeLabel: 'Close paytable',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('PAYTABLE', textAlign: TextAlign.center, style: _h2(60)),
          const SizedBox(height: 26),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('THREE ON THE PAYLINE', style: _h3()),
                    for (final (sym, tier) in jackpotOrder) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                        decoration: BoxDecoration(
                          color: GC.a(255, 214, 120, .07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: GC.a(255, 214, 120, .2), width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              for (var i = 0; i < 3; i++) ...[
                                if (i > 0) const SizedBox(width: 6),
                                Img(GoldAssets.symbol(sym), w: 70, h: 70, fit: BoxFit.contain),
                              ],
                            ]),
                            Text('${tier.name.toUpperCase()} JACKPOT', style: jackpotLabel(tier, 30)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 40),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('LINE PAYS', style: _h3()),
                    const SizedBox(height: 6 + 8),
                    ...grid,
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            'Wins pay on the middle payline only. Line pays are multiplied by your total bet; '
            'jackpots pay their current displayed value and grow with every spin. '
            'Malfunction voids all pays and plays.',
            textAlign: TextAlign.center,
            style: rubik(20, height: 1.5, color: const Color(0xFFCDBFA6)),
          ),
        ],
      ),
    );
  }
}

// ── Settings ─────────────────────────────────────────────────────────────────
class SettingsModal extends StatelessWidget {
  const SettingsModal({super.key, required this.c, required this.onPlayLimits, required this.onExit});
  final GoldController c;
  final VoidCallback onPlayLimits;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Sound effects', 'Reels, wins and buttons', c.sfx, c.toggleSfx),
      ('Music', 'Background soundtrack', c.music, c.toggleMusic),
      ('Fast spin', 'Shorter reel animation', c.fastSpin, c.toggleFastSpin),
      ('Vibration', 'Haptics on big wins', c.haptics, c.toggleHaptics),
    ];
    return _ModalCard(
      width: 860,
      glow: const Color(0xFF3A2209),
      padding: const EdgeInsets.fromLTRB(40, 34, 40, 36),
      onClose: c.closePanel,
      closeLabel: 'Close settings',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('SETTINGS', textAlign: TextAlign.center, style: _h2(56)),
          const SizedBox(height: 10),
          for (final r in rows) ...[
            const SizedBox(height: 14),
            Container(
              constraints: const BoxConstraints(minHeight: 92),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: GC.a(255, 214, 120, .06),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: GC.a(255, 214, 120, .18), width: 1.5),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.$1, style: rubik(28, weight: FontWeight.w700, color: GC.cream)),
                      const SizedBox(height: 4),
                      Text(r.$2, style: rubik(19, color: GC.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                GoldSwitch(on: r.$3, onTap: r.$4, label: r.$1),
              ]),
            ),
          ],
          const SizedBox(height: 14 + 10),
          Row(children: [
            Expanded(child: PillButton(label: 'PAYTABLE', onTap: c.openPaytable, height: 76, fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(child: PillButton(label: 'PLAY LIMITS', onTap: onPlayLimits, height: 76, fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(child: PillButton(label: 'EXIT TO LOBBY', onTap: onExit, height: 76, fontSize: 24, red: true)),
          ]),
        ],
      ),
    );
  }
}

class GoldSwitch extends StatelessWidget {
  const GoldSwitch({super.key, required this.on, required this.onTap, required this.label});
  final bool on;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) => Tap(
        onTap: onTap,
        label: label,
        toggled: on,
        pressScale: 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 96,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            border: Border.all(color: on ? GC.brightBorder : const Color(0xFF4A3A1E), width: 3),
            color: on ? null : const Color(0xFF22180C),
            gradient: on
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF5FD35A), Color(0xFF1F9A24)],
                  )
                : null,
          ),
          child: Stack(children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              top: 5,
              left: on ? 46 : 6,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: circleGradient(
                    cx: .4,
                    cy: .3,
                    colors: const [Color(0xFFFFF8E0), Color(0xFFE0C48A)],
                  ),
                  boxShadow: [bs(0, 3, 6, GC.a(0, 0, 0, .5))],
                ),
              ),
            ),
          ]),
        ),
      );
}

// ── Not enough coins ─────────────────────────────────────────────────────────
class NoCoinsModal extends StatelessWidget {
  const NoCoinsModal({super.key, required this.c, required this.onBuy});
  final GoldController c;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final cur = curLabel(c.mode);
    final other = c.mode == Currency.sc ? 'PLAY WITH GC' : 'PLAY WITH SC';
    return _ModalCard(
      width: 900,
      glow: const Color(0xFF5A1A10),
      padding: const EdgeInsets.fromLTRB(50, 40, 50, 44),
      onClose: c.closePanel,
      closeLabel: 'Close',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 150,
            height: 150,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: circleGradient(
                cx: .4,
                cy: .3,
                colors: const [Color(0xFFFFF0B3), Color(0xFFF2C14E), Color(0xFFA8691A)],
                stops: const [0, .45, 1],
              ),
              boxShadow: [bs(0, 0, 40, GC.a(255, 200, 80, .6))],
            ),
            child: Text(cur, style: lilita(54, color: const Color(0xFF4A2E05))),
          ),
          const SizedBox(height: 18),
          Text('NOT ENOUGH COINS', textAlign: TextAlign.center, style: _h2(60, .04)),
          const SizedBox(height: 18),
          Text(
            'A ${fmtAmount(c.bet, c.mode)} $cur spin is more than your balance of '
            '${fmtAmount(c.balance, c.mode)} $cur. Grab a package, lower your bet or switch currency.',
            textAlign: TextAlign.center,
            style: rubik(26, height: 1.45, color: const Color(0xFFE9DCC0)),
          ),
          const SizedBox(height: 18 + 8),
          Tap(
            onTap: onBuy,
            child: Container(
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(48),
                border: Border.all(color: GC.brightBorder, width: 3),
                gradient: GC.greenButton,
                boxShadow: [bs(0, 0, 26, GC.a(120, 255, 120, .3))],
              ),
              child: Text('BUY COINS',
                  style: lilita(40,
                      color: const Color(0xFFFFE27A),
                      letterSpacingEm: .04,
                      shadows: [ts(0, 3, 0, const Color(0xFF0B3D0E))])),
            ),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: PillButton(label: 'LOWER BET', onTap: c.lowerBet, height: 80, fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(child: PillButton(label: other, onTap: c.switchCurrency, height: 80, fontSize: 28)),
          ]),
        ],
      ),
    );
  }
}
