import 'package:flutter/widgets.dart';

import 'sound_out_io.dart' if (dart.library.js_interop) 'sound_out_web.dart' as impl;

/// A music loop. [loop] is its exact length in seconds: the web plays `<path>.mp3`, which has a
/// 1 s wrap-around pad at each end (see tools/sounds/make_sounds.py), from 1 s to 1 s + [loop];
/// phones loop `<path>.ogg` whole.
@immutable
class Track {
  const Track(this.path, this.loop);

  /// Without the extension.
  final String path;
  final double loop;

  @override
  bool operator ==(Object other) => other is Track && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

/// The app's own sounds (all made by tools/sounds/make_sounds.py). Each game's sounds come
/// with its skin.
class Sounds {
  Sounds._();
  static const _d = 'assets/sounds';
  static const tap = '$_d/tap.mp3';
  static const coins = '$_d/coins.mp3';
  static const lobby = Track('$_d/lobby', 38.4);

  static const blackjackMusic = Track('assets/games/blackjack/sounds/music', 40);
  static String blackjack(String name) => 'assets/games/blackjack/sounds/$name.mp3';
}

/// What makes the sound on this platform (Web Audio on the web, audioplayers on phones).
abstract class SoundOut {
  Future<void> load(String asset);
  Future<void> loadMusic(Track track);

  /// [duck]: lower the music while this plays.
  void play(String asset, {double volume = 1, double rate = 1, bool duck = false});

  /// Fades over to [track] (loaded), or out to silence.
  void music(Track? track, double volume);

  /// The app went to the background (or came back).
  void pause(bool paused);
}

class SilentSoundOut implements SoundOut {
  @override
  Future<void> load(String asset) async {}
  @override
  Future<void> loadMusic(Track track) async {}
  @override
  void play(String asset, {double volume = 1, double rate = 1, bool duck = false}) {}
  @override
  void music(Track? track, double volume) {}
  @override
  void pause(bool paused) {}
}

/// Sound effects and background music, following the player's Sound and Music settings.
///
/// Music is a stack: the lobby plays its loop, a game opened over it plays its own, and the
/// lobby's comes back when the game closes ([SoundScope]). Browsers keep sound off until the
/// first tap; web/sound.js starts it then.
class Sound {
  Sound(this._out);

  static final instance = Sound(impl.createSoundOut());

  static const musicVolume = .45;

  final SoundOut _out;
  final _loaded = <String, Future<void>>{};
  final _tracks = <Track>[];
  bool _sfxOn = true, _musicOn = true, _paused = false;
  Track? _playing;

  void configure({required bool sfx, required bool music}) {
    _sfxOn = sfx;
    _musicOn = music;
    _applyMusic();
  }

  /// Gets effects ready so they play the moment they're needed.
  Future<void> preload(Iterable<String> assets) => Future.wait(assets.map(_load));

  Future<void> _load(String asset) => _loaded.putIfAbsent(asset, () => _out.load(asset).catchError((Object _) {}));

  void play(String asset, {double volume = 1, double rate = 1, bool duck = false}) {
    if (!_sfxOn || _paused) return;
    final asked = DateTime.now();
    _load(asset).then((_) {
      // A sound that took too long to load is dropped rather than played late.
      if (DateTime.now().difference(asked) > const Duration(milliseconds: 400)) return;
      if (_sfxOn && !_paused) _out.play(asset, volume: volume, rate: rate, duck: duck);
    });
  }

  void tap() => play(Sounds.tap, volume: .8);

  void pushMusic(Track t) {
    _tracks.add(t);
    _applyMusic();
  }

  void popMusic(Track t) {
    final i = _tracks.lastIndexOf(t);
    if (i >= 0) _tracks.removeAt(i);
    _applyMusic();
  }

  void setPaused(bool paused) {
    if (paused == _paused) return;
    _paused = paused;
    _out.pause(paused);
    _applyMusic();
  }

  void _applyMusic() {
    final want = _musicOn && !_paused && _tracks.isNotEmpty ? _tracks.last : null;
    if (want == _playing) return;
    _playing = want;
    if (want == null) {
      _out.music(null, 0);
      return;
    }
    _out.loadMusic(want).then((_) {
      if (_playing == want) _out.music(want, musicVolume);
    }, onError: (Object _) {});
  }
}

/// While on screen: plays [music] (over whatever played before, which comes back afterwards)
/// and has [effects] loaded, ready to play.
class SoundScope extends StatefulWidget {
  const SoundScope({super.key, this.music, this.effects = const [], required this.child});
  final Track? music;
  final List<String> effects;
  final Widget child;

  @override
  State<SoundScope> createState() => _SoundScopeState();
}

class _SoundScopeState extends State<SoundScope> {
  @override
  void initState() {
    super.initState();
    final m = widget.music;
    if (m != null) Sound.instance.pushMusic(m);
    Sound.instance.preload(widget.effects);
  }

  @override
  void dispose() {
    final m = widget.music;
    if (m != null) Sound.instance.popMusic(m);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
