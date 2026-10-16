import 'package:flutter/material.dart';

import '../backoffice/casino.dart';
import 'admin_app.dart';
import 'kit.dart';
import 'players.dart';

const cashMethods = ['Cash App', 'Cash', 'Card', 'Bank'];

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
    final list = casino.players.reversed
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

/// Load a player's account.
Future<void> showCashIn(BuildContext context, {Player? player}) async {
  final p = player ?? await pickPlayer(context);
  if (p == null || !context.mounted) return;
  await kSheet<void>(context, title: 'Cash in', builder: (_) => _CashInForm(p));
}

class _CashInForm extends StatefulWidget {
  const _CashInForm(this.p);
  final Player p;

  @override
  State<_CashInForm> createState() => _CashInFormState();
}

class _CashInFormState extends State<_CashInForm> {
  final amount = TextEditingController();
  late final bonus = TextEditingController(text: _trim(CasinoScope.read(context).settings.cashInBonusPct));
  final note = TextEditingController();
  String method = cashMethods.first;

  @override
  void dispose() {
    amount.dispose();
    bonus.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final dollars = amountOf(amount.text) ?? 0;
    final b = amountOf(bonus.text) ?? 0;
    final coins = casino.coinsFor(dollars, bonusPct: b);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _PlayerChip(widget.p),
      const SizedBox(height: 16),
      KField(
        label: 'Amount paid',
        controller: amount,
        prefix: '\$ ',
        hint: '0.00',
        autofocus: true,
        keyboard: const TextInputType.numberWithOptions(decimal: true),
        formatters: KField.money,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final v in const [10, 20, 50, 100, 200])
          ActionChip(
            label: Text('\$$v', style: kt(14, w: FontWeight.w600)),
            backgroundColor: K.field,
            side: BorderSide.none,
            shape: const StadiumBorder(),
            onPressed: () => setState(() => amount.text = '$v'),
          ),
      ]),
      const SizedBox(height: 14),
      Text('Paid with', style: kt(13, w: FontWeight.w600, c: K.sub)),
      const SizedBox(height: 6),
      KSegment(values: cashMethods, selected: method, label: (m) => m, onChanged: (m) => setState(() => method = m)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: KField(
            label: 'Bonus %',
            controller: bonus,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            formatters: KField.money,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: KField(label: 'Note (optional)', controller: note)),
      ]),
      const SizedBox(height: 16),
      KCard(
        color: K.greenSoft,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const Icon(Icons.south_west_rounded, color: K.greenInk),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${widget.p.username} gets ${gcAmt(coins.gc)} + ${scAmt(coins.sc)}',
                style: kt(15, w: FontWeight.w600, c: K.greenInk)),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      KButton(
        dollars > 0 ? 'Cash in ${usd(dollars)}' : 'Cash in',
        expand: true,
        onTap: dollars <= 0
            ? null
            : () {
                if (attempt(context, () => casino.cashIn(widget.p, dollars, method: method, bonusPct: b, note: note.text.trim()),
                    done: '${usd(dollars)} cashed in to ${widget.p.username}')) {
                  Navigator.of(context).pop();
                }
              },
      ),
    ]);
  }
}

