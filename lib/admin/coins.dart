import 'package:flutter/material.dart';

import '../backoffice/casino.dart';
import 'admin_app.dart';
import 'kit.dart';
import 'players.dart';

// ── Sheets ───────────────────────────────────────────────────────────────────
/// Choose a player (search by name, username or ID).
Future<Player?> pickPlayer(BuildContext context, {bool activeOnly = true}) => kSheet<Player>(
      context,
      title: 'Choose player',
      builder: (ctx) => _PlayerPicker(activeOnly: activeOnly),
    );

class _PlayerPicker extends StatefulWidget {
  const _PlayerPicker({required this.activeOnly});
  final bool activeOnly;

  @override
  State<_PlayerPicker> createState() => _PlayerPickerState();
}

class _PlayerPickerState extends State<_PlayerPicker> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final list = casino.visiblePlayers.reversed
        .where((p) => !widget.activeOnly || p.status == PlayerStatus.active)
        .where((p) => matchesPlayer(p, q))
        .take(40)
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KField(hint: 'Name, username or ID', icon: Icons.search_rounded, autofocus: K.desktop(context), onChanged: (v) => setState(() => q = v)),
      const SizedBox(height: 8),
      if (list.isEmpty) const KEmpty('No players match', icon: Icons.person_search_outlined),
      for (final p in list)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: KAvatar(p.name),
          title: Text(p.username, style: kt(16, w: FontWeight.w600)),
          subtitle: Text('${p.id} · ${p.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(13, c: K.sub)),
          trailing: Text(scAmt(p.sc), style: kt(14, w: FontWeight.w600, num: true)),
          onTap: () => Navigator.of(context).pop(p),
        ),
    ]);
  }
}

bool matchesPlayer(Player p, String q) {
  final s = q.trim().toLowerCase();
  final digits = s.replaceAll(RegExp(r'\D'), '');
  return s.isEmpty ||
      p.username.toLowerCase().contains(s) ||
      p.name.toLowerCase().contains(s) ||
      p.id.toLowerCase().contains(s) ||
      (digits.length >= 3 && p.phone.replaceAll(RegExp(r'\D'), '').contains(digits));
}

/// Put coins on a player's account.
Future<void> showCoinIn(BuildContext context, {Player? player}) => _showCoins(context, player, out: false);

/// Take coins off a player's account.
Future<void> showCoinOut(BuildContext context, {Player? player}) => _showCoins(context, player, out: true);

Future<void> _showCoins(BuildContext context, Player? player, {required bool out}) async {
  final p = player ?? await pickPlayer(context, activeOnly: !out);
  if (p == null || !context.mounted) return;
  await kSheet<void>(context, title: out ? 'Coin out' : 'Coin in', builder: (_) => _CoinForm(p, out: out));
}

class _CoinForm extends StatefulWidget {
  const _CoinForm(this.p, {required this.out});
  final Player p;
  final bool out;

  @override
  State<_CoinForm> createState() => _CoinFormState();
}

class _CoinFormState extends State<_CoinForm> {
  final sc = TextEditingController(), gc = TextEditingController(), note = TextEditingController();

