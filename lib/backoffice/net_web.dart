import 'dart:js_interop';

extension type _Init._(JSObject _) implements JSObject {
  external factory _Init({JSString method, JSString? body, JSString cache});
}

extension type _Response._(JSObject _) implements JSObject {
  external int get status;
  external JSPromise<JSString> text();
}

@JS('fetch')
external JSPromise<_Response> _fetch(JSString url, _Init init);

Future<({int status, String body})> request(String method, String url, String? body) async {
  final res = await _fetch(url.toJS, _Init(method: method.toJS, body: body?.toJS, cache: 'no-store'.toJS)).toDart;
  final text = (await res.text().toDart).toDart;
  return (status: res.status, body: text);
}
