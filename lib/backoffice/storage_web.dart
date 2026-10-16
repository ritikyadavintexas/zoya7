import 'dart:js_interop';

extension type _Storage(JSObject _) implements JSObject {
  external JSString? getItem(JSString key);
  external void setItem(JSString key, JSString value);
  external void removeItem(JSString key);
}

@JS('localStorage')
external _Storage? get _storage;

// Storage can be missing or throw (private browsing, blocked site data).
String? load(String key) {
  try {
    return _storage?.getItem(key.toJS)?.toDart;
  } catch (_) {
    return null;
  }
}

void save(String key, String value) {
  try {
    _storage?.setItem(key.toJS, value.toJS);
  } catch (_) {}
}

void clear(String key) {
  try {
    _storage?.removeItem(key.toJS);
  } catch (_) {}
}
