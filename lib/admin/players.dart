import 'package:flutter/material.dart';

import '../app/assets.dart' show games;
import '../backoffice/casino.dart';
import 'admin_app.dart';
import 'coins.dart';
import 'kit.dart';

/// Open a player's profile: beside the list on a wide screen, else full page.
void openPlayer(BuildContext context, Player p) {
  final host = context is StatefulElement && context.state is _PlayersPageState
      ? context.state as _PlayersPageState
      : context.findAncestorStateOfType<_PlayersPageState>();
  if (host != null && host.mounted && host.sidePane) {
    host.select(p.id);
    return;
  }
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PlayerScreen(playerId: p.id)));
}

class PlayersPage extends StatefulWidget {
  const PlayersPage({super.key});

  @override
  State<PlayersPage> createState() => _PlayersPageState();
}

enum _Sort { newest, balance, coinIn, lastSeen }

class _PlayersPageState extends State<PlayersPage> {
  String q = '';
  PlayerStatus? status;
  _Sort sort = _Sort.newest;
  String? selected;

  bool get sidePane => MediaQuery.sizeOf(context).width >= 1240;
  void select(String id) => setState(() => selected = id);

  List<Player> _list(Casino casino) {
    final l = casino.players.where((p) => (status == null || p.status == status) && matchesPlayer(p, q)).toList();
    switch (sort) {
      case _Sort.newest:
        l.sort((a, b) => b.created.compareTo(a.created));
      case _Sort.balance:
        l.sort((a, b) => b.sc.compareTo(a.sc));
      case _Sort.coinIn:
        final t = {for (final p in l) p.id: casino.coinInTotal(p.id)};
        l.sort((a, b) => t[b.id]!.compareTo(t[a.id]!));
      case _Sort.lastSeen:
        l.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    }
    return l;
  }

  Widget _filters({required bool wide}) => Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: wide ? 300 : double.infinity,
          child: KField(hint: 'Search name, username, ID or phone', icon: Icons.search_rounded, onChanged: (v) => setState(() => q = v)),
        ),
        KSegment<PlayerStatus?>(
          values: const [null, PlayerStatus.active, PlayerStatus.suspended, PlayerStatus.banned],
          selected: status,
          label: (s) => s == null ? 'All' : statusName(s),
          onChanged: (s) => setState(() => status = s),
        ),
        if (wide)
          KSegment<_Sort>(
            values: _Sort.values,
            selected: sort,
            label: (s) => switch (s) { _Sort.newest => 'Newest', _Sort.balance => 'Balance', _Sort.coinIn => 'Coin in', _Sort.lastSeen => 'Last seen' },
            onChanged: (s) => setState(() => sort = s),
          ),
      ]);

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final list = _list(casino);
    if (!K.desktop(context)) {
      return Stack(children: [
        ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: [
          _filters(wide: false),
          const SizedBox(height: 12),
          Text('${list.length} of ${casino.players.length} players · ${casino.online} online', style: kt(13, c: K.sub)),
          const SizedBox(height: 8),
          KCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(children: [
              if (list.isEmpty) const KEmpty('No players match', icon: Icons.person_search_outlined),
              for (final p in list) _PlayerRow(p),
            ]),
          ),
        ]),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'new-player',
            backgroundColor: K.green,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            onPressed: () => showCreatePlayer(context),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text('New player ID', style: kt(16, w: FontWeight.w700, c: Colors.white)),
          ),
        ),
      ]);
    }
    final pane = sidePane && selected != null && casino.player(selected!) != null;
    final page = DeskPage(
      title: 'Players',
      sub: '${casino.players.length} players · ${casino.online} online now',
      actions: [
        KButton('Bulk create', tone: KTone.light, icon: Icons.group_add_outlined, onTap: () => showBulkCreate(context)),
        KButton('New player ID', icon: Icons.person_add_alt_1_rounded, onTap: () => showCreatePlayer(context)),
      ],
      children: [
        _filters(wide: true),
        const SizedBox(height: 14),
        KCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: list.isEmpty
              ? const KEmpty('No players match', icon: Icons.person_search_outlined)
              : KTable(
                  minWidth: 860,
                  columns: const ['Player', 'ID', 'Sweeps Coins', 'Gold Coins', 'Coin in SC (all time)', 'Status', 'Last seen'],
                  numeric: const {2, 3, 4},
                  rows: [
                    for (final p in list)
                      [
                        Row(children: [
                          KAvatar(p.name, size: 32),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              cellText(p.username, w: FontWeight.w600),
                              cellText(p.name, c: K.sub, size: 12),
                            ]),
                          ),
                        ]),
                        cellText(p.id, c: K.sub, size: 13),
                        cellText(grouped(p.sc), w: FontWeight.w600),
                        cellText(compact(p.gc), c: K.sub),
                        cellText(grouped(casino.coinInTotal(p.id))),
                        KBadge.player(p.status),
                        cellText(ago(p.lastSeen, casino.now), c: K.sub, size: 13),
                      ],
                  ],
                  onTap: (i) => openPlayer(context, list[i]),
                ),
        ),
      ],
    );
    if (!pane) return page;
    return Row(children: [
      Expanded(child: page),
      Container(
        width: 420,
        decoration: const BoxDecoration(color: K.card, border: Border(left: BorderSide(color: K.line))),
        child: PlayerDetail(key: ValueKey(selected), playerId: selected!, onClose: () => setState(() => selected = null)),
      ),
    ]);
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow(this.p);
  final Player p;

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    return InkWell(
      onTap: () => openPlayer(context, p),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          KAvatar(p.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.username, maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(16, w: FontWeight.w600)),
              Text('${p.id} · ${ago(p.lastSeen, casino.now)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(13, c: K.sub)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(scAmt(p.sc), style: kt(15, w: FontWeight.w700, num: true)),
            if (p.status != PlayerStatus.active) KBadge.player(p.status) else Text('${compact(p.gc)} GC', style: kt(12, c: K.sub)),
          ]),
        ]),
      ),
    );
  }
}

