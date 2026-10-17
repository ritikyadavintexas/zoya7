import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/web_safe_area.dart';
import '../backoffice/auth.dart';
import '../backoffice/casino.dart';
import '../backoffice/sync.dart';
import 'coins.dart';
import 'dashboard.dart';
import 'games.dart';
import 'kit.dart';
import 'players.dart';
import 'reports.dart';
import 'settings.dart';
import 'setup.dart';
import 'team.dart';

/// The Zoya7 admin panel: portrait on a phone (the basics: today, players,
/// coin in/out, games on/off), everything on a desktop.
class AdminApp extends StatefulWidget {
  const AdminApp({super.key, required this.casino, this.sync, this.onExit, this.initialSection = Section.dashboard});
  final Casino casino;

  /// The shared database connection (status and setup in Settings).
  final CasinoSync? sync;

  /// The page to open on after signing in.
  final Section initialSection;

  /// "Open player app".
  final VoidCallback? onExit;

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  /// Signing back in with the account this device remembers.
  bool resuming = false;

  @override
  void initState() {
    super.initState();
    // Signed in once on this device: straight in.
    _resume();
    // The game locks phones to landscape; the admin panel stands up.
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Future<void> _resume() async {
    final sync = widget.sync;
    if (widget.casino.admin != null || sync == null || sync.auth == null) return;
    setState(() => resuming = true);
    if (await sync.resumeStaff()) {
      final uid = sync.session?.uid;
      if (uid == null || widget.casino.signIn(uid, log: false) == null) {
        // Not on the staff any more (or the session ended).
        if (sync.state == SyncState.live) sync.signOut(staff: true);
      }
    }
    if (mounted) setState(() => resuming = false);
  }

  @override
  Widget build(BuildContext context) => CasinoScope(
        casino: widget.casino,
        child: SyncScope(
          sync: widget.sync,
          child: MaterialApp(
          builder: (context, child) => WebSafeArea(child: StatusBand(child: child!)),
          title: 'Zoya7 Admin',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: K.bg,
            colorScheme: ColorScheme.fromSeed(seedColor: K.green, primary: K.green, surface: K.card),
            splashFactory: InkSparkle.splashFactory,
            dividerColor: K.line,
          ),
          home: ListenableBuilder(
            listenable: widget.casino,
            builder: (context, _) => widget.casino.admin == null
                ? SignInGate(onExit: widget.onExit, resuming: resuming)
                : AdminShell(onExit: widget.onExit, initial: widget.initialSection),
          ),
          ),
        ),
      );
}

// ── Sign in ──────────────────────────────────────────────────────────────────
/// Staff sign in with their username and password (a Firebase account).
class SignInGate extends StatefulWidget {
  const SignInGate({super.key, this.onExit, this.resuming = false});
  final VoidCallback? onExit;
  final bool resuming;

  @override
  State<SignInGate> createState() => _SignInGateState();
}

class _SignInGateState extends State<SignInGate> {
  final username = TextEditingController(), password = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    for (final c in [username, password]) {
      c.dispose();
    }
    super.dispose();
  }

  static final _usernameOk = RegExp(r'^[a-zA-Z0-9_.-]{3,30}$');

  Future<void> _go() async {
    final sync = SyncScope.read(context), auth = sync?.auth, casino = CasinoScope.read(context);
    final u = username.text.trim(), pw = password.text;
    String? problem;
    if (!_usernameOk.hasMatch(u)) problem ??= 'Username: 3 or more letters, numbers, _ . or -';
    if (pw.length < 6) problem ??= 'The password needs at least 6 characters';
    if (sync == null || auth == null) problem ??= 'Not connected to the database';
    if (problem != null) {
      setState(() => error = problem);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final s = await auth!.signIn(staffEmail(u), pw);
      await sync!.useStaff(s);
      if (casino.signIn(s.uid) == null) {
        sync.signOut(staff: true);
        error = sync.error ?? 'This account isn’t on the staff';
      }
    } on AuthError catch (e) {
      error = e.message;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg,
      body: SafeArea(
        child: Stack(children: [
          if (widget.onExit != null)
            Positioned(
              left: 8,
              top: 8,
              child: TextButton.icon(
                onPressed: widget.onExit,
                icon: const Icon(Icons.arrow_back_rounded, color: K.text),
                label: Text('Back to the game', style: kt(15, w: FontWeight.w600)),
              ),
            ),
          // Near the top, not centred: on a phone the keyboard takes the lower
          // half, and the fields and the button stay above it.
          Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, (K.desktop(context) ? 120 : 28) + (widget.onExit != null ? 40 : 0), 24, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: widget.resuming
                    ? const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(child: CircularProgressIndicator(color: K.green)),
                      )
                    : AutofillGroup(
                        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          // Plain: no logo, name or heading.
                          KCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              KField(label: 'Username', controller: username, autofocus: true, action: TextInputAction.next),
                              const SizedBox(height: 12),
                              KField(label: 'Password', controller: password, obscure: true, action: TextInputAction.go, onSubmitted: (_) => _go()),
                              if (error != null) ...[
                                const SizedBox(height: 10),
                                Text(error!, style: kt(14, w: FontWeight.w600, c: K.red, h: 1.35)),
                              ],
                              const SizedBox(height: 14),
                              KButton(busy ? 'Please wait…' : 'Continue',
                                  expand: true, onTap: busy ? null : _go),
                            ]),
                          ),
                        ]),
                      ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Cash App's number pad: 1–9, then [extra] (a dot, or nothing), 0, delete.
