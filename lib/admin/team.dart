import 'package:flutter/material.dart';

import '../backoffice/auth.dart';
import '../backoffice/casino.dart';
import 'admin_app.dart';
import 'kit.dart';

/// The chain. The owner sees every executive and agent, gives executives
/// points and takes them back; an executive does the same for their agents;
/// an agent refers new agents (who join the same executive). The owner also
/// sees the activity log here.
class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final me = casino.admin!;
    final desktop = K.desktop(context);
    final actions = [
      if (me.isOwner) KButton('New executive', icon: Icons.person_add_alt_rounded, onTap: () => addMember(context, StaffRole.executive)),
      if (!me.isAgent)
        KButton('New agent', tone: me.isOwner ? KTone.light : KTone.green, icon: Icons.person_add_alt_1_rounded, onTap: () => addMember(context, StaffRole.agent)),
      if (me.isAgent) KButton('Refer an agent', icon: Icons.group_add_rounded, onTap: () => addMember(context, StaffRole.agent)),
    ];
    final children = [
      if (!me.isOwner) ...[MyPointsCard(me), const SizedBox(height: 16)],
      ..._members(context, casino, me),
      const SizedBox(height: 16),
      _History(casino),
      if (me.isOwner) ...[const SizedBox(height: 16), _log(casino)],
    ];
    if (!desktop) {
      return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        Wrap(spacing: 8, runSpacing: 8, children: actions),
        const SizedBox(height: 14),
        ...children,
      ]);
    }
    return DeskPage(
      title: me.isAgent ? 'My referrals' : 'Team',
      sub: switch (me.role) {
        StaffRole.owner => 'You supply executives · executives supply their agents · agents put coins on their players',
        StaffRole.executive => 'Your agents and the points you supply them',
        StaffRole.agent => 'Agents you brought in join your executive',
      },
      actions: actions,
      children: children,
    );
  }

  List<Widget> _members(BuildContext context, Casino casino, Staff me) {
    if (me.isOwner) {
      final execs = [for (final s in casino.staff) if (s.isExecutive) s];
      final loose = [for (final s in casino.staff) if (s.isAgent && casino.staffBy(s.parent) == null) s];
      return [
        if (execs.isEmpty && loose.isEmpty) const KCard(child: KEmpty('No executives yet. Add one, then give them points.', icon: Icons.groups_outlined)),
        for (final e in execs) ...[
          KCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _MemberRow(e),
              for (final a in casino.agentsOf(e)) Padding(padding: const EdgeInsets.only(left: 28), child: _MemberRow(a)),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        if (loose.isNotEmpty)
          KCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(padding: const EdgeInsets.only(top: 8), child: Text('Agents you supply directly', style: kt(14, w: FontWeight.w700, c: K.sub))),
              for (final a in loose) _MemberRow(a),
            ]),
          ),
      ];
    }
    final team = casino.teamOf(me);
    return [
      KCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: team.isEmpty
            ? KEmpty(me.isAgent ? 'Nobody referred yet' : 'No agents yet. Add one, then give them points.', icon: Icons.groups_outlined)
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final s in team) _MemberRow(s)]),
      ),
    ];
  }

  Widget _log(Casino casino) {
    final log = casino.audit.reversed.where((a) => q.isEmpty || '${a.by} ${a.action}'.toLowerCase().contains(q.toLowerCase())).take(150).toList();
    return KCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KTitle('Activity log', trailing: SizedBox(width: 220, child: KField(hint: 'Search', icon: Icons.search_rounded, onChanged: (v) => setState(() => q = v)))),
        if (log.isEmpty) const KEmpty('Nothing logged'),
        for (final a in log)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 130, child: Text(when(a.at, casino.now), style: kt(13, c: K.sub, num: true))),
              SizedBox(width: 80, child: Text(a.by, maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(14, w: FontWeight.w600))),
              Expanded(child: Text(a.action, style: kt(14))),
            ]),
          ),
      ]),
    );
  }
}

String _pts(double gc, double sc) => '${gcAmt(gc)} · ${scAmt(sc)}';

