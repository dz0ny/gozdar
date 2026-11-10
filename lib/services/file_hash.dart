import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// The SHA-256 of the file at [path] as lower-case hex. A background
/// isolate reads the file, so a large database does not block the UI.
Future<String> sha256OfFile(String path) => compute(_sha256OfFile, path);

Future<String> _sha256OfFile(String path) async =>
    (await sha256.bind(File(path).openRead()).first).toString();
