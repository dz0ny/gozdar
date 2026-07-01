import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_nsd/flutter_nsd.dart';
import 'package:http/http.dart' as http;
import 'package:nsd/nsd.dart' as nsd;
import 'package:path_provider/path_provider.dart';

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

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'bytes': bytes,
      };

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

  bool get isSharing => _server != null;
  Stream<Set<KatasterPeer>> get peersStream => _peersController.stream;
  Set<KatasterPeer> get peers => Set.unmodifiable(_peers);

  Future<void> startSharing() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, defaultPort);
      _server!.listen(_handleRequest, onError: (error) {
        debugPrint('KatasterSharingService server error: $error');
      });
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
      onError: (error) => debugPrint('KatasterSharingService discovery: $error'),
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
          .map((entry) => SharedKatasterFile.fromJson(entry as Map<String, dynamic>))
          .where((entry) => entry.fileName.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('KatasterSharingService.fetchFiles failed: $e');
      return const [];
    }
  }

  Future<bool> downloadFileTo(
    String fileName,
    File target, {
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    await startDiscovery();
    if (_peers.isEmpty) {
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    for (final peer in List<KatasterPeer>.from(_peers)) {
      if (isCancelled?.call() ?? false) return false;
      final files = await fetchFiles(peer);
      if (!files.any((file) => file.fileName == fileName)) continue;
      final ok = await _downloadFromPeer(
        peer,
        fileName,
        target,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
      if (ok) return true;
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
    final request = http.Request(
      'GET',
      Uri.parse('${peer.baseUrl}/kataster/files/${Uri.encodeComponent(fileName)}'),
    );
    try {
      final response = await _httpClient.send(request).timeout(
            const Duration(seconds: 5),
          );
      if (response.statusCode != HttpStatus.ok) return false;

      final sink = target.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          if (isCancelled?.call() ?? false) return false;
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, response.contentLength);
        }
      } finally {
        await sink.close();
      }
      return received > 0;
    } catch (e) {
      debugPrint('KatasterSharingService._downloadFromPeer failed: $e');
      return false;
    }
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

    final match = RegExp(r'^/kataster/files/([^/]+)$').firstMatch(request.uri.path);
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
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.binary
          ..headers.set(HttpHeaders.contentLengthHeader, await file.length());
        await request.response.addStream(file.openRead());
        await request.response.close();
        return;
      }
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  bool _isSharedFileName(String fileName) =>
      fileName.startsWith('parcels') &&
      fileName.endsWith('.sqlite') &&
      !fileName.contains('/') &&
      !fileName.contains('\\');
}
