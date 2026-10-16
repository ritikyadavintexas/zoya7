import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../games/gold/src/style.dart' show bs, circleGradient, ellipseGradient, ts;

export '../games/gold/src/style.dart' show bs, circleGradient, ellipseGradient, ts;

/// Design tokens for the Zoya7 app pages (portrait), taken from the design canvas.
class Z {
  static const ink = Color(0xFF0B0806);
  static const inkDeep = Color(0xFF07050A);
  static const text = Color(0xFFF5E6C4);
  static const cream = Color(0xFFFFF4DC);
  static const gold = Color(0xFFF2C869);
  static const goldHi = Color(0xFFFFE7A0);
  static const goldBright = Color(0xFFFFD45A);
  static const goldEdge = Color(0xFFE2B04F);
  static const label = Color(0xFFE8C06A);
  static const border = Color(0xFFC99A3E);
  static const ghostBorder = Color(0xFFD9A94A);
  static const chip = Color(0xFF6E5428);
  static const chipDark = Color(0xFF4A3A1E);
  static const field = Color(0xFF120C06);
  static const card = Color(0xFF110B06);
  static const cardBorder = Color(0xFF3A2C16);
  static const divider = Color(0xFF2A1F10);
  static const track = Color(0xFF2A1D0E);
  static const iconTile = Color(0xFF22180C);
  static const muted = Color(0xFFB9AD97);
  static const muted2 = Color(0xFFA99E8C);
  static const faint = Color(0xFF8F8576);
  static const body = Color(0xFFD9C9A8);
  static const soft = Color(0xFFE9DCC0);
  static const tabOff = Color(0xFFC9BFAE);
  static const footer = Color(0xFFB3AAA0);
  static const green = Color(0xFF3FD17A);
  static const greenHi = Color(0xFF8FF0B4);
  static const teal = Color(0xFF6FE0C0);
  static const red = Color(0xFFE3242B);
  static const coral = Color(0xFFFF8A7A);
  static const ctaText = Color(0xFFFBD88A);
  static const ctaShadow = Color(0xFF5A0408);
  static const brown = Color(0xFF3A2205);
  static const coinInk = Color(0xFF4A2E05);
  static const tealInk = Color(0xFF062E24);
  static const rimBright = Color(0xFFF3C662);
  static const line = Color(0x4DC99A3E); // rgba(201,154,62,.3)
  static const line35 = Color(0x59C99A3E);

  static const red3 = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE0303B), Color(0xFFB0121C), Color(0xFF7A050C)],
    stops: [0, .45, 1],
  );
  static const goldTab = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFE7A0), Color(0xFFE0A52E), Color(0xFFA8691A)],
    stops: [0, .6, 1],
  );
  static const goldBadge = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFE7A0), Color(0xFFE0A52E)],
  );
  static const goldFrame = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFE7A0), Color(0xFFC99A3E), Color(0xFF8A5F1C)],
    stops: [0, .5, 1],
  );
  static const green3 = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF5FD35A), Color(0xFF1F9A24), Color(0xFF0B5A12)],
    stops: [0, .55, 1],
  );
  static const green2 = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF5FD35A), Color(0xFF1F9A24)],
  );
  static const progress = LinearGradient(colors: [Color(0xFFA8691A), Color(0xFFFFD45A)]);
  static const footerBar = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF140D07), Color(0xFF0A0704)],
  );

  static RadialGradient coinGold() => circleGradient(
        cx: .4,
        cy: .3,
        colors: const [Color(0xFFFFE08A), Color(0xFFE0A52E), Color(0xFF9A6512)],
        stops: const [0, .6, 1],
      );
  static RadialGradient coinBig() => circleGradient(
        cx: .4,
        cy: .3,
        colors: const [Color(0xFFFFF0B3), Color(0xFFF2C14E), Color(0xFFA8691A)],
        stops: const [0, .45, 1],
      );
  static RadialGradient coinTeal() => circleGradient(
        cx: .4,
        cy: .3,
        colors: const [Color(0xFF6FF0CF), Color(0xFF14B38A), Color(0xFF08664E)],
        stops: const [0, .6, 1],
      );
  static RadialGradient darkKnob() =>
      circleGradient(cx: .5, cy: .3, colors: const [Color(0xFF3A2A14), Color(0xFF120C06)]);
  static RadialGradient darkWell() =>
      circleGradient(cx: .5, cy: .3, colors: const [Color(0xFF2E2112), Color(0xFF0E0905)]);

  /// `radial-gradient(ellipse 120% RY% at 50% 0%, TOP 0%, #0b0806 70%)` — the page glow.
  static RadialGradient pageGlow({double ry = .30, Color top = const Color(0xFF3A2209), double rx = 1.2}) =>
      ellipseGradient(cx: .5, cy: 0, rx: rx, ry: ry, colors: [top, ink], stops: const [0, .7]);

  static List<BoxShadow> ctaGlow([double blur = 18, double a = .4]) =>
      [bs(0, 0, blur, Color.fromRGBO(255, 170, 60, a))];
}

/// Outfit — the app pages' typeface. [ls] is letter-spacing in em.
TextStyle outfit(
  double size, {
  FontWeight w = FontWeight.w500,
  Color c = Z.text,
  double ls = 0,
  double? h,
  List<Shadow>? sh,
  TextDecoration? deco,
  List<FontFeature>? features,
}) =>
    GoogleFonts.outfit(
      fontSize: size,
      fontWeight: w,
      color: c,
      letterSpacing: size * ls,
      height: h,
      shadows: sh,
      decoration: deco,
      decorationColor: c,
      fontFeatures: features,
    );

/// Playfair Display — the tagline and VIP tier name.
TextStyle playfair(double size, {FontWeight w = FontWeight.w700, Color c = Z.text, double? h}) =>
    GoogleFonts.playfairDisplay(fontSize: size, fontWeight: w, color: c, height: h);

const tabular = [FontFeature.tabularFigures()];

final ctaTextShadow = [ts(0, 2, 0, Z.ctaShadow)];

String fmtInt(num v) {
  final s = v.round().abs().toString();
  final b = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

String fmtSc(double v) {
  final whole = v.truncate();
  final cents = ((v - whole) * 100).round().toString().padLeft(2, '0');
  return '${fmtInt(whole)}.$cents';
}

String monthName(int m) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
