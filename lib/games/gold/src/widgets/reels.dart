import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../assets.dart';
import '../controller.dart';
import '../math.dart';
import '../style.dart';
import 'fx.dart';

/// Reel window: 3 reels behind the design's frame artwork, plus the payline.
class GoldReels extends StatelessWidget {
  const GoldReels({super.key, required this.c});
  final GoldController c;

  static const double w = 1160, h = 656;
  // left %, width % of each reel window (from the design).
  static const _cols = [(11.1, 24.6), (37.8, 24.4), (64.3, 24.7)];

  @override
  Widget build(BuildContext context) {
    final won = c.lastMult > 0 && !c.busy;
    return Semantics(
      label: 'Reels',
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(children: [
          for (var i = 0; i < 3; i++)
            Positioned(
              left: w * _cols[i].$1 / 100,
              width: w * _cols[i].$2 / 100,
              top: h * .25,
              height: h * .573,
              child: ReelColumn(
                symbols: c.grid[i],
                spinning: c.spinning[i],
                won: won,
                busy: c.busy,
                fast: c.fastSpin,
                filler: c.outcomes.fillerSymbol,
                width: w * _cols[i].$2 / 100,
                height: h * .573,
              ),
            ),
          Positioned(
            left: w * .105,
            right: w * .105,
            top: h * .536 - 2,
            height: 4,
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: won ? GC.goldTitle : GC.a(232, 181, 69, .45),
                  boxShadow: won ? [bs(0, 0, 14, GC.a(255, 200, 60, .9), 4)] : const [],
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(child: Img(GoldAssets.reelFrame, w: w, h: h)),
          ),
        ]),
      ),
    );
  }
}

enum _Mode { idle, spinning, settling }

class ReelColumn extends StatefulWidget {
  const ReelColumn({
    super.key,
    required this.symbols,
    required this.spinning,
    required this.won,
    required this.busy,
    required this.fast,
    required this.filler,
    required this.width,
    required this.height,
  });

  final List<Sym> symbols;
  final bool spinning, won, busy, fast;
  final Sym Function() filler;
  final double width, height;

  @override
  State<ReelColumn> createState() => _ReelColumnState();
}

class _ReelColumnState extends State<ReelColumn> with TickerProviderStateMixin {
  static const double _pad = 8; // reel padding: 8px 0

  late final Ticker _ticker = createTicker(_onTick);
  late final AnimationController _settle = AnimationController(vsync: this)
    ..addListener(() => setState(() {}))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) setState(() => _mode = _Mode.idle);
    });

  _Mode _mode = _Mode.idle;
  List<Sym> _loop = const [];
  List<Sym> _strip = const [];
  double _offset = 0;
  Duration _last = Duration.zero;

  double get _cellH => (widget.height - _pad * 2) / 3;

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _startSpin();
  }

  @override
  void didUpdateWidget(ReelColumn old) {
    super.didUpdateWidget(old);
    if (!old.spinning && widget.spinning) {
      _startSpin();
    } else if (old.spinning && !widget.spinning) {
      _startSettle();
    }
  }

  void _startSpin() {
    _settle.stop();
    _loop = [widget.filler(), ...widget.symbols, widget.filler()];
    _offset = 0;
    _last = Duration.zero;
    _mode = _Mode.spinning;
    if (!_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final speed = _cellH / (widget.fast ? .045 : .06);
    _offset += speed * dt;
    while (_offset >= _cellH) {
      _offset -= _cellH;
      _loop.removeLast();
      _loop.insert(0, widget.filler());
    }
    setState(() {});
  }

  void _startSettle() {
    if (_ticker.isActive) _ticker.stop();
    final visible = _loop.length >= 4 ? _loop.sublist(1, 4) : [widget.filler(), widget.filler(), widget.filler()];
    // [overshoot filler, final ×3, what was on screen ×3] — scrolls from index 4 down to 1.
    _strip = [widget.filler(), ...widget.symbols, ...visible];
    _mode = _Mode.settling;
    _settle.duration = Duration(milliseconds: widget.fast ? 170 : 260);
    _settle.forward(from: 0);
  }

  /// Strip position in cells: 4 → 0.82 (overshoot) → 1.
  double _settlePos(double t) {
    if (t < .75) return 4 - 3.18 * Curves.easeOut.transform(t / .75);
    return .82 + .18 * Curves.easeInOut.transform((t - .75) / .25);
  }

  Widget _cell(Sym s, {int? row}) {
    final idle = _mode == _Mode.idle;
    final isWin = idle && widget.won && row == 1;
    final dim = idle && !widget.busy && row != 1 && row != null;
    Widget img = Img(GoldAssets.symbol(s), w: widget.width * .88, h: 104, fit: BoxFit.contain);
    if (row != null) {
      img = AnimatedScale(
        scale: isWin ? 1.08 : 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: DropGlow(color: GC.a(255, 215, 90, .95), blur: 12, opacity: isWin ? 1 : 0, child: img),
      );
    }
    if (dim) img = Opacity(opacity: .7, child: img);
    return SizedBox(width: widget.width, height: _cellH, child: Center(child: img));
  }

  @override
  Widget build(BuildContext context) {
    final List<Sym> strip;
    double top;
    var blur = false;
    switch (_mode) {
      case _Mode.idle:
        strip = widget.symbols;
        top = _pad;
      case _Mode.spinning:
        strip = _loop;
        top = _pad - _cellH + _offset;
        blur = true;
      case _Mode.settling:
        final p = _settlePos(_settle.value);
        strip = _strip;
        top = _pad - p * _cellH;
        blur = p > 1.3;
    }

    Widget reel = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D0906), Color(0xFF3A3027), Color(0xFF0D0906)],
        ),
      ),
      child: ClipRect(
        child: Stack(children: [
          Positioned(
            left: 0,
            right: 0,
            top: top,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < strip.length; i++)
                  _cell(strip[i], row: _mode == _Mode.idle ? i : null),
              ],
            ),
          ),
        ]),
      ),
    );

    if (blur) {
      // CSS `filter: blur(3px)` while spinning.
      reel = ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3), child: reel);
    }
    return Semantics(
      label: _mode == _Mode.idle ? widget.symbols.map((s) => s.name).join(', ') : 'Spinning',
      child: reel,
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _settle.dispose();
    super.dispose();
  }
}