/// An executive's or agent's own points.
class MyPointsCard extends StatelessWidget {
  const MyPointsCard(this.me, {super.key});
  final Staff me;

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final supplier = casino.staffBy(me.parent);
    return KCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your points', style: kt(15, c: K.sub)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(gcAmt(me.gc), style: kt(40, w: FontWeight.w700, num: true, h: 1.2)),
        ),
        Text(scAmt(me.sc), style: kt(22, w: FontWeight.w600, c: K.greenInk, num: true)),
        const SizedBox(height: 6),
        Text(
          me.isExecutive
              ? 'From the owner. Give them to your agents.'
              : 'From ${supplier?.name ?? 'the owner'}. Coin in to your players takes from these; coin out puts them back.',
          style: kt(13, c: K.sub, h: 1.4),
        ),
      ]),
    );
  }
}

/// One executive or agent: points on hand, and what the viewer can do.
class _MemberRow extends StatelessWidget {
  const _MemberRow(this.s);
  final Staff s;

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final me = casino.admin!;
    final supply = casino.supplies(me, s);
    final canSwitch = me.isOwner || (me.isExecutive && s.parent == me.uid);
    final players = casino.players.where((p) => p.agent == s.uid).length;
    final referrer = casino.staffBy(s.referredBy);
    final info = [
      roleName(s.role),
      if (s.username.isNotEmpty) s.username,
      if (s.isExecutive) '${casino.agentsOf(s).length} agent${casino.agentsOf(s).length == 1 ? '' : 's'}',
      if (s.isAgent) '$players player${players == 1 ? '' : 's'}',
      if (referrer != null) 'referred by ${referrer.name}',
      if (!s.active) 'switched off',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.spaceBetween, children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 420),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            KAvatar(s.name, size: 36),
            const SizedBox(width: 10),
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name, style: kt(16, w: FontWeight.w700, c: s.active ? K.text : K.faint)),
                Text(info, style: kt(12.5, c: K.sub)),
              ]),
            ),
          ]),
        ),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(_pts(s.gc, s.sc), style: kt(14, w: FontWeight.w700, num: true)),
          if (supply) ...[
            KButton('Give', icon: Icons.south_rounded, height: 36, onTap: () => movePoints(context, s, give: true)),
            KButton('Take back', tone: KTone.light, icon: Icons.north_rounded, height: 36, onTap: () => movePoints(context, s, give: false)),
          ],
          if (canSwitch)
            KSwitch(
              label: '${s.name} can sign in',
              value: s.active,
              onChanged: (on) => attempt(context, () => casino.setStaffActive(s, on), done: on ? '${s.name} can sign in' : '${s.name} switched off'),
            ),
          if (me.isOwner)
            KIconButton(Icons.delete_outline_rounded, tooltip: 'Remove ${s.name}', size: 34, color: K.redSoft, fg: K.red, onTap: () async {
              if (await kConfirm(context, title: 'Remove ${s.name}?', message: 'They can’t sign in any more.', action: 'Remove', danger: true) &&
                  context.mounted) {
                attempt(context, () => casino.removeStaff(s), done: '${s.name} removed');
              }
            }),
        ]),
      ]),
    );
  }
}

/// Points given and taken back (as far as the viewer can see).
class _History extends StatelessWidget {
  const _History(this.casino);
  final Casino casino;

  String _who(String id) {
    if (id.startsWith('p:')) return casino.player(id.substring(2))?.username ?? id.substring(2);
    return casino.staffBy(id)?.name ?? 'Owner';
  }

  @override
  Widget build(BuildContext context) {
    final moves = casino.visiblePoints.reversed.where((m) => !m.from.startsWith('p:') && !m.to.startsWith('p:')).take(40).toList();
    return KCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const KTitle('Points given and taken back'),
        if (moves.isEmpty) const KEmpty('No points moved yet'),
        for (final m in moves)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_who(m.from)} to ${_who(m.to)}', style: kt(14, w: FontWeight.w600)),
              Text('${_pts(m.gc, m.sc)} · ${when(m.at, casino.now)}', style: kt(13, c: K.sub, num: true)),
            ]),
          ),
      ]),
    );
  }
}

