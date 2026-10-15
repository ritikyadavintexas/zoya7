import 'package:flutter/widgets.dart';

/// Keeps the app in landscape. Android and iOS builds lock the screen to
/// landscape; a browser can't, so when the window is taller than it is wide
/// (a phone held upright) the whole app is drawn turned a quarter clockwise,
/// with the safe-area insets turned to match. Turning the phone sideways then
/// shows it the right way up.
class ForceLandscape extends StatelessWidget {
  const ForceLandscape({super.key, required this.child});
  final Widget child;

  /// Screen insets → insets of the turned app: the screen's top edge becomes
  /// the app's left, its right the app's top, and so on.
  static EdgeInsets _turn(EdgeInsets e) => EdgeInsets.fromLTRB(e.top, e.right, e.bottom, e.left);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width >= mq.size.height) return child;
    return RotatedBox(
      quarterTurns: 1,
      child: MediaQuery(
        data: mq.copyWith(
          size: mq.size.flipped,
          padding: _turn(mq.padding),
          viewPadding: _turn(mq.viewPadding),
          viewInsets: _turn(mq.viewInsets),
          systemGestureInsets: _turn(mq.systemGestureInsets),
        ),
        child: child,
      ),
    );
  }
}
