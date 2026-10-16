import 'web_env_stub.dart' if (dart.library.js_interop) 'web_env_web.dart' as impl;

/// "admin" when the page is the separate admin app (web/admin/index.html).
String? pageApp() => impl.pageApp();

/// Opened from the home screen (installed), not in a browser tab.
bool runningStandalone() => impl.runningStandalone();

/// iPhone / iPad (for the right "Add to Home Screen" steps).
bool isAppleMobile() => impl.isAppleMobile();