// ── New player IDs ───────────────────────────────────────────────────────────
Future<void> showCreatePlayer(BuildContext context) =>
    kSheet<void>(context, title: 'New player ID', builder: (_) => const _CreatePlayer(), width: 520);

class _CreatePlayer extends StatefulWidget {
  const _CreatePlayer();

  @override
  State<_CreatePlayer> createState() => _CreatePlayerState();
}

class _CreatePlayerState extends State<_CreatePlayer> {
  late final casino = CasinoScope.read(context);
  late final username = TextEditingController(text: casino.suggestUsername());
  final name = TextEditingController(), phone = TextEditingController(), email = TextEditingController(), note = TextEditingController();
  late final password = TextEditingController(text: casino.newPassword());
  late final startGc = TextEditingController(text: casino.settings.newPlayerGc.toStringAsFixed(0));
  late final startSc = TextEditingController(text: casino.settings.newPlayerSc.toStringAsFixed(2));
  Player? made;

  @override
  void dispose() {
    for (final c in [username, name, phone, email, note, password, startGc, startSc]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = made;
    if (p != null) return CredentialsCard(p, onDone: () => Navigator.of(context).pop(), offerCoinIn: true);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: KField(label: 'Username', controller: username, icon: Icons.alternate_email_rounded)),
        const SizedBox(width: 12),
        Expanded(child: KField(label: 'Name (optional)', controller: name)),
      ]),
      const SizedBox(height: 12),
      KField(
        label: 'Password',
        controller: password,
        icon: Icons.key_rounded,
        suffix: IconButton(
          tooltip: 'New password',
          icon: const Icon(Icons.refresh_rounded, color: K.sub),
          onPressed: () => setState(() => password.text = casino.newPassword()),
        ),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: KField(label: 'Phone (optional)', controller: phone, keyboard: TextInputType.phone)),
        const SizedBox(width: 12),
        Expanded(child: KField(label: 'Email (optional)', controller: email, keyboard: TextInputType.emailAddress)),
      ]),
      const SizedBox(height: 16),
      Text('Starting amount', style: kt(15, w: FontWeight.w700)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: KField(label: 'Gold Coins', controller: startGc, keyboard: TextInputType.number, formatters: KField.money)),
        const SizedBox(width: 12),
        Expanded(child: KField(label: 'Sweeps Coins', controller: startSc, keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: KField.money)),
      ]),
      const SizedBox(height: 12),
      KField(label: 'Note (optional)', controller: note, hint: 'e.g. Referred by luckylina'),
      const SizedBox(height: 18),
      KButton('Create player ID', expand: true, icon: Icons.person_add_alt_1_rounded, onTap: () {
        attempt(context, () {
          final p = casino.createPlayer(
            username: username.text,
            name: name.text,
            password: password.text.trim(),
            phone: phone.text.trim(),
            email: email.text.trim(),
            note: note.text,
            startGc: amountOf(startGc.text) ?? 0,
            startSc: amountOf(startSc.text) ?? 0,
          );
          setState(() => made = p);
        });
      }),
    ]);
  }
}

