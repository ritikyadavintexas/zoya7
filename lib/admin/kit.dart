import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../backoffice/casino.dart';
import '../backoffice/storage.dart';
import '../backoffice/sync.dart';

/// The admin panel's look: Cash App — white, black type, one bright green.
class K {
  static const green = Color(0xFF00D632);
  static const greenInk = Color(0xFF00A827);
  static const greenSoft = Color(0xFFE3FAE8);
  static const ink = Color(0xFF000000);
  static const text = Color(0xFF111111);
  static const sub = Color(0xFF6E6E73);
  static const faint = Color(0xFFA1A1A6);
  static const line = Color(0xFFE9E9EB);
  static const bg = Color(0xFFF4F4F5);
  static const card = Color(0xFFFFFFFF);
  static const field = Color(0xFFF2F2F3);
  static const red = Color(0xFFE5342B);
  static const redSoft = Color(0xFFFDECEA);
  static const amber = Color(0xFFC77C00);
  static const amberSoft = Color(0xFFFFF3D6);
  static const blue = Color(0xFF0A7CFF);
  static const blueSoft = Color(0xFFE5F1FF);

  /// Wide enough for the desktop panel (sidebar, tables, side panes).
  static bool desktop(BuildContext context) => MediaQuery.sizeOf(context).width >= 900;
}

/// Rubik, the closest open face to Cash App's type (weights 500–800).
TextStyle kt(double size, {FontWeight w = FontWeight.w500, Color c = K.text, double? h, double ls = 0, bool num = false}) =>
    GoogleFonts.rubik(
      fontSize: size,
      fontWeight: w,
      color: c,
      height: h,
      letterSpacing: ls,
      fontFeatures: num ? const [FontFeature.tabularFigures()] : null,
    );

// ── Numbers ──────────────────────────────────────────────────────────────────
String _group(String digits) {
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
    b.write(digits[i]);
  }
  return b.toString();
}

/// 1234.5 → "1,234.50"; [decimals] 0 → "1,235".
String grouped(double v, [int decimals = 2]) {
  final s = v.abs().toStringAsFixed(decimals);
  final dot = s.indexOf('.');
  final whole = _group(dot < 0 ? s : s.substring(0, dot));
  return '${v < -1e-9 ? '−' : ''}$whole${dot < 0 ? '' : s.substring(dot)}';
}

String scAmt(double v) => '${grouped(v)} SC';
String gcAmt(double v) => '${grouped(v, 0)} GC';

/// 1.2K, 3.45M.
String compact(double v) {
  final a = v.abs();
  final s = a >= 1e9
      ? '${(a / 1e9).toStringAsFixed(2)}B'
      : a >= 1e6
          ? '${(a / 1e6).toStringAsFixed(a >= 1e8 ? 0 : 2)}M'
          : a >= 1e4
              ? '${(a / 1e3).toStringAsFixed(a >= 1e5 ? 0 : 1)}K'
              : grouped(a, a == a.roundToDouble() ? 0 : 2);
  return '${v < 0 ? '−' : ''}$s';
}

String pct(double v, [int decimals = 2]) => '${(v * 100).toStringAsFixed(decimals)}%';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

String shortDate(DateTime t) => '${_months[t.month - 1]} ${t.day}';

/// "Today 9:41 PM", "Yesterday 8:02 AM", "Oct 3 4:10 PM".
String when(DateTime t, DateTime now) {
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  final d = switch (days) { 0 => 'Today', 1 => 'Yesterday', _ => shortDate(t) };
  return '$d ${clock(t)}';
}

/// "just now", "5m ago", "3h ago", "2d ago".
String ago(DateTime t, DateTime now) {
  final d = now.difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  if (d.inDays < 60) return '${d.inDays}d ago';
  return shortDate(t);
}

// ── Building blocks ──────────────────────────────────────────────────────────
class KCard extends StatelessWidget {
  const KCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color = K.card, this.radius = 20});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: const BorderSide(color: K.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

enum KTone { green, dark, light, red, ghost }

/// A Cash App pill button.
class KButton extends StatelessWidget {
  const KButton(this.label,
      {super.key, this.onTap, this.tone = KTone.green, this.icon, this.height = 48, this.expand = false, this.fontSize});
  final String label;
  final VoidCallback? onTap;
  final KTone tone;
  final IconData? icon;
  final double height;
  final bool expand;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      KTone.green => (K.green, Colors.white),
      KTone.dark => (K.ink, Colors.white),
      KTone.light => (K.field, K.text),
      KTone.red => (K.redSoft, K.red),
      KTone.ghost => (Colors.transparent, K.greenInk),
    };
    final off = onTap == null;
    final child = Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
      if (icon != null) ...[Icon(icon, size: height * .4, color: fg), const SizedBox(width: 6)],
      Flexible(
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: kt(fontSize ?? (height >= 44 ? 16 : 14), w: FontWeight.w700, c: fg)),
      ),
    ]);
    return Opacity(
      opacity: off ? .4 : 1,
      child: Material(
        color: bg,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // No alignment: a button is as wide as its label unless [expand].
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: height * .42),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A round icon button (top bars, row actions).
class KIconButton extends StatelessWidget {
  const KIconButton(this.icon, {super.key, required this.tooltip, this.onTap, this.size = 40, this.color = K.field, this.fg = K.text});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final Color color;
  final Color fg;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: color,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(width: size, height: size, child: Icon(icon, size: size * .5, color: fg, semanticLabel: tooltip)),
          ),
        ),
      );
}

