import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/assets.dart' show GameInfo, games;
import '../app/site.dart';
import '../backoffice/casino.dart';
import '../backoffice/slot_math.dart';
import '../games/blackjack/engine.dart' show BjRules;
import '../games/gold/src/assets.dart' show GoldAssets;
import '../games/gold/src/math.dart';
import '../games/html/model.dart';
import 'admin_app.dart';
import 'kit.dart';
import 'upload.dart';

String _betStep(int i) => '${compact(GoldRules.bets[Currency.gc]![i])} GC / ${grouped(GoldRules.bets[Currency.sc]![i])} DC';

String betRange(GameConfig c) => switch (c.kind) {
      GameKind.goldSlot => 'Bets ${compact(GoldRules.bets[Currency.gc]![c.minIdx])}–${compact(GoldRules.bets[Currency.gc]![c.maxIdx])} GC · '
          '${grouped(GoldRules.bets[Currency.sc]![c.minIdx])}–${grouped(GoldRules.bets[Currency.sc]![c.maxIdx])} DC',
      GameKind.slot => 'Bet limits set at launch',
      _ => 'Bets ${compact(c.minGc)}–${compact(c.maxGc)} GC · ${grouped(c.minSc)}–${grouped(c.maxSc)} DC',
    };

/// Games: on, off (maintenance) or hidden; featured; ribbons; bet limits.
class GamesAdminPage extends StatelessWidget {
  const GamesAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    GameUpload.resume(casino);
    final owner = casino.admin?.role == StaffRole.owner;
    if (!K.desktop(context)) {
      return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        if (owner) ...[
          KButton('Upload a game', icon: Icons.upload_file_rounded, expand: true, onTap: () => showUploadGame(context)),
          const SizedBox(height: 14),
        ],
        const _MaintenanceCard(compact: true),
        const SizedBox(height: 14),
        KCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(children: [
            for (final g in games)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: gameImage(g.cardArt, width: 52, height: 52)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(g.name, style: kt(16, w: FontWeight.w600)),
                      Text(
                        '${casino.config(g.id).html?.live == false ? 'Publishing' : statusName(casino.config(g.id).status) == 'Maintenance' ? 'Off' : statusName(casino.config(g.id).status)} · RTP ${pct(casino.config(g.id).rtp, 1)}',
                        style: kt(13, c: K.sub),
                      ),
                    ]),
                  ),
                  KSwitch(
                    label: '${g.name} on',
                    value: casino.statusOf(g.id) == GameStatus.live,
                    onChanged: (on) => casino.setGameStatus(g.id, on ? GameStatus.live : GameStatus.maintenance),
                  ),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        Text('Off: players see the game but can’t open it. Hide games and change their math on the desktop panel.',
            style: kt(13, c: K.sub, h: 1.4)),
      ]);
    }
    return DeskPage(
      title: 'Games',
      sub: 'What players can open, what the lobby features, and the bets each table takes',
      actions: [
        if (owner) KButton('Upload a game', icon: Icons.upload_file_rounded, onTap: () => showUploadGame(context)),
      ],
      children: [
        const _MaintenanceCard(),
        const SizedBox(height: 16),
        KGrid(min: 300, gap: 16, max: 3, children: [for (final g in games) _GameCard(g)]),
      ],
    );
  }
}

class _MaintenanceCard extends StatefulWidget {
  const _MaintenanceCard({this.compact = false});
  final bool compact;

  @override
  State<_MaintenanceCard> createState() => _MaintenanceCardState();
}

class _MaintenanceCardState extends State<_MaintenanceCard> {
  late final TextEditingController msg;

  @override
  void initState() {
    super.initState();
    msg = TextEditingController(text: CasinoScope.read(context).settings.maintenanceMessage);
  }

