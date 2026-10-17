import 'package:flutter/material.dart';

import '../app/assets.dart' show games;
import '../app/site.dart';
import '../backoffice/casino.dart';
import 'admin_app.dart';
import 'coins.dart';
import 'kit.dart';
import 'players.dart';
import 'setup.dart';
import 'team.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int period = 0; // Today, 7 days, 30 days

  @override
  Widget build(BuildContext context) {
    if (!CasinoScope.of(context).admin!.isOwner) return const _NetworkHome();
    return K.desktop(context) ? _desktop(context) : _phone(context);
  }

  Widget _desktop(BuildContext context) {
    final casino = CasinoScope.of(context);
    final now = casino.now;
    final periods = Period.standard(now);
    final p = [periods[0], periods[2], periods[3]][period];
    final r = casino.report(p);
    final greeting = now.hour < 12 ? 'Good morning' : now.hour < 18 ? 'Good afternoon' : 'Good evening';
    final manage = casino.admin!.canManage;
    return DeskPage(
      title: '$greeting, ${casino.admin!.name}',
      sub: '${const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][now.weekday - 1]}, ${shortDate(now)}',
      actions: [
        KSegment(values: const [0, 1, 2], selected: period, label: (i) => const ['Today', '7 days', '30 days'][i], onChanged: (i) => setState(() => period = i)),
        KButton('New player ID', tone: KTone.light, icon: Icons.person_add_alt_1_rounded, onTap: () => showCreatePlayer(context)),
        KButton('Coin in', icon: Icons.south_west_rounded, onTap: () => showCoinIn(context)),
      ],
      children: [
        const RequestsCard(),
        KGrid(min: 200, children: [
          KStat(label: 'Coin in', value: scAmt(r.coinInSc), sub: '${r.coinIns} times · ${compact(r.coinInGc)} GC', icon: Icons.south_west_rounded, color: K.greenInk),
          KStat(label: 'Coin out', value: scAmt(r.coinOutSc), sub: '${r.coinOuts} times · ${compact(r.coinOutGc)} GC', icon: Icons.north_east_rounded),
          KStat(label: 'Net coin in', value: scAmt(r.netSc), sub: 'Coin in − coin out', icon: Icons.account_balance_wallet_outlined, color: r.netSc < 0 ? K.red : K.text),
          KStat(
            label: 'Player balances',
            value: scAmt(r.closeSc),
            sub: '${compact(r.closeGc)} GC · all players',
            icon: Icons.toll_rounded,
            onTap: () => AdminNav.to(context, Section.coins),
          ),
          KStat(label: 'Players who played', value: '${r.active.length}', sub: '${r.rounds} rounds', icon: Icons.sports_esports_outlined),
          KStat(label: 'New player IDs', value: '${r.newPlayers}', sub: '${casino.players.length} in total', icon: Icons.person_add_alt_outlined),
          KStat(label: 'Hold (DC)', value: grouped(r.ggrSc), sub: 'Played ${compact(r.wageredSc)} · won ${compact(r.wonSc)}', icon: Icons.casino_outlined),
          KStat(label: 'Online now', value: '${casino.online}', sub: 'Seen in the last 15 min', icon: Icons.wifi_tethering_rounded),
        ]),
        const SizedBox(height: 16),
        KCard(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            KTitle('Coin in vs coin out (DC) · last 14 days', trailing: manage ? KButton('Reports', tone: KTone.ghost, height: 32, onTap: () => AdminNav.to(context, Section.reports)) : null),
            KBarChart(days: casino.daily(14), height: 200),
          ]),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, box) {
          final gamesCard = KCard(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              KTitle('Games', trailing: manage ? KButton('Manage', tone: KTone.ghost, height: 32, onTap: () => AdminNav.to(context, Section.games)) : null),
              for (final g in games) _GameLine(g.id, r.games[g.id], canToggle: manage),
            ]),
          );
          final recent = KCard(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const KTitle('Latest activity'),
              for (final t in casino.txns.reversed.take(7)) TxnTile(t),
            ]),
          );
          return box.maxWidth >= 980
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: gamesCard),
                  const SizedBox(width: 16),
                  Expanded(child: recent),
                ])
              : Column(children: [gamesCard, const SizedBox(height: 16), recent]);
        }),
      ],
    );
  }

  Widget _phone(BuildContext context) {
    final casino = CasinoScope.of(context);
    final r = casino.report(Period.standard(casino.now).first);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
      const InstallCard(),
      const RequestsCard(),
      // Cash App's balance: one big number (in coins).
      KCard(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Net coin in today', style: kt(15, c: K.sub)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(scAmt(r.netSc), style: kt(46, w: FontWeight.w700, c: r.netSc < 0 ? K.red : K.text, num: true, h: 1.2)),
          ),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: _flow(Icons.south_west_rounded, 'In', scAmt(r.coinInSc), K.greenInk)),
            Expanded(child: _flow(Icons.north_east_rounded, 'Out', scAmt(r.coinOutSc), K.text)),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _Quick(Icons.person_add_alt_1_rounded, 'New ID', () => showCreatePlayer(context))),
        Expanded(child: _Quick(Icons.south_west_rounded, 'Coin in', () => showCoinIn(context))),
        Expanded(child: _Quick(Icons.north_east_rounded, 'Coin out', () => showCoinOut(context))),
      ]),
      const SizedBox(height: 14),
      KGrid(min: 150, gap: 10, max: 2, children: [
        _small('Players who played', '${r.active.length}'),
        _small('New player IDs', '${r.newPlayers}'),
        _small('Hold (DC)', grouped(r.ggrSc)),
        _small('Online now', '${casino.online}'),
        _small('Player balances', scAmt(r.closeSc)),
        _small('Coin ins today', '${r.coinIns}'),
      ]),
      const SizedBox(height: 14),
      KCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const KTitle('Latest activity', size: 17),
          for (final t in casino.txns.reversed.take(6)) TxnTile(t),
        ]),
      ),
    ]);
  }

  static Widget _flow(IconData i, String k, String v, Color c) => Row(children: [
        Icon(i, size: 16, color: c),
        const SizedBox(width: 4),
        Flexible(child: Text('$k $v', maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(15, w: FontWeight.w600, c: c, num: true))),
      ]);

  static Widget _small(String k, String v) => KCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(13, c: K.sub)),
          const SizedBox(height: 2),
          Text(v, style: kt(22, w: FontWeight.w700, num: true)),
        ]),
      );
}

