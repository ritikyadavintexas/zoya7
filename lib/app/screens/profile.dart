import 'package:flutter/material.dart';

import '../icons.dart';
import '../nav.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'lobby.dart' show Avatar;

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

Widget _tile(String path) => Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Z.iconTile, borderRadius: BorderRadius.circular(10)),
      child: Ico(path, size: 18),
    );

// ── Profile ──────────────────────────────────────────────────────────────────

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final rows = [
      ('Edit profile', P.pencil, () => Nav.push(R.editProfile), null),
      ('Terms, privacy & rules', P.doc, () => Nav.push(R.legal), null),
      ('Wallet & transactions', P.wallet, () => Nav.tab(AppTab.wallet, walletTab: 'history'), null),
      ('VIP Club', P.crown, () => Nav.push(R.vip), null),
      ('Notifications', P.bell, () => Nav.push(R.notifications), s.unreadNotifications > 0 ? '${s.unreadNotifications}' : null),
      ('Live chat & help', P.chat, () => Nav.push(R.chat), '3'),
      ('Promotions & bonuses', P.giftPlain, () => Nav.tab(AppTab.promotions), null),
      ('Responsible gaming', P.shield, () => Nav.push(R.settings), null),
      ('Settings', P.gear, () => Nav.push(R.settings), null),
    ];
    return ZPage(
      gradient: Z.pageGlow(ry: .36, top: const Color(0xFF4A2A0A)),
      child: Column(children: [
        TopBar(
          title: 'PROFILE',
          backLabel: 'Back to lobby',
          onBack: () => Nav.tab(AppTab.home),
          border: false,
          right: RoundBtn(
            label: 'Settings',
            onTap: () => Nav.push(R.settings),
            child: const RawIco(
                '<g fill="none" stroke="#f2c869" stroke-width="2.4" stroke-linecap="round"><circle cx="12" cy="12" r="3.2"/><path d="${P.gearSpokes}"/></g>',
                size: 20),
          ),
        ),
        Expanded(
          child: PaneLists(
            top: 0,
            sideFraction: .4,
            side: [
                Row(children: [
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: Stack(children: [
                      const Avatar(size: 80, border: 3),
                      Positioned(
                        right: 0,
                        bottom: 2,
                        child: Press(
                          label: 'Edit profile',
                          onTap: () => Nav.push(R.editProfile),
                          child: Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: Z.goldBadge,
                              border: Border.all(color: Z.ink, width: 2),
                            ),
                            child: const Ico(P.pencil, size: 14, color: Z.brown),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: outfit(22, w: FontWeight.w800, c: Z.cream)),
                      const SizedBox(height: 4),
                      Text('ID 7700 1234 · Member since 2026', style: outfit(13, c: Z.muted)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                Press(
                  onTap: () => Nav.push(R.vip),
                  label: 'VIP Bronze — VIP Club',
                  child: GoldFrame(
                    radius: 16,
                    inner: ellipseGradient(
                        cx: 0, cy: 0, rx: 1, ry: .8, colors: const [Color(0xFF4A2A0A), Z.field], stops: const [0, .7]),
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Ico(P.crown, size: 22, color: Color(0xFFD9915A)),
                        const SizedBox(width: 8),
                        Expanded(child: Text('VIP BRONZE', style: outfit(16, w: FontWeight.w800, c: const Color(0xFFE8B878)))),
                        Text('VIP Club ›', style: outfit(13, w: FontWeight.w600, c: Z.gold)),
                      ]),
                      const SizedBox(height: 10),
                      const GoldBar(value: .62),
                      const SizedBox(height: 8),
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
                const SizedBox(height: 12),
                Row(children: [
                  for (final (i, (v, l)) in const [('248', 'SPINS'), ('75K', 'BIGGEST WIN'), ('4', 'DAY STREAK')].indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: ZCard(
                        radius: 14,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                        child: Column(children: [
                          Text(v, style: outfit(20, w: FontWeight.w800, c: Z.goldHi)),
                          const SizedBox(height: 2),
                          FittedBox(child: Text(l, style: outfit(11, w: FontWeight.w600, ls: .06, c: Z.muted))),
                        ]),
                      ),
                    ),
                  ],
                ]),
              ],
            main: [
                ZCard(
                  child: Column(children: [
                    for (final (i, (label, path, onTap, badge)) in rows.indexed)
                      ListRow(
                        label: label,
                        leading: _tile(path),
                        badge: badge,
                        onTap: onTap,
                        last: i == rows.length - 1,
                      ),
                  ]),
                ),
                const SizedBox(height: 12),
                GhostButton('LOG OUT', color: Z.coral, borderColor: const Color(0xFF8A2A2A), onTap: () => Nav.reset(R.welcome)),
              ],
          ),
        ),
      ]),
    );
  }
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
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Z.rimBright, width: 1.5),
                gradient: Z.red3,
              ),
              child: Text('SAVE', style: outfit(14, w: FontWeight.w800, ls: .06, c: Z.ctaText)),
            ),
          ),
        ),
        Expanded(
          child: PaneLists(
            sideFraction: .34,
            minSide: 240,
            maxSide: 320,
            side: [Center(child: Column(children: [
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
                ZField(label: 'USERNAME', initial: s.name, helper: 'Shown in chat and on leaderboards.'),
                const SizedBox(height: 12),
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
                  return box.maxWidth >= 460
                      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: email),
                          const SizedBox(width: 12),
                          const Expanded(child: phone),
                        ])
                      : Column(children: [email, const SizedBox(height: 12), phone]);
                }),
                const SizedBox(height: 14),
                ZCard(
                  child: Column(children: [
                    ListRow(label: 'Change password', onTap: () => Nav.push(R.forgot)),
                    ListRow(
                        label: 'Identity verification',
                        value: 'Start',
                        valueColor: Z.gold,
                        onTap: () => Nav.tab(AppTab.wallet, walletTab: 'redeem')),
                    ListRow(label: 'Close my account', color: Z.coral, last: true, onTap: () => Nav.push(R.chat, 'support')),
                  ]),
                ),
              ],
          ),
        ),
      ]),
    );
  }
}

