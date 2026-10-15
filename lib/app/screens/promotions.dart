import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../assets.dart';
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
    return ZPage(
      child: Column(children: [
        TopBar(title: 'PROMOTIONS', backLabel: 'Back to lobby', onBack: () => Nav.tab(AppTab.home)),
        Expanded(
          child: Panes(
            sideFraction: .5,
            maxSide: 520,
            side: PaneList(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 16),
              children: [
              GoldFrame(
                shadows: [bs(0, 8, 22, const Color(0x80000000))],
                inner: ellipseGradient(
                    cx: .5, cy: 0, rx: .9, ry: .7, colors: const [Color(0xFF5A1A10), Color(0xFF150B06)], stops: const [0, .7]),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('DAILY BONUS', style: outfit(12, w: FontWeight.w700, ls: .14, c: Z.label)),
                        const SizedBox(height: 2),
                        Text('Day ${s.streakDay} streak', style: outfit(22, w: FontWeight.w800, c: Z.cream)),
                      ]),
                    ),
                    Text('Resets in 07:12:44', style: outfit(13, c: Z.body)),
                  ]),
                  const SizedBox(height: 14),
                  const StreakRow(tall: true),
                  const SizedBox(height: 14),
                  s.bonusClaimed
                      ? Container(
                          height: 54,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Z.chipDark, width: 1.5),
                            color: Z.field,
                          ),
                          child: Text('CLAIMED — COME BACK TOMORROW',
                              style: outfit(17, w: FontWeight.w800, ls: .04, c: Z.muted)),
                        )
                      : CtaButton('CLAIM ${fmtInt(s.todayBonus)} GC', height: 54, fontSize: 17, onTap: () {
                          s.claimBonus();
                          showToast(context, '+${fmtInt(s.todayBonus)} GC added to your balance');
                        }),
                ]),
              ),
              const SizedBox(height: 14),
              Press(
                label: 'Exclusive VIP Rewards — higher status, bigger rewards. Learn more',
                onTap: () => Nav.push(R.vip),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Z.border, width: 1.5),
                    boxShadow: [bs(0, 6, 18, const Color(0x80000000))],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AspectRatio(aspectRatio: 366 / 114, child: Image.asset(A.vipBanner, fit: BoxFit.cover)),
                ),
              ),
              ],
            ),
            main: PaneList(
              padding: const EdgeInsets.fromLTRB(8, 12, 14, 16),
              children: [
              const SectionTitle('MORE OFFERS'),
              const SizedBox(height: 12),
              _Offer(
                tint: const Color(0xFF2A1A08),
                icon: Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: Z.coinGold()),
                  child: const Ico(P.gift, size: 30, color: Z.coinInk),
                ),
                title: 'Welcome Pack',
                body: Text('Bonus Gold Coins plus free Sweeps Coins on your first package.',
                    style: outfit(13, c: Z.body, h: 1.35)),
                action: _PillAction('GET', gold: true, onTap: () => Nav.tab(AppTab.wallet, walletTab: 'buy')),
              ),
              const SizedBox(height: 10),
              _Offer(
                tint: const Color(0xFF0E2A1A),
                icon: Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: Z.coinTeal()),
                  child: const Ico(P.addFriend, size: 30, color: Z.tealInk),
                ),
                title: 'Refer a Friend',
                body: Text('You both get a bonus when they sign up and play.', style: outfit(13, c: Z.body, h: 1.35)),
                footer: Row(children: [
                  Expanded(
                    child: DottedBox(
                      child: Text(s.name.toUpperCase(), style: outfit(16, w: FontWeight.w800, ls: .14, c: Z.goldHi)),
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
                      width: 96,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: Z.green3),
                      child: Text(copied ? 'COPIED' : 'COPY', style: outfit(14, w: FontWeight.w800, c: Z.cream)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              _Offer(
                tint: const Color(0xFF261040),
                icon: Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: circleGradient(
                        cx: .4, cy: .3, colors: const [Color(0xFFE3C2FF), Color(0xFF9B4FE0), Color(0xFF4E1A85)], stops: const [0, .6, 1]),
                  ),
                  child: const Ico(P.trophyFull, size: 30, color: Color(0xFF24083F)),
                ),
                title: 'Weekend Slots Race',
                body: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Ends in '),
                    TextSpan(
                        text: _countdown(raceSecondsLeft()),
                        style: outfit(13, w: FontWeight.w800, c: Z.goldHi, features: tabular)),
                  ]),
                  style: outfit(13, c: Z.body),
                ),
                action: _PillAction('JOIN', onTap: () => Nav.push(R.leaderboard)),
              ),
              ],
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
    return Row(children: [
      for (var n = 1; n <= 7; n++) ...[
        if (n > 1) SizedBox(width: tall ? 5 : 4),
        Expanded(child: _day(s, n)),
      ],
    ]);
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
      height: 62,
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
        const SizedBox(height: 4),
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