  @override
  void dispose() {
    sc.dispose();
    gc.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final p = widget.p, out = widget.out;
    final s = amountOf(sc.text) ?? 0, g = (amountOf(gc.text) ?? 0).roundToDouble();
    final what = [if (s > 0) scAmt(s), if (g > 0) gcAmt(g)].join(' + ');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _PlayerChip(p),
      const SizedBox(height: 16),
      KField(
        label: 'DC',
        controller: sc,
        hint: '0.00',
        autofocus: true,
        keyboard: const TextInputType.numberWithOptions(decimal: true),
        formatters: KField.money,
        suffix: out
            ? TextButton(
                onPressed: () => setState(() => sc.text = p.sc.toStringAsFixed(2)),
                child: Text('All', style: kt(14, w: FontWeight.w700, c: K.greenInk)),
              )
            : null,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final v in const [10, 20, 50, 100, 200])
          ActionChip(
            label: Text('$v DC', style: kt(14, w: FontWeight.w600)),
            backgroundColor: K.field,
            side: BorderSide.none,
            shape: const StadiumBorder(),
            onPressed: () => setState(() => sc.text = '$v'),
          ),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: KField(
            label: 'Gold Coins',
            controller: gc,
            hint: '0',
            keyboard: TextInputType.number,
            formatters: KField.money,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: KField(label: 'Note (optional)', controller: note)),
      ]),
      const SizedBox(height: 16),
      KCard(
        color: out ? K.field : K.greenSoft,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(out ? Icons.north_east_rounded : Icons.south_west_rounded, color: out ? K.text : K.greenInk),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                what.isEmpty
                    ? 'Balance ${scAmt(p.sc)} · ${gcAmt(p.gc)}'
                    : out
                        ? '$what comes off ${p.username}'
                        : '${p.username} gets $what',
                style: kt(15, w: FontWeight.w600, c: out ? K.text : K.greenInk)),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      Text('Coins have no cash value.', style: kt(12, c: K.faint)),
      const SizedBox(height: 12),
      KButton(
        what.isEmpty ? (out ? 'Coin out' : 'Coin in') : '${out ? 'Coin out' : 'Coin in'} $what',
        tone: out ? KTone.dark : KTone.green,
        expand: true,
        onTap: what.isEmpty
            ? null
            : () {
                final n = note.text.trim();
                if (attempt(context, () => out ? casino.coinOut(p, sc: s, gc: g, note: n) : casino.coinIn(p, sc: s, gc: g, note: n),
                    done: out ? '$what taken off ${p.username}' : '$what added to ${p.username}')) {
                  Navigator.of(context).pop();
                }
              },
      ),
    ]);
  }
}

/// Free coins (bonus) or a correction (adjustment, either sign).
Future<void> showCredit(BuildContext context, Player p, TxnType type) =>
    kSheet<void>(context, title: type == TxnType.bonus ? 'Give a bonus' : 'Adjust balance', builder: (_) => _CreditForm(p, type));

class _CreditForm extends StatefulWidget {
  const _CreditForm(this.p, this.type);
  final Player p;
  final TxnType type;

  @override
  State<_CreditForm> createState() => _CreditFormState();
}

class _CreditFormState extends State<_CreditForm> {
  final gc = TextEditingController(), sc = TextEditingController(), note = TextEditingController();
  bool take = false;

  @override
  void dispose() {
    gc.dispose();
    sc.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final adjust = widget.type == TxnType.adjust;
    final sign = take ? -1 : 1;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _PlayerChip(widget.p),
      if (adjust) ...[
        const SizedBox(height: 14),
        KSegment(values: const [false, true], selected: take, expand: true, label: (t) => t ? 'Take off' : 'Add', onChanged: (v) => setState(() => take = v)),
      ],
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: KField(label: 'Gold Coins', controller: gc, hint: '0', keyboard: TextInputType.number, formatters: KField.money)),
        const SizedBox(width: 12),
        Expanded(child: KField(label: 'DC', controller: sc, hint: '0.00', keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: KField.money)),
      ]),
      const SizedBox(height: 12),
      KField(label: adjust ? 'Reason' : 'Note', controller: note, hint: adjust ? 'Why the balance changes' : 'e.g. Birthday bonus'),
      const SizedBox(height: 16),
      KButton(
        adjust ? 'Save adjustment' : 'Give bonus',
        expand: true,
        tone: take ? KTone.dark : KTone.green,
        onTap: () {
          final g = (amountOf(gc.text) ?? 0) * sign, s = (amountOf(sc.text) ?? 0) * sign;
          if (adjust && note.text.trim().isEmpty) {
            kToast(context, 'Add a reason for the adjustment');
            return;
          }
          if (attempt(context, () => casino.credit(widget.p, gc: g, sc: s, type: widget.type, note: note.text.trim()),
              done: adjust ? 'Balance adjusted' : 'Bonus sent to ${widget.p.username}')) {
            Navigator.of(context).pop();
          }
        },
      ),
    ]);
  }
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip(this.p);
  final Player p;

  @override
  Widget build(BuildContext context) => KCard(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          KAvatar(p.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.username, style: kt(16, w: FontWeight.w700)),
              Text(p.id, style: kt(13, c: K.sub)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(scAmt(p.sc), style: kt(15, w: FontWeight.w700, num: true)),
            Text(gcAmt(p.gc), style: kt(12, c: K.sub, num: true)),
          ]),
        ]),
      );
}

