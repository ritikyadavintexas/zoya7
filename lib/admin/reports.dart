import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/assets.dart' show games;
import '../backoffice/casino.dart';
import 'admin_app.dart';
import 'kit.dart';
import 'players.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

enum _PlayerSort { net, coinIn, coinOut, ending }

class _ReportsPageState extends State<ReportsPage> {
  int period = 0;
  _PlayerSort sort = _PlayerSort.net;

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final periods = Period.standard(casino.now);
    final p = periods[period];
    final r = casino.report(p);
    final days = math.min(31, p.to.difference(p.from).inDays.clamp(1, 1 << 20));
    final series = casino.daily(math.max(days, 1));

    // Players with any movement in the period.
    final rows = r.players.values.where((x) => x.coinInSc > 0 || x.coinOutSc > 0 || x.wSc > 0 || (x.openSc - x.closeSc).abs() > .001).toList()
      ..sort((a, b) => switch (sort) {
            _PlayerSort.net => b.netSc.compareTo(a.netSc),
            _PlayerSort.coinIn => b.coinInSc.compareTo(a.coinInSc),
            _PlayerSort.coinOut => b.coinOutSc.compareTo(a.coinOutSc),
            _PlayerSort.ending => b.closeSc.compareTo(a.closeSc),
          });

    // Coins each staff member put on and took off accounts.
    final byStaff = <String, ({int ins, double inSc, int outs, double outSc})>{};
    bool inP(DateTime t) => !t.isBefore(p.from) && t.isBefore(p.to);
    for (final t in casino.txns) {
      if (!inP(t.at)) continue;
      final s = byStaff[t.by] ?? (ins: 0, inSc: 0.0, outs: 0, outSc: 0.0);
      if (t.type == TxnType.coinIn) {
        byStaff[t.by] = (ins: s.ins + 1, inSc: s.inSc + t.sc, outs: s.outs, outSc: s.outSc);
      } else if (t.type == TxnType.coinOut) {
        byStaff[t.by] = (ins: s.ins, inSc: s.inSc, outs: s.outs + 1, outSc: s.outSc - t.sc);
      }
    }

