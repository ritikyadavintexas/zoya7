import 'package:flutter/material.dart';

import '../icons.dart';
import '../nav.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'promotions.dart' show RaysBurst;

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => WalletPageState();
}

class WalletPageState extends State<WalletPage> {
  static const tabs = ['buy', 'redeem', 'history'];
  int tab = 0;
  int payout = 0;

  void showTab(String t) => setState(() => tab = tabs.indexOf(t).clamp(0, 2));

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ZPage(
      child: Column(children: [
        TopBar(
          title: 'WALLET',
          backLabel: 'Back to lobby',
          onBack: () => Nav.tab(AppTab.home),
          right: RoundBtn(
            label: 'Payment help',
            onTap: () => Nav.push(R.chat, 'support'),
            child: Text('?', style: outfit(18, w: FontWeight.w800, c: Z.gold)),
          ),
        ),
        Expanded(
          child: Panes(
            sideFraction: .36,
            side: PaneList(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 16),
              children: [
                GoldFrame(
                  inner: ellipseGradient(
                      cx: 0, cy: 0, rx: 1, ry: .8, colors: const [Color(0xFF3A2209), Color(0xFF0D0906)], stops: const [0, .7]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _Balance(
                      coin: const Coin(size: 26, fontSize: 9),
                      label: 'GOLD COINS',
                      labelColor: Z.label,
                      value: fmtInt(s.gc),
                      note: 'For fun play',
                    ),
                    Container(height: 1, color: Z.line35),
                    _Balance(
                      coin: const Coin(label: 'SC', size: 26, fontSize: 9, teal: true),
                      label: 'SWEEPS COINS',
                      labelColor: Z.teal,
                      value: fmtSc(s.sc),
                      note: '${fmtSc(s.redeemableSc)} redeemable',
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                for (final (i, label) in const ['BUY COINS', 'REDEEM', 'HISTORY'].indexed) ...[
                  _SideTab(label, selected: tab == i, onTap: () => setState(() => tab = i)),
                  const SizedBox(height: 8),
                ],
              ],
            ),
            main: PaneList(
              padding: const EdgeInsets.fromLTRB(8, 12, 14, 18),
              children: [
                if (tab == 0) _buy(s),
                if (tab == 1) _redeem(s),
                if (tab == 2) _history(),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buy(AppState s) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, box) => GridView.builder(
            clipBehavior: Clip.none,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: coinPacks.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: box.maxWidth >= 360 ? 3 : 2, mainAxisSpacing: 14, crossAxisSpacing: 10, mainAxisExtent: 172),
            itemBuilder: (_, i) => _PackTile(coinPacks[i], selected: i == s.selectedPack, onTap: () => s.selectPack(i)),
          ),
        ),
        const SizedBox(height: 12),
        CtaButton('BUY ${s.pack.gcLabel} GC · ${s.pack.priceLabel}', ls: .03, onTap: () => Nav.push(R.checkout)),
        const SizedBox(height: 12),
        Text('Sweeps Coins are a free bonus with Gold Coin packages. No purchase necessary.',
            textAlign: TextAlign.center, style: outfit(12, c: Z.muted2, h: 1.45)),
      ]);

  Widget _redeem(AppState s) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2F6E5A), width: 1.5),
            color: const Color(0x1414B38A),
          ),
          child: Row(children: [
            Expanded(child: Text('Redeemable SC', style: outfit(14, c: Z.body))),
            Text(fmtSc(s.redeemableSc), style: outfit(22, w: FontWeight.w800, c: Z.teal)),
          ]),
        ),
        const SizedBox(height: 14),
        const ZField(label: 'AMOUNT TO REDEEM', hint: 'Minimum [MIN] SC', keyboard: TextInputType.number),
        const SizedBox(height: 14),
        Text('PAYOUT METHOD', style: outfit(13, w: FontWeight.w600, c: Z.label)),
        const SizedBox(height: 8),
        for (final (i, m) in const ['Bank transfer', 'Gift card'].indexed) ...[
          RadioRow(label: m, selected: payout == i, onTap: () => setState(() => payout = i)),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 6),
        CtaButton('REQUEST REDEMPTION', onTap: () => showToast(context, 'Redemption request submitted')),
        const SizedBox(height: 14),
        Text('Identity verification is required before your first redemption.',
            textAlign: TextAlign.center, style: outfit(12, c: Z.muted2, h: 1.45)),
      ]);

  Widget _history() {
    const hist = [
      ('GC', 'Daily bonus', 'Today · 9:41 AM', '+5,000 GC', true),
      ('GC', 'Classic 777 win', 'Today · 9:12 AM', '+75,000 GC', true),
      ('GC', '120K GC package', 'Yesterday · 8:30 PM', '+120,000 GC', true),
      ('SC', 'Free SC with package', 'Yesterday · 8:30 PM', '+10.00 SC', true),
      ('SC', 'Redemption — bank', 'Oct 12 · Pending', '−50.00 SC', false),
      ('GC', 'Referral bonus', 'Oct 10', '+10,000 GC', true),
    ];
    return Column(children: [
      for (final (icon, title, at, amount, plus) in hist)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ZCard(
            radius: 14,
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: icon == 'SC' ? Z.coinTeal() : Z.coinGold(),
                ),
                child: Text(icon, style: outfit(12, w: FontWeight.w800, c: icon == 'SC' ? Z.tealInk : Z.coinInk)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: outfit(15, w: FontWeight.w700, c: Z.cream)),
                  const SizedBox(height: 2),
                  Text(at, style: outfit(12, c: Z.muted2)),
                ]),
              ),
              Text(amount, style: outfit(15, w: FontWeight.w800, c: plus ? Z.green : Z.coral)),
            ]),
          ),
        ),
    ]);
  }
}

