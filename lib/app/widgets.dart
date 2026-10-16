import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'icons.dart';
import 'nav.dart';
import 'state.dart';
import 'theme.dart';

/// A tappable area with press feedback and button semantics.
class Press extends StatefulWidget {
  const Press({super.key, required this.child, this.onTap, this.label, this.selected});
  final Widget child;
  final VoidCallback? onTap;
  final String? label;
  final bool? selected;

  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.label,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapUp: enabled ? (_) => setState(() => _down = false) : null,
          onTapCancel: enabled ? () => setState(() => _down = false) : null,
          onTap: widget.onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  widget.onTap!();
                },
          child: AnimatedScale(
            scale: _down ? .96 : 1,
            duration: const Duration(milliseconds: 90),
            child: AnimatedOpacity(
              opacity: enabled ? 1 : .9,
              duration: const Duration(milliseconds: 90),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A landscape app page: dark background with the top glow, safe-area aware,
/// and capped in width so it also looks right on tablets and desktop.
class ZPage extends StatelessWidget {
  const ZPage({super.key, required this.child, this.gradient, this.color = Z.ink});
  final Widget child;
  final Gradient? gradient;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient ?? Z.pageGlow()),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              // Text fields need a Material ancestor.
              child: Material(
                type: MaterialType.transparency,
                child: DefaultTextStyle(style: outfit(15), child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Landscape page body: a side pane (summary, filters, controls) next to the
/// main pane. The side pane takes [sideFraction] of the width (kept between
/// [minSide] and [maxSide]); if that would leave the main pane narrower than
/// [minMain], the page shows [narrow] instead (one column), or keeps the
/// split at [minSide] when no single-column version is given.
class Panes extends StatelessWidget {
  const Panes({
    super.key,
    required this.side,
    required this.main,
    this.narrow,
    this.sideFraction = .38,
    this.minSide = 250,
    this.maxSide = 380,
    this.minMain = 300,
    this.divider = false,
  });
  final Widget side;
  final Widget main;
  final Widget? narrow;
  final double sideFraction;
  final double minSide;
  final double maxSide;
  final double minMain;
  final bool divider;

  /// Width of the side pane in [width], or null when both panes don't fit.
  static double? sideWidth(double width, double fraction, double minSide, double maxSide, double minMain) {
    final w = (width * fraction).clamp(minSide, maxSide);
    return width - w >= minMain ? w : null;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final w = sideWidth(box.maxWidth, sideFraction, minSide, maxSide, minMain);
        if (w == null && narrow != null) return narrow!;
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: w ?? minSide, child: side),
          if (divider) Container(width: 1, color: Z.line),
          Expanded(child: main),
        ]);
      });
}

/// [Panes] for pages whose panes are plain scrolling lists: two lists side by
/// side when both fit, otherwise one list with the side items first.
class PaneLists extends StatelessWidget {
  const PaneLists({
    super.key,
    required this.side,
    required this.main,
    this.sideFraction = .38,
    this.minSide = 250,
    this.maxSide = 380,
    this.minMain = 300,
    this.top = 12,
    this.divider = false,
  });
  final List<Widget> side;
  final List<Widget> main;
  final double sideFraction;
  final double minSide;
  final double maxSide;
  final double minMain;
  final double top;
  final bool divider;

  @override
  Widget build(BuildContext context) => Panes(
        sideFraction: sideFraction,
        minSide: minSide,
        maxSide: maxSide,
        minMain: minMain,
        divider: divider,
        side: ListView(padding: EdgeInsets.fromLTRB(14, top, divider ? 14 : 6, 16), children: side),
        main: ListView(padding: EdgeInsets.fromLTRB(divider ? 18 : 8, top, 14, 16), children: main),
        narrow: ListView(
          padding: EdgeInsets.fromLTRB(14, top, 14, 16),
          children: [...side, const SizedBox(height: 16), ...main],
        ),
      );
}

