import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../games/gold/src/assets.dart' show GoldAssets;
import '../../games/gold/src/math.dart' show JackpotTier, Sym;
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
    final pad = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(pad.left + 10, 8, pad.right + 10, pad.bottom + 8),
      child: LayoutBuilder(builder: (context, box) {
        // Jackpots on top; the games take everything below, with the reward
        // shortcuts in a slim column beside them.
        const gap = 10.0;
        final h = box.maxHeight;
        final jackpotH = (h * .22).clamp(54.0, 116.0);
        final cardH = (h - jackpotH - gap).clamp(150.0, 340.0);
        final iconSize = (cardH * .26).clamp(48.0, 72.0);
        final content = Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(height: jackpotH, child: _JackpotStrip(tick: tick)),
          const SizedBox(height: gap),
          SizedBox(
            height: cardH,
            child: Row(children: [
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                _RewardIcon(
                  label: 'DAILY',
                  semantic: s.bonusClaimed ? 'Daily bonus' : 'Daily bonus, 1 to claim',
                  count: s.bonusClaimed ? 0 : 1,
                  size: iconSize,
                  onTap: () => Nav.push(R.dailyBonus),
                  child: Image.asset(A.dailyBonusIcon, fit: BoxFit.cover),
                ),
                SizedBox(height: iconSize * .3),
                _RewardIcon(
                  label: 'VIP',
                  semantic: 'VIP Club, ${s.vipRewards} rewards waiting',
                  count: s.vipRewards,
                  size: iconSize,
                  onTap: () => Nav.push(R.vip),
                  child: Padding(
                    padding: EdgeInsets.all(iconSize * .14),
                    child: Image.asset(GoldAssets.symbol(Sym.crown), fit: BoxFit.contain),
                  ),
                ),
              ]),
              const SizedBox(width: 12),
              Expanded(child: _GameRow(height: cardH, gap: gap)),
            ]),
          ),
        ]);
        final total = jackpotH + gap + cardH;
        return total <= h ? Center(child: content) : SingleChildScrollView(child: content);
      }),
    );
  }
}

/// The game cards, centred when they all fit and scrolling sideways when not.
class _GameRow extends StatelessWidget {
  const _GameRow({required this.height, required this.gap});
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final cardW = height * .84;
        final fits = games.length * cardW + (games.length - 1) * gap <= box.maxWidth;
        if (fits) {
          return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final (i, g) in games.indexed) ...[
              if (i > 0) SizedBox(width: gap),
              GameCard(g, height: height),
            ],
          ]);
        }
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: games.length,
          separatorBuilder: (_, __) => SizedBox(width: gap),
          itemBuilder: (_, i) => GameCard(games[i], height: height),
        );
      });
}

/// A round-cornered reward shortcut with a red count badge (hidden at 0).
class _RewardIcon extends StatelessWidget {
  const _RewardIcon({
    required this.label,
    required this.semantic,
    required this.count,
    required this.size,
    required this.onTap,
    required this.child,
  });
  final String label;
  final String semantic;
  final int count;
  final double size;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Press(
        label: semantic,
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: size + 6,
            height: size + 6,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 0,
                top: 6,
                child: Container(
                  width: size,
                  height: size,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size * .26),
                    gradient: Z.goldFrame,
                    boxShadow: [bs(0, 6, 14, const Color(0x99000000)), bs(0, 0, 12, const Color(0x55FFC846))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(size * .26 - 2),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: circleGradient(cx: .5, cy: .35, colors: const [Color(0xFF4A2A0A), Color(0xFF120A05)]),
                      ),
                      child: SizedBox.expand(child: child),
                    ),
                  ),
                ),
              ),
              if (count > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Z.red,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: Z.cream, width: 1.5),
                      boxShadow: [bs(0, 2, 6, const Color(0x99000000))],
                    ),
                    child: Text('$count', style: outfit(12, w: FontWeight.w800, c: Z.cream, h: 1)),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 4),
          Text(label, style: outfit(11, w: FontWeight.w800, ls: .08, c: Z.goldHi)),
        ]),
      );
}

/// The four live jackpot meters on a gold-framed strip.
class _JackpotStrip extends StatelessWidget {
  const _JackpotStrip({required this.tick});
  final int tick;

  // Plaque art (from the Gold game) and its width / height.
  static const _plaques = [
    (JackpotTier.mega, 243 / 176),
    (JackpotTier.major, 232 / 175),
    (JackpotTier.minor, 216 / 159),
    (JackpotTier.mini, 205 / 154),
  ];

