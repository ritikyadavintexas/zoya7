import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../app/web_env.dart';
import '../backoffice/storage.dart';
import '../backoffice/sync.dart';
import 'kit.dart';

/// Where the app is published (the game at the root, the admin app in admin/).
String siteRoot() {
  if (!kIsWeb) return 'https://ritikyadavintexas.github.io/zoya7/';
  final b = Uri.base;
  var path = b.path;
  if (path.endsWith('/admin/')) {
    path = path.substring(0, path.length - 'admin/'.length);
  } else if (!path.endsWith('/')) {
    path = path.substring(0, path.lastIndexOf('/') + 1);
  }
  return Uri(scheme: b.scheme, host: b.host, port: b.hasPort ? b.port : null, path: path).toString();
}

String _withDb(String url, CasinoSync? sync) =>
    sync?.url == null ? url : '$url?db=${Uri.encodeComponent(sync!.url!)}';

String playerAppLink(CasinoSync? sync) => _withDb(siteRoot(), sync);
String adminAppLink(CasinoSync? sync) => _withDb('${siteRoot()}admin/', sync);

/// Database and install help, as a sheet (the phone's account menu).
Future<void> showDatabaseSheet(BuildContext context) => kSheet<void>(
      context,
      title: 'Database & install',
      width: 560,
      builder: (_) => const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InstallCard(always: true),
        SizedBox(height: 14),
        DatabaseCard(),
      ]),
    );

/// Connect this device to the shared database, and how to make one.
class DatabaseCard extends StatefulWidget {
  const DatabaseCard({super.key});

  @override
  State<DatabaseCard> createState() => _DatabaseCardState();
}

class _DatabaseCardState extends State<DatabaseCard> {
  final url = TextEditingController();
  bool help = false;

  @override
  void initState() {
    super.initState();
    url.text = context.getInheritedWidgetOfExactType<SyncScope>()?.notifier?.url ?? '';
  }

  @override
  void dispose() {
    url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.of(context);
    final casino = CasinoScope.of(context);
    final owner = casino.admin?.isOwner ?? false;
    if (sync == null) return const SizedBox();
    final on = sync.url != null;
    final status = switch (sync.state) {
      SyncState.off => 'Not connected. Everything is kept on this device only, so other phones and computers can’t see it.',
      SyncState.connecting => 'Connecting to ${sync.url}…',
      SyncState.live => 'Live: every device on this database sees the same players, coins and games'
          '${sync.lastSync == null ? '' : ' (synced ${ago(sync.lastSync!, casino.now)})'}.',
      SyncState.offline => 'Can’t reach the database${sync.error == null ? '' : ': ${sync.error}'}. Changes are kept and sent when it’s back.',
    };
    return KCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.cloud_sync_outlined, color: K.sub, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('Shared database', style: kt(18, w: FontWeight.w700))),
          const SyncChip(),
        ]),
        const SizedBox(height: 8),
        Text(status, style: kt(14, c: K.sub, h: 1.4)),
        const SizedBox(height: 12),
        KField(label: 'Firebase Realtime Database URL', controller: url, hint: 'https://your-project-default-rtdb.firebaseio.com', keyboard: TextInputType.url),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          KButton(on ? 'Reconnect' : 'Connect', icon: Icons.link_rounded, height: 42, onTap: () async {
            if (CasinoSync.normalize(url.text) == null) {
              kToast(context, 'Paste the database URL from Firebase');
              return;
            }
            await sync.connect(url.text);
            if (context.mounted) kToast(context, sync.state == SyncState.live ? 'Connected' : (sync.error ?? 'Couldn’t connect'));
          }),
          if (on)
            KButton('Disconnect', tone: KTone.light, height: 42, onTap: () {
              sync.disconnect();
              kToast(context, 'This device works on its own now');
            }),
          KButton(help ? 'Hide steps' : 'How to make one (free)', tone: KTone.ghost, height: 42, onTap: () => setState(() => help = !help)),
        ]),
        if (help) ...[
          const SizedBox(height: 12),
          KCard(
            color: K.field,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final (i, step) in const [
                'Open console.firebase.google.com and add a project (free; Analytics can be off).',
                'In the project: Build → Realtime Database → Create database → pick a location → Start in test mode.',
                'Copy the URL at the top of the Data tab (…firebaseio.com or …firebasedatabase.app).',
                'Paste it above and tap Connect. If the database is empty, this device uploads its data.',
                'Open the player and admin links below on every phone and computer once — they connect by themselves after that.',
              ].indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: K.green),
                      child: Text('${i + 1}', style: kt(12, w: FontWeight.w700, c: Colors.white)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(step, style: kt(14, h: 1.4))),
                  ]),
                ),
              Text('Test mode lets anyone with the URL read and write, and Firebase switches it off after 30 days — '
                  'fine for trying it out; lock the rules down before real use.',
                  style: kt(13, c: K.amber, h: 1.4)),
            ]),
          ),
        ],
        const SizedBox(height: 14),
        _LinkRow('Player app link', playerAppLink(sync)),
        _LinkRow('Admin app link', adminAppLink(sync)),
        if (owner && on) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            KButton('Upload this device’s data', tone: KTone.light, icon: Icons.cloud_upload_outlined, height: 40, onTap: () async {
              if (!await kConfirm(context,
                  title: 'Replace the database?',
                  message: 'Everything in the database is replaced by what this device has. Other devices pick it up within seconds.',
                  action: 'Replace',
                  danger: true)) {
                return;
              }
              try {
                await sync.uploadAll();
                if (context.mounted) kToast(context, 'Database replaced');
              } catch (e) {
                if (context.mounted) kToast(context, '$e');
              }
            }),
          ]),
        ],
      ]),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow(this.label, this.link);
  final String label;
  final String link;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: kt(13, w: FontWeight.w600, c: K.sub)),
              Text(link, maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(14, c: K.text)),
            ]),
          ),
          KButton('Copy', tone: KTone.light, height: 36, onTap: () => copy(context, link, label)),
        ]),
      );
}

