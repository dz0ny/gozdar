import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/map_layer.dart';
import '../services/offline_tile_cache_service.dart';
import '../services/map_preferences_service.dart';
import '../services/tile_cache_service.dart';
import '../services/tile_sharing_service.dart';

/// Dialog for downloading map tiles for offline use.
/// Includes peer sharing UI from the MeshCore flow.
class TileDownloadDialog extends StatefulWidget {
  final MapLayer currentLayer;
  final LatLngBounds bounds;
  final int currentZoom;

  const TileDownloadDialog({
    super.key,
    required this.currentLayer,
    required this.bounds,
    required this.currentZoom,
  });

  @override
  State<TileDownloadDialog> createState() => _TileDownloadDialogState();
}

class _TileDownloadDialogState extends State<TileDownloadDialog> {
  final TileCacheService _tileCacheService = TileCacheService();
  final TileSharingService _tileSharingService = TileSharingService.instance;
  StreamSubscription<Set<TilePeer>>? _peersSubscription;
  StreamSubscription<PeerSyncEvent>? _syncSubscription;

  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _errorMessage;
  Map<String, dynamic>? _cacheStats;
  bool _isServerRunning = false;
  bool _isFetchingCatalogs = false;
  bool _isSyncing = false;
  String _syncStatus = '';
  double _syncProgress = 0;
  Set<TilePeer> _discoveredPeers = {};
  List<PeerCatalog> _peerCatalogs = [];
  List<StyleInfo> _localStyles = [];
  final String _workerUrl = MapPreferencesService.defaultWorkerUrl;

  int get _minZoom => widget.currentZoom.clamp(1, widget.currentLayer.maxZoom).toInt();
  int get _maxZoom => widget.currentLayer.maxZoom.toInt();

  @override
  void initState() {
    super.initState();
    _isServerRunning = _tileSharingService.isRunning;
    _peersSubscription = _tileSharingService.peersStream.listen((peers) {
      if (mounted) {
        setState(() {
          _discoveredPeers = peers;
        });
      }
    });
    _tileSharingService.startDiscovery();
    _loadCacheStats();
    _refreshLocalStyles();
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _peersSubscription?.cancel();
    _tileSharingService.stopPeerDiscovery();
    super.dispose();
  }

  Future<void> _loadCacheStats() async {
    final stats = await _tileCacheService.getStats();
    if (mounted) {
      setState(() {
        _cacheStats = stats;
      });
    }
  }

  Future<void> _refreshLocalStyles() async {
    final styles = await OfflineTileCacheService.instance.listStylesDetailed();
    if (mounted) {
      setState(() {
        _localStyles = styles;
      });
    }
  }

  Future<void> _refreshPeerCatalogs() async {
    setState(() {
      _isFetchingCatalogs = true;
    });
    final catalogs = await _tileSharingService.fetchAllPeerCatalogs();
    if (mounted) {
      setState(() {
        _peerCatalogs = catalogs;
        _isFetchingCatalogs = false;
      });
    }
  }

  int get _estimatedTileCount {
    return _tileCacheService.estimateTileCount(
      bounds: widget.bounds,
      minZoom: _minZoom,
      maxZoom: _maxZoom,
    );
  }

  bool get _canDownload => _urlTemplate != null;

  String? get _urlTemplate {
    return widget.currentLayer.resolveUrlTemplate(_workerUrl);
  }

  Future<void> _startDownload() async {
    final urlTemplate = _urlTemplate;
    if (urlTemplate == null) {
      setState(() {
        _errorMessage = 'URL predloge ni na voljo';
      });
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _errorMessage = null;
    });