  int _value(JackpotTier t) => switch (t) {
        JackpotTier.mega => 1234567 + tick * 7,
        JackpotTier.major => 234567 + tick * 3,
        JackpotTier.minor => 56789 + tick ~/ 2,
        JackpotTier.mini => 12345 + tick ~/ 5,
      };

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final h = box.maxHeight;
        const gap = 10.0;
        // Plaques as tall as the strip allows, smaller if four don't fit across.
        final ratios = _plaques.fold<double>(0, (a, p) => a + p.$2);
        final plaqueH = math.min(h * .9, (box.maxWidth - h * .6 - 3 * gap) / ratios);
        return Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(h / 2),
            gradient: Z.goldFrame,
            boxShadow: [bs(0, 6, 18, const Color(0x99000000)), bs(0, 0, 18, const Color(0x40FFC846))],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(h / 2),
              gradient: ellipseGradient(
                  cx: .5, cy: .5, rx: .7, ry: 1.2, colors: const [Color(0xFF4A260C), Color(0xFF120A05)], stops: const [0, 1]),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              for (final (tier, ratio) in _plaques)
                _Plaque(tier: tier, value: _value(tier), height: plaqueH, width: plaqueH * ratio),
            ]),
          ),
        );
      });
}

class _Plaque extends StatelessWidget {
  const _Plaque({required this.tier, required this.value, required this.height, required this.width});
  final JackpotTier tier;
  final int value;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '${tier.name.toUpperCase()} jackpot ${fmtInt(value)} Gold Coins',
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(children: [
            Positioned.fill(child: Image.asset(GoldAssets.jackpot(tier), fit: BoxFit.fill)),
            // The plaque's dark value slot.
            Positioned(
              left: width * .12,
              right: width * .12,
              top: height * .6,
              bottom: height * .13,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(fmtInt(value),
                      style: outfit(height * .2, w: FontWeight.w800, c: Z.cream, features: tabular, sh: [
                        ts(0, 1, 0, const Color(0xFF000000)),
                        ts(0, 0, 8, const Color(0x80FFC850)),
                      ])),
                ),
              ),
            ),
          ]),
        ),
      );
}

/// A tall game card: art, name and a PLAY button, scaled to [height].
class GameCard extends StatelessWidget {
  const GameCard(this.g, {super.key, required this.height});
  final GameInfo g;
  final double height;

  @override
  Widget build(BuildContext context) {
    final w = height * .84;
    final nameSize = (height * .085).clamp(12.0, 26.0);
    final buttonH = (height * .14).clamp(24.0, 46.0);
    return Press(
      label: '${g.name} — ${g.playable ? 'play' : 'coming soon'}',
      onTap: () => openGame(g),
      child: Container(
        width: w,
        height: height,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: Z.goldFrame,
          boxShadow: [bs(0, 8, 18, const Color(0xB3000000)), bs(0, 0, 12, const Color(0x40FFC846))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(fit: StackFit.expand, children: [
            const ColoredBox(color: Color(0xFF120A05)),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AspectRatio(aspectRatio: 229 / 178, child: Image.asset(A.card(g.id), fit: BoxFit.cover)),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00120A05), Color(0x00120A05), Color(0xF2120A05)],
                  stops: [0, .45, .72],
                ),
              ),
            ),
            if (!g.playable)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xD90A0603),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Z.border),
                  ),
                  child: Text('SOON', style: outfit(10, w: FontWeight.w800, ls: .06, c: Z.gold, h: 1)),
                ),
              ),
            Positioned(
              left: 8,
              right: 8,
              bottom: height * .05,
              child: Column(children: [
                Text(g.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: outfit(nameSize,
                        w: FontWeight.w800,
                        c: Z.goldHi,
                        sh: [ts(0, 2, 4, const Color(0xE6000000)), ts(0, 0, 10, const Color(0x66FFC850))])),
                SizedBox(height: height * .03),
                Container(
                  height: buttonH,
                  width: w * .78,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(buttonH / 2),
                    border: Border.all(color: Z.rimBright, width: 1.5),
                    gradient: g.playable ? Z.red3 : null,
                    color: g.playable ? null : const Color(0xFF2A1B0B),
                  ),
                  alignment: Alignment.center,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (g.playable) ...[
                      Ico(P.play, size: buttonH * .42, color: Z.cream),
                      SizedBox(width: buttonH * .2),
                    ],
                    Text(g.playable ? 'PLAY' : 'PREVIEW',
                        style: outfit(buttonH * .42, w: FontWeight.w800, ls: .04, c: g.playable ? Z.cream : Z.gold)),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

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