class Keypad extends StatelessWidget {
  const Keypad({super.key, required this.onDigit, required this.onBack, this.dot = false, this.keyHeight = 64, this.color = Colors.white});
  final ValueChanged<String> onDigit;
  final VoidCallback onBack;
  final bool dot;
  final double keyHeight;
  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget key(String k) {
      final del = k == '<';
      final blank = k.isEmpty;
      return Expanded(
        child: SizedBox(
          height: keyHeight,
          child: blank
              ? null
              : InkResponse(
                  onTap: del ? onBack : () => onDigit(k),
                  radius: keyHeight * .6,
                  highlightColor: Colors.transparent,
                  child: Center(
                    child: del
                        ? Icon(Icons.backspace_outlined, color: color, size: keyHeight * .36, semanticLabel: 'Delete')
                        : Text(k, style: kt(keyHeight * .44, w: FontWeight.w600, c: color, h: 1)),
                  ),
                ),
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (final row in [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
        [dot ? '.' : '', '0', '<'],
      ])
        Row(children: [for (final k in row) key(k)]),
    ]);
  }
}

/// The strip under the phone's status bar (clock, battery) is the panel's
/// own light grey on every screen, and the pages start below it.
class StatusBand extends StatelessWidget {
  const StatusBand({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    if (top <= 0) return child;
    return ColoredBox(
      color: K.bg,
      child: Padding(
        padding: EdgeInsets.only(top: top),
        child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
      ),
    );
  }
}

/// The Zoya7 app icon: the crowned ZOYA7 on a rounded black square.
class AdminLogo extends StatelessWidget {
  const AdminLogo({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset('assets/app/icon.png', width: size, height: size, semanticLabel: 'Zoya7');
}

// ── Shell ────────────────────────────────────────────────────────────────────
enum Section { dashboard, team, players, coins, reports, games, math, settings }

extension SectionInfo on Section {
  String get label => switch (this) {
        Section.dashboard => 'Home',
        Section.players => 'Players',
        Section.coins => 'Coin in / out',
        Section.reports => 'Reports',
        Section.games => 'Games',
        Section.math => 'Game math',
        Section.settings => 'Settings',
        Section.team => 'Team',
      };

  /// Shorter, for the phone's tab bar.
  String get tab => this == Section.coins ? 'Coins' : label;

  IconData get icon => switch (this) {
        Section.dashboard => Icons.home_rounded,
        Section.players => Icons.people_alt_rounded,
        Section.coins => Icons.toll_rounded,
        Section.reports => Icons.bar_chart_rounded,
        Section.games => Icons.sports_esports_rounded,
        Section.math => Icons.functions_rounded,
        Section.settings => Icons.tune_rounded,
        Section.team => Icons.account_tree_rounded,
      };
}

/// What each role can open. The owner: everything. An executive: their
/// agents and points, and their agents' players. An agent: their players,
/// coin in / out, and referring agents.
List<Section> sectionsFor(Staff s) {
  final all = switch (s.role) {
    StaffRole.agent => const [Section.dashboard, Section.players, Section.coins, Section.team],
    StaffRole.executive => const [Section.dashboard, Section.team, Section.players],
    StaffRole.owner => Section.values,
  };
  return all;
}

/// A phone's bottom bar: these as tabs (when allowed), the rest under More.
const phoneTabs = [Section.dashboard, Section.players, Section.coins, Section.team];

/// Lets a page switch sections (quick actions, "see all" links).
class AdminNav extends InheritedWidget {
  const AdminNav({super.key, required this.go, required super.child});
  final void Function(Section s) go;

  static void to(BuildContext context, Section s) => context.getInheritedWidgetOfExactType<AdminNav>()?.go(s);

  @override
  bool updateShouldNotify(AdminNav old) => false;
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, this.onExit, this.initial = Section.dashboard});
  final VoidCallback? onExit;
  final Section initial;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late Section section = widget.initial;

