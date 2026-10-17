import 'dart:js_interop';
import 'dart:js_interop_unsafe';

extension type _Init._(JSObject _) implements JSObject {
  external factory _Init({JSString method, JSString? body, JSString cache});
}

extension type _Response._(JSObject _) implements JSObject {
  external int get status;
  external JSPromise<JSString> text();
}

@JS('fetch')
external JSPromise<_Response> _fetch(JSString url, _Init init);

Future<({int status, String body})> request(String method, String url, String? body,
    {String? contentType, Map<String, String>? headers}) async {
  final init = _Init(method: method.toJS, body: body?.toJS, cache: 'no-store'.toJS);
  // Only when asked: a content type turns a database request into one the
  // browser checks with the server first.
  if (contentType != null || headers != null) {
    init.setProperty('headers'.toJS, {...?headers, if (contentType != null) 'Content-Type': contentType}.jsify());
  }
  final res = await _fetch(url.toJS, init).toDart;
  final text = (await res.text().toDart).toDart;
  return (status: res.status, body: text);
}
