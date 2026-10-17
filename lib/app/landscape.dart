import 'package:flutter/widgets.dart';

/// Keeps the game in landscape. Android and iOS builds lock the screen to
/// landscape; a browser can't, so while the window is taller than it is wide
/// (a phone held upright) the whole game is drawn turned a quarter clockwise,
/// with the safe-area insets turned to match. It starts in landscape whichever
/// way the phone is held, with nothing to wait for.
class ForceLandscape extends StatelessWidget {
  const ForceLandscape({super.key, required this.child});
  final Widget child;

  /// Screen insets → insets of the turned game: the screen's top edge becomes
  /// the game's left, its right the game's top, and so on.
  static EdgeInsets _turn(EdgeInsets e) => EdgeInsets.fromLTRB(e.top, e.right, e.bottom, e.left);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final upright = mq.size.width < mq.size.height;
    // The same tree either way, so turning the phone keeps the page as it was.
    return RotatedBox(
      quarterTurns: upright ? 1 : 0,
      child: MediaQuery(
        data: upright
            ? mq.copyWith(
                size: mq.size.flipped,
                padding: _turn(mq.padding),
                viewPadding: _turn(mq.viewPadding),
                viewInsets: _turn(mq.viewInsets),
                systemGestureInsets: _turn(mq.systemGestureInsets),
              )
            : mq,
        child: child,
      ),
    );
  }
}
