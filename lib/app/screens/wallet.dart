import 'package:flutter/material.dart';

import '../../backoffice/casino.dart';
import '../icons.dart';
import '../nav.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'promotions.dart' show RaysBurst;

class WalletPage extends StatefulWidget {
  const WalletPage({super.key, this.initialTab = 'buy'});

  /// 'buy' or 'history'.
  final String initialTab;

  @override
  State<WalletPage> createState() => WalletPageState();
}

class WalletPageState extends State<WalletPage> {
  static const tabs = ['buy', 'history'];
  late int tab = tabs.indexOf(widget.initialTab).clamp(0, 1);

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // Small phones: shorter labels in the top strip.
    final narrow = MediaQuery.sizeOf(context).width < 700;
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Balances and the three sections in one strip.
              SizedBox(
                height: 50,
                child: Row(children: [
                  _BalanceChip(
                    coin: const Coin(size: 30, fontSize: 10),
                    label: 'GOLD COINS',
                    labelColor: Z.label,
                    value: fmtInt(s.gc),
                  ),
                  const SizedBox(width: 8),
                  _BalanceChip(
                    coin: const Coin(label: 'DC', size: 30, fontSize: 10, teal: true),
                    label: 'DC',
                    labelColor: Z.teal,
                    value: fmtSc(s.sc),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: SegTabs(
                          labels: narrow ? const ['BUY', 'HISTORY'] : const ['BUY COINS', 'HISTORY'],
                          index: tab,
                          height: 36,
                          fontSize: 12,
                          ls: .04,
                          onChanged: (i) => setState(() => tab = i),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: switch (tab) {
                  0 => _buy(s),
                  _ => _history(s),
                },
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // Packs in one row (sideways scroll when they don't fit), buy button below.
  Widget _buy(AppState s) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            const gap = 10.0;
            final w = ((box.maxWidth - gap * (coinPacks.length - 1)) / coinPacks.length).clamp(118.0, 180.0);
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.only(top: 8),
              itemCount: coinPacks.length,
              separatorBuilder: (_, __) => const SizedBox(width: gap),
              itemBuilder: (_, i) => SizedBox(
                width: w,
                child: _PackTile(coinPacks[i], selected: i == s.selectedPack, onTap: () => s.selectPack(i)),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Text('Coins are for play only and have no cash value. DC are a free bonus with Gold Coin packages.',
                style: outfit(12, c: Z.muted2, h: 1.35)),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 290,
            child: CtaButton('BUY ${s.pack.gcLabel} GC · ${s.pack.priceLabel}',
                height: 46, fontSize: 16, ls: .03, onTap: () => Nav.push(R.checkout)),
          ),
        ]),
      ]);

  // Two columns of compact entries.
  Widget _history(AppState s) {
    String when(DateTime t) {
      final now = s.casino.now;
      final days = DateTime(now.year, now.month, now.day).difference(DateTime(t.year, t.month, t.day)).inDays;
      final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
      final clock = '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
      return switch (days) { 0 => 'Today · $clock', 1 => 'Yesterday · $clock', _ => '${monthName(t.month)} ${t.day}' };
    }

    // The latest moves on this account, from the back office's ledger.
    final hist = [
      for (final t in s.casino.txnsOf(s.playerId ?? '').take(6))
        (
          t.sc != 0 && t.gc == 0 ? 'DC' : 'GC',
          t.note.isNotEmpty ? t.note : statusName(t.type),
          when(t.at),
          t.gc != 0 ? '${t.gc > 0 ? '+' : '−'}${fmtInt(t.gc.abs())} GC' : '${t.sc > 0 ? '+' : '−'}${fmtSc(t.sc.abs())} DC',
          t.gc + t.sc >= 0,
        ),
    ];
    return GridView(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 420, mainAxisExtent: 58, mainAxisSpacing: 8, crossAxisSpacing: 10),
      children: [
        for (final (icon, title, at, amount, plus) in hist)
          ZCard(
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: icon == 'DC' ? Z.coinTeal() : Z.coinGold(),
                ),
                child: Text(icon, style: outfit(11, w: FontWeight.w800, c: icon == 'DC' ? Z.tealInk : Z.coinInk)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: outfit(14, w: FontWeight.w700, c: Z.cream)),
                  Text(at, style: outfit(11, c: Z.muted2)),
                ]),
              ),
              Text(amount, style: outfit(14, w: FontWeight.w800, c: plus ? Z.green : Z.coral)),
            ]),
          ),
      ],
    );
  }
}