    return DeskPage(
      title: 'Reports',
      sub: '${p.label} · ${shortDate(p.from)}${days > 1 ? ' – ${shortDate(p.to.subtract(const Duration(days: 1)))}' : ''}',
      actions: [
        KButton('Copy CSV', tone: KTone.dark, icon: Icons.download_rounded, onTap: () => copy(context, casino.reportCsv(r), 'Report CSV')),
      ],
      children: [
        KSegment(values: List.generate(periods.length, (i) => i), selected: period, label: (i) => periods[i].label, onChanged: (i) => setState(() => period = i)),
        const SizedBox(height: 16),
        KGrid(min: 200, children: [
          KStat(label: 'Starting amount', value: '${grouped(r.openSc)} DC', sub: '${compact(r.openGc)} GC on player balances', icon: Icons.flag_outlined),
          KStat(label: 'Coin in', value: scAmt(r.coinInSc), sub: '${r.coinIns} times · ${compact(r.coinInGc)} GC', icon: Icons.south_west_rounded, color: K.greenInk),
          KStat(label: 'Coin out', value: scAmt(r.coinOutSc), sub: '${r.coinOuts} times · ${compact(r.coinOutGc)} GC', icon: Icons.north_east_rounded),
          KStat(label: 'Ending amount', value: '${grouped(r.closeSc)} DC', sub: '${compact(r.closeGc)} GC on player balances', icon: Icons.outlined_flag_rounded),
        ]),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, box) {
          final flow = KCard(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const KTitle('DC, start to end'),
              _line('Starting amount', r.openSc, bold: true),
              _line('+ Coin in', r.coinInSc),
              _line('+ Starting amounts of new IDs', r.startSc),
              _line('+ Bonuses', r.bonusSc),
              if (r.adjustSc != 0) _line('± Adjustments', r.adjustSc),
              _line('− Coin out', -r.coinOutSc),
              _line('− Played', -r.wageredSc),
              _line('+ Won', r.wonSc),
              const Divider(color: K.line, height: 18),
              _line('Ending amount', r.closeSc, bold: true),
            ]),
          );
          final money = KCard(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const KTitle('Coin in / out'),
              _line('Coin in', r.coinInSc),
              _line('− Coin out', -r.coinOutSc),
              const Divider(color: K.line, height: 18),
              _line('Net coin in', r.netSc, bold: true),
              const SizedBox(height: 10),
              _line('Hold on DC play', r.ggrSc),
              _line('Hold on GC play', r.wageredGc - r.wonGc, gc: true),
              const SizedBox(height: 14),
              KBarChart(days: series, height: 140),
            ]),
          );
          return box.maxWidth >= 900
              ? IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child: flow),
                    const SizedBox(width: 16),
                    Expanded(child: money),
                  ]),
                )
              : Column(children: [flow, const SizedBox(height: 16), money]);
        }),
        const SizedBox(height: 16),
        KCard(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: KTitle('Each game')),
            KTable(
              minWidth: 900,
              columns: const ['Game', 'Status', 'Rounds', 'Players', 'Played DC', 'Won DC', 'Hold DC', 'RTP actual', 'RTP set'],
              numeric: const {2, 3, 4, 5, 6, 7, 8},
              rows: [
                for (final g in games)
                  () {
                    final gr = r.games[g.id];
                    final c = casino.config(g.id);
                    return [
                      cellText(g.name, w: FontWeight.w600),
                      KBadge.game(c.status),
                      cellText('${gr?.rounds ?? 0}'),
                      cellText('${gr?.players.length ?? 0}'),
                      cellText(grouped(gr?.wSc ?? 0)),
                      cellText(grouped(gr?.winSc ?? 0)),
                      cellText(grouped(gr?.ggrSc ?? 0), w: FontWeight.w600, c: (gr?.ggrSc ?? 0) < 0 ? K.red : K.text),
                      cellText(gr?.actualRtp == null ? '—' : pct(gr!.actualRtp!, 1)),
                      cellText(pct(c.rtp, 1), c: K.sub),
                    ];
                  }(),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 16),
        KCard(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: KTitle('Each player',
                  trailing: KSegment(
                    values: _PlayerSort.values,
                    selected: sort,
                    label: (s) => switch (s) { _PlayerSort.net => 'Net', _PlayerSort.coinIn => 'Coin in', _PlayerSort.coinOut => 'Coin out', _PlayerSort.ending => 'Ending' },
                    onChanged: (s) => setState(() => sort = s),
                  )),
            ),
            if (rows.isEmpty) const KEmpty('No player activity in this period'),
            if (rows.isNotEmpty)
              KTable(
                minWidth: 900,
                columns: const ['Player', 'Starting DC', 'Coin in DC', 'Coin out DC', 'Net DC', 'Played DC', 'Won DC', 'Ending DC'],
                numeric: const {1, 2, 3, 4, 5, 6, 7},
                rows: [
                  for (final x in rows.take(100))
                    [
                      cellText(casino.player(x.playerId)?.username ?? x.playerId, w: FontWeight.w600),
                      cellText(grouped(x.openSc)),
                      cellText(grouped(x.coinInSc), c: K.greenInk),
                      cellText(grouped(x.coinOutSc)),
                      cellText(grouped(x.netSc), w: FontWeight.w600, c: x.netSc < 0 ? K.red : K.text),
                      cellText(grouped(x.wSc), c: K.sub),
                      cellText(grouped(x.winSc), c: K.sub),
                      cellText(grouped(x.closeSc), w: FontWeight.w600),
                    ],
                ],
                onTap: (i) {
                  final pl = casino.player(rows[i].playerId);
                  if (pl != null) openPlayer(context, pl);
                },
              ),
          ]),
        ),
        const SizedBox(height: 16),
        KCard(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: KTitle('By staff')),
            if (byStaff.isEmpty) const KEmpty('No coin in or out in this period'),
            if (byStaff.isNotEmpty)
              KTable(
                minWidth: 420,
                columns: const ['Who', 'Coin ins', 'Coin in DC', 'Coin outs', 'Coin out DC'],
                numeric: const {1, 2, 3, 4},
                rows: [
                  for (final e in byStaff.entries)
                    [
                      cellText(e.key, w: FontWeight.w600),
                      cellText('${e.value.ins}'),
                      cellText(grouped(e.value.inSc), c: K.greenInk),
                      cellText('${e.value.outs}'),
                      cellText(grouped(e.value.outSc)),
                    ],
                ],
              ),
          ]),
        ),
      ],
    );
  }

  Widget _line(String k, double v, {bool bold = false, bool gc = false}) {
    // The label carries the sign ("+ Won", "− Played").
    final shown = k.startsWith('+ ') || k.startsWith('− ') ? v.abs() : v;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(k, style: kt(15, w: bold ? FontWeight.w700 : FontWeight.w500, c: bold ? K.text : K.sub))),
        Text(gc ? gcAmt(shown) : scAmt(shown),
            style: kt(bold ? 17 : 15, w: bold ? FontWeight.w700 : FontWeight.w600, c: shown < -1e-9 ? K.red : K.text, num: true)),
      ]),
    );
  }
}
