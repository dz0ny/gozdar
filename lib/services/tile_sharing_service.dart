import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nsd/nsd.dart' as nsd;

import 'offline_tile_cache_service.dart';

class TilePeer {
  final String ipAddress;
  final int port;

  const TilePeer({required this.ipAddress, required this.port});

  String get baseUrl => 'http://$ipAddress:$port';

  @override
  bool operator ==(Object other) {
    return other is TilePeer && other.ipAddress == ipAddress && other.port == port;
  }

  @override
  int get hashCode => Object.hash(ipAddress, port);
}

class PeerCatalog {
  final TilePeer peer;
  final List<StyleInfo> styles;

  const PeerCatalog({required this.peer, required this.styles});
}

sealed class PeerSyncEvent {}

class PeerSyncStarted extends PeerSyncEvent {
  final int totalTiles;

  PeerSyncStarted(this.totalTiles);
}

class PeerSyncTileDownloaded extends PeerSyncEvent {
  final int downloaded;
  final int total;

  PeerSyncTileDownloaded({required this.downloaded, required this.total});
}

class PeerSyncTileSkipped extends PeerSyncEvent {
  final int skipped;
  final int total;

  PeerSyncTileSkipped({required this.skipped, required this.total});
}

class PeerSyncComplete extends PeerSyncEvent {
  final int downloaded;
  final int skipped;
  final int failed;

  PeerSyncComplete({
    required this.downloaded,
    required this.skipped,
    required this.failed,
  });
}

class PeerSyncCancelled extends PeerSyncEvent {}

class TileSharingService {
  TileSharingService._();

  static final instance = TileSharingService._();

  static const int defaultPort = 8347;
  static const String serviceType = '_sartiles._tcp';

  final OfflineTileCacheService _cache = OfflineTileCacheService.instance;
  final http.Client _httpClient = http.Client();

  HttpServer? _server;
  nsd.Discovery? _activeDiscovery;
  nsd.Registration? _activeRegistration;

  final _peersController = StreamController<Set<TilePeer>>.broadcast();
  final Set<TilePeer> _discoveredPeers = {};

  bool _syncCancelled = false;

  bool get isRunning => _server != null;
  Stream<Set<TilePeer>> get peersStream => _peersController.stream;
  Set<TilePeer> get discoveredPeers => Set.unmodifiable(_discoveredPeers);

