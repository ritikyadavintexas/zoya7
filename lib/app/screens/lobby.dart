import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../backoffice/casino.dart';
import '../../games/gold/src/assets.dart' show GoldAssets;
import '../../games/gold/src/math.dart' show JackpotTier, Sym;
import '../assets.dart';
import '../icons.dart';
import '../nav.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Open a game tile: Blackjack has its table, Classic 777 / Fruit Spin play
/// Gold, and the rest show "coming soon".
/// Games switched off in the back office (or everything, in maintenance
/// mode) say so instead of opening.
void openGame(BuildContext context, GameInfo g) {
  final casino = AppScope.read(context).casino;
  if (casino.settings.maintenance) {
    showToast(context, casino.settings.maintenanceMessage);
    return;
  }
  if (casino.statusOf(g.id) != GameStatus.live) {
    showToast(context, '${g.name} is under maintenance. Back soon!');
    return;
  }
  switch (g.id) {
    case 'blackjack':
      Nav.push(R.blackjack);
    case _ when g.playable:
      Nav.push(R.gold, g.id);
    default:
      Nav.push(R.comingSoon, g.id);
  }
}

/// The daily bonus, unless the back office has paused it.
void openDailyBonus(BuildContext context) {
  if (AppScope.read(context).casino.settings.dailyBonus) {
    Nav.push(R.dailyBonus);
  } else {
    showToast(context, 'The daily bonus is paused right now');
  }
}

/// The games players can see, in lobby order.
List<GameInfo> visibleGames(Casino casino) => [
      for (final g in games)
        if (casino.statusOf(g.id) != GameStatus.hidden) g,
    ];

/// A tile's corner tag: off, coming soon, or the back office's ribbon.
({String text, bool off})? gameTag(Casino casino, GameInfo g) {
  if (casino.settings.maintenance || casino.statusOf(g.id) == GameStatus.maintenance) return (text: 'OFF', off: true);
  if (!g.playable) return (text: 'SOON', off: false);
  final b = casino.config(g.id).badge;
  return b.isEmpty ? null : (text: b, off: false);
}

/// Jackpot meters tick up on a shared clock, so the lobby icon and the
/// jackpot popup always agree.
final _jackpotClock = Stopwatch()..start();
int _jackpotTick() => _jackpotClock.elapsedMilliseconds ~/ 200;

int jackpotValue(JackpotTier t, [int? tick]) {
  final k = tick ?? _jackpotTick();
  return switch (t) {
    JackpotTier.mega => 1234567 + k * 7,
    JackpotTier.major => 234567 + k * 3,
    JackpotTier.minor => 56789 + k ~/ 2,
    JackpotTier.mini => 12345 + k ~/ 5,
  };
}

String _short(int v) => v >= 1000000 ? '${(v / 1000000).toStringAsFixed(2)}M' : '${(v / 1000).toStringAsFixed(0)}K';