// ── Lists ────────────────────────────────────────────────────────────────────
/// A ledger line: who, what, how many coins.
class TxnTile extends StatelessWidget {
  const TxnTile(this.t, {super.key, this.showPlayer = true});
  final Txn t;
  final bool showPlayer;

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final p = casino.player(t.playerId);
    final coinIn = t.type == TxnType.coinIn;
    final amount = t.sc != 0
        ? '${t.sc > 0 ? '+' : '−'}${scAmt(t.sc.abs())}'
        : t.gc != 0
            ? '${t.gc > 0 ? '+' : '−'}${compact(t.gc.abs())} GC'
            : '—';
    final icon = switch (t.type) {
      TxnType.coinIn => Icons.south_west_rounded,
      TxnType.coinOut => Icons.north_east_rounded,
      TxnType.bonus => Icons.card_giftcard_rounded,
      TxnType.start => Icons.person_add_alt_rounded,
      TxnType.adjust => Icons.tune_rounded,
    };
    return InkWell(
      onTap: p == null ? null : () => openPlayer(context, p),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: coinIn ? K.greenSoft : K.field),
            child: Icon(icon, size: 20, color: coinIn ? K.greenInk : K.text),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(showPlayer ? (p?.username ?? t.playerId) : statusName(t.type),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(15, w: FontWeight.w600)),
              Text(
                [
                  if (showPlayer) statusName(t.type),
                  if (t.note.isNotEmpty) t.note,
                  when(t.at, casino.now),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kt(13, c: K.sub),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Text(amount, style: kt(15, w: FontWeight.w700, c: coinIn ? K.greenInk : K.text, num: true)),
        ]),
      ),
    );
  }
}

// ── Page ─────────────────────────────────────────────────────────────────────
class CoinsPage extends StatefulWidget {
  const CoinsPage({super.key});

  @override
  State<CoinsPage> createState() => _CoinsPageState();
}

class _CoinsPageState extends State<CoinsPage> {
  String tab = 'Pad';
  TxnType? type;
  String q = '';

  @override
  Widget build(BuildContext context) => K.desktop(context) ? _desktop(context) : _phone(context);

  List<Txn> _ledger(Casino casino) {
    bool hit(Txn t) {
      if (q.isEmpty) return true;
      final p = casino.player(t.playerId);
      return (p != null && matchesPlayer(p, q)) || t.id.toLowerCase().contains(q.trim().toLowerCase());
    }

    final mine = casino.admin?.isOwner ?? true ? null : {for (final p in casino.visiblePlayers) p.id};
    return [
      for (final t in casino.txns.reversed)
        if ((type == null || t.type == type) && hit(t) && (mine == null || mine.contains(t.playerId))) t,
    ];
  }