  Future<void> startServer() async {
    if (_server != null) return;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, defaultPort);
      _server!.listen(_handleRequest, onError: (error) {
        debugPrint('[TileSharing] Server error: $error');
      });
      await _advertise();
    } catch (e) {
      debugPrint('[TileSharing] Failed to start server: $e');
      _server = null;
    }
  }

  Future<void> stopServer() async {
    await _stopAdvertising();
    await _server?.close();
    _server = null;
  }

  Future<void> startDiscovery() async {
    if (_activeDiscovery != null) return;

    try {
      _activeDiscovery = await nsd.startDiscovery(serviceType);
      _activeDiscovery!.addServiceListener((service, status) {
        if (service.host == null || service.port == null) return;

        final peer = TilePeer(
          ipAddress: service.host!,
          port: service.port!,
        );

        if (status == nsd.ServiceStatus.found) {
          _discoveredPeers.add(peer);
        } else {
          _discoveredPeers.remove(peer);
        }
        _peersController.add(Set.unmodifiable(_discoveredPeers));
      });
    } catch (e) {
      debugPrint('[TileSharing] Discovery error: $e');
    }
  }

  Future<void> stopPeerDiscovery() async {
    if (_activeDiscovery != null) {
      await nsd.stopDiscovery(_activeDiscovery!);
      _activeDiscovery = null;
    }
    _discoveredPeers.clear();
    _peersController.add(const {});
  }

  void addManualPeer(String ipAddress, {int port = defaultPort}) {
    _discoveredPeers.add(TilePeer(ipAddress: ipAddress, port: port));
    _peersController.add(Set.unmodifiable(_discoveredPeers));
  }

  void removePeer(TilePeer peer) {
    _discoveredPeers.remove(peer);
    _peersController.add(Set.unmodifiable(_discoveredPeers));
  }

  Future<PeerCatalog?> fetchPeerCatalog(TilePeer peer) async {
    try {
      final uri = Uri.parse('${peer.baseUrl}/styles');
      final response = await _httpClient.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as List<dynamic>;
      final styles = data
          .map((entry) => StyleInfo.fromJson(entry as Map<String, dynamic>))
          .toList();
      return PeerCatalog(peer: peer, styles: styles);
    } catch (e) {
      debugPrint('[TileSharing] fetchPeerCatalog(${peer.ipAddress}): $e');
      return null;
    }
  }

  Future<List<PeerCatalog>> fetchAllPeerCatalogs() async {
    final futures = _discoveredPeers.map((peer) => fetchPeerCatalog(peer)).toList();
    final results = await Future.wait(futures);
    return results.whereType<PeerCatalog>().toList();
  }

  Future<List<CachedTileCoord>?> fetchPeerTileList(
    TilePeer peer,
    String styleHash,
  ) async {
    try {
      final uri = Uri.parse('${peer.baseUrl}/tiles/$styleHash/list');
      final response = await _httpClient.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((entry) => CachedTileCoord.fromJson(entry as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[TileSharing] fetchPeerTileList(${peer.ipAddress}): $e');
      return null;
    }
  }

  Future<Uint8List?> fetchTileFromPeer(
    TilePeer peer,
    String styleHash,
    int z,
    int x,
    int y,
  ) async {
    try {
      final uri = Uri.parse('${peer.baseUrl}/tiles/$styleHash/$z/$x/$y.avif');
      final response = await _httpClient.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (_) {}
    return null;
  }

  void cancelSync() {
    _syncCancelled = true;
  }

  Stream<PeerSyncEvent> syncStyleFromPeers({
    required List<TilePeer> peers,
    required String styleHash,
    required StyleInfo styleMeta,
    int maxConcurrency = 8,
  }) {
    final controller = StreamController<PeerSyncEvent>();
    _runSync(
      controller: controller,
      peers: peers,
      styleHash: styleHash,
      styleMeta: styleMeta,
      maxConcurrency: maxConcurrency,
    );
    return controller.stream;
  }

  Future<void> _runSync({
    required StreamController<PeerSyncEvent> controller,
    required List<TilePeer> peers,
    required String styleHash,
    required StyleInfo styleMeta,
    required int maxConcurrency,
  }) async {
    _syncCancelled = false;

    await _cache.saveStyleMeta(
      styleHash,
      displayName: styleMeta.displayName,
      urlTemplate: styleMeta.urlTemplate,
      region: styleMeta.region,
    );

    final allTiles = <String, CachedTileCoord>{};
    for (final peer in peers) {
      if (_syncCancelled) break;
      final tiles = await fetchPeerTileList(peer, styleHash);
      if (tiles != null) {
        for (final tile in tiles) {
          allTiles['${tile.z}/${tile.x}/${tile.y}'] = tile;
        }
      }
    }

    final tilesToSync = allTiles.values.toList();
    controller.add(PeerSyncStarted(tilesToSync.length));

    if (tilesToSync.isEmpty || _syncCancelled) {
      controller.add(PeerSyncComplete(downloaded: 0, skipped: 0, failed: 0));
      await controller.close();
      return;
    }

    var downloaded = 0;
    var skipped = 0;
    var failed = 0;
    final total = tilesToSync.length;

    final semaphore = _Semaphore(maxConcurrency);
    final futures = <Future<void>>[];
    var peerIndex = 0;

    for (final tile in tilesToSync) {
      if (_syncCancelled) break;

      await semaphore.acquire();
      if (_syncCancelled) {
        semaphore.release();
        break;
      }

      final peer = peers[peerIndex % peers.length];
      peerIndex++;

      final future = () async {
        try {
          if (await _cache.hasTile(styleHash, tile.z, tile.x, tile.y)) {
            skipped++;
            controller.add(PeerSyncTileSkipped(skipped: skipped, total: total));
            return;
          }

          Uint8List? bytes = await fetchTileFromPeer(peer, styleHash, tile.z, tile.x, tile.y);
          if (bytes == null) {
            for (final fallback in peers) {
              if (fallback == peer) continue;
              bytes = await fetchTileFromPeer(
                fallback,
                styleHash,
                tile.z,
                tile.x,
                tile.y,
              );
              if (bytes != null) break;
            }
          }

          if (bytes != null) {
            await _cache.putRawTile(styleHash, tile.z, tile.x, tile.y, bytes);
            downloaded++;
            controller.add(PeerSyncTileDownloaded(downloaded: downloaded, total: total));
          } else {
            failed++;
          }
        } catch (_) {
          failed++;
        } finally {
          semaphore.release();
        }
      }();
      futures.add(future);
    }

    await Future.wait(futures);

    if (_syncCancelled) {
      controller.add(PeerSyncCancelled());
    } else {
      controller.add(
        PeerSyncComplete(downloaded: downloaded, skipped: skipped, failed: failed),
      );
    }
    await controller.close();
  }

  Future<void> _advertise() async {
    try {
      final styles = await _cache.listStyles();
      _activeRegistration = await nsd.register(
        nsd.Service(
          name: 'Gozdar Tiles',
          type: serviceType,
          port: defaultPort,
          txt: {'styles': Uint8List.fromList(utf8.encode(styles.join(',')))},
        ),
      );
    } catch (e) {
      debugPrint('[TileSharing] mDNS registration error: $e');
    }
  }

  Future<void> _stopAdvertising() async {
    if (_activeRegistration != null) {
      await nsd.unregister(_activeRegistration!);
      _activeRegistration = null;
    }
  }

  void _handleRequest(HttpRequest request) async {
    request.response.headers.add('Access-Control-Allow-Origin', '*');

    final path = request.uri.path;

    if (path == '/styles') {
      final styles = await _cache.listStylesDetailed();
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(styles.map((style) => style.toJson()).toList()));
      await request.response.close();
      return;
    }

    final listPattern = RegExp(r'^/tiles/([a-f0-9]+)/list$');
    final listMatch = listPattern.firstMatch(path);
    if (listMatch != null) {
      final styleHash = listMatch.group(1)!;
      final tiles = await _cache.listTilesForStyle(styleHash);
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(tiles.map((tile) => tile.toJson()).toList()));
      await request.response.close();
      return;
    }

    final tilePattern = RegExp(r'^/tiles/([a-f0-9]+)/(\d+)/(\d+)/(\d+)\.avif$');
    final tileMatch = tilePattern.firstMatch(path);
    if (tileMatch != null) {
      final styleHash = tileMatch.group(1)!;
      final z = int.parse(tileMatch.group(2)!);
      final x = int.parse(tileMatch.group(3)!);
      final y = int.parse(tileMatch.group(4)!);

      final bytes = await _cache.getRawTile(styleHash, z, x, y);
      if (bytes != null) {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType('image', 'avif')
          ..add(bytes);
        await request.response.close();
        return;
      }
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }
}

class _Semaphore {
  final int maxCount;
  int _currentCount = 0;
  final _waitQueue = <Completer<void>>[];

  _Semaphore(this.maxCount);

  Future<void> acquire() async {
    if (_currentCount < maxCount) {
      _currentCount++;
      return;
    }
    final completer = Completer<void>();
    _waitQueue.add(completer);
    await completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      _waitQueue.removeAt(0).complete();
    } else {
      _currentCount--;
    }
  }
}
