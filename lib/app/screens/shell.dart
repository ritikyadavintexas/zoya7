import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../icons.dart';
import '../nav.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'lobby.dart';

/// Home: the lobby under the HUD. Every other section opens over it — the
/// avatar opens the profile, the balances the wallet, the gift the daily
/// bonus, and the menu button the rest.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Z.inkDeep,
    resizeToAvoidBottomInset: false,
    body: Stack(
      children: [
        const Positioned.fill(child: CasinoBackdrop()),
        Column(
          children: [
            const Hud(),
            Expanded(
              child: MediaQuery.removePadding(context: context, removeTop: true, child: const LobbyPage()),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Top bar of the lobby: player, level, balances and quick actions. What it
/// shows follows the width it gets — the level meter and the sound toggle
/// drop out first on small phones.
class Hud extends StatelessWidget {
  const Hud({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final mq = MediaQuery.of(context);
    // 13% of the screen height, 46–64 tall.
    final h = (mq.size.height * .13).clamp(46.0, 64.0);
    return Container(
      height: h + mq.padding.top,
      padding: EdgeInsets.fromLTRB(mq.padding.left + 10, mq.padding.top, mq.padding.right + 10, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF22160B), Color(0xFF0C0805)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        border: const Border(bottom: BorderSide(color: Z.goldEdge, width: 1.5)),
        boxShadow: [bs(0, 6, 18, const Color(0xB3000000))],
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final showLevel = w >= 880; // after the name has room
          final showSound = w >= 620;
          final soundOn = (s.settings['sound'] ?? false) || (s.settings['music'] ?? false);
          final showName = w >= 600;
          final showBadge = w >= 520;
          // Small phones: tighter icon buttons and spacing.
          final compact = w < 620;
          final iconW = compact ? 36.0 : 42.0;
          final pillH = h * .72;
          return Row(
            children: [
              Flexible(
                child: Press(
                  label: 'Your profile',
                  onTap: () => Nav.tab(AppTab.profile),
                  child: Row(
                    children: [
                      _FramedAvatar(size: h * .84),
                      if (showName) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Ico(P.crown, size: 14, color: Z.goldBright),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        s.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: outfit(15, w: FontWeight.w800, c: Z.cream),
                                      ),
                                    ),
                                  ],
                                ),
                                if (showBadge) ...[
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: const Color(0xFF2A1B0B),
                                      border: Border.all(color: const Color(0x99C99A3E)),
                                    ),
                                    child: Text(
                                      'VIP BRONZE',
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.fade,
                                      style: outfit(10, w: FontWeight.w700, ls: .06, c: Z.goldEdge),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (showLevel) ...[const SizedBox(width: 14), _Level(level: s.level, progress: s.levelProgress)],
              SizedBox(width: compact ? 8 : 16),
              _BalancePill(
                height: pillH,
                coin: Coin(size: pillH * .78, fontSize: pillH * .26),
                label: 'GC',
                labelColor: Z.goldBright,
                value: fmtInt(s.gc),
                border: Z.goldEdge,
                onPlus: () => Nav.tab(AppTab.wallet, walletTab: 'buy'),
                plusLabel: 'Buy Gold Coins',
              ),
              const SizedBox(width: 8),
              _BalancePill(
                height: pillH,
                coin: Coin(label: 'DC', size: pillH * .78, fontSize: pillH * .26, teal: true),
                label: 'DC',
                labelColor: Z.teal,
                value: fmtSc(s.sc),
                border: const Color(0xFF2FB58E),
              ),
              if (!compact) const Spacer() else const SizedBox(width: 4),
              _HudIcon(
                extent: iconW,
                label: s.bonusClaimed ? 'Daily bonus' : 'Daily bonus ready',
                dot: !s.bonusClaimed,
                onTap: () => openDailyBonus(context),
                child: const RawIco(_giftSvg, size: 28),
              ),
              _HudIcon(
                extent: iconW,
                label: 'Messages, ${s.unreadNotifications} new',
                dot: s.unreadNotifications > 0,
                onTap: () => Nav.push(R.notifications),
                child: const RawIco(_mailSvg, size: 28),
              ),
              _HudIcon(
                extent: iconW,
                label: 'Chat',
                onTap: () => Nav.push(R.chat),
                child: const Ico(P.chatDots, size: 27),
              ),
              if (showSound)
                _HudIcon(
                  extent: iconW,
                  label: soundOn ? 'Sound on' : 'Sound off',
                  // Mutes (or brings back) both the effects and the music.
                  onTap: () => s
                    ..setSetting('sound', !soundOn)
                    ..setSetting('music', !soundOn),
                  child: RawIco(soundOn ? _soundOnSvg : _soundOffSvg, size: 27),
                ),
              _HudIcon(
                extent: iconW,
                label: 'Menu',
                onTap: () => showOptionsMenu(context),
                child: const RawIco(_menuSvg, size: 27),
              ),
            ],
          );
        },
      ),
    );
  }
}

const _giftSvg =
    '<path d="M3 9h18v4H3z" fill="#f2c869"/><path d="M4 13h16v8H4z" fill="#d9a23a"/>'
    '<path d="M10.5 9h3v12h-3z" fill="#e3242b"/>'
    '<path d="M12 9c-1.5-3-5-4.5-6-2.5S8.5 9 12 9zm0 0c1.5-3 5-4.5 6-2.5S15.5 9 12 9z" fill="#ffe7a0"/>';
const _mailSvg =
    '<rect x="2.5" y="5" width="19" height="14" rx="2" fill="#f2c869"/>'
    '<path d="M3.5 6.5l8.5 6.5 8.5-6.5" fill="none" stroke="#6a4310" stroke-width="1.8" stroke-linejoin="round"/>';
const _soundOnSvg =
    '<path d="M3 9h4l5-4v14l-5-4H3z" fill="#f2c869"/>'
    '<path d="M15.5 8.5a5 5 0 0 1 0 7M18 6a8.5 8.5 0 0 1 0 12" fill="none" stroke="#f2c869" stroke-width="2" stroke-linecap="round"/>';
const _soundOffSvg =
    '<path d="M3 9h4l5-4v14l-5-4H3z" fill="#8f8576"/>'
    '<path d="M16 9.5l5 5M21 9.5l-5 5" fill="none" stroke="#8f8576" stroke-width="2" stroke-linecap="round"/>';
const _menuSvg =
    '<rect x="3" y="3" width="8" height="8" rx="2" fill="#f2c869"/>'
    '<rect x="13" y="3" width="8" height="8" rx="2" fill="#f2c869"/>'
    '<rect x="3" y="13" width="8" height="8" rx="2" fill="#f2c869"/>'
    '<rect x="13" y="13" width="8" height="8" rx="2" fill="#e3242b"/>';

/// The options panel: everything the HUD doesn't already have one tap away,
/// as tiles in a gold panel that drops from the top-right corner.
void showOptionsMenu(BuildContext context) {
  final options = [
    ('All games', P.games, () => Nav.tab(AppTab.games)),
    ('Promotions', P.giftPlain, () => Nav.tab(AppTab.promotions)),
    ('VIP Club', P.crown, () => Nav.push(R.vip)),
    ('Slots race', P.trophyFull, () => Nav.push(R.leaderboard)),
    ('Settings', P.gear, () => Nav.push(R.settings)),
    ('Help & support', P.chat, () => Nav.push(R.chat, 'support')),
    ('Rules & terms', P.doc, () => Nav.push(R.legal)),
    ('Log out', P.back, () => logOut(context)),
  ];
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close menu',
    barrierColor: const Color(0x99000000),
    transitionDuration: const Duration(milliseconds: 180),
    transitionBuilder: (_, a, __, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
        alignment: Alignment.topRight,
        scale: Tween(begin: .92, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
        child: child,
      ),
    ),
    pageBuilder: (ctx, _, __) {
      final mq = MediaQuery.of(ctx);
      final top = mq.padding.top + (mq.size.height * .13).clamp(46.0, 64.0) + 6;
      return Stack(
        children: [
          Positioned(
            top: top,
            right: mq.padding.right + 10,
            // Two columns of tiles; scrolls if a short phone can't fit them all.
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 340, maxHeight: mq.size.height - top - mq.padding.bottom - 10),
              child: GoldFrame(
                radius: 20,
                shadows: [bs(0, 12, 30, const Color(0xCC000000))],
                inner: ellipseGradient(
                  cx: .5,
                  cy: 0,
                  rx: .9,
                  ry: .8,
                  colors: const [Color(0xFF3A2209), Color(0xFF0E0905)],
                  stops: const [0, .8],
                ),
                padding: const EdgeInsets.all(10),
                child: Material(
                  type: MaterialType.transparency,
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (label, icon, go) in options)
                          _MenuTile(
                            label: label,
                            icon: icon,
                            danger: label == 'Log out',
                            onTap: () {
                              Navigator.of(ctx).pop();
                              go();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.label, required this.icon, required this.onTap, this.danger = false});
  final String label;
  final String icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => Press(
    label: label,
    onTap: onTap,
    child: Container(
      width: 152,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xCC140D07),
        border: Border.all(color: danger ? const Color(0xFF8A2A2A) : Z.chip, width: 1.5),
      ),
      child: Row(
        children: [
          Ico(icon, size: 20, color: danger ? Z.coral : Z.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: outfit(14, w: FontWeight.w700, c: danger ? Z.coral : Z.cream),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FramedAvatar extends StatelessWidget {
  const _FramedAvatar({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(2.5),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: Z.goldFrame,
      boxShadow: [bs(0, 0, 10, const Color(0x66FFC846))],
    ),
    child: Avatar(size: size - 5, border: 0),
  );
}

class _Level extends StatelessWidget {
  const _Level({required this.level, required this.progress});
  final int level;
  final double progress;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Level $level, ${(progress * 100).round()}% to the next level',
    child: SizedBox(
      width: 92,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lv. $level',
            style: outfit(13, w: FontWeight.w800, c: Z.cream),
          ),
          const SizedBox(height: 4),
          Container(
            height: 8,
            decoration: BoxDecoration(color: const Color(0xFF241A10), borderRadius: BorderRadius.circular(4)),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress.clamp(0, 1),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF2FB58E), Color(0xFF6FF0CF)]),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BalancePill extends StatelessWidget {
  const _BalancePill({
    required this.height,
    required this.coin,
    required this.label,
    required this.labelColor,
    required this.value,
    required this.border,
    this.onPlus,
    this.plusLabel,
  });
  final double height;
  final Widget coin;
  final String label;
  final Color labelColor;
  final String value;
  final Color border;
  final VoidCallback? onPlus;
  final String? plusLabel;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    padding: EdgeInsets.fromLTRB(3, 0, onPlus == null ? 14 : 3, 0),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(height / 2),
      border: Border.all(color: border, width: 1.5),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1C130A), Color(0xFF070503)],
      ),
      boxShadow: [bs(0, 0, 10, border.withValues(alpha: .25))],
    ),
    child: Row(
      children: [
        coin,
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label + value take ~75% of the pill's height.
            Text(
              label,
              style: outfit((height * .26).clamp(9.0, 12.0), w: FontWeight.w800, ls: .08, c: labelColor, h: 1),
            ),
            SizedBox(height: height * .05),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: outfit((height * .42).clamp(13.0, 19.0), w: FontWeight.w800, c: Z.cream, h: 1, features: tabular),
            ),
          ],
        ),
        if (onPlus != null) ...[
          const SizedBox(width: 10),
          Press(
            label: plusLabel,
            onTap: onPlus,
            child: Container(
              width: height - 9,
              height: height - 9,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: Z.coinGold()),
              child: StrokeIco(P.plus, size: height * .36, color: Z.coinInk, width: 3.5),
            ),
          ),
        ],
      ],
    ),
  );
}

class _HudIcon extends StatelessWidget {
  const _HudIcon({required this.label, required this.onTap, required this.child, this.dot = false, this.extent = 42});
  final String label;
  final double extent;
  final VoidCallback onTap;
  final Widget child;
  final bool dot;

  @override
  Widget build(BuildContext context) => Press(
    label: label,
    onTap: onTap,
    child: SizedBox(
      width: extent,
      height: extent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          child,
          if (dot)
            Positioned(
              top: 6,
              right: 5,
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
        ],
      ),
    ),
  );
}

/// Dark, warm casino-floor backdrop: a lit ceiling, side glows and soft
/// out-of-focus lights.
class CasinoBackdrop extends StatelessWidget {
  const CasinoBackdrop({super.key});

  @override
  Widget build(BuildContext context) => const RepaintBoundary(child: CustomPaint(painter: _BackdropPainter()));
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E1209), Color(0xFF0E0805), Color(0xFF070403)],
          stops: [0, .55, 1],
        ).createShader(r),
    );
    void glow(Offset c, double radius, Color color) => canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: c, radius: radius)),
    );
    final w = size.width, h = size.height;
    glow(Offset(w * .5, -h * .1), w * .55, const Color(0x593A2209));
    glow(Offset(w * .08, h * .55), h * .7, const Color(0x40553010));
    glow(Offset(w * .95, h * .45), h * .7, const Color(0x40553010));
    glow(Offset(w * .5, h * 1.05), w * .5, const Color(0x332A1606));
    // Out-of-focus lights, always in the same places.
    final rnd = math.Random(7);
    for (var i = 0; i < 26; i++) {
      final c = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * .8);
      final radius = 3 + rnd.nextDouble() * 9;
      glow(c, radius * 2.2, Color.fromRGBO(255, 196, 90, .05 + rnd.nextDouble() * .1));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