  @override
  void dispose() {
    msg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final on = casino.settings.maintenance;
    return KCard(
      color: on ? K.amberSoft : K.card,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.construction_rounded, color: on ? K.amber : K.sub),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Maintenance mode', style: kt(16, w: FontWeight.w700)),
              Text(on ? 'Every game is closed to players' : 'Close every game at once', style: kt(13, c: K.sub)),
            ]),
          ),
          KSwitch(
            label: 'Maintenance mode',
            value: on,
            onChanged: (v) => casino.updateSettings(v ? 'maintenance on' : 'maintenance off', (s) => s.maintenance = v),
          ),
        ]),
        if (!widget.compact) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: KField(controller: msg, hint: 'Message players see')),
            const SizedBox(width: 10),
            KButton('Save message', tone: KTone.light, height: 44, onTap: () {
              casino.updateSettings('maintenance message', (s) => s.maintenanceMessage = msg.text.trim());
              kToast(context, 'Message saved');
            }),
          ]),
        ],
      ]),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard(this.g);
  final GameInfo g;

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final c = casino.config(g.id);
    final featured = casino.featured == g.id;
    return KCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 120,
          child: Stack(fit: StackFit.expand, children: [
            gameImage(g.cardArt, alignment: const Alignment(0, -.3)),
            Positioned(left: 12, top: 12, child: KBadge.game(c.status)),
            if (!g.playable) const Positioned(right: 12, top: 12, child: KBadge('Coming soon', fg: K.blue, bg: K.blueSoft)),
            if (c.html?.live == false)
              const Positioned(right: 12, top: 12, child: KBadge('Publishing · about 5 min', fg: K.amber, bg: K.amberSoft))
            else if (g.uploaded)
              Positioned(right: 12, top: 12, child: KBadge('Uploaded · v${c.html!.version}', fg: K.blue, bg: K.blueSoft)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(g.name, style: kt(18, w: FontWeight.w700))),
              Tooltip(
                message: featured ? 'Featured in the lobby' : 'Feature in the lobby',
                child: IconButton(
                  onPressed: featured ? null : () => casino.setFeatured(g.id),
                  icon: Icon(featured ? Icons.star_rounded : Icons.star_border_rounded, color: featured ? K.green : K.faint),
                ),
              ),
            ]),
            Text('RTP ${pct(c.rtp)} · ${betRange(c)}', maxLines: 2, style: kt(13, c: K.sub, h: 1.35)),
            const SizedBox(height: 12),
            KSegment<GameStatus>(
              values: GameStatus.values,
              selected: c.status,
              expand: true,
              label: (s) => switch (s) { GameStatus.live => 'Live', GameStatus.maintenance => 'Off', GameStatus.hidden => 'Hidden' },
              onChanged: (s) => casino.setGameStatus(g.id, s),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Text('Ribbon', style: kt(14, c: K.sub)),
              const SizedBox(width: 10),
              Expanded(
                child: KSegment<String>(
                  values: const ['', 'NEW', 'HOT'],
                  selected: c.badge,
                  expand: true,
                  label: (b) => b.isEmpty ? 'None' : b,
                  onChanged: (b) => casino.updateGame(g.id, 'ribbon ${b.isEmpty ? 'off' : b}', (x) => x.badge = b),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: KButton('Bet limits', tone: KTone.light, height: 40, onTap: c.kind == GameKind.slot ? null : () => showBetLimits(context, g))),
              const SizedBox(width: 8),
              Expanded(
                child: KButton('Math', tone: KTone.dark, height: 40, onTap: () {
                  MathPage.selected = g.id;
                  AdminNav.to(context, Section.math);
                }),
              ),
            ]),
            if (g.uploaded && casino.admin?.role == StaffRole.owner) ...[
              const SizedBox(height: 8),
              KButton('Remove game', tone: KTone.red, height: 40, expand: true, onTap: () => showRemoveGame(context, g)),
            ],
          ]),
        ),
      ]),
    );
  }
}

Future<void> showBetLimits(BuildContext context, GameInfo g) =>
    kSheet<void>(context, title: '${g.name} bet limits', builder: (_) => _BetLimits(g));

class _BetLimits extends StatefulWidget {
  const _BetLimits(this.g);
  final GameInfo g;

  @override
  State<_BetLimits> createState() => _BetLimitsState();
}

class _BetLimitsState extends State<_BetLimits> {
  late final casino = CasinoScope.read(context);
  late final c = casino.config(widget.g.id);
  late int minIdx = c.minIdx, maxIdx = c.maxIdx;
  late final minGc = TextEditingController(text: c.minGc.toStringAsFixed(0)), maxGc = TextEditingController(text: c.maxGc.toStringAsFixed(0));
  late final minSc = TextEditingController(text: c.minSc.toString()), maxSc = TextEditingController(text: c.maxSc.toString());

