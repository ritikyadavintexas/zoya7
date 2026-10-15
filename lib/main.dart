import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'games/gold/gold_game.dart';

/// Set by CI (`--dart-define=BUILD_SHA=…`) so you can tell which build is on your phone.
const _buildSha = String.fromEnvironment('BUILD_SHA');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  runApp(const Zoya7GoldApp());
}

final _messenger = GlobalKey<ScaffoldMessengerState>();

class Zoya7GoldApp extends StatelessWidget {
  const Zoya7GoldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zoya7 — Gold',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messenger,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: Scaffold(
        backgroundColor: const Color(0xFF1A0F04),
        resizeToAvoidBottomInset: false,
        body: _PreviewShell(
          child: GoldGame(
            onBuyCoins: (cur) => _toast('Open wallet (${cur.name.toUpperCase()})'),
            onOpenPlayLimits: () => _toast('Open play limits'),
            onExitToLobby: () => _toast('Back to lobby'),
          ),
        ),
      ),
    );
  }

  static void _toast(String msg) {
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }
}

/// Dev conveniences: a "turn sideways" prompt in a portrait browser,
/// and the build id in the corner so you know your phone has the latest.
class _PreviewShell extends StatelessWidget {
  const _PreviewShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final portrait = box.maxHeight > box.maxWidth;
      return Stack(children: [
        Positioned.fill(child: child),
        if (kIsWeb && portrait)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xF21A0F04),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.screen_rotation, size: 56, color: Color(0xFFFFD45A)),
                  SizedBox(height: 16),
                  Text('Turn your phone sideways to play',
                      style: TextStyle(fontSize: 18, color: Color(0xFFFFF4D6))),
                ]),
              ),
            ),
          ),
        if (_buildSha.isNotEmpty)
          Positioned(
            left: 8,
            bottom: 6,
            child: IgnorePointer(
              child: Text('build $_buildSha',
                  style: const TextStyle(fontSize: 11, color: Color(0x80FFF4D6))),
            ),
          ),
      ]);
    });
  }
}
