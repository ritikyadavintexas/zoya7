import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'sound.dart';

/// web/sound.js (absent on the admin page: then the app is silent).
@JS('zoyaSound')
external _Api? get _api;

extension type _Api(JSObject _) implements JSObject {
  external JSPromise<JSAny?> load(JSString name, JSArrayBuffer data);
  external void play(JSString name, JSNumber volume, JSNumber rate, JSBoolean duck);
  external void music(JSString? name, JSNumber volume, JSNumber loopStart, JSNumber loopLength);
  external void pause(JSBoolean paused);
}

SoundOut createSoundOut() => _WebSoundOut();

class _WebSoundOut implements SoundOut {
  static String _mp3(Track t) => '${t.path}.mp3';

  Future<void> _decode(String asset) async {
    final api = _api;
    if (api == null) return;
    final data = await rootBundle.load(asset);
    final bytes = Uint8List.fromList(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    await api.load(asset.toJS, bytes.buffer.toJS).toDart;
  }

  @override
  Future<void> load(String asset) => _decode(asset);

  @override
  Future<void> loadMusic(Track track) => _decode(_mp3(track));

  @override
  void play(String asset, {double volume = 1, double rate = 1, bool duck = false}) =>
      _api?.play(asset.toJS, volume.toJS, rate.toJS, duck.toJS);

  @override
  void music(Track? track, double volume) =>
      _api?.music(track == null ? null : _mp3(track).toJS, volume.toJS, 1.0.toJS, (track?.loop ?? 0).toJS);

  @override
  void pause(bool paused) => _api?.pause(paused.toJS);
}