  @override
  void dispose() {
    for (final x in [minGc, maxGc, minSc, maxSc]) {
      x.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (c.kind == GameKind.goldSlot) {
      final steps = List.generate(GoldRules.bets[Currency.gc]!.length, (i) => i);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Players step through these bets. Pick the smallest and biggest offered.', style: kt(15, c: K.sub, h: 1.4)),
        const SizedBox(height: 14),
        for (final (label, value, set) in [
          ('Smallest bet', minIdx, (int i) => setState(() => minIdx = math.min(i, maxIdx))),
          ('Biggest bet', maxIdx, (int i) => setState(() => maxIdx = math.max(i, minIdx))),
        ]) ...[
          Text(label, style: kt(13, w: FontWeight.w600, c: K.sub)),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            initialValue: value,
            decoration: InputDecoration(filled: true, fillColor: K.field, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
            items: [for (final i in steps) DropdownMenuItem(value: i, child: Text(_betStep(i), style: kt(15)))],
            onChanged: (i) => set(i!),
          ),
          const SizedBox(height: 12),
        ],
        KButton('Save', expand: true, onTap: () {
          casino.updateGame(widget.g.id, 'bets ${_betStep(minIdx)} to ${_betStep(maxIdx)}', (x) => x
            ..minIdx = minIdx
            ..maxIdx = maxIdx);
          Navigator.of(context).pop();
          kToast(context, 'Bet limits saved');
        }),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: KField(label: 'Min bet GC', controller: minGc, keyboard: TextInputType.number, formatters: KField.money)),
        const SizedBox(width: 12),
        Expanded(child: KField(label: 'Max bet GC', controller: maxGc, keyboard: TextInputType.number, formatters: KField.money)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: KField(label: 'Min bet DC', controller: minSc, keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: KField.money)),
        const SizedBox(width: 12),
        Expanded(child: KField(label: 'Max bet DC', controller: maxSc, keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: KField.money)),
      ]),
      const SizedBox(height: 16),
      KButton('Save', expand: true, onTap: () {
        final v = [minGc, maxGc, minSc, maxSc].map((x) => amountOf(x.text)).toList();
        if (v.any((x) => x == null || x <= 0) || v[0]! > v[1]! || v[2]! > v[3]!) {
          kToast(context, 'Check the limits: each min must be above 0 and below its max');
          return;
        }
        casino.updateGame(widget.g.id, 'bet limits', (x) => x
          ..minGc = v[0]!
          ..maxGc = v[1]!
          ..minSc = v[2]!
          ..maxSc = v[3]!);
        Navigator.of(context).pop();
        kToast(context, 'Bet limits saved');
      }),
    ]);
  }
}

// ── Math ─────────────────────────────────────────────────────────────────────
/// Each game's math: RTP, odds and rules.
class MathPage extends StatefulWidget {
  const MathPage({super.key});

  /// Game to open on (set by a game card's "Math" button).
  static String selected = 'classic777';

  @override
  State<MathPage> createState() => _MathPageState();
}

class _MathPageState extends State<MathPage> {
  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final id = MathPage.selected;
    final g = games.firstWhere((x) => x.id == id, orElse: () => games.first);
    return DeskPage(
      title: 'Game math',
      sub: 'Return to player, odds and table rules. Changes apply the next time a game is opened.',
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final x in games)
            ChoiceChip(
              label: Text('${x.name} · ${pct(casino.config(x.id).rtp, 1)}',
                  style: kt(14, w: FontWeight.w600, c: x.id == id ? Colors.white : K.text)),
              selected: x.id == id,
              showCheckmark: false,
              selectedColor: K.ink,
              backgroundColor: K.card,
              side: const BorderSide(color: K.line),
              shape: const StadiumBorder(),
              onSelected: (_) => setState(() => MathPage.selected = x.id),
            ),
        ]),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: ValueKey(id),
          child: switch (casino.config(id).kind) {
            GameKind.goldSlot => _SlotMath(g),
            GameKind.blackjack => _BlackjackMath(g),
            GameKind.roulette => _RouletteMath(g),
            GameKind.plinko || GameKind.slot => _TargetMath(g),
            GameKind.html => _HtmlMath(g),
          },
        ),
      ],
    );
  }
}

String oneIn(double p) => p <= 0 ? 'never' : '1 in ${grouped(1 / p, 0)}';

class _SlotMath extends StatefulWidget {
  const _SlotMath(this.g);
  final GameInfo g;

  @override
  State<_SlotMath> createState() => _SlotMathState();
}