/// How to put the admin app on the home screen (shown until it's installed).
class InstallCard extends StatefulWidget {
  const InstallCard({super.key, this.always = false});

  /// Show even when dismissed or already installed (the help sheet).
  final bool always;

  @override
  State<InstallCard> createState() => _InstallCardState();
}

class _InstallCardState extends State<InstallCard> {
  static const _key = 'zoya7.installHint';
  late bool hidden = loadSaved(_key) == 'off';

  @override
  Widget build(BuildContext context) {
    final installed = !kIsWeb || runningStandalone();
    if (!widget.always && (installed || hidden)) return const SizedBox();
    final onAdminPage = pageApp() == 'admin';
    final apple = isAppleMobile();
    final steps = [
      if (!onAdminPage) 'Open the admin app link (copy it below) in ${apple ? 'Safari' : 'your browser'}.',
      if (apple) ...[
        'Tap the Share button (the square with an arrow).',
        'Choose “Add to Home Screen”, then Add.',
      ] else ...[
        'Open the browser menu (⋮) and choose “Install app” or “Add to Home screen”.',
        'On a computer, use the install icon at the right of the address bar.',
      ],
      'Open “Z7 Admin” from your home screen: it stands upright, separate from the game, and stays signed in.',
    ];
    final card = KCard(
      color: K.greenSoft,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: K.green, borderRadius: BorderRadius.circular(10)),
            child: Text('\$', style: kt(22, w: FontWeight.w800, c: Colors.white, h: 1)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(installed && widget.always ? 'Admin app is installed' : 'Add the admin app to your home screen',
                style: kt(16, w: FontWeight.w700, c: K.greenInk)),
          ),
          if (!widget.always)
            KIconButton(Icons.close_rounded, tooltip: 'Hide', size: 32, color: Colors.white, onTap: () {
              save(_key, 'off');
              setState(() => hidden = true);
            }),
        ]),
        const SizedBox(height: 10),
        for (final (i, s) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('${i + 1}.  $s', style: kt(14, c: K.text, h: 1.4)),
          ),
        if (!onAdminPage) _LinkRow('Admin app link', adminAppLink(SyncScope.of(context))),
      ]),
    );
    return widget.always ? card : Padding(padding: const EdgeInsets.only(bottom: 14), child: card);
  }
}
