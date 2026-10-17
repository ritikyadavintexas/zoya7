import 'dart:convert';

import 'package:flutter/material.dart';

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
  late bool registration = s.registrationOpen;

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
      ..registrationOpen = registration);
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
          ]),
          if (casino.admin?.isOwner ?? false) const _PlayerAppCard(),
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

/// What the player app shows (owner only). Off means shown nowhere; the
/// player ID, the games, DC, sound and notifications always stay.
class _PlayerAppCard extends StatelessWidget {
  const _PlayerAppCard();

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final s = casino.settings;
    Widget row(String key, String title, {String? sub}) {
      final on = key == 'daily' ? s.dailyBonus : !s.hidden.contains(key);
      return KRow(
        title: title,
        sub: sub,
        trailing: KSwitch(
          label: title,
          value: on,
          onChanged: (v) => casino.updateSettings('${v ? 'show' : 'hide'} ${title.toLowerCase()}', (x) {
            if (key == 'daily') {
              x.dailyBonus = v;
            } else if (v) {
              x.hidden = {...x.hidden}..remove(key);
            } else {
              x.hidden = {...x.hidden, key};
            }
          }),
        ),
      );
    }

    return KCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.phone_iphone_rounded, size: 20, color: K.sub),
          const SizedBox(width: 8),
          Text('Player app', style: kt(18, w: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        Text('Off means players see it nowhere. Their player ID, the games, DC, sound and notifications always stay.',
            style: kt(13, c: K.sub, h: 1.4)),
        const SizedBox(height: 8),
        row('gc', 'Gold Coins (GC)', sub: 'Off: DC only, in the lobby and in every game'),
        row('store', 'Get coins', sub: 'Players ask their agent for coins in the app'),
        row('daily', 'Daily bonus', sub: s.gcOn ? 'The 7-day streak (paid in GC)' : 'Needs Gold Coins'),
        row('jackpots', 'Jackpots', sub: s.gcOn ? 'The lobby’s jackpot meters' : 'Needs Gold Coins'),
        row('vip', 'VIP club and badge'),
        row('level', 'Player level'),
        row('promotions', 'Promotions'),
        row('race', 'Slots race'),
      ]),
    );
  }
}
