import 'dart:async';

import 'package:flutter/material.dart';

import '../assets.dart';
import '../game_frame.dart';
import '../html_host.dart';
import '../nav.dart';
import '../site.dart';
import '../sound.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// A game uploaded from the admin panel, running in a frame. The game brings
/// its own screen, sounds and back button; the app holds the coins and draws
/// each round ([HtmlGameHost]).
class HtmlGameScreen extends StatefulWidget {
  const HtmlGameScreen({super.key, required this.gameId});
  final String gameId;

  @override
  State<HtmlGameScreen> createState() => _HtmlGameScreenState();
}

class _HtmlGameScreenState extends State<HtmlGameScreen> {
  late final AppState _app;
  late final HtmlGameHost _host;
  late final GameFrame _frame;
  late final AppLifecycleListener _lifecycle;
  bool _started = false, _ready = false, _failed = false;
  Timer? _giveUp, _lift;
  Map<String, bool>? _sound;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _app = AppScope.read(context);
    _host = HtmlGameHost(gameId: widget.gameId, app: _app);
    final h = _app.casino.config(widget.gameId).html;
    _frame = createGameFrame(siteUrl('${h?.folder(widget.gameId) ?? 'games/${widget.gameId}'}/index.html'), _onMessage);
    _app.addListener(_appChanged);
    _sound = _host.soundSettings();
    _lifecycle = AppLifecycleListener(
      onHide: () => _frame.send(HtmlGameHost.event('pause')),
      onShow: () => _frame.send(HtmlGameHost.event('resume')),
    );
    _giveUp = Timer(const Duration(seconds: 20), () {
      if (mounted && !_ready) setState(() => _failed = true);
    });
  }

  void _onMessage(Object? data) {
    final (reply, action) = _host.handle(data);
    if (reply != null) _frame.send(reply);
    // A game that forgets Zoya7.ready() still gets the loading cover lifted.
    if (data is Map && data['type'] == 'init' && !_ready) {
      _lift ??= Timer(const Duration(milliseconds: 1500), () => _show());
    }
    switch (action) {
      case HostAction.ready:
        _show();
      case HostAction.exit:
        if (mounted) Nav.back(context);
      case HostAction.buyCoins:
        Nav.tab(AppTab.wallet, walletTab: 'buy');
      case HostAction.none:
        break;
    }
  }

  void _show() {
    if (mounted && !_ready) setState(() => _ready = true);
  }

  /// Coins added (or taken) outside the game, and sound settings, reach it as they change.
  void _appChanged() {
    final b = _host.balanceEvent();
    if (b != null) _frame.send(b);
    final s = _host.soundSettings();
    if (s['effects'] != _sound?['effects'] || s['music'] != _sound?['music']) {
      _sound = s;
      _frame.send(HtmlGameHost.event('sound', s));
    }
  }

  @override
  void dispose() {
    _giveUp?.cancel();
    _lift?.cancel();
    _lifecycle.dispose();
    _app.removeListener(_appChanged);
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = gameById(widget.gameId);
    final view = _frame.view;
    return SoundScope(
      // The game plays its own music: the lobby's stops while it's open.
      music: Sounds.silence,
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(children: [
          if (view != null) Positioned.fill(child: view),
          if (view == null)
            _Cover(name: g.name, message: 'This game plays in the web version of Zoya7 for now.')
          else if (_failed)
            _Cover(name: g.name, message: 'The game didn’t start. Check your connection and try again.')
          else if (!_ready)
            _Cover(name: g.name, loading: true),
        ]),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.name, this.message, this.loading = false});
  final String name;
  final String? message;
  final bool loading;

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: ColoredBox(
          color: Z.ink,
          child: Stack(children: [
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(name, textAlign: TextAlign.center, style: outfit(26, w: FontWeight.w800, c: Z.cream)),
                const SizedBox(height: 18),
                if (loading)
                  const SizedBox(width: 34, height: 34, child: CircularProgressIndicator(strokeWidth: 3, color: Z.gold))
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(message ?? '', textAlign: TextAlign.center, style: outfit(15, c: Z.muted, h: 1.4)),
                  ),
              ]),
            ),
            const Positioned(left: 16, top: 12, child: SafeArea(child: BackBtn(label: 'Back to lobby'))),
          ]),
        ),
      );
}
