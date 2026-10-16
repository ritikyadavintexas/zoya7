import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/icons.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../gold/src/math.dart' show Currency;
import '../gold/src/style.dart' show curLabel, fmtAmount;
import 'controller.dart';
import 'engine.dart';

export 'controller.dart' show BlackjackWallet;

/// The Blackjack table: one player against the dealer, landscape, sized to
/// the screen (cards scale with the table's height).
class BlackjackGame extends StatefulWidget {
  const BlackjackGame({
    super.key,
    required this.wallet,
    this.onExit,
    this.onBuyCoins,
    this.rules = const BjRules(),
    this.limits = BlackjackController.defaultLimits,
    this.onSettled,
    this.shoe,
    this.pace,
  });
  final BlackjackWallet wallet;
  final VoidCallback? onExit;
  final ValueChanged<Currency>? onBuyCoins;

  /// The table's math and limits (set from the back office).
  final BjRules rules;
  final Map<Currency, (double, double)> limits;
  final void Function(Currency currency, double staked, double returned)? onSettled;

  /// For tests: a stacked shoe and fast pacing.
  final Shoe? shoe;
  final Duration? pace;

  @override
  State<BlackjackGame> createState() => _BlackjackGameState();
}

class _BlackjackGameState extends State<BlackjackGame> {
  late final c = BlackjackController(
    wallet: widget.wallet,
    shoe: widget.shoe,
    rules: widget.rules,
    limits: widget.limits,
    onSettled: widget.onSettled,
    pace: widget.pace ?? const Duration(milliseconds: 520),
  );

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.2),
          radius: 1.1,
          colors: [Color(0xFF1D6B45), Color(0xFF0E4429), Color(0xFF06200F)],
          stops: [0, .55, 1],
        ),
      ),
      child: SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) => Column(children: [
              SizedBox(height: (h * .13).clamp(44.0, 56.0), child: _TopStrip(c: c, onExit: widget.onExit)),
              Expanded(child: _Table(c: c)),
              SizedBox(
                height: (h * .17).clamp(54.0, 72.0),
                child: _Controls(c: c, onBuyCoins: () => widget.onBuyCoins?.call(c.currency)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Top strip ────────────────────────────────────────────────────────────────

class _TopStrip extends StatelessWidget {
  const _TopStrip({required this.c, this.onExit});
  final BlackjackController c;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          BackBtn(label: 'Back to lobby', onTap: onExit ?? () => Navigator.maybePop(context)),
          const SizedBox(width: 12),
          Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('BLACKJACK', style: playfair(20, w: FontWeight.w800, c: Z.goldHi, h: 1)),
            const SizedBox(height: 2),
            Text('Pays ${payLabel(c.rules.blackjackPays)}', style: outfit(11, w: FontWeight.w600, ls: .06, c: const Color(0xFFB8D8C2))),
          ]),
          const Spacer(),
          _CurrencyToggle(c: c),
          const SizedBox(width: 8),
          Container(
            height: 36,
            padding: const EdgeInsets.fromLTRB(4, 0, 14, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xCC07150D),
              border: Border.all(color: c.currency == Currency.gc ? Z.goldEdge : const Color(0xFF2FB58E), width: 1.5),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Coin(label: curLabel(c.currency), size: 28, fontSize: 10, teal: c.currency == Currency.sc),
              const SizedBox(width: 8),
              Text(fmtAmount(c.balance, c.currency),
                  style: outfit(16, w: FontWeight.w800, c: Z.cream, features: tabular)),
            ]),
          ),
          const SizedBox(width: 8),
          RoundBtn(
            label: 'Rules',
            onTap: () => _showRules(context, c.rules),
            child: Text('?', style: outfit(18, w: FontWeight.w800, c: Z.gold)),
          ),
        ]),
      );
}

class _CurrencyToggle extends StatelessWidget {
  const _CurrencyToggle({required this.c});
  final BlackjackController c;