class _Balance extends StatelessWidget {
  const _Balance({required this.coin, required this.label, required this.labelColor, required this.value, required this.note});
  final Widget coin;
  final String label;
  final Color labelColor;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            coin,
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                  child: Text(label, style: outfit(12, w: FontWeight.w700, ls: .1, c: labelColor))),
            ),
          ]),
          const SizedBox(height: 4),
          FittedBox(child: Text(value, style: outfit(24, w: FontWeight.w800, c: Z.cream))),
          const SizedBox(height: 2),
          Text(note, style: outfit(12, c: Z.muted)),
        ]),
      );
}

/// One of the wallet's BUY COINS / REDEEM / HISTORY choices in the side pane.
class _SideTab extends StatelessWidget {
  const _SideTab(this.label, {required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        selected: selected,
        label: label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: selected ? Z.goldTab : null,
            color: selected ? null : const Color(0xFF0D0906),
            border: selected ? null : Border.all(color: Z.border, width: 1.5),
          ),
          child: Row(children: [
            Expanded(child: Text(label, style: outfit(14, w: FontWeight.w800, ls: .06, c: selected ? Z.brown : Z.tabOff))),
            StrokeIco(P.forward, size: 14, color: selected ? Z.brown : Z.faint, width: 2.6),
          ]),
        ),
      );
}

class _PackTile extends StatelessWidget {
  const _PackTile(this.p, {required this.selected, required this.onTap});
  final CoinPack p;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        selected: selected,
        label: '${p.gcLabel} Gold Coins plus ${p.sc} Sweeps Coins, ${p.priceLabel}',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: ellipseGradient(
                cx: .5, cy: 0, rx: 1, ry: .7, colors: const [Color(0xFF3A2209), Z.field], stops: const [0, .75]),
            border: Border.all(color: selected ? Z.goldBright : Z.chip, width: selected ? 2 : 1.5),
            boxShadow: selected ? [bs(0, 0, 16, const Color(0x73FFC846))] : null,
          ),
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
            Column(children: [
              const SizedBox(height: 8),
              Coin(size: 44, fontSize: 13, glow: [bs(0, 0, 14, const Color(0x73FFC850))]),
              const SizedBox(height: 4),
              Text(p.gcLabel, style: outfit(20, w: FontWeight.w800, c: Z.cream)),
              const SizedBox(height: 4),
              Text('+ ${p.sc} SC FREE', style: outfit(12, w: FontWeight.w700, c: Z.teal)),
              const Spacer(),
              Container(
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: Z.green3),
                child: Text(p.priceLabel, style: outfit(15, w: FontWeight.w800, c: Z.cream)),
              ),
            ]),
            if (p.tag != null)
              Positioned(
                top: -13,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
                    gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE0303B), Color(0xFF9A0A14)]),
                  ),
                  child: Text(p.tag!, style: outfit(10, w: FontWeight.w800, ls: .08, c: Z.cream)),
                ),
              ),
          ]),
        ),
      );
}

/// Radio option row (payout method, payment method).
class RadioRow extends StatelessWidget {
  const RadioRow({super.key, required this.label, required this.selected, required this.onTap, this.sub, this.icon, this.glow = false});
  final String label;
  final String? sub;
  final Widget? icon;
  final bool selected;
  final bool glow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        selected: selected,
        label: label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: BoxConstraints(minHeight: sub == null ? 54 : 62),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Z.field,
            border: Border.all(
                color: glow && selected ? Z.goldBright : (glow ? Z.chipDark : Z.chip), width: glow && selected ? 2 : 1.5),
            boxShadow: glow && selected ? [bs(0, 0, 12, const Color(0x4DFFC846))] : null,
          ),
          child: Row(children: [
            Container(
              width: 20,
              height: 20,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? Z.ghostBorder : Z.faint, width: 2),
              ),
              child: selected
                  ? Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: Z.ghostBorder))
                  : null,
            ),
            const SizedBox(width: 12),
            if (icon != null) ...[icon!, const SizedBox(width: 12)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(label, style: outfit(15, w: sub == null ? FontWeight.w600 : FontWeight.w700, c: sub == null ? Z.text : Z.cream)),
                if (sub != null) Text(sub!, style: outfit(12, c: Z.muted2)),
              ]),
            ),
          ]),
        ),
      );
}