class LobbyPage extends StatefulWidget {
  const LobbyPage({super.key});

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  static const cats = ['All games', 'Slots', 'Table', 'Instant'];
  String cat = 'All games';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
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
    final shown = visibleGames(s.casino);
    final list = shown.where((g) => cat == 'All games' || g.cat == cat.toUpperCase()).toList();
    final featured = shown.where((g) => g.id == s.casino.featured).firstOrNull ?? shown.firstOrNull;
    return Padding(
      padding: EdgeInsets.fromLTRB(pad.left + 10, 8, pad.right + 10, pad.bottom + 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Categories.
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _CatChip(cats[i], selected: cats[i] == cat, onTap: () => setState(() => cat = cats[i])),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            // Two rows of square tiles fill the height; the reward icons share
            // the same height in a column on the left.
            // Two rows on phones; tall screens get a third row rather than
            // giant tiles.
            const gap = 8.0, maxTile = 230.0;
            final rows = ((box.maxHeight + gap) / (maxTile + gap)).ceil().clamp(2, 3);
            final tile = (box.maxHeight - gap * (rows - 1)) / rows;
            // Three icons: each is size + 6 (badge room) + 4 + ~18 (label),
            // with .2 × size between them.
            final iconSize = ((box.maxHeight - 3 * 28) / 3.4).clamp(34.0, 66.0);
            final mega = jackpotValue(JackpotTier.mega);
            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                _RewardIcon(
                  label: 'DAILY',
                  semantic: s.bonusClaimed ? 'Daily bonus' : 'Daily bonus, 1 to claim',
                  count: s.bonusClaimed ? 0 : 1,
                  size: iconSize,
                  onTap: () => openDailyBonus(context),
                  child: Image.asset(A.dailyBonusIcon, fit: BoxFit.cover),
                ),
                SizedBox(height: iconSize * .2),
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
                SizedBox(height: iconSize * .2),
                _RewardIcon(
                  label: 'JACKPOTS',
                  semantic: 'Jackpots — MEGA ${fmtInt(mega)} GC. Show all',
                  count: 0,
                  size: iconSize,
                  onTap: () => showJackpots(context),
                  child: Center(
                    child: _Plaque(
                      tier: JackpotTier.mega,
                      value: mega,
                      label: _short(mega),
                      width: iconSize * .9,
                      height: iconSize * .9 * 176 / 243,
                    ),
                  ),
                ),
              ]),
              const SizedBox(width: 12),
              Expanded(
                // One game highlighted, then two rows of tiles, scrolling sideways.
                child: CustomScrollView(
                  scrollDirection: Axis.horizontal,
                  slivers: [
                    if (featured != null) ...[
                      SliverToBoxAdapter(
                        child: _FeaturedTile(featured, size: Size(box.maxHeight * 1.05, box.maxHeight)),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(width: gap)),
                    ],
                    SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: rows,
                        mainAxisSpacing: gap,
                        crossAxisSpacing: gap,
                        mainAxisExtent: tile,
                      ),
                      delegate: SliverChildBuilderDelegate((_, i) => _GameTile(list[i]), childCount: list.length),
                    ),
                  ],
                ),
              ),
            ]);
          }),
        ),
      ]),
    );
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip(this.label, {required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Press(
        label: label,
        selected: selected,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: selected ? Z.goldTab : null,
            color: selected ? null : const Color(0xCC140D07),
            border: Border.all(color: selected ? Z.goldBright : const Color(0x99C99A3E), width: 1.2),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(label.toUpperCase(),
                style: outfit(12, w: FontWeight.w800, ls: .08, c: selected ? Z.brown : Z.tabOff)),
          ),
        ),
      );
}

/// The highlighted game: a large tile spanning both rows.
class _FeaturedTile extends StatelessWidget {
  const _FeaturedTile(this.g, {required this.size});
  final GameInfo g;
  final Size size;

  @override
  Widget build(BuildContext context) => Press(
        label: 'Featured: ${g.name} — play',
        onTap: () => openGame(context, g),
        child: Container(
          width: size.width,
          height: size.height,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: Z.goldFrame,
            boxShadow: [bs(0, 8, 18, const Color(0xB3000000)), bs(0, 0, 18, const Color(0x55FFC846))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(fit: StackFit.expand, children: [
              Transform.scale(
                scale: 1.45,
                alignment: const Alignment(0, .55),
                child: g.id == 'classic777'
                    ? Image.asset(A.welcomeHero, fit: BoxFit.cover, alignment: const Alignment(0, .9))
                    : Image.asset(A.card(g.id), fit: BoxFit.cover, alignment: Alignment.topCenter),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x00000000), Color(0xE60A0603)],
                    stops: [0, .5, 1],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(colors: [Color(0xFFFFB347), Color(0xFFE8771A)]),
                    boxShadow: [bs(0, 2, 6, const Color(0x99000000))],
                  ),
                  child: Text('★ FEATURED', style: outfit(11, w: FontWeight.w800, ls: .08, c: const Color(0xFF3A1A02), h: 1)),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(g.name.toUpperCase(),
                            maxLines: 1,
                            style: playfair((size.height * .1).clamp(16.0, 30.0), w: FontWeight.w800, c: Z.goldHi, h: 1)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                          switch (g.cat) {
                            'TABLE' => 'Table game · ${g.players.isEmpty ? 'live tables' : '${g.players} playing'}',
                            'INSTANT' => 'Instant win',
                            _ => '3-reel slot · MEGA jackpot',
                          },
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: outfit(12, c: Z.soft)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Z.rimBright, width: 1.5),
                      gradient: Z.red3,
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Ico(P.play, size: 11, color: Z.cream),
                      const SizedBox(width: 6),
                      Text('PLAY', style: outfit(13, w: FontWeight.w800, ls: .06, c: Z.cream)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      );
}

/// A square game tile: art with the name across the bottom.
class _GameTile extends StatelessWidget {
  const _GameTile(this.g);
  final GameInfo g;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final tag = gameTag(AppScope.of(context).casino, g);
          return Press(
          label: '${g.name} — ${tag?.off ?? false ? 'under maintenance' : g.playable ? 'play' : 'coming soon'}',
          onTap: () => openGame(context, g),
          child: Container(
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: Z.goldFrame,
              boxShadow: [bs(0, 6, 12, const Color(0x99000000))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10.5),
              child: Stack(fit: StackFit.expand, children: [
                const ColoredBox(color: Color(0xFF0E0A14)),
                if (tag?.off ?? false)
                  ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      .2, .6, .1, 0, 0, .2, .6, .1, 0, 0, .2, .6, .1, 0, 0, 0, 0, 0, 1, 0, //
                    ]),
                    child: Image.asset(A.card(g.id), fit: BoxFit.cover, alignment: Alignment.topCenter),
                  )
                else
                  Image.asset(A.card(g.id), fit: BoxFit.cover, alignment: Alignment.topCenter),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0x00000000), Color(0xE6080512)],
                      stops: [0, .55, 1],
                    ),
                  ),
                ),
                if (tag != null) Positioned(top: 5, right: 5, child: GameTagChip(tag, size: 9)),
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: Text(g.name.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: playfair((box.maxHeight * .12).clamp(12.0, 20.0), w: FontWeight.w800, c: Z.goldHi, h: 1)
                          .copyWith(shadows: [ts(0, 2, 4, const Color(0xE6000000))])),
                ),
              ]),
            ),
          ),
        );
        },
      );
}

