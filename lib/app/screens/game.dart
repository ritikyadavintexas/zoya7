import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../games/gold/gold_game.dart';
import '../nav.dart';
import '../state.dart';
import '../theme.dart';

/// Portrait for the app pages, landscape while a game is open (native only;
/// browsers can't lock orientation, so the web build asks the player to turn).
Future<void> usePortrait() async {
  if (kIsWeb) return;
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}

Future<void> useLandscape() async {
  if (kIsWeb) return;
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}

/// Classic 777 (Gold) — the landscape slot, hosted inside the app.
class GoldScreen extends StatefulWidget {
  const GoldScreen({super.key});

  @override
  State<GoldScreen> createState() => _GoldScreenState();
}

class _GoldScreenState extends State<GoldScreen> {
  @override
  void initState() {
    super.initState();
    useLandscape();
  }

  @override
  void dispose() {
    usePortrait();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
    return Scaffold(
      backgroundColor: const Color(0xFF1A0F04),
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(builder: (context, box) {
        final portrait = box.maxHeight > box.maxWidth;
        return Stack(children: [
          Positioned.fill(
            child: GoldGame(
              initialGc: s.gc,
              initialSc: s.sc,
              onExitToLobby: () => Nav.back(context),
              onBuyCoins: (_) => Nav.tab(AppTab.wallet, walletTab: 'buy'),
              onOpenPlayLimits: () => Nav.push(R.settings),
            ),
          ),
          if (kIsWeb && portrait)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0xF21A0F04),
                child: SafeArea(
                  child: Stack(children: [
                    Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.screen_rotation, size: 56, color: Color(0xFFFFD45A)),
                        const SizedBox(height: 16),
                        Text('Turn your phone sideways to play', style: outfit(18, c: const Color(0xFFFFF4D6))),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () => Nav.back(context),
                          child: Text('Back to lobby', style: outfit(15, w: FontWeight.w600, c: Z.gold)),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
        ]);
      }),
    );
  }
}