  @override
  Widget build(BuildContext context) {
    final enabled = c.betting && !c.busy;
    return Opacity(
      opacity: enabled ? 1 : .5,
      child: Container(
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xCC07150D),
          border: Border.all(color: const Color(0x66C99A3E)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final cur in Currency.values)
            Press(
              label: 'Play with ${cur == Currency.gc ? 'Gold' : 'Sweeps'} Coins',
              selected: c.currency == cur,
              onTap: enabled ? () => c.setCurrency(cur) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: c.currency == cur ? (cur == Currency.gc ? Z.goldTab : Z.coinTeal()) : null,
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(curLabel(cur),
                      style: outfit(12, w: FontWeight.w800, c: c.currency == cur ? Z.brown : Z.tabOff)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// "3 to 2", "6 to 5", "2 to 1"…
String payLabel(double pays) {
  for (var d = 1; d <= 10; d++) {
    final n = pays * d;
    if ((n - n.round()).abs() < 1e-6) return '${n.round()} to $d';
  }
  return '${pays.toStringAsFixed(2)} to 1';
}

void _showRules(BuildContext context, BjRules rules) => showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close rules',
      barrierColor: const Color(0xB3000000),
      pageBuilder: (ctx, _, __) => Center(
        child: Material(
          type: MaterialType.transparency,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 560, maxHeight: MediaQuery.sizeOf(ctx).height - 32),
            child: GoldFrame(
              radius: 20,
              inner: ellipseGradient(
                  cx: .5, cy: 0, rx: .9, ry: .8, colors: const [Color(0xFF1D4A31), Color(0xFF0B1A11)], stops: const [0, .8]),
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(child: Text('TABLE RULES', style: outfit(16, w: FontWeight.w800, ls: .12, c: Z.goldHi))),
                    RoundBtn(label: 'Close', onTap: () => Navigator.of(ctx).pop(), child: const StrokeIco(P.close, size: 16)),
                  ]),
                  const SizedBox(height: 8),
                  for (final r in [
                    'Get closer to 21 than the dealer without going over.',
                    'Blackjack (an Ace and a ten-value card) pays ${payLabel(rules.blackjackPays)}.',
                    rules.hitSoft17
                        ? 'Dealer hits soft 17, stands on hard 17, and checks for blackjack under an Ace or a ten.'
                        : 'Dealer stands on all 17s and checks for blackjack under an Ace or a ten.',
                    rules.doubleAfterSplit
                        ? 'Double on any first two cards, also after splitting.'
                        : 'Double on any first two cards (not after splitting).',
                    rules.maxHands > 1
                        ? 'Split pairs up to ${rules.maxHands} hands. Split Aces get one card each.'
                        : 'Pairs can\'t be split at this table.',
                    if (rules.insurance) 'Insurance is offered when the dealer shows an Ace and pays 2 to 1.',
                    '${rules.decks == 1 ? 'One deck' : '${rules.decks} decks'}, reshuffled when the cut card comes out.',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('•  $r', style: outfit(13, c: const Color(0xFFDDEBE1), h: 1.35)),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );

// ── Table ────────────────────────────────────────────────────────────────────

class _Table extends StatelessWidget {
  const _Table({required this.c});
  final BlackjackController c;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        // Cards scale with the table: dealer and player rows each get one card
        // height plus a label line.
        final cardH = ((box.maxHeight - 36 - 2 * 26) / 2).clamp(48.0, 150.0);
        final r = c.round;
        final dealerShown = r.dealer.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(children: [
            // Dealer.
            SizedBox(
              height: cardH + 26,
              child: dealerShown
                  ? _HandView(
                      label: 'DEALER',
                      total: r.holeRevealed ? r.dealerTotal : null,
                      cards: r.dealer,
                      hiddenFrom: r.holeRevealed ? null : 1,
                      cardH: cardH,
                      dealOrder: const [1, 3],
                      serial: c.dealSerial,
                      keyPrefix: 'd',
                    )
                  : Center(child: _FeltText(c.rules.hitSoft17 ? 'DEALER HITS SOFT 17' : 'DEALER STANDS ON ALL 17s', size: 13)),
            ),
            SizedBox(height: 36, child: Center(child: _Middle(c: c))),
            // Player.
            SizedBox(
              height: cardH + 26,
              child: r.hands.isEmpty
                  ? Center(child: _BetCircle(c: c, size: (cardH * .9).clamp(56.0, 110.0)))
                  : LayoutBuilder(
                      builder: (context, row) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        for (final (i, hand) in r.hands.indexed)
                          SizedBox(
                            width: math.min(row.maxWidth / r.hands.length, cardH * .7 * 3.2),
                            child: _HandView(
                              label: r.hands.length > 1 ? 'HAND ${i + 1}' : 'YOU',
                              total: hand.total,
                              soft: hand.soft && hand.total < 21,
                              cards: hand.cards,
                              cardH: cardH,
                              bet: hand.bet,
                              currency: c.currency,
                              outcome: hand.outcome,
                              active: r.phase == Phase.player && i == r.active && r.hands.length > 1,
                              dealOrder: r.hands.length == 1 ? const [0, 2] : const [],
                              serial: c.dealSerial,
                              keyPrefix: 'p$i',
                            ),
                          ),
                      ]),
                    ),
            ),
          ]),
        );
      });
}

class _FeltText extends StatelessWidget {
  const _FeltText(this.text, {this.size = 12});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, style: outfit(size, w: FontWeight.w800, ls: .18, c: const Color(0x99E8C06A))),
      );
}