String _trim(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Pay a player out.
Future<void> showCashOut(BuildContext context, {Player? player}) async {
  final p = player ?? await pickPlayer(context);
  if (p == null || !context.mounted) return;
  await kSheet<void>(context, title: 'Cash out', builder: (_) => _CashOutForm(p));
}

class _CashOutForm extends StatefulWidget {
  const _CashOutForm(this.p);
  final Player p;

  @override
  State<_CashOutForm> createState() => _CashOutFormState();
}

class _CashOutFormState extends State<_CashOutForm> {
  final amount = TextEditingController();
  final note = TextEditingController();
  String method = cashMethods.first;
  bool payNow = true;

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final sc = amountOf(amount.text) ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _PlayerChip(widget.p),
      const SizedBox(height: 16),
      KField(
        label: 'Sweeps Coins to cash out',
        controller: amount,
        hint: '0.00',
        autofocus: true,
        keyboard: const TextInputType.numberWithOptions(decimal: true),
        formatters: KField.money,
        suffix: TextButton(
          onPressed: () => setState(() => amount.text = widget.p.sc.toStringAsFixed(2)),
          child: Text('All', style: kt(14, w: FontWeight.w700, c: K.greenInk)),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 6),
      Text('Balance ${scAmt(widget.p.sc)} · 1 SC = ${usd(casino.settings.usdPerSc)}', style: kt(13, c: K.sub)),
      const SizedBox(height: 14),
      Text('Pay with', style: kt(13, w: FontWeight.w600, c: K.sub)),
      const SizedBox(height: 6),
      KSegment(values: cashMethods, selected: method, label: (m) => m, onChanged: (m) => setState(() => method = m)),
      const SizedBox(height: 6),
      KRow(
        title: 'Pay now',
        sub: payNow ? 'Paid and closed at once' : 'Goes to the pending queue for approval',
        trailing: KSwitch(value: payNow, label: 'Pay now', onChanged: (v) => setState(() => payNow = v)),
      ),
      KField(label: 'Note (optional)', controller: note),
      const SizedBox(height: 16),
      KButton(
        sc > 0 ? 'Cash out ${usd(sc * casino.settings.usdPerSc)}' : 'Cash out',
        tone: KTone.dark,
        expand: true,
        onTap: sc <= 0
            ? null
            : () {
                if (attempt(context, () => casino.cashOut(widget.p, sc, method: method, review: !payNow, note: note.text.trim()),
                    done: payNow ? 'Paid ${usd(sc * casino.settings.usdPerSc)} to ${widget.p.username}' : 'Sent for approval')) {
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
        Expanded(child: KField(label: 'Sweeps Coins', controller: sc, hint: '0.00', keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: KField.money)),
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
/// A ledger line: who, what, how much.
class TxnTile extends StatelessWidget {
  const TxnTile(this.t, {super.key, this.showPlayer = true});
  final Txn t;
  final bool showPlayer;

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final p = casino.player(t.playerId);
    final out = t.type == TxnType.cashOut;
    final money = t.type == TxnType.cashIn || out;
    final amount = money
        ? '${out ? '−' : '+'}${usd(t.usd)}'
        : t.sc != 0
            ? '${t.sc > 0 ? '+' : '−'}${scAmt(t.sc.abs())}'
            : '${t.gc > 0 ? '+' : '−'}${compact(t.gc.abs())} GC';
    final icon = switch (t.type) {
      TxnType.cashIn => Icons.south_west_rounded,
      TxnType.cashOut => Icons.north_east_rounded,
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
            decoration: BoxDecoration(shape: BoxShape.circle, color: t.type == TxnType.cashIn ? K.greenSoft : K.field),
            child: Icon(icon, size: 20, color: t.type == TxnType.cashIn ? K.greenInk : K.text),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(showPlayer ? (p?.username ?? t.playerId) : statusName(t.type),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(15, w: FontWeight.w600)),
              Text(
                [
                  if (showPlayer) statusName(t.type),
                  if (t.method.isNotEmpty) t.method,
                  when(t.at, casino.now),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kt(13, c: K.sub),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(amount, style: kt(15, w: FontWeight.w700, c: t.type == TxnType.cashIn ? K.greenInk : K.text, num: true)),
            if (t.status != TxnStatus.approved) KBadge.txn(t.status),
          ]),
        ]),
      ),
    );
  }
}

/// A cash out waiting for a decision.
class PendingTile extends StatelessWidget {
  const PendingTile(this.t, {super.key});
  final Txn t;

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final p = casino.player(t.playerId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        KAvatar(p?.name ?? '?', size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p?.username ?? t.playerId} · ${usd(t.usd)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(15, w: FontWeight.w700)),
            Text('${t.method.isEmpty ? '' : '${t.method} · '}${ago(t.at, casino.now)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(13, c: K.sub)),
          ]),
        ),
        KIconButton(Icons.close_rounded, tooltip: 'Reject', size: 38, color: K.redSoft, fg: K.red, onTap: () async {
          if (await kConfirm(context,
                  title: 'Reject this cash out?',
                  message: '${scAmt(-t.sc)} goes back to ${p?.username ?? 'the player'}.',
                  action: 'Reject',
                  danger: true) &&
              context.mounted) {
            casino.reject(t, reason: 'Rejected by ${casino.actor}');
            kToast(context, 'Rejected — SC returned');
          }
        }),
        const SizedBox(width: 8),
        KButton('Pay', height: 38, onTap: () {
          casino.approve(t);
          kToast(context, 'Paid ${usd(t.usd)} to ${p?.username ?? t.playerId}');
        }),
      ]),
    );
  }
}

