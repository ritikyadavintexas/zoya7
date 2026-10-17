import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'game_frame.dart';

GameFrame createGameFrame(String url, void Function(Object? data) onMessage) => _WebFrame(url, onMessage);

/// A sandboxed iframe: the game runs its scripts but can't reach the app's
/// page, storage or sign-in, and talks to it only by postMessage.
class _WebFrame implements GameFrame {
  _WebFrame(String url, void Function(Object? data) onMessage) {
    _iframe = web.HTMLIFrameElement()
      ..src = url
      ..setAttribute('sandbox', 'allow-scripts allow-pointer-lock')
      ..setAttribute('allow', 'autoplay; fullscreen')
      ..setAttribute('title', 'Game');
    _iframe.style
      ..border = 'none'
      ..width = '100%'
      ..height = '100%'
      ..display = 'block'
      ..background = '#000';
    _viewType = 'zoya7-game-${_count++}';
    final frame = _iframe;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) => frame);
    _listener = ((web.MessageEvent e) {
      // Only the game's own frame is listened to.
      final source = e.source;
      if (source == null || !source.strictEquals(_iframe.contentWindow).toDart) return;
      onMessage(e.data.dartify());
    }).toJS;
    web.window.addEventListener('message', _listener);
  }

  static int _count = 0;
  late final web.HTMLIFrameElement _iframe;
  late final String _viewType;
  late final JSFunction _listener;

  @override
  Widget get view => HtmlElementView(viewType: _viewType);

  @override
  void send(Map<String, Object?> message) => _iframe.contentWindow?.postMessage(message.jsify(), '*'.toJS);

  @override
  void dispose() => web.window.removeEventListener('message', _listener);
}
