import 'dart:async';

import 'package:flutter/material.dart';

import '../assets.dart';
import '../icons.dart';
import '../nav.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Open a game tile: Classic 777 / Fruit Spin play Gold, others show "coming soon".
void openGame(GameInfo g) => g.playable ? Nav.push(R.gold) : Nav.push(R.comingSoon, g.id);

class LobbyPage extends StatefulWidget {
  const LobbyPage({super.key});

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  int tick = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) => setState(() => tick++));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ZPage(
      child: Column(children: [
        // Header: player · logo · notifications
        SizedBox(
          height: 58,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Stack(alignment: Alignment.center, children: [
              Image.asset(A.logo, width: 108, height: 44, fit: BoxFit.contain, semanticLabel: 'Zoya7'),
              Row(children: [
                Press(
                  label: 'Your profile',
                  onTap: () => Nav.tab(AppTab.profile),
                  child: const Avatar(size: 42),
                ),
                const SizedBox(width: 8),
                Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: outfit(14, w: FontWeight.w700, c: Z.cream)),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Ico(P.crown, size: 12, color: Z.goldEdge),
                    const SizedBox(width: 3),
                    Text(s.guest ? 'GUEST' : 'VIP BRONZE', style: outfit(10, w: FontWeight.w600, ls: .04, c: Z.goldEdge)),
                  ]),
                ]),
                const Spacer(),
                Press(
                  label: 'Notifications, ${s.unreadNotifications} new',
                  onTap: () => Nav.push(R.notifications),
                  child: Stack(children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Z.goldEdge, width: 1.5),
                        gradient: Z.darkKnob(),
                      ),
                      child: const Ico(P.bell, size: 20),
                    ),
                    if (s.unreadNotifications > 0)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Z.red,
                            border: Border.all(color: Z.ink, width: 1.5),
                          ),
                        ),
                      ),
                  ]),
                ),
              ]),
            ]),
          ),
        ),
        Expanded(
          child: PaneLists(
            top: 2,
            side: [
              // Balances: side by side when there's room, stacked otherwise.
              LayoutBuilder(builder: (context, box) {
                final gc = _BalanceBar(
                  coin: const Coin(size: 28, fontSize: 10),
                  value: fmtInt(s.gc),
                  plus: Press(
                    label: 'Buy Gold Coins',
                    onTap: () => Nav.tab(AppTab.wallet, walletTab: 'buy'),
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: Z.coinGold()),
                      child: const StrokeIco(P.plus, size: 13, color: Z.coinInk, width: 3.5),
                    ),
                  ),
                );
                final sc = _BalanceBar(coin: const Coin(label: 'SC', size: 28, fontSize: 10, teal: true), value: fmtSc(s.sc));
                return box.maxWidth >= 400
                    ? Row(children: [Expanded(child: gc), const SizedBox(width: 8), Expanded(child: sc)])
                    : Column(children: [gc, const SizedBox(height: 8), sc]);
              }),
              const SizedBox(height: 10),
              _Jackpots(tick: tick),
              const SizedBox(height: 12),
              const _QuickActions(),
              const SizedBox(height: 12),
              // VIP banner
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Press(
                    label: 'Exclusive VIP Rewards — higher status, bigger rewards. Learn more',
                    onTap: () => Nav.push(R.vip),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Z.border, width: 1.5),
                        color: Z.field,
                        boxShadow: [bs(0, 6, 18, const Color(0x80000000))],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: AspectRatio(aspectRatio: 366 / 114, child: Image.asset(A.vipBanner, fit: BoxFit.cover)),
                    ),
                  ),
                ),
              ),
            ],
            main: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: SectionTitle(
                  'POPULAR GAMES',
                  size: 16,
                  trailing: Press(
                    onTap: () => Nav.tab(AppTab.games),
                    child: Text('See all ›', style: outfit(13, w: FontWeight.w700, c: Z.gold)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // As many columns as fit tiles up to 230 wide.
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 230,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 179 / 96,
                ),
                children: [
                  for (final g in games)
                    Press(
                      label: '${g.name} — ${g.playable ? 'play' : 'coming soon'}',
                      onTap: () => openGame(g),
                      child: RoundImage(g.image),
                    ),
                ],
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

const _gearSvg =
    '<g fill="none" stroke="#f2c869" stroke-width="2.4" stroke-linecap="round"><circle cx="12" cy="12" r="3.2"/><path d="${P.gearSpokes}"/></g>';

/// The player avatar inside a glowing frame. Frame color follows Edit profile.
class Avatar extends StatelessWidget {
  const Avatar({super.key, this.size = 50, this.border = 2});
  final double size;
  final double border;

  static const frames = [
    ('Gold frame', Color(0xFFE2B04F)),
    ('Ruby frame', Color(0xFFE3242B)),
    ('Emerald frame', Color(0xFF3FD17A)),
    ('Sapphire frame', Color(0xFF5A9BFF)),
    ('Amethyst frame', Color(0xFFB06BFF)),
  ];

  @override
  Widget build(BuildContext context) {
    final c = frames[AppScope.of(context).avatarFrame].$2;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c, width: border),
        boxShadow: [bs(0, 0, size * .2, c.withValues(alpha: .45))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(A.avatar, fit: BoxFit.cover),
    );
  }
}

class _BalanceBar extends StatelessWidget {
  const _BalanceBar({required this.coin, required this.value, this.plus});
  final Widget coin;
  final String value;
  final Widget? plus;

  @override
  Widget build(BuildContext context) => Container(
        height: 40,
        padding: EdgeInsets.fromLTRB(5, 0, plus == null ? 10 : 5, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Z.border, width: 1.5),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF17110A), Color(0xFF0A0704)],
          ),
        ),
        child: Row(children: [
          coin,
          const SizedBox(width: 8),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: outfit(17, w: FontWeight.w700, c: Z.cream)),
            ),
          ),
          if (plus != null) ...[const SizedBox(width: 8), plus!],
        ]),
      );
}

