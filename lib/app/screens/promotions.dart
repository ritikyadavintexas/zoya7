import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons.dart';
import '../nav.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'lobby.dart' show Avatar;

String _countdown(int secs) {
  String pad(int n) => n.toString().padLeft(2, '0');
  final d = secs ~/ 86400, h = (secs % 86400) ~/ 3600, m = (secs % 3600) ~/ 60, s = secs % 60;
  return '${d}d ${pad(h)}:${pad(m)}:${pad(s)}';
}

/// Shared weekend-race clock (both Promotions and the leaderboard count down to it).
final raceEnds = DateTime.now().add(const Duration(days: 2, hours: 5, minutes: 42, seconds: 17));
int raceSecondsLeft() => math.max(0, raceEnds.difference(DateTime.now()).inSeconds);

mixin _Ticker<T extends StatefulWidget> on State<T> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}

String _short(int v) => v >= 1000 ? '${v ~/ 1000}K' : '$v';

// ── Promotions & daily bonus ─────────────────────────────────────────────────

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key});

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> with _Ticker {
  bool copied = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final claim = s.bonusClaimed
        ? Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Z.chipDark, width: 1.5),
              color: Z.field,
            ),
            child: Text('CLAIMED — BACK TOMORROW', style: outfit(14, w: FontWeight.w800, ls: .04, c: Z.muted)),
          )
        : CtaButton('CLAIM ${fmtInt(s.todayBonus)} GC', height: 46, fontSize: 16, onTap: () {
            s.claimBonus();
            showToast(context, '+${fmtInt(s.todayBonus)} GC added to your balance');
          });
    final title = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text('DAILY BONUS', style: outfit(12, w: FontWeight.w700, ls: .14, c: Z.label)),
      const SizedBox(height: 2),
      Text('Day ${s.streakDay} streak', style: outfit(20, w: FontWeight.w800, c: Z.cream, h: 1.1)),
      const SizedBox(height: 2),
      Text('Resets in 07:12:44', style: outfit(12, c: Z.body)),
    ]);
    Widget daily({required bool strip}) => GoldFrame(
          shadows: [bs(0, 8, 22, const Color(0x80000000))],
          inner: ellipseGradient(
              cx: .5, cy: 0, rx: .9, ry: .9, colors: const [Color(0xFF5A1A10), Color(0xFF150B06)], stops: const [0, .8]),
          padding: const EdgeInsets.all(12),
          child: strip
              // Wide: title · streak · claim in one strip.
              ? Row(children: [
                  title,
                  const SizedBox(width: 16),
                  const Expanded(child: StreakRow(tall: true)),
                  const SizedBox(width: 16),
                  SizedBox(width: 200, child: claim),
                ])
              // Narrower: a card — title, streak, claim.
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  title,
                  const Spacer(),
                  const StreakRow(tall: true),
                  const Spacer(),
                  claim,
                ]),
        );
    final offers = [
      _OfferCard(
        tint: const Color(0xFF2A1A08),
        iconGradient: Z.coinGold(),
        icon: const Ico(P.gift, size: 24, color: Z.coinInk),
        title: 'Welcome Pack',
        body: Text('Bonus Gold Coins plus free Sweeps Coins on your first package.', style: outfit(13, c: Z.body, h: 1.3)),
        action: _PillAction('GET PACK', gold: true, onTap: () => Nav.tab(AppTab.wallet, walletTab: 'buy')),
      ),
      _OfferCard(
        tint: const Color(0xFF0E2A1A),
        iconGradient: Z.coinTeal(),
        icon: const Ico(P.addFriend, size: 24, color: Z.tealInk),
        title: 'Refer a Friend',
        body: Text('You both get a bonus when they sign up and play.', style: outfit(13, c: Z.body, h: 1.3)),
        action: Row(children: [
          Expanded(
            child: DottedBox(
              child: Text(s.name.toUpperCase(),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: outfit(14, w: FontWeight.w800, ls: .1, c: Z.goldHi)),
            ),
          ),
          const SizedBox(width: 8),
          Press(
            onTap: () {
              Clipboard.setData(ClipboardData(text: s.name.toUpperCase()));
              setState(() => copied = true);
              showToast(context, 'Referral code copied');
            },
            child: Container(
              width: 72,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: Z.green3),
              child: Text(copied ? 'COPIED' : 'COPY', style: outfit(13, w: FontWeight.w800, c: Z.cream)),
            ),
          ),
        ]),
      ),
      _OfferCard(
        tint: const Color(0xFF261040),
        iconGradient: circleGradient(
            cx: .4, cy: .3, colors: const [Color(0xFFE3C2FF), Color(0xFF9B4FE0), Color(0xFF4E1A85)], stops: const [0, .6, 1]),
        icon: const Ico(P.trophyFull, size: 24, color: Color(0xFF24083F)),
        title: 'Weekend Slots Race',
        body: Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Climb the leaderboard for Gold Coin prizes. Ends in '),
            TextSpan(
                text: _countdown(raceSecondsLeft()), style: outfit(13, w: FontWeight.w800, c: Z.goldHi, features: tabular)),
          ]),
          style: outfit(13, c: Z.body, h: 1.3),
        ),
        action: _PillAction('JOIN RACE', onTap: () => Nav.push(R.leaderboard)),
      ),
    ];
    // Offers: side by side, scrolling sideways when they don't all fit.
    Widget offerRow() => LayoutBuilder(builder: (context, box) {
          const gap = 10.0;
          final w = ((box.maxWidth - 2 * gap) / 3).clamp(220.0, 320.0);
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: offers.length,
            separatorBuilder: (_, __) => const SizedBox(width: gap),
            itemBuilder: (_, i) => SizedBox(width: w, child: offers[i]),
          );
        });
    return ZPage(
      child: Column(children: [
        TopBar(title: 'PROMOTIONS', backLabel: 'Back to lobby', onBack: () => Nav.tab(AppTab.home)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: LayoutBuilder(
              builder: (context, box) => box.maxWidth >= 760
                  // Wide: the daily bonus strip on top, the offers below.
                  ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      daily(strip: true),
                      const SizedBox(height: 12),
                      Expanded(child: offerRow()),
                    ])
                  // Narrower: the daily bonus card beside the offers.
                  : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      SizedBox(width: (box.maxWidth * .44).clamp(250.0, 320.0), child: daily(strip: false)),
                      const SizedBox(width: 12),
                      Expanded(child: offerRow()),
                    ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Seven-day streak tiles. [tall] = the Promotions version with amounts.
class StreakRow extends StatelessWidget {
  const StreakRow({super.key, this.tall = false});
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final gap = tall ? 5.0 : 4.0;
    // One row of seven while each day gets 40px, otherwise days 1–4 over 5–7.
    return LayoutBuilder(builder: (context, box) {
      final perRow = (box.maxWidth - 6 * gap) / 7 >= 40 ? 7 : 4;
      final w = (box.maxWidth - (perRow - 1) * gap) / perRow;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (var n = 1; n <= 7; n++) SizedBox(width: w, child: _day(s, n)),
      ]);
    });
  }

  Widget _day(AppState s, int n) {
    final done = n < s.streakDay || (n == s.streakDay && s.bonusClaimed);
    final today = n == s.streakDay && !s.bonusClaimed;
    if (!tall) {
      return Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          gradient: today ? Z.goldBadge : null,
          color: today ? null : (done ? const Color(0x243FD17A) : Z.field),
          border: today ? null : Border.all(color: done ? const Color(0x803FD17A) : Z.chipDark),
          boxShadow: today ? [bs(0, 0, 10, const Color(0x99FFC846))] : null,
        ),
        child: done
            ? const StrokeIco(P.check, size: 14, color: Z.greenHi, width: 3.2)
            : Text('D$n', style: outfit(12, w: FontWeight.w800, c: today ? Z.brown : Z.muted)),
      );
    }
    final last = n == 7;
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: today
            ? const LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFB0121C), Color(0xFF5A0408)])
            : last
                ? const LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3A2A0A), Z.field])
                : null,
        color: today || last ? null : (done ? const Color(0x1A3FD17A) : Z.field),
        border: Border.all(
          color: today
              ? Z.goldBright
              : last
                  ? Z.goldEdge
                  : done
                      ? const Color(0x803FD17A)
                      : Z.chipDark,
          width: today ? 2 : 1.5,
        ),
        boxShadow: today ? [bs(0, 0, 12, const Color(0x99FFC846))] : null,
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        FittedBox(child: Text('DAY $n', style: outfit(10, w: FontWeight.w700, ls: .04, c: Z.soft))),
        const SizedBox(height: 3),
        done
            ? Semantics(label: 'Claimed', child: const StrokeIco(P.check, size: 18, color: Z.green, width: 3.2))
            : FittedBox(child: Text(_short(s.streakAmounts[n - 1]), style: outfit(12, w: FontWeight.w800, c: Z.goldHi))),
      ]),
    );
  }
}

