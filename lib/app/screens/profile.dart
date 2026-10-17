import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../icons.dart';
import '../nav.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'lobby.dart' show Avatar, openDailyBonus;

/// A row inside a dark list card: label, optional value, chevron.
class ListRow extends StatelessWidget {
  const ListRow({super.key, required this.label, required this.onTap, this.leading, this.value, this.badge, this.color = Z.text, this.last = false, this.valueColor = const Color(0xFFC9A35A)});
  final String label;
  final VoidCallback onTap;
  final Widget? leading;
  final String? value;
  final String? badge;
  final Color color;
  final Color valueColor;
  final bool last;

  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        label: label,
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Z.divider))),
          child: Row(children: [
            if (leading != null) ...[leading!, const SizedBox(width: 14)],
            Expanded(child: Text(label, style: outfit(15, w: FontWeight.w600, c: color))),
            if (value != null && value!.isNotEmpty) ...[
              Text(value!, style: outfit(14, c: valueColor)),
              const SizedBox(width: 12),
            ],
            if (badge != null) ...[
              Container(
                constraints: const BoxConstraints(minWidth: 22),
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Z.red, borderRadius: BorderRadius.circular(11)),
                child: Text(badge!, style: outfit(12, w: FontWeight.w800, c: const Color(0xFFFFFFFF))),
              ),
              const SizedBox(width: 12),
            ],
            const StrokeIco(P.forward, size: 16, color: Z.faint, width: 2.6),
          ]),
        ),
      );
}

