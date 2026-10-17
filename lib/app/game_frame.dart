import 'package:flutter/widgets.dart';

import 'game_frame_stub.dart' if (dart.library.js_interop) 'game_frame_web.dart' as impl;

/// An uploaded game's page, shown in a frame, with messages both ways.
abstract class GameFrame {
  /// The page; null where frames aren't available (the phone app, for now).
  Widget? get view;

  void send(Map<String, Object?> message);
  void dispose();
}

/// A frame for [url] (relative to the site) that passes the game's messages to [onMessage].
GameFrame createGameFrame(String url, void Function(Object? data) onMessage) => impl.createGameFrame(url, onMessage);