  /// Coin requests already announced, so each new one toasts only once.
  Set<String>? _announced;

  void _watchRequests(Casino casino) {
    final ids = {for (final r in casino.waitingRequests) r.id};
    final before = _announced;
    _announced = ids;
    if (before == null) return;
    final fresh = ids.difference(before).length;
    if (fresh == 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) kToast(context, fresh == 1 ? 'New coin request from a player' : '$fresh new coin requests');
    });
  }

  Widget _page(Section s) => switch (s) {
        Section.dashboard => const DashboardPage(),
        Section.players => const PlayersPage(),
        Section.coins => const CoinsPage(),
        Section.reports => const ReportsPage(),
        Section.games => const GamesAdminPage(),
        Section.math => const MathPage(),
        Section.settings => const SettingsPage(),
        Section.team => const TeamPage(),
      };

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final me = casino.admin!;
    final desktop = K.desktop(context);
    final sections = sectionsFor(me);
    final current = sections.contains(section) ? section : sections.first;
    _watchRequests(casino);
    final waiting = casino.waitingRequests.length;
    final page = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (waiting > 0 && current != Section.coins && current != Section.dashboard && sections.contains(Section.coins))
        _RequestsBanner(count: waiting, onTap: () => setState(() => section = Section.coins)),
      Expanded(child: KeyedSubtree(key: ValueKey(current), child: _page(current))),
    ]);
    return AdminNav(
      go: (s) => setState(() => section = s),
      child: desktop
          ? Scaffold(
              body: Row(children: [
                _Sidebar(sections: sections, current: current, onPick: (s) => setState(() => section = s), onExit: widget.onExit),
                const VerticalDivider(width: 1, color: K.line),
                Expanded(child: page),
              ]),
            )
          : Scaffold(
              backgroundColor: K.bg,
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: _PhoneTopBar(title: current == Section.dashboard ? 'Today' : current.label, onExit: widget.onExit),
              ),
              body: page,
              bottomNavigationBar: _TabBar(
                tabs: [for (final s in phoneTabs) if (sections.contains(s)) s],
                more: [for (final s in sections) if (!phoneTabs.contains(s)) s],
                current: current,
                onPick: (s) => setState(() => section = s),
              ),
            ),
    );
  }
}

