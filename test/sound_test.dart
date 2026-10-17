import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zoya7_gold/app/sound.dart';
import 'package:zoya7_gold/games/blackjack/controller.dart';
import 'package:zoya7_gold/games/blackjack/engine.dart';
import 'package:zoya7_gold/games/gold/gold_game.dart';

/// Records what the app asked to hear.
class _Out implements SoundOut {
  final played = <String>[];
  final tracks = <String?>[];

  @override
  Future<void> load(String asset) async {}
  @override
  Future<void> loadMusic(Track track) async {}
  @override
  void play(String asset, {double volume = 1, double rate = 1, bool duck = false}) => played.add(asset);
  @override
  void music(Track? track, double volume) => tracks.add(track?.path);
  @override
  void pause(bool paused) {}
}

class _Wallet implements BlackjackWallet {
  final b = {Currency.gc: 125000.0, Currency.sc: 250.5};
  @override
  double balance(Currency c) => b[c]!;
  @override
  void add(Currency c, double amount) => b[c] = b[c]! + amount;
}

/// Samples in an Ogg Vorbis file (the last page's granule position).
int oggSamples(String path) {
  final bytes = File(path).readAsBytesSync();
  var i = bytes.length - 4;
  while (i >= 0 && !(bytes[i] == 0x4F && bytes[i + 1] == 0x67 && bytes[i + 2] == 0x67 && bytes[i + 3] == 0x53)) {
    i--;
  }
  return ByteData.sublistView(bytes, i + 6, i + 14).getInt64(0, Endian.little);
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('music follows the screens: the lobby, a game over it, the lobby again', () async {
    final out = _Out();
    final s = Sound(out);
    const game = Track('assets/games/fruit/sounds/music', 34);
    s.pushMusic(Sounds.lobby);
    await settle();
    s.pushMusic(game);
    await settle();
    s.popMusic(game);
    await settle();
    expect(out.tracks, [Sounds.lobby.path, game.path, Sounds.lobby.path]);
  });

  test('the Sound and Music settings silence effects and music', () async {
    final out = _Out();
    final s = Sound(out)..pushMusic(Sounds.lobby);
    await settle();
    s.configure(sfx: false, music: false);
    s.play(Sounds.tap);
    await settle();
    expect(out.played, isEmpty);
    expect(out.tracks.last, isNull);

    s.configure(sfx: true, music: true);
    s.play(Sounds.tap);
    await settle();
    expect(out.played, [Sounds.tap]);
    expect(out.tracks.last, Sounds.lobby.path);

    // In the background: nothing plays.
    s.setPaused(true);
    s.play(Sounds.tap);
    await settle();
    expect(out.played, hasLength(1));
    expect(out.tracks.last, isNull);
  });

  test('every game has all its sounds, and each music file is exactly its loop long', () {
    final tracks = <Track>[Sounds.lobby, Sounds.blackjackMusic];
    final effects = <String>[Sounds.tap, Sounds.coins, for (final x in BjSound.values) Sounds.blackjack(x.name)];
    for (final skin in [SlotSkin.classic, SlotSkin.fruit, SlotSkin.phoenix]) {
      tracks.add(Track('${skin.sounds}/music', skin.musicLoop));
      effects.addAll(skin.effects);
    }
    for (final f in effects) {
      expect(File(f).existsSync(), isTrue, reason: f);
    }
    for (final t in tracks) {
      expect(File('${t.path}.mp3').existsSync(), isTrue, reason: t.path);
      expect(oggSamples('${t.path}.ogg') / 44100, closeTo(t.loop, .001), reason: t.path);
    }
    // Each slot sounds like itself.
    expect({SlotSkin.classic.sounds, SlotSkin.fruit.sounds, SlotSkin.phoenix.sounds}, hasLength(3));
  });

  test('blackjack calls for a chip, the four cards and the blackjack', () async {
    final heard = <BjSound>[];
    PlayingCard card(int rank) => PlayingCard(rank, Suit.spades);
    final c = BlackjackController(
      wallet: _Wallet(),
      shoe: Shoe.stacked([card(1), card(9), card(13), card(7)]),
      pace: const Duration(milliseconds: 1),
      onSound: heard.add,
    );
    c.addChip(500);
    await c.deal();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(heard.where((s) => s == BjSound.card), hasLength(4));
    expect(heard.first, BjSound.chip);
    expect(heard, contains(BjSound.blackjack));
  });
}
