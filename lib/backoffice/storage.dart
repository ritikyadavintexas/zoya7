import 'storage_stub.dart' if (dart.library.js_interop) 'storage_web.dart' as impl;

/// Where the back office keeps its data between visits: the browser's
/// localStorage on the web; nowhere yet on Android/iOS (in memory only) —
/// replace with your server.
String? loadSaved(String key) => impl.load(key);
void save(String key, String value) => impl.save(key, value);
void clearSaved(String key) => impl.clear(key);
