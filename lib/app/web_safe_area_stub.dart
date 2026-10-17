import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

EdgeInsets readSafeAreaInsets() => EdgeInsets.zero;

final _keyboard = ValueNotifier<double>(0);

/// Off the web the keyboard reaches the app as view insets already.
ValueListenable<double> keyboardInset() => _keyboard;

/// Lets tests raise a pretend keyboard (in pixels).
@visibleForTesting
ValueNotifier<double> get debugKeyboard => _keyboard;
