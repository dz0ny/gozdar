import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Downloads a single remote file into the application-support directory on
/// first use and re-uses the cached copy afterwards — the same "fetch once,
/// keep offline" model the kataster uses, but for one fixed file.
///
/// Used to keep large, rarely-changing data (the public-owners DB, the Vlake
/// overlay) off the app bundle: they are hosted on R2 and pulled on demand.
class RemoteAsset {
  /// Local path for [fileName] in the app-support dir.
  static Future<String> localPath(String fileName) async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}${Platform.pathSeparator}$fileName';
  }

  /// Whether [fileName] has already been downloaded.
  static Future<bool> exists(String fileName) async {
    final f = File(await localPath(fileName));
    return await f.exists() && await f.length() > 0;
  }

  /// Ensure [fileName] is present locally, downloading it from [url] if needed.
  /// Streams to a `.part` file and only commits on success, so a failed or
  /// interrupted download never leaves a corrupt file. Returns the local path,
  /// or null when no copy exists and the download failed.
  static Future<String?> ensure(
    String url,
    String fileName, {
    void Function(int received, int? total)? onProgress,
  }) async {
    try {
      final target = await localPath(fileName);
      final targetFile = File(target);
      if (await targetFile.exists() && await targetFile.length() > 0) {
        return target;
      }
      final part = File('$target.part');
      if (await part.exists()) await part.delete();

      final client = http.Client();
      try {
        final resp =
            await client.send(http.Request('GET', Uri.parse(url)));
        if (resp.statusCode != 200) {
          debugPrint('RemoteAsset $fileName: HTTP ${resp.statusCode}');
          return null;
        }
        final total = resp.contentLength;
        var received = 0;
        final sink = part.openWrite();
        try {
          await for (final chunk in resp.stream) {
            sink.add(chunk);
            received += chunk.length;
            onProgress?.call(received, total);
          }
        } finally {
          await sink.close();
        }
        await part.rename(target);
        return target;
      } finally {
        client.close();
        if (await part.exists()) {
          try {
            await part.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('RemoteAsset.ensure($fileName) failed: $e');
      return null;
    }
  }
}