// ── Drawer ───────────────────────────────────────────────────────────────────
/// The signed-in cashier's drawer: start with a counted starting amount,
/// close by counting what's there.
class ShiftCard extends StatelessWidget {
  const ShiftCard({super.key});

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final s = casino.myShift;
    if (s == null) {
      return KCard(
        child: Row(children: [
          const Icon(Icons.point_of_sale_rounded, color: K.sub),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Drawer closed', style: kt(16, w: FontWeight.w700)),
              Text('Count the starting amount to open your shift', style: kt(13, c: K.sub)),
            ]),
          ),
          const SizedBox(width: 8),
          KButton('Start shift', height: 40, onTap: () => _amountSheet(context, start: true)),
        ]),
      );
    }
    final sum = casino.summary(s);
    return KCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: K.green)),
          const SizedBox(width: 8),
          Expanded(child: Text('Shift open since ${clock(s.start)}', style: kt(16, w: FontWeight.w700))),
          KButton('Close shift', height: 38, tone: KTone.dark, onTap: () => _amountSheet(context, start: false)),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 22, runSpacing: 10, children: [
          _mini('Starting amount', usd(s.startAmount)),
          _mini('Cash taken', '+${usd(sum.drawerIn)}'),
          _mini('Cash paid', '−${usd(sum.drawerOut)}'),
          _mini('Expected in drawer', usd(sum.expected), strong: true),
          _mini('All methods', '${sum.ins} in · ${sum.outs} out'),
        ]),
      ]),
    );
  }

  static Widget _mini(String label, String value, {bool strong = false}) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: kt(12, c: K.sub)),
        Text(value, style: kt(strong ? 18 : 16, w: FontWeight.w700, c: strong ? K.greenInk : K.text, num: true)),
      ]);

  static void _amountSheet(BuildContext context, {required bool start}) {
    final c = TextEditingController();
    kSheet<void>(
      context,
      title: start ? 'Start shift' : 'Close shift',
      builder: (ctx) {
        final casino = CasinoScope.read(ctx);
        final s = casino.myShift;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
              start
                  ? 'Count the cash in the drawer. This is your starting amount.'
                  : 'Count the cash in the drawer. Expected: ${usd(casino.summary(s!).expected)}.',
              style: kt(15, c: K.sub, h: 1.4)),
          const SizedBox(height: 14),
          KField(
              label: start ? 'Starting amount' : 'Counted amount',
              controller: c,
              prefix: '\$ ',
              hint: '0.00',
              autofocus: true,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
              formatters: KField.money),
          const SizedBox(height: 16),
          KButton(start ? 'Open drawer' : 'Close drawer', expand: true, tone: start ? KTone.green : KTone.dark, onTap: () {
            final v = amountOf(c.text);
            if (v == null) {
              kToast(ctx, 'Enter the amount');
              return;
            }
            if (start) {
              if (attempt(ctx, () => casino.startShift(v), done: 'Shift started with ${usd(v)}')) Navigator.of(ctx).pop();
            } else {
              casino.closeShift(s!, v);
              final d = casino.summary(s).difference!;
              Navigator.of(ctx).pop();
              kToast(context, d.abs() < .005 ? 'Drawer balanced' : 'Drawer ${d > 0 ? 'over' : 'short'} by ${usd(d.abs())}');
            }
          }),
        ]);
      },
    ).whenComplete(c.dispose);
  }
}

