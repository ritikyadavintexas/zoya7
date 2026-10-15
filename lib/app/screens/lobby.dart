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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 84),
        children: [
          // Header
          Row(children: [
            Press(
              label: 'Your profile',
              onTap: () => Nav.tab(AppTab.profile),
              child: const Avatar(size: 50),
            ),
            const SizedBox(width: 7),
            Expanded(
              flex: 3,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: outfit(14, w: FontWeight.w700, c: Z.cream)),
                const SizedBox(height: 2),
                Row(children: [
                  const Ico(P.crown, size: 12, color: Z.goldEdge),
                  const SizedBox(width: 3),
                  Text(s.guest ? 'GUEST' : 'VIP BRONZE', style: outfit(10, w: FontWeight.w600, ls: .04, c: Z.goldEdge)),
                ]),
              ]),
            ),
            Image.asset(A.logo, width: 108, height: 44, fit: BoxFit.contain, semanticLabel: 'Zoya7'),
            const Spacer(),
            Press(
              label: 'Notifications, ${s.unreadNotifications} new',
              onTap: () => Nav.push(R.notifications),
              child: Stack(children: [
                Container(
                  width: 44,
                  height: 44,
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
          const SizedBox(height: 12),

          // Balances
          Row(children: [
            Expanded(
              child: _BalanceBar(
                coin: const Coin(size: 30, fontSize: 11),
                value: fmtInt(s.gc),
                plus: Press(
                  label: 'Buy Gold Coins',
                  onTap: () => Nav.tab(AppTab.wallet, walletTab: 'buy'),
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: Z.coinGold()),
                    child: const StrokeIco(P.plus, size: 14, color: Z.coinInk, width: 3.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _BalanceBar(
                coin: const Coin(label: 'SC', size: 30, fontSize: 11, teal: true),
                value: fmtSc(s.sc),
                center: true,
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Jackpots
          GoldFrame(
            radius: 14,
            shadows: [bs(0, 6, 18, const Color(0x80000000))],
            child: Row(children: [
              _Jackpot('MEGA', const Color(0xFFFF8A7A), Z.gold, const Color(0x73C81E28), 1234567 + tick * 7),
              _Jackpot('MAJOR', const Color(0xFFD6A8FF), const Color(0xFFD6A8FF), const Color(0x738C28C8), 234567 + tick * 3),
              _Jackpot('MINOR', const Color(0xFF8CC0FF), const Color(0xFF8CC0FF), const Color(0x731E5AD2), 56789 + tick ~/ 2),
              _Jackpot('MINI', const Color(0xFF7FE39A), const Color(0xFF7FE39A), const Color(0x731EA046), 12345 + tick ~/ 5, last: true),
            ]),
          ),
          const SizedBox(height: 12),

          // Quick actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(children: [
              _Quick('BONUS', const Ico(P.gift), () => Nav.tab(AppTab.promotions)),
              _Quick('CHAT', const Ico(P.chatDots), () => Nav.push(R.chat)),
              _Quick('WALLET', const Ico(P.wallet), () => Nav.tab(AppTab.wallet)),
              _Quick('SETTINGS', const RawIco(_gearSvg), () => Nav.push(R.settings)),
            ]),
          ),
          const SizedBox(height: 12),

          // VIP banner
          Press(
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
          const SizedBox(height: 12),

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
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 179 / 96,
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
  const _BalanceBar({required this.coin, required this.value, this.plus, this.center = false});
  final Widget coin;
  final String value;
  final Widget? plus;
  final bool center;

  @override
  Widget build(BuildContext context) => Container(
        height: 42,
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
              alignment: center ? Alignment.center : Alignment.centerLeft,
              child: Text(value, style: outfit(17, w: FontWeight.w700, c: Z.cream)),
            ),
          ),
          if (plus != null) ...[const SizedBox(width: 8), plus!],
        ]),
      );
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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(fmtInt(value), style: outfit(15, w: FontWeight.w800, c: Z.cream, features: tabular)),
            ),
            Text('GC', style: outfit(9, w: FontWeight.w600, c: const Color(0xFFCDBB94))),
          ]),
        ),
      );
}

class _Quick extends StatelessWidget {
  const _Quick(this.label, this.icon, this.onTap);
  final String label;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Press(
          label: label,
          onTap: onTap,
          child: Column(children: [
            Container(
              width: 52,
              height: 52,
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
        ),
      );
}
