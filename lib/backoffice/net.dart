import 'net_io.dart' if (dart.library.js_interop) 'net_web.dart' as impl;

/// One HTTP request (fetch on the web, dart:io elsewhere).
Future<({int status, String body})> httpRequest(String method, String url, [String? body]) =>
    impl.request(method, url, body);

/// A POST with a content type (the sign-in service wants one).
Future<({int status, String body})> httpPost(String url, String body, String contentType) =>
    impl.request('POST', url, body, contentType: contentType);
