import 'dart:convert';

import 'package:flutter/material.dart';

import '../backoffice/casino.dart';
import 'admin_app.dart';
import 'kit.dart';

/// Rules for the whole casino: starting amount, cash in/out rates and limits.
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
    'gpd': TextEditingController(text: _n(s.gcPerDollar)),
    'spd': TextEditingController(text: _n(s.scPerDollar)),
    'bon': TextEditingController(text: _n(s.cashInBonusPct)),
    'mci': TextEditingController(text: _n(s.maxCashInPerDay)),
    'ups': TextEditingController(text: _n(s.usdPerSc)),
    'mco': TextEditingController(text: _n(s.minCashOut)),
    'mcd': TextEditingController(text: _n(s.maxCashOutPerDay)),
    'aau': TextEditingController(text: _n(s.autoApproveUnder)),
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
    if (v.values.any((x) => x == null || x < 0) || v['ups'] == 0) {
      kToast(context, 'Every field needs a number (0 or more)');
      return;
    }
    casino.updateSettings('starting amount ${grouped(v['ngc']!, 0)} GC + ${grouped(v['nsc']!)} SC, rates and limits', (s) => s
      ..newPlayerGc = v['ngc']!
      ..newPlayerSc = v['nsc']!
      ..gcPerDollar = v['gpd']!
      ..scPerDollar = v['spd']!
      ..cashInBonusPct = v['bon']!
      ..maxCashInPerDay = v['mci']!
      ..usdPerSc = v['ups']!
      ..minCashOut = v['mco']!
      ..maxCashOutPerDay = v['mcd']!
      ..autoApproveUnder = v['aau']!
      ..registrationOpen = registration
      ..dailyBonus = daily);
    kToast(context, 'Settings saved');
  }

  Widget _num(String key, String label, {String? prefix, String? help}) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        KField(label: label, controller: f[key], prefix: prefix, keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: KField.money),
        if (help != null) ...[const SizedBox(height: 4), Text(help, style: kt(12, c: K.faint))],
      ]);

  @override
  Widget build(BuildContext context) {
    return DeskPage(
      title: 'Settings',
      sub: 'Starting amount, what cash buys, and the limits on cash in and out',
      actions: [KButton('Save changes', icon: Icons.check_rounded, onTap: _save)],
      children: [
        KGrid(min: 380, gap: 16, max: 2, children: [
          _card('New player IDs', Icons.person_add_alt_1_rounded, [
            Row(children: [
              Expanded(child: _num('ngc', 'Starting Gold Coins')),
              const SizedBox(width: 12),
              Expanded(child: _num('nsc', 'Starting Sweeps Coins')),
            ]),
            KRow(title: 'Players can sign up in the app', trailing: KSwitch(label: 'Players can sign up', value: registration, onChanged: (v) => setState(() => registration = v))),
            KRow(title: 'Daily bonus', sub: 'The 7-day streak in the app', trailing: KSwitch(label: 'Daily bonus', value: daily, onChanged: (v) => setState(() => daily = v))),
          ]),
          _card('Cash in', Icons.south_west_rounded, [
            Row(children: [
              Expanded(child: _num('gpd', 'GC per \$1')),
              const SizedBox(width: 12),
              Expanded(child: _num('spd', 'SC per \$1')),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _num('bon', 'Bonus on every cash in (%)')),
              const SizedBox(width: 12),
              Expanded(child: _num('mci', 'Max per player per day', prefix: '\$ ')),
            ]),
          ]),
          _card('Cash out', Icons.north_east_rounded, [
            Row(children: [
              Expanded(child: _num('ups', 'Value of 1 SC', prefix: '\$ ')),
              const SizedBox(width: 12),
              Expanded(child: _num('mco', 'Minimum (SC)')),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _num('mcd', 'Max per player per day', prefix: '\$ ')),
              const SizedBox(width: 12),
              Expanded(child: _num('aau', 'Auto-pay up to (SC)', help: '0 = every request is reviewed')),
            ]),
          ]),
          _card('Data', Icons.storage_rounded, [
            Text(
                'Everything is kept on this device (in the browser on the web). Copy a backup before clearing site data. '
                'Connect a server to share it between devices.',
                style: kt(14, c: K.sub, h: 1.4)),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              KButton('Copy backup', tone: KTone.light, icon: Icons.copy_rounded, height: 42, onTap: () => copy(context, jsonEncode(casino.toJson()), 'Backup')),
              if (casino.admin?.isOwner ?? false)
                KButton('Reset demo data', tone: KTone.red, icon: Icons.restart_alt_rounded, height: 42, onTap: () async {
                  if (await kConfirm(context,
                          title: 'Reset everything?',
                          message: 'Players, ledger, game settings and reports go back to the demo data.',
                          action: 'Reset',
                          danger: true) &&
                      context.mounted) {
                    casino.resetDemo();
                    kToast(context, 'Demo data restored');
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
      sub: 'Owners do everything · managers all but staff · cashiers players and cash',
      actions: [KButton('Add staff', icon: Icons.person_add_alt_rounded, onTap: () => _add(context))],
      children: [
        KCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: KTable(
            minWidth: 520,
            columns: const ['Name', 'Role', 'PIN', ''],
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
                  cellText('••••', c: K.sub),
                  s == casino.admin
                      ? const SizedBox()
                      : KIconButton(Icons.delete_outline_rounded, tooltip: 'Remove ${s.name}', size: 34, color: K.redSoft, fg: K.red, onTap: () async {
                          if (await kConfirm(context, title: 'Remove ${s.name}?', message: 'Their PIN stops working.', action: 'Remove', danger: true) &&
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
    final name = TextEditingController(), pin = TextEditingController();
    var role = StaffRole.cashier;
    kSheet<void>(
      context,
      title: 'Add staff',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KField(label: 'Name', controller: name, autofocus: true),
          const SizedBox(height: 12),
          KField(label: '4-digit PIN', controller: pin, keyboard: TextInputType.number, obscure: true, formatters: KField.money),
          const SizedBox(height: 12),
          Text('Role', style: kt(13, w: FontWeight.w600, c: K.sub)),
          const SizedBox(height: 6),
          KSegment<StaffRole>(values: StaffRole.values, selected: role, expand: true, label: statusName, onChanged: (r) => set(() => role = r)),
          const SizedBox(height: 16),
          KButton('Add', expand: true, onTap: () {
            if (attempt(ctx, () => CasinoScope.read(ctx).addStaff(name.text, role, pin.text.trim()), done: '${name.text.trim()} can sign in now')) {
              Navigator.of(ctx).pop();
            }
          }),
        ]),
      ),
    ).whenComplete(() {
      name.dispose();
      pin.dispose();
    });
  }
}