/// Give points to someone below, or take them back.
Future<void> movePoints(BuildContext context, Staff s, {required bool give}) {
  final gc = TextEditingController(), sc = TextEditingController(), note = TextEditingController();
  return kSheet<void>(
    context,
    title: give ? 'Give points to ${s.name}' : 'Take points back from ${s.name}',
    builder: (ctx) {
      final casino = CasinoScope.read(ctx);
      final me = casino.admin!;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          give
              ? (me.isOwner ? 'From the house.' : 'You have ${_pts(me.gc, me.sc)}.')
              : '${s.name} has ${_pts(s.gc, s.sc)}.',
          style: kt(14, c: K.sub),
        ),
        const SizedBox(height: 12),
        Row(children: [
          if (casino.settings.gcOn) ...[
            Expanded(child: KField(label: 'Gold Coins', controller: gc, keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: KField.money, autofocus: true)),
            const SizedBox(width: 12),
          ],
          Expanded(child: KField(label: 'DC', controller: sc, keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: KField.money)),
        ]),
        const SizedBox(height: 12),
        KField(label: 'Note (optional)', controller: note),
        const SizedBox(height: 16),
        KButton(give ? 'Give points' : 'Take back', expand: true, onTap: () {
          final g = amountOf(gc.text.isEmpty ? '0' : gc.text), d = amountOf(sc.text.isEmpty ? '0' : sc.text);
          if (g == null || d == null) {
            kToast(ctx, 'Enter amounts as numbers');
            return;
          }
          final ok = attempt(
            ctx,
            () => give ? casino.givePoints(s, gc: g, sc: d, note: note.text.trim()) : casino.takePoints(s, gc: g, sc: d, note: note.text.trim()),
            done: give ? 'Points given to ${s.name}' : 'Points taken back from ${s.name}',
          );
          if (ok) Navigator.of(ctx).pop();
        }),
      ]);
    },
  ).whenComplete(() {
    gc.dispose();
    sc.dispose();
    note.dispose();
  });
}

/// Add an executive (owner) or an agent (owner, an executive, or an agent's referral).
Future<void> addMember(BuildContext context, StaffRole role) {
  final name = TextEditingController(), username = TextEditingController(), password = TextEditingController();
  final casino = CasinoScope.read(context);
  final me = casino.admin!;
  final execs = [for (final s in casino.staff) if (s.isExecutive) s];
  var parent = execs.isEmpty ? '' : execs.first.uid;
  var busy = false;
  final title = role == StaffRole.executive ? 'New executive' : me.isAgent ? 'Refer an agent' : 'New agent';
  return kSheet<void>(
    context,
    title: title,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KField(label: 'Name', controller: name, autofocus: true),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: KField(label: 'Username', controller: username)),
          const SizedBox(width: 12),
          Expanded(child: KField(label: 'Password (6+ characters)', controller: password, obscure: true)),
        ]),
        if (role == StaffRole.agent && me.isOwner) ...[
          const SizedBox(height: 12),
          Text('Their executive (who gives them points)', style: kt(13, w: FontWeight.w600, c: K.sub)),
          const SizedBox(height: 6),
          DropdownButton<String>(
            value: parent,
            isExpanded: true,
            items: [
              for (final e in execs) DropdownMenuItem(value: e.uid, child: Text(e.name)),
              const DropdownMenuItem(value: '', child: Text('None: I supply them myself')),
            ],
            onChanged: (v) => set(() => parent = v ?? ''),
          ),
        ],
        if (me.isAgent) ...[
          const SizedBox(height: 10),
          Text('They join ${casino.staffBy(me.parent)?.name ?? 'the owner'}’s team and get points from them.', style: kt(13, c: K.sub, h: 1.4)),
        ],
        const SizedBox(height: 16),
        KButton(busy ? 'Adding…' : 'Add', expand: true, onTap: busy
            ? null
            : () async {
                final u = username.text.trim().toLowerCase();
                if (!RegExp(r'^[a-z0-9_.-]{3,30}$').hasMatch(u)) {
                  kToast(ctx, 'Username: 3 or more letters, numbers, _ . or -');
                  return;
                }
                if (password.text.length < 6) {
                  kToast(ctx, 'The password needs at least 6 characters');
                  return;
                }
                set(() => busy = true);
                final ok = await attemptAsync(ctx, () async {
                  if (name.text.trim().isEmpty) throw CasinoError('Enter a name');
                  final auth = SyncScope.read(ctx)?.auth;
                  final uid = auth == null ? 'local:$u' : (await auth.signUp(staffEmail(u), password.text)).uid;
                  if (ctx.mounted) CasinoScope.read(ctx).addStaff(uid, name.text, role, username: u, parent: role == StaffRole.agent ? parent : '');
                }, done: '${name.text.trim()} can sign in now as $u');
                if (ok && ctx.mounted) {
                  Navigator.of(ctx).pop();
                } else {
                  set(() => busy = false);
                }
              }),
      ]),
    ),
  ).whenComplete(() {
    name.dispose();
    username.dispose();
    password.dispose();
  });
}