// ── Profile ──────────────────────────────────────────────────────────────────

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // What the HUD and the options menu don't already give you.
    final items = [
      ('Edit profile', P.pencil, () => Nav.push(R.editProfile), 0),
      ('Wallet & history', P.wallet, () => Nav.tab(AppTab.wallet, walletTab: 'history'), 0),
      if (s.shows('vip')) ('VIP Club', P.crown, () => Nav.push(R.vip), 0),
      ('Notifications', P.bell, () => Nav.push(R.notifications), s.unreadNotifications),
      ('Responsible gaming', P.shield, () => Nav.push(R.settings, 'responsible'), 0),
      ('Settings', P.gear, () => Nav.push(R.settings), 0),
      ('Log out', P.back, () => logOut(context), 0),
    ];
    return ZPage(
      gradient: Z.pageGlow(ry: .36, top: const Color(0xFF4A2A0A)),
      child: Column(children: [
        TopBar(title: 'PROFILE', backLabel: 'Back to lobby', onBack: () => Nav.tab(AppTab.home), border: false),
        Expanded(
          child: Panes(
            sideFraction: .4,
            minMain: 280,
            side: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 6, 12),
              child: LayoutBuilder(builder: (context, box) {
                final avatar = (box.maxHeight * .26).clamp(54.0, 84.0);
                return Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    SizedBox(
                      width: avatar + 4,
                      height: avatar + 4,
                      child: Stack(children: [
                        Avatar(size: avatar, border: 3),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Press(
                            label: 'Edit profile',
                            onTap: () => Nav.push(R.editProfile),
                            child: Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: Z.goldBadge,
                                border: Border.all(color: Z.ink, width: 2),
                              ),
                              child: const Ico(P.pencil, size: 13, color: Z.brown),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: outfit(21, w: FontWeight.w800, c: Z.cream)),
                        const SizedBox(height: 2),
                        Text('ID 7700 1234 · Member since 2026', style: outfit(12, c: Z.muted)),
                      ]),
                    ),
                  ]),
                  Press(
                    onTap: () => Nav.push(R.vip),
                    label: 'VIP Bronze — VIP Club',
                    child: GoldFrame(
                      radius: 16,
                      inner: ellipseGradient(
                          cx: 0, cy: 0, rx: 1, ry: .8, colors: const [Color(0xFF4A2A0A), Z.field], stops: const [0, .7]),
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Ico(P.crown, size: 20, color: Color(0xFFD9915A)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text('VIP BRONZE', style: outfit(15, w: FontWeight.w800, c: const Color(0xFFE8B878)))),
                          Text('VIP Club ›', style: outfit(13, w: FontWeight.w600, c: Z.gold)),
                        ]),
                        const SizedBox(height: 8),
                        const GoldBar(value: .62, height: 10),
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(children: [
                            const TextSpan(text: '6,200 / 10,000 points to '),
                            TextSpan(text: 'Silver', style: outfit(13, w: FontWeight.w700, c: const Color(0xFFE6E6F0))),
                          ]),
                          style: outfit(13, c: Z.body),
                        ),
                      ]),
                    ),
                  ),
                  Row(children: [
                    for (final (i, (v, l)) in const [('248', 'SPINS'), ('75K', 'BIGGEST WIN'), ('4', 'DAY STREAK')].indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: ZCard(
                          radius: 14,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          child: Column(children: [
                            Text(v, style: outfit(19, w: FontWeight.w800, c: Z.goldHi, h: 1.1)),
                            FittedBox(child: Text(l, style: outfit(10, w: FontWeight.w600, ls: .06, c: Z.muted))),
                          ]),
                        ),
                      ),
                    ],
                  ]),
                ]);
              }),
            ),
            // The menu as tiles: as many columns as fit 210px, rows sharing the height.
            main: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 14, 12),
              child: LayoutBuilder(builder: (context, box) {
                const gap = 8.0;
                final cols = columnsFor(box.maxWidth, 240, gap: gap, min: 2);
                final rows = (items.length / cols).ceil();
                final tileH = ((box.maxHeight - gap * (rows - 1)) / rows).clamp(44.0, 64.0);
                final tileW = (box.maxWidth - gap * (cols - 1)) / cols;
                return GridView.count(
                  crossAxisCount: cols,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: gap,
                  childAspectRatio: tileW / tileH,
                  children: [
                    for (final (label, path, onTap, badge) in items)
                      _ProfileTile(
                          label: label,
                          icon: path,
                          onTap: onTap,
                          badge: badge,
                          danger: label == 'Log out',
                          // Narrow tiles: icon above the label so it isn't cut short.
                          stacked: tileW < 190),
                  ],
                );
              }),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.badge = 0,
    this.danger = false,
    this.stacked = false,
  });
  final String label;
  final String icon;
  final VoidCallback onTap;
  final int badge;
  final bool danger;
  final bool stacked;

  @override
  Widget build(BuildContext context) => Press(
        label: badge > 0 ? '$label, $badge new' : label,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: stacked ? 6 : 12),
          decoration: BoxDecoration(
            color: Z.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: danger ? const Color(0xFF8A2A2A) : Z.cardBorder, width: 1.5),
          ),
          child: stacked
              ? Stack(alignment: Alignment.center, children: [
                  Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Ico(icon, size: 18, color: danger ? Z.coral : Z.gold),
                    const SizedBox(height: 3),
                    Text(label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: outfit(12, w: FontWeight.w700, c: danger ? Z.coral : Z.cream, h: 1.15)),
                  ]),
                  if (badge > 0)
                    Positioned(
                      top: 4,
                      right: 2,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Z.red, borderRadius: BorderRadius.circular(9)),
                        child: Text('$badge', style: outfit(10, w: FontWeight.w800, c: const Color(0xFFFFFFFF))),
                      ),
                    ),
                ])
              : Row(children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Z.iconTile, borderRadius: BorderRadius.circular(10)),
              child: Ico(icon, size: 17, color: danger ? Z.coral : Z.gold),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: outfit(14, w: FontWeight.w700, c: danger ? Z.coral : Z.cream)),
            ),
            if (badge > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Z.red, borderRadius: BorderRadius.circular(10)),
                child: Text('$badge', style: outfit(11, w: FontWeight.w800, c: const Color(0xFFFFFFFF))),
              ),
          ]),
        ),
      );
}

