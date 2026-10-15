import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// SVG path data copied from the design (24×24 viewBox).
class P {
  static const back = 'M15 5l-7 7 7 7';
  static const forward = 'M9 5l7 7-7 7';
  static const chevDown = 'M6 9l6 6 6-6';
  static const close = 'M6 6l12 12M18 6L6 18';
  static const check = 'M5 12l5 5 9-10';
  static const plus = 'M12 5v14M5 12h14';
  static const home = 'M12 3l9 8h-3v9h-4.5v-6h-3v6H6v-9H3z';
  static const games =
      'M7 7h10a5 5 0 0 1 4.9 6l-.8 4a2.5 2.5 0 0 1-4.4 1L14.5 16h-5l-2.2 2a2.5 2.5 0 0 1-4.4-1l-.8-4A5 5 0 0 1 7 7zm1 3v1.5H6.5v1.5H8v1.5h1.5V13H11v-1.5H9.5V10zm8 .5a1 1 0 1 0 0 2 1 1 0 0 0 0-2zm-2 2a1 1 0 1 0 0 2 1 1 0 0 0 0-2z';
  static const gift =
      'M3 9h18v4H3zM4 13h7v8H4zM13 13h7v8h-7zM11 9h2v12h-2zM12 9C9 9 6.5 7.5 7.5 5.5S11 6 12 9zM12 9c3 0 5.5-1.5 4.5-3.5S13 6 12 9z';
  static const giftPlain = 'M3 9h18v4H3zM4 13h7v8H4zM13 13h7v8h-7zM11 9h2v12h-2z';
  static const wallet =
      'M4 6a2 2 0 0 1 2-2h11v3H6v.01H20a1 1 0 0 1 1 1V19a1 1 0 0 1-1 1H6a2 2 0 0 1-2-2zm12 7a1.5 1.5 0 1 0 0 3h5v-3z';
  static const profile = 'M12 3.5a4.5 4.5 0 1 1 0 9 4.5 4.5 0 0 1 0-9zM3.5 21c0-4.4 3.8-7.5 8.5-7.5s8.5 3.1 8.5 7.5z';
  static const bell = 'M12 2a6 6 0 0 0-6 6v4l-2 4h16l-2-4V8a6 6 0 0 0-6-6zm-2.5 16a2.5 2.5 0 0 0 5 0z';
  static const chat =
      'M12 3C6.5 3 2 6.6 2 11c0 2.4 1.3 4.5 3.4 6L4.5 21l4.4-2.3c1 .2 2 .3 3.1.3 5.5 0 10-3.6 10-8s-4.5-8-10-8z';
  static const chatDots =
      'M12 3C6.5 3 2 6.6 2 11c0 2.4 1.3 4.5 3.4 6L4.5 21l4.4-2.3c1 .2 2 .3 3.1.3 5.5 0 10-3.6 10-8s-4.5-8-10-8zM7.5 12.5a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zm4.5 0a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zm4.5 0a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3z';
  static const crown = 'M3 18h18l1.5-11-5.5 4.5L12 4 7 11.5 1.5 7z';
  static const gearSpokes =
      'M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M5.3 18.7l2.1-2.1M16.6 7.4l2.1-2.1';
  static const gear =
      'M19.4 13a7.5 7.5 0 0 0 0-2l2-1.6-2-3.4-2.4 1a7.5 7.5 0 0 0-1.7-1L15 3.5h-4l-.4 2.5a7.5 7.5 0 0 0-1.7 1l-2.4-1-2 3.4L6.6 11a7.5 7.5 0 0 0 0 2l-2 1.6 2 3.4 2.4-1a7.5 7.5 0 0 0 1.7 1l.4 2.5h4l.4-2.5a7.5 7.5 0 0 0 1.7-1l2.4 1 2-3.4zM12 15.5a3.5 3.5 0 1 1 0-7 3.5 3.5 0 0 1 0 7z';
  static const pencil =
      'M4 17.5V20h2.5l9.9-9.9-2.5-2.5zM18.7 7.8a1.5 1.5 0 0 0 0-2.1l-.4-.4a1.5 1.5 0 0 0-2.1 0l-1.3 1.3 2.5 2.5z';
  static const doc = 'M6 2h9l5 5v15H6zm8 1.5V8h4.5zM9 12v1.5h8V12zm0 4v1.5h8V16z';
  static const shield = 'M12 2l8 3v6c0 5-3.4 9.3-8 11-4.6-1.7-8-6-8-11V5z';
  static const trophy =
      'M7 3h10v2h4v3a5 5 0 0 1-4.6 5A5 5 0 0 1 13 16v2h3v3H8v-3h3v-2a5 5 0 0 1-3.4-3A5 5 0 0 1 3 8V5h4z';
  static const trophyFull =
      'M7 3h10v2h4v3a5 5 0 0 1-4.6 5A5 5 0 0 1 13 16v2h3v3H8v-3h3v-2a5 5 0 0 1-3.4-3A5 5 0 0 1 3 8V5h4zm-2 4v1a3 3 0 0 0 2 2.8V7zm14 0h-2v3.8A3 3 0 0 0 19 8z';
  static const coin =
      'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm1 15.5V19h-2v-1.5c-1.7-.3-3-1.4-3-3h2c0 .8.9 1.5 2 1.5s2-.6 2-1.5-.8-1.2-2.3-1.6C9.6 12.3 8 11.7 8 10c0-1.5 1.3-2.6 3-2.9V5.5h2v1.6c1.7.3 3 1.4 3 2.9h-2c0-.8-.9-1.5-2-1.5s-2 .6-2 1.4.8 1.1 2.3 1.5c2.1.6 3.7 1.2 3.7 3.1 0 1.6-1.3 2.7-3 3z';
  static const addFriend =
      'M9 4a4 4 0 1 1 0 8 4 4 0 0 1 0-8zM1.5 20c0-4 3.4-6.5 7.5-6.5s7.5 2.5 7.5 6.5zM18 8v3h-3v2h3v3h2v-3h3v-2h-3V8z';
  static const play = 'M6 4l14 8-14 8z';
  static const send = 'M3 20.5l18-8.5L3 3.5 3 10l12 2-12 2z';
  static const lock =
      'M6 10V8a6 6 0 1 1 12 0v2h1a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V11a1 1 0 0 1 1-1zm2 0h8V8a4 4 0 1 0-8 0z';
  static const card =
      'M3 5h18a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1zm-1 4v2h20V9zM5 15v1.5h5V15z';
  static const bank = 'M12 2l10 5v2H2V7zM4 10h3v8H4zm6.5 0h3v8h-3zM17 10h3v8h-3zM2 19h20v3H2z';
}

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
String _op(Color c) => ((c.toARGB32() >> 24) / 255).toStringAsFixed(3);

/// A filled design icon.
class Ico extends StatelessWidget {
  const Ico(this.d, {super.key, this.size = 24, this.color = const Color(0xFFF2C869)});
  final String d;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.string(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="$d" fill="${_hex(color)}" fill-opacity="${_op(color)}"/></svg>',
        width: size,
        height: size,
      );
}

/// A stroked (line) design icon.
class StrokeIco extends StatelessWidget {
  const StrokeIco(this.d, {super.key, this.size = 24, this.color = const Color(0xFFF2C869), this.width = 3});
  final String d;
  final double size;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) => SvgPicture.string(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="${_hex(color)}" '
        'stroke-width="$width" stroke-linecap="round" stroke-linejoin="round"><path d="$d"/></svg>',
        width: size,
        height: size,
      );
}

/// Arbitrary inline SVG markup inside a 24×24 viewBox.
class RawIco extends StatelessWidget {
  const RawIco(this.inner, {super.key, this.size = 24});
  final String inner;
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.string(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">$inner</svg>',
        width: size,
        height: size,
      );
}