  Widget _desktop(BuildContext context) {
    final casino = CasinoScope.of(context);
    final r = casino.report(Period.standard(casino.now).first);
    final ledger = _ledger(casino).take(60).toList();
    return DeskPage(
      title: 'Coin in / out',
      sub: 'Put coins on accounts and take them off · coins have no cash value',
      actions: [
        KButton('Coin out', tone: KTone.dark, icon: Icons.north_east_rounded, onTap: () => showCoinOut(context)),
        KButton('Coin in', icon: Icons.south_west_rounded, onTap: () => showCoinIn(context)),
      ],
      children: [
        KGrid(min: 190, children: [
          KStat(label: 'Coin in today', value: scAmt(r.coinInSc), sub: '${r.coinIns} times · ${compact(r.coinInGc)} GC', icon: Icons.south_west_rounded, color: K.greenInk),
          KStat(label: 'Coin out today', value: scAmt(r.coinOutSc), sub: '${r.coinOuts} times · ${compact(r.coinOutGc)} GC', icon: Icons.north_east_rounded),
          KStat(label: 'Net coin in today', value: scAmt(r.netSc), sub: 'Coin in − coin out', icon: Icons.account_balance_wallet_outlined, color: r.netSc < 0 ? K.red : K.text),
          KStat(label: 'Players who played', value: '${r.active.length}', sub: '${r.rounds} rounds', icon: Icons.sports_esports_outlined),
        ]),
        const SizedBox(height: 16),
        KCard(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('Ledger', style: kt(18, w: FontWeight.w700)),
                KSegment<TxnType?>(
                  values: const [null, TxnType.coinIn, TxnType.coinOut, TxnType.bonus, TxnType.start, TxnType.adjust],
                  selected: type,
                  label: (t) => t == null ? 'All' : statusName(t),
                  onChanged: (t) => setState(() => type = t),
                ),
                SizedBox(width: 260, child: KField(hint: 'Search player or txn ID', icon: Icons.search_rounded, onChanged: (v) => setState(() => q = v))),
              ]),
            ),
            const SizedBox(height: 10),
            KTable(
              minWidth: 760,
              columns: const ['Player', 'Type', 'When', 'DC', 'Gold Coins', 'Note', 'By'],
              numeric: const {3, 4},
              rows: [
                for (final t in ledger)
                  [
                    cellText(casino.player(t.playerId)?.username ?? t.playerId, w: FontWeight.w600),
                    cellText(statusName(t.type)),
                    cellText(when(t.at, casino.now), c: K.sub, size: 13),
                    cellText(t.sc == 0 ? '—' : '${t.sc > 0 ? '+' : '−'}${grouped(t.sc.abs())}',
                        c: t.type == TxnType.coinIn ? K.greenInk : K.text, w: FontWeight.w600),
                    cellText(t.gc == 0 ? '—' : '${t.gc > 0 ? '+' : '−'}${compact(t.gc.abs())}', c: K.sub),
                    cellText(t.note.isEmpty ? '—' : t.note, c: K.sub, size: 13),
                    cellText(t.by, c: K.sub, size: 13),
                  ],
              ],
              onTap: (i) {
                final p = casino.player(ledger[i].playerId);
                if (p != null) openPlayer(context, p);
              },
            ),
            if (ledger.isEmpty) const KEmpty('No transactions match'),
          ]),
        ),
      ],
    );
  }

  Widget _phone(BuildContext context) {
    final casino = CasinoScope.of(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: KSegment(
          values: const ['Pad', 'History'],
          selected: tab,
          expand: true,
          label: (t) => t,
          onChanged: (t) => setState(() => tab = t),
        ),
      ),
      Expanded(
        child: tab == 'Pad'
            ? const CoinPad()
            : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
                KField(hint: 'Search player or txn ID', icon: Icons.search_rounded, onChanged: (v) => setState(() => q = v)),
                const SizedBox(height: 8),
                KCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Column(children: [for (final t in _ledger(casino).take(60)) TxnTile(t)]),
                ),
              ]),
      ),
    ]);
  }
}

/// Cash App's green pad, for coins: pick a player, type an amount, coin in or out.
class CoinPad extends StatefulWidget {
  const CoinPad({super.key});

  @override
  State<CoinPad> createState() => _CoinPadState();
}

class _CoinPadState extends State<CoinPad> {
  String amount = '0';
  String? playerId;

