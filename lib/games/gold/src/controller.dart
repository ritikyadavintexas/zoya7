import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'math.dart';

enum GoldPanel { none, paytable, settings, noCoins }

class ChatMessage {
  const ChatMessage({this.name = '', this.text = '', this.color, this.mine = false, this.system = false});
  final String name;
  final String text;
  final int? color;
  final bool mine;
  final bool system;
}

/// Sound hooks (the app plays each skin's sounds). Effects are only asked
/// for while the player's Sound effects setting is on.
abstract class GoldAudio {
  void spinStart() {}
  void reelStop(int reel) {}
  void win(WinTier? tier, double amount) {}

  /// Bet −/+, max bet, auto.
  void button() {}

  /// COLLECT on a win banner.
  void collect() {}

  /// The player switched sound effects or music on or off in the game's settings.
  void sfx(bool on) {}
  void music(bool on) {}
}

class _SilentAudio extends GoldAudio {}

/// All Gold game state and rules, mirroring the design's component logic.
class GoldController extends ChangeNotifier {
  GoldController({
    GoldOutcomeSource? outcomes,
    GoldAudio? audio,
    double initialGc = 1250000,
    double initialSc = 125.5,
    Currency currency = Currency.gc,
    WinTier? previewOverlay,
    GoldPanel previewPanel = GoldPanel.none,
    this.minBetIdx = 0,
    this.maxBetIdx = GoldRules.maxBetIndex,
    this.sfx = true,
    this.music = true,
    this.gcAllowed = true,
  })  : outcomes = outcomes ?? LocalGoldMath(),
        audio = audio ?? _SilentAudio(),
        gc = initialGc,
        sc = initialSc,
        mode = gcAllowed ? currency : Currency.sc,
        overlay = previewOverlay,
        panel = previewPanel {
    _tickTimer = Timer.periodic(const Duration(milliseconds: 180), (_) => tick.value++);
  }

  final GoldOutcomeSource outcomes;
  final GoldAudio audio;

  /// Gold Coins switched off by the owner: DC only, and GC shown nowhere.
  final bool gcAllowed;

  // Wallet & bet
  Currency mode;
  double gc;
  double sc;
  late int betIdx = 2.clamp(minBetIdx, maxBetIdx);

  /// The bet steps this table offers (set from the back office).
  final int minBetIdx;
  final int maxBetIdx;

  // Reels
  List<List<Sym>> grid = [
    [Sym.cherry, Sym.seven, Sym.lemon],
    [Sym.bell, Sym.seven, Sym.plum],
    [Sym.melon, Sym.seven, Sym.orange],
  ];
  List<bool> spinning = [false, false, false];
  bool busy = false;

  // Results
  double win = 0;
  int lastMult = 0;
  JackpotTier? jpHit;
  WinTier? overlay;
  bool auto = false;

  // UI
  GoldPanel panel;
  bool chatOpen = false;
  bool chatSeen = false;
  int chatUnread = 3;
  bool sfx;
  bool music;
  bool fastSpin = false;
  bool haptics = true;

  final List<ChatMessage> chat = [
    const ChatMessage(name: 'LuckyLina', color: 0xFFC99BFF, text: 'Reels are warm tonight'),
    const ChatMessage(name: 'SpinKing', color: 0xFF8CC0FF, text: 'Just hit three bells, 20x!'),
    const ChatMessage(system: true, text: 'SpinKing won 50,000 GC on Gold slots'),
    const ChatMessage(name: 'RubyRose', color: 0xFFFF8A7A, text: 'Good luck everyone'),
  ];

  /// Drives the live jackpot meters without rebuilding the whole game.
  final ValueNotifier<int> tick = ValueNotifier(0);

  Timer? _tickTimer;
  final List<Timer> _timers = [];
  GoldSpinOutcome? _pending;
  int _spinSerial = 0;
  bool _disposed = false;

  /// Reel settle animation length; results are shown after the last reel lands.
  Duration get settleDuration => Duration(milliseconds: fastSpin ? 170 : 260);
  List<int> get _stopTimes => fastSpin ? const [350, 500, 650] : const [700, 1000, 1300];

  double get bet => GoldRules.bets[mode]![betIdx];
  double get balance => mode == Currency.gc ? gc : sc;
  bool get hasPending => _pending != null;

  Map<JackpotTier, double> jackpots([Currency? c]) {
    final t = tick.value;
    return (c ?? mode) == Currency.sc
        ? {
            JackpotTier.mega: 5000 + t * 0.07,
            JackpotTier.major: 500 + t * 0.03,
            JackpotTier.minor: 50 + t * 0.01,
            JackpotTier.mini: 10 + (t ~/ 4) * 0.01,
          }
        : {
            JackpotTier.mega: 5000000.0 + t * 37,
            JackpotTier.major: 500000.0 + t * 11,
            JackpotTier.minor: 50000.0 + t * 3,
            JackpotTier.mini: 10000.0 + t,
          };
  }

  void _set(VoidCallback f) {
    if (_disposed) return;
    f();
    notifyListeners();
  }

  // ── Currency & bet ─────────────────────────────────────────────────────────
  void pickCurrency(Currency c) {
    if (busy || (c == Currency.gc && !gcAllowed)) return;
    _set(() {
      mode = c;
      win = 0;
      lastMult = 0;
    });
  }

  void betDown() {
    if (!busy && betIdx > minBetIdx) _set(() => betIdx--);
    _click();
  }

  void betUp() {
    if (!busy && betIdx < maxBetIdx) _set(() => betIdx++);
    _click();
  }

  void maxBet() {
    if (!busy) _set(() => betIdx = maxBetIdx);
    _click();
  }

  void _click() {
    if (sfx) audio.button();
  }

