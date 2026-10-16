import 'dart:js_interop';

@JS('zoyaApp')
external JSString? get _zoyaApp;

@JS('zoyaStandalone')
external JSFunction? get _zoyaStandalone;

@JS('navigator.userAgent')
external JSString get _ua;

String? pageApp() => _zoyaApp?.toDart;

bool runningStandalone() {
  final f = _zoyaStandalone;
  if (f == null) return false;
  return (f.callAsFunction() as JSBoolean?)?.toDart ?? false;
}

bool isAppleMobile() => RegExp('iPhone|iPad|iPod').hasMatch(_ua.toDart);