/// A tile's corner tag (OFF / SOON / NEW / HOT).
class GameTagChip extends StatelessWidget {
  const GameTagChip(this.tag, {super.key, this.size = 10});
  final ({String text, bool off}) tag;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hot = !tag.off && (tag.text == 'HOT' || tag.text == 'NEW');
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * .7, vertical: size * .35),
      decoration: BoxDecoration(
        color: tag.off ? const Color(0xE6400A0A) : hot ? null : const Color(0xD90A0603),
        gradient: hot ? Z.red3 : null,
        borderRadius: BorderRadius.circular(size * .8),
        border: Border.all(color: tag.off ? Z.coral : hot ? Z.rimBright : Z.border),
      ),
      child: Text(tag.text, style: outfit(size, w: FontWeight.w800, ls: .06, c: tag.off ? Z.coral : hot ? Z.cream : Z.gold, h: 1)),
    );
  }
}

/// All four jackpots, live, in a popup.
void showJackpots(BuildContext context) => showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close jackpots',
      barrierColor: const Color(0xB3000000),
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (_, a, __, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: .94, end: 1.0).animate(a), child: child),
      ),
      pageBuilder: (_, __, ___) => const _JackpotsPopup(),
    );

class _JackpotsPopup extends StatefulWidget {
  const _JackpotsPopup();

  @override
  State<_JackpotsPopup> createState() => _JackpotsPopupState();
}

class _JackpotsPopupState extends State<_JackpotsPopup> {
  late final Timer _timer = Timer.periodic(const Duration(milliseconds: 200), (_) => setState(() {}));

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: math.min(size.width - 40, 720),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text('JACKPOTS', style: outfit(18, w: FontWeight.w800, ls: .12, c: Z.goldHi)),
              const Spacer(),
              RoundBtn(
                label: 'Close',
                onTap: () => Navigator.of(context).pop(),
                child: const StrokeIco(P.close, size: 16),
              ),
            ]),
            const SizedBox(height: 10),
            SizedBox(height: (size.height * .3).clamp(80.0, 140.0), child: _JackpotStrip(tick: _jackpotTick())),
            const SizedBox(height: 10),
            Text('Line up three on the payline in Classic 777 to win a jackpot.', style: outfit(13, c: Z.body)),
          ]),
        ),
      ),
    );
  }
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

  int _value(JackpotTier t) => jackpotValue(t, tick);

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
  const _Plaque({required this.tier, required this.value, required this.height, required this.width, this.label});
  final JackpotTier tier;
  final int value;

  /// Text in the value slot (defaults to the full amount).
  final String? label;
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
                  child: Text(label ?? fmtInt(value),
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

