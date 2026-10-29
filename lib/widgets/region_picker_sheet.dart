import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/parcel_lookup_service.dart';
import 'kataster_share_tile.dart';

/// Draggable sheet for picking offline kataster regions to download, grouped
/// by country. The country matching the app language comes first. Pops with
/// the chosen regions, or null when closed.
class RegionPickerSheet extends StatefulWidget {
  final List<ParcelRegion> regions;
  final ScrollController scrollController;

  const RegionPickerSheet({
    super.key,
    required this.regions,
    required this.scrollController,
  });

  static Future<List<ParcelRegion>?> show(
    BuildContext context,
    List<ParcelRegion> regions,
  ) {
    return showModalBottomSheet<List<ParcelRegion>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 1,
        builder: (context, scrollController) => RegionPickerSheet(
          regions: regions,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  State<RegionPickerSheet> createState() => _RegionPickerSheetState();
}

class _RegionPickerSheetState extends State<RegionPickerSheet> {
  final _selected = <String>{};

  /// Regions per country code, each list sorted by name, countries ordered
  /// with the app language's country first.
  List<MapEntry<String, List<ParcelRegion>>> _groups(BuildContext context) {
    final byCountry = <String, List<ParcelRegion>>{};
    for (final r in widget.regions) {
      byCountry.putIfAbsent(r.country, () => []).add(r);
    }
    for (final list in byCountry.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    final first =
        Localizations.localeOf(context).languageCode == 'hr' ? 'hr' : 'si';
    return byCountry.entries.toList()
      ..sort((a, b) {
        if (a.key == first) return -1;
        if (b.key == first) return 1;
        return a.key.compareTo(b.key);
      });
  }

  String _countryName(BuildContext context, String code) => switch (code) {
        'si' => context.l10n.aboutCountrySi,
        'hr' => context.l10n.aboutCountryHr,
        _ => code.toUpperCase(),
      };

  /// Group digits with dots, e.g. 1354039 -> "1.354.039".
  String _formatCount(int n) {
    final s = n.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final loadedFiles = ParcelLookupService.instance.loadedFiles;
    final selectedBytes = widget.regions
        .where((r) => _selected.contains(r.file))
        .fold<int>(0, (sum, r) => sum + (r.bytes ?? 0));
    final mb = (selectedBytes / (1024 * 1024)).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 4, 8),
          child: Row(
            children: [
              Icon(Icons.cloud_download_outlined, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.aboutPickRegionsTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.l10n.commonCancel,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: CustomScrollView(
            controller: widget.scrollController,
            slivers: [
              for (final group in _groups(context)) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                    child: Text(
                      '${_countryName(context, group.key)} · ${group.value.length}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ),
                SliverList.builder(
                  itemCount: group.value.length,
                  itemBuilder: (context, i) {
                    final region = group.value[i];
                    final loaded = loadedFiles.contains(region.file);
                    return CheckboxListTile(
                      value: _selected.contains(region.file),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(region.file);
                        } else {
                          _selected.remove(region.file);
                        }
                      }),
                      secondary: Icon(
                        loaded ? Icons.check_circle : Icons.map_outlined,
                        color: loaded ? Colors.green : null,
                      ),
                      title: Text(region.name),
                      subtitle: region.sizeMb != null
                          ? Text(
                              '${region.sizeMb!.toStringAsFixed(0)} MB'
                              '${region.rows != null ? context.l10n.aboutRegionParcels(_formatCount(region.rows!)) : ''}'
                              '${loaded ? context.l10n.aboutRegionLoaded : ''}',
                            )
                          : null,
                    );
                  },
                ),
              ],
              // Sharing only makes sense once this phone has regions.
              if (ParcelLookupService.instance.isAvailable) ...[
                const SliverToBoxAdapter(child: Divider(height: 32)),
                const SliverToBoxAdapter(child: KatasterShareTile()),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
            ],
          ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: FilledButton.icon(
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(
                        widget.regions
                            .where((r) => _selected.contains(r.file))
                            .toList(),
                      ),
              icon: const Icon(Icons.cloud_download_outlined),
              label: Text(
                _selected.isEmpty
                    ? context.l10n.commonDownload
                    : context.l10n.aboutDownloadSelected(_selected.length, mb),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
