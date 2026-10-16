import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Keeps the game in landscape. Android and iOS builds lock the screen to
/// landscape; a browser can't, so while the window is taller than it is wide
/// (a phone held upright) the game waits behind a swirl, as if starting, and
/// carries on, as it was, once the phone is sideways — in plain landscape,
/// with the status bar on top.
class ForceLandscape extends StatelessWidget {
  const ForceLandscape({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final upright = mq.size.width < mq.size.height;
    final size = upright ? mq.size.flipped : mq.size;
    return Stack(children: [
      // The same tree either way, so nothing is lost while the phone is
      // upright: kept, paused and laid out at a landscape size.
      Offstage(
        offstage: upright,
        child: OverflowBox(
          minWidth: size.width,
          maxWidth: size.width,
          minHeight: size.height,
          maxHeight: size.height,
          alignment: Alignment.topLeft,
          child: MediaQuery(
            data: upright ? mq.copyWith(size: size) : mq,
            child: TickerMode(enabled: !upright, child: child),
          ),
        ),
      ),
      if (upright) const Positioned.fill(child: TurnPhoneCard()),
    ]);
  }
}

/// While the phone is upright: a gold swirl, as if the game is starting, so
/// the player turns the phone sideways (no words, no symbols).
class TurnPhoneCard extends StatefulWidget {
  const TurnPhoneCard({super.key});

  @override
  State<TurnPhoneCard> createState() => _TurnPhoneCardState();
}

class _TurnPhoneCardState extends State<TurnPhoneCard> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Turn your phone sideways',
        child: ColoredBox(
          color: Z.ink,
          child: Center(
            child: SizedBox.square(
              dimension: 160,
              child: CustomPaint(painter: _SwirlPainter(_spin)),
            ),
          ),
        ),
      );
}

class _SwirlPainter extends CustomPainter {
  _SwirlPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: [Z.gold.withValues(alpha: .18), Z.gold.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Three gold arcs swirling at different speeds (the inner ones the other way).
    for (final (i, (radius, width, speed)) in const [(.86, 7.0, 1.0), (.62, 5.0, -1.5), (.38, 4.0, 2.0)].indexed) {
      final rr = r * radius;
      final rect = Rect.fromCircle(center: c, radius: rr);
      final start = t.value * 2 * math.pi * speed + i * 1.3;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(start);
      canvas.translate(-c.dx, -c.dy);
      canvas.drawArc(
        rect,
        0,
        math.pi * 1.4,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            colors: [Z.gold.withValues(alpha: 0), Z.gold, Z.goldHi],
            stops: const [0, .6, .7],
          ).createShader(rect),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SwirlPainter old) => false;
}