class _BalanceChip extends StatelessWidget {
  const _BalanceChip({required this.coin, required this.label, required this.labelColor, required this.value});
  final Widget coin;
  final String label;
  final Color labelColor;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(8, 0, 14, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Z.border, width: 1.5),
          gradient: ellipseGradient(
              cx: 0, cy: 0, rx: 1, ry: 1, colors: const [Color(0xFF3A2209), Color(0xFF0D0906)], stops: const [0, .8]),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          coin,
          const SizedBox(width: 8),
          Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: outfit(9, w: FontWeight.w700, ls: .08, c: labelColor)),
            Text(value, style: outfit(18, w: FontWeight.w800, c: Z.cream, h: 1.1)),
          ]),
        ]),
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
        label: '${p.gcLabel} Gold Coins plus ${p.sc} DC, ${p.priceLabel}',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: ellipseGradient(
                cx: .5, cy: 0, rx: 1, ry: .7, colors: const [Color(0xFF3A2209), Z.field], stops: const [0, .75]),
            border: Border.all(color: selected ? Z.goldBright : Z.chip, width: selected ? 2 : 1.5),
            boxShadow: selected ? [bs(0, 0, 16, const Color(0x73FFC846))] : null,
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              // The coin grows with the tile; the price button stays put.
              final coin = (box.maxHeight * .3).clamp(26.0, 50.0);
              return Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
                Column(children: [
                  const Spacer(),
                  Coin(size: coin, fontSize: coin * .3, glow: [bs(0, 0, 14, const Color(0x73FFC850))]),
                  const SizedBox(height: 4),
                  Text(p.gcLabel, style: outfit(19, w: FontWeight.w800, c: Z.cream, h: 1.1)),
                  Text('+ ${p.sc} DC FREE', style: outfit(11, w: FontWeight.w700, c: Z.teal)),
                  const Spacer(),
                  Container(
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: Z.green3),
                    child: Text(p.priceLabel, style: outfit(15, w: FontWeight.w800, c: Z.cream)),
                  ),
                ]),
                if (p.tag != null)
                  Positioned(
                    top: -19,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFE0303B), Color(0xFF9A0A14)]),
                      ),
                      child: Text(p.tag!, style: outfit(10, w: FontWeight.w800, ls: .08, c: Z.cream)),
                    ),
                  ),
              ]);
            },
          ),
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
          constraints: BoxConstraints(minHeight: sub == null ? 46 : 56),
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
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 6, 4),
                  children: [
                    GoldFrame(
                      inner: ellipseGradient(
                          cx: 0, cy: 0, rx: 1, ry: .8, colors: const [Color(0xFF3A2209), Color(0xFF0D0906)], stops: const [0, .7]),
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Coin(size: 46, fontSize: 14, glow: [bs(0, 0, 18, const Color(0x80FFC850))]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.tag == null ? 'GOLD COIN PACKAGE' : '${p.tag} PACKAGE',
                                style: outfit(12, w: FontWeight.w700, ls: .12, c: Z.label)),
                            const SizedBox(height: 2),
                            Text('${fmtInt(p.gc)} GC', style: outfit(20, w: FontWeight.w800, c: Z.cream)),
                            const SizedBox(height: 2),
                            Text('+ ${p.sc} DC free', style: outfit(14, w: FontWeight.w700, c: Z.teal)),
                          ]),
                        ),
                        Text(p.priceLabel, style: outfit(20, w: FontWeight.w800, c: Z.cream)),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(children: [
                        if (bonus > 0) ...[
                          _line('Promo bonus', Text('+${fmtInt(bonus)} GC', style: outfit(14, w: FontWeight.w700, c: Z.goldHi))),
                          const SizedBox(height: 6),
                        ],
                        Row(children: [
                          Expanded(child: Text('Total', style: outfit(17, w: FontWeight.w800))),
                          Text(p.priceLabel, style: outfit(17, w: FontWeight.w800, c: Z.goldHi)),
                        ]),
                      ]),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 6, 10),
                child: Column(children: [
                  CtaButton('PAY ${p.priceLabel}', height: 48, fontSize: 18, onTap: () {
                    if (!s.storeOpen) {
                      showToast(context, 'Coin packs aren’t sold in the app yet — ask your cashier for coins');
                      return;
                    }
                    s.completePurchase(p, bonusGc: bonus);
                    Nav.replace(R.purchaseSuccess, (p, bonus));
                  }),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'GC have no cash value; DC are a free bonus. By paying you agree to the '),
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
            main: ListView(
              padding: const EdgeInsets.fromLTRB(8, 12, 14, 18),
              children: [
                Text('PAYMENT METHOD', style: outfit(13, w: FontWeight.w800, ls: .12, c: Z.label)),
                const SizedBox(height: 8),
                // Methods side by side (stacked when the pane is narrow).
                LayoutBuilder(builder: (context, box) {
                  final across = box.maxWidth >= 420;
                  final cards = [
                    for (final (i, (label, sub, path)) in methods.indexed)
                      _MethodCard(
                        label: label,
                        sub: sub,
                        icon: path,
                        selected: method == i,
                        compact: !across,
                        onTap: () => setState(() => method = i),
                      ),
                  ];
                  return across
                      ? IntrinsicHeight(
                          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            for (final (i, c) in cards.indexed) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: c)],
                          ]),
                        )
                      : Column(children: [
                          for (final (i, c) in cards.indexed) ...[if (i > 0) const SizedBox(height: 6), c],
                        ]);
                }),
                const SizedBox(height: 10),
                Row(children: [
                  Press(
                    onTap: () => showToast(context, 'Card form opens here in the real app'),
                    child: CustomPaint(
                      painter: _DashedRRect(),
                      child: SizedBox(
                        height: 44,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Center(
                            widthFactor: 1,
                            child: Text('+ Add card', style: outfit(14, w: FontWeight.w600, c: Z.gold)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                      width: 80,
                      height: 44,
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

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.label,
    required this.sub,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });
  final String label;
  final String sub;
  final String icon;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: 40,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Z.iconTile,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Z.chipDark),
      ),
      child: Ico(icon, size: 20),
    );
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: outfit(14, w: FontWeight.w700, c: Z.cream)),
      Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: outfit(11, c: Z.muted2, h: 1.25)),
    ]);
    return Press(
      onTap: onTap,
      selected: selected,
      label: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.all(compact ? 7 : 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Z.field,
          border: Border.all(color: selected ? Z.goldBright : Z.chipDark, width: selected ? 2 : 1.5),
          boxShadow: selected ? [bs(0, 0, 12, const Color(0x4DFFC846))] : null,
        ),
        child: compact
            ? Row(children: [tile, const SizedBox(width: 10), Expanded(child: text)])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [tile, const SizedBox(height: 6), text]),
      ),
    );
  }
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
                        child: Text('+ ${p.sc} DC free bonus', style: outfit(16, w: FontWeight.w700, c: Z.teal)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ZCard(
                      color: const Color(0xD9110B06),
                      padding: const EdgeInsets.all(14),
                      child: Column(children: [
                        _row('New GC balance', Text(fmtInt(s.gc), style: outfit(14, w: FontWeight.w800, c: Z.cream))),
                        const SizedBox(height: 8),
                        _row('New DC balance', Text(fmtSc(s.sc), style: outfit(14, w: FontWeight.w800, c: Z.cream))),
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
