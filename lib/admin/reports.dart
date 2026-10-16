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

enum _PlayerSort { net, cashIn, cashOut, ending }

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
    final rows = r.players.values.where((x) => x.cashInUsd > 0 || x.cashOutUsd > 0 || x.wSc > 0 || (x.openSc - x.closeSc).abs() > .001).toList()
      ..sort((a, b) => switch (sort) {
            _PlayerSort.net => b.netCash.compareTo(a.netCash),
            _PlayerSort.cashIn => b.cashInUsd.compareTo(a.cashInUsd),
            _PlayerSort.cashOut => b.cashOutUsd.compareTo(a.cashOutUsd),
            _PlayerSort.ending => b.closeSc.compareTo(a.closeSc),
          });

    // Cash handled by each staff member.
    final byStaff = <String, ({int ins, double inUsd, int outs, double outUsd})>{};
    bool inP(DateTime? t) => t != null && !t.isBefore(p.from) && t.isBefore(p.to);
    for (final t in casino.txns) {
      if (t.type == TxnType.cashIn && inP(t.at)) {
        final s = byStaff[t.by] ?? (ins: 0, inUsd: 0.0, outs: 0, outUsd: 0.0);
        byStaff[t.by] = (ins: s.ins + 1, inUsd: s.inUsd + t.usd, outs: s.outs, outUsd: s.outUsd);
      } else if (t.type == TxnType.cashOut && t.status == TxnStatus.approved && inP(t.settledAt ?? t.at)) {
        final who = t.settledBy ?? t.by;
        final s = byStaff[who] ?? (ins: 0, inUsd: 0.0, outs: 0, outUsd: 0.0);
        byStaff[who] = (ins: s.ins, inUsd: s.inUsd, outs: s.outs + 1, outUsd: s.outUsd + t.usd);
      }
    }
    final shifts = casino.shifts.where((s) => inP(s.start)).toList().reversed.toList();

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
          KStat(label: 'Starting amount', value: '${grouped(r.openSc)} SC', sub: '${compact(r.openGc)} GC on player balances', icon: Icons.flag_outlined),
          KStat(label: 'Cash in', value: usd(r.cashInUsd), sub: '${r.cashIns} payments${r.cashIns == 0 ? '' : ' · avg ${usd(r.cashInUsd / r.cashIns)}'}', icon: Icons.south_west_rounded, color: K.greenInk),
          KStat(label: 'Cash out', value: usd(r.cashOutUsd), sub: '${r.cashOuts} paid · ${usd(r.pendingUsd)} pending', icon: Icons.north_east_rounded),
          KStat(label: 'Ending amount', value: '${grouped(r.closeSc)} SC', sub: '${compact(r.closeGc)} GC on player balances', icon: Icons.outlined_flag_rounded),
        ]),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, box) {
          final flow = KCard(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const KTitle('Sweeps Coins, start to end'),
              _line('Starting amount', r.openSc, bold: true),
              _line('+ Bought with cash in', r.cashInSc),
              _line('+ Starting amounts of new IDs', r.startSc),
              _line('+ Bonuses', r.bonusSc),
              if (r.adjustSc != 0) _line('± Adjustments', r.adjustSc),
              _line('− Cashed out', -r.cashOutSc),
              _line('− Played', -r.wageredSc),
              _line('+ Won', r.wonSc),
              const Divider(color: K.line, height: 18),
              _line('Ending amount', r.closeSc, bold: true),
            ]),
          );
          final money = KCard(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const KTitle('Money'),
              _line('Cash in', r.cashInUsd, money: true),
              _line('Cash out (paid)', -r.cashOutUsd, money: true),
              const Divider(color: K.line, height: 18),
              _line('Net cash', r.netCash, money: true, bold: true),
              const SizedBox(height: 10),
              _line('Pending cash outs', r.pendingUsd, money: true),
              _line('Hold on SC play', r.ggrSc),
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
              columns: const ['Game', 'Status', 'Rounds', 'Players', 'Played SC', 'Won SC', 'Hold SC', 'RTP actual', 'RTP set'],
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
                    label: (s) => switch (s) { _PlayerSort.net => 'Net', _PlayerSort.cashIn => 'Cash in', _PlayerSort.cashOut => 'Cash out', _PlayerSort.ending => 'Ending' },
                    onChanged: (s) => setState(() => sort = s),
                  )),
            ),
            if (rows.isEmpty) const KEmpty('No player activity in this period'),
            if (rows.isNotEmpty)
              KTable(
                minWidth: 900,
                columns: const ['Player', 'Starting SC', 'Cash in', 'Cash out', 'Net cash', 'Played SC', 'Won SC', 'Ending SC'],
                numeric: const {1, 2, 3, 4, 5, 6, 7},
                rows: [
                  for (final x in rows.take(100))
                    [
                      cellText(casino.player(x.playerId)?.username ?? x.playerId, w: FontWeight.w600),
                      cellText(grouped(x.openSc)),
                      cellText(usd(x.cashInUsd), c: K.greenInk),
                      cellText(usd(x.cashOutUsd)),
                      cellText(usd(x.netCash), w: FontWeight.w600, c: x.netCash < 0 ? K.red : K.text),
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
        LayoutBuilder(builder: (context, box) {
          final staff = KCard(
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: KTitle('By staff')),
              if (byStaff.isEmpty) const KEmpty('No cash handled in this period'),
              if (byStaff.isNotEmpty)
                KTable(
                  minWidth: 420,
                  columns: const ['Who', 'Cash ins', 'Cash in', 'Payouts', 'Cash out'],
                  numeric: const {1, 2, 3, 4},
                  rows: [
                    for (final e in byStaff.entries)
                      [
                        cellText(e.key, w: FontWeight.w600),
                        cellText('${e.value.ins}'),
                        cellText(usd(e.value.inUsd), c: K.greenInk),
                        cellText('${e.value.outs}'),
                        cellText(usd(e.value.outUsd)),
                      ],
                  ],
                ),
            ]),
          );
          final drawer = KCard(
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: KTitle('Drawer shifts')),
              if (shifts.isEmpty) const KEmpty('No shifts in this period'),
              if (shifts.isNotEmpty)
                KTable(
                  minWidth: 460,
                  columns: const ['Who', 'Started', 'Starting', 'Expected', 'Counted'],
                  numeric: const {2, 3, 4},
                  rows: [
                    for (final s in shifts)
                      () {
                        final sum = casino.summary(s);
                        final d = sum.difference;
                        return [
                          cellText(s.staff, w: FontWeight.w600),
                          cellText(when(s.start, casino.now), c: K.sub, size: 13),
                          cellText(usd(s.startAmount)),
                          cellText(usd(sum.expected)),
                          s.open
                              ? const KBadge('Open')
                              : cellText('${usd(s.counted!)}${d!.abs() < .005 ? '' : d > 0 ? ' (+${usd(d)})' : ' (−${usd(-d)})'}',
                                  c: d.abs() < .005 ? K.text : K.red),
                        ];
                      }(),
                  ],
                ),
            ]),
          );
          return box.maxWidth >= 1000
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: staff),
                  const SizedBox(width: 16),
                  Expanded(child: drawer),
                ])
              : Column(children: [staff, const SizedBox(height: 16), drawer]);
        }),
      ],
    );
  }

  Widget _line(String k, double v, {bool bold = false, bool money = false, bool gc = false}) {
    // The label carries the sign ("+ Won", "− Played").
    final shown = k.startsWith('+ ') || k.startsWith('− ') ? v.abs() : v;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(k, style: kt(15, w: bold ? FontWeight.w700 : FontWeight.w500, c: bold ? K.text : K.sub))),
        Text(money ? usd(shown) : gc ? gcAmt(shown) : scAmt(shown),
            style: kt(bold ? 17 : 15, w: bold ? FontWeight.w700 : FontWeight.w600, c: shown < -1e-9 ? K.red : K.text, num: true)),
      ]),
    );
  }
}
