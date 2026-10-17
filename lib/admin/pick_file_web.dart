import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

const canPickFiles = true;

Future<(String, Uint8List)?> pickZip() {
  final done = Completer<(String, Uint8List)?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.zip,application/zip';
  input.style.display = 'none';
  web.document.body?.append(input);
  void finish((String, Uint8List)? result) {
    input.remove();
    if (!done.isCompleted) done.complete(result);
  }

  input.addEventListener(
      'change',
      ((web.Event _) {
        final f = input.files?.item(0);
        if (f == null) return finish(null);
        f.arrayBuffer().toDart.then((b) => finish((f.name, b.toDart.asUint8List())), onError: (Object _) => finish(null));
      }).toJS);
  input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);
  input.click();
  return done.future;
}
