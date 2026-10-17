import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../assets.dart';
import '../icons.dart';
import '../nav.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'lobby.dart' show GameTagChip, gameTag, openGame, visibleGames;

class GamesPage extends StatefulWidget {
  const GamesPage({super.key});

  @override
  State<GamesPage> createState() => _GamesPageState();
}

class _GamesPageState extends State<GamesPage> {
  static const cats = ['All', 'Slots', 'Table', 'Instant', 'Jackpot'];
  String cat = 'All';
  String query = '';

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final casino = AppScope.of(context).casino;
    final list = visibleGames(casino).where((g) {
      final catOk = cat == 'All' || g.cat == cat.toUpperCase() || (cat == 'Jackpot' && g.cat == 'SLOTS');
      return catOk && (q.isEmpty || g.name.toLowerCase().contains(q));
    }).toList();

    return ZPage(
      child: Column(children: [
        TopBar(
          title: 'GAMES',
          backLabel: 'Back to lobby',
          onBack: () => Nav.tab(AppTab.home),
          right: GcChip(onTap: () => Nav.tab(AppTab.wallet, walletTab: 'buy')),
        ),
        Expanded(
          child: Panes(
            sideFraction: .36,
            side: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // The featured banner takes whatever height the search and
                // categories leave.
                Expanded(child: _Featured(onTap: () => Nav.push(R.gold))),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setState(() => query = v),
                  style: outfit(15, c: Z.cream),
                  cursorColor: Z.goldHi,
                  decoration: fieldDeco(hint: 'Search games', radius: 24, left: 0).copyWith(
                    hintStyle: outfit(15, c: Z.faint),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 14, right: 10),
                      child: RawIco(
                          '<g fill="none" stroke="#c9a35a" stroke-width="2.4" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/></g>',
                          size: 18),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 42),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                // Categories: one row, scrolling sideways when they don't all fit.
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: cats.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final c = cats[i];
                      return Press(
                        selected: c == cat,
                        onTap: () => setState(() => cat = c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: c == cat ? Z.goldTab : null,
                            color: c == cat ? null : Z.field,
                            border: c == cat ? null : Border.all(color: Z.chip, width: 1.5),
                          ),
                          child: Center(
                            widthFactor: 1,
                            child: Text(c, style: outfit(14, w: FontWeight.w700, ls: .03, c: c == cat ? Z.brown : Z.soft)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ]),
            ),
            main: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 14, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SectionTitle(
                  cat == 'All' ? 'ALL GAMES' : cat.toUpperCase(),
                  trailing: Text('${list.length} ${list.length == 1 ? 'game' : 'games'}', style: outfit(13, c: Z.muted)),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: list.isEmpty
                      ? Text('No games match “$query”.', textAlign: TextAlign.center, style: outfit(15, c: Z.muted))
                      : LayoutBuilder(builder: (context, box) => _FitGrid(list: list, box: box)),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// The game tiles in the fewest columns that still fit the height (so tiles
/// are as big as possible without scrolling). Only when even 4+ narrow
/// columns can't fit does the grid scroll.
class _FitGrid extends StatelessWidget {
  const _FitGrid({required this.list, required this.box});
  final List<GameInfo> list;
  final BoxConstraints box;

  static const gap = 10.0;

  static (double imageH, double tileH, bool twoLines) _tile(double tileW) {
    final imageH = tileW * 96 / 179;
    final twoLines = tileW < 175;
    return (imageH, imageH + 6 + (twoLines ? 36 : 18), twoLines);
  }

  @override
  Widget build(BuildContext context) {
    final w = box.maxWidth, h = box.maxHeight;
    var cols = 1;
    for (; cols < list.length; cols++) {
      final tileW = (w - gap * (cols - 1)) / cols;
      final rows = (list.length / cols).ceil();
      if (rows * _tile(tileW).$2 + (rows - 1) * gap <= h) break;
    }
    // Don't let tiles get unusably small: past that, scroll instead.
    while (cols > 1 && (w - gap * (cols - 1)) / cols < 64) {
      cols--;
    }
    final tileW = (w - gap * (cols - 1)) / cols;
    final (imageH, tileH, twoLines) = _tile(tileW);
    return GridView.builder(
      padding: EdgeInsets.zero,
      itemCount: list.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: gap,
        crossAxisSpacing: gap,
        mainAxisExtent: tileH,
      ),
      itemBuilder: (_, i) => _GameTile(list[i], imageHeight: imageH, twoLines: twoLines),
    );
  }
}

class _Featured extends StatelessWidget {
  const _Featured({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Press(
        label: 'Featured: Classic 777 — play now',
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Z.goldEdge, width: 2),
            boxShadow: [bs(0, 0, 20, const Color(0x4DE2B04F))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(fit: StackFit.expand, children: [
            Image.asset(A.welcomeHero, fit: BoxFit.cover, alignment: const Alignment(0, .7)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xEB080503), Color(0x8C080503), Color(0x00080503)],
                  stops: [0, .5, .8],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                // Short banner: just the title and the button.
                builder: (context, box) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                if (box.maxHeight >= 120)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: Z.goldBadge),
                  child: Text('FEATURED', style: outfit(11, w: FontWeight.w800, ls: .08, c: Z.brown, h: 1)),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Classic 777',
                      style: outfit(box.maxHeight >= 120 ? 26 : 20,
                          w: FontWeight.w800, c: Z.cream, h: 1.05, sh: [ts(0, 2, 8, const Color(0xCC000000))])),
                  if (box.maxHeight >= 90) ...[
                    const SizedBox(height: 2),
                    Text('MEGA jackpot over 1.2M GC', style: outfit(13, c: Z.soft)),
                  ],
                ]),
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Z.rimBright, width: 1.5),
                    gradient: Z.red3,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Ico(P.play, size: 12, color: Z.ctaText),
                    const SizedBox(width: 8),
                    Text('PLAY NOW', style: outfit(14, w: FontWeight.w800, ls: .04, c: Z.ctaText)),
                  ]),
                ),
              ]),
              ),
            ),
          ]),
        ),
      );
}

