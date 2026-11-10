import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_nsd/flutter_nsd.dart';
import 'package:http/http.dart' as http;
import 'package:nsd/nsd.dart' as nsd;
import 'package:path_provider/path_provider.dart';

import 'address_lookup_service.dart';
import 'file_hash.dart';
import 'kataster_update_service.dart';
import 'owner_lookup_service.dart';
import 'resumable_download.dart';
import 'vlake_service.dart';

class KatasterPeer {
  final String host;
  final int port;

  const KatasterPeer({required this.host, required this.port});

  String get baseUrl => 'http://$host:$port';

  @override
  bool operator ==(Object other) =>
      other is KatasterPeer && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);
}

class SharedKatasterFile {
  final String fileName;
  final int bytes;

  const SharedKatasterFile({required this.fileName, required this.bytes});

  Map<String, dynamic> toJson() => {'fileName': fileName, 'bytes': bytes};

  factory SharedKatasterFile.fromJson(Map<String, dynamic> json) =>
      SharedKatasterFile(
        fileName: json['fileName'] as String? ?? '',
        bytes: json['bytes'] as int? ?? 0,
      );
}

class KatasterSharingService {
  KatasterSharingService._();

  static final instance = KatasterSharingService._();

  static const int defaultPort = 8348;
  static const String serviceType = '_gozdar-kataster._tcp';
  static const String discoveryServiceType = '$serviceType.';

  final FlutterNsd _flutterNsd = FlutterNsd();
  final http.Client _httpClient = http.Client();
  final _peersController = StreamController<Set<KatasterPeer>>.broadcast();
  final Set<KatasterPeer> _peers = {};

  HttpServer? _server;
  nsd.Registration? _registration;
  StreamSubscription<NsdServiceInfo>? _discoverySubscription;
  bool _discovering = false;

  /// The SHA-256 a data file must have, or null when it is not known. The
  /// default reads the manifest on R2, which comes over HTTPS.
  @visibleForTesting
  Future<String?> Function(String fileName) trustedHash =
      KatasterUpdateService.instance.trustedSha256;

  /// Adds a phone without the network discovery.
  @visibleForTesting
  void addPeerForTesting(KatasterPeer peer) => _peers.add(peer);

  @visibleForTesting
  void clearPeersForTesting() => _peers.clear();

  bool get isSharing => _server != null;
  Stream<Set<KatasterPeer>> get peersStream => _peersController.stream;
  Set<KatasterPeer> get peers => Set.unmodifiable(_peers);

