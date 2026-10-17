import 'package:flutter/widgets.dart';

import 'web_safe_area_stub.dart' if (dart.library.js_interop) 'web_safe_area_web.dart';

export 'web_safe_area_stub.dart' if (dart.library.js_interop) 'web_safe_area_web.dart' show debugKeyboard;

/// Flutter web leaves [MediaQueryData.padding] at zero, so a home-screen web app
/// drawn edge to edge would put content under the notch and home indicator.
/// This feeds the browser's safe-area insets into the [MediaQuery] so every
/// [SafeArea] works on web like it does natively.
///
/// It also keeps the field being typed in above a phone's on-screen keyboard:
/// Flutter web can't see the keyboard when it draws into a box of its own, so
/// while the keyboard is up (web/viewport.js measures it) the app is laid out
/// in the part above it, as a phone app is, and the field is scrolled into
/// view. Does nothing off the web.
class WebSafeArea extends StatefulWidget {
  const WebSafeArea({super.key, required this.child, this.keyboardFill = const Color(0xFF000000), this.turnsWhenUpright = false});
  final Widget child;

  /// Painted behind the keyboard (seen through it on iPhones).
  final Color keyboardFill;

  /// The app is drawn turned on an upright phone (the game, [ForceLandscape]).
  /// Laying it out again above the keyboard would change its width, and pages
  /// would swap their fields for others (losing the one being typed in, and
  /// with it the keyboard), so there it keeps its layout and slides up instead,
  /// just enough to show the field.
  final bool turnsWhenUpright;

  @override
  State<WebSafeArea> createState() => _WebSafeAreaState();
}

class _WebSafeAreaState extends State<WebSafeArea> with WidgetsBindingObserver {
  EdgeInsets _insets = readSafeAreaInsets();
  final _keyboard = keyboardInset();

  /// Sliding up instead of laying out again (see [WebSafeArea.turnsWhenUpright]),
  /// and by how much.
  bool _slides = false;
  double _slide = 0;

  @override
  void initState() {
    super.initState();
    _keyboard.addListener(_keyboardMoved);
    FocusManager.instance.addListener(_focusMoved);
    WidgetsBinding.instance.addObserver(this);
    // The browser can settle the insets a moment after start-up or a rotation.
    Future<void>.delayed(const Duration(milliseconds: 300), _refresh);
  }

  @override
  void dispose() {
    _keyboard.removeListener(_keyboardMoved);
    FocusManager.instance.removeListener(_focusMoved);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _keyboardMoved() {
    if (!mounted) return;
    setState(() {
      if (_keyboard.value <= 0) _slide = 0;
    });
    if (_keyboard.value > 0) WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  /// Return moved to the next field while the keyboard is up.
  void _focusMoved() {
    if (mounted && _keyboard.value > 0) WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  /// Brings the field being typed in into view above the keyboard.
  void _reveal() {
    if (!mounted || _keyboard.value <= 0) return;
    final box = FocusManager.instance.primaryFocus?.context?.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    if (_slides) {
      // Where the field is on screen without the slide, and how far up it must go.
      final rect = MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size).shift(Offset(0, _slide));
      final visible = MediaQuery.sizeOf(context).height - _keyboard.value;
      final slide = (rect.bottom + 24 - visible).clamp(0.0, _keyboard.value);
      if (slide != _slide) setState(() => _slide = slide);
      return;
    }
    // With a margin, so the whole box around the text shows too.
    box.showOnScreen(
      rect: (Offset.zero & box.size).inflate(20),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  void didChangeMetrics() {
    _refresh();
    Future<void>.delayed(const Duration(milliseconds: 300), _refresh);
  }

  void _refresh() {
    if (!mounted) return;
    final insets = readSafeAreaInsets();
    if (insets != _insets) setState(() => _insets = insets);
  }

  static EdgeInsets _max(EdgeInsets a, EdgeInsets b) => EdgeInsets.fromLTRB(
    a.left > b.left ? a.left : b.left,
    a.top > b.top ? a.top : b.top,
    a.right > b.right ? a.right : b.right,
    a.bottom > b.bottom ? a.bottom : b.bottom,
  );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    _slides = widget.turnsWhenUpright && mq.size.width < mq.size.height;
    // How much less room the layout gets (none when it slides instead).
    final kb = _slides ? 0.0 : _keyboard.value.clamp(0.0, mq.size.height);
    final size = Size(mq.size.width, mq.size.height - kb);
    final viewPadding = _max(mq.viewPadding, _insets);
    final base = _insets == EdgeInsets.zero
        ? mq
        : mq.copyWith(
            viewPadding: viewPadding,
            // Like native: the keyboard covers the bottom inset.
            padding: viewPadding.copyWith(
              bottom: viewPadding.bottom > mq.viewInsets.bottom ? viewPadding.bottom - mq.viewInsets.bottom : 0,
            ),
          );
    // The same widgets with or without the keyboard, so no page loses its state.
    return ColoredBox(
      color: widget.keyboardFill,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox.fromSize(
          size: size,
          child: Transform.translate(
            offset: Offset(0, _slides && _keyboard.value > 0 ? -_slide : 0),
            child: MediaQuery(
              data: kb > 0
                  // Above the keyboard: nothing more to avoid at the bottom.
                  ? base.copyWith(
                      size: size,
                      viewPadding: base.viewPadding.copyWith(bottom: 0),
                      padding: base.padding.copyWith(bottom: 0),
                      viewInsets: EdgeInsets.zero,
                    )
                  : base,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
