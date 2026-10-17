import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/assets.dart' show GameInfo;
import '../app/site.dart';
import '../backoffice/casino.dart';
import '../backoffice/github.dart';
import '../backoffice/net.dart';
import '../backoffice/sync.dart';
import '../games/html/model.dart';
import '../games/html/package.dart';
import 'kit.dart';
import 'pick_file.dart';

/// Uploading a game made with docs/GAME_PROMPT.md: the zip is checked, its
/// files are committed to the repository (web/games/<id>/<version>/), which
/// rebuilds the site, and once the site has it the game goes live in the lobby
/// with its pay table at the RTP set in Game math.
class GameUpload {
  GameUpload._();

  /// The GitHub token: saved in the database where only the owner can read it
  /// (zoya7_secrets/github), loaded when the uploader first opens.
  static String token = '';
  static bool _loaded = false;

  static Future<void> loadToken(CasinoSync? sync) async {
    if (_loaded) return;
    try {
      token = await readToken(sync) ?? '';
      _loaded = true;
    } catch (_) {
      // Not reachable now: asked again next time.
    }
  }

  // Swapped in tests.
  static Future<String?> Function(CasinoSync? sync) readToken = (sync) async => sync?.readSecret('github');
  static Future<void> Function(CasinoSync? sync, String? token) saveToken = (sync, token) async {
    if (sync == null) throw 'Not connected to the database';
    await sync.writeSecret('github', token);
  };
  static bool canPick = canPickFiles;
  static Future<(String, Uint8List)?> Function() pick = pickZip;
  static GitHubPublisher Function(String token) publisher = GitHubPublisher.new;
  static Future<Uint8List> Function() bridge =
      () async => (await rootBundle.load('assets/sdk/zoya7-bridge.js')).buffer.asUint8List();

  /// Whether the site serves this version yet.
  static Future<bool> Function(String id, int version) isLive = (id, version) async {
    try {
      final r = await httpRequest('GET', siteUrl('games/$id/$version/game.json?t=${DateTime.now().millisecondsSinceEpoch}'));
      return r.status == 200;
    } catch (_) {
      return false;
    }
  };

  static final _watching = <String, Timer>{};

  /// Checks every 15 s (for up to 20 minutes) until the site has the game, then switches it on.
  static void watch(Casino casino, String id, int version) {
    if (_watching.containsKey('$id/$version')) return;
    var tries = 0;
    Future<void> check(Timer t) async {
      if (++tries > 80 || casino.configs[id]?.html?.version != version) {
        t.cancel();
        _watching.remove('$id/$version');
        return;
      }
      if (await isLive(id, version)) {
        casino.markLive(id, version);
        t.cancel();
        _watching.remove('$id/$version');
      }
    }

    _watching['$id/$version'] = Timer.periodic(const Duration(seconds: 15), check);
  }

  static void stopWatching() {
    for (final t in _watching.values) {
      t.cancel();
    }
    _watching.clear();
  }

  /// Picks up games still being published (after the panel is reopened).
  static void resume(Casino casino) {
    for (final c in casino.configs.values) {
      final h = c.html;
      if (h != null && !h.live) watch(casino, c.id, h.version);
    }
  }
}

Future<void> showUploadGame(BuildContext context) => showDialog(context: context, builder: (_) => const _Uploader());

Future<void> showRemoveGame(BuildContext context, GameInfo g) => showDialog(context: context, builder: (_) => _Remover(g));

/// The key in the corner: the saved GitHub token (green dot when there is one).
class _TokenButton extends StatelessWidget {
  const _TokenButton({required this.onChanged});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
        IconButton(
          tooltip: GameUpload.token.isEmpty ? 'Add the GitHub token' : 'GitHub token (saved)',
          onPressed: () async {
            await showTokenDialog(context);
            onChanged();
          },
          icon: Icon(Icons.key_rounded, color: GameUpload.token.isEmpty ? K.amber : K.text),
        ),
        if (GameUpload.token.isNotEmpty)
          Positioned(
            right: 8,
            top: 8,
            child: Container(width: 9, height: 9, decoration: const BoxDecoration(shape: BoxShape.circle, color: K.green)),
          ),
      ]);
}

