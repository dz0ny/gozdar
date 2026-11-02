import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'kataster_sharing_service.dart';
import 'resumable_download.dart';

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

  /// Ensure [fileName] is present locally, fetching it if needed: from a
  /// nearby phone that has it (see [KatasterSharingService]), else from
  /// [url]. Streams to a `.part` file and only commits on success, so a
  /// failed download never leaves a corrupt file; an interrupted one is
  /// continued, now or on the next call (see [ResumableDownload]). Returns
  /// the local path, or null when no copy exists and the download failed.
  ///
  /// With [refresh] an existing copy is re-downloaded and replaced on success
  /// (the old file stays intact until then). Callers must close any handle on
  /// the old file before the swap — see [beforeSwap]. [isCancelled] is polled
  /// per chunk; a cancelled download returns null and leaves the old copy open.
  static Future<String?> ensure(
    String url,
    String fileName, {
    void Function(int received, int? total)? onProgress,
    bool refresh = false,
    Future<void> Function()? beforeSwap,
    bool Function()? isCancelled,
  }) async {
    try {
      final target = await localPath(fileName);
      final targetFile = File(target);
      if (!refresh &&
          await targetFile.exists() &&
          await targetFile.length() > 0) {
        return target;
      }
      final part = File('$target.part');
      // A refresh must not pick up the peer copy of the file we already have.
      final fromPeer =
          !refresh &&
          await KatasterSharingService.instance.downloadFileTo(
            fileName,
            part,
            onProgress: onProgress,
            isCancelled: isCancelled,
            discover: false,
          );
      if (!fromPeer) {
        final result = await ResumableDownload.fetch(
          url,
          part,
          onProgress: onProgress,
          isCancelled: isCancelled,
        );
        if (!result.isComplete) {
          if (result.statusCode != null) {
            debugPrint('RemoteAsset $fileName: HTTP ${result.statusCode}');
          }
          return null;
        }
      }
      if (isCancelled?.call() ?? false) return null;
      await beforeSwap?.call();
      if (await targetFile.exists()) await targetFile.delete();
      await part.rename(target);
      await ResumableDownload.discard(part);
      return target;
    } catch (e) {
      debugPrint('RemoteAsset.ensure($fileName) failed: $e');
      return null;
    }
  }
}
