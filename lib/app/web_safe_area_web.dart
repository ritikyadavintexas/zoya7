import 'dart:js_interop';

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