class _SlotMathState extends State<_SlotMath> {
  late final casino = CasinoScope.read(context);
  late Map<Sym, double> w = Map.of(casino.config(widget.g.id).weights ?? LocalGoldMath.defaultWeights);
  late double target = (SlotMath(w).rtp * 200).roundToDouble() / 200;
  String? sim;

  bool get dirty {
    final saved = casino.config(widget.g.id).weights ?? LocalGoldMath.defaultWeights;
    return Sym.values.any((s) => saved[s] != w[s]);
  }

  void _simulate() {
    final m = LocalGoldMath(weights: w, random: math.Random());
    const n = 100000;
    final none = {for (final t in JackpotTier.values) t: 0.0};
    var paid = 0.0, hits = 0;
    for (var i = 0; i < n; i++) {
      final grid = [
        for (var r = 0; r < 3; r++) [m.fillerSymbol(), m.fillerSymbol(), m.fillerSymbol()],
      ];
      final o = GoldRules.evaluate(grid, 1, none);
      paid += o.win;
      if (o.win > 0 || o.jackpot != null) hits++;
    }
    setState(() => sim = 'Simulated ${grouped(n.toDouble(), 0)} spins: paid back ${pct(paid / n)} · hit ${pct(hits / n, 1)} of spins');
  }

  @override
  Widget build(BuildContext context) {
    final m = SlotMath(w);
    final total = w.values.fold<double>(0, (a, b) => a + b);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KGrid(min: 200, children: [
        KStat(label: 'Return to player', value: pct(m.rtp), sub: 'Line pays; jackpots extra', color: K.greenInk),
        KStat(label: 'House edge', value: pct(1 - m.rtp), sub: 'Kept per 100 DC played: ${grouped(100 * (1 - m.rtp))}'),
        KStat(label: 'Hit rate', value: pct(m.hitRate, 1), sub: '${oneIn(m.hitRate)} spins pays'),
        KStat(label: 'MEGA jackpot', value: oneIn(m.jackpotChance(JackpotTier.mega)), sub: 'MAJOR ${oneIn(m.jackpotChance(JackpotTier.major))}'),
      ]),
      const SizedBox(height: 16),
      KCard(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const KTitle('Set the RTP'),
          Text('Pick a target and the reels are re-weighted to hit it. The paytable players see stays the same.',
              style: kt(14, c: K.sub, h: 1.4)),
          Row(children: [
            Expanded(
              child: Slider(
                value: target.clamp(.5, .99),
                min: .5,
                max: .99,
                divisions: 98,
                activeColor: K.green,
                label: pct(target, 1),
                onChanged: (v) => setState(() => target = v),
              ),
            ),
            SizedBox(width: 70, child: Text(pct(target, 1), textAlign: TextAlign.right, style: kt(18, w: FontWeight.w700, num: true))),
            const SizedBox(width: 12),
            KButton('Re-weight reels', tone: KTone.dark, height: 42, onTap: () => setState(() {
                  w = SlotMath.solve(target);
                  sim = null;
                })),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      KCard(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: KTitle('Reel stops (each of the 3 reels)', trailing: Text('${grouped(total, 0)} stops', style: kt(14, c: K.sub))),
          ),
          KTable(
            minWidth: 820,
            columns: const ['Symbol', 'Pays (× bet)', 'Stops', 'Chance per reel', 'Three in a row', 'Share of RTP'],
            numeric: const {1, 3, 4, 5},
            rows: [
              for (final s in Sym.values)
                [
                  Row(children: [
                    Image.asset(GoldAssets.symbol(s), width: 28, height: 28),
                    const SizedBox(width: 8),
                    cellText(s.name[0].toUpperCase() + s.name.substring(1), w: FontWeight.w600),
                  ]),
                  cellText(GoldRules.jackpotSymbols.containsKey(s)
                      ? '${GoldRules.jackpotSymbols[s]!.name.toUpperCase()} jackpot'
                      : '${GoldRules.linePays[s]}×${s == Sym.cherry ? ' (2 = ${GoldRules.twoCherryPay}×)' : ''}'),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _step(Icons.remove_rounded, 'Fewer ${s.name}', () => setState(() => w[s] = math.max(1, w[s]! - (w[s]! > 20 ? 5 : 1)))),
                    SizedBox(width: 40, child: Text(grouped(w[s]!, 0), textAlign: TextAlign.center, style: kt(15, w: FontWeight.w700, num: true))),
                    _step(Icons.add_rounded, 'More ${s.name}', () => setState(() => w[s] = w[s]! + (w[s]! >= 20 ? 5 : 1))),
                  ]),
                  cellText(pct(m.p(s))),
                  cellText(oneIn(math.pow(m.p(s), 3).toDouble()), c: K.sub),
                  cellText(GoldRules.linePays.containsKey(s) ? pct(m.breakdown['3 × ${s.name}']!) : '—', c: K.sub),
                ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Text('Any two cherries add ${pct(m.breakdown['2 × cherry']!)} to the RTP.', style: kt(13, c: K.sub)),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        KButton(dirty ? 'Save — RTP ${pct(m.rtp)}' : 'Saved', icon: Icons.check_rounded, onTap: dirty
            ? () {
                casino.updateGame(widget.g.id, 'RTP set to ${pct(m.rtp)}', (c) => c.weights = Map.of(w));
                kToast(context, '${widget.g.name} now returns ${pct(m.rtp)}');
                setState(() {});
              }
            : null),
        KButton('Simulate 100,000 spins', tone: KTone.light, icon: Icons.play_arrow_rounded, onTap: _simulate),
        KButton('Undo changes', tone: KTone.ghost, onTap: dirty
            ? () => setState(() {
                  w = Map.of(casino.config(widget.g.id).weights ?? LocalGoldMath.defaultWeights);
                  sim = null;
                })
            : null),
      ]),
      if (sim != null) ...[
        const SizedBox(height: 12),
        KCard(color: K.greenSoft, padding: const EdgeInsets.all(14), child: Text(sim!, style: kt(15, w: FontWeight.w600, c: K.greenInk))),
      ],
    ]);
  }