const _palette = [Color(0xFF00D632), Color(0xFF0A7CFF), Color(0xFFFF6B00), Color(0xFF8E44FF), Color(0xFFFF2D78), Color(0xFF00B5C8), Color(0xFF111111)];

/// Initials in a coloured circle, like Cash App's contacts.
class KAvatar extends StatelessWidget {
  const KAvatar(this.name, {super.key, this.size = 40});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'[\s_.]+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.length == 1
            ? parts.first.substring(0, math.min(2, parts.first.length)).toUpperCase()
            : (parts[0][0] + parts[1][0]).toUpperCase();
    final c = _palette[name.codeUnits.fold(0, (a, b) => a + b) % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c),
      child: Text(initials, style: kt(size * .38, w: FontWeight.w700, c: Colors.white, h: 1)),
    );
  }
}

class KBadge extends StatelessWidget {
  const KBadge(this.text, {super.key, this.fg = K.greenInk, this.bg = K.greenSoft});
  final String text;
  final Color fg;
  final Color bg;

  factory KBadge.player(PlayerStatus s) => switch (s) {
        PlayerStatus.active => const KBadge('Active'),
        PlayerStatus.suspended => const KBadge('Suspended', fg: K.amber, bg: K.amberSoft),
        PlayerStatus.banned => const KBadge('Banned', fg: K.red, bg: K.redSoft),
      };

  factory KBadge.game(GameStatus s) => switch (s) {
        GameStatus.live => const KBadge('Live'),
        GameStatus.maintenance => const KBadge('Off', fg: K.red, bg: K.redSoft),
        GameStatus.hidden => const KBadge('Hidden', fg: K.sub, bg: K.field),
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text, maxLines: 1, style: kt(12, w: FontWeight.w600, c: fg, h: 1.2)),
      );
}

/// A headline number with its label (dashboard tiles).
class KStat extends StatelessWidget {
  const KStat({super.key, required this.label, required this.value, this.sub, this.icon, this.color = K.text, this.onTap});
  final String label;
  final String value;
  final String? sub;
  final IconData? icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => KCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            if (icon != null) ...[Icon(icon, size: 16, color: K.sub), const SizedBox(width: 6)],
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(13, c: K.sub))),
          ]),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: kt(26, w: FontWeight.w700, c: color, h: 1.1, num: true)),
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(12, c: K.faint)),
          ],
        ]),
      );
}

class KField extends StatelessWidget {
  const KField({
    super.key,
    this.label,
    this.controller,
    this.hint,
    this.keyboard,
    this.prefix,
    this.suffix,
    this.obscure = false,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.maxLines = 1,
    this.icon,
    this.formatters,
  });
  final String? label;
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboard;
  final String? prefix;
  final Widget? suffix;
  final bool obscure;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final int maxLines;
  final IconData? icon;
  final List<TextInputFormatter>? formatters;

  /// Digits and one decimal point.
  static final money = [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))];

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        if (label != null) ...[
          Text(label!, style: kt(13, w: FontWeight.w600, c: K.sub)),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          keyboardType: keyboard,
          obscureText: obscure,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          autofocus: autofocus,
          maxLines: maxLines,
          inputFormatters: formatters,
          cursorColor: K.green,
          style: kt(16, c: K.text),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: kt(16, c: K.faint),
            prefixText: prefix,
            prefixStyle: kt(16, c: K.sub),
            prefixIcon: icon == null ? null : Icon(icon, size: 20, color: K.faint),
            suffixIcon: suffix,
            filled: true,
            fillColor: K.field,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.green, width: 2)),
          ),
        ),
      ]);
}

