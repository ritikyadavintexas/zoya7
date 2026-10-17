import 'package:flutter/widgets.dart';

import 'game_frame.dart';

GameFrame createGameFrame(String url, void Function(Object? data) onMessage) => _NoFrame();

class _NoFrame implements GameFrame {
  @override
  Widget? get view => null;
  @override
  void send(Map<String, Object?> message) {}
  @override
  void dispose() {}
}