/// Middle line of the felt: the house rules, the insurance question, or the
/// result of the round.
class _Middle extends StatelessWidget {
  const _Middle({required this.c});
  final BlackjackController c;

  @override
  Widget build(BuildContext context) {
    if (c.shuffling) return const _FeltText('SHUFFLING THE SHOE…', size: 14);
    switch (c.phase) {
      case Phase.insurance:
        return Text('Dealer shows an Ace — insurance?', style: outfit(16, w: FontWeight.w800, c: Z.goldHi));
      case Phase.dealer:
        return Text('Dealer plays…', style: outfit(15, w: FontWeight.w700, c: const Color(0xFFDDEBE1)));
      case Phase.settled:
        final net = c.net;
        final cur = curLabel(c.currency);
        final blackjack = c.round.hands.any((h) => h.outcome == Outcome.blackjack);
        final (text, color) = net > 0
            ? ('${blackjack ? 'BLACKJACK! ' : 'YOU WIN '}+${fmtAmount(net, c.currency)} $cur', Z.goldHi)
            : net == 0
                ? ('PUSH — BET RETURNED', const Color(0xFFDDEBE1))
                : (c.round.dealerBlackjack ? 'DEALER BLACKJACK' : 'DEALER WINS', Z.coral);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xCC07150D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: .7), width: 1.5),
            boxShadow: net > 0 ? [bs(0, 0, 18, const Color(0x80FFC850))] : null,
          ),
          child: Text(text, style: outfit(16, w: FontWeight.w800, ls: .06, c: color)),
        );
      case Phase.betting:
      case Phase.player:
        return const _FeltText('BLACKJACK PAYS 3 TO 2   •   INSURANCE PAYS 2 TO 1');
    }
  }
}

/// A hand of overlapping cards with its label, total, bet and result.
class _HandView extends StatelessWidget {
  const _HandView({
    required this.label,
    required this.total,
    required this.cards,
    required this.cardH,
    required this.serial,
    required this.keyPrefix,
    this.soft = false,
    this.hiddenFrom,
    this.bet,
    this.currency = Currency.gc,
    this.outcome,
    this.active = false,
    this.dealOrder = const [],
  });
  final String label;
  final int? total;
  final bool soft;
  final List<PlayingCard> cards;
  final double cardH;
  final int? hiddenFrom;
  final double? bet;
  final Currency currency;
  final Outcome? outcome;
  final bool active;

  /// Positions of the first cards in the initial deal (for staggered entry).
  final List<int> dealOrder;
  final int serial;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final cardW = cardH * .7;
        final n = cards.length;
        // Overlap more as the hand grows, so it always fits its column.
        final step = n <= 1 ? 0.0 : math.min(cardW * .55, (box.maxWidth - 8 - cardW) / (n - 1));
        final (tag, tagColor) = switch (outcome) {
          Outcome.blackjack => ('BLACKJACK', Z.goldHi),
          Outcome.win => ('WIN', Z.greenHi),
          Outcome.push => ('PUSH', const Color(0xFFDDEBE1)),
          Outcome.lose => ('LOSE', Z.coral),
          Outcome.bust => ('BUST', Z.coral),
          null => (null, Z.cream),
        };
        return Column(children: [
          SizedBox(
            height: 22,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(label, style: outfit(11, w: FontWeight.w800, ls: .12, c: active ? Z.goldHi : const Color(0xB3DDEBE1))),
              if (total != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(
                    color: total! > 21 ? const Color(0xFF8A1A1A) : const Color(0xE607150D),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: active ? Z.goldBright : const Color(0x66E8C06A)),
                  ),
                  child: Text(soft ? '${total! - 10}/$total' : '$total',
                      style: outfit(12, w: FontWeight.w800, c: Z.cream, features: tabular)),
                ),
              ],
              if (bet != null) ...[
                const SizedBox(width: 6),
                Text('${fmtAmount(bet!, currency)} ${curLabel(currency)}',
                    style: outfit(11, w: FontWeight.w700, c: const Color(0xFFE8C06A))),
              ],
              if (tag != null) ...[
                const SizedBox(width: 6),
                Text(tag, style: outfit(11, w: FontWeight.w800, ls: .08, c: tagColor)),
              ],
            ]),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: active
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(cardH * .1),
                    boxShadow: [bs(0, 0, 14, const Color(0xAAFFD45A))],
                  )
                : null,
            child: SizedBox(
              width: cardW + step * math.max(0, n - 1),
              height: cardH - 4,
              child: Stack(children: [
                for (var i = 0; i < n; i++)
                  Positioned(
                    left: step * i,
                    top: 0,
                    child: _DealtCard(
                      key: ValueKey('$serial-$keyPrefix-$i'),
                      delay: i < dealOrder.length ? dealOrder[i] : 0,
                      child: _CardView(cards[i], height: cardH - 4, faceDown: hiddenFrom != null && i >= hiddenFrom!),
                    ),
                  ),
              ]),
            ),
          ),
        ]);
      });
}

