import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/map_layer.dart';
import '../services/tile_cache_service.dart';

/// Dialog for downloading map tiles for offline use
/// Shows download progress and cache statistics
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

  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _errorMessage;
  Map<String, dynamic>? _cacheStats;

  int get _minZoom => widget.currentZoom.clamp(1, widget.currentLayer.maxZoom).toInt();
  int get _maxZoom => widget.currentLayer.maxZoom.toInt();

  @override
  void initState() {
    super.initState();
    _loadCacheStats();
  }

  Future<void> _loadCacheStats() async {
    final stats = await _tileCacheService.getStats();
    if (mounted) {
      setState(() {
        _cacheStats = stats;
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

  /// WMS layers use {bbox} placeholder which flutter_map_tile_caching doesn't support.
  /// Only XYZ tile layers with {x}, {y}, {z} placeholders can be cached offline.
  bool get _canDownload => !widget.currentLayer.isWms;

  String? get _urlTemplate {
    if (widget.currentLayer.isWms) {
      // WMS layers cannot be downloaded - they use {bbox} which is not supported
      return null;
    }
    return widget.currentLayer.urlTemplate;
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
        isSlovenian: widget.currentLayer.isWms,
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

      if (mounted) {
        await _loadCacheStats();
        setState(() {
          _isDownloading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Prenos koncen'),
              backgroundColor: Colors.green,
            ),
          );
        }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Predpomnilnik izpraznjen'),
          ),
        );
      }
    }
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Za delo brez povezave',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildLayerInfo() {
    return Card(
      child: ListTile(
        leading: Icon(
          widget.currentLayer.isWms ? Icons.layers : Icons.map,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Podlaga'),
        subtitle: Text(widget.currentLayer.name),
      ),
    );
  }

  Widget _buildZoomInfo() {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.zoom_in,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Povečava'),
        subtitle: Text('$_minZoom → $_maxZoom'),
      ),
    );
  }

  Widget _buildTileEstimate() {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.grid_view,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Ocena'),
        subtitle: Text('~$_estimatedTileCount ploščic'),
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
            'WMS sloji ne podpirajo prenosa',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Izberite ploščično podlago (npr. OSM, TopoMap, ESRI) za prenos kart brez povezave.',
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

    return Card(
      color: Colors.grey.shade100,
      child: ListTile(
        leading: const Icon(Icons.storage, color: Colors.grey),
        title: const Text('Predpomnilnik'),
        subtitle: Text('$totalTiles ploščic ($totalSizeMB MB)'),
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
