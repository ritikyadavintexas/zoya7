import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../app/web_env.dart';
import '../backoffice/storage.dart';
import '../backoffice/sync.dart';
import 'admin_app.dart' show AdminLogo;
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

String playerAppLink() => siteRoot();
String adminAppLink() => '${siteRoot()}admin/';

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

/// The server (Firebase) every device works on: whether this one is in step.
class DatabaseCard extends StatelessWidget {
  const DatabaseCard({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.of(context);
    final casino = CasinoScope.of(context);
    if (sync == null) return const SizedBox();
    final status = switch (sync.state) {
      SyncState.off || SyncState.connecting => 'Connecting to the server…',
      SyncState.live => 'Live: every phone and computer sees the same players, coins and games'
          '${sync.lastSync == null ? '' : ' (synced ${ago(sync.lastSync!, casino.now)})'}.',
      SyncState.offline => 'Can’t reach the server${sync.error == null ? '' : ': ${sync.error}'}. Changes made now are sent when it’s back — keep the app open.',
    };
    return KCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.cloud_sync_outlined, color: K.sub, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('Server (Firebase)', style: kt(18, w: FontWeight.w700))),
          const SyncChip(),
        ]),
        const SizedBox(height: 8),
        Text(status, style: kt(14, c: K.sub, h: 1.4)),
        if (sync.url != null) ...[
          const SizedBox(height: 4),
          Text(sync.url!, maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(13, c: K.faint)),
        ],
        const SizedBox(height: 14),
        _LinkRow('Player app link', playerAppLink()),
        _LinkRow('Admin app link', adminAppLink()),
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
        'Open the browser menu (the three dots) and choose “Install app” or “Add to Home screen”.',
        'On a computer, use the install icon at the right of the address bar.',
      ],
      'Open “Z7 Admin” from your home screen: it stands upright, separate from the game, and stays signed in.',
    ];
    final card = KCard(
      color: K.greenSoft,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const AdminLogo(size: 40),
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
        if (!onAdminPage) _LinkRow('Admin app link', adminAppLink()),
      ]),
    );
    return widget.always ? card : Padding(padding: const EdgeInsets.only(bottom: 14), child: card);
  }
}