// ── Checkout ─────────────────────────────────────────────────────────────────

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int method = 0;
  final _promo = TextEditingController();
  bool applied = false;

  @override
  void dispose() {
    _promo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pack;
    final code = _promo.text.trim().toUpperCase();
    final bonus = applied && code.isNotEmpty ? (p.gc * .1).round() : 0;
    const methods = [
      ('Visa ending 4242', 'Expires 08/28', P.card),
      ('Mobile wallet', 'Apple Pay or Google Pay', P.wallet),
      ('Online banking', 'Pay from your bank account', P.bank),
    ];
    return ZPage(
      child: Column(children: [
        TopBar(
          title: 'CHECKOUT',
          backLabel: 'Back to wallet',
          right: Row(mainAxisSize: MainAxisSize.min, children: [
            const Ico(P.lock, size: 14, color: Z.greenHi),
            const SizedBox(width: 4),
            Text('Secure', style: outfit(12, w: FontWeight.w600, c: Z.greenHi)),
          ]),
        ),
        Expanded(
          child: Panes(
            sideFraction: .44,
            maxSide: 440,
            side: Column(children: [
              Expanded(
                child: PaneList(
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
                  children: [
                    GoldFrame(
                      inner: ellipseGradient(
                          cx: 0, cy: 0, rx: 1, ry: .8, colors: const [Color(0xFF3A2209), Color(0xFF0D0906)], stops: const [0, .7]),
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Coin(size: 54, fontSize: 16, glow: [bs(0, 0, 18, const Color(0x80FFC850))]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.tag == null ? 'GOLD COIN PACKAGE' : '${p.tag} PACKAGE',
                                style: outfit(12, w: FontWeight.w700, ls: .12, c: Z.label)),
                            const SizedBox(height: 2),
                            Text('${fmtInt(p.gc)} GC', style: outfit(20, w: FontWeight.w800, c: Z.cream)),
                            const SizedBox(height: 2),
                            Text('+ ${p.sc} SC free', style: outfit(14, w: FontWeight.w700, c: Z.teal)),
                          ]),
                        ),
                        Text(p.priceLabel, style: outfit(20, w: FontWeight.w800, c: Z.cream)),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    ZCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(children: [
                        _line('${fmtInt(p.gc)} Gold Coins', Text(p.priceLabel, style: outfit(15))),
                        const SizedBox(height: 8),
                        _line('${p.sc} Sweeps Coins', Text('FREE', style: outfit(15, w: FontWeight.w700, c: Z.teal))),
                        if (bonus > 0) ...[
                          const SizedBox(height: 8),
                          _line('Promo bonus', Text('+${fmtInt(bonus)} GC', style: outfit(15, w: FontWeight.w700, c: Z.goldHi))),
                        ],
                        const SizedBox(height: 8),
                        Container(height: 1, color: Z.divider),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: Text('Total', style: outfit(18, w: FontWeight.w800))),
                          Text(p.priceLabel, style: outfit(18, w: FontWeight.w800, c: Z.goldHi)),
                        ]),
                      ]),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 6, 10),
                child: Column(children: [
                  CtaButton('PAY ${p.priceLabel}', height: 52, fontSize: 19, onTap: () {
                    s.completePurchase(p, bonusGc: bonus);
                    Nav.replace(R.purchaseSuccess, (p, bonus));
                  }),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(
                          text: 'Gold Coins have no cash value. Sweeps Coins are a free promotional bonus. By paying you agree to the '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Press(
                          onTap: () => Nav.push(R.legal),
                          child: Text('Terms', style: outfit(11, c: Z.gold, deco: TextDecoration.underline)),
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ]),
                    textAlign: TextAlign.center,
                    style: outfit(11, c: Z.muted2, h: 1.4),
                  ),
                ]),
              ),
            ]),
            main: PaneList(
              padding: const EdgeInsets.fromLTRB(8, 12, 14, 18),
              children: [
                Text('PAYMENT METHOD', style: outfit(13, w: FontWeight.w800, ls: .12, c: Z.label)),
                const SizedBox(height: 8),
                for (final (i, (label, sub, path)) in methods.indexed) ...[
                  RadioRow(
                    label: label,
                    sub: sub,
                    glow: true,
                    selected: method == i,
                    onTap: () => setState(() => method = i),
                    icon: Container(
                      width: 44,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Z.iconTile,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Z.chipDark),
                      ),
                      child: Ico(path, size: 22),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Press(
                  onTap: () => showToast(context, 'Card form opens here in the real app'),
                  child: CustomPaint(
                    painter: _DashedRRect(),
                    child: SizedBox(
                      height: 48,
                      child: Center(child: Text('+ Add new card', style: outfit(15, w: FontWeight.w600, c: Z.gold))),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _promo,
                      textCapitalization: TextCapitalization.characters,
                      style: outfit(15, c: Z.cream),
                      cursorColor: Z.goldHi,
                      onChanged: (_) => setState(() => applied = false),
                      decoration: fieldDeco(hint: 'Promo code').copyWith(hintStyle: outfit(15, c: Z.faint)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Press(
                    onTap: () => setState(() => applied = true),
                    child: Container(
                      width: 96,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Z.field,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Z.border, width: 1.5),
                      ),
                      child: Text('APPLY', style: outfit(14, w: FontWeight.w800, c: Z.gold)),
                    ),
                  ),
                ]),
                if (applied)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(code.isNotEmpty ? 'Code $code applied — +10% bonus GC' : 'Enter a code first',
                        style: outfit(13, c: code.isNotEmpty ? Z.greenHi : Z.coral)),
                  ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _line(String label, Widget value) => Row(children: [
        Expanded(child: Text(label, style: outfit(15, c: Z.tabOff))),
        value,
      ]);
}

class _DashedRRect extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Z.chip
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)));
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 10) {
        canvas.drawPath(m.extractPath(d, d + 6), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Purchase success ─────────────────────────────────────────────────────────

class PurchaseSuccessScreen extends StatefulWidget {
  const PurchaseSuccessScreen({super.key, required this.pack, this.bonusGc = 0});
  final CoinPack pack;
  final int bonusGc;

  @override
  State<PurchaseSuccessScreen> createState() => _PurchaseSuccessScreenState();
}

class _PurchaseSuccessScreenState extends State<PurchaseSuccessScreen> with TickerProviderStateMixin {
  late final _rays = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();
  late final _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
  final order = (DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');

  @override
  void dispose() {
    _rays.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = widget.pack;
    return ZPage(
      color: Z.inkDeep,
      gradient: ellipseGradient(
          cx: .5, cy: .34, rx: .9, ry: .55, colors: const [Color(0xFF4A2A0A), Z.inkDeep], stops: const [0, .75]),
      child: Stack(children: [
        Positioned.fill(
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: .5,
            child: RaysBurst(controller: _rays, size: 640, dy: 0, slice: 8),
          ),
        ),
        Row(children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  ScaleTransition(
                    scale: CurvedAnimation(parent: _pop, curve: Curves.easeOutBack),
                    child: Coin(size: 120, fontSize: 38, big: true, glow: [bs(0, 0, 50, const Color(0xBFFFC850))]),
                  ),
                  const SizedBox(height: 14),
                  Text('Coins added!', style: outfit(28, w: FontWeight.w800, c: Z.cream)),
                  const SizedBox(height: 8),
                  FittedBox(
                    child: Text('+${fmtInt(p.gc + widget.bonusGc)} GC',
                        style: outfit(44,
                            w: FontWeight.w800,
                            c: Z.goldHi,
                            h: 1,
                            sh: [ts(0, 3, 0, const Color(0xFF6A3D00)), ts(0, 0, 24, const Color(0x99FFC850))])),
                  ),
                ]),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 16, 28, 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0x1F14B38A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0x806FE0C0)),
                        ),
                        child: Text('+ ${p.sc} SC free bonus', style: outfit(16, w: FontWeight.w700, c: Z.teal)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ZCard(
                      color: const Color(0xD9110B06),
                      padding: const EdgeInsets.all(14),
                      child: Column(children: [
                        _row('New GC balance', Text(fmtInt(s.gc), style: outfit(14, w: FontWeight.w800, c: Z.cream))),
                        const SizedBox(height: 8),
                        _row('New SC balance', Text(fmtSc(s.sc), style: outfit(14, w: FontWeight.w800, c: Z.cream))),
                        const SizedBox(height: 8),
                        _row('Receipt', Text('#Z7-$order', style: outfit(14, c: Z.body))),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    CtaButton('PLAY NOW', height: 54, fontSize: 19, onTap: () => Nav.replace(R.gold)),
                    const SizedBox(height: 10),
                    GhostButton('BACK TO WALLET', height: 48, onTap: () => Nav.tab(AppTab.wallet)),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _row(String l, Widget v) => Row(children: [
        Expanded(child: Text(l, style: outfit(14, c: Z.muted))),
        v,
      ]);
}