// ── Page ─────────────────────────────────────────────────────────────────────
class CashPage extends StatefulWidget {
  const CashPage({super.key});

  @override
  State<CashPage> createState() => _CashPageState();
}

class _CashPageState extends State<CashPage> {
  String tab = 'Pay';
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

    return [
      for (final t in casino.txns.reversed)
        if ((type == null || t.type == type) && hit(t)) t,
    ];
  }

  Widget _desktop(BuildContext context) {
    final casino = CasinoScope.of(context);
    final r = casino.report(Period.standard(casino.now).first);
    final pending = casino.pendingCashOuts;
    final ledger = _ledger(casino).take(60).toList();
    return DeskPage(
      title: 'Cash in / out',
      sub: 'Load accounts, pay out winnings, review requests',
      actions: [
        KButton('Cash out', tone: KTone.dark, icon: Icons.north_east_rounded, onTap: () => showCashOut(context)),
        KButton('Cash in', icon: Icons.south_west_rounded, onTap: () => showCashIn(context)),
      ],
      children: [
        KGrid(min: 190, children: [
          KStat(label: 'Cash in today', value: usd(r.cashInUsd), sub: '${r.cashIns} payments', icon: Icons.south_west_rounded, color: K.greenInk),
          KStat(label: 'Cash out today', value: usd(r.cashOutUsd), sub: '${r.cashOuts} payouts', icon: Icons.north_east_rounded),
          KStat(label: 'Net today', value: usd(r.netCash), icon: Icons.account_balance_wallet_outlined, color: r.netCash < 0 ? K.red : K.text),
          KStat(label: 'Waiting for approval', value: usd(pending.fold(0, (a, t) => a + t.usd)), sub: '${pending.length} requests', icon: Icons.schedule_rounded, color: pending.isEmpty ? K.text : K.amber),
        ]),
        const SizedBox(height: 16),
        const ShiftCard(),
        const SizedBox(height: 16),
        KCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KTitle('Pending cash outs', trailing: Text('${pending.length}', style: kt(15, c: K.sub))),
            if (pending.isEmpty) const KEmpty('Nothing waiting — all caught up', icon: Icons.task_alt_rounded),
            for (final t in pending) PendingTile(t),
          ]),
        ),
        const SizedBox(height: 16),
        KCard(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('Ledger', style: kt(18, w: FontWeight.w700)),
                KSegment<TxnType?>(
                  values: const [null, TxnType.cashIn, TxnType.cashOut, TxnType.bonus, TxnType.start, TxnType.adjust],
                  selected: type,
                  label: (t) => t == null ? 'All' : statusName(t),
                  onChanged: (t) => setState(() => type = t),
                ),
                SizedBox(width: 260, child: KField(hint: 'Search player or txn ID', icon: Icons.search_rounded, onChanged: (v) => setState(() => q = v))),
              ]),
            ),
            const SizedBox(height: 10),
            KTable(
              minWidth: 820,
              columns: const ['Player', 'Type', 'Method', 'When', 'Money', 'Coins', 'Status', 'By'],
              numeric: const {4, 5},
              rows: [
                for (final t in ledger)
                  [
                    cellText(casino.player(t.playerId)?.username ?? t.playerId, w: FontWeight.w600),
                    cellText(statusName(t.type)),
                    cellText(t.method.isEmpty ? '—' : t.method, c: K.sub),
                    cellText(when(t.at, casino.now), c: K.sub, size: 13),
                    cellText(t.usd == 0 ? '—' : '${t.type == TxnType.cashOut ? '−' : '+'}${usd(t.usd)}',
                        c: t.type == TxnType.cashIn ? K.greenInk : K.text, w: FontWeight.w600),
                    cellText([if (t.gc != 0) '${compact(t.gc)} GC', if (t.sc != 0) '${grouped(t.sc)} SC'].join(' · '), c: K.sub, size: 13),
                    KBadge.txn(t.status),
                    cellText(t.settledBy ?? t.by, c: K.sub, size: 13),
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
    final pending = casino.pendingCashOuts;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: KSegment(
          values: const ['Pay', 'Pending', 'History'],
          selected: tab,
          expand: true,
          label: (t) => t == 'Pending' && pending.isNotEmpty ? 'Pending ${pending.length}' : t,
          onChanged: (t) => setState(() => tab = t),
        ),
      ),
      Expanded(
        child: switch (tab) {
          'Pay' => const CashPad(),
          'Pending' => ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
              const ShiftCard(),
              const SizedBox(height: 12),
              KCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (pending.isEmpty) const KEmpty('Nothing waiting — all caught up', icon: Icons.task_alt_rounded),
                  for (final t in pending) PendingTile(t),
                ]),
              ),
            ]),
          _ => ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
              KField(hint: 'Search player or txn ID', icon: Icons.search_rounded, onChanged: (v) => setState(() => q = v)),
              const SizedBox(height: 8),
              KCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(children: [for (final t in _ledger(casino).take(60)) TxnTile(t)]),
              ),
            ]),
        },
      ),
    ]);
  }
}