Future<void> showTokenDialog(BuildContext context) => showDialog(context: context, builder: (_) => const _TokenDialog());

class _TokenDialog extends StatefulWidget {
  const _TokenDialog();

  @override
  State<_TokenDialog> createState() => _TokenDialogState();
}

class _TokenDialogState extends State<_TokenDialog> {
  final field = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  /// Checks the token with GitHub, then saves it (or, with null, deletes it).
  Future<void> _save(String? token) async {
    final sync = SyncScope.read(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (token != null) await GameUpload.publisher(token).check();
      await GameUpload.saveToken(sync, token);
      GameUpload.token = token ?? '';
      if (mounted) {
        Navigator.pop(context);
        kToast(context, token == null ? 'Token removed' : 'Token saved');
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = GameUpload.token;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(22), children: [
          Row(children: [
            const Icon(Icons.key_rounded),
            const SizedBox(width: 10),
            Expanded(child: Text('GitHub token', style: kt(20, w: FontWeight.w800))),
          ]),
          const SizedBox(height: 6),
          Text(
            saved.isEmpty
                ? 'Needed to publish and remove games. Saved in the database, where only the owner can read it.'
                : 'Saved: ${saved.length > 14 ? '${saved.substring(0, 11)}…${saved.substring(saved.length - 4)}' : '••••'}. '
                    'Paste a new one to replace it.',
            style: kt(14, c: K.sub, h: 1.4),
          ),
          const SizedBox(height: 14),
          KField(label: saved.isEmpty ? 'Token' : 'New token', controller: field, obscure: true, hint: 'github_pat_…', onChanged: (_) => setState(() {})),
          const SizedBox(height: 6),
          Text(
            'Make one on GitHub: Settings, Developer settings, Fine-grained tokens. Repository access: only '
            '${const GitHubRepo()}. Permissions: Contents, Read and write. Nothing else.',
            style: kt(12.5, c: K.sub, h: 1.4),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: kt(14, w: FontWeight.w600, c: K.red, h: 1.4)),
          ],
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            KButton(busy ? 'Checking…' : 'Save token',
                icon: Icons.check_rounded, onTap: busy || field.text.trim().isEmpty ? null : () => _save(field.text.trim())),
            if (saved.isNotEmpty) KButton('Remove token', tone: KTone.red, onTap: busy ? null : () => _save(null)),
            KButton('Cancel', tone: KTone.light, onTap: busy ? null : () => Navigator.pop(context)),
          ]),
        ]),
      ),
    );
  }
}

class _Uploader extends StatefulWidget {
  const _Uploader();

  @override
  State<_Uploader> createState() => _UploaderState();
}

class _UploaderState extends State<_Uploader> {
  String? fileName;
  GamePackage? pkg;

  /// The version already in the lobby when the zip was chosen.
  HtmlGame? current;
  bool busy = false;
  String? step;
  String? error;
  bool done = false;