  Future<void> startSharing() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, defaultPort);
      _server!.listen(
        _handleRequest,
        onError: (error) {
          debugPrint('KatasterSharingService server error: $error');
        },
      );
      await _advertise();
    } catch (e) {
      debugPrint('KatasterSharingService.startSharing failed: $e');
      await _server?.close();
      _server = null;
    }
  }

  Future<void> stopSharing() async {
    await _stopAdvertising();
    await _server?.close();
    _server = null;
  }

  Future<void> startDiscovery() async {
    if (_discovering) return;
    _discoverySubscription ??= _flutterNsd.stream.listen(
      _handleDiscoveredService,
      onError: (error) =>
          debugPrint('KatasterSharingService discovery: $error'),
    );
    try {
      await _flutterNsd.discoverServices(discoveryServiceType);
      _discovering = true;
    } catch (e) {
      debugPrint('KatasterSharingService.startDiscovery failed: $e');
    }
  }

  Future<void> stopDiscovery() async {
    if (!_discovering) return;
    try {
      await _flutterNsd.stopDiscovery();
    } catch (e) {
      debugPrint('KatasterSharingService.stopDiscovery failed: $e');
    }
    _discovering = false;
  }

  Future<List<SharedKatasterFile>> fetchFiles(KatasterPeer peer) async {
    try {
      final response = await _httpClient
          .get(Uri.parse('${peer.baseUrl}/kataster/files'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != HttpStatus.ok) return const [];
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map(
            (entry) =>
                SharedKatasterFile.fromJson(entry as Map<String, dynamic>),
          )
          .where((entry) => entry.fileName.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('KatasterSharingService.fetchFiles failed: $e');
      return const [];
    }
  }

  /// Fetches [fileName] from a nearby phone that has it into [target]. With
  /// [discover] it first looks for phones (and briefly waits for them);
  /// without, only phones already found are asked, so a background download
  /// never triggers the system's local-network prompt.
  ///
  /// A phone sends the file over plain HTTP, so the copy is only accepted
  /// when its SHA-256 equals the one in the manifest ([trustedHash]). The
  /// copy arrives in `<target>.peer`, where an interrupted transfer
  /// continues, and replaces [target] after the check. Returns false when
  /// no phone has the file, the hash is not known or no copy passed; the
  /// caller then downloads from the internet.
  Future<bool> downloadFileTo(
    String fileName,
    File target, {
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
    bool discover = true,
  }) async {
    if (discover) {
      await startDiscovery();
      if (_peers.isEmpty) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }

    final part = File('${target.path}.peer');
    String? expected;
    try {
      for (final peer in List<KatasterPeer>.from(_peers)) {
        if (isCancelled?.call() ?? false) return false;
        final files = await fetchFiles(peer);
        if (!files.any((file) => file.fileName == fileName)) continue;
        expected ??= await trustedHash(fileName);
        if (expected == null) {
          debugPrint('KatasterSharingService: no hash for $fileName');
          return false;
        }
        final ok = await _downloadFromPeer(
          peer,
          fileName,
          part,
          onProgress: onProgress,
          isCancelled: isCancelled,
        );
        if (isCancelled?.call() ?? false) return false;
        if (!ok) continue;
        if (await sha256OfFile(part.path) != expected) {
          debugPrint(
            'KatasterSharingService: $fileName from ${peer.host} has '
            'the wrong hash',
          );
          await ResumableDownload.discard(part);
          continue;
        }
        // An internet download left unfinished must not mix with this copy.
        await ResumableDownload.discard(target);
        await part.rename(target.path);
        await ResumableDownload.discard(part);
        return true;
      }
    } on FileSystemException catch (e, s) {
      debugPrint('KatasterSharingService.downloadFileTo failed: $e\n$s');
    }
    return false;
  }

  Future<bool> _downloadFromPeer(
    KatasterPeer peer,
    String fileName,
    File target, {
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    // Resumes a part left by an earlier attempt; few retries, since the
    // caller falls back to the internet when the peer goes away.
    final result = await ResumableDownload.fetch(
      '${peer.baseUrl}/kataster/files/${Uri.encodeComponent(fileName)}',
      target,
      client: _httpClient,
      connectTimeout: const Duration(seconds: 5),
      attempts: 2,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    return result.isComplete;
  }

  Future<List<SharedKatasterFile>> listLocalFiles() async {
    final dir = await getApplicationSupportDirectory();
    final out = <SharedKatasterFile>[];
    if (!await dir.exists()) return out;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!_isSharedFileName(name)) continue;
      out.add(SharedKatasterFile(fileName: name, bytes: await entity.length()));
    }
    out.sort((a, b) => a.fileName.compareTo(b.fileName));
    return out;
  }

  Future<void> _advertise() async {
    try {
      _registration = await nsd.register(
        nsd.Service(
          name: 'Gozdar Kataster',
          type: serviceType,
          port: _server?.port ?? defaultPort,
        ),
      );
    } catch (e) {
      debugPrint('KatasterSharingService._advertise failed: $e');
    }
  }

  Future<void> _stopAdvertising() async {
    if (_registration == null) return;
    try {
      await nsd.unregister(_registration!);
    } catch (e) {
      debugPrint('KatasterSharingService._stopAdvertising failed: $e');
    }
    _registration = null;
  }

  void _handleDiscoveredService(NsdServiceInfo service) {
    final host = service.hostname;
    final port = service.port;
    if (host == null || host.isEmpty || port == null || port <= 0) return;

    final peer = KatasterPeer(host: host, port: port);
    _peers.add(peer);
    _peersController.add(Set.unmodifiable(_peers));
  }

  Future<void> _handleRequest(HttpRequest request) async {
    request.response.headers.add('Access-Control-Allow-Origin', '*');

    if (request.uri.path == '/kataster/files') {
      final files = await listLocalFiles();
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(files.map((file) => file.toJson()).toList()));
      await request.response.close();
      return;
    }

    final match = RegExp(r'^/kataster/files/([^/]+)$')
        .firstMatch(request.uri.path);
    if (match != null) {
      final fileName = Uri.decodeComponent(match.group(1)!);
      if (!_isSharedFileName(fileName)) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      if (await file.exists()) {
        await serveFile(request, file);
        return;
      }
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  /// Sends [file], or the requested tail of it (`Range: bytes=N-`) so an
  /// interrupted copy on the other phone continues instead of restarting.
  /// The ETag (size + modification time) lets that phone check with
  /// `If-Range` that the file is still the one it started on.
  @visibleForTesting
  static Future<void> serveFile(HttpRequest request, File file) async {
    final length = await file.length();
    final etag =
        '"$length-${(await file.lastModified()).millisecondsSinceEpoch}"';
    final response = request.response
      ..headers.contentType = ContentType.binary
      ..headers.set(HttpHeaders.etagHeader, etag)
      ..headers.set(HttpHeaders.acceptRangesHeader, 'bytes');

    final ifRange = request.headers.value(HttpHeaders.ifRangeHeader);
    final range = RegExp(r'^bytes=(\d+)-$')
        .firstMatch(request.headers.value(HttpHeaders.rangeHeader) ?? '');
    final start = range == null ? null : int.tryParse(range.group(1)!);
    if (start != null && (ifRange == null || ifRange == etag)) {
      if (start >= length) {
        response
          ..statusCode = HttpStatus.requestedRangeNotSatisfiable
          ..headers.set(HttpHeaders.contentRangeHeader, 'bytes */$length');
        await response.close();
        return;
      }
      response
        ..statusCode = HttpStatus.partialContent
        ..headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-${length - 1}/$length',
        )
        ..headers.set(HttpHeaders.contentLengthHeader, length - start);
      await response.addStream(file.openRead(start));
    } else {
      response
        ..statusCode = HttpStatus.ok
        ..headers.set(HttpHeaders.contentLengthHeader, length);
      await response.addStream(file.openRead());
    }
    await response.close();
  }

  /// Downloaded data other phones may fetch: kataster regions, the owner
  /// databases and the Vlake overlay.
  static const _sharedAssets = {
    OwnerLookupService.sharedFileName,
    OwnerLookupService.publicFileName,
    OwnerLookupService.publicHrFileName,
    VlakeService.fileName,
    AddressLookupService.fileName,
  };

  bool _isSharedFileName(String fileName) =>
      !fileName.contains('/') &&
      !fileName.contains('\\') &&
      ((fileName.startsWith('parcels') && fileName.endsWith('.sqlite')) ||
          _sharedAssets.contains(fileName));
}