  Widget _step(IconData i, String tip, VoidCallback onTap) => KIconButton(i, tooltip: tip, size: 30, onTap: onTap);
}

class _BlackjackMath extends StatefulWidget {
  const _BlackjackMath(this.g);
  final GameInfo g;

  @override
  State<_BlackjackMath> createState() => _BlackjackMathState();
}

class _BlackjackMathState extends State<_BlackjackMath> {
  late final casino = CasinoScope.read(context);
  late BjRules r = casino.config('blackjack').bj;

  @override
  Widget build(BuildContext context) {
    final saved = casino.config('blackjack').bj;
    final dirty = r.toJson().toString() != saved.toJson().toString();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KGrid(min: 220, children: [
        KStat(label: 'Return to player', value: pct(1 - r.houseEdge), sub: 'Basic-strategy play', color: K.greenInk),
        KStat(label: 'House edge', value: pct(r.houseEdge), sub: 'Kept per 100 DC bet: ${grouped(100 * r.houseEdge)}'),
        KStat(label: 'Blackjack pays', value: r.blackjackPays == 1.5 ? '3 to 2' : r.blackjackPays == 1.2 ? '6 to 5' : '1 to 1', sub: 'Insurance pays 2 to 1'),
      ]),
      const SizedBox(height: 16),
      KCard(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const KTitle('Table rules'),
          KRow(
            title: 'Decks in the shoe',
            sub: 'Fewer decks favour the player',
            trailing: KSegment<int>(values: const [1, 2, 4, 6, 8], selected: r.decks, label: (d) => '$d', onChanged: (d) => setState(() => r = r.copyWith(decks: d))),
          ),
          KRow(
            title: 'Blackjack pays',
            sub: '6 to 5 costs players about 1.4%',
            trailing: KSegment<double>(
              values: const [1.5, 1.2, 1.0],
              selected: r.blackjackPays,
              label: (v) => v == 1.5 ? '3:2' : v == 1.2 ? '6:5' : '1:1',
              onChanged: (v) => setState(() => r = r.copyWith(blackjackPays: v)),
            ),
          ),
          KRow(title: 'Dealer hits soft 17', sub: 'Adds about 0.2% to the house edge', trailing: KSwitch(label: 'Dealer hits soft 17', value: r.hitSoft17, onChanged: (v) => setState(() => r = r.copyWith(hitSoft17: v)))),
          KRow(title: 'Double after split', trailing: KSwitch(label: 'Double after split', value: r.doubleAfterSplit, onChanged: (v) => setState(() => r = r.copyWith(doubleAfterSplit: v)))),
          KRow(
            title: 'Split up to',
            trailing: KSegment<int>(values: const [1, 2, 3, 4], selected: r.maxHands, label: (h) => h == 1 ? 'No split' : '$h hands', onChanged: (h) => setState(() => r = r.copyWith(maxHands: h))),
          ),
          KRow(title: 'Offer insurance', trailing: KSwitch(label: 'Offer insurance', value: r.insurance, onChanged: (v) => setState(() => r = r.copyWith(insurance: v)))),
        ]),
      ),
      const SizedBox(height: 16),
      Wrap(spacing: 10, children: [
        KButton(dirty ? 'Save rules' : 'Saved', icon: Icons.check_rounded, onTap: dirty
            ? () {
                casino.updateGame('blackjack', 'rules (house edge ${pct(r.houseEdge)})', (c) => c.bj = r);
                kToast(context, 'Blackjack rules saved');
                setState(() {});
              }
            : null),
        KButton('Standard rules', tone: KTone.light, onTap: () => setState(() => r = const BjRules())),
      ]),
    ]);
  }
}

