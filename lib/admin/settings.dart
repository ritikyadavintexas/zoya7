import 'dart:convert';

import 'package:flutter/material.dart';

import '../backoffice/auth.dart';
import '../backoffice/casino.dart';
import 'admin_app.dart';
import 'kit.dart';
import 'setup.dart';

/// Rules for the whole casino: starting amount and the coin-in limit.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final casino = CasinoScope.read(context);
  late final s = casino.settings;
  late final f = {
    'ngc': TextEditingController(text: _n(s.newPlayerGc)),
    'nsc': TextEditingController(text: _n(s.newPlayerSc)),
    'cid': TextEditingController(text: _n(s.maxCoinInPerDay)),
  };
  late bool registration = s.registrationOpen, daily = s.dailyBonus;

  static String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    for (final c in f.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final v = {for (final e in f.entries) e.key: amountOf(e.value.text)};
    if (v.values.any((x) => x == null || x < 0)) {
      kToast(context, 'Every field needs a number (0 or more)');
      return;
    }
    casino.updateSettings('starting amount ${grouped(v['ngc']!, 0)} GC + ${grouped(v['nsc']!)} DC, coin-in limit ${grouped(v['cid']!)} DC', (s) => s
      ..newPlayerGc = v['ngc']!
      ..newPlayerSc = v['nsc']!
      ..maxCoinInPerDay = v['cid']!
      ..registrationOpen = registration
      ..dailyBonus = daily);
    kToast(context, 'Settings saved');
  }

  Widget _num(String key, String label) =>
      KField(label: label, controller: f[key], keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: KField.money);

  @override
  Widget build(BuildContext context) {
    return DeskPage(
      title: 'Settings',
      sub: 'Starting amount and coin-in limit · coins have no cash value',
      actions: [KButton('Save changes', icon: Icons.check_rounded, onTap: _save)],
      children: [
        const InstallCard(),
        const DatabaseCard(),
        const SizedBox(height: 16),
        KGrid(min: 380, gap: 16, max: 2, children: [
          _card('New player IDs', Icons.person_add_alt_1_rounded, [
            Row(children: [
              Expanded(child: _num('ngc', 'Starting Gold Coins')),
              const SizedBox(width: 12),
              Expanded(child: _num('nsc', 'Starting DC')),
            ]),
            KRow(title: 'Players can sign up in the app', trailing: KSwitch(label: 'Players can sign up', value: registration, onChanged: (v) => setState(() => registration = v))),
            KRow(title: 'Daily bonus', sub: 'The 7-day streak in the app', trailing: KSwitch(label: 'Daily bonus', value: daily, onChanged: (v) => setState(() => daily = v))),
          ]),
          _card('Coin in', Icons.south_west_rounded, [
            _num('cid', 'Most DC per player per day'),
            const SizedBox(height: 10),
            Text('Coins are for play only: they have no cash value and are never paid out.', style: kt(13, c: K.sub, h: 1.4)),
          ]),
          _card('Data', Icons.storage_rounded, [
            Text(
                'Everything is kept on the server (Firebase), not on this device. Copy a backup any time.',
                style: kt(14, c: K.sub, h: 1.4)),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              KButton('Copy backup', tone: KTone.light, icon: Icons.copy_rounded, height: 42, onTap: () => copy(context, jsonEncode(casino.toJson()), 'Backup')),
              if (casino.admin?.isOwner ?? false)
                KButton('Reset all (keep users)', tone: KTone.red, icon: Icons.restart_alt_rounded, height: 42, onTap: () async {
                  if (await kConfirm(context,
                          title: 'Reset all data?',
                          message: 'Deletes every coin in and out, bonus, adjustment, game play record and the log — '
                              'from the server, for good. Player IDs (back on their starting amount), their passwords, '
                              'staff, settings and games stay.',
                          action: 'Reset all',
                          danger: true) &&
                      context.mounted) {
                    casino.resetData();
                    kToast(context, 'All data reset — users kept');
                  }
                }),
              if (casino.admin?.isOwner ?? false)
                KButton('Clear players & ledger', tone: KTone.red, icon: Icons.delete_sweep_outlined, height: 42, onTap: () async {
                  if (await kConfirm(context,
                          title: 'Start clean?',
                          message: 'Every player ID, the coin ledger and play records are removed from the server. '
                              'Staff, settings and games stay.',
                          action: 'Clear everything',
                          danger: true) &&
                      context.mounted) {
                    casino.clearAll();
                    kToast(context, 'All players and the ledger are cleared');
                  }
                }),
            ]),
          ]),
        ]),
      ],
    );
  }

  Widget _card(String title, IconData icon, List<Widget> children) => KCard(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, size: 20, color: K.sub),
            const SizedBox(width: 8),
            Text(title, style: kt(18, w: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          ...children,
        ]),
      );
}