// ── Edit profile ─────────────────────────────────────────────────────────────

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cur = Avatar.frames[s.avatarFrame].$2;
    return ZPage(
      child: Column(children: [
        TopBar(
          title: 'EDIT PROFILE',
          backLabel: 'Back to profile',
          right: Press(
            label: 'Save changes',
            onTap: () => showToast(context, 'Profile saved', border: Z.green, color: Z.greenHi),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Z.rimBright, width: 1.5),
                gradient: Z.red3,
              ),
              child: Center(
                widthFactor: 1,
                child: Text('SAVE', style: outfit(14, w: FontWeight.w800, ls: .06, c: Z.ctaText)),
              ),
            ),
          ),
        ),
        Expanded(
          child: PaneLists(
            sideFraction: .34,
            minSide: 240,
            maxSide: 320,
            side: [Center(child: Column(children: [
                  // Tap the picture to choose another avatar.
                  Press(
                    label: 'Change avatar',
                    onTap: () => showAvatarPicker(context),
                    child: Stack(clipBehavior: Clip.none, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: cur, width: 4),
                          boxShadow: [bs(0, 0, 26, cur)],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: const Avatar(size: 104, border: 0),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(shape: BoxShape.circle, gradient: Z.red3, border: Border.all(color: Z.rimBright, width: 1.5)),
                          child: const Center(child: StrokeIco(P.pencil, size: 14, color: Z.cream, width: 2.4)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Text('AVATAR FRAME', style: outfit(13, w: FontWeight.w700, ls: .12, c: Z.label)),
                  const SizedBox(height: 12),
                  Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 12, children: [
                    for (final (i, (label, c)) in Avatar.frames.indexed)
                      Press(
                        label: label,
                        selected: i == s.avatarFrame,
                        onTap: () => s.setAvatarFrame(i),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: Z.darkWell(),
                            border: Border.all(color: c, width: 4),
                            boxShadow: i == s.avatarFrame
                                ? const [BoxShadow(color: Z.ink, spreadRadius: 3), BoxShadow(color: Z.cream, spreadRadius: 5)]
                                : null,
                          ),
                        ),
                      ),
                  ]),
                ]))],
            main: [
                LayoutBuilder(builder: (context, box) {
                  final email = ZField(
                      label: 'EMAIL',
                      initial: '${s.name.toLowerCase()}@example.com',
                      keyboard: TextInputType.emailAddress,
                      badge: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0x243FD17A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x803FD17A)),
                        ),
                        child: Text('VERIFIED', style: outfit(11, w: FontWeight.w700, c: Z.greenHi)),
                      ),
                    );
                  const phone = ZField(label: 'PHONE', hint: 'Add a phone number', keyboard: TextInputType.phone);
                  Widget pair(Widget a, Widget b) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: a),
                        const SizedBox(width: 10),
                        Expanded(child: b),
                      ]);
                  // Wide: username, then email beside phone. Narrow: username
                  // beside phone, then email (it needs the width for its badge).
                  return box.maxWidth >= 400
                      ? Column(children: [
                          ZField(label: 'USERNAME', initial: s.name, helper: 'Shown on leaderboards.'),
                          const SizedBox(height: 10),
                          pair(email, phone),
                        ])
                      : Column(children: [
                          pair(ZField(label: 'USERNAME', initial: s.name), phone),
                          const SizedBox(height: 10),
                          email,
                        ]);
                }),
                const SizedBox(height: 12),
                // Account actions in one row (scrolling sideways on narrow screens).
                SizedBox(
                  height: 40,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    _AccountAction('Change password', onTap: () => Nav.push(R.forgot)),
                  ]),
                ),
              ],
          ),
        ),
      ]),
    );
  }
}

/// The avatar gallery, in a popup: tap one, or let Random choose.
void showAvatarPicker(BuildContext context) => showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close avatars',
      barrierColor: const Color(0xB3000000),
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      pageBuilder: (_, __, ___) => const _AvatarPicker(),
    );

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final size = MediaQuery.sizeOf(context);
    final tile = size.height < 360 ? 46.0 : 56.0;
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: math.min(size.width - 40, 600),
          padding: const EdgeInsets.fromLTRB(18, 12, 12, 18),
          decoration: BoxDecoration(
            color: Z.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Z.cardBorder, width: 1.5),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text('CHOOSE AVATAR', style: outfit(18, w: FontWeight.w800, ls: .12, c: Z.goldHi)),
              const Spacer(),
              LinkText('Random', size: 14, w: FontWeight.w700, onTap: () {
                final others = [for (final a in avatarNames) if (s.avatar != 'assets/app/avatars/$a.webp') a];
                s.setAvatar(others[math.Random().nextInt(others.length)]);
              }),
              const SizedBox(width: 14),
              RoundBtn(
                label: 'Close',
                onTap: () => Navigator.of(context).pop(),
                child: const StrokeIco(P.close, size: 16),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
              for (final a in avatarNames)
                Press(
                  label: 'Avatar $a',
                  selected: s.avatar == 'assets/app/avatars/$a.webp',
                  onTap: () => s.setAvatar(a),
                  child: Container(
                    width: tile,
                    height: tile,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: s.avatar == 'assets/app/avatars/$a.webp' ? Z.goldBright : Z.chip, width: 3),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/app/avatars/$a.webp', fit: BoxFit.cover),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _AccountAction extends StatelessWidget {
  const _AccountAction(this.label, {required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Press(
        label: label,
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Z.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Z.cardBorder, width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: outfit(13, w: FontWeight.w700, c: Z.cream)),
            const SizedBox(width: 6),
            const StrokeIco(P.forward, size: 12, color: Z.faint, width: 2.6),
          ]),
        ),
      );
}