class _RouletteMath extends StatelessWidget {
  const _RouletteMath(this.g);
  final GameInfo g;

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final c = casino.config(g.id);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KGrid(min: 220, children: [
        KStat(label: 'Return to player', value: pct(c.rtp), color: K.greenInk),
        KStat(label: 'House edge', value: pct(c.houseEdge), sub: 'Same on every bet'),
        KStat(label: 'Straight up pays', value: '35 to 1', sub: c.wheel == 'american' ? '38 pockets' : '37 pockets'),
      ]),
      const SizedBox(height: 16),
      KCard(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const KTitle('Wheel'),
          KRow(
            title: 'Wheel type',
            sub: 'European has one zero; American adds a double zero',
            trailing: KSegment<String>(
              values: const ['european', 'american'],
              selected: c.wheel,
              label: (w) => w == 'european' ? 'European' : 'American',
              onChanged: (w) => casino.updateGame(g.id, '$w wheel', (x) => x.wheel = w),
            ),
          ),
          if (!g.playable) Text('Roulette isn’t live yet — these settings apply when it launches.', style: kt(13, c: K.sub)),
        ]),
      ),
    ]);
  }
}

/// Games whose math is a target RTP (Plinko, and slots still in development).
class _TargetMath extends StatefulWidget {
  const _TargetMath(this.g);
  final GameInfo g;

  @override
  State<_TargetMath> createState() => _TargetMathState();
}

class _TargetMathState extends State<_TargetMath> {
  late final casino = CasinoScope.read(context);
  late double rtp = casino.config(widget.g.id).targetRtp;

  @override
  Widget build(BuildContext context) {
    final c = CasinoScope.of(context).config(widget.g.id);
    final plinko = c.kind == GameKind.plinko;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KGrid(min: 220, children: [
        KStat(label: 'Return to player', value: pct(rtp), color: K.greenInk),
        KStat(label: 'House edge', value: pct(1 - rtp)),
        if (plinko) KStat(label: 'Risk', value: c.risk[0].toUpperCase() + c.risk.substring(1), sub: 'Spread of the multipliers'),
      ]),
      const SizedBox(height: 16),
      KCard(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const KTitle('Target RTP'),
          Row(children: [
            Expanded(
              child: Slider(
                value: rtp,
                min: .8,
                max: .99,
                divisions: 38,
                activeColor: K.green,
                label: pct(rtp, 1),
                onChanged: (v) => setState(() => rtp = v),
              ),
            ),
            SizedBox(width: 70, child: Text(pct(rtp, 1), textAlign: TextAlign.right, style: kt(18, w: FontWeight.w700, num: true))),
          ]),
          if (plinko)
            KRow(
              title: 'Risk level',
              sub: 'Higher risk: bigger edge multipliers, more low ones',
              trailing: KSegment<String>(
                values: const ['low', 'medium', 'high'],
                selected: c.risk,
                label: (r) => r[0].toUpperCase() + r.substring(1),
                onChanged: (r) => casino.updateGame(widget.g.id, 'risk $r', (x) => x.risk = r),
              ),
            ),
          const SizedBox(height: 6),
          Text('${widget.g.name} isn’t live yet — its math will be built to this RTP.', style: kt(13, c: K.sub)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: KButton('Save', icon: Icons.check_rounded, onTap: (rtp - c.targetRtp).abs() < 1e-9
                ? null
                : () {
                    casino.updateGame(widget.g.id, 'target RTP ${pct(rtp)}', (x) => x.targetRtp = rtp);
                    kToast(context, 'Saved');
                  }),
          ),
        ]),
      ),
    ]);
  }
}