// ── VIP club ─────────────────────────────────────────────────────────────────

class VipScreen extends StatefulWidget {
  const VipScreen({super.key});

  @override
  State<VipScreen> createState() => _VipScreenState();
}

class _VipScreenState extends State<VipScreen> {
  String open = 'Bronze';

  static const tiers = [
    ('Bronze', Color(0xFFD9915A), '0 – 9,999 pts', ['Daily bonus', 'Weekly promotions', 'Live chat support']),
    ('Silver', Color(0xFFD9DAE6), '10,000 pts', ['Bigger daily bonus', 'Birthday gift', 'Priority chat support']),
    ('Gold', Color(0xFFF2C869), '50,000 pts', ['Gold daily bonus', 'Faster redemptions', 'Exclusive tournaments']),
    ('Platinum', Color(0xFF9FD8FF), '150,000 pts', ['Platinum bonus wheel', 'Monthly cashback in GC', 'Dedicated VIP host']),
    ('Diamond', Color(0xFFC99BFF), 'Invite only', ['Custom rewards', 'Event invitations', 'Top-priority redemptions']),
  ];

  @override
  Widget build(BuildContext context) {
    return ZPage(
      gradient: Z.pageGlow(ry: .4, top: const Color(0xFF5A3510)),
      child: Column(children: [
        TopBar(
          title: 'VIP CLUB',
          backLabel: 'Back to profile',
          border: false,
          right: RoundBtn(
            label: 'Contact VIP host',
            onTap: () => Nav.push(R.chat, 'support'),
            child: const Ico(P.chat, size: 20),
          ),
        ),
        Expanded(
          child: PaneLists(
            top: 0,
            sideFraction: .4,
            side: [
                GoldFrame(
                  radius: 20,
                  shadows: [bs(0, 10, 26, const Color(0x8C000000)), bs(0, 0, 30, const Color(0x33E2B04F))],
                  inner: ellipseGradient(
                      cx: .5, cy: 0, rx: .9, ry: .8, colors: const [Color(0xFF4A2A0A), Z.field], stops: const [0, .75]),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(children: [
                    const RawIco('<path d="${P.crown}" fill="#d9915a"/><rect x="3" y="19" width="18" height="2" rx="1" fill="#d9915a"/>',
                        size: 48),
                    const SizedBox(height: 6),
                    Text('YOUR STATUS', style: outfit(12, w: FontWeight.w700, ls: .2, c: Z.label)),
                    const SizedBox(height: 6),
                    Text('Bronze', style: playfair(32, w: FontWeight.w800, c: const Color(0xFFE8B878), h: 1)),
                    const SizedBox(height: 12),
                    const GoldBar(value: .62),
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: '3,800 points until '),
                        TextSpan(text: 'Silver', style: outfit(14, w: FontWeight.w800, c: const Color(0xFFE6E6F0))),
                      ]),
                      style: outfit(14, c: Z.body),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                ZCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('HOW TO EARN POINTS', style: outfit(15, w: FontWeight.w800, ls: .06, c: Z.gold)),
                    const SizedBox(height: 8),
                    Text(
                        'Every spin earns VIP points. Daily logins and completed promotions add bonus points. Your tier is reviewed monthly.',
                        style: outfit(14, c: Z.body, h: 1.5)),
                    const SizedBox(height: 4),
                    LinkText('Play to earn points ›', size: 14, w: FontWeight.w700, onTap: () => Nav.tab(AppTab.games)),
                  ]),
                ),
              ],
            main: [
                const SectionTitle('TIERS & PERKS'),
                const SizedBox(height: 10),
                for (final (name, color, pts, perks) in tiers) ...[
                  _tier(name, color, pts, perks),
                  const SizedBox(height: 8),
                ],
              ],
          ),
        ),
      ]),
    );
  }

  Widget _tier(String name, Color color, String pts, List<String> perks) {
    final isOpen = open == name;
    final cur = name == 'Bronze';
    return Container(
      decoration: BoxDecoration(
        color: Z.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cur ? Z.goldEdge : Z.cardBorder, width: cur ? 1.5 : 1),
        boxShadow: cur ? [bs(0, 0, 14, const Color(0x40E2B04F))] : null,
      ),
      child: Column(children: [
        Press(
          onTap: () => setState(() => open = isOpen ? '' : name),
          label: '$name tier',
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(children: [
              Ico(P.crown, size: 26, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: outfit(17, w: FontWeight.w800, c: color)),
                  const SizedBox(height: 1),
                  Text(pts, style: outfit(12, c: Z.muted2)),
                ]),
              ),
              if (cur) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x26FFD45A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Z.border),
                  ),
                  child: Text('CURRENT', style: outfit(10, w: FontWeight.w800, ls: .08, c: Z.goldBright)),
                ),
                const SizedBox(width: 12),
              ],
              AnimatedRotation(
                turns: isOpen ? .5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const StrokeIco(P.chevDown, size: 16, color: Z.faint, width: 2.6),
              ),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: isOpen
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(54, 0, 14, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final p in perks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('•  $p', style: outfit(14, c: Z.body)),
                      ),
                  ]),
                )
              : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }
}