// ── VIP club ─────────────────────────────────────────────────────────────────

class VipScreen extends StatefulWidget {
  const VipScreen({super.key});

  @override
  State<VipScreen> createState() => _VipScreenState();
}

class _VipScreenState extends State<VipScreen> {
  static const tiers = [
    ('Bronze', Color(0xFFD9915A), '0 – 9,999 pts', ['Daily bonus', 'Weekly promotions', 'Help from your agent']),
    ('Silver', Color(0xFFD9DAE6), '10,000 pts', ['Bigger daily bonus', 'Birthday gift', 'Priority help from your agent']),
    ('Gold', Color(0xFFF2C869), '50,000 pts', ['Gold daily bonus', 'Bigger daily bonus', 'Exclusive tournaments']),
    ('Platinum', Color(0xFF9FD8FF), '150,000 pts', ['Platinum bonus wheel', 'Monthly cashback in GC', 'Dedicated VIP host']),
    ('Diamond', Color(0xFFC99BFF), 'Invite only', ['Custom rewards', 'Event invitations', 'Priority support']),
  ];

  @override
  Widget build(BuildContext context) {
    return ZPage(
      gradient: Z.pageGlow(ry: .4, top: const Color(0xFF5A3510)),
      child: Column(children: [
        const TopBar(
          title: 'VIP CLUB',
          backLabel: 'Back to profile',
          border: false,
        ),
        Expanded(
          child: Panes(
            sideFraction: .34,
            minSide: 230,
            maxSide: 330,
            side: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 6, 12),
              child: GoldFrame(
                radius: 20,
                shadows: [bs(0, 10, 26, const Color(0x8C000000)), bs(0, 0, 30, const Color(0x33E2B04F))],
                inner: ellipseGradient(
                    cx: .5, cy: 0, rx: .9, ry: .8, colors: const [Color(0xFF4A2A0A), Z.field], stops: const [0, .75]),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  const RawIco('<path d="${P.crown}" fill="#d9915a"/><rect x="3" y="19" width="18" height="2" rx="1" fill="#d9915a"/>',
                      size: 38),
                  Text('YOUR STATUS', style: outfit(11, w: FontWeight.w700, ls: .2, c: Z.label)),
                  Text('Bronze', style: playfair(30, w: FontWeight.w800, c: const Color(0xFFE8B878), h: 1)),
                  const GoldBar(value: .62, height: 10),
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: '3,800 points until '),
                      TextSpan(text: 'Silver', style: outfit(13, w: FontWeight.w800, c: const Color(0xFFE6E6F0))),
                    ]),
                    style: outfit(13, c: Z.body),
                  ),
                  Container(height: 1, color: Z.line35),
                  Text('Every spin earns VIP points; daily logins and promotions add more. Tiers are reviewed monthly.',
                      textAlign: TextAlign.center, style: outfit(12, c: Z.muted, h: 1.35)),
                  LinkText('Play to earn points ›', size: 13, w: FontWeight.w700, onTap: () => Nav.tab(AppTab.games)),
                ]),
              ),
            ),
            // Tiers side by side, scrolling sideways when they don't all fit.
            main: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 14, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle('TIERS & PERKS', size: 15),
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(builder: (context, box) {
                    const gap = 10.0;
                    final w = ((box.maxWidth - gap * (tiers.length - 1)) / tiers.length).clamp(150.0, 220.0);
                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: tiers.length,
                      separatorBuilder: (_, __) => const SizedBox(width: gap),
                      itemBuilder: (_, i) {
                        final (name, color, pts, perks) = tiers[i];
                        return SizedBox(width: w, child: _TierCard(name: name, color: color, pts: pts, perks: perks, current: i == 0));
                      },
                    );
                  }),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.name, required this.color, required this.pts, required this.perks, this.current = false});
  final String name;
  final Color color;
  final String pts;
  final List<String> perks;
  final bool current;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: .16), Z.card],
            stops: const [0, .55],
          ),
          border: Border.all(color: current ? Z.goldEdge : Z.cardBorder, width: current ? 2 : 1),
          boxShadow: current ? [bs(0, 0, 14, const Color(0x40E2B04F))] : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Ico(P.crown, size: 24, color: color),
            const Spacer(),
            if (current)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x26FFD45A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Z.border),
                ),
                child: Text('CURRENT', style: outfit(9, w: FontWeight.w800, ls: .08, c: Z.goldBright)),
              ),
          ]),
          const SizedBox(height: 6),
          Text(name, style: outfit(18, w: FontWeight.w800, c: color, h: 1.1)),
          Text(pts, style: outfit(12, c: Z.muted2)),
          const SizedBox(height: 8),
          for (final p in perks)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('•  $p', style: outfit(13, c: Z.body, h: 1.25)),
            ),
        ]),
      );
}

