import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'math.dart';

/// Design canvas. Everything is laid out in these units and scaled to the device.
const double kDesignW = 1920;
const double kDesignH = 1080;

class GC {
  GC._();
  static const bgDeep = Color(0xFF1A0F04);
  static const bgMid = Color(0xFF4A2E0B);
  static const bgHot = Color(0xFF8A5F1C);
  static const text = Color(0xFFFFF4D6);
  static const goldText = Color(0xFFFFE7A0);
  static const goldTitle = Color(0xFFFFD45A);
  static const goldLabel = Color(0xFFE8C06A);
  static const note = Color(0xFFD9C08A);
  static const muted = Color(0xFFB9AD97);
  static const goldShadow = Color(0xFF6A3D00);
  static const panelTop = Color(0xFF1C120A);
  static const panelBottom = Color(0xFF0C0805);
  static const btnDark = Color(0xFF120C06);
  static const btnBorder = Color(0xFFC99A3E);
  static const chipBorder = Color(0xFF6E5428);
  static const brightBorder = Color(0xFFF3C662);
  static const green = Color(0xFF3FD17A);
  static const cream = Color(0xFFFFF4DC);

  static const jackpotColors = {
    JackpotTier.mega: Color(0xFFFF6B5B),
    JackpotTier.major: Color(0xFFC99BFF),
    JackpotTier.minor: Color(0xFF7AB8FF),
    JackpotTier.mini: Color(0xFF74E07C),
  };
  static const jackpotShadows = {
    JackpotTier.mega: Color(0xFF3A0A05),
    JackpotTier.major: Color(0xFF2A0A3A),
    JackpotTier.minor: Color(0xFF0A1F3A),
    JackpotTier.mini: Color(0xFF0A3A10),
  };

  /// linear-gradient(180deg, #fff0b3 0%, #e8b545 35%, #a8691a 70%, #ffd56b 100%)
  static const goldRim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF0B3), Color(0xFFE8B545), Color(0xFFA8691A), Color(0xFFFFD56B)],
    stops: [0, .35, .70, 1],
  );

  static const panelFill = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [panelTop, panelBottom],
  );

  static const redButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE0303B), Color(0xFFB0121C), Color(0xFF7A050C)],
    stops: [0, .45, 1],
  );

  static const greenButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF5FD35A), Color(0xFF1F9A24), Color(0xFF0B5A12)],
    stops: [0, .55, 1],
  );

  static Color a(int r, int g, int b, double o) => Color.fromRGBO(r, g, b, o);
}

// ── CSS → Flutter conversions ────────────────────────────────────────────────

/// CSS blur radius (box-shadow / text-shadow / drop-shadow) → Flutter blurRadius.
/// CSS uses sigma = r / 2; Flutter uses sigma = r * 0.57735 + 0.5.
double cssBlur(double px) => px <= 1 ? 0 : (px / 2 - 0.5) / 0.57735;

/// CSS blur radius → Gaussian sigma for ImageFilter.blur.
double cssSigma(double px) => px / 2;

BoxShadow bs(double x, double y, double blur, Color c, [double spread = 0]) =>
    BoxShadow(offset: Offset(x, y), blurRadius: cssBlur(blur), spreadRadius: spread, color: c);

Shadow ts(double x, double y, double blur, Color c) =>
    Shadow(offset: Offset(x, y), blurRadius: cssBlur(blur), color: c);

/// CSS `radial-gradient(ellipse RX% RY% at CX% CY%, …)`.
RadialGradient ellipseGradient({
  required double cx,
  required double cy,
  required double rx,
  required double ry,
  required List<Color> colors,
  List<double>? stops,
}) {
  final center = Alignment(cx * 2 - 1, cy * 2 - 1);
  return RadialGradient(
    center: center,
    radius: .5,
    colors: colors,
    stops: stops,
    transform: _EllipseTransform(center, rx, ry),
  );
}