class _Jackpots extends StatelessWidget {
  const _Jackpots({required this.tick});
  final int tick;

  @override
  Widget build(BuildContext context) {
    final meters = [
      ('MEGA', const Color(0xFFFF8A7A), Z.gold, const Color(0x73C81E28), 1234567 + tick * 7),
      ('MAJOR', const Color(0xFFD6A8FF), const Color(0xFFD6A8FF), const Color(0x738C28C8), 234567 + tick * 3),
      ('MINOR', const Color(0xFF8CC0FF), const Color(0xFF8CC0FF), const Color(0x731E5AD2), 56789 + tick ~/ 2),
      ('MINI', const Color(0xFF7FE39A), const Color(0xFF7FE39A), const Color(0x731EA046), 12345 + tick ~/ 5),
    ];
    Widget row(List<(String, Color, Color, Color, int)> ms) => Row(children: [
          for (final (i, (n, c, cr, g, v)) in ms.indexed) _Jackpot(n, c, cr, g, v, last: i == ms.length - 1),
        ]);
    return GoldFrame(
      radius: 14,
      shadows: [bs(0, 6, 18, const Color(0x80000000))],
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth / 4 >= 84
            ? row(meters)
            : Column(children: [
                Container(
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Z.line35))),
                  child: row(meters.sublist(0, 2)),
                ),
                row(meters.sublist(2)),
              ]),
      ),
    );
  }
}

class _Jackpot extends StatelessWidget {
  const _Jackpot(this.name, this.color, this.crown, this.glow, this.value, {this.last = false});
  final String name;
  final Color color;
  final Color crown;
  final Color glow;
  final int value;
  final bool last;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [glow, const Color(0x000D0906)],
            ),
            border: last ? null : const Border(right: BorderSide(color: Z.line35)),
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Ico(P.crown, size: 12, color: crown),
              const SizedBox(width: 3),
              Text(name, style: outfit(11, w: FontWeight.w800, ls: .04, c: color)),
            ]),
            const SizedBox(height: 1),
            Text(fmtInt(value), style: outfit(15, w: FontWeight.w800, c: Z.cream, features: tabular)),
            Text('GC', style: outfit(9, w: FontWeight.w600, c: const Color(0xFFCDBB94))),
          ]),
        ),
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final items = [
      _Quick('BONUS', const Ico(P.gift), () => Nav.tab(AppTab.promotions)),
      _Quick('CHAT', const Ico(P.chatDots), () => Nav.push(R.chat)),
      _Quick('WALLET', const Ico(P.wallet), () => Nav.tab(AppTab.wallet)),
      _Quick('SETTINGS', const RawIco(_gearSvg), () => Nav.push(R.settings)),
    ];
    return LayoutBuilder(builder: (context, box) {
      final perRow = (box.maxWidth / 66).floor().clamp(2, items.length);
      final w = box.maxWidth / perRow;
      return Wrap(runSpacing: 10, children: [for (final q in items) SizedBox(width: w, child: q)]);
    });
  }
}

class _Quick extends StatelessWidget {
  const _Quick(this.label, this.icon, this.onTap);
  final String label;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Press(
        label: label,
        onTap: onTap,
        child: Column(children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Z.border, width: 2),
              gradient: Z.darkWell(),
              boxShadow: [bs(0, 0, 10, const Color(0x4DC99A3E))],
            ),
            child: icon,
          ),
          const SizedBox(height: 5),
          Text(label, style: outfit(11, w: FontWeight.w600, ls: .04)),
        ]),
      );
}