// ── Settings ─────────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.section = 'gameplay'});

  /// 'gameplay', 'notifications', 'responsible' or 'account'.
  final String section;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const keys = ['gameplay', 'notifications', 'responsible', 'account'];
  late int section = keys.indexOf(widget.section).clamp(0, keys.length - 1);

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    Widget t(String key, String label, String hint) =>
        _ToggleRow(label: label, hint: hint, on: s.settings[key] ?? false, onTap: () => s.toggleSetting(key), last: true);
    Widget l(String label, String value, VoidCallback onTap) =>
        ListRow(label: label, value: value, onTap: onTap, color: Z.cream, last: true);
    final sections = [
      ('GAMEPLAY', P.games, [
        t('sound', 'Sound effects', 'Reels, wins and buttons'),
        t('music', 'Music', 'Background soundtrack'),
        t('vibe', 'Vibration', 'Haptics on big wins'),
        t('fast', 'Fast spin', 'Shorter reel animation'),
      ]),
      ('NOTIFICATIONS', P.bell, [
        t('push', 'Push notifications', 'Jackpots and account alerts'),
        t('bonus', 'Bonus reminders', 'Daily bonus and streaks'),
        t('coins', 'Coins added', 'When your agent loads your coins'),
      ]),
      ('RESPONSIBLE GAMING', P.shield, [
        t('reminder', 'Session reminder', 'Remind me every 60 minutes'),
        l('Daily purchase limit', 'Not set', () => showToast(context, 'Ask your agent to set a daily limit')),
        l('Take a break', '', () => showToast(context, 'Breaks of 24h, 7 days or 30 days')),
        l('Self-exclusion', '', () => showToast(context, 'Ask your agent to close your account for the time you choose')),
      ]),
      ('ACCOUNT & HELP', P.profile, [
        l('Language', 'English', () => showToast(context, 'More languages coming soon')),
        l('Edit profile', '', () => Nav.push(R.editProfile)),
        l('Change password', '', () => Nav.push(R.forgot)),
        l('Terms, privacy & rules', '', () => Nav.push(R.legal)),
        l('Connection test', '', () => Nav.push(R.offline)),
      ]),
    ];
    final (_, _, rows) = sections[section];
    return ZPage(
      child: Panes(
        sideFraction: .3,
        minSide: 210,
        maxSide: 280,
        minMain: 260,
        divider: true,
        // Sections on the left, the chosen section's settings on the right.
        side: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const BackBtn(label: 'Back'),
              const SizedBox(width: 12),
              Text('SETTINGS', style: outfit(20, w: FontWeight.w800, ls: .1, c: Z.gold)),
            ]),
            const SizedBox(height: 12),
            for (final (i, (title, icon, _)) in sections.indexed) ...[
              _SectionTab(title: title, icon: icon, selected: i == section, onTap: () => setState(() => section = i)),
              const SizedBox(height: 6),
            ],
            const Spacer(),
            Text('Zoya7 · v1.0.0 · 18+ · Play responsibly', style: outfit(11, c: Z.faint)),
          ]),
        ),
        main: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
          // Two columns once each can be 260 wide.
          child: GridView(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 420, mainAxisExtent: 58, mainAxisSpacing: 8, crossAxisSpacing: 10),
            children: [for (final r in rows) ZCard(child: r)],
          ),
        ),
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  const _SectionTab({required this.title, required this.icon, required this.selected, required this.onTap});
  final String title;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        selected: selected,
        label: title,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            gradient: selected ? Z.goldTab : null,
            color: selected ? null : const Color(0xFF0D0906),
            border: selected ? null : Border.all(color: Z.border, width: 1.5),
          ),
          child: Row(children: [
            Ico(icon, size: 16, color: selected ? Z.brown : Z.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: outfit(12, w: FontWeight.w800, ls: .05, c: selected ? Z.brown : Z.tabOff)),
            ),
          ]),
        ),
      );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.label, required this.hint, required this.on, required this.onTap, this.last = false});
  final String label;
  final String hint;
  final bool on;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) => Semantics(
        toggled: on,
        label: label,
        child: Press(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Z.divider))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: outfit(15, w: FontWeight.w600, c: Z.cream)),
                  const SizedBox(height: 1),
                  Text(hint, style: outfit(12, c: Z.muted2)),
                ]),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 54,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: on ? Z.green2 : null,
                  color: on ? null : Z.iconTile,
                  border: Border.all(color: on ? Z.rimBright : Z.chipDark, width: 1.5),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 23,
                    height: 23,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: circleGradient(cx: .4, cy: .3, colors: const [Color(0xFFFFF8E0), Color(0xFFE0C48A)]),
                      boxShadow: [bs(0, 2, 4, const Color(0x80000000))],
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
}

