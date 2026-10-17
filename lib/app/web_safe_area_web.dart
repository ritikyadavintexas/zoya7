import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Defined in web/index.html: the CSS safe-area insets as [top, right, bottom, left].
@JS('zoyaSafeArea')
external JSFunction? get _zoyaSafeArea;

EdgeInsets readSafeAreaInsets() {
  final fn = _zoyaSafeArea;
  if (fn == null) return EdgeInsets.zero;
  final v = fn.callAsFunction().dartify();
  if (v is! List || v.length != 4) return EdgeInsets.zero;
  double at(int i) => (v[i] as num?)?.toDouble() ?? 0;
  return EdgeInsets.fromLTRB(at(3), at(0), at(1), at(2));
}

/// Set by web/viewport.js: how much of the app the on-screen keyboard covers.
@JS('zoyaKeyboardInset')
external JSNumber? get _zoyaKeyboardInset;

@JS('zoyaOnKeyboard')
external set _zoyaOnKeyboard(JSFunction? f);

final _keyboard = ValueNotifier<double>(0);
var _watching = false;

/// The keyboard's height over the app (0 when it's down), as it changes.
ValueListenable<double> keyboardInset() {
  if (!_watching) {
    _watching = true;
    _zoyaOnKeyboard = ((JSNumber px) => _keyboard.value = px.toDartDouble).toJS;
    _keyboard.value = _zoyaKeyboardInset?.toDartDouble ?? 0;
  }
  return _keyboard;
}

/// Lets tests raise a pretend keyboard (in pixels).
@visibleForTesting
ValueNotifier<double> get debugKeyboard => _keyboard;
