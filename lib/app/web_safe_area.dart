import 'package:flutter/widgets.dart';

import 'web_safe_area_stub.dart' if (dart.library.js_interop) 'web_safe_area_web.dart';

export 'web_safe_area_stub.dart' if (dart.library.js_interop) 'web_safe_area_web.dart' show debugKeyboard;

/// Flutter web leaves [MediaQueryData.padding] at zero, so a home-screen web app
/// drawn edge to edge would put content under the notch and home indicator.
/// This feeds the browser's safe-area insets into the [MediaQuery] so every
/// [SafeArea] works on web like it does natively.
///
/// It also keeps everything above a phone's on-screen keyboard: Flutter web
/// can't see the keyboard when it draws into a box of its own, so while the
/// keyboard is up (web/viewport.js measures it) the app is laid out in the part
/// above it, as a phone app is, and the field being typed in is scrolled into
/// view. Does nothing off the web.
class WebSafeArea extends StatefulWidget {
  const WebSafeArea({super.key, required this.child, this.keyboardFill = const Color(0xFF000000)});
  final Widget child;

  /// Painted behind the keyboard (seen through it on iPhones).
  final Color keyboardFill;

  @override
  State<WebSafeArea> createState() => _WebSafeAreaState();
}

class _WebSafeAreaState extends State<WebSafeArea> with WidgetsBindingObserver {
  EdgeInsets _insets = readSafeAreaInsets();
  final _keyboard = keyboardInset();

  @override
  void initState() {
    super.initState();
    _keyboard.addListener(_keyboardMoved);
    WidgetsBinding.instance.addObserver(this);
    // The browser can settle the insets a moment after start-up or a rotation.
    Future<void>.delayed(const Duration(milliseconds: 300), _refresh);
  }

  @override
  void dispose() {
    _keyboard.removeListener(_keyboardMoved);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _keyboardMoved() {
    if (!mounted) return;
    setState(() {});
    if (_keyboard.value <= 0) return;
    // Once laid out above the keyboard, bring the field being typed in into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = FocusManager.instance.primaryFocus?.context?.findRenderObject();
      if (box is! RenderBox || !box.attached) return;
      // With a margin, so the whole box around the text shows too.
      box.showOnScreen(
        rect: (Offset.zero & box.size).inflate(20),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
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
    final kb = _keyboard.value.clamp(0.0, mq.size.height);
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
    );
  }
}