/// The new account's login, ready to hand to the player.
class CredentialsCard extends StatelessWidget {
  const CredentialsCard(this.p, {super.key, required this.onDone, this.offerCoinIn = false});
  final Player p;
  final VoidCallback onDone;
  final bool offerCoinIn;

  String get login => 'Zoya7 login\nPlayer ID: ${p.id}\nUsername: ${p.username}\nPassword: ${p.password}';

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Center(
          child: CircleAvatar(radius: 32, backgroundColor: K.green, child: Icon(Icons.check_rounded, color: Colors.white, size: 38)),
        ),
        const SizedBox(height: 12),
        Text('Player ID created', textAlign: TextAlign.center, style: kt(22, w: FontWeight.w800)),
        Text('Starting amount ${gcAmt(p.startGc)} + ${scAmt(p.startSc)}', textAlign: TextAlign.center, style: kt(14, c: K.sub)),
        const SizedBox(height: 16),
        KCard(
          color: K.field,
          child: Column(children: [
            for (final (k, v) in [('Player ID', p.id), ('Username', p.username), ('Password', p.password)])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  SizedBox(width: 92, child: Text(k, style: kt(14, c: K.sub))),
                  Expanded(child: SelectableText(v, style: kt(17, w: FontWeight.w700, num: true))),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 14),
        KButton('Copy login', tone: KTone.dark, icon: Icons.copy_rounded, expand: true, onTap: () => copy(context, login, 'Login')),
        const SizedBox(height: 10),
        Row(children: [
          if (offerCoinIn) ...[
            Expanded(
              child: KButton('Coin in now', icon: Icons.south_west_rounded, onTap: () {
                // The sheet closes; open the next one from the navigator.
                final host = Navigator.of(context).context;
                onDone();
                showCoinIn(host, player: p);
              }),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(child: KButton('Done', tone: KTone.light, onTap: onDone)),
        ]),
      ]);
}

Future<void> showBulkCreate(BuildContext context) =>
    kSheet<void>(context, title: 'Bulk create player IDs', builder: (_) => const _BulkCreate(), width: 560);

class _BulkCreate extends StatefulWidget {
  const _BulkCreate();

  @override
  State<_BulkCreate> createState() => _BulkCreateState();
}

class _BulkCreateState extends State<_BulkCreate> {
  late final casino = CasinoScope.read(context);
  final count = TextEditingController(text: '10'), prefix = TextEditingController(text: 'shop');
  late final startGc = TextEditingController(text: casino.settings.newPlayerGc.toStringAsFixed(0));
  late final startSc = TextEditingController(text: casino.settings.newPlayerSc.toStringAsFixed(2));
  List<Player>? made;

  @override
  void dispose() {
    for (final c in [count, prefix, startGc, startSc]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = made;
    if (m != null) {
      final csv = StringBuffer('Player ID,Username,Password\n');
      for (final p in m) {
        csv.writeln('${p.id},${p.username},${p.password}');
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${m.length} player IDs created', style: kt(18, w: FontWeight.w700)),
        const SizedBox(height: 10),
        KCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: KTable(minWidth: 380, columns: const ['Username', 'Player ID', 'Password'], rows: [
            for (final p in m) [cellText(p.username, w: FontWeight.w600), cellText(p.id, c: K.sub), cellText(p.password)],
          ]),
        ),
        const SizedBox(height: 14),
        KButton('Copy all (CSV)', tone: KTone.dark, icon: Icons.copy_rounded, expand: true, onTap: () => copy(context, csv.toString(), 'Logins')),
        const SizedBox(height: 10),
        KButton('Done', tone: KTone.light, expand: true, onTap: () => Navigator.of(context).pop()),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Make a batch of accounts to hand out (e.g. for a store). Each gets its own password.', style: kt(15, c: K.sub, h: 1.4)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: KField(label: 'How many', controller: count, keyboard: TextInputType.number, formatters: KField.money)),
        const SizedBox(width: 12),
        Expanded(child: KField(label: 'Username prefix', controller: prefix)),
      ]),
      const SizedBox(height: 6),
      Text('Names run ${prefix.text.isEmpty ? 'prefix' : prefix.text}001, ${prefix.text.isEmpty ? 'prefix' : prefix.text}002…', style: kt(13, c: K.sub)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: KField(label: 'Starting GC each', controller: startGc, keyboard: TextInputType.number, formatters: KField.money)),
        const SizedBox(width: 12),
        Expanded(child: KField(label: 'Starting SC each', controller: startSc, keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: KField.money)),
      ]),
      const SizedBox(height: 18),
      KButton('Create IDs', expand: true, icon: Icons.group_add_rounded, onTap: () {
        attempt(context, () {
          final r = casino.bulkCreate((amountOf(count.text) ?? 0).round(), prefix.text.trim().isEmpty ? 'player' : prefix.text.trim(),
              startGc: amountOf(startGc.text) ?? 0, startSc: amountOf(startSc.text) ?? 0);
          setState(() => made = r);
        });
      }),
    ]);
  }
}