class _Offer extends StatelessWidget {
  const _Offer({required this.tint, required this.icon, required this.title, required this.body, this.action, this.footer});
  final Color tint;
  final Widget icon;
  final String title;
  final Widget body;
  final Widget? action;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Z.chip, width: 1.5),
          gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [tint, Z.field], stops: const [0, .6]),
        ),
        child: Column(children: [
          Row(children: [
            icon,
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: outfit(16, w: FontWeight.w800, c: Z.cream)),
                const SizedBox(height: 3),
                body,
              ]),
            ),
            if (action != null) ...[const SizedBox(width: 14), action!],
          ]),
          if (footer != null) ...[const SizedBox(height: 12), footer!],
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
            side: PaneList(
              padding: const EdgeInsets.fromLTRB(14, 0, 6, 12),
              children: [
                SegTabs(
                  labels: const ['THIS WEEKEND', 'LAST RACE'],
                  index: live ? 0 : 1,
                  onChanged: (i) => setState(() => live = i == 0),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Text(live ? 'Ends in' : 'Final results', style: outfit(13, c: Z.body)),
                  const Spacer(),
                  Text(live ? _countdown(raceSecondsLeft()) : 'Oct 11 – 12',
                      style: outfit(13, w: FontWeight.w800, c: Z.goldHi, features: tabular)),
                ]),
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (final i in const [1, 0, 2]) ...[
                    if (i != 1) const SizedBox(width: 8),
                    Expanded(
                      child: Column(children: [
                        _av(i, names[i], i == 0 ? 52 : 44, border: i == 0 ? Z.goldBright : Z.chip),
                        const SizedBox(height: 4),
                        Text(names[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: outfit(13, w: FontWeight.w700, c: Z.cream)),
                        const SizedBox(height: 4),
                        Container(
                          height: const [100.0, 82.0, 70.0][i],
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(14), bottom: Radius.circular(6)),
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: medals[i],
                                stops: const [0, .6, 1]),
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('${i + 1}', style: outfit(24, w: FontWeight.w800, c: const Color(0xFF2A1605), h: 1.1)),
                            Text(fmtInt(pts[i]), style: outfit(12, w: FontWeight.w700, c: const Color(0xFF2A1605))),
                            Text(prizes[i], style: outfit(11, w: FontWeight.w600, c: const Color(0xD92A1605))),
                          ]),
                        ),
                      ]),
                    ),
                  ],
                ]),
              ],
            ),
            main: PaneList(
              padding: const EdgeInsets.fromLTRB(8, 0, 14, 12),
              children: [
                ZCard(
                  child: Column(children: [
                    for (var k = 3; k < names.length; k++)
                      Container(
                        constraints: const BoxConstraints(minHeight: 46),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Z.divider))),
                        child: Row(children: [
                          SizedBox(width: 26, child: Text('${k + 1}', style: outfit(15, w: FontWeight.w800, c: Z.muted))),
                          const SizedBox(width: 12),
                          _av(k, names[k], 30),
                          const SizedBox(width: 12),
                          Expanded(child: Text(names[k], style: outfit(15, w: FontWeight.w600, c: Z.cream))),
                          Text(fmtInt(pts[k]), style: outfit(14, w: FontWeight.w700, c: Z.goldHi)),
                        ]),
                      ),
                  ]),
                ),
                const SizedBox(height: 12),
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Points = GC wagered on slots during the race. Prizes are paid in Gold Coins. Full rules in '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: Press(
                        onTap: () => Nav.push(R.legal, 'rules'),
                        child: Text('Sweeps rules',
                            style: outfit(12, c: Z.gold, h: 1.5, deco: TextDecoration.underline)),
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ]),
                  style: outfit(12, c: Z.muted2, h: 1.5),
                ),
              ],
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
            const Avatar(size: 38),
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