// ── Notifications ────────────────────────────────────────────────────────────

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final notes = s.notes;
    final unread = s.unreadNotifications;
    return ZPage(
      child: Column(children: [
        TopBar(
          title: 'NOTIFICATIONS',
          backLabel: 'Back to lobby',
          titleSize: 19,
          right: Press(
            onTap: s.markAllRead,
            label: 'Mark all read',
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Z.field,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Z.chip),
              ),
              child: Center(
                widthFactor: 1,
                child: Text(unread > 0 ? 'Mark $unread read' : 'All caught up',
                    style: outfit(12, w: FontWeight.w700, c: Z.gold)),
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            // As many columns as fit 420px cards; rows share the height.
            child: notes.isEmpty
                ? Center(child: Text('Nothing yet. When your agent adds coins, you’ll see it here.', style: outfit(14, c: Z.muted)))
                : LayoutBuilder(builder: (context, box) {
              const gap = 8.0;
              final cols = columnsFor(box.maxWidth, 420, gap: gap);
              final rows = (notes.length / cols).ceil();
              final tileH = ((box.maxHeight - gap * (rows - 1)) / rows).clamp(64.0, 96.0);
              return GridView.count(
                crossAxisCount: cols,
                mainAxisSpacing: gap,
                crossAxisSpacing: 10,
                childAspectRatio: ((box.maxWidth - 10 * (cols - 1)) / cols) / tileH,
                children: [
                  for (final n in notes)
                    _Note(
                      title: n.title,
                      body: n.body,
                      when: _when(n.at, s.casino.now),
                      path: n.kind == NoteKind.bonus ? P.gift : P.coin,
                      color: switch (n.kind) { NoteKind.coinsIn => Z.teal, NoteKind.declined => Z.coral, _ => Z.gold },
                      unread: s.isUnread(n),
                      onTap: n.kind == NoteKind.bonus
                          ? () => openDailyBonus(context)
                          : () => Nav.tab(AppTab.wallet, walletTab: 'history'),
                    ),
                ],
              );
            }),
          ),
        ),
      ]),
    );
  }
}

/// "9:05 AM" today, "Yesterday", or "Oct 13".
String _when(DateTime at, DateTime now) {
  final day = DateTime(at.year, at.month, at.day), today = DateTime(now.year, now.month, now.day);
  if (day == today) {
    final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    return '$h:${at.minute.toString().padLeft(2, '0')} ${at.hour < 12 ? 'AM' : 'PM'}';
  }
  if (today.difference(day).inDays == 1) return 'Yesterday';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[at.month - 1]} ${at.day}';
}

class _Note extends StatelessWidget {
  const _Note({required this.title, required this.body, required this.when, required this.path, required this.color, required this.unread, required this.onTap});
  final String title, body, when, path;
  final Color color;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        label: unread ? '$title, unread' : title,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: unread ? const LinearGradient(colors: [Color(0xFF2A1A0A), Color(0xFF140D07)]) : null,
            color: unread ? null : Z.card,
            border: Border.all(color: unread ? Z.chip : Z.divider),
          ),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Z.iconTile,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Z.cardBorder),
              ),
              child: Ico(path, size: 19, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (unread) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Z.red, boxShadow: [bs(0, 0, 6, Z.red)]),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(title,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: outfit(14, w: FontWeight.w700, c: Z.cream)),
                  ),
                  const SizedBox(width: 8),
                  Text(when, style: outfit(11, c: Z.faint)),
                ]),
                const SizedBox(height: 2),
                Text(body,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: outfit(12, c: const Color(0xFFCDBFA6), h: 1.3)),
              ]),
            ),
          ]),
        ),
      );
}

