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
          builder: (context, child) => WebSafeArea(child: child!),
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
/// Staff sign in with their username and password (a Firebase account). The
/// very first time, the owner sets themselves up here.
class SignInGate extends StatefulWidget {
  const SignInGate({super.key, this.onExit, this.resuming = false});
  final VoidCallback? onExit;
  final bool resuming;

  @override
  State<SignInGate> createState() => _SignInGateState();
}

class _SignInGateState extends State<SignInGate> {
  final name = TextEditingController(), username = TextEditingController(), password = TextEditingController();
  bool setup = false, busy = false;
  String? error;

  @override
  void dispose() {
    for (final c in [name, username, password]) {
      c.dispose();
    }
    super.dispose();
  }

  static final _usernameOk = RegExp(r'^[a-zA-Z0-9_.-]{3,30}$');

  Future<void> _go() async {
    final sync = SyncScope.read(context), auth = sync?.auth, casino = CasinoScope.read(context);
    final u = username.text.trim(), pw = password.text;
    String? problem;
    if (setup && name.text.trim().isEmpty) problem = 'Enter your name';
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
      if (setup) {
        final s = await auth!.signUp(staffEmail(u), pw);
        await sync!.setUpOwner(s, name.text, u);
      } else {
        final s = await auth!.signIn(staffEmail(u), pw);
        await sync!.useStaff(s);
        if (casino.signIn(s.uid) == null) {
          sync.signOut(staff: true);
          error = sync.error ?? 'This account isn’t on the staff';
        }
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
    const white = Colors.white;
    return Scaffold(
      backgroundColor: K.green,
      body: SafeArea(
        child: Stack(children: [
          if (widget.onExit != null)
            Positioned(
              left: 8,
              top: 8,
              child: TextButton.icon(
                onPressed: widget.onExit,
                icon: const Icon(Icons.arrow_back_rounded, color: white),
                label: Text('Back to the game', style: kt(15, w: FontWeight.w600, c: white)),
              ),
            ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: widget.resuming
                    ? Column(mainAxisSize: MainAxisSize.min, children: [
                        const AdminLogo(size: 72),
                        const SizedBox(height: 18),
                        const CircularProgressIndicator(color: white),
                        const SizedBox(height: 14),
                        Text('Signing in…', style: kt(17, w: FontWeight.w600, c: white)),
                      ])
                    : AutofillGroup(
                        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          const Center(child: AdminLogo(size: 72)),
                          const SizedBox(height: 16),
                          Text('Zoya7 Admin', textAlign: TextAlign.center, style: kt(28, w: FontWeight.w800, c: white)),
                          const SizedBox(height: 4),
                          Text(setup ? 'First-time setup: make the owner account' : 'Sign in',
                              textAlign: TextAlign.center, style: kt(17, w: FontWeight.w600, c: const Color(0xE6FFFFFF))),
                          const SizedBox(height: 20),
                          KCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              if (setup) ...[
                                KField(label: 'Your name', controller: name),
                                const SizedBox(height: 12),
                              ],
                              KField(label: 'Username', controller: username, autofocus: true),
                              const SizedBox(height: 12),
                              KField(label: 'Password', controller: password, obscure: true, onSubmitted: (_) => _go()),
                              if (error != null) ...[
                                const SizedBox(height: 10),
                                Text(error!, style: kt(14, w: FontWeight.w600, c: K.red, h: 1.35)),
                              ],
                              const SizedBox(height: 14),
                              KButton(busy ? 'Please wait…' : (setup ? 'Create owner account' : 'Sign in'),
                                  expand: true, onTap: busy ? null : _go),
                            ]),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: busy ? null : () => setState(() {
                              setup = !setup;
                              error = null;
                            }),
                            child: Text(setup ? 'Back to sign in' : 'First time? Set up the owner account',
                                style: kt(14, w: FontWeight.w600, c: white)),
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

/// The Zoya7 app icon: the crowned ZOYA7 on a rounded black square.
class AdminLogo extends StatelessWidget {
  const AdminLogo({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset('assets/app/icon.png', width: size, height: size, semanticLabel: 'Zoya7');
}

// ── Shell ────────────────────────────────────────────────────────────────────
enum Section { dashboard, players, coins, reports, games, math, settings, staff }

extension SectionInfo on Section {
  String get label => switch (this) {
        Section.dashboard => 'Home',
        Section.players => 'Players',
        Section.coins => 'Coin in / out',
        Section.reports => 'Reports',
        Section.games => 'Games',
        Section.math => 'Game math',
        Section.settings => 'Settings',
        Section.staff => 'Staff & log',
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
        Section.staff => Icons.badge_outlined,
      };
}

/// What each role can open.
List<Section> sectionsFor(Staff s, {required bool desktop}) {
  final all = switch (s.role) {
    StaffRole.cashier => const [Section.dashboard, Section.players, Section.coins],
    StaffRole.manager => Section.values.where((x) => x != Section.staff).toList(),
    StaffRole.owner => Section.values,
  };
  // A phone gets the basics.
  const phone = [Section.dashboard, Section.players, Section.coins, Section.games];
  return desktop ? all : all.where(phone.contains).toList();
}

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

  Widget _page(Section s) => switch (s) {
        Section.dashboard => const DashboardPage(),
        Section.players => const PlayersPage(),
        Section.coins => const CoinsPage(),
        Section.reports => const ReportsPage(),
        Section.games => const GamesAdminPage(),
        Section.math => const MathPage(),
        Section.settings => const SettingsPage(),
        Section.staff => const StaffPage(),
      };

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final me = casino.admin!;
    final desktop = K.desktop(context);
    final sections = sectionsFor(me, desktop: desktop);
    final current = sections.contains(section) ? section : sections.first;
    final page = KeyedSubtree(key: ValueKey(current), child: _page(current));
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
              bottomNavigationBar: _TabBar(sections: sections, current: current, onPick: (s) => setState(() => section = s)),
            ),
    );
  }
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
                  PopupMenuItem(value: 'db', child: Text('Database & install', style: kt(15, w: FontWeight.w600))),
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
  const _TabBar({required this.sections, required this.current, required this.onPick});
  final List<Section> sections;
  final Section current;
  final ValueChanged<Section> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: K.card, border: Border(top: BorderSide(color: K.line))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(children: [
            for (final s in sections)
              Expanded(
                child: Semantics(
                  selected: s == current,
                  button: true,
                  label: s.tab,
                  child: InkResponse(
                    onTap: () => onPick(s),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(s.icon, size: 26, color: s == current ? K.green : K.ink),
                      const SizedBox(height: 2),
                      ExcludeSemantics(
                        child: Text(s.tab, style: kt(11, w: FontWeight.w600, c: s == current ? K.green : K.sub)),
                      ),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
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
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 40),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: kt(30, w: FontWeight.w800)),
                if (sub != null) Text(sub!, style: kt(15, c: K.sub)),
              ]),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ),
          const SizedBox(height: 22),
          ...children,
        ],
      );
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