/// Number of columns of at most [maxTile] wide (plus [gap]) that fill [width].
int columnsFor(double width, double maxTile, {double gap = 10, int min = 1}) =>
    ((width + gap) / (maxTile + gap)).ceil().clamp(min, 99);

/// 40px round gold-rimmed icon button used in page headers.
class RoundBtn extends StatelessWidget {
  const RoundBtn({super.key, required this.child, this.onTap, required this.label, this.size = 40});
  final Widget child;
  final VoidCallback? onTap;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        label: label,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Z.border, width: 1.5),
            gradient: Z.darkKnob(),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      );
}

class BackBtn extends StatelessWidget {
  const BackBtn({super.key, this.onTap, this.label = 'Back'});
  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) => RoundBtn(
        label: label,
        onTap: onTap ?? () => Nav.back(context),
        child: const StrokeIco(P.back, size: 18),
      );
}

/// 54px page header: back button, gold title, optional right action.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.title,
    this.onBack,
    this.backLabel = 'Back',
    this.right,
    this.border = true,
    this.titleSize = 21,
  });
  final String title;
  final VoidCallback? onBack;
  final String backLabel;
  final Widget? right;
  final bool border;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    // 44–54 tall: shorter on short phones so the page below gets the room.
    return Container(
        height: (MediaQuery.sizeOf(context).height * .14).clamp(44.0, 54.0),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(border: border ? const Border(bottom: BorderSide(color: Z.line)) : null),
        // Keeps the title centred on the bar while it fits between the ends,
        // and slides it over (then ellipsizes) when it doesn't.
        child: NavigationToolbar(
          middleSpacing: 12,
          leading: BackBtn(onTap: onBack, label: backLabel),
          middle: Semantics(
            header: true,
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: outfit(titleSize, w: FontWeight.w800, ls: .1, c: Z.gold)),
          ),
          trailing: right,
        ),
      );
  }
}

/// The red, gold-rimmed primary button.
class CtaButton extends StatelessWidget {
  const CtaButton(this.label,
      {super.key, this.onTap, this.height = 58, this.fontSize = 18, this.icon, this.trailing, this.ls = .04});
  final String label;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;
  final Widget? icon;
  final Widget? trailing;
  final double ls;

  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height),
            border: Border.all(color: Z.rimBright, width: 2),
            gradient: Z.red3,
            boxShadow: Z.ctaGlow(),
          ),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[icon!, const SizedBox(width: 10)],
            Flexible(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: outfit(fontSize, w: FontWeight.w800, ls: ls, c: Z.ctaText, sh: ctaTextShadow)),
            ),
            if (trailing != null) ...[const SizedBox(width: 18), trailing!],
          ]),
        ),
      );
}

/// The green confirmation button (after claiming, notify on).
class GreenButton extends StatelessWidget {
  const GreenButton(this.label, {super.key, this.onTap, this.height = 58, this.fontSize = 19, this.icon});
  final String label;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;
  final Widget? icon;

  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height),
            border: Border.all(color: Z.rimBright, width: 2),
            gradient: Z.green3,
          ),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[icon!, const SizedBox(width: 10)],
            Text(label, style: outfit(fontSize, w: FontWeight.w800, ls: .04, c: Z.cream)),
          ]),
        ),
      );
}

/// Outlined secondary button.
class GhostButton extends StatelessWidget {
  const GhostButton(this.label,
      {super.key, this.onTap, this.height = 52, this.fontSize = 16, this.color = Z.text, this.borderColor = Z.ghostBorder});
  final String label;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height),
            border: Border.all(color: borderColor, width: 1.5),
            color: const Color(0x990A0604),
          ),
          alignment: Alignment.center,
          child: Text(label, style: outfit(fontSize, w: FontWeight.w700, ls: .04, c: color)),
        ),
      );
}

/// Underlined / plain gold text link.
class LinkText extends StatelessWidget {
  const LinkText(this.text, {super.key, this.onTap, this.size = 15, this.w = FontWeight.w500, this.underline = false});
  final String text;
  final VoidCallback? onTap;
  final double size;
  final FontWeight w;
  final bool underline;

  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(text,
              style: outfit(size, w: w, c: Z.gold, deco: underline ? TextDecoration.underline : null)),
        ),
      );
}