/// Cash App's green pad: pick a player, type an amount, cash in or out.
class CashPad extends StatefulWidget {
  const CashPad({super.key});

  @override
  State<CashPad> createState() => _CashPadState();
}

class _CashPadState extends State<CashPad> {
  String amount = '0';
  String? playerId;
  String method = cashMethods.first;

  void _digit(String d) => setState(() {
        if (d == '.') {
          if (!amount.contains('.')) amount += '.';
        } else if (amount.contains('.') && amount.split('.')[1].length >= 2) {
          return;
        } else if (amount.replaceAll('.', '').length >= 7) {
          return;
        } else {
          amount = amount == '0' ? d : amount + d;
        }
      });

  void _back() => setState(() => amount = amount.length <= 1 ? '0' : amount.substring(0, amount.length - 1));

  Future<void> _go(bool cashIn) async {
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
    final sc = v / casino.settings.usdPerSc;
    final coins = casino.coinsFor(v);
    final ok = await kConfirm(
      context,
      title: cashIn ? 'Cash in ${usd(v)}?' : 'Cash out ${usd(v)}?',
      message: cashIn
          ? '${p.username} paid ${usd(v)} by $method and gets ${gcAmt(coins.gc)} + ${scAmt(coins.sc)}.'
          : '${scAmt(sc)} comes off ${p.username}\'s balance and you pay ${usd(v)} by $method.',
      action: cashIn ? 'Cash in' : 'Cash out',
    );
    if (!ok || !mounted) return;
    if (attempt(context, () => cashIn ? casino.cashIn(p, v, method: method) : casino.cashOut(p, sc, method: method, review: false),
        done: cashIn ? '${usd(v)} cashed in to ${p.username}' : 'Paid ${usd(v)} to ${p.username}')) {
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
                    child: Text('\$$amount', style: kt(keyH * 1.25, w: FontWeight.w700, c: onGreen, h: 1.15, num: true)),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (final m in cashMethods)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Semantics(
                            selected: m == method,
                            button: true,
                            child: Material(
                              color: m == method ? Colors.white : const Color(0x29000000),
                              shape: const StadiumBorder(),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => setState(() => method = m),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  child: Text(m, style: kt(14, w: FontWeight.w600, c: m == method ? K.greenInk : onGreen)),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ]),
                  ),
                ]),
                Keypad(onDigit: _digit, onBack: _back, dot: true, keyHeight: keyH),
                Row(children: [
                  Expanded(child: _PadButton('Cash out', onTap: () => _go(false))),
                  const SizedBox(width: 12),
                  Expanded(child: _PadButton('Cash in', onTap: () => _go(true))),
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