class DottedBox extends StatelessWidget {
  const DottedBox({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _DashPainter(),
        child: SizedBox(height: 42, child: Center(child: child)),
      );
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Z.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)));
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 5), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// An offer card: icon and title, a short description, and its action at
/// the bottom (the card fills the height it's given).
class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.tint,
    required this.iconGradient,
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
  });
  final Color tint;
  final Gradient iconGradient;
  final Widget icon;
  final String title;
  final Widget body;
  final Widget action;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Z.chip, width: 1.5),
          gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [tint, Z.field], stops: const [0, .7]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: iconGradient),
              child: icon,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: outfit(16, w: FontWeight.w800, c: Z.cream, h: 1.15))),
          ]),
          const SizedBox(height: 8),
          Expanded(child: body),
          const SizedBox(height: 8),
          action,
        ]),
      );
}

class _PillAction extends StatelessWidget {
  const _PillAction(this.label, {required this.onTap, this.gold = false});
  final String label;
  final VoidCallback onTap;
  final bool gold;

  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: gold ? Z.goldTab : null,
            border: gold ? null : Border.all(color: Z.border, width: 1.5),
          ),
          child: Text(label, style: outfit(13, w: FontWeight.w800, c: gold ? Z.brown : Z.gold)),
        ),
      );
}