  /// DC (true) or Gold Coins.
  bool sweeps = true;

  void _digit(String d) => setState(() {
        if (d == '.') {
          if (sweeps && !amount.contains('.')) amount += '.';
        } else if (amount.contains('.') && amount.split('.')[1].length >= 2) {
          return;
        } else if (amount.replaceAll('.', '').length >= (sweeps ? 7 : 9)) {
          return;
        } else {
          amount = amount == '0' ? d : amount + d;
        }
      });

  void _back() => setState(() => amount = amount.length <= 1 ? '0' : amount.substring(0, amount.length - 1));

  Future<void> _go(bool coinIn) async {
    final casino = CasinoScope.read(context);
    final p = playerId == null ? null : casino.player(playerId!);
    final v = double.tryParse(amount) ?? 0;
    if (p == null) {
      kToast(context, 'Choose a player first');
      return;
    }
    if (v <= 0) {
      kToast(context, 'Type an amount');
      return;
    }
    final what = sweeps ? scAmt(v) : gcAmt(v);
    final ok = await kConfirm(
      context,
      title: coinIn ? 'Coin in $what?' : 'Coin out $what?',
      message: coinIn ? '${p.username} gets $what.' : '$what comes off ${p.username}\'s balance.',
      action: coinIn ? 'Coin in' : 'Coin out',
    );
    if (!ok || !mounted) return;
    final sc = sweeps ? v : 0.0, gc = sweeps ? 0.0 : v;
    if (attempt(context, () => coinIn ? casino.coinIn(p, sc: sc, gc: gc) : casino.coinOut(p, sc: sc, gc: gc),
        done: coinIn ? '$what added to ${p.username}' : '$what taken off ${p.username}')) {
      setState(() => amount = '0');
    }
  }

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final p = playerId == null ? null : casino.player(playerId!);
    const onGreen = Colors.white;
    return Container(
      color: K.green,
      child: LayoutBuilder(builder: (context, box) {
        final keyH = ((box.maxHeight - 250) / 4).clamp(40.0, 72.0);
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(children: [
                  Material(
                    color: const Color(0x29000000),
                    shape: const StadiumBorder(),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () async {
                        final picked = await pickPlayer(context);
                        if (picked != null) setState(() => playerId = picked.id);
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (p != null) KAvatar(p.name, size: 28) else const Icon(Icons.person_add_alt_1_rounded, color: onGreen, size: 22),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(p == null ? 'Choose player' : '${p.username} · ${scAmt(p.sc)}',
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(15, w: FontWeight.w600, c: onGreen)),
                          ),
                          const Icon(Icons.expand_more_rounded, color: onGreen, size: 20),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('$amount ${sweeps ? 'DC' : 'GC'}', style: kt(keyH * 1.25, w: FontWeight.w700, c: onGreen, h: 1.15, num: true)),
                  ),
                  const SizedBox(height: 6),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    for (final (sc, label) in const [(true, 'DC'), (false, 'Gold Coins')])
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Semantics(
                          selected: sc == sweeps,
                          button: true,
                          child: Material(
                            color: sc == sweeps ? Colors.white : const Color(0x29000000),
                            shape: const StadiumBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => setState(() {
                                sweeps = sc;
                                if (!sc) amount = amount.split('.').first;
                              }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                child: Text(label, style: kt(14, w: FontWeight.w600, c: sc == sweeps ? K.greenInk : onGreen)),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ]),
                ]),
                Keypad(onDigit: _digit, onBack: _back, dot: sweeps, keyHeight: keyH),
                Row(children: [
                  Expanded(child: _PadButton('Coin out', onTap: () => _go(false))),
                  const SizedBox(width: 12),
                  Expanded(child: _PadButton('Coin in', onTap: () => _go(true))),
                ]),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton(this.label, {required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0x29000000),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(height: 52, child: Center(child: Text(label, style: kt(17, w: FontWeight.w700, c: Colors.white)))),
        ),
      );
}
