import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum DownloadOutcome { complete, failed, cancelled }

class DownloadResult {
  const DownloadResult(this.outcome, {this.statusCode});

  final DownloadOutcome outcome;

  /// HTTP status of a refused request (e.g. 404), when that ended it.
  final int? statusCode;

  bool get isComplete => outcome == DownloadOutcome.complete;
}

/// Downloads a URL into a `.part` file that survives interruptions: a dropped
/// connection or stalled stream is retried from the bytes already on disk
/// (HTTP `Range`), and a part left behind by an earlier run (app killed, phone
/// offline) is continued the next time. The first response's ETag /
/// Last-Modified is kept with the part; a file that changed meanwhile is
/// downloaded whole again (via `If-Range`, or by checking the partial
/// response where a server ignores that), so an old part is never glued onto
/// a new file.
///
/// The caller owns [part]: on [DownloadOutcome.complete] it holds the whole
/// file; otherwise it is kept for the next attempt. A complete part that is
/// not [discard]ed (e.g. it could not be decrypted) is confirmed by the next
/// [fetch] without downloading it again.
class ResumableDownload {
  ResumableDownload._();

  /// Retries per [fetch] after a network error; each continues where the
  /// last stopped.
  static const maxAttempts = 6;

  /// A stream that delivers nothing for this long counts as dropped.
  static const stallTimeout = Duration(seconds: 30);

  static Future<DownloadResult> fetch(
    String url,
    File part, {
    http.Client? client,
    Map<String, String> headers = const {},
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
    Duration connectTimeout = const Duration(seconds: 30),
    int attempts = maxAttempts,
  }) async {
    final ownClient = client == null;
    final c = client ?? http.Client();
    final validatorFile = File('${part.path}.validator');
    try {
      for (var attempt = 1; ; attempt++) {
        if (isCancelled?.call() ?? false) {
          return const DownloadResult(DownloadOutcome.cancelled);
        }
        try {
          final result = await _attempt(
            c,
            url,
            part,
            validatorFile,
            headers: headers,
            onProgress: onProgress,
            isCancelled: isCancelled,
            connectTimeout: connectTimeout,
          );
          if (result != null) return result;
          // null: incomplete body — retry from what arrived.
        } on TimeoutException catch (e) {
          debugPrint('ResumableDownload $url: $e (attempt $attempt)');
        } on SocketException catch (e) {
          debugPrint('ResumableDownload $url: $e (attempt $attempt)');
        } on HttpException catch (e) {
          debugPrint('ResumableDownload $url: $e (attempt $attempt)');
        } on http.ClientException catch (e) {
          debugPrint('ResumableDownload $url: $e (attempt $attempt)');
        }
        if (attempt >= attempts) {
          return const DownloadResult(DownloadOutcome.failed);
        }
        // 1, 2, 4, 8, 16 s between attempts.
        await Future<void>.delayed(Duration(seconds: 1 << (attempt - 1)));
      }
    } finally {
      if (ownClient) c.close();
    }
  }

  /// One request; null when the body ended early and should be resumed.
  static Future<DownloadResult?> _attempt(
    http.Client client,
    String url,
    File part,
    File validatorFile, {
    required Map<String, String> headers,
    required void Function(int, int?)? onProgress,
    required bool Function()? isCancelled,
    required Duration connectTimeout,
  }) async {
    var have = await part.exists() ? await part.length() : 0;
    final validator = await validatorFile.exists()
        ? (await validatorFile.readAsString()).trim()
        : '';
    // Without a validator we can't tell whether the part still matches.
    if (have > 0 && validator.isEmpty) have = 0;

    final request = http.Request('GET', Uri.parse(url))
      ..headers.addAll(headers);
    if (have > 0) {
      request.headers['Range'] = 'bytes=$have-';
      request.headers['If-Range'] = validator;
    }
    final response = await client.send(request).timeout(connectTimeout);

    if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable &&
        have > 0) {
      // Nothing left past what we have: the part is the whole file, if it is
      // still the same file (R2 sends no validator with a 416, so ask).
      await response.stream.drain<void>();
      final head = await client
          .head(Uri.parse(url), headers: headers)
          .timeout(connectTimeout);
      final now = head.headers['etag'] ?? head.headers['last-modified'];
      // A HEAD response's contentLength is its (empty) body; use the header.
      final length = int.tryParse(head.headers['content-length'] ?? '');
      if (head.statusCode == HttpStatus.ok &&
          now == validator &&
          length == have) {
        return const DownloadResult(DownloadOutcome.complete);
      }
      await discard(part);
      return _attempt(
        client,
        url,
        part,
        validatorFile,
        headers: headers,
        onProgress: onProgress,
        isCancelled: isCancelled,
        connectTimeout: connectTimeout,
      );
    }
    final resumed = response.statusCode == HttpStatus.partialContent;
    if (!resumed && response.statusCode != HttpStatus.ok) {
      await response.stream.drain<void>();
      final status = response.statusCode;
      if (status >= 500) {
        throw HttpException('HTTP $status');
      }
      return DownloadResult(DownloadOutcome.failed, statusCode: status);
    }

    // Not every server honours If-Range (R2 sends the tail of the new file
    // regardless), so check the validator of the partial response too.
    if (resumed) {
      final now = response.headers['etag'] ?? response.headers['last-modified'];
      if (now != null && now != validator) {
        await response.stream.drain<void>();
        await discard(part);
        return _attempt(
          client,
          url,
          part,
          validatorFile,
          headers: headers,
          onProgress: onProgress,
          isCancelled: isCancelled,
          connectTimeout: connectTimeout,
        );
      }
    }

    final int? total;
    if (resumed) {
      total =
          _contentRangeTotal(response.headers['content-range']) ??
          (response.contentLength == null
              ? null
              : have + response.contentLength!);
    } else {
      // Fresh copy (first try, or the file changed): start over.
      have = 0;
      total = response.contentLength;
      final v = response.headers['etag'] ?? response.headers['last-modified'];
      if (v != null && v.isNotEmpty) {
        await validatorFile.writeAsString(v);
      } else if (await validatorFile.exists()) {
        await validatorFile.delete();
      }
    }

    final sink = part.openWrite(
      mode: resumed ? FileMode.append : FileMode.write,
    );
    var received = have;
    try {
      await for (final chunk in response.stream.timeout(stallTimeout)) {
        if (isCancelled?.call() ?? false) {
          return const DownloadResult(DownloadOutcome.cancelled);
        }
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
    } finally {
      await sink.close();
    }
    if (total != null && received < total) return null;
    return const DownloadResult(DownloadOutcome.complete);
  }

  /// Removes [part] and its bookkeeping, e.g. after it was moved into place
  /// or turned out to be unusable.
  static Future<void> discard(File part) async {
    for (final f in [part, File('${part.path}.validator')]) {
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  /// "bytes 100-199/1000" → 1000.
  static int? _contentRangeTotal(String? header) {
    if (header == null) return null;
    final slash = header.lastIndexOf('/');
    if (slash < 0) return null;
    return int.tryParse(header.substring(slash + 1).trim());
  }
}