/// CSS `radial-gradient(ellipse at CX% CY%, …)` (farthest-corner).
RadialGradient ellipseFarthestCorner({
  required double cx,
  required double cy,
  required List<Color> colors,
  List<double>? stops,
}) =>
    ellipseGradient(
      cx: cx,
      cy: cy,
      rx: math.max(cx, 1 - cx) * math.sqrt2,
      ry: math.max(cy, 1 - cy) * math.sqrt2,
      colors: colors,
      stops: stops,
    );

/// CSS `radial-gradient(circle at CX% CY%, …)` on a square box (farthest-corner).
RadialGradient circleGradient({
  required double cx,
  required double cy,
  required List<Color> colors,
  List<double>? stops,
}) {
  final dx = math.max(cx, 1 - cx), dy = math.max(cy, 1 - cy);
  return RadialGradient(
    center: Alignment(cx * 2 - 1, cy * 2 - 1),
    radius: math.sqrt(dx * dx + dy * dy),
    colors: colors,
    stops: stops,
  );
}

class _EllipseTransform extends GradientTransform {
  const _EllipseTransform(this.center, this.rx, this.ry);
  final Alignment center;
  final double rx, ry;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final c = center.withinRect(bounds);
    final base = bounds.shortestSide * .5;
    final sx = rx * bounds.width / base;
    final sy = ry * bounds.height / base;
    return Matrix4.translationValues(c.dx, c.dy, 0)
        .multiplied(Matrix4.diagonal3Values(sx, sy, 1))
        .multiplied(Matrix4.translationValues(-c.dx, -c.dy, 0));
  }
}

/// CSS `saturate(s) brightness(b)` as a color matrix.
List<double> saturateBrightness(double s, double b) => [
      (.213 + .787 * s) * b, (.715 - .715 * s) * b, (.072 - .072 * s) * b, 0, 0,
      (.213 - .213 * s) * b, (.715 + .285 * s) * b, (.072 - .072 * s) * b, 0, 0,
      (.213 - .213 * s) * b, (.715 - .715 * s) * b, (.072 + .928 * s) * b, 0, 0,
      0, 0, 0, 1, 0,
    ];

List<double> lerpMatrix(List<double> a, List<double> b, double t) =>
    List.generate(20, (i) => a[i] + (b[i] - a[i]) * t);

// ── Typography ───────────────────────────────────────────────────────────────

/// Display face: Lilita One.
TextStyle lilita(
  double size, {
  Color color = GC.goldText,
  double letterSpacingEm = 0,
  List<Shadow>? shadows,
  double? height,
}) =>
    GoogleFonts.lilitaOne(
      fontSize: size,
      color: color,
      letterSpacing: size * letterSpacingEm,
      shadows: shadows,
      height: height,
    );

/// UI face: Rubik. The design only loads 500/700, so unweighted text renders at 500.
TextStyle rubik(
  double size, {
  FontWeight weight = FontWeight.w500,
  Color color = GC.text,
  double? height,
}) =>
    GoogleFonts.rubik(fontSize: size, fontWeight: weight, color: color, height: height);

/// `text-shadow: 0 2px 0 #6a3d00, 0 0 10px rgba(255,200,80,.5)`
List<Shadow> goldGlow([double drop = 2, double glow = 10, double alpha = .5]) => [
      ts(0, drop, 0, GC.goldShadow),
      ts(0, 0, glow, GC.a(255, 200, 80, alpha)),
    ];

String fmtAmount(double v, Currency c) {
  if (c == Currency.sc) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    return '${_commas(parts[0])}.${parts[1]}';
  }
  return _commas(v.round().toString());
}

String _commas(String digits) {
  final neg = digits.startsWith('-');
  final d = neg ? digits.substring(1) : digits;
  final b = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i > 0 && (d.length - i) % 3 == 0) b.write(',');
    b.write(d[i]);
  }
  return neg ? '-$b' : b.toString();
}

String curLabel(Currency c) => c == Currency.sc ? 'SC' : 'GC';
