import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/l10n.dart';
import '../router/route_names.dart';
import '../services/locale_settings.dart';
import '../services/owner_lookup_service.dart';
import '../services/cache_settings.dart';
import '../services/drone_settings.dart';
import '../services/owner_offline_settings_service.dart';
import '../services/parcel_lookup_service.dart';
import '../services/kataster_sharing_service.dart';
import '../services/kataster_update_service.dart';
import '../utils/formats.dart';
import '../services/tile_cache_service.dart';
import '../services/vlake_service.dart';
import '../services/vlake_settings.dart';
import '../widgets/download_progress_view.dart';
import '../widgets/region_picker_sheet.dart';

/// Which offline reference databases a wipe action targets.
enum _WipeScope { all, imported, downloaded }

/// Full-featured About screen with app info, map sources, and legal information
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _packageInfo;

  /// Hidden developer options, revealed by long-pressing the version card.
  bool _showDeveloperOptions = false;

  /// R2-hosted databases.
  static const _dbBaseUrl = ParcelLookupService.r2BaseUrl;
  static const _regionsManifestUrl = ParcelLookupService.regionsManifestUrl;
  static const _ownersDbUrl = '$_dbBaseUrl/owners.sqlite.enc';

  // Offline parcels download progress.
  bool _downloadingParcels = false;
  bool _cancelParcelDownload = false;
  int _parcelReceived = 0;
  int? _parcelTotal;
  String? _parcelDownloadLabel;

  // Owners database download progress.
  bool _downloadingOwners = false;
  bool _cancelOwnerDownload = false;
  int _ownerReceived = 0;
  int? _ownerTotal;


  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    KatasterSharingService.instance.startDiscovery();
    // Rate-limited (weekly) by the service; usually answers from cache.
    KatasterUpdateService.instance.check().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _packageInfo = info);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App name and version (long-press for developer options)
          _buildAppHeader(context, colorScheme),
          const SizedBox(height: 24),

          // Settings first: they are what people come here for.
          _buildSectionTitle(context, context.l10n.aboutSectionGeneral),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildLanguageRow(context, colorScheme),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.school_outlined, color: colorScheme.primary),
                    title: Text(context.l10n.aboutShowIntro),
                    subtitle: Text(context.l10n.aboutShowIntroDesc),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go(AppRoutes.onboarding),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionTitle(context, context.l10n.aboutOfflineKataster),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildParcelsDbSection(context, colorScheme),
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionTitle(context, context.l10n.aboutSectionMapCache),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _buildMapCacheSection(context, colorScheme),
            ),
          ),
          const SizedBox(height: 16),

          if (_showDeveloperOptions) ...[
            _buildSectionTitle(context, context.l10n.aboutDeveloperOptions),
            Card(child: _buildDeveloperOptions(context, colorScheme)),
            const SizedBox(height: 16),
          ],

          // Contact & Support
          _buildSectionTitle(context, context.l10n.aboutSectionSupport),
          _buildSupportCard(context, colorScheme),
          const SizedBox(height: 16),

          // Map sources
          _buildSectionTitle(context, context.l10n.aboutSectionMapSources),
          _buildMapSourcesCard(context, colorScheme),
          const SizedBox(height: 16),

          // Legal texts (collapsed) and open source licenses
          _buildSectionTitle(context, context.l10n.aboutSectionLegal),
          _buildLegalCard(context, colorScheme),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Icon, name, tagline and version in one card. Long-press it to toggle
  /// the hidden developer options.
  Widget _buildAppHeader(BuildContext context, ColorScheme colorScheme) {
    final textTheme = Theme.of(context).textTheme;
    final version = _packageInfo?.version ?? '...';
    final buildNumber = _packageInfo?.buildNumber ?? '...';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onLongPress: () =>
            setState(() => _showDeveloperOptions = !_showDeveloperOptions),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'icon.png',
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gozdar',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.aboutTagline,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${context.l10n.aboutVersion} $version ($buildNumber)',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Inline developer options (owners database import + Vlake), revealed by
  /// long-pressing the version card.
  Widget _buildDeveloperOptions(BuildContext context, ColorScheme colorScheme) {
    final service = OwnerLookupService.instance;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.aboutOwnersDb,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          FutureBuilder<int?>(
            future: service.fileSizeBytes(),
            builder: (context, snapshot) {
              if (!service.isAvailable) {
                return Text(
                  context.l10n.aboutNotImported,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                );
              }
              final size = snapshot.data;
              final sizeLabel = size != null
                  ? ' • ${(size / (1024 * 1024)).toStringAsFixed(1)} MB'
                  : '';
              return Text(
                context.l10n.aboutOwnersCount(_formatCount(service.rowCount), sizeLabel),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          if (_downloadingOwners)
            _buildDbDownloadProgress(
              context,
              colorScheme,
              received: _ownerReceived,
              total: _ownerTotal,
              label: context.l10n.aboutOwnersDownloading,
              onCancel: () => setState(() => _cancelOwnerDownload = true),
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _downloadOwners,
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: Text(
                      service.isAvailable
                          ? context.l10n.aboutOwnersUpdateButton
                          : context.l10n.aboutOwnersDownloadButton,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.outlined(
                  onPressed: _importOwners,
                  icon: const Icon(Icons.file_open),
                  tooltip: context.l10n.aboutImportFromFile,
                ),
                if (service.isAvailable) ...[
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: _removeOwners,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: context.l10n.aboutRemove,
                  ),
                ],
              ],
            ),
          if (service.isAvailable && service.hasGeometry) ...[
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                Icons.location_searching,
                color: colorScheme.primary,
              ),
              title: Text(context.l10n.aboutOfflineOwnerSearch),
              subtitle: Text(
                context.l10n.aboutOfflineOwnerSearchDesc,
              ),
              value: OwnerOfflineSettingsService.instance.enabled,
              onChanged: (v) async {
                await OwnerOfflineSettingsService.instance.setEnabled(v);
                if (mounted) setState(() {});
              },
            ),
          ],

          const Divider(height: 24),
          _buildWipeSection(context, colorScheme),

          const Divider(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(Icons.forest, color: colorScheme.primary),
            title: Text(context.l10n.aboutVlake),
            subtitle: Text(
              context.l10n.aboutVlakeDesc,
            ),
            value: VlakeSettings.instance.enabled,
            onChanged: (v) async {
              await VlakeSettings.instance.setEnabled(v);
              if (v) VlakeService.instance.ensureLoaded();
              if (mounted) setState(() {});
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(Icons.flight, color: colorScheme.primary),
            title: const Text('Dron (eksperimentalno)'),
            subtitle: const Text(
              'Omogoči izvoz načrta poleta (DJI KMZ) za pregled parcele, npr. iskanje sušic.',
            ),
            value: DroneSettings.instance.enabled,
            onChanged: (v) async {
              await DroneSettings.instance.setEnabled(v);
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMapCacheSection(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(Icons.cloud_download_outlined, color: colorScheme.primary),
          title: Text(context.l10n.aboutHttpCache),
          subtitle: Text(
            context.l10n.aboutHttpCacheDesc,
          ),
          value: CacheSettings.instance.httpEnabled,
          onChanged: (v) async {
            await CacheSettings.instance.setHttpEnabled(v);
            if (mounted) setState(() {});
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(Icons.map, color: colorScheme.primary),
          title: Text(context.l10n.aboutTileCache),
          subtitle: Text(
            context.l10n.aboutTileCacheDesc,
          ),
          value: CacheSettings.instance.tileEnabled,
          onChanged: (v) async {
            await CacheSettings.instance.setTileEnabled(v);
            if (mounted) setState(() {});
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _clearFlutterMapCache,
            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
            label: Text(context.l10n.aboutClearMapCache),
          ),
        ),
      ],
    );
  }

  Future<void> _importOwners() async {
    final messenger = ScaffoldMessenger.of(context);
    final file = await FilePicker.pickFile(type: FileType.any);
    final path = file?.path;
    if (path == null) return;

    final lower = path.toLowerCase();
    if (!lower.endsWith('.sqlite') && !lower.endsWith('.db')) {
      messenger.showSnackBar(
        SnackBar(content: Text(L10n.current.aboutPickSqlite)),
      );
      return;
    }

    try {
      final imported = await OwnerLookupService.instance.importFromFile(path);
      if (mounted) setState(() {});
      messenger.showSnackBar(
        SnackBar(
          content: Text(L10n.current.aboutOwnersImported(_formatCount(imported.rows))),
        ),
      );
    } catch (e) {
      final message = e is FormatException ? e.message : L10n.current.aboutImportFailed('$e');
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _removeOwners() async {
    final messenger = ScaffoldMessenger.of(context);
    await OwnerLookupService.instance.remove();
    if (mounted) setState(() {});
    messenger.showSnackBar(
      SnackBar(content: Text(L10n.current.aboutOwnersRemoved)),
    );
  }

  Future<void> _clearFlutterMapCache() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.aboutClearCacheTitle),
        content: Text(context.l10n.aboutClearCacheBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await TileCacheService().clearCache();
      messenger.showSnackBar(
        SnackBar(content: Text(L10n.current.aboutCacheCleared)),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(L10n.current.aboutCacheClearFailed('$e'))),
      );
    }
  }

  /// Offline parcels (kataster) database — when loaded, the cadastral layer is
  /// rendered and identified locally instead of via the online WMS proxy.
  Widget _buildParcelsDbSection(BuildContext context, ColorScheme colorScheme) {
    final service = ParcelLookupService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<int?>(
          future: service.fileSizeBytes(),
          builder: (context, snapshot) {
            if (!service.isAvailable) {
              return Text(
                context.l10n.aboutKatasterNotLoaded,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              );
            }
            final size = snapshot.data;
            final sizeLabel = size != null
                ? ' • ${(size / (1024 * 1024)).toStringAsFixed(0)} MB'
                : '';
            final rawDate = service.dataDate;
            final parsedDate =
                rawDate != null ? DateTime.tryParse(rawDate) : null;
            final dateLabel = rawDate != null
                ? ' • ${parsedDate != null ? Fmt.date(parsedDate) : rawDate}'
                : '';
            final regions = service.loadedRegions;
            final regionLabel = regions.isNotEmpty
                ? '${regions.join(', ')}\n'
                : '';
            return Text(
              context.l10n.aboutParcelsSummary(
              regionLabel,
              _formatCount(service.rowCount),
              sizeLabel,
              dateLabel,
            ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        if (!_downloadingParcels) _buildKatasterUpdateCard(context, colorScheme),
        if (_downloadingParcels)
          _buildDbDownloadProgress(
            context,
            colorScheme,
            received: _parcelReceived,
            total: _parcelTotal,
            label: _parcelDownloadLabel ?? context.l10n.aboutDownloadingRegion,
            onCancel: () => setState(() => _cancelParcelDownload = true),
          )
        else
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _pickAndDownloadRegion,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(
                    service.isAvailable ? context.l10n.aboutAddRegion : context.l10n.aboutDownloadRegion,
                  ),
                ),
              ),
              if (service.isAvailable) ...[
                const SizedBox(width: 12),
                IconButton.outlined(
                  onPressed: _removeParcels,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: context.l10n.aboutRemove,
                ),
              ],
            ],
          ),
        if (!_downloadingParcels && !service.isAvailable) ...[
          const SizedBox(height: 6),
          Text(
            context.l10n.aboutDownloadRegionHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  /// "Newer kataster available" card with a one-tap update of everything that
  /// is outdated on this device (loaded regions + public owners DB).
  Widget _buildKatasterUpdateCard(BuildContext context, ColorScheme colorScheme) {
    final update = KatasterUpdateService.instance.pending;
    if (update == null) return const SizedBox.shrink();
    final parts = <String>[
      if (update.outdatedRegions.isNotEmpty)
        update.outdatedRegions.map((r) => r.name).join(', '),
      if (update.publicOwnersOutdated) L10n.current.aboutPublicOwners,
    ];
    final mb = (update.bytes / (1024 * 1024)).toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.aboutKatasterUpdateAvailable(update.manifest.date ?? ''),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                context.l10n.aboutKatasterOutdated(
                  parts.join(' • '),
                  update.bytes > 0 ? ' • ~$mb MB' : '',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      await KatasterUpdateService.instance.dismiss();
                      if (mounted) setState(() {});
                    },
                    child: Text(context.l10n.updateLater),
                  ),
                  FilledButton.icon(
                    onPressed: () => _applyKatasterUpdate(update),
                    icon: const Icon(Icons.system_update_alt),
                    label: Text(context.l10n.updateNow),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Re-download every outdated region, then the public owners DB, then
  /// re-evaluate so the card disappears once everything is current.
  Future<void> _applyKatasterUpdate(KatasterUpdate update) async {
    final messenger = ScaffoldMessenger.of(context);
    var cancelled = false;
    if (update.outdatedRegions.isNotEmpty) {
      cancelled = await _downloadRegions(update.outdatedRegions);
    }
    if (update.publicOwnersOutdated && !cancelled && mounted) {
      setState(() {
        _downloadingParcels = true;
        _cancelParcelDownload = false;
        _parcelDownloadLabel = L10n.current.aboutPublicOwnersLabel;
        _parcelReceived = 0;
        _parcelTotal = update.manifest.publicOwnersBytes;
      });
      try {
        final ok = await OwnerLookupService.instance.refreshPublic(
          isCancelled: () => _cancelParcelDownload,
          onProgress: (received, total) {
            if (!mounted) return;
            if (received - _parcelReceived >= 4 * 1024 * 1024 ||
                (total != null && received >= total)) {
              setState(() {
                _parcelReceived = received;
                _parcelTotal = total ?? update.manifest.publicOwnersBytes;
              });
            }
          },
        );
        if (!ok && !_cancelParcelDownload) {
          messenger.showSnackBar(
            SnackBar(content: Text(L10n.current.aboutPublicOwnersFailed)),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _downloadingParcels = false;
            _cancelParcelDownload = false;
          });
        }
      }
    }
    KatasterUpdateService.instance.recompute();
    if (mounted) setState(() {});
  }

  /// Fetch the region manifest, let the user pick one or more regions, then
  /// download them all in sequence.
  Future<void> _pickAndDownloadRegion() async {
    final messenger = ScaffoldMessenger.of(context);
    List<ParcelRegion> regions;
    try {
      regions = await ParcelLookupService.fetchRegions(_regionsManifestUrl);
    } catch (e) {
      final message = e is FormatException ? e.message : L10n.current.aboutErrorWithDetail('$e');
      messenger.showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    if (!mounted || regions.isEmpty) return;
    final chosen = await RegionPickerSheet.show(context, regions);
    if (chosen != null && chosen.isNotEmpty) {
      await _downloadRegions(chosen);
    }
  }

  /// Returns true when the user cancelled part-way.
  Future<bool> _downloadRegions(List<ParcelRegion> regions) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _downloadingParcels = true;
      _cancelParcelDownload = false;
      _parcelReceived = 0;
      _parcelTotal = null;
    });
    var done = 0;
    final failures = <String>[];
    try {
      for (var i = 0; i < regions.length; i++) {
        if (_cancelParcelDownload) break;
        final region = regions[i];
        setState(() {
          _parcelDownloadLabel = L10n.current.aboutRegionProgress(region.name, i + 1, regions.length);
          _parcelReceived = 0;
          _parcelTotal = region.bytes;
        });
        try {
          await ParcelLookupService.instance.downloadAndOpen(
            '$_dbBaseUrl/${region.file}',
            fileName: region.file,
            onProgress: (received, total) {
              if (!mounted) return;
              if (received - _parcelReceived >= 4 * 1024 * 1024 ||
                  (total != null && received >= total)) {
                setState(() {
                  _parcelReceived = received;
                  _parcelTotal = total ?? region.bytes;
                });
              }
            },
            isCancelled: () => _cancelParcelDownload,
          );
          OwnerLookupService.instance.initPublicHr().ignore();
          done++;
        } on ParcelDownloadCancelled {
          break;
        } catch (e) {
          failures.add(region.name);
        }
      }
      if (mounted) setState(() {});
      final msg = StringBuffer(L10n.current.aboutRegionsDownloaded(done));
      if (failures.isNotEmpty) {
        msg.write(L10n.current.aboutRegionsFailed(failures.join(', ')));
      }
      messenger.showSnackBar(SnackBar(content: Text(msg.toString())));
      return _cancelParcelDownload;
    } finally {
      if (mounted) {
        setState(() {
          _downloadingParcels = false;
          _cancelParcelDownload = false;
        });
      }
    }
  }

  /// Shared download-progress row (bar + MB/percent + cancel) used by the
  /// parcels and owners database sections.
  Widget _buildDbDownloadProgress(
    BuildContext context,
    ColorScheme colorScheme, {
    required int received,
    required int? total,
    required String label,
    required VoidCallback onCancel,
  }) {
    return DownloadProgressView(
      title: label,
      received: received,
      total: total,
      onCancel: onCancel,
    );
  }

  /// Prompt for a password (obscured). Returns null if cancelled.
  Future<String?> _promptPassword(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.l10n.aboutPasswordLabel,
            prefixIcon: const Icon(Icons.lock_outline),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(context.l10n.aboutUnlock),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadOwners() async {
    final messenger = ScaffoldMessenger.of(context);
    // The owners DB is AES-encrypted in transit; ask for the password to
    // decrypt it as it streams in.
    final password = await _promptPassword(context.l10n.aboutOwnersPasswordTitle);
    if (password == null || password.isEmpty) return;
    setState(() {
      _downloadingOwners = true;
      _cancelOwnerDownload = false;
      _ownerReceived = 0;
      _ownerTotal = null;
    });
    try {
      final result = await OwnerLookupService.instance.downloadAndOpen(
        _ownersDbUrl,
        password: password,
        onProgress: (received, total) {
          if (!mounted) return;
          if (received - _ownerReceived >= 4 * 1024 * 1024 ||
              (total != null && received >= total)) {
            setState(() {
              _ownerReceived = received;
              _ownerTotal = total;
            });
          }
        },
        isCancelled: () => _cancelOwnerDownload,
      );
      if (mounted) setState(() {});
      messenger.showSnackBar(
        SnackBar(
          content: Text(L10n.current.aboutOwnersDownloaded(_formatCount(result.rows))),
        ),
      );
    } on OwnerDownloadCancelled {
      messenger.showSnackBar(
        SnackBar(content: Text(L10n.current.aboutDownloadCancelled)),
      );
    } catch (e) {
      final message = e is FormatException ? e.message : L10n.current.aboutDownloadFailed('$e');
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _downloadingOwners = false;
          _cancelOwnerDownload = false;
        });
      }
    }
  }

  Future<void> _removeParcels() async {
    final messenger = ScaffoldMessenger.of(context);
    await ParcelLookupService.instance.removeAll();
    if (mounted) setState(() {});
    messenger.showSnackBar(
      SnackBar(content: Text(L10n.current.aboutParcelsRemoved)),
    );
  }

  /// Wipe the offline reference databases (owners + parcels) by how they were
  /// obtained. Does NOT touch the user's own parcels/logs (ObjectBox).
  Widget _buildWipeSection(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.aboutWipeSection,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _wipeData(_WipeScope.imported),
              icon: const Icon(Icons.file_open_outlined, size: 18),
              label: Text(context.l10n.aboutWipeImported),
            ),
            OutlinedButton.icon(
              onPressed: () => _wipeData(_WipeScope.downloaded),
              icon: const Icon(Icons.cloud_off_outlined, size: 18),
              label: Text(context.l10n.aboutWipeDownloaded),
            ),
            OutlinedButton.icon(
              onPressed: () => _wipeData(_WipeScope.all),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
              ),
              icon: const Icon(Icons.delete_forever, size: 18),
              label: Text(context.l10n.aboutWipeAll),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _wipeData(_WipeScope scope) async {
    final messenger = ScaffoldMessenger.of(context);
    final label = switch (scope) {
      _WipeScope.all => context.l10n.aboutWipeScopeAll,
      _WipeScope.imported => context.l10n.aboutWipeScopeImported,
      _WipeScope.downloaded => context.l10n.aboutWipeScopeDownloaded,
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.aboutWipeTitle),
        content: Text(context.l10n.aboutWipeConfirm(label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.aboutWipeButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final onlySource = switch (scope) {
      _WipeScope.all => null,
      _WipeScope.imported => 'imported',
      _WipeScope.downloaded => 'downloaded',
    };
    bool ownerMatches(String? src) => onlySource == null || src == onlySource;

    var removed = 0;
    final owners = OwnerLookupService.instance;
    final parcels = ParcelLookupService.instance;
    if (owners.isAvailable && ownerMatches(owners.source)) {
      await owners.remove();
      removed++;
    }
    // Parcels can hold multiple region databases — remove those matching.
    removed += await parcels.removeBySource(onlySource);
    if (mounted) setState(() {});
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          removed == 0
              ? L10n.current.aboutWipeNone
              : L10n.current.aboutWipeDone(removed),
        ),
      ),
    );
  }

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

  /// Language selector: follow the device, or force Slovenian / Croatian.
  Widget _buildLanguageRow(BuildContext context, ColorScheme colorScheme) {
    return ListenableBuilder(
      listenable: LocaleSettings.instance,
      builder: (context, _) {
        final code = LocaleSettings.instance.override?.languageCode;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.language, color: colorScheme.primary),
          title: Text(context.l10n.aboutLanguage),
          trailing: DropdownButton<String>(
            value: (code == 'sl' || code == 'hr') ? code : 'auto',
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(
                value: 'auto',
                child: Text(context.l10n.aboutLanguageAuto),
              ),
              const DropdownMenuItem(value: 'sl', child: Text('Slovenščina')),
              const DropdownMenuItem(value: 'hr', child: Text('Hrvatski')),
            ],
            onChanged: (v) => LocaleSettings.instance.setOverride(
              (v == null || v == 'auto') ? null : Locale(v),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildMapSourcesCard(BuildContext context, ColorScheme colorScheme) {
    // Croatian users see their own source (DGU) first.
    final isCroatian = context.l10n.localeName == 'hr';
    final dgu = _buildMapSourceItem(
      context,
      'Državna geodetska uprava RH (DGU)',
      context.l10n.aboutSrcDguDesc,
      'https://oss.uredjenazemlja.hr',
      Icons.badge_outlined,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCroatian) ...[dgu, const Divider(height: 24)],
            _buildMapSourceItem(
              context,
              'Zavod za gozdove Slovenije (ZGS)',
              context.l10n.aboutSrcZgsDesc,
              'https://prostor.zgs.gov.si',
              Icons.park,
            ),
            const Divider(height: 24),
            _buildMapSourceItem(
              context,
              'Geodetska uprava RS (GURS)',
              context.l10n.aboutSrcGursDesc,
              'https://www.e-prostor.gov.si',
              Icons.map,
            ),
            if (!isCroatian) ...[
              const Divider(height: 24),
              dgu,
            ],
            const Divider(height: 24),
            _buildMapSourceItem(
              context,
              'OpenStreetMap',
              context.l10n.aboutSrcOsmDesc,
              'https://www.openstreetmap.org',
              Icons.public,
            ),
            const Divider(height: 24),
            _buildMapSourceItem(
              context,
              'Topo LIDAR + OSM',
              context.l10n.aboutSrcTopoDesc,
              'https://mapy.cz',
              Icons.terrain,
            ),
            const Divider(height: 24),
            _buildMapSourceItem(
              context,
              'ESRI',
              context.l10n.aboutSrcEsriDesc,
              'https://www.esri.com',
              Icons.satellite_alt,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSourceItem(
    BuildContext context,
    String name,
    String description,
    String url,
    IconData icon,
  ) {
    return InkWell(
      onTap: () => _launchUrl(url),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalCard(BuildContext context, ColorScheme colorScheme) {
    Widget legalTile(IconData icon, String title, String body) {
      return ExpansionTile(
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(title),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedAlignment: Alignment.centerLeft,
        children: [
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          legalTile(
            Icons.description_outlined,
            context.l10n.aboutTermsTitle,
            context.l10n.aboutTermsBody,
          ),
          const Divider(height: 1),
          legalTile(
            Icons.warning_amber_outlined,
            context.l10n.aboutDisclaimerTitle,
            context.l10n.aboutDisclaimerBody,
          ),
          const Divider(height: 1),
          legalTile(
            Icons.copyright,
            context.l10n.aboutCopyrightTitle,
            context.l10n.aboutCopyrightBody,
          ),
          const Divider(height: 1),
          legalTile(
            Icons.privacy_tip_outlined,
            context.l10n.aboutPrivacyTitle,
            context.l10n.aboutPrivacyBody,
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.code, color: colorScheme.primary),
            title: Text(context.l10n.aboutShowLicenses),
            subtitle: Text(context.l10n.aboutLicensesDesc),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'Gozdar',
                applicationVersion: _packageInfo?.version,
                applicationIcon: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'icon.png',
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard(BuildContext context, ColorScheme colorScheme) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.bug_report, color: colorScheme.primary),
            title: Text(context.l10n.aboutReportBug),
            subtitle: const Text('GitHub Issues'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _launchUrl('https://github.com/dz0ny/gozdar/issues'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.email, color: colorScheme.primary),
            title: Text(context.l10n.aboutContact),
            subtitle: Text(context.l10n.aboutContactDesc),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _launchUrl('mailto:gozdar@dz0ny.dev'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.star, color: colorScheme.primary),
            title: Text(context.l10n.aboutSourceCode),
            subtitle: Text(context.l10n.aboutSourceCodeDesc),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _launchUrl('https://github.com/dz0ny/gozdar'),
          ),
        ],
      ),
    );
  }
}
