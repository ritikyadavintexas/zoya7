import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../assets.dart';
import '../icons.dart';
import '../nav.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'lobby.dart' show openGame;

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
    final list = games.where((g) {
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
            side: PaneList(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 16),
              children: [
                _Featured(onTap: () => Nav.push(R.gold)),
                const SizedBox(height: 12),
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in cats)
                    Press(
                      selected: c == cat,
                      onTap: () => setState(() => cat = c),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: c == cat ? Z.goldTab : null,
                          color: c == cat ? null : Z.field,
                          border: c == cat ? null : Border.all(color: Z.chip, width: 1.5),
                        ),
                        child: Center(
                          widthFactor: 1,
                          child: Text(c,
                              style: outfit(14, w: FontWeight.w700, ls: .03, c: c == cat ? Z.brown : Z.soft)),
                        ),
                      ),
                    ),
                ]),
              ],
            ),
            main: LayoutBuilder(builder: (context, box) {
              const cols = 3, gap = 10.0, pad = EdgeInsets.fromLTRB(8, 12, 14, 16);
              final tileW = (box.maxWidth - pad.horizontal - gap * (cols - 1)) / cols;
              return PaneList(
                padding: pad,
                children: [
                  SectionTitle(
                    cat == 'All' ? 'ALL GAMES' : cat.toUpperCase(),
                    trailing: Text('${list.length} ${list.length == 1 ? 'game' : 'games'}',
                        style: outfit(13, c: Z.muted)),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: gap,
                      crossAxisSpacing: gap,
                      mainAxisExtent: tileW * 96 / 179 + 6 + 18,
                    ),
                    itemBuilder: (_, i) => _GameTile(list[i], imageHeight: tileW * 96 / 179),
                  ),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text('No games match “$query”.',
                          textAlign: TextAlign.center, style: outfit(15, c: Z.muted)),
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

class _Featured extends StatelessWidget {
  const _Featured({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Press(
        label: 'Featured: Classic 777 — play now',
        onTap: onTap,
        child: Container(
          height: 160,
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
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: Z.goldBadge),
                  child: Text('FEATURED', style: outfit(11, w: FontWeight.w800, ls: .08, c: Z.brown, h: 1)),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Classic 777',
                      style: outfit(26, w: FontWeight.w800, c: Z.cream, h: 1.05, sh: [ts(0, 2, 8, const Color(0xCC000000))])),
                  const SizedBox(height: 2),
                  Text('MEGA jackpot over 1.2M GC', style: outfit(13, c: Z.soft)),
                ]),
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
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
          ]),
        ),
      );
}

class _GameTile extends StatelessWidget {
  const _GameTile(this.g, {required this.imageHeight});
  final GameInfo g;
  final double imageHeight;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Press(
          label: '${g.name} — ${g.playable ? 'play' : 'coming soon'}',
          onTap: () => openGame(g),
          child: Stack(children: [
            g.playable
                ? RoundImage(g.image, height: imageHeight)
                : ColorFiltered(
                    colorFilter: ColorFilter.matrix(saturateBrightness(.8, .85)),
                    child: RoundImage(g.image, height: imageHeight, borderColor: Z.chip),
                  ),
            if (!g.playable)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xD90A0603),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Z.border),
                  ),
                  child: Text('SOON', style: outfit(10, w: FontWeight.w700, ls: .06, c: Z.gold, h: 1)),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(children: [
            Text(g.cat, style: outfit(12, w: FontWeight.w600, ls: .04, c: Z.muted)),
            const SizedBox(width: 6),
            Expanded(
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (g.playable) ...[
                  Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: Z.green)),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(g.playable ? '${g.players} playing' : 'Coming soon',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: outfit(12, c: Z.muted)),
                ),
              ]),
            ),
          ]),
        ),
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
              padding: const EdgeInsets.fromLTRB(20, 18, 24, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: Z.goldBadge),
                  child: Text('COMING SOON', style: outfit(12, w: FontWeight.w800, ls: .12, c: Z.brown)),
                ),
                const SizedBox(height: 10),
                Text(g.name, style: outfit(30, w: FontWeight.w800, c: Z.cream, h: 1.1)),
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