// ── Daily bonus popup (over the lobby) ───────────────────────────────────────

class DailyBonusDialog extends StatefulWidget {
  const DailyBonusDialog({super.key});

  @override
  State<DailyBonusDialog> createState() => _DailyBonusDialogState();
}

class _DailyBonusDialogState extends State<DailyBonusDialog> with TickerProviderStateMixin {
  late final _rays = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();
  late final _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 350))..forward();

  @override
  void dispose() {
    _rays.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final next = s.streakDay < 7 ? s.streakAmounts[s.streakDay] : s.streakAmounts.last;
    return Material(
      color: const Color(0xD1060301),
      child: SafeArea(
        child: Stack(alignment: Alignment.center, children: [
          Positioned.fill(child: RaysBurst(controller: _rays)),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: ScaleTransition(
                  scale: CurvedAnimation(parent: _pop, curve: Curves.easeOutBack),
                  child: GoldFrame(
                    radius: 24,
                    width: 3,
                    shadows: [bs(0, 20, 50, const Color(0xB3000000)), bs(0, 0, 40, const Color(0x4DFFBE46))],
                    inner: ellipseGradient(
                        cx: .25, cy: .5, rx: .6, ry: 1, colors: const [Color(0xFF5A1A10), Color(0xFF150B06)], stops: const [0, .8]),
                    child: Stack(children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                        child: Row(children: [
                          Column(mainAxisSize: MainAxisSize.min, children: [
                            Coin(size: 96, fontSize: 28, big: true, glow: [bs(0, 0, 30, const Color(0xB3FFC850))]),
                            const SizedBox(height: 12),
                            Text('+${fmtInt(s.todayBonus)}',
                                style: outfit(40,
                                    w: FontWeight.w800,
                                    c: Z.goldHi,
                                    h: 1,
                                    sh: [ts(0, 3, 0, const Color(0xFF6A3D00)), ts(0, 0, 20, const Color(0x99FFC850))])),
                          ]),
                          const SizedBox(width: 22),
                          Expanded(
                            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Text('DAILY BONUS', style: outfit(13, w: FontWeight.w800, ls: .2, c: Z.label)),
                              const SizedBox(height: 6),
                              Text('Day ${s.streakDay} streak!', style: outfit(28, w: FontWeight.w800, c: Z.cream)),
                              const SizedBox(height: 12),
                              const StreakRow(),
                              const SizedBox(height: 10),
                              Text('Come back tomorrow for ${fmtInt(next)} GC. Miss a day and the streak resets.',
                                  style: outfit(13, c: Z.body)),
                              const SizedBox(height: 14),
                              s.bonusClaimed
                                  ? GreenButton("ADDED — LET'S PLAY",
                                      height: 54,
                                      fontSize: 17,
                                      icon: const StrokeIco(P.check, size: 20, color: Z.cream, width: 3.2),
                                      onTap: () => Navigator.of(context).pop())
                                  : CtaButton('CLAIM BONUS', height: 54, fontSize: 19, onTap: s.claimBonus),
                            ]),
                          ),
                        ]),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Press(
                          label: 'Close',
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Z.field,
                              border: Border.all(color: Z.chip, width: 1.5),
                            ),
                            child: const StrokeIco(P.close, size: 16),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Slowly turning light rays behind celebrations.
class RaysBurst extends StatelessWidget {
  const RaysBurst({super.key, required this.controller, this.size = 640, this.dy = -.16, this.slice = 9});
  final AnimationController controller;
  final double size;
  final double dy;
  final double slice;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Align(
          alignment: Alignment(0, dy),
          child: OverflowBox(
            maxWidth: size,
            maxHeight: size,
            child: RotationTransition(
              turns: controller,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      for (var i = 0; i < 360 / slice; i++) ...[
                        i.isEven ? const Color(0x1FFFC850) : const Color(0x00000000),
                        i.isEven ? const Color(0x1FFFC850) : const Color(0x00000000),
                      ],
                    ],
                    stops: [
                      for (var i = 0; i < 360 / slice; i++) ...[i * slice / 360, (i + 1) * slice / 360],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

// ── Slots race leaderboard ───────────────────────────────────────────────────

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with _Ticker {
  bool live = true;

  static const colors = [
    Color(0xFFC99BFF), Color(0xFF8CC0FF), Color(0xFFFF8A7A), Color(0xFF7FE39A), Color(0xFFF2C869),
    Color(0xFFFFB36B), Color(0xFF6FE0C0), Color(0xFFE6E6F0), Color(0xFFFF9AD5), Color(0xFF9FD8FF),
  ];
  static const liveNames = ['SpinKing', 'LuckyLina', 'RubyRose', 'GoldRush88', 'NeonAce', 'VelvetQueen', 'MidasTouch', 'HighRoller7', 'CherryBomb', 'StarDust'];
  static const pastNames = ['MidasTouch', 'SpinKing', 'NeonAce', 'LuckyLina', 'StarDust', 'RubyRose', 'CherryBomb', 'GoldRush88', 'VelvetQueen', 'HighRoller7'];
  static const livePts = [412000, 388500, 351200, 298000, 254300, 221900, 190400, 166800, 141200, 120700];
  static const pastPts = [520300, 470100, 402800, 355000, 301200, 280900, 244100, 199500, 172000, 150300];
  static const prizes = ['500K GC', '250K GC', '100K GC'];
  static const medals = [
    [Color(0xFFFFE7A0), Color(0xFFE0A52E), Color(0xFFA8691A)],
    [Color(0xFFF4F4FA), Color(0xFFB8B8C8), Color(0xFF7A7A8A)],
    [Color(0xFFF0B98A), Color(0xFFC0743A), Color(0xFF7A4318)],
  ];

  Widget _av(int i, String name, double size, {Color? border}) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors[i],
          border: border == null ? null : Border.all(color: border, width: 3),
        ),
        child: Text(name.substring(0, 2).toUpperCase(),
            style: outfit((size / 3).roundToDouble(), w: FontWeight.w800, c: Z.ink)),
      );

  @override
  Widget build(BuildContext context) {
    final names = live ? liveNames : pastNames;
    final pts = live ? livePts : pastPts;
    return ZPage(
      gradient: Z.pageGlow(ry: .36, top: const Color(0xFF2E1450)),
      child: Column(children: [
        const TopBar(title: 'SLOTS RACE', backLabel: 'Back to promotions', border: false, titleSize: 19),
        Expanded(
          child: Panes(
            sideFraction: .45,
            maxSide: 460,
            minMain: 260,
            // Tabs, countdown and the podium on the left…
            side: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 6, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SegTabs(
                  labels: const ['THIS WEEKEND', 'LAST RACE'],
                  index: live ? 0 : 1,
                  height: 34,
                  fontSize: 12,
                  onChanged: (i) => setState(() => live = i == 0),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Text(live ? 'Ends in' : 'Final results', style: outfit(13, c: Z.body)),
                  const Spacer(),
                  Text(live ? _countdown(raceSecondsLeft()) : 'Oct 11 – 12',
                      style: outfit(13, w: FontWeight.w800, c: Z.goldHi, features: tabular)),
                ]),
                const SizedBox(height: 6),
                Expanded(
                  child: LayoutBuilder(builder: (context, box) {
                    // Podium blocks share whatever height is left under the names.
                    final first = (box.maxHeight - 72).clamp(30.0, 120.0);
                    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      for (final i in const [1, 0, 2]) ...[
                        if (i != 1) const SizedBox(width: 8),
                        Expanded(
                          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                            _av(i, names[i], i == 0 ? 48 : 40, border: i == 0 ? Z.goldBright : Z.chip),
                            const SizedBox(height: 3),
                            Text(names[i],
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: outfit(13, w: FontWeight.w700, c: Z.cream)),
                            const SizedBox(height: 3),
                            Container(
                              height: first * const [1.0, .82, .7][i],
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(14), bottom: Radius.circular(6)),
                                gradient: LinearGradient(
                                    begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: medals[i], stops: const [0, .6, 1]),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  Text('${i + 1}', style: outfit(22, w: FontWeight.w800, c: const Color(0xFF2A1605), h: 1.1)),
                                  Text(fmtInt(pts[i]), style: outfit(12, w: FontWeight.w700, c: const Color(0xFF2A1605))),
                                  Text(prizes[i], style: outfit(11, w: FontWeight.w600, c: const Color(0xD92A1605))),
                                ]),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ]);
                  }),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Points = GC wagered on slots. '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: Press(
                        onTap: () => Nav.push(R.legal, 'rules'),
                        child: Text('Full rules', style: outfit(11, c: Z.gold, deco: TextDecoration.underline)),
                      ),
                    ),
                  ]),
                  style: outfit(11, c: Z.muted2),
                ),
              ]),
            ),
            // …places 4–10 on the right, in two columns when they fit.
            main: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 14, 8),
              child: LayoutBuilder(builder: (context, box) {
                const gap = 6.0;
                final entries = [for (var k = 3; k < names.length; k++) k];
                final cols = box.maxWidth >= 440 ? 2 : 1;
                final rows = (entries.length / cols).ceil();
                final rowH = ((box.maxHeight - gap * (rows - 1)) / rows).clamp(24.0, 46.0);
                final avatar = rowH >= 36;
                return GridView.count(
                  crossAxisCount: cols,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: 8,
                  childAspectRatio: ((box.maxWidth - 8 * (cols - 1)) / cols) / rowH,
                  children: [
                    for (final k in entries)
                      ZCard(
                        radius: 12,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(children: [
                          SizedBox(width: 22, child: Text('${k + 1}', style: outfit(14, w: FontWeight.w800, c: Z.muted))),
                          if (avatar) ...[_av(k, names[k], rowH - 14), const SizedBox(width: 8)],
                          Expanded(
                            child: Text(names[k],
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: outfit(14, w: FontWeight.w600, c: Z.cream)),
                          ),
                          Text(fmtInt(pts[k]), style: outfit(13, w: FontWeight.w700, c: Z.goldHi)),
                        ]),
                      ),
                  ],
                );
              }),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Z.border, width: 1.5)),
            gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A1A08), Color(0xFF0A0704)]),
          ),
          child: Row(children: [
            SizedBox(width: 40, child: Text('#27', style: outfit(18, w: FontWeight.w800, c: Z.goldHi))),
            const SizedBox(width: 12),
            const Avatar(size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('You', style: outfit(15, w: FontWeight.w700, c: Z.cream)),
                Text('48,200 pts · 6,400 to top 20', style: outfit(12, c: Z.muted)),
              ]),
            ),
            Press(
              onTap: () => Nav.push(R.gold),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Z.rimBright, width: 1.5),
                  gradient: Z.red3,
                ),
                child: Text('PLAY', style: outfit(14, w: FontWeight.w800, c: Z.ctaText)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
