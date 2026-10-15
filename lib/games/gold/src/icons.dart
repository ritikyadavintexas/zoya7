import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Inline SVG icons, copied verbatim from the design.
class GoldIcons {
  GoldIcons._();

  static const _chat =
      '<svg viewBox="0 0 24 24" fill="#ffe08a"><path d="M12 3C6.5 3 2 6.6 2 11c0 2.4 1.3 4.5 3.4 6L4.5 21l4.4-2.3c1 .2 2 .3 3.1.3 5.5 0 10-3.6 10-8s-4.5-8-10-8z"/></svg>';
  static const _gear =
      '<svg viewBox="0 0 24 24" fill="#ffe08a"><path d="M19.4 13a7.5 7.5 0 0 0 0-2l2-1.6-2-3.4-2.4 1a7.5 7.5 0 0 0-1.7-1L15 3.5h-4l-.4 2.5a7.5 7.5 0 0 0-1.7 1l-2.4-1-2 3.4L6.6 11a7.5 7.5 0 0 0 0 2l-2 1.6 2 3.4 2.4-1a7.5 7.5 0 0 0 1.7 1l.4 2.5h4l.4-2.5a7.5 7.5 0 0 0 1.7-1l2.4 1 2-3.4zM12 15.5a3.5 3.5 0 1 1 0-7 3.5 3.5 0 0 1 0 7z"/></svg>';
  static const _info =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#ffd45a" stroke-width="2.6" stroke-linecap="round"><circle cx="12" cy="12" r="9.5"/><path d="M12 11v6"/><path d="M12 7.2v.1"/></svg>';
  static const _send =
      '<svg viewBox="0 0 24 24" fill="#ffe7a0"><path d="M3 20.5l18-8.5L3 3.5 3 10l12 2-12 2z"/></svg>';
  static String _close(double w) =>
      '<svg viewBox="0 0 24 24" fill="none" stroke="#ffd45a" stroke-width="$w" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg>';

  static Widget chat(double s) => SvgPicture.string(_chat, width: s, height: s);
  static Widget gear(double s) => SvgPicture.string(_gear, width: s, height: s);
  static Widget info(double s) => SvgPicture.string(_info, width: s, height: s);
  static Widget send(double s) => SvgPicture.string(_send, width: s, height: s);
  static Widget close(double s) => SvgPicture.string(_close(3), width: s, height: s);
}