// ── Settings ─────────────────────────────────────────────────────────────────

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    Widget t(String key, String label, String hint, {bool last = false}) =>
        _ToggleRow(label: label, hint: hint, on: s.settings[key] ?? false, onTap: () => s.toggleSetting(key), last: last);
    Widget l(String label, String value, VoidCallback onTap, {bool last = false}) =>
        ListRow(label: label, value: value, onTap: onTap, color: Z.cream, last: last);
    final sections = [
      ('GAMEPLAY', [
        t('sound', 'Sound effects', 'Reels, wins and buttons'),
        t('music', 'Music', 'Background soundtrack'),
        t('vibe', 'Vibration', 'Haptics on big wins'),
        t('fast', 'Fast spin', 'Shorter reel animation', last: true),
      ]),
      ('NOTIFICATIONS', [
        t('push', 'Push notifications', 'Jackpots and account alerts'),
        t('bonus', 'Bonus reminders', 'Daily bonus and streaks'),
        t('mentions', 'Chat mentions', 'When someone replies to you', last: true),
      ]),
      ('RESPONSIBLE GAMING', [
        t('reminder', 'Session reminder', 'Remind me every 60 minutes'),
        l('Daily purchase limit', 'Not set', () => showToast(context, 'Set a daily limit with Zoya Support')),
        l('Take a break', '', () => showToast(context, 'Breaks of 24h, 7 days or 30 days')),
        l('Self-exclusion', '', () => Nav.push(R.chat, 'support'), last: true),
      ]),
      ('ACCOUNT & HELP', [
        l('Language', 'English', () => showToast(context, 'More languages coming soon')),
        l('Edit profile', '', () => Nav.push(R.editProfile)),
        l('Change password', '', () => Nav.push(R.forgot)),
        l('Live chat support', '', () => Nav.push(R.chat, 'support')),
        l('Terms, privacy & rules', '', () => Nav.push(R.legal)),
        l('Connection test', '', () => Nav.push(R.offline), last: true),
      ]),
    ];
    return ZPage(
      child: Column(children: [
        const TopBar(title: 'SETTINGS', backLabel: 'Back to profile'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
            children: [
              // Two columns once each can be 300 wide, one otherwise.
              LayoutBuilder(builder: (context, box) {
                final cols = box.maxWidth >= 2 * 300 + 14
                    ? [sections.sublist(0, 2), sections.sublist(2)]
                    : [sections];
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final (c, col) in cols.indexed) ...[
                    if (c > 0) const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        for (final (title, rows) in col) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(title, style: outfit(13, w: FontWeight.w800, ls: .14, c: Z.label)),
                          ),
                          const SizedBox(height: 8),
                          ZCard(child: Column(children: rows)),
                          const SizedBox(height: 14),
                        ],
                      ]),
                    ),
                  ],
                ]);
              }),
              Text('Zoya7 · version 1.0.0 · 18+ · Play responsibly',
                  textAlign: TextAlign.center, style: outfit(12, c: Z.faint)),
            ],
          ),
        ),
      ]),
    );
  }
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
    final groups = [
      ('TODAY', [
        ('Daily bonus ready', 'Day ${s.streakDay} of your streak — claim ${fmtInt(s.todayBonus)} GC now.', '9:00 AM', P.gift, Z.gold,
            () => Nav.tab(AppTab.promotions), true),
        ('Support replied', 'Zoya Support answered your question about coin packages.', '8:47 AM', P.chat, Z.teal,
            () => Nav.push(R.chat, 'support'), true),
        ('MEGA jackpot climbing', 'The MEGA jackpot just passed 1.2M GC. Spin Classic 777 for a shot.', '8:15 AM', P.trophy,
            Z.coral, () => Nav.push(R.gold), false),
      ]),
      ('EARLIER', [
        ('Package delivered', '120,000 GC and 10 free SC were added to your wallet.', 'Yesterday', P.coin, Z.gold,
            () => Nav.tab(AppTab.wallet, walletTab: 'history'), false),
        ('Almost Silver', 'You are 3,800 points away from VIP Silver.', 'Oct 13', P.crown, const Color(0xFFD9DAE6),
            () => Nav.push(R.vip), false),
        ('Weekend Slots Race', 'The race starts Friday — join from Promotions.', 'Oct 12', P.trophy, const Color(0xFFC99BFF),
            () => Nav.tab(AppTab.promotions), false),
      ]),
    ];
    final unread = s.unreadNotifications;
    return ZPage(
      child: Column(children: [
        const TopBar(title: 'NOTIFICATIONS', backLabel: 'Back to lobby', titleSize: 19),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
            children: [
              Row(children: [
                Expanded(child: Text(unread > 0 ? '$unread unread' : 'All caught up', style: outfit(14, c: Z.muted))),
                Press(
                  onTap: s.markAllRead,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Z.field,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Z.chip),
                    ),
                    child: Text('Mark all read', style: outfit(13, w: FontWeight.w700, c: Z.gold)),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              // TODAY and EARLIER side by side once each can be 300 wide.
              LayoutBuilder(builder: (context, box) {
                final cols = [
                  for (final (title, items) in groups)
                    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(title, style: outfit(13, w: FontWeight.w800, ls: .14, c: Z.label)),
                      for (final (t, b, at, path, color, onTap, u) in items) ...[
                        const SizedBox(height: 8),
                        _Note(
                          title: t,
                          body: b,
                          when: at,
                          path: path,
                          color: color,
                          unread: u && !s.notificationsRead,
                          onTap: onTap,
                        ),
                      ],
                    ]),
                ];
                return box.maxWidth >= 2 * 300 + 14
                    ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: cols[0]),
                        const SizedBox(width: 14),
                        Expanded(child: cols[1]),
                      ])
                    : Column(children: [cols[0], const SizedBox(height: 16), cols[1]]);
              }),
            ],
          ),
        ),
      ]),
    );
  }
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: unread ? const LinearGradient(colors: [Color(0xFF2A1A0A), Color(0xFF140D07)]) : null,
            color: unread ? null : Z.card,
            border: Border.all(color: unread ? Z.chip : Z.divider),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Z.iconTile,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Z.cardBorder),
              ),
              child: Ico(path, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: outfit(15, w: FontWeight.w700, c: Z.cream)),
                const SizedBox(height: 2),
                Text(body, style: outfit(13, c: const Color(0xFFCDBFA6), h: 1.35)),
                const SizedBox(height: 2),
                Text(when, style: outfit(11, c: Z.faint)),
              ]),
            ),
            if (unread)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(left: 8, top: 4),
                decoration: BoxDecoration(shape: BoxShape.circle, color: Z.red, boxShadow: [bs(0, 0, 6, Z.red)]),
              ),
          ]),
        ),
      );
}