// ── Terms, privacy & coin rules ─────────────────────────────────────────────

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key, this.doc = 'terms'});
  final String doc;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  static const keys = ['terms', 'privacy', 'rules'];
  late int doc = keys.indexOf(widget.doc).clamp(0, 2);

  static const docs = [
    ('TERMS', 'Terms of Service', [
      ('1. Eligibility', '[Minimum age, eligible locations and excluded jurisdictions.]'),
      ('2. Your account', '[One account per person, accurate information, account security.]'),
      ('3. Virtual currencies', 'Gold Coins and DC are for play only. They have no cash value and can’t be redeemed for money or prizes.'),
      ('4. Purchases & refunds', '[Package purchases, payment methods, refund policy.]'),
      ('5. Prohibited conduct', '[Cheating, multiple accounts, abusive behaviour, automated play.]'),
      ('6. Ending your account', '[Closure, suspension and what happens to balances.]'),
    ]),
    ('PRIVACY', 'Privacy Policy', [
      ('What we collect', '[Account details, identity documents, location, device and gameplay data.]'),
      ('How we use it', '[Running the service, verifying identity and location, fraud prevention, support.]'),
      ('Sharing', '[Payment processors, verification providers, legal requests.]'),
      ('Your choices', '[Access, correction, deletion, marketing opt-out.]'),
      ('Retention & security', '[How long data is kept and how it is protected.]'),
    ]),
    ('COIN RULES', 'Coin Rules', [
      ('Operator', '[Legal name and address of the operator.]'),
      ('Who can play', '[Age requirement and eligible countries.]'),
      ('Getting coins', '[Starting amount, daily bonus, coin packages, coins added by staff.]'),
      ('No cash value', 'Coins can’t be exchanged, redeemed or paid out for money or prizes.'),
      ('Odds', '[How game outcomes are determined.]'),
      ('Disputes', '[Governing law and how disputes are resolved.]'),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final (_, title, sections) = docs[doc];
    return ZPage(
      child: PaneLists(
            top: 8,
        sideFraction: .3,
        minSide: 220,
        maxSide: 300,
        divider: true,
        side: [
            Row(children: [
              const BackBtn(label: 'Back to settings'),
              const SizedBox(width: 12),
              Text('LEGAL', style: outfit(21, w: FontWeight.w800, ls: .1, c: Z.gold)),
            ]),
            const SizedBox(height: 14),
            for (final (i, d) in docs.indexed) ...[
              Press(
                onTap: () => setState(() => doc = i),
                selected: i == doc,
                label: d.$2,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(21),
                    gradient: i == doc ? Z.goldTab : null,
                    color: i == doc ? null : const Color(0xFF0D0906),
                    border: i == doc ? null : Border.all(color: Z.border, width: 1.5),
                  ),
                  child: Text(d.$1, style: outfit(13, w: FontWeight.w800, ls: .06, c: i == doc ? Z.brown : Z.tabOff)),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 6),
            Text('Questions? Ask your agent.', style: outfit(14, w: FontWeight.w700, c: Z.muted)),
          ],
        main: [
            Text(title, style: outfit(24, w: FontWeight.w800, c: Z.cream)),
            const SizedBox(height: 4),
            Text('Last updated [DATE] · Version [X.X]', style: outfit(13, c: Z.muted2)),
            if (doc == 2) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0x14E2B04F),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Z.goldEdge, width: 2),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('NO CASH VALUE', style: outfit(15, w: FontWeight.w800, ls: .06, c: Z.goldHi)),
                  const SizedBox(height: 6),
                  Text(
                      'Coins are for entertainment only. Winning coins never wins money or prizes.',
                      style: outfit(14, c: Z.soft, h: 1.5)),
                ]),
              ),
            ],
            for (final (h, b) in sections) ...[
              const SizedBox(height: 14),
              Text(h, style: outfit(16, w: FontWeight.w800, c: Z.gold)),
              const SizedBox(height: 6),
              Text(b, style: outfit(14, c: Z.body, h: 1.6)),
            ],
          ],
      ),
    );
  }
}