  @override
  void initState() {
    super.initState();
    GameUpload.loadToken(SyncScope.read(context)).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _choose() async {
    final picked = await GameUpload.pick();
    if (picked == null || !mounted) return;
    final read = GamePackage.read(picked.$2);
    setState(() {
      fileName = picked.$1;
      pkg = read;
      current = CasinoScope.read(context).configs[read.id]?.html;
      error = null;
      step = null;
      done = false;
    });
  }

  Future<void> _publish(Casino casino) async {
    if (GameUpload.token.isEmpty) {
      await showTokenDialog(context);
      if (!mounted || GameUpload.token.isEmpty) return;
      setState(() {});
    }
    final p = pkg!;
    final game = p.game!;
    final version = (casino.configs[p.id]?.html?.version ?? 0) + 1;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final files = {...p.files, 'zoya7-bridge.js': await GameUpload.bridge()};
      await GameUpload.publisher(GameUpload.token).publish(
        folder: 'web/games/${p.id}/$version',
        files: files,
        clear: 'web/games/${p.id}',
        message: 'Add ${game.name} (version $version) from the admin panel',
        progress: (s) {
          if (mounted) setState(() => step = s);
        },
      );
      casino.addUploadedGame(
        p.id,
        HtmlGame(
          name: game.name,
          cat: game.cat,
          blurb: game.blurb,
          credits: game.credits,
          version: version,
          options: game.options,
          uploaded: casino.now.millisecondsSinceEpoch,
        ),
      );
      GameUpload.watch(casino, p.id, version);
      if (mounted) {
        setState(() {
          done = true;
          step = 'Saved to GitHub. The site is rebuilding with ${game.name}: it switches on in the lobby by itself '
              'in about 5 minutes (keep this panel open until then).';
        });
      }
    } on GitHubError catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    final p = pkg;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(22), children: [
          Row(children: [
            Expanded(child: Text('Upload a game', style: kt(22, w: FontWeight.w800))),
            _TokenButton(onChanged: () => setState(() {})),
            IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          ]),
          Text('A game made with docs/GAME_PROMPT.md, as one .zip. It’s checked here first.', style: kt(14, c: K.sub)),
          const SizedBox(height: 16),
          if (!GameUpload.canPick)
            Text('Upload from the admin panel in a web browser on a computer.', style: kt(14, w: FontWeight.w600))
          else
            Align(
              alignment: Alignment.centerLeft,
              child: KButton(fileName == null ? 'Choose the game’s zip' : 'Choose another zip',
                  icon: Icons.upload_file_rounded, tone: fileName == null ? KTone.green : KTone.light, onTap: busy ? null : _choose),
            ),
          if (p != null) ...[
            const SizedBox(height: 16),
            _Report(fileName: fileName!, pkg: p, current: current),
            if (p.ok && !done) ...[
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: KButton(busy ? 'Publishing…' : 'Publish to the lobby',
                    icon: Icons.rocket_launch_rounded, onTap: busy ? null : () => _publish(casino)),
              ),
              if (GameUpload.token.isEmpty) ...[
                const SizedBox(height: 6),
                Text('First time: you’ll be asked for the GitHub token (it’s saved for next time).', style: kt(12.5, c: K.sub)),
              ],
            ],
          ],
          if (step != null) ...[
            const SizedBox(height: 14),
            Text(step!, style: kt(14, w: FontWeight.w600, c: done ? K.greenInk : K.text, h: 1.4)),
          ],
          if (error != null) ...[
            const SizedBox(height: 14),
            Text(error!, style: kt(14, w: FontWeight.w600, c: K.red, h: 1.4)),
          ],
        ]),
      ),
    );
  }
}

/// What's in the zip: the game, its pay table, and anything to fix.
class _Report extends StatelessWidget {
  const _Report({required this.fileName, required this.pkg, this.current});
  final String fileName;
  final GamePackage pkg;
  final HtmlGame? current;