/// A card flying in from the shoe (top right), after [delay] deal steps.
class _DealtCard extends StatefulWidget {
  const _DealtCard({super.key, required this.child, this.delay = 0});
  final Widget child;
  final int delay;

  @override
  State<_DealtCard> createState() => _DealtCardState();
}

class _DealtCardState extends State<_DealtCard> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay * 200), () {
      if (mounted) _a.forward();
    });
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_a.value);
          return Opacity(
            opacity: _a.value.clamp(0, 1),
            child: Transform.translate(offset: Offset(160 * (1 - t), -120 * (1 - t)), child: child),
          );
        },
        child: widget.child,
      );
}

const _suitPaths = {
  Suit.hearts:
      'M12 21s-7.5-4.6-9.5-9.2C1 8.4 3.2 4.5 7 4.5c2.1 0 3.6 1.2 5 3 1.4-1.8 2.9-3 5-3 3.8 0 6 3.9 4.5 7.3C19.5 16.4 12 21 12 21z',
  Suit.diamonds: 'M12 2l8 10-8 10-8-10z',
  Suit.spades:
      'M12 2C9 6 3.5 9.5 3.5 13.5 3.5 16.2 5.6 18 8 18c1.4 0 2.6-.6 3.3-1.6-.2 2.2-1 3.8-2.6 5.1h6.6c-1.6-1.3-2.4-2.9-2.6-5.1.7 1 1.9 1.6 3.3 1.6 2.4 0 4.5-1.8 4.5-4.5C20.5 9.5 15 6 12 2z',
  Suit.clubs:
      'M12 2.5a4 4 0 0 0-3.6 5.8A4 4 0 1 0 10.6 15.8c-.3 2.3-1.1 4-2.6 5.2h8c-1.5-1.2-2.3-2.9-2.6-5.2a4 4 0 1 0 2.2-7.5A4 4 0 0 0 12 2.5z',
};

/// A playing card face (or back), drawn to [height].
class _CardView extends StatelessWidget {
  const _CardView(this.card, {required this.height, this.faceDown = false});
  final PlayingCard card;
  final double height;
  final bool faceDown;