    try {
      await _tileCacheService.downloadRegion(
        isSlovenian: widget.currentLayer.isSlovenian,
        urlTemplate: urlTemplate,
        bounds: widget.bounds,
        minZoom: _minZoom,
        maxZoom: _maxZoom,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
            });
          }
        },
      );

      await _loadCacheStats();
      await _refreshLocalStyles();
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prenos koncen'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _cancelDownload() async {
    await _tileCacheService.cancelDownload();
    if (mounted) {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pocisti predpomnilnik?'),
        content: const Text(
          'Vse prenesene ploščice bodo izbrisane. Te operacije ni mogoče razveljaviti.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Prekliči'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Izbriši'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _tileCacheService.clearCache();
      await _loadCacheStats();
      await _refreshLocalStyles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Predpomnilnik izpraznjen')),
        );
      }
    }
  }

  Future<void> _toggleServer() async {
    if (_isServerRunning) {
      await _tileSharingService.stopServer();
    } else {
      await _tileSharingService.startServer();
    }
    if (mounted) {
      setState(() {
        _isServerRunning = _tileSharingService.isRunning;
      });
    }
  }

  Future<void> _deleteStyle(StyleInfo style) async {
    await OfflineTileCacheService.instance.deleteStyle(style.hash);
    await _loadCacheStats();
    await _refreshLocalStyles();
  }

  void _syncStyleFromPeers(PeerCatalog catalog, StyleInfo style) {
    final peers = _peerCatalogs
        .where((entry) => entry.styles.any((candidate) => candidate.hash == style.hash))
        .map((entry) => entry.peer)
        .toList();

    _syncSubscription?.cancel();
    setState(() {
      _isSyncing = true;
      _syncStatus = 'Syncing ${style.displayName}';
      _syncProgress = 0;
    });

    _syncSubscription = _tileSharingService
        .syncStyleFromPeers(peers: peers, styleHash: style.hash, styleMeta: style)
        .listen((event) async {
      if (!mounted) return;
      if (event is PeerSyncStarted) {
        setState(() {
          _syncStatus = 'Syncing ${style.displayName}';
          _syncProgress = event.totalTiles == 0 ? 1 : 0;
        });
      } else if (event is PeerSyncTileDownloaded) {
        setState(() {
          _syncProgress = event.total == 0 ? 1 : event.downloaded / event.total;
          _syncStatus = 'Downloaded ${event.downloaded}/${event.total}';
        });
      } else if (event is PeerSyncTileSkipped) {
        setState(() {
          _syncProgress = event.total == 0 ? 1 : event.skipped / event.total;
          _syncStatus = 'Cached ${event.skipped}/${event.total}';
        });
      } else if (event is PeerSyncComplete) {
        await _loadCacheStats();
        await _refreshLocalStyles();
        setState(() {
          _isSyncing = false;
          _syncProgress = 1;
          _syncStatus =
              'Done! ${event.downloaded} downloaded, ${event.skipped} cached, ${event.failed} failed';
        });
      } else if (event is PeerSyncCancelled) {
        setState(() {
          _isSyncing = false;
          _syncStatus = 'Sync cancelled';
        });
      }
    });
  }

  void _showSharingSheet() {
    _refreshPeerCatalogs();
    _refreshLocalStyles();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void refreshSheet() {
              if (mounted) {
                setState(() {});
              }
              setModalState(() {});
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.3,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: Container(
                        width: 32,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Tile Sharing',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Share my tiles'),
                      subtitle: Text(
                        _isServerRunning
                            ? 'Other devices can fetch tiles from this device'
                            : 'Start serving cached tiles to nearby devices',
                      ),
                      secondary: Icon(
                        _isServerRunning
                            ? Icons.wifi_tethering
                            : Icons.wifi_tethering_off,
                      ),
                      value: _isServerRunning,
                      onChanged: (_) async {
                        await _toggleServer();
                        refreshSheet();
                      },
                    ),
                    if (_localStyles.isNotEmpty) ...[
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'My Cached Maps',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      ..._localStyles.map((style) {
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.map, size: 20),
                          title: Text(style.displayName),
                          subtitle: Text(
                            '${_formatNumber(style.tileCount)} tiles, ${_formatBytes(style.sizeBytes)}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            tooltip: 'Delete',
                            onPressed: () async {
                              await _confirmDeleteStyle(context, style);
                              refreshSheet();
                            },
                          ),
                        );
                      }),
                    ],
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Nearby Devices',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          if (_isFetchingCatalogs)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 20),
                              tooltip: 'Refresh',
                              onPressed: () async {
                                await _refreshPeerCatalogs();
                                refreshSheet();
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 20),
                            tooltip: 'Add peer manually',
                            onPressed: () => _showAddPeerDialog(context, refreshSheet),
                          ),
                        ],
                      ),
                    ),
                    if (_discoveredPeers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No peers found on the local network.\nMake sure other devices have tile sharing enabled.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ..._peerCatalogs.map((catalog) => _buildPeerCard(context, catalog, refreshSheet)),
                    ..._discoveredPeers
                        .where((peer) => !_peerCatalogs.any((catalog) => catalog.peer == peer))
                        .map(
                          (peer) => ListTile(
                            leading: const Icon(Icons.devices),
                            title: Text(peer.ipAddress),
                            subtitle: const Text('Fetching catalog'),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 20),
                              onPressed: () {
                                _tileSharingService.removePeer(peer);
                                refreshSheet();
                              },
                            ),
                          ),
                        ),
                    if (_isSyncing || _syncStatus.isNotEmpty) ...[
                      const Divider(),
                      if (_isSyncing)
                        LinearProgressIndicator(
                          value: _syncProgress > 0 ? _syncProgress : null,
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _syncStatus,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            if (_isSyncing)
                              TextButton(
                                onPressed: () {
                                  _tileSharingService.cancelSync();
                                  refreshSheet();
                                },
                                child: const Text('Cancel'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPeerCard(
    BuildContext context,
    PeerCatalog catalog,
    VoidCallback refreshSheet,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.devices, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    catalog.peer.ipAddress,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  onPressed: () {
                    _tileSharingService.removePeer(catalog.peer);
                    refreshSheet();
                  },
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (catalog.styles.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'No cached tiles on this device',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ),
            ...catalog.styles.map((style) {
              final localMatch =
                  _localStyles.where((localStyle) => localStyle.hash == style.hash);
              final localCount = localMatch.isNotEmpty ? localMatch.first.tileCount : 0;
              final missingTiles = style.tileCount - localCount;

              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.map_outlined, size: 20),
                title: Text(style.displayName),
                subtitle: Text(
                  '${_formatNumber(style.tileCount)} tiles, ${_formatBytes(style.sizeBytes)}'
                  '${localCount > 0 ? ' (you have ${_formatNumber(localCount)})' : ''}',
                ),
                trailing: missingTiles > 0
                    ? TextButton.icon(
                        onPressed: _isSyncing
                            ? null
                            : () {
                                _syncStyleFromPeers(catalog, style);
                                refreshSheet();
                              },
                        icon: const Icon(Icons.download, size: 16),
                        label: Text(
                          missingTiles == style.tileCount
                              ? 'Get all'
                              : '+${_formatNumber(missingTiles)}',
                        ),
                      )
                    : const Icon(Icons.check_circle, color: Colors.green, size: 20),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddPeerDialog(BuildContext context, VoidCallback refreshSheet) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add peer'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'IP Address',
            hintText: '192.168.1.100',
          ),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final ip = controller.text.trim();
              if (ip.isNotEmpty) {
                _tileSharingService.addManualPeer(ip);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    refreshSheet();
  }

  Future<void> _confirmDeleteStyle(BuildContext context, StyleInfo style) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${style.displayName}?'),
        content: Text(
          '${_formatNumber(style.tileCount)} tiles, ${_formatBytes(style.sizeBytes)} will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteStyle(style);
    }
  }

  String _formatNumber(int number) {
    if (number < 1000) return '$number';
    if (number < 1000000) return '${(number / 1000).toStringAsFixed(1)}K';
    return '${(number / 1000000).toStringAsFixed(1)}M';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLayerInfo(),
                  const SizedBox(height: 16),
                  _buildZoomInfo(),
                  const SizedBox(height: 16),
                  _buildTileEstimate(),
                  const SizedBox(height: 24),
                  if (_errorMessage != null) ...[
                    _buildErrorMessage(),
                    const SizedBox(height: 16),
                  ],
                  if (!_canDownload) ...[
                    _buildWmsNotSupportedMessage(),
                  ] else if (_isDownloading) ...[
                    _buildProgressSection(),
                    const SizedBox(height: 16),
                    _buildCancelButton(),
                  ] else ...[
                    _buildDownloadButton(),
                  ],
                  const SizedBox(height: 24),
                  _buildCacheStats(),
                  const SizedBox(height: 8),
                  _buildClearCacheButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Column(
              children: [
                Text(
                  'Prenos kart',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Za delo brez povezave',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: _discoveredPeers.isNotEmpty,
              label: Text('${_discoveredPeers.length}'),
              child: Icon(
                _isServerRunning ? Icons.wifi_tethering : Icons.wifi_tethering_off,
              ),
            ),
            tooltip: _isServerRunning ? 'Sharing tiles' : 'Tile sharing off',
            onPressed: _showSharingSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildLayerInfo() {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: Icon(
          widget.currentLayer.isSlovenian ? Icons.layers : Icons.map,
          color: colorScheme.primary,
        ),
        title: Text('Podlaga', style: TextStyle(color: colorScheme.onSurface)),
        subtitle: Text(
          widget.currentLayer.name,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildZoomInfo() {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: Icon(Icons.zoom_in, color: colorScheme.primary),
        title: Text('Povečava', style: TextStyle(color: colorScheme.onSurface)),
        subtitle: Text(
          '$_minZoom → $_maxZoom',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildTileEstimate() {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: Icon(Icons.grid_view, color: colorScheme.primary),
        title: Text('Ocena', style: TextStyle(color: colorScheme.onSurface)),
        subtitle: Text(
          '~$_estimatedTileCount ploščic',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Prenašam... ${_downloadProgress.toStringAsFixed(1)}%',
          style: const TextStyle(fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: _downloadProgress / 100,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildDownloadButton() {
    return FilledButton.icon(
      onPressed: _startDownload,
      icon: const Icon(Icons.download),
      label: const Text('Prenesi'),
    );
  }

  Widget _buildCancelButton() {
    return OutlinedButton.icon(
      onPressed: _cancelDownload,
      icon: const Icon(Icons.cancel),
      label: const Text('Prekliči'),
      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
    );
  }

  Widget _buildWmsNotSupportedMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 32),
          const SizedBox(height: 12),
          Text(
            'Sloj ni na voljo za prenos',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900),
          ),
          const SizedBox(height: 8),
          Text(
            'Za ta sloj ni bilo mogoče določiti XYZ predloge.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.orange.shade800),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheStats() {
    if (_cacheStats == null || _cacheStats!['initialized'] != true) {
      return const SizedBox.shrink();
    }

    final totalTiles = _cacheStats!['totalTiles'] ?? 0;
    final totalSizeMB = _cacheStats!['totalSizeMB'] ?? '0';
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.surfaceContainerLow,
      child: ListTile(
        leading: Icon(Icons.storage, color: colorScheme.onSurfaceVariant),
        title: Text('Predpomnilnik', style: TextStyle(color: colorScheme.onSurface)),
        subtitle: Text(
          '$totalTiles ploščic ($totalSizeMB MB)',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildClearCacheButton() {
    return TextButton.icon(
      onPressed: _clearCache,
      icon: const Icon(Icons.delete_outline),
      label: const Text('Pocisti predpomnilnik'),
      style: TextButton.styleFrom(foregroundColor: Colors.red),
    );
  }
}
