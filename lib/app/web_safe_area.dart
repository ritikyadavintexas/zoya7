import 'package:flutter/widgets.dart';

import 'web_safe_area_stub.dart' if (dart.library.js_interop) 'web_safe_area_web.dart';

/// Flutter web leaves [MediaQueryData.padding] at zero, so a home-screen web app
/// drawn edge to edge would put content under the notch and home indicator.
/// This feeds the browser's safe-area insets into the [MediaQuery] so every
/// [SafeArea] works on web like it does natively. Does nothing off the web.
class WebSafeArea extends StatefulWidget {
  const WebSafeArea({super.key, required this.child});
  final Widget child;

  @override
  State<WebSafeArea> createState() => _WebSafeAreaState();
}

class _WebSafeAreaState extends State<WebSafeArea> with WidgetsBindingObserver {
  EdgeInsets _insets = readSafeAreaInsets();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The browser can settle the insets a moment after start-up or a rotation.
    Future<void>.delayed(const Duration(milliseconds: 300), _refresh);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
    if (_insets == EdgeInsets.zero) return widget.child;
    final mq = MediaQuery.of(context);
    final viewPadding = _max(mq.viewPadding, _insets);
    return MediaQuery(
      data: mq.copyWith(
        viewPadding: viewPadding,
        // Like native: the keyboard covers the bottom inset.
        padding: viewPadding.copyWith(
          bottom: viewPadding.bottom > mq.viewInsets.bottom ? viewPadding.bottom - mq.viewInsets.bottom : 0,
        ),
      ),
      child: widget.child,
    );
  }
}