/// Cash App's pill tabs.
class KSegment<T> extends StatelessWidget {
  const KSegment({super.key, required this.values, required this.selected, required this.onChanged, required this.label, this.expand = false});
  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T) label;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    Widget pill(T v) {
      final on = v == selected;
      return Semantics(
        selected: on,
        button: true,
        child: GestureDetector(
          onTap: () => onChanged(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: on ? K.ink : Colors.transparent, borderRadius: BorderRadius.circular(17)),
            child: Text(label(v), maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(14, w: FontWeight.w600, c: on ? Colors.white : K.sub)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: K.field, borderRadius: BorderRadius.circular(20)),
      child: expand
          ? Row(children: [for (final v in values) Expanded(child: pill(v))])
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(mainAxisSize: MainAxisSize.min, children: [for (final v in values) pill(v)]),
            ),
    );
  }
}

class KSwitch extends StatelessWidget {
  const KSwitch({super.key, required this.value, required this.onChanged, this.label});
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        child: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: K.green,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: const Color(0xFFD9D9DC),
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      );
}

/// A settings row: label (and help) on the left, control on the right.
class KRow extends StatelessWidget {
  const KRow({super.key, required this.title, this.sub, required this.trailing});
  final String title;
  final String? sub;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: kt(15, w: FontWeight.w600)),
              if (sub != null) Text(sub!, style: kt(13, c: K.sub, h: 1.3)),
            ]),
          ),
          const SizedBox(width: 12),
          trailing,
        ]),
      );
}

class KTitle extends StatelessWidget {
  const KTitle(this.text, {super.key, this.trailing, this.size = 18});
  final String text;
  final Widget? trailing;
  final double size;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(size, w: FontWeight.w700))),
          if (trailing != null) trailing!,
        ]),
      );
}

class KEmpty extends StatelessWidget {
  const KEmpty(this.text, {super.key, this.icon = Icons.inbox_outlined});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 32, color: K.faint),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: kt(14, c: K.sub)),
        ]),
      );
}

/// A simple table that scrolls sideways when it doesn't fit.
class KTable extends StatelessWidget {
  const KTable({super.key, required this.columns, required this.rows, this.onTap, this.numeric = const {}, this.minWidth = 640});
  final List<String> columns;
  final List<List<Widget>> rows;
  final void Function(int row)? onTap;

  /// Columns aligned right.
  final Set<int> numeric;
  final double minWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final width = math.max(box.maxWidth, minWidth);
        Widget cell(int i, Widget w) => Expanded(
              flex: i == 0 ? 3 : 2,
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 8, right: i == columns.length - 1 ? 0 : 8),
                child: Align(alignment: numeric.contains(i) ? Alignment.centerRight : Alignment.centerLeft, child: w),
              ),
            );
        final table = SizedBox(
          width: width,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                for (final (i, c) in columns.indexed)
                  cell(i, Text(c, maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(12, w: FontWeight.w600, c: K.sub))),
              ]),
            ),
            const Divider(height: 1, color: K.line),
            for (final (r, row) in rows.indexed) ...[
              InkWell(
                onTap: onTap == null ? null : () => onTap!(r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [for (final (i, w) in row.indexed) cell(i, w)]),
                ),
              ),
              if (r < rows.length - 1) const Divider(height: 1, color: K.line, indent: 12, endIndent: 12),
            ],
          ]),
        );
        return width > box.maxWidth ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: table) : table;
      });
}

/// Table cell text.
Widget cellText(String s, {Color c = K.text, FontWeight w = FontWeight.w500, double size = 14}) =>
    Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(size, w: w, c: c, num: true));

/// Bars for Sweeps Coins in (green) and out (black) per day.
class KBarChart extends StatelessWidget {
  const KBarChart({super.key, required this.days, this.height = 180});
  final List<({DateTime day, double coinIn, double coinOut})> days;
  final double height;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(painter: _BarsPainter(days, kt(10, c: K.faint))),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _legend(K.green, 'Coin in'),
          const SizedBox(width: 16),
          _legend(K.ink, 'Coin out'),
        ]),
      ]);

  Widget _legend(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(t, style: kt(12, c: K.sub)),
      ]);
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.days, this.labelStyle);
  final List<({DateTime day, double coinIn, double coinOut})> days;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    const labelH = 16.0;
    final h = size.height - labelH;
    final top = days.fold<double>(1, (a, d) => math.max(a, math.max(d.coinIn, d.coinOut)));
    final slot = size.width / days.length;
    final bar = math.min(14.0, slot * .32);
    final grid = Paint()..color = K.line;
    for (var i = 0; i <= 3; i++) {
      final y = h * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final every = (days.length / 7).ceil();
    for (final (i, d) in days.indexed) {
      final x = slot * i + slot / 2;
      void draw(double v, double dx, Color c) {
        final bh = v / top * (h - 4);
        canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTWH(x + dx, h - bh, bar, bh), topLeft: const Radius.circular(4), topRight: const Radius.circular(4)),
          Paint()..color = c,
        );
      }

      draw(d.coinIn, -bar - 1, K.green);
      draw(d.coinOut, 1, K.ink);
      if (i % every == 0 || i == days.length - 1) {
        final tp = TextPainter(text: TextSpan(text: '${d.day.day}', style: labelStyle), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, h + 3));
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.days != days;
}

