import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'game_keyboard.dart';

/// Keeps the game in landscape. Android and iOS builds lock the screen to
/// landscape; a browser can't, so while the window is taller than it is wide
/// (a phone held upright) the whole game is drawn turned a quarter clockwise,
/// with the safe-area insets turned to match. It starts in landscape whichever
/// way the phone is held, with nothing to wait for.
///
/// Turned, the phone's own keyboard would come up across the bottom the
/// ordinary way, so on a touch phone text boxes type with [GameKeyboard]
/// instead, drawn turned along the game's bottom edge, the page above it.
class ForceLandscape extends StatefulWidget {
  const ForceLandscape({super.key, required this.child});
  final Widget child;

  /// Screen insets → insets of the turned game: the screen's top edge becomes
  /// the game's left, its right the game's top, and so on.
  static EdgeInsets _turn(EdgeInsets e) => EdgeInsets.fromLTRB(e.top, e.right, e.bottom, e.left);

  /// Phones and tablets (a computer keeps its own keys, even in a tall window).
  static bool get _touch => defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;

  @override
  State<ForceLandscape> createState() => _ForceLandscapeState();
}

class _ForceLandscapeState extends State<ForceLandscape> {
  final _keyboard = GameKeyboard.instance;
  bool _upright = false;

  @override
  void initState() {
    super.initState();
    _keyboard.addListener(_keyboardMoved);
  }

  @override
  void dispose() {
    _keyboard.removeListener(_keyboardMoved);
    _keyboard.use(false);
    super.dispose();
  }

  void _keyboardMoved() {
    if (!mounted) return;
    setState(() {});
    if (!_keyboard.visible) return;
    // Once the page is above the keys, bring the box being typed in into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = FocusManager.instance.primaryFocus?.context?.findRenderObject();
      if (box is RenderBox && box.attached) {
        box.showOnScreen(rect: (Offset.zero & box.size).inflate(16), duration: const Duration(milliseconds: 150));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final upright = mq.size.width < mq.size.height;
    if (upright != _upright) {
      _upright = upright;
      final own = upright && ForceLandscape._touch;
      WidgetsBinding.instance.addPostFrameCallback((_) => _keyboard.use(own));
    }
    final size = upright ? mq.size.flipped : mq.size;
    final turned = upright
        ? mq.copyWith(
            size: size,
            padding: ForceLandscape._turn(mq.padding),
            viewPadding: ForceLandscape._turn(mq.viewPadding),
            viewInsets: ForceLandscape._turn(mq.viewInsets),
            systemGestureInsets: ForceLandscape._turn(mq.systemGestureInsets),
          )
        : mq;
    final keys = upright && _keyboard.visible ? GameKeyboardView.heightFor(size.height, safeBottom: turned.padding.bottom) : 0.0;
    // The same tree either way, so turning the phone keeps the page as it was.
    return RotatedBox(
      quarterTurns: upright ? 1 : 0,
      child: MediaQuery(
        data: turned,
        child: Column(children: [
          Expanded(
            // The page in the room above the keys (same width, so it keeps its layout).
            child: MediaQuery(
              data: turned.copyWith(
                size: Size(size.width, size.height - keys),
                padding: keys > 0 ? turned.padding.copyWith(bottom: 0) : turned.padding,
                viewPadding: keys > 0 ? turned.viewPadding.copyWith(bottom: 0) : turned.viewPadding,
              ),
              child: widget.child,
            ),
          ),
          SizedBox(
            height: keys,
            child: keys > 0 ? GameKeyboardView(height: size.height) : null,
          ),
        ]),
      ),
    );
  }
}