/// An uploaded game: its pay tables (the game's own multipliers) and the
/// chances the payout rule gives them at the chosen RTP ([chancesFor]).
class _HtmlMath extends StatefulWidget {
  const _HtmlMath(this.g);
  final GameInfo g;

  @override
  State<_HtmlMath> createState() => _HtmlMathState();
}

class _HtmlMathState extends State<_HtmlMath> {
  late final casino = CasinoScope.read(context);
  late double rtp = casino.config(widget.g.id).targetRtp;

  /// The highest RTP every one of the game's pay tables can reach (at most 99%).
  double _ceiling(HtmlGame h) {
    var top = .99;
    while (top > .8 && h.options.any((o) => chancesFor(o.outcomes, top) == null)) {
      top = ((top - .005) * 1000).roundToDouble() / 1000;
    }
    return top;
  }

  @override
  Widget build(BuildContext context) {
    final c = CasinoScope.of(context).config(widget.g.id);
    final h = c.html!;
    final top = _ceiling(h);
    final shown = rtp.clamp(.8, top);
    final main = h.options.first;
    final p = chancesFor(main.outcomes, shown)!;
    final hit = [for (var i = 0; i < p.length; i++) if (main.outcomes[i].wins) p[i]].fold<double>(0, (a, b) => a + b);
    final best = main.outcomes.map((o) => o.multiplier).reduce(math.max);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KGrid(min: 200, children: [
        KStat(label: 'Return to player', value: pct(shown, 1), color: K.greenInk),
        KStat(label: 'House edge', value: pct(1 - shown, 1)),
        KStat(label: 'Rounds that win', value: pct(hit, 1), sub: main.label.isEmpty ? main.id : main.label),
        KStat(label: 'Top win', value: '${grouped(best, best % 1 == 0 ? 0 : 2)}×', sub: oneIn(p[main.outcomes.indexWhere((o) => o.multiplier == best)])),
      ]),
      const SizedBox(height: 16),
      KCard(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const KTitle('Return to player'),
          Row(children: [
            Expanded(
              child: Slider(
                value: shown,
                min: .8,
                max: top,
                divisions: math.max(1, ((top - .8) / .005).round()),
                activeColor: K.green,
                label: pct(shown, 1),
                onChanged: (v) => setState(() => rtp = (v * 1000).roundToDouble() / 1000),
              ),
            ),
            SizedBox(width: 70, child: Text(pct(shown, 1), textAlign: TextAlign.right, style: kt(18, w: FontWeight.w700, num: true))),
          ]),
          Text(
              'The game sets what each result pays; Zoya7 sets how often, so the game pays back exactly this. '
              'Every win gets its share of the payback (the game can weight them), and the rest of the time the round is a no-win. '
              '${top < .99 ? 'These pays can reach at most ${pct(top, 1)}.' : ''}',
              style: kt(13, c: K.sub, h: 1.4)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: KButton('Save', icon: Icons.check_rounded, onTap: (shown - c.targetRtp).abs() < 1e-9
                ? null
                : () {
                    casino.updateGame(widget.g.id, 'RTP ${pct(shown, 1)}', (x) => x.targetRtp = shown);
                    kToast(context, 'Saved');
                  }),
          ),
        ]),
      ),
      for (final o in h.options) ...[
        const SizedBox(height: 16),
        KCard(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KTitle(h.options.length == 1 ? 'Pay table' : 'Pay table · ${o.label.isEmpty ? o.id : o.label}'),
            Builder(builder: (context) {
              final q = chancesFor(o.outcomes, shown)!;
              return KTable(
                minWidth: 640,
                columns: const ['Result', 'Pays (× bet)', 'Chance', 'How often', 'Share of RTP'],
                numeric: const {1, 2, 3, 4},
                rows: [
                  for (final (i, x) in o.outcomes.indexed)
                    [
                      cellText(x.label.isEmpty ? x.id : x.label, w: FontWeight.w600),
                      cellText(x.wins ? '${grouped(x.multiplier, x.multiplier % 1 == 0 ? 0 : 2)}×' : 'No win'),
                      cellText(pct(q[i], 2)),
                      cellText(oneIn(q[i]), c: K.sub),
                      cellText(x.wins ? pct(q[i] * x.multiplier / shown, 1) : '—', c: K.sub),
                    ],
                ],
              );
            }),
          ]),
        ),
      ],
    ]);
  }
}