class _Quick extends StatelessWidget {
  const _Quick(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkResponse(
        onTap: onTap,
        child: Column(children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: K.green),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: kt(13, w: FontWeight.w600)),
        ]),
      );
}

/// A game with its status and the period's numbers, switchable on the spot.
class _GameLine extends StatelessWidget {
  const _GameLine(this.id, this.r, {required this.canToggle});
  final String id;
  final GameReport? r;
  final bool canToggle;

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final g = games.firstWhere((x) => x.id == id);
    final c = casino.config(id);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(10), child: gameImage(g.cardArt, width: 40, height: 40)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g.name, style: kt(15, w: FontWeight.w600)),
            Text(
              r == null ? 'RTP ${pct(c.rtp)} · no play yet' : 'RTP ${pct(c.rtp)} · ${r!.rounds} rounds · hold ${grouped(r!.ggrSc)} DC',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kt(13, c: K.sub),
            ),
          ]),
        ),
        if (c.status == GameStatus.hidden) KBadge.game(c.status),
        if (canToggle && c.status != GameStatus.hidden)
          KSwitch(
            label: '${g.name} on',
            value: c.status == GameStatus.live,
            onChanged: (on) => casino.setGameStatus(id, on ? GameStatus.live : GameStatus.maintenance),
          ),
      ]),
    );
  }
}

/// Home for an executive or an agent: their points, their part of the
/// chain, what to do next, and the latest coin in and out.
class _NetworkHome extends StatelessWidget {
  const _NetworkHome();

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final me = casino.admin!;
    final players = casino.visiblePlayers;
    final ids = {for (final p in players) p.id};
    final today = dayOf(casino.now);
    final todays = [for (final t in casino.txns) if (ids.contains(t.playerId) && dayOf(t.at) == today) t];
    double sum(TxnType type, bool dc) => todays.where((t) => t.type == type).fold(0, (a, t) => a + (dc ? t.sc : t.gc).abs());
    final agents = me.isExecutive ? casino.agentsOf(me) : const <Staff>[];
    final children = <Widget>[
      const RequestsCard(),
      MyPointsCard(me),
      const SizedBox(height: 16),
      KGrid(min: 180, children: [
        if (me.isExecutive) ...[
          KStat(label: 'Agents', value: '${agents.length}', sub: '${agents.where((a) => a.active).length} can sign in', icon: Icons.groups_outlined),
          KStat(
            label: 'Points with agents',
            value: compact(agents.fold<double>(0, (a, s) => a + s.gc)),
            sub: scAmt(agents.fold<double>(0, (a, s) => a + s.sc)),
            icon: Icons.toll_rounded,
          ),
        ],
        KStat(label: me.isAgent ? 'My players' : 'Their players', value: '${players.length}', sub: '${players.where((p) => p.status == PlayerStatus.active).length} active', icon: Icons.people_alt_outlined),
        KStat(label: 'Coin in today', value: scAmt(sum(TxnType.coinIn, true)), sub: gcAmt(sum(TxnType.coinIn, false)), icon: Icons.south_west_rounded, color: K.greenInk),
        KStat(label: 'Coin out today', value: scAmt(sum(TxnType.coinOut, true)), sub: gcAmt(sum(TxnType.coinOut, false)), icon: Icons.north_east_rounded),
      ]),
      const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, children: [
        if (me.isAgent) ...[
          KButton('New player ID', icon: Icons.person_add_alt_1_rounded, onTap: () => showCreatePlayer(context)),
          KButton('Coin in', tone: KTone.light, icon: Icons.south_west_rounded, onTap: () => showCoinIn(context)),
          KButton('Coin out', tone: KTone.light, icon: Icons.north_east_rounded, onTap: () => showCoinOut(context)),
        ] else
          KButton('Give points to an agent', icon: Icons.account_tree_rounded, onTap: () => AdminNav.to(context, Section.team)),
      ]),
      const SizedBox(height: 16),
      KCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const KTitle('Latest activity'),
          if (!casino.txns.any((t) => ids.contains(t.playerId))) const KEmpty('Nothing yet'),
          for (final t in casino.txns.reversed.where((t) => ids.contains(t.playerId)).take(8)) TxnTile(t),
        ]),
      ),
    ];
    final greeting = casino.now.hour < 12 ? 'Good morning' : casino.now.hour < 18 ? 'Good afternoon' : 'Good evening';
    if (!K.desktop(context)) return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: children);
    return DeskPage(title: '$greeting, ${me.name}', sub: '${roleName(me.role)} · coins have no cash value', children: children);
  }
}
