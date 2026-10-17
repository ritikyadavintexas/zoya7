import 'package:flutter/material.dart';

import '../../games/gold/gold_game.dart';
import '../nav.dart';
import '../sound.dart';
import '../state.dart';

/// Classic 777 / Fruit Spin / Phoenix Ruby (the Gold slot), hosted inside the (landscape)
/// app. Reel math and bet range come from the back office; every spin moves
/// the app's balance and is recorded for the reports. Plays the game's music
/// and sounds.
class GoldScreen extends StatelessWidget {
  const GoldScreen({super.key, this.gameId = 'classic777'});
  final String gameId;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
    final cfg = s.casino.config(gameId);
    final skin = SlotSkin.forGame(gameId);
    return SoundScope(
      music: Track('${skin.sounds}/music', skin.musicLoop),
      effects: [...skin.effects, Sounds.tap, Sounds.coins],
      child: Scaffold(
        backgroundColor: skin.background.last,
        resizeToAvoidBottomInset: false,
        body: GoldGame(
          outcomes: _Recorded(gameId, s, LocalGoldMath(weights: cfg.weights)),
          audio: _SlotSounds(s, skin),
          sfx: s.settings['sound'] ?? true,
          music: s.settings['music'] ?? true,
          initialGc: s.gc,
          initialSc: s.sc,
          minBetIdx: cfg.minIdx,
          maxBetIdx: cfg.maxIdx,
          onExitToLobby: () => Nav.back(context),
          onBuyCoins: (_) => Nav.tab(AppTab.wallet, walletTab: 'buy'),
          onOpenPlayLimits: () => Nav.push(R.settings),
          skin: skin,
        ),
      ),
    );
  }
}

/// The skin's sounds for each moment of a spin. The game's own Sound effects
/// and Music switches are the app's settings.
class _SlotSounds extends GoldAudio {
  _SlotSounds(this.s, this.skin);
  final AppState s;
  final SlotSkin skin;

  Sound get _sound => Sound.instance;

  @override
  void spinStart() => _sound.play(skin.sound('spin'));

  /// A little higher for each reel, so the three stops climb.
  @override
  void reelStop(int reel) => _sound.play(skin.sound('reel_stop'), rate: 1 + reel * .06);

  @override
  void win(WinTier? tier, double amount) {
    if (amount <= 0) return;
    switch (tier) {
      case null:
        _sound.play(skin.sound('win_small'));
      case WinTier.jackpot:
        _sound.play(skin.sound('jackpot'), duck: true);
      case _:
        _sound.play(skin.sound('win_big'), duck: true);
    }
  }

  @override
  void button() => skin.extraSounds.contains('button') ? _sound.play(skin.sound('button')) : _sound.tap();

  @override
  void collect() => _sound.play(skin.extraSounds.contains('collect') ? skin.sound('collect') : Sounds.coins);

  @override
  void sfx(bool on) => s.setSetting('sound', on);

  @override
  void music(bool on) => s.setSetting('music', on);
}

/// Passes spins through to the math and books each one.
class _Recorded implements GoldOutcomeSource {
  _Recorded(this.gameId, this.s, this.math);
  final String gameId;
  final AppState s;
  final GoldOutcomeSource math;

  @override
  Sym fillerSymbol() => math.fillerSymbol();

  @override
  Future<GoldSpinOutcome> spin({
    required double bet,
    required Currency currency,
    required Map<JackpotTier, double> jackpots,
  }) async {
    final o = await math.spin(bet: bet, currency: currency, jackpots: jackpots);
    s.recordRound(gameId, currency, bet, o.win);
    return o;
  }
}
