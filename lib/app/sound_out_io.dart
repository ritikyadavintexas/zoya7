import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';

import 'sound.dart';

/// Phones (and desktop): audioplayers. Silent under `flutter test`.
SoundOut createSoundOut() => Platform.environment.containsKey('FLUTTER_TEST') ? SilentSoundOut() : _NativeSoundOut();

class _NativeSoundOut implements SoundOut {
  _NativeSoundOut() {
    // Effects play over the music instead of taking the audio focus from it.
    AudioPlayer.global
        .setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build())
        .catchError((Object _) {});
  }

  final _pools = <String, AudioPool>{};
  AudioPlayer? _player;

  /// audioplayers looks assets up under "assets/".
  static String _key(String asset) => asset.substring('assets/'.length);

  @override
  Future<void> load(String asset) async {
    _pools[asset] ??= await AudioPool.create(source: AssetSource(_key(asset)), maxPlayers: 3, playerMode: PlayerMode.lowLatency);
  }

  @override
  Future<void> loadMusic(Track track) async {}

  @override
  void play(String asset, {double volume = 1, double rate = 1, bool duck = false}) {
    _pools[asset]?.start(volume: volume).catchError((Object _) => () async {});
  }

  @override
  Future<void> music(Track? track, double volume) async {
    try {
      final p = _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      await p.stop();
      if (track == null) return;
      await p.setVolume(volume);
      await p.play(AssetSource('${_key(track.path)}.ogg'));
    } catch (_) {}
  }

  @override
  void pause(bool paused) {
    final p = _player;
    if (p == null) return;
    (paused ? p.pause() : p.resume()).catchError((Object _) {});
  }
}