  @override
  Widget build(BuildContext context) {
    final g = pkg.game;
    final tile = pkg.files['lobby/tile.png'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 176,
              height: 94,
              child: tile == null
                  ? const ColoredBox(color: K.field)
                  : Image.memory(tile, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: K.field)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g?.name ?? fileName, style: kt(18, w: FontWeight.w700)),
              Text(
                [
                  if (pkg.id.isNotEmpty) pkg.id,
                  if (g != null) g.cat,
                  '${pkg.files.length} files',
                  pkg.bytes < 1 << 20 ? '${(pkg.bytes / 1024).ceil()} KB' : '${(pkg.bytes / (1 << 20)).toStringAsFixed(1)} MB',
                ].join(' · '),
                style: kt(13, c: K.sub),
              ),
              if (g != null)
                Text(current == null ? 'A new game' : 'Replaces version ${current!.version} (it’s off for a few minutes while the site rebuilds)',
                    style: kt(13, c: K.sub)),
              if (g?.blurb.isNotEmpty ?? false) Text(g!.blurb, maxLines: 2, overflow: TextOverflow.ellipsis, style: kt(13, h: 1.35)),
            ]),
          ),
        ]),
      ),
      if (pkg.errors.isNotEmpty) ...[
        const SizedBox(height: 12),
        KCard(
          color: K.redSoft,
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('Fix these before it can go in', style: kt(15, w: FontWeight.w700, c: K.red))),
              KButton('Copy for GPT', tone: KTone.light, height: 36, icon: Icons.copy_rounded, onTap: () {
                Clipboard.setData(ClipboardData(
                    text: 'The Zoya7 uploader refused the game. Fix every one of these, keep everything else the same, '
                        'and send the complete zip again:\n${pkg.errors.map((e) => '- $e').join('\n')}'));
                kToast(context, 'Copied');
              }),
            ]),
            const SizedBox(height: 6),
            for (final e in pkg.errors) Text('• $e', style: kt(13.5, c: K.red, h: 1.4)),
          ]),
        ),
      ],
      if (pkg.warnings.isNotEmpty) ...[
        const SizedBox(height: 10),
        for (final w in pkg.warnings) Text('Note: $w', style: kt(13, c: K.amber, h: 1.4)),
      ],
      if (g != null) ...[
        const SizedBox(height: 12),
        for (final o in g.options) _PayPreview(o),
      ],
    ]);
  }
}

/// The game's pays, and how often each comes at a 95% RTP.
class _PayPreview extends StatelessWidget {
  const _PayPreview(this.o);
  final BetOption o;

  @override
  Widget build(BuildContext context) {
    final p = chancesFor(o.outcomes, .95)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: KCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Pays${o.label.isEmpty ? '' : ' · ${o.label}'} (at 95% RTP; change it in Game math)', style: kt(14, w: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (i, x) in o.outcomes.indexed)
              KBadge(
                '${x.label.isEmpty ? x.id : x.label}: ${x.wins ? '${grouped(x.multiplier, x.multiplier % 1 == 0 ? 0 : 2)}×' : 'no win'} · ${pct(p[i], 1)}',
                fg: x.wins ? K.greenInk : K.sub,
                bg: x.wins ? K.greenSoft : K.field,
              ),
          ]),
        ]),
      ),
    );
  }
}

class _Remover extends StatefulWidget {
  const _Remover(this.g);
  final GameInfo g;

  @override
  State<_Remover> createState() => _RemoverState();
}

class _RemoverState extends State<_Remover> {
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    GameUpload.loadToken(SyncScope.read(context)).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _remove(Casino casino) async {
    if (GameUpload.token.isEmpty) {
      await showTokenDialog(context);
      if (!mounted || GameUpload.token.isEmpty) return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await GameUpload.publisher(GameUpload.token)
          .remove(folder: 'web/games/${widget.g.id}', message: 'Remove ${widget.g.name} from the admin panel');
      casino.removeUploadedGame(widget.g.id);
      if (mounted) {
        Navigator.pop(context);
        kToast(context, '${widget.g.name} removed');
      }
    } on GitHubError catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final casino = CasinoScope.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(22), children: [
          Text('Remove ${widget.g.name}?', style: kt(20, w: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('It leaves the lobby and its files are deleted from the site. Its play stays in the reports.', style: kt(14, c: K.sub, h: 1.4)),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: kt(14, w: FontWeight.w600, c: K.red)),
          ],
          const SizedBox(height: 16),
          Row(children: [
            KButton('Cancel', tone: KTone.light, onTap: busy ? null : () => Navigator.pop(context)),
            const SizedBox(width: 10),
            KButton(busy ? 'Removing…' : 'Remove', tone: KTone.red, onTap: busy ? null : () => _remove(casino)),
          ]),
        ]),
      ),
    );
  }
}