  @override
  Widget build(BuildContext context) {
    final w = height * .7;
    final r = BorderRadius.circular(height * .08);
    return TweenAnimationBuilder<double>(
      // Flips over when it's turned face up.
      tween: Tween(end: faceDown ? 1 : 0),
      duration: const Duration(milliseconds: 360),
      builder: (context, v, _) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .001)
          ..rotateY(v * math.pi),
        child: v > .5
            ? Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..rotateY(math.pi),
                child: _back(w, r),
              )
            : _face(w, r),
      ),
    );
  }

  Widget _back(double w, BorderRadius r) => Semantics(
        label: 'Face-down card',
        child: Container(
          width: w,
          height: height,
          padding: EdgeInsets.all(w * .07),
          decoration: BoxDecoration(
            color: const Color(0xFFF7EEDB),
            borderRadius: r,
            boxShadow: [bs(0, 3, 8, const Color(0x99000000))],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height * .05),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFB0121C), Color(0xFF6A0710)],
              ),
              border: Border.all(color: Z.goldEdge, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text('Z7', style: playfair(height * .2, w: FontWeight.w800, c: Z.goldHi)),
          ),
        ),
      );

  Widget _face(double w, BorderRadius r) {
    final color = card.isRed ? const Color(0xFFC8102E) : const Color(0xFF14161A);
    final path = _suitPaths[card.suit]!;
    final corner = Column(mainAxisSize: MainAxisSize.min, children: [
      Text(card.label, style: outfit(height * .2, w: FontWeight.w800, c: color, h: 1)),
      Ico(path, size: height * .13, color: color),
    ]);
    final suitName = card.suit.name;
    final rankName = switch (card.rank) { 1 => 'Ace', 11 => 'Jack', 12 => 'Queen', 13 => 'King', _ => card.label };
    return Semantics(
      label: '$rankName of $suitName',
      child: Container(
        width: w,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFFBF8F1),
          borderRadius: r,
          border: Border.all(color: const Color(0xFFD9D2C3)),
          boxShadow: [bs(0, 3, 8, const Color(0x99000000))],
        ),
        child: Stack(children: [
          Positioned(left: w * .07, top: height * .05, child: corner),
          Positioned(right: w * .07, bottom: height * .05, child: Transform.rotate(angle: math.pi, child: corner)),
          Center(
            child: card.rank > 10
                ? Text(card.label, style: playfair(height * .42, w: FontWeight.w800, c: color, h: 1))
                : Ico(path, size: height * .38, color: color),
          ),
        ]),
      ),
    );
  }
}

/// The betting circle with the chips placed on it.
class _BetCircle extends StatelessWidget {
  const _BetCircle({required this.c, required this.size});
  final BlackjackController c;
  final double size;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x99E8C06A), width: 2),
            color: const Color(0x2207150D),
          ),
          alignment: Alignment.center,
          child: c.bet > 0
              ? _ChipView(c.bet, currency: c.currency, size: size * .62)
              : Text('BET', style: outfit(size * .18, w: FontWeight.w800, ls: .14, c: const Color(0x99E8C06A))),
        ),
        const SizedBox(width: 14),
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.bet > 0 ? 'YOUR BET' : 'PLACE YOUR BET',
              style: outfit(12, w: FontWeight.w800, ls: .12, c: const Color(0xB3DDEBE1))),
          const SizedBox(height: 2),
          Text(c.bet > 0 ? '${fmtAmount(c.bet, c.currency)} ${curLabel(c.currency)}' : 'Tap chips below',
              style: outfit(18, w: FontWeight.w800, c: Z.cream)),
          if (c.note != null) ...[
            const SizedBox(height: 2),
            Text(c.note!, style: outfit(12, w: FontWeight.w600, c: Z.coral)),
          ],
        ]),
      ]);
}

const _chipColors = [Color(0xFF2F6FD6), Color(0xFFC8202C), Color(0xFF1E9A50), Color(0xFF1A1A1A)];

String _chipLabel(double v, Currency c) {
  if (c == Currency.sc) return v < 1 ? v.toStringAsFixed(2) : v.toStringAsFixed(0);
  return v >= 1000 ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}K' : v.toStringAsFixed(0);
}

class _ChipView extends StatelessWidget {
  const _ChipView(this.value, {required this.currency, required this.size, this.index});
  final double value;
  final Currency currency;
  final double size;
  final int? index;

  @override
  Widget build(BuildContext context) {
    final color = _chipColors[(index ?? 3) % _chipColors.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: size * .07),
        boxShadow: [bs(0, 3, 6, const Color(0x99000000))],
      ),
      padding: EdgeInsets.all(size * .1),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xCCFFFFFF), width: 1.2),
          color: color,
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.all(size * .04),
            child: Text(_chipLabel(value, currency),
                style: outfit(size * .28, w: FontWeight.w800, c: Colors.white, h: 1)),
          ),
        ),
      ),
    );
  }
}

