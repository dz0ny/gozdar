import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/parcel.dart';
import '../providers/map_provider.dart';
import '../services/cadastral_service.dart';
import '../services/database_service.dart';
import '../services/owner_lookup_service.dart';
import '../widgets/owner_hit_tile.dart';
import '../widgets/owner_search_controller.dart';
import '../widgets/owner_search_panel.dart';
import '../widgets/parcel_map_preview.dart';

enum _ImportState { idle, importing, imported, exists, notFound, error }

/// Search the imported GURS owners database by name and/or address, then import
/// the cadastral parcel (KO + parcela) for any result into "Moj gozd".
class OwnerImportSearchScreen extends StatefulWidget {
  const OwnerImportSearchScreen({super.key});

  @override
  State<OwnerImportSearchScreen> createState() =>
      _OwnerImportSearchScreenState();
}

class _OwnerImportSearchScreenState extends State<OwnerImportSearchScreen> {
  final _search = OwnerSearchController();
  final _databaseService = DatabaseService();
  final _cadastralService = CadastralService();

  final Map<String, _ImportState> _status = {};

  /// Key of the hit whose geometry is currently being fetched for preview.
  String? _previewingKey;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _key(OwnerSearchHit h) => '${h.sifko}/${h.parcela}';

  Future<void> _import(OwnerSearchHit hit, {WfsParcel? prefetched}) async {
    final key = _key(hit);
    setState(() => _status[key] = _ImportState.importing);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Already imported?
      final existing = await _databaseService.findParcelByKoAndNumber(
        hit.sifko,
        hit.parcela,
      );
      if (existing != null) {
        if (!mounted) return;
        setState(() => _status[key] = _ImportState.exists);
        messenger.showSnackBar(
          SnackBar(content: Text('Parcela ${hit.parcela} je že uvožena.')),
        );
        return;
      }

      // Fetch geometry from the cadastral WFS (owners DB has no geometry),
      // unless the preview already fetched it.
      final wfs =
          prefetched ??
          await _cadastralService.queryParcelByKoAndNumber(
            hit.sifko.toString(),
            hit.parcela,
          );
      if (wfs == null || wfs.polygon.isEmpty) {
        if (!mounted) return;
        setState(() => _status[key] = _ImportState.notFound);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Geometrije za ${hit.parcela} ni bilo mogoče najti.'),
          ),
        );
        return;
      }

      final parcel = Parcel(
        name: '${hit.sifko} - ${hit.parcela}',
        polygon: wfs.polygon,
        cadastralMunicipality: hit.sifko,
        parcelNumber: hit.parcela,
        owner: hit.owner,
        createdAt: DateTime.now(),
      );
      await _databaseService.insertParcel(parcel);
      if (mounted) {
        context.read<MapProvider>().loadParcels();
      }

      if (!mounted) return;
      setState(() => _status[key] = _ImportState.imported);
      messenger.showSnackBar(
        SnackBar(content: Text('Uvožena parcela ${hit.parcela}.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _status[key] = _ImportState.error);
      messenger.showSnackBar(SnackBar(content: Text('Uvoz ni uspel: $e')));
    }
  }

  /// Fetch the parcel geometry from the cadastral WFS and show a map preview
  /// of its outline, from which the parcel can be imported.
  Future<void> _previewHit(OwnerSearchHit hit) async {
    setState(() => _previewingKey = _key(hit));
    final messenger = ScaffoldMessenger.of(context);
    try {
      final wfs = await _cadastralService.queryParcelByKoAndNumber(
        hit.sifko.toString(),
        hit.parcela,
      );
      if (!mounted) return;
      setState(() => _previewingKey = null);
      if (wfs == null || wfs.polygon.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Geometrije za ${hit.parcela} ni bilo mogoče najti.'),
          ),
        );
        return;
      }
      await _showPreviewSheet(hit, wfs);
    } catch (e) {
      if (!mounted) return;
      setState(() => _previewingKey = null);
      messenger.showSnackBar(SnackBar(content: Text('Napaka pri iskanju: $e')));
    }
  }

  Future<void> _showPreviewSheet(OwnerSearchHit hit, WfsParcel wfs) {
    final mapProvider = context.read<MapProvider>();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      // Near-fullscreen sheet so the embedded map is large and pannable. The
      // map captures pan/zoom gestures; drag-to-dismiss works on the header.
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        final imported = _status[_key(hit)] == _ImportState.imported;
        return SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.9,
          child: Column(
            children: [
              // Drag handle.
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KO ${hit.koLabel} • Parcela ${hit.parcela}',
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(hit.owners.join('\n')),
                    if (hit.address != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        hit.address!,
                        style: Theme.of(sheetContext).textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Interactive map fills the remaining height.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ParcelMapPreview(
                    polygon: wfs.polygon,
                    baseLayer: mapProvider.currentBaseLayer,
                    activeOverlays: mapProvider.activeOverlays,
                    workerUrl: mapProvider.workerUrl,
                    outlineColor: cs.primary,
                    interactive: true,
                    fill: true,
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: imported
                          ? null
                          : () {
                              Navigator.of(sheetContext).pop();
                              _import(hit, prefetched: wfs);
                            },
                      icon: Icon(imported ? Icons.check : Icons.download),
                      label: Text(
                        imported ? 'Že uvožena' : 'Uvozi v Moj gozd',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _trailingFor(OwnerSearchHit hit) {
    final state = _status[_key(hit)] ?? _ImportState.idle;
    switch (state) {
      case _ImportState.importing:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case _ImportState.imported:
        return const Icon(Icons.check_circle, color: Colors.green);
      case _ImportState.exists:
        return Icon(
          Icons.library_add_check,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
      case _ImportState.notFound:
      case _ImportState.error:
        return IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Poskusi znova',
          onPressed: () => _import(hit),
        );
      case _ImportState.idle:
        return IconButton(
          icon: const Icon(Icons.download),
          tooltip: 'Uvozi parcelo',
          onPressed: () => _import(hit),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uvoz po lastniku')),
      body: OwnerSearchPanel(
        controller: _search,
        itemBuilder: (context, hit) {
          final previewing = _previewingKey == _key(hit);
          return OwnerHitTile(
            hit: hit,
            trailing: previewing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _trailingFor(hit),
            // Tap a result to fetch its geometry and preview the parcel outline.
            onTap: _previewingKey != null ? null : () => _previewHit(hit),
          );
        },
      ),
    );
  }
}
