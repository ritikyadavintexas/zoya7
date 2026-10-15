import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../icons.dart';
import '../style.dart';

/// Tappable region with a subtle press response, cursor and semantics.
class Tap extends StatefulWidget {
  const Tap({
    super.key,
    required this.child,
    this.onTap,
    this.label,
    this.pressScale = .96,
    this.selected,
    this.toggled,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? label;
  final double pressScale;
  final bool? selected;
  final bool? toggled;

  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _down = false;

  void _setDown(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      label: widget.label,
      selected: widget.selected,
      toggled: widget.toggled,
      enabled: enabled,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => _setDown(true) : null,
          onTapUp: enabled ? (_) => _setDown(false) : null,
          onTapCancel: () => _setDown(false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _down ? widget.pressScale : 1,
            duration: const Duration(milliseconds: 90),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Fixed-size asset image (CSS `width/height` → stretched like the browser does).
class Img extends StatelessWidget {
  const Img(this.asset, {super.key, required this.w, required this.h, this.fit = BoxFit.fill});
  final String asset;
  final double w, h;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Image.asset(
        asset,
        width: w,
        height: h,
        fit: fit,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      );
}

/// CSS `filter: drop-shadow(0 0 Rpx color)` — a blurred, tinted silhouette behind the child.
class DropGlow extends StatelessWidget {
  const DropGlow({super.key, required this.child, required this.color, required this.blur, this.opacity = 1});
  final Widget child;
  final Color color;
  final double blur;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return child;
    final sigma = cssSigma(blur);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: opacity > 1 ? 1.0 : opacity,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
            child: ColorFiltered(colorFilter: ColorFilter.mode(color, BlendMode.srcIn), child: child),
          ),
        ),
        child,
      ],
    );
  }
}

/// The gold-rimmed dark panel used across the design.
class GoldRim extends StatelessWidget {
  const GoldRim({
    super.key,
    required this.child,
    required this.radius,
    this.rim = 4,
    this.width,
    this.height,
    this.fill = GC.panelFill,
    this.padding,
    this.shadows = const [],
  });

  final Widget child;
  final double radius;
  final double rim;
  final double? width, height;
  final Gradient fill;
  final EdgeInsets? padding;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(rim),
        decoration: BoxDecoration(
          gradient: GC.goldRim,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: shadows,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: fill,
            borderRadius: BorderRadius.circular(radius - rim),
          ),
          child: child,
        ),
      );
}

/// Round dark close button (72 or 64 px in the design).
class CloseButtonRound extends StatelessWidget {
  const CloseButtonRound({super.key, required this.onTap, this.size = 72, this.icon = 30, this.label = 'Close'});
  final VoidCallback onTap;
  final double size, icon;
  final String label;

  @override
  Widget build(BuildContext context) => Tap(
        onTap: onTap,
        label: label,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: GC.btnDark,
            border: Border.all(color: GC.btnBorder, width: 2),
          ),
          alignment: Alignment.center,
          child: GoldIcons.close(icon),
        ),
      );
}

/// Pill button with the dark fill + gold hairline used in modals.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.height,
    required this.fontSize,
    this.width,
    this.red = false,
  });

  final String label;
  final VoidCallback? onTap;
  final double height, fontSize;
  final double? width;
  final bool red;

  @override
  Widget build(BuildContext context) => Tap(
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: red ? GC.brightBorder : GC.btnBorder, width: 2),
            color: red ? null : GC.btnDark,
            gradient: red ? GC.redButton : null,
          ),
          child: Text(
            label,
            style: lilita(fontSize, color: red ? const Color(0xFFFBD88A) : GC.goldTitle, letterSpacingEm: .04),
          ),
        ),
      );
}

/// Fade + gentle scale for modals.
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.from = .92});
  final Widget child;
  final double from;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (_, t, c) => Opacity(
          opacity: t,
          child: Transform.scale(scale: from + (1 - from) * t, child: c),
        ),
        child: child,
      );
}

/// Full-screen dimmed layer that centres a modal card.
class ModalScrim extends StatelessWidget {
  const ModalScrim({super.key, required this.child, required this.opacity, this.label});
  final Widget child;
  final double opacity;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        label: label,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 180),
          builder: (_, t, c) => ColoredBox(color: GC.a(10, 5, 2, opacity * t), child: c),
          child: Center(child: PopIn(child: child)),
        ),
      );
}