// ── Controls ─────────────────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  const _Controls({required this.c, required this.onBuyCoins});
  final BlackjackController c;
  final VoidCallback onBuyCoins;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x0007150D), Color(0xCC050E08)],
          ),
        ),
        child: LayoutBuilder(builder: (context, box) {
          final h = box.maxHeight;
          final cur = curLabel(c.currency);
          switch (c.phase) {
            case Phase.betting:
              final broke = c.balance < c.minBet;
              return Row(children: [
                for (final (i, v) in c.chips.indexed) ...[
                  Press(
                    label: 'Add ${_chipLabel(v, c.currency)} $cur chip',
                    onTap: c.busy || v > c.balance ? null : () => c.addChip(v),
                    child: Opacity(
                      opacity: v > c.balance ? .35 : 1,
                      child: _ChipView(v, currency: c.currency, size: h, index: i),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                if (c.bet > 0)
                  _ActionBtn('CLEAR', kind: _Kind.ghost, height: h, onTap: c.clearBet)
                else if (c.lastBet > 0)
                  _ActionBtn('REBET', kind: _Kind.ghost, height: h, onTap: c.rebet),
                const SizedBox(width: 8),
                broke
                    ? _ActionBtn('GET COINS', kind: _Kind.gold, height: h, onTap: onBuyCoins)
                    : _ActionBtn(
                        'DEAL',
                        kind: _Kind.red,
                        height: h,
                        wide: true,
                        onTap: c.canDeal ? c.deal : null,
                      ),
              ]);
            case Phase.insurance:
              return Row(children: [
                Expanded(
                  child: Text('Insurance costs ${fmtAmount(c.insuranceCost, c.currency)} $cur and pays 2 to 1 if the dealer has blackjack.',
                      maxLines: 2, style: outfit(13, c: const Color(0xFFDDEBE1), h: 1.3)),
                ),
                const SizedBox(width: 10),
                _ActionBtn('NO THANKS', kind: _Kind.ghost, height: h, onTap: () => c.insurance(false)),
                const SizedBox(width: 8),
                _ActionBtn('INSURE', kind: _Kind.gold, height: h, onTap: c.canInsure ? () => c.insurance(true) : null),
              ]);
            case Phase.player:
            case Phase.dealer:
              return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _ActionBtn('HIT', kind: _Kind.green, height: h, wide: true, onTap: c.canHit ? c.hit : null),
                const SizedBox(width: 10),
                _ActionBtn('STAND', kind: _Kind.red, height: h, wide: true, onTap: c.canStand ? c.stand : null),
                const SizedBox(width: 10),
                _ActionBtn('DOUBLE', kind: _Kind.gold, height: h, onTap: c.canDouble ? c.doubleDown : null),
                const SizedBox(width: 10),
                _ActionBtn('SPLIT', kind: _Kind.purple, height: h, onTap: c.canSplit ? c.split : null),
              ]);
            case Phase.settled:
              final again = c.lastBet <= c.balance;
              return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _ActionBtn('CHANGE BET', kind: _Kind.ghost, height: h, onTap: c.busy ? null : c.newRound),
                const SizedBox(width: 10),
                again
                    ? _ActionBtn('PLAY AGAIN · ${fmtAmount(c.lastBet, c.currency)}',
                        kind: _Kind.red, height: h, wide: true, onTap: c.busy ? null : c.playAgain)
                    : _ActionBtn('GET COINS', kind: _Kind.gold, height: h, onTap: onBuyCoins),
              ]);
          }
        }),
      );
}

enum _Kind { red, green, gold, purple, ghost }

class _ActionBtn extends StatelessWidget {
  const _ActionBtn(this.label, {required this.kind, required this.height, this.onTap, this.wide = false});
  final String label;
  final _Kind kind;
  final double height;
  final VoidCallback? onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final gradient = switch (kind) {
      _Kind.red => Z.red3,
      _Kind.green => Z.green3,
      _Kind.gold => Z.goldTab,
      _Kind.purple => const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF9B4FE0), Color(0xFF4E1A85)]),
      _Kind.ghost => null,
    };
    final text = kind == _Kind.gold ? Z.brown : (kind == _Kind.ghost ? Z.gold : Z.cream);
    return Press(
      label: label,
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? .4 : 1,
        child: Container(
          height: height,
          constraints: BoxConstraints(minWidth: wide ? 130 : 96),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            gradient: gradient,
            color: gradient == null ? const Color(0xCC07150D) : null,
            border: Border.all(color: kind == _Kind.ghost ? Z.border : Z.rimBright, width: 1.5),
            boxShadow: onTap != null && kind != _Kind.ghost ? [bs(0, 0, 12, const Color(0x40FFC846))] : null,
          ),
          child: Center(
            widthFactor: 1,
            child: Text(label, style: outfit(15, w: FontWeight.w800, ls: .06, c: text)),
          ),
        ),
      ),
    );
  }
}