/// Who can sign in, with what role, and everything they did.
class StaffPage extends StatefulWidget {
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final log = casino.audit.reversed.where((a) => q.isEmpty || '${a.by} ${a.action}'.toLowerCase().contains(q.toLowerCase())).take(150).toList();
    return DeskPage(
      title: 'Staff & log',
      sub: 'Owners do everything · managers all but staff · cashiers players and coins',
      actions: [KButton('Add staff', icon: Icons.person_add_alt_rounded, onTap: () => _add(context))],
      children: [
        KCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: KTable(
            minWidth: 520,
            columns: const ['Name', 'Role', 'Username', ''],
            numeric: const {3},
            rows: [
              for (final s in casino.staff)
                [
                  Row(children: [
                    KAvatar(s.name, size: 32),
                    const SizedBox(width: 10),
                    Flexible(child: cellText(s.name + (s == casino.admin ? ' (you)' : ''), w: FontWeight.w600)),
                  ]),
                  KBadge(statusName(s.role), fg: s.isOwner ? K.greenInk : K.text, bg: s.isOwner ? K.greenSoft : K.field),
                  cellText(s.username.isEmpty ? '—' : s.username, c: K.sub),
                  s == casino.admin
                      ? const SizedBox()
                      : KIconButton(Icons.delete_outline_rounded, tooltip: 'Remove ${s.name}', size: 34, color: K.redSoft, fg: K.red, onTap: () async {
                          if (await kConfirm(context, title: 'Remove ${s.name}?', message: 'They can’t sign in to the admin panel any more.', action: 'Remove', danger: true) &&
                              context.mounted) {
                            attempt(context, () => casino.removeStaff(s), done: '${s.name} removed');
                          }
                        }),
                ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        KCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KTitle('Audit log', trailing: SizedBox(width: 260, child: KField(hint: 'Search', icon: Icons.search_rounded, onChanged: (v) => setState(() => q = v)))),
            if (log.isEmpty) const KEmpty('Nothing logged'),
            for (final a in log)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 150, child: Text(when(a.at, casino.now), style: kt(13, c: K.sub, num: true))),
                  SizedBox(width: 90, child: Text(a.by, maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(14, w: FontWeight.w600))),
                  Expanded(child: Text(a.action, style: kt(14))),
                ]),
              ),
          ]),
        ),
      ],
    );
  }

  void _add(BuildContext context) {
    final name = TextEditingController(), username = TextEditingController(), password = TextEditingController();
    var role = StaffRole.cashier;
    var busy = false;
    kSheet<void>(
      context,
      title: 'Add staff',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KField(label: 'Name', controller: name, autofocus: true),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: KField(label: 'Username', controller: username)),
            const SizedBox(width: 12),
            Expanded(child: KField(label: 'Password (6+ characters)', controller: password, obscure: true)),
          ]),
          const SizedBox(height: 12),
          Text('Role', style: kt(13, w: FontWeight.w600, c: K.sub)),
          const SizedBox(height: 6),
          KSegment<StaffRole>(values: StaffRole.values, selected: role, expand: true, label: statusName, onChanged: (r) => set(() => role = r)),
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
                    if (ctx.mounted) CasinoScope.read(ctx).addStaff(uid, name.text, role, username: u);
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
}