/// A black Cash App toast.
void kToast(BuildContext context, String text) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text, style: kt(15, w: FontWeight.w600, c: Colors.white)),
      backgroundColor: K.ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      duration: const Duration(milliseconds: 2200),
    ));
}

void copy(BuildContext context, String text, String what) {
  Clipboard.setData(ClipboardData(text: text));
  kToast(context, '$what copied');
}

/// A form: a bottom sheet on a phone, a centred dialog on desktop.
Future<T?> kSheet<T>(BuildContext context, {required String title, required Widget Function(BuildContext) builder, double width = 480}) {
  Widget body(BuildContext ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
          child: Row(children: [
            Expanded(child: Text(title, style: kt(20, w: FontWeight.w700))),
            KIconButton(Icons.close, tooltip: 'Close', size: 36, onTap: () => Navigator.of(ctx).pop()),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
            child: builder(ctx),
          ),
        ),
      ]);
  if (K.desktop(context)) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: K.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: width, maxHeight: MediaQuery.sizeOf(ctx).height * .9), child: body(ctx)),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: K.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .92), child: body(ctx)),
  );
}

Future<bool> kConfirm(BuildContext context, {required String title, required String message, required String action, bool danger = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: K.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title, style: kt(20, w: FontWeight.w700)),
      content: Text(message, style: kt(15, c: K.sub, h: 1.4)),
      actions: [
        KButton('Cancel', tone: KTone.light, height: 42, onTap: () => Navigator.of(ctx).pop(false)),
        KButton(action, tone: danger ? KTone.red : KTone.green, height: 42, onTap: () => Navigator.of(ctx).pop(true)),
      ],
    ),
  );
  return ok ?? false;
}

/// Run a back-office action, showing its error (if any) as a toast.
bool attempt(BuildContext context, void Function() action, {String? done}) {
  try {
    action();
    if (done != null) kToast(context, done);
    return true;
  } on CasinoError catch (e) {
    kToast(context, e.message);
    return false;
  }
}

/// Parse a typed amount ("1,250.50").
double? amountOf(String s) => double.tryParse(s.trim().replaceAll(',', '').replaceAll('\$', ''));

/// The back office for the admin pages.
class CasinoScope extends InheritedNotifier<Casino> {
  const CasinoScope({super.key, required Casino casino, required super.child}) : super(notifier: casino);

  static Casino of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<CasinoScope>()!.notifier!;
  static Casino read(BuildContext context) => context.getInheritedWidgetOfExactType<CasinoScope>()!.notifier!;
}

// ── Staying signed in ────────────────────────────────────────────────────────
const _adminKey = 'zoya7.admin';

/// Sign in and keep this device signed in until Lock.
Staff? signInAndRemember(Casino c, String pin) {
  final s = c.signIn(pin);
  if (s != null) save(_adminKey, pin);
  return s;
}

/// Sign back in with the PIN this device remembers (no PIN screen).
void restoreAdmin(Casino c) {
  if (c.admin != null) return;
  final pin = loadSaved(_adminKey);
  if (pin != null && c.signIn(pin, log: false) == null) clearSaved(_adminKey);
}

/// Lock: forget the PIN on this device and go back to the PIN screen.
void lockAdmin(Casino c) {
  clearSaved(_adminKey);
  c.signOut();
}

// ── Database ─────────────────────────────────────────────────────────────────
class SyncScope extends InheritedNotifier<CasinoSync> {
  const SyncScope({super.key, required CasinoSync? sync, required super.child}) : super(notifier: sync);

  static CasinoSync? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SyncScope>()?.notifier;
}

/// A dot and a word: is this device on the shared database?
class SyncChip extends StatelessWidget {
  const SyncChip({super.key, this.onTap, this.compact = false});
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.of(context);
    final state = sync?.state ?? SyncState.off;
    final (color, label) = switch (state) {
      SyncState.off => (K.faint, 'This device only'),
      SyncState.connecting => (K.amber, 'Connecting…'),
      SyncState.live => (K.green, 'Live database'),
      SyncState.offline => (K.red, 'Offline — retrying'),
    };
    return Semantics(
      button: onTap != null,
      label: 'Database: $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
            if (!compact) ...[
              const SizedBox(width: 7),
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: kt(13, w: FontWeight.w600, c: K.sub))),
            ],
          ]),
        ),
      ),
    );
  }
}