/// Gold pill segmented tabs (LOG IN / SIGN UP, BUY / HISTORY …).
class SegTabs extends StatelessWidget {
  const SegTabs({super.key, required this.labels, required this.index, required this.onChanged, this.height = 40, this.fontSize = 13, this.ls = .06});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final double height;
  final double fontSize;
  final double ls;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Z.border, width: 1.5),
          color: const Color(0xFF0D0906),
        ),
        child: Row(children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Press(
                onTap: () => onChanged(i),
                selected: i == index,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: height,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: i == index ? Z.goldTab : null,
                  ),
                  child: Text(labels[i],
                      maxLines: 1,
                      style: outfit(fontSize,
                          w: FontWeight.w800, ls: ls, c: i == index ? Z.brown : Z.tabOff)),
                ),
              ),
            ),
          ],
        ]),
      );
}

InputDecoration fieldDeco({String? hint, Widget? suffix, double radius = 14, double left = 16, double? right}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: outfit(16, c: Z.faint),
      isDense: true,
      filled: true,
      fillColor: Z.field,
      contentPadding: EdgeInsets.fromLTRB(left, 12, right ?? 16, 12),
      suffixIcon: suffix,
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius), borderSide: const BorderSide(color: Z.chip, width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius), borderSide: const BorderSide(color: Z.goldHi, width: 2)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius)),
    );

/// Labeled text field: "EMAIL" above a dark rounded input.
class ZField extends StatelessWidget {
  const ZField({
    super.key,
    required this.label,
    this.hint,
    this.obscure = false,
    this.suffix,
    this.controller,
    this.initial,
    this.keyboard,
    this.helper,
    this.badge,
  });
  final String label;
  final String? hint;
  final bool obscure;
  final Widget? suffix;
  final TextEditingController? controller;
  final String? initial;
  final TextInputType? keyboard;
  final String? helper;
  final Widget? badge;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label, style: outfit(13, w: FontWeight.w600, c: Z.label)),
        const SizedBox(height: 6),
        Stack(alignment: Alignment.centerRight, children: [
          TextFormField(
            controller: controller,
            initialValue: controller == null ? initial : null,
            obscureText: obscure,
            keyboardType: keyboard,
            style: outfit(16, c: Z.cream),
            cursorColor: Z.goldHi,
            decoration: fieldDeco(hint: hint, suffix: suffix, right: badge != null ? 96 : null),
          ),
          if (badge != null) Padding(padding: const EdgeInsets.only(right: 10), child: badge),
        ]),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(helper!, style: outfit(12, c: Z.muted2)),
        ],
      ]);
}

/// 2px gold gradient frame around a card.
class GoldFrame extends StatelessWidget {
  const GoldFrame({super.key, required this.child, this.radius = 18, this.inner, this.padding, this.shadows, this.width = 2});
  final Widget child;
  final double radius;
  final Gradient? inner;
  final EdgeInsets? padding;
  final List<BoxShadow>? shadows;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(width),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: Z.goldFrame,
          boxShadow: shadows,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius - width),
            gradient: inner,
            color: inner == null ? const Color(0xFF0D0906) : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      );
}

/// Round GC / SC coin badge.
class Coin extends StatelessWidget {
  const Coin({super.key, this.label = 'GC', this.size = 30, this.fontSize, this.teal = false, this.big = false, this.glow});
  final String label;
  final double size;
  final double? fontSize;
  final bool teal;
  final bool big;
  final List<BoxShadow>? glow;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: teal ? Z.coinTeal() : (big ? Z.coinBig() : Z.coinGold()),
          boxShadow: glow,
        ),
        child: Text(label,
            style: outfit(fontSize ?? size * .37, w: FontWeight.w800, c: teal ? Z.tealInk : Z.coinInk, h: 1)),
      );
}