// ── Terms, privacy & sweeps rules ────────────────────────────────────────────

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
      ('3. Virtual currencies', '[Gold Coins have no monetary value. Sweeps Coins rules are set out in the Sweepstakes Rules.]'),
      ('4. Purchases & refunds', '[Package purchases, payment methods, refund policy.]'),
      ('5. Prohibited conduct', '[Cheating, multiple accounts, abuse in chat, automated play.]'),
      ('6. Ending your account', '[Closure, suspension and what happens to balances.]'),
    ]),
    ('PRIVACY', 'Privacy Policy', [
      ('What we collect', '[Account details, identity documents, location, device and gameplay data.]'),
      ('How we use it', '[Running the service, verifying identity and location, fraud prevention, support.]'),
      ('Sharing', '[Payment processors, verification providers, legal requests.]'),
      ('Your choices', '[Access, correction, deletion, marketing opt-out.]'),
      ('Retention & security', '[How long data is kept and how it is protected.]'),
    ]),
    ('SWEEPS RULES', 'Official Sweepstakes Rules', [
      ('Sponsor', '[Legal name and address of the sponsor.]'),
      ('Who can enter', '[Age requirement and eligible / excluded states or countries.]'),
      ('How to get Sweeps Coins', '[Free bonus with Gold Coin packages, daily bonus, free entry method and its limits.]'),
      ('Redeeming prizes', '[Minimum redemption, verification required, payout methods and timing.]'),
      ('Odds & prizes', '[How winning outcomes are determined; prize values.]'),
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
            LinkText('Questions? Contact support ›', size: 14, w: FontWeight.w700, onTap: () => Nav.push(R.chat, 'support')),
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
                  Text('NO PURCHASE NECESSARY', style: outfit(15, w: FontWeight.w800, ls: .06, c: Z.goldHi)),
                  const SizedBox(height: 6),
                  Text(
                      'A purchase does not increase your chances of winning. Free Sweeps Coins are available through [FREE ENTRY METHOD — e.g. mail-in request, daily bonus].',
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