class _GameTile extends StatelessWidget {
  const _GameTile(this.g, {required this.imageHeight, this.twoLines = false});
  final GameInfo g;
  final double imageHeight;
  final bool twoLines;

  @override
  Widget build(BuildContext context) {
    final tag = gameTag(AppScope.of(context).casino, g);
    final off = tag?.off ?? false;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Press(
          label: '${g.name} — ${off ? 'under maintenance' : g.playable ? 'play' : 'coming soon'}',
          onTap: () => openGame(context, g),
          child: Stack(children: [
            g.playable && !off
                ? RoundImage(g.image, height: imageHeight)
                : ColorFiltered(
                    colorFilter: ColorFilter.matrix(saturateBrightness(.8, .85)),
                    child: RoundImage(g.image, height: imageHeight, borderColor: Z.chip),
                  ),
            if (tag != null) Positioned(right: 6, top: 6, child: GameTagChip(tag)),
          ]),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          // On the narrowest tiles (a 4-inch phone) the two lines shrink to fit.
          child: twoLines
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(g.cat, style: outfit(12, w: FontWeight.w600, ls: .04, c: Z.muted, h: 1.5)),
                    _status(),
                  ]),
                )
              : Row(children: [
                  Text(g.cat, style: outfit(12, w: FontWeight.w600, ls: .04, c: Z.muted)),
                  const Spacer(),
                  _status(),
                ]),
        ),
      ]);
  }
}

extension on _GameTile {
  Widget _status() => Row(mainAxisSize: MainAxisSize.min, children: [
        if (g.playable) ...[
          Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: Z.green)),
          const SizedBox(width: 4),
        ],
        Text(g.playable ? '${g.players} playing' : 'Coming soon', style: outfit(12, c: Z.muted, h: 1.5)),
      ]);
}

/// CSS `saturate(s) brightness(b)`.
List<double> saturateBrightness(double s, double b) => [
      (.213 + .787 * s) * b, (.715 - .715 * s) * b, (.072 - .072 * s) * b, 0, 0,
      (.213 - .213 * s) * b, (.715 + .285 * s) * b, (.072 - .072 * s) * b, 0, 0,
      (.213 - .213 * s) * b, (.715 - .715 * s) * b, (.072 + .928 * s) * b, 0, 0,
      0, 0, 0, 1, 0,
    ];

final blur2 = ImageFilter.blur(sigmaX: 1, sigmaY: 1);

// ── Coming soon (Mega Reels, Blackjack, Roulette, Plinko) ────────────────────

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.gameId});
  final String gameId;

  @override
  Widget build(BuildContext context) {
    final g = gameById(gameId);
    final s = AppScope.of(context);
    final on = s.notifyAtLaunch.contains(g.id);
    return ZPage(
      gradient: const LinearGradient(colors: [Z.ink, Z.ink]),
      child: Panes(
        sideFraction: .46,
        maxSide: 520,
        side: Stack(fit: StackFit.expand, children: [
          ImageFiltered(
            imageFilter: blur2,
            child: Image.asset(g.image, fit: BoxFit.cover, alignment: Alignment.topCenter),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x330B0806), Color(0x590B0806), Z.ink],
                stops: [0, .6, 1],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x000B0806), Color(0x000B0806), Z.ink],
                stops: [0, .55, 1],
              ),
            ),
          ),
          const Positioned(left: 14, top: 10, child: BackBtn(label: 'Back to games')),
          Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
              child: AspectRatio(
                aspectRatio: 300 / 162,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Z.goldEdge, width: 2),
                    boxShadow: [bs(0, 14, 34, const Color(0xB3000000)), bs(0, 0, 24, const Color(0x59E2B04F))],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(g.image, fit: BoxFit.cover, semanticLabel: '${g.name} artwork'),
                ),
              ),
            ),
          ),
        ]),
        main: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 24, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: Z.goldBadge),
                  child: Text('COMING SOON', style: outfit(12, w: FontWeight.w800, ls: .12, c: Z.brown)),
                ),
                const SizedBox(height: 10),
                Text(g.name, style: outfit(26, w: FontWeight.w800, c: Z.cream, h: 1.1)),
                const SizedBox(height: 6),
                Text(g.category, style: outfit(13, w: FontWeight.w700, ls: .1, c: Z.label)),
                const SizedBox(height: 10),
                Text(g.blurb, style: outfit(15, c: Z.body, h: 1.5)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final t in g.tags)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Z.field,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Z.chipDark),
                      ),
                      child: Text(t, style: outfit(13, w: FontWeight.w600, c: Z.soft)),
                    ),
                ]),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 24, 14),
            child: Row(children: [
              Expanded(
                flex: 3,
                child: on
                    ? GreenButton("YOU'LL BE NOTIFIED",
                        height: 52,
                        fontSize: 15,
                        icon: const Ico(P.bell, size: 18, color: Color(0xFF062E14)),
                        onTap: () => s.toggleNotify(g.id))
                    : CtaButton('NOTIFY ME AT LAUNCH',
                        height: 52,
                        fontSize: 14,
                        ls: .02,
                        icon: const Ico(P.bell, size: 18, color: Z.ctaText),
                        onTap: () => s.toggleNotify(g.id)),
              ),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: GhostButton('Play Classic 777', fontSize: 14, onTap: () => Nav.replace(R.gold))),
            ]),
          ),
        ]),
      ),
    );
  }
}
