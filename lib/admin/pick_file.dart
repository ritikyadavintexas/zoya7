import 'dart:typed_data';

import 'pick_file_stub.dart' if (dart.library.js_interop) 'pick_file_web.dart' as impl;

/// Whether this panel can open files from the computer (the web panel can).
bool get canPickFiles => impl.canPickFiles;

/// Asks for a .zip; its name and bytes, or null if none was chosen.
Future<(String, Uint8List)?> pickZip() => impl.pickZip();