/// Dark rounded card with a thin brown border.
class ZCard extends StatelessWidget {
  const ZCard({super.key, required this.child, this.padding, this.radius = 16, this.color = Z.card, this.border = Z.cardBorder});
  final Widget child;
  final EdgeInsets? padding;
  final double radius;
  final Color color;
  final Color border;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

/// Gold progress bar (VIP points, loading).
class GoldBar extends StatelessWidget {
  const GoldBar({super.key, required this.value, this.height = 12, this.border});
  final double value;
  final double height;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: border == null ? Z.track : const Color(0xFF22180C),
          borderRadius: BorderRadius.circular(height / 2),
          border: border == null ? null : Border.all(color: border!),
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0, 1),
          child: Container(
            decoration: BoxDecoration(
              gradient: Z.progress,
              borderRadius: BorderRadius.circular(height / 2),
              boxShadow: [bs(0, 0, 10, const Color(0x99FFD45A))],
            ),
          ),
        ),
      );
}

/// "18+  |  Play Responsibly.  |  …" footer.
class ResponsibleFooter extends StatelessWidget {
  const ResponsibleFooter({super.key, required this.parts, this.color = Z.footer, this.badge = 28});
  final List<String> parts;
  final Color color;
  final double badge;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 6,
        children: [
          Container(
            width: badge,
            height: badge,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 1.5)),
            child: Text('18+', style: outfit(badge * .39, w: FontWeight.w600, c: color)),
          ),
          for (final p in parts) ...[
            Container(width: 1, height: 16, color: const Color(0xFF5A524A)),
            Text(p, style: outfit(12, c: color)),
          ],
        ],
      );
}

/// Pill toast near the bottom of the screen.
void showToast(BuildContext context, String text,
    {Color border = Z.border, Color color = Z.text, double bottom = 40, Duration duration = const Duration(milliseconds: 1800)}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _toast?.remove();
  _toastTimer?.cancel();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: 16,
      right: 16,
      bottom: bottom + MediaQuery.of(context).padding.bottom,
      child: IgnorePointer(
        child: Center(
          child: Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xF20E0905),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: border),
                boxShadow: [bs(0, 8, 22, const Color(0x99000000))],
              ),
              child: Text(text,
                  textAlign: TextAlign.center,
                  style: outfit(14, w: FontWeight.w600, c: color).copyWith(decoration: TextDecoration.none)),
            ),
          ),
        ),
      ),
    ),
  );
  _toast = entry;
  overlay.insert(entry);
  _toastTimer = Timer(duration, () {
    if (_toast == entry) {
      entry.remove();
      _toast = null;
    }
  });
}

OverlayEntry? _toast;
Timer? _toastTimer;

/// Header balance chip: "[GC] 125,000".
class GcChip extends StatelessWidget {
  const GcChip({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Press(
      onTap: onTap,
      label: 'Gold Coins balance',
      child: Container(
        height: 34,
        padding: const EdgeInsets.fromLTRB(4, 0, 10, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Z.border, width: 1.5),
          color: Z.field,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Coin(size: 24, fontSize: 9),
          const SizedBox(width: 6),
          Text(fmtInt(s.gc), style: outfit(13, w: FontWeight.w700, c: Z.cream)),
        ]),
      ),
    );
  }
}

/// Section title like "POPULAR GAMES".
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.size = 17, this.color = Z.text, this.trailing});
  final String text;
  final double size;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(text, style: outfit(size, w: FontWeight.w800, ls: .06, c: color)),
          ),
        ),
        if (trailing != null) trailing!,
      ]);
}

/// A square-ish asset image with rounded corners.
class RoundImage extends StatelessWidget {
  const RoundImage(this.asset, {super.key, this.height, this.radius = 12, this.borderColor = Z.border, this.fit = BoxFit.cover, this.alignment = Alignment.center, this.semantic});
  final String asset;
  final double? height;
  final double radius;
  final Color borderColor;
  final BoxFit fit;
  final Alignment alignment;
  final String? semantic;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(asset, fit: fit, alignment: alignment, width: double.infinity, semanticLabel: semantic),
      );
}