/// A strip above every other page while players wait for coins.
class _RequestsBanner extends StatelessWidget {
  const _RequestsBanner({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: K.amberSoft,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              const Icon(Icons.notifications_active_rounded, color: K.amber, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(count == 1 ? '1 player is waiting for coins' : '$count players are waiting for coins', style: kt(14, w: FontWeight.w600))),
              Text('OPEN', style: kt(13, w: FontWeight.w800, c: K.amber)),
            ]),
          ),
        ),
      );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.sections, required this.current, required this.onPick, this.onExit});
  final List<Section> sections;
  final Section current;
  final ValueChanged<Section> onPick;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final me = casino.admin!;
    return Container(
      width: 248,
      color: K.card,
      child: SafeArea(
        right: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Row(children: [
              const AdminLogo(),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Zoya7', style: kt(20, w: FontWeight.w800, h: 1.1)),
                Text('Admin', style: kt(13, c: K.sub)),
              ]),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: [
              for (final s in sections)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Material(
                    color: s == current ? K.greenSoft : Colors.transparent,
                    shape: const StadiumBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onPick(s),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        child: Row(children: [
                          Icon(s.icon, size: 21, color: s == current ? K.greenInk : K.sub),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(s.label,
                                style: kt(15, w: s == current ? FontWeight.w700 : FontWeight.w600, c: s == current ? K.greenInk : K.text)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SyncChip(
                onTap: () => sections.contains(Section.settings) ? onPick(Section.settings) : showDatabaseSheet(context),
              ),
            ),
          ),
          if (casino.settings.maintenance)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: KCard(
                color: K.amberSoft,
                padding: const EdgeInsets.all(12),
                onTap: () => onPick(sections.contains(Section.games) ? Section.games : current),
                child: Row(children: [
                  const Icon(Icons.construction_rounded, color: K.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Maintenance mode is on', style: kt(13, w: FontWeight.w600, c: K.amber))),
                ]),
              ),
            ),
          const Divider(height: 1, color: K.line),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                KAvatar(me.name, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(me.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(15, w: FontWeight.w700)),
                    Text(statusName(me.role), style: kt(13, c: K.sub)),
                  ]),
                ),
                KIconButton(Icons.lock_outline_rounded, tooltip: 'Lock', size: 36, onTap: () => lockAdmin(casino, SyncScope.read(context))),
              ]),
              if (onExit != null) ...[
                const SizedBox(height: 12),
                KButton('Open player app', tone: KTone.light, height: 40, icon: Icons.sports_esports_outlined, onTap: onExit),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PhoneTopBar extends StatelessWidget {
  const _PhoneTopBar({required this.title, this.onExit});
  final String title;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final me = casino.admin!;
    return Container(
      color: K.bg,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(28, w: FontWeight.w800))),
              SyncChip(compact: true, onTap: () => showDatabaseSheet(context)),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                tooltip: 'Account',
                color: K.card,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (v) => switch (v) {
                  'lock' => lockAdmin(casino, SyncScope.read(context)),
                  'db' => showDatabaseSheet(context),
                  _ => onExit?.call(),
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Text('${me.name} · ${statusName(me.role)}', style: kt(14, w: FontWeight.w600, c: K.sub)),
                  ),
                  PopupMenuItem(value: 'db', child: Text('Database', style: kt(15, w: FontWeight.w600))),
                  if (onExit != null)
                    PopupMenuItem(value: 'exit', child: Text('Open player app', style: kt(15, w: FontWeight.w600))),
                  PopupMenuItem(value: 'lock', child: Text('Lock', style: kt(15, w: FontWeight.w600))),
                ],
                child: KAvatar(me.name, size: 38),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.tabs, required this.more, required this.current, required this.onPick});
  final List<Section> tabs;

  /// Sections behind the More tab (a sheet).
  final List<Section> more;
  final Section current;
  final ValueChanged<Section> onPick;

  Future<void> _openMore(BuildContext context) async {
    final picked = await showModalBottomSheet<Section>(
      context: context,
      backgroundColor: K.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final s in more)
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                selected: s == current,
                selectedTileColor: K.greenSoft,
                selectedColor: K.greenInk,
                leading: Icon(s.icon),
                title: Text(s.label, style: kt(16, w: FontWeight.w600, c: s == current ? K.greenInk : K.text)),
                trailing: const Icon(Icons.chevron_right_rounded, color: K.faint),
                onTap: () => Navigator.of(context).pop(s),
              ),
          ]),
        ),
      ),
    );
    if (picked != null) onPick(picked);
  }

  Widget _item({required String label, required IconData icon, required bool selected, required VoidCallback onTap}) => Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          label: label,
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 56,
                height: 30,
                decoration: BoxDecoration(color: selected ? K.greenSoft : Colors.transparent, borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, size: 23, color: selected ? K.greenInk : K.sub),
              ),
              const SizedBox(height: 3),
              ExcludeSemantics(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kt(11.5, w: selected ? FontWeight.w700 : FontWeight.w500, c: selected ? K.text : K.sub)),
              ),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Above the home indicator; a little air when the phone has none.
    final bottom = MediaQuery.paddingOf(context).bottom;
    final inMore = more.contains(current);
    return Container(
      decoration: const BoxDecoration(
        color: K.card,
        border: Border(top: BorderSide(color: K.line)),
        boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, -2))],
      ),
      padding: EdgeInsets.only(top: 6, bottom: bottom > 0 ? bottom : 8),
      child: SizedBox(
        height: 56,
        child: Row(children: [
          for (final s in tabs) _item(label: s.tab, icon: s.icon, selected: s == current, onTap: () => onPick(s)),
          if (more.isNotEmpty)
            _item(
              label: inMore ? current.tab : 'More',
              icon: inMore ? current.icon : Icons.menu_rounded,
              selected: inMore,
              onTap: () => _openMore(context),
            ),
        ]),
      ),
    );
  }
}

/// A desktop page: big title, actions, then the content (scrolls).
class DeskPage extends StatelessWidget {
  const DeskPage({super.key, required this.title, this.sub, this.actions = const [], required this.children});
  final String title;
  final String? sub;
  final List<Widget> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // A phone's top bar already shows the title: just the line under it.
    final desktop = K.desktop(context);
    return ListView(
      padding: desktop ? const EdgeInsets.fromLTRB(28, 26, 28, 40) : const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (desktop) Text(title, style: kt(30, w: FontWeight.w800)),
              if (sub != null) Text(sub!, style: kt(desktop ? 15 : 14, c: K.sub)),
            ]),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
        SizedBox(height: desktop ? 22 : 14),
        ...children,
      ],
    );
  }
}

/// Lays [children] out in as many columns of at least [min] wide as fit.
class KGrid extends StatelessWidget {
  const KGrid({super.key, required this.children, this.min = 200, this.gap = 12, this.max = 4});
  final List<Widget> children;
  final double min;
  final double gap;
  final int max;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final cols = ((box.maxWidth + gap) / (min + gap)).floor().clamp(1, max);
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final c in children) SizedBox(width: w, child: c)]);
      });
}