  void toggleAuto() {
    _click();
    final next = !auto;
    _set(() => auto = next);
    if (next) spin();
  }

  // ── Spin flow ──────────────────────────────────────────────────────────────
  Future<void> spin() async {
    if (busy || overlay != null || panel != GoldPanel.none) return;
    final m = mode;
    final b = bet;
    if (balance < b) {
      _set(() {
        auto = false;
        panel = GoldPanel.noCoins;
      });
      return;
    }
    final serial = ++_spinSerial;
    final started = DateTime.now();
    _set(() {
      if (m == Currency.gc) {
        gc = round2(gc - b);
      } else {
        sc = round2(sc - b);
      }
      busy = true;
      spinning = [true, true, true];
      win = 0;
      lastMult = 0;
      jpHit = null;
    });
    if (sfx) audio.spinStart();

    final GoldSpinOutcome outcome;
    try {
      outcome = await outcomes.spin(bet: b, currency: m, jackpots: jackpots(m));
    } catch (e) {
      // Refund and reset if the result can't be fetched.
      _set(() {
        if (m == Currency.gc) {
          gc = round2(gc + b);
        } else {
          sc = round2(sc + b);
        }
        busy = false;
        auto = false;
        spinning = [false, false, false];
      });
      return;
    }
    if (_disposed || serial != _spinSerial) return;
    _pending = outcome;
    _pendingMode = m;

    final elapsed = DateTime.now().difference(started).inMilliseconds;
    for (var i = 0; i < 3; i++) {
      final wait = math.max(0, _stopTimes[i] - elapsed);
      _timers.add(Timer(Duration(milliseconds: wait), () => _landReel(i)));
    }
  }

  Currency _pendingMode = Currency.gc;

  void _landReel(int i) {
    final p = _pending;
    if (p == null) return;
    _set(() {
      grid = [...grid]..[i] = p.grid[i];
      spinning = [...spinning]..[i] = false;
    });
    if (sfx) audio.reelStop(i);
    if (i == 2) _timers.add(Timer(settleDuration, _finish));
  }

  /// STOP button: land every reel now.
  void stop() {
    final p = _pending;
    if (p == null) return;
    _clearTimers();
    _set(() {
      grid = p.grid;
      spinning = [false, false, false];
    });
    _timers.add(Timer(settleDuration, _finish));
  }

  void _finish() {
    final p = _pending;
    if (p == null) return;
    _pending = null;
    final tier = GoldRules.tierFor(p.multiplier, p.jackpot);
    _set(() {
      if (_pendingMode == Currency.gc) {
        gc = round2(gc + p.win);
      } else {
        sc = round2(sc + p.win);
      }
      win = p.win;
      lastMult = p.multiplier;
      jpHit = p.jackpot;
      busy = false;
      overlay = tier ?? overlay;
    });
    if (sfx) audio.win(tier, p.win);
    if (tier != null && haptics) HapticFeedback.heavyImpact();
    if (auto && tier == null) {
      _timers.add(Timer(const Duration(milliseconds: 700), spin));
    }
  }

  void collect() {
    if (sfx && overlay != null) audio.collect();
    _set(() {
      overlay = null;
      auto = false;
    });
  }

  /// Amount shown on the celebration overlay (design uses samples in preview states).
  double overlayAmount() {
    if (win > 0) return win;
    final b = bet;
    return switch (overlay) {
      WinTier.big => b * 15,
      WinTier.superWin => b * 20,
      WinTier.mega => b * 30,
      WinTier.jackpot => jackpots()[JackpotTier.mega]!,
      null => 0,
    };
  }

  String get winNote {
    if (busy) return 'Good luck!';
    if (jpHit != null) return '${_jpName(jpHit!)}!';
    if (lastMult > 0) return 'Payline win · $lastMult× bet';
    return 'Line up three on the payline';
  }

  static String _jpName(JackpotTier t) => '${t.name.toUpperCase()} JACKPOT';
  String get jackpotHitName => _jpName(jpHit ?? JackpotTier.mega);
  JackpotTier get jackpotHitTier => jpHit ?? JackpotTier.mega;

  // ── Panels ─────────────────────────────────────────────────────────────────
  void openPaytable() => _set(() => panel = GoldPanel.paytable);
  void openSettings() => _set(() => panel = GoldPanel.settings);
  void closePanel() => _set(() => panel = GoldPanel.none);

  void lowerBet() => _set(() {
        betIdx = minBetIdx;
        panel = GoldPanel.none;
      });

  void switchCurrency() => _set(() {
        if (gcAllowed) mode = mode == Currency.sc ? Currency.gc : Currency.sc;
        panel = GoldPanel.none;
        win = 0;
        lastMult = 0;
      });

  void toggleSfx() {
    _set(() => sfx = !sfx);
    audio.sfx(sfx);
  }
  void toggleMusic() {
    _set(() => music = !music);
    audio.music(music);
  }

  void toggleFastSpin() => _set(() => fastSpin = !fastSpin);
  void toggleHaptics() => _set(() => haptics = !haptics);

  // ── Chat ───────────────────────────────────────────────────────────────────
  void openChat() => _set(() {
        chatOpen = true;
        chatSeen = true;
      });

  void closeChat() => _set(() => chatOpen = false);

  void chatSend(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _set(() => chat.add(ChatMessage(mine: true, name: 'You', text: t)));
    // Demo reply from the design prototype; replace with the real chat service.
    _timers.add(Timer(const Duration(milliseconds: 1400), () {
      _set(() => chat.add(const ChatMessage(name: 'LuckyLina', color: 0xFFC99BFF, text: 'Haha same! Good luck')));
    }));
  }

  void _clearTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    _tickTimer?.cancel();
    _clearTimers();
    tick.dispose();
    super.dispose();
  }
}