// ── Profile ──────────────────────────────────────────────────────────────────
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key, required this.playerId});
  final String playerId;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: K.card,
        appBar: AppBar(
          backgroundColor: K.card,
          surfaceTintColor: Colors.transparent,
          title: Text('Player', style: kt(18, w: FontWeight.w700)),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: PlayerDetail(playerId: playerId)),
          ),
        ),
      );
}

class PlayerDetail extends StatefulWidget {
  const PlayerDetail({super.key, required this.playerId, this.onClose});
  final String playerId;
  final VoidCallback? onClose;

  @override
  State<PlayerDetail> createState() => _PlayerDetailState();
}

class _PlayerDetailState extends State<PlayerDetail> {
  bool showPw = false;

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final p = casino.player(widget.playerId);
    if (p == null) return const KEmpty('This player was deleted', icon: Icons.person_off_outlined);
    final txns = casino.txnsOf(p.id);
    final coinIn = txns.where((t) => t.type == TxnType.coinIn).fold<double>(0, (a, t) => a + t.sc);
    final coinOut = txns.where((t) => t.type == TxnType.coinOut).fold<double>(0, (a, t) => a - t.sc);
    final plays = casino.plays.values.where((x) => x.playerId == p.id);
    final byGame = <String, ({int rounds, double w, double win})>{};
    for (final x in plays) {
      final g = byGame[x.gameId] ?? (rounds: 0, w: 0.0, win: 0.0);
      byGame[x.gameId] = (rounds: g.rounds + x.rounds, w: g.w + x.wSc, win: g.win + x.winSc);
    }
    final wagered = byGame.values.fold<double>(0, (a, g) => a + g.w), won = byGame.values.fold<double>(0, (a, g) => a + g.win);
    final canManage = casino.admin?.canManage ?? false;

    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        KAvatar(p.name, size: 60),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(22, w: FontWeight.w800)),
            Text('@${p.username}', style: kt(15, c: K.sub)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              InkWell(
                onTap: () => copy(context, p.id, 'Player ID'),
                borderRadius: BorderRadius.circular(20),
                child: KBadge(p.id, fg: K.text, bg: K.field),
              ),
              KBadge.player(p.status),
            ]),
          ]),
        ),
        if (widget.onClose != null) KIconButton(Icons.close_rounded, tooltip: 'Close', size: 36, onTap: widget.onClose),
      ]),
      const SizedBox(height: 18),
      // Cash App's balance card.
      KCard(
        color: K.ink,
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Sweeps Coins', style: kt(14, c: const Color(0xB3FFFFFF))),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(grouped(p.sc), style: kt(40, w: FontWeight.w700, c: Colors.white, num: true)),
          ),
          Text('${gcAmt(p.gc)} · no cash value', style: kt(14, c: const Color(0xB3FFFFFF))),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: KButton('Coin in', height: 44, onTap: p.status == PlayerStatus.active ? () => showCoinIn(context, player: p) : null)),
            const SizedBox(width: 10),
            Expanded(
              child: Material(
                color: const Color(0x33FFFFFF),
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => showCoinOut(context, player: p),
                  child: SizedBox(height: 44, child: Center(child: Text('Coin out', style: kt(16, w: FontWeight.w700, c: Colors.white)))),
                ),
              ),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _Action(Icons.card_giftcard_rounded, 'Bonus', () => showCredit(context, p, TxnType.bonus)),
        if (canManage) _Action(Icons.tune_rounded, 'Adjust', () => showCredit(context, p, TxnType.adjust)),
        _Action(Icons.edit_outlined, 'Edit', () => _edit(context, p)),
        _Action(Icons.key_rounded, 'Reset password', () async {
          if (await kConfirm(context, title: 'Reset password?', message: '${p.username} will need the new password to log in.', action: 'Reset') && context.mounted) {
            casino.resetPassword(p);
            setState(() => showPw = true);
            kToast(context, 'New password: ${p.password}');
          }
        }),
        if (p.status == PlayerStatus.active)
          _Action(Icons.pause_circle_outline_rounded, 'Suspend', () => casino.setPlayerStatus(p, PlayerStatus.suspended))
        else
          _Action(Icons.play_circle_outline_rounded, 'Reactivate', () => casino.setPlayerStatus(p, PlayerStatus.active)),
        if (canManage && p.status != PlayerStatus.banned)
          _Action(Icons.block_rounded, 'Ban', () async {
            if (await kConfirm(context, title: 'Ban ${p.username}?', message: 'They won’t be able to log in or get coins.', action: 'Ban', danger: true)) {
              casino.setPlayerStatus(p, PlayerStatus.banned);
            }
          }, danger: true),
        if (canManage && p.id != Casino.meId)
          _Action(Icons.delete_outline_rounded, 'Delete', () async {
            if (await kConfirm(context,
                    title: 'Delete ${p.username}?',
                    message: 'The account goes away; its ledger lines stay in the reports.',
                    action: 'Delete',
                    danger: true) &&
                context.mounted) {
              attempt(context, () => casino.deletePlayer(p), done: 'Player deleted');
              widget.onClose?.call();
              if (widget.onClose == null) Navigator.of(context).maybePop();
            }
          }, danger: true),
      ]),
      const SizedBox(height: 18),
      KTitle('Login', size: 16, trailing: TextButton(onPressed: () => copy(context, 'Player ID: ${p.id}\nUsername: ${p.username}\nPassword: ${p.password}', 'Login'), child: Text('Copy', style: kt(14, w: FontWeight.w700, c: K.greenInk)))),
      KCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(children: [
          _info('Username', p.username),
          Row(children: [
            Expanded(child: _info('Password', showPw ? p.password : '••••••••')),
            IconButton(
              tooltip: showPw ? 'Hide password' : 'Show password',
              onPressed: () => setState(() => showPw = !showPw),
              icon: Icon(showPw ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: K.sub, size: 20),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 18),
      const KTitle('Coins', size: 16),
      KGrid(min: 150, gap: 10, children: [
        _stat('Coin in (SC)', grouped(coinIn), K.greenInk),
        _stat('Coin out (SC)', grouped(coinOut)),
        _stat('Net (SC)', grouped(coinIn - coinOut), coinIn - coinOut < 0 ? K.red : K.text),
        _stat('Starting amount', '${compact(p.startGc)} GC + ${grouped(p.startSc)} SC'),
        _stat('Played (SC)', grouped(wagered)),
        _stat('Won (SC)', grouped(won)),
      ]),
      if (byGame.isNotEmpty) ...[
        const SizedBox(height: 18),
        const KTitle('Games', size: 16),
        KCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(children: [
            for (final e in byGame.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  Expanded(child: Text(games.firstWhere((g) => g.id == e.key, orElse: () => games.first).name, style: kt(15, w: FontWeight.w600))),
                  Text('${e.value.rounds} rounds · ${grouped(e.value.w)} SC', style: kt(13, c: K.sub, num: true)),
                ]),
              ),
          ]),
        ),
      ],
      const SizedBox(height: 18),
      const KTitle('Details', size: 16),
      KCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(children: [
          _info('Phone', p.phone.isEmpty ? '—' : p.phone),
          _info('Email', p.email.isEmpty ? '—' : p.email),
          _info('Created', '${when(p.created, casino.now)} by ${p.createdBy.isEmpty ? '—' : p.createdBy}'),
          _info('Last seen', ago(p.lastSeen, casino.now)),
          if (p.note.isNotEmpty) _info('Note', p.note),
        ]),
      ),
      const SizedBox(height: 18),
      KTitle('Activity', size: 16, trailing: Text('${txns.length}', style: kt(14, c: K.sub))),
      KCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(children: [
          if (txns.isEmpty) const KEmpty('No activity yet'),
          for (final t in txns.take(40)) TxnTile(t, showPlayer: false),
        ]),
      ),
    ]);
  }

  Widget _info(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 92, child: Text(k, style: kt(14, c: K.sub))),
          Expanded(child: Text(v, style: kt(15, w: FontWeight.w600))),
        ]),
      );

  Widget _stat(String k, String v, [Color c = K.text]) => KCard(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: kt(12, c: K.sub)),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(v, style: kt(17, w: FontWeight.w700, c: c, num: true))),
        ]),
      );

  void _edit(BuildContext context, Player p) {
    final u = TextEditingController(text: p.username), n = TextEditingController(text: p.name);
    final ph = TextEditingController(text: p.phone), em = TextEditingController(text: p.email), no = TextEditingController(text: p.note);
    kSheet<void>(
      context,
      title: 'Edit player',
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KField(label: 'Username', controller: u),
        const SizedBox(height: 12),
        KField(label: 'Name', controller: n),
        const SizedBox(height: 12),
        KField(label: 'Phone', controller: ph, keyboard: TextInputType.phone),
        const SizedBox(height: 12),
        KField(label: 'Email', controller: em, keyboard: TextInputType.emailAddress),
        const SizedBox(height: 12),
        KField(label: 'Note', controller: no, maxLines: 3),
        const SizedBox(height: 16),
        KButton('Save', expand: true, onTap: () {
          if (attempt(ctx, () => CasinoScope.read(ctx).updatePlayer(p, username: u.text, name: n.text, phone: ph.text, email: em.text, note: no.text),
              done: 'Saved')) {
            Navigator.of(ctx).pop();
          }
        }),
      ]),
    ).whenComplete(() {
      for (final c in [u, n, ph, em, no]) {
        c.dispose();
      }
    });
  }
}

class _Action extends StatelessWidget {
  const _Action(this.icon, this.label, this.onTap, {this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => ActionChip(
        avatar: Icon(icon, size: 18, color: danger ? K.red : K.text),
        label: Text(label, style: kt(14, w: FontWeight.w600, c: danger ? K.red : K.text)),
        backgroundColor: danger ? K.redSoft : K.field,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        onPressed: onTap,
      );
}
