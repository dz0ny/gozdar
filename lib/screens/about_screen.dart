import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/owner_lookup_service.dart';
import '../services/cache_settings.dart';
import '../services/owner_offline_settings_service.dart';
import '../services/parcel_lookup_service.dart';
import '../services/kataster_sharing_service.dart';
import '../services/tile_cache_service.dart';
import '../services/vlake_service.dart';
import '../services/vlake_settings.dart';

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
  String _parcelDownloadLabel = 'Prenašam regijo…';

  // Owners database download progress.
  bool _downloadingOwners = false;
  bool _cancelOwnerDownload = false;
  int _ownerReceived = 0;
  int? _ownerTotal;

  StreamSubscription<Set<KatasterPeer>>? _katasterPeersSubscription;
  bool _sharingKataster = false;
  int _katasterPeerCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _sharingKataster = KatasterSharingService.instance.isSharing;
    _katasterPeerCount = KatasterSharingService.instance.peers.length;
    _katasterPeersSubscription = KatasterSharingService.instance.peersStream
        .listen((peers) {
          if (mounted) setState(() => _katasterPeerCount = peers.length);
        });
    KatasterSharingService.instance.startDiscovery();
  }

  @override
  void dispose() {
    _katasterPeersSubscription?.cancel();
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
      appBar: AppBar(title: const Text('O aplikaciji')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App header
          _buildAppHeader(context, colorScheme),
          const SizedBox(height: 24),

          // Version info
          _buildVersionCard(context, colorScheme),
          const SizedBox(height: 16),

          // Settings
          _buildSectionTitle(context, 'Nastavitve'),
          _buildSettingsCard(context, colorScheme),
          const SizedBox(height: 16),

          // Map sources
          _buildSectionTitle(context, 'Viri kartografskih podatkov'),
          _buildMapSourcesCard(context, colorScheme),
          const SizedBox(height: 16),

          // Legal section
          _buildSectionTitle(context, 'Pravne informacije'),
          _buildLegalCard(context, colorScheme),
          const SizedBox(height: 16),

          // Open source libraries
          _buildSectionTitle(context, 'Odprtokodne knjižnice'),
          _buildOpenSourceCard(context, colorScheme),
          const SizedBox(height: 16),

          // Contact & Support
          _buildSectionTitle(context, 'Podpora'),
          _buildSupportCard(context, colorScheme),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAppHeader(BuildContext context, ColorScheme colorScheme) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'icon.png',
              width: 96,
              height: 96,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Gozdar',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Aplikacija za lastnike gozdov in gozdarske delavce v Sloveniji',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildVersionCard(BuildContext context, ColorScheme colorScheme) {
    final version = _packageInfo?.version ?? '...';
    final buildNumber = _packageInfo?.buildNumber ?? '...';

    return GestureDetector(
      // Hidden developer options: long-press the version card to reveal them
      // inline in the settings card below.
      onLongPress: () =>
          setState(() => _showDeveloperOptions = !_showDeveloperOptions),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Informacije o aplikaciji',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildInfoRow('Verzija', version),
              _buildInfoRow('Številka gradnje', buildNumber),
              _buildInfoRow('Paket', _packageInfo?.packageName ?? '...'),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.developer_mode, color: colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                'Razvijalske moznosti',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Baza lastnikov (kataster)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          FutureBuilder<int?>(
            future: service.fileSizeBytes(),
            builder: (context, snapshot) {
              if (!service.isAvailable) {
                return Text(
                  'Ni uvozena.',
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
                '${_formatCount(service.rowCount)} lastnikov$sizeLabel',
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
              label: 'Prenašam bazo lastnikov…',
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
                          ? 'Posodobi (~300 MB)'
                          : 'Prenesi (~300 MB)',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.outlined(
                  onPressed: _importOwners,
                  icon: const Icon(Icons.file_open),
                  tooltip: 'Uvozi iz datoteke (.sqlite)',
                ),
                if (service.isAvailable) ...[
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: _removeOwners,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Odstrani',
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
              title: const Text('Iskanje lastnika brez povezave'),
              subtitle: const Text(
                'Ko ni povezave, določi lastnika iz približnih mej parcel (lokalna baza).',
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
            title: const Text('Vlake (gozdne vlake)'),
            subtitle: const Text(
              'Omogoči sloj — prikaže se v izbiri slojev (Infrastruktura)',
            ),
            value: VlakeSettings.instance.enabled,
            onChanged: (v) async {
              await VlakeSettings.instance.setEnabled(v);
              if (v) VlakeService.instance.ensureLoaded();
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
          secondary: Icon(Icons.http, color: colorScheme.primary),
          title: const Text('Predpomnilnik HTTP'),
          subtitle: const Text(
            'Predpomni odgovore državnih API-jev (prostor.zgs.gov.si).',
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
          title: const Text('Predpomnilnik ploščic'),
          subtitle: const Text(
            'Predpomni karte (ločeno od HTTP predpomnilnika).',
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
            label: const Text('Počisti predpomnilnik karte'),
          ),
        ),
      ],
    );
  }

  Future<void> _importOwners() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.pickFiles(type: FileType.any);
    final path = result?.files.single.path;
    if (path == null) return;

    final lower = path.toLowerCase();
    if (!lower.endsWith('.sqlite') && !lower.endsWith('.db')) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Izberi datoteko .sqlite.')),
      );
      return;
    }

    try {
      final imported = await OwnerLookupService.instance.importFromFile(path);
      if (mounted) setState(() {});
      messenger.showSnackBar(
        SnackBar(
          content: Text('Uvozenih ${_formatCount(imported.rows)} lastnikov.'),
        ),
      );
    } catch (e) {
      final message = e is FormatException ? e.message : 'Uvoz ni uspel: $e';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _removeOwners() async {
    final messenger = ScaffoldMessenger.of(context);
    await OwnerLookupService.instance.remove();
    if (mounted) setState(() {});
    messenger.showSnackBar(
      const SnackBar(content: Text('Baza lastnikov odstranjena.')),
    );
  }

  Future<void> _clearFlutterMapCache() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await TileCacheService().clearFlutterMapCache();
      messenger.showSnackBar(
        const SnackBar(content: Text('Predpomnilnik karte počiščen.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Brisanje predpomnilnika ni uspelo: $e')),
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
        Text(
          'Offline kataster (parcele)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        FutureBuilder<int?>(
          future: service.fileSizeBytes(),
          builder: (context, snapshot) {
            if (!service.isAvailable) {
              return Text(
                'Ni naložena — kataster se prikazuje prek spleta.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              );
            }
            final size = snapshot.data;
            final sizeLabel = size != null
                ? ' • ${(size / (1024 * 1024)).toStringAsFixed(0)} MB'
                : '';
            final dateLabel = service.dataDate != null
                ? ' • ${service.dataDate}'
                : '';
            final regions = service.loadedRegions;
            final regionLabel = regions.isNotEmpty
                ? '${regions.join(', ')}\n'
                : '';
            return Text(
              '$regionLabel${_formatCount(service.rowCount)} parcel'
              '$sizeLabel$dateLabel • brez spleta',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        if (_downloadingParcels)
          _buildDbDownloadProgress(
            context,
            colorScheme,
            received: _parcelReceived,
            total: _parcelTotal,
            label: _parcelDownloadLabel,
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
                    service.isAvailable ? 'Dodaj regijo' : 'Prenesi regijo',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.outlined(
                onPressed: _importParcels,
                icon: const Icon(Icons.file_open),
                tooltip: 'Uvozi iz datoteke (.sqlite)',
              ),
              if (service.isAvailable) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: _removeParcels,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Odstrani',
                ),
              ],
            ],
          ),
        if (!_downloadingParcels && !service.isAvailable) ...[
          const SizedBox(height: 6),
          Text(
            'Prenesi le svojo statistično regijo — priporočena povezava Wi-Fi.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const Divider(height: 24),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(Icons.lan, color: colorScheme.primary),
          title: const Text('Deli offline kataster'),
          subtitle: Text(
            _sharingKataster
                ? 'Na voljo v lokalnem omrežju • najdenih naprav: $_katasterPeerCount'
                : 'Dovoli drugim napravam v istem omrežju prenos naloženih regij.',
          ),
          value: _sharingKataster,
          onChanged: (enabled) async {
            if (enabled) {
              await KatasterSharingService.instance.startSharing();
            } else {
              await KatasterSharingService.instance.stopSharing();
            }
            if (mounted) {
              setState(() {
                _sharingKataster = KatasterSharingService.instance.isSharing;
              });
            }
          },
        ),
      ],
    );
  }

  /// Fetch the region manifest, let the user pick one or more regions, then
  /// download them all in sequence.
  Future<void> _pickAndDownloadRegion() async {
    final messenger = ScaffoldMessenger.of(context);
    List<ParcelRegion> regions;
    try {
      regions = await ParcelLookupService.fetchRegions(_regionsManifestUrl);
    } catch (e) {
      final message = e is FormatException ? e.message : 'Napaka: $e';
      messenger.showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    if (!mounted || regions.isEmpty) return;
    regions.sort((a, b) => a.name.compareTo(b.name));

    final chosen = await showModalBottomSheet<List<ParcelRegion>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final selected = <String>{};
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final loadedFiles = ParcelLookupService.instance.loadedFiles;
            final selectedBytes = regions
                .where((r) => selected.contains(r.file))
                .fold<int>(0, (sum, r) => sum + (r.bytes ?? 0));
            final mb = (selectedBytes / (1024 * 1024)).toStringAsFixed(0);
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Izberi statistične regije',
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final region in regions)
                          CheckboxListTile(
                            value: selected.contains(region.file),
                            onChanged: (v) => setSheetState(() {
                              if (v == true) {
                                selected.add(region.file);
                              } else {
                                selected.remove(region.file);
                              }
                            }),
                            secondary: Icon(
                              loadedFiles.contains(region.file)
                                  ? Icons.check_circle
                                  : Icons.map_outlined,
                              color: loadedFiles.contains(region.file)
                                  ? Colors.green
                                  : null,
                            ),
                            title: Text(region.name),
                            subtitle: region.sizeMb != null
                                ? Text(
                                    '${region.sizeMb!.toStringAsFixed(0)} MB'
                                    '${region.rows != null ? ' • ${_formatCount(region.rows!)} parcel' : ''}'
                                    '${loadedFiles.contains(region.file) ? ' • naloženo' : ''}',
                                  )
                                : null,
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: selected.isEmpty
                            ? null
                            : () => Navigator.of(sheetContext).pop(
                                regions
                                    .where((r) => selected.contains(r.file))
                                    .toList(),
                              ),
                        icon: const Icon(Icons.cloud_download_outlined),
                        label: Text(
                          selected.isEmpty
                              ? 'Prenesi'
                              : 'Prenesi ${selected.length} (~$mb MB)',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (chosen != null && chosen.isNotEmpty) {
      await _downloadRegions(chosen);
    }
  }

  Future<void> _downloadRegions(List<ParcelRegion> regions) async {
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
          _parcelDownloadLabel = '${region.name} (${i + 1}/${regions.length})…';
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
          done++;
        } on ParcelDownloadCancelled {
          break;
        } catch (e) {
          failures.add(region.name);
        }
      }
      if (mounted) setState(() {});
      final msg = StringBuffer('Prenesenih regij: $done.');
      if (failures.isNotEmpty) msg.write(' Neuspešno: ${failures.join(', ')}.');
      messenger.showSnackBar(SnackBar(content: Text(msg.toString())));
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
    final pct = (total != null && total > 0) ? received / total : null;
    final mb = received / (1024 * 1024);
    final totalMb = total != null ? total / (1024 * 1024) : null;
    final sizes = totalMb != null
        ? '${mb.toStringAsFixed(0)} / ${totalMb.toStringAsFixed(0)} MB'
        : '${mb.toStringAsFixed(0)} MB';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: pct),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                '$label $sizes'
                '${pct != null ? ' • ${(pct * 100).toStringAsFixed(0)}%' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(onPressed: onCancel, child: const Text('Prekliči')),
          ],
        ),
      ],
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
          decoration: const InputDecoration(
            labelText: 'Geslo',
            prefixIcon: Icon(Icons.lock_outline),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Prekliči'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Odkleni'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadOwners() async {
    final messenger = ScaffoldMessenger.of(context);
    // The owners DB is AES-encrypted in transit; ask for the password to
    // decrypt it as it streams in.
    final password = await _promptPassword('Geslo za bazo lastnikov');
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
          content: Text('Prenesenih ${_formatCount(result.rows)} lastnikov.'),
        ),
      );
    } on OwnerDownloadCancelled {
      messenger.showSnackBar(
        const SnackBar(content: Text('Prenos preklican.')),
      );
    } catch (e) {
      final message = e is FormatException ? e.message : 'Prenos ni uspel: $e';
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

  Future<void> _importParcels() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.pickFiles(type: FileType.any);
    final path = result?.files.single.path;
    if (path == null) return;

    final lower = path.toLowerCase();
    if (!lower.endsWith('.sqlite') && !lower.endsWith('.db')) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Izberi datoteko .sqlite.')),
      );
      return;
    }

    try {
      final imported = await ParcelLookupService.instance.importFromFile(path);
      if (mounted) setState(() {});
      messenger.showSnackBar(
        SnackBar(
          content: Text('Uvoženih ${_formatCount(imported.rows)} parcel.'),
        ),
      );
    } catch (e) {
      final message = e is FormatException ? e.message : 'Uvoz ni uspel: $e';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _removeParcels() async {
    final messenger = ScaffoldMessenger.of(context);
    await ParcelLookupService.instance.removeAll();
    if (mounted) setState(() {});
    messenger.showSnackBar(
      const SnackBar(content: Text('Baze parcel odstranjene.')),
    );
  }

  /// Wipe the offline reference databases (owners + parcels) by how they were
  /// obtained. Does NOT touch the user's own parcels/logs (ObjectBox).
  Widget _buildWipeSection(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pobriši podatke (baze parcel + lastnikov)',
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
              label: const Text('Uvožene'),
            ),
            OutlinedButton.icon(
              onPressed: () => _wipeData(_WipeScope.downloaded),
              icon: const Icon(Icons.cloud_off_outlined, size: 18),
              label: const Text('Prenesene'),
            ),
            OutlinedButton.icon(
              onPressed: () => _wipeData(_WipeScope.all),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
              ),
              icon: const Icon(Icons.delete_forever, size: 18),
              label: const Text('Vse'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _wipeData(_WipeScope scope) async {
    final messenger = ScaffoldMessenger.of(context);
    final label = switch (scope) {
      _WipeScope.all => 'vse baze',
      _WipeScope.imported => 'uvožene baze',
      _WipeScope.downloaded => 'prenesene baze',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pobriši podatke'),
        content: Text(
          'Ali res želiš pobrisati $label? Tega ni mogoče razveljaviti.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Prekliči'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Pobriši'),
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
              ? 'Ni ustreznih baz za brisanje.'
              : 'Pobrisanih baz: $removed.',
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

  Widget _buildSettingsCard(BuildContext context, ColorScheme colorScheme) {
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildParcelsDbSection(context, colorScheme),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildMapCacheSection(context, colorScheme),
          ),
          if (_showDeveloperOptions) ...[
            const Divider(height: 1),
            _buildDeveloperOptions(context, colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMapSourceItem(
              context,
              'Zavod za gozdove Slovenije (ZGS)',
              'Gozdarski sloji, sestoji, odseki, revirji, gozdni rezervati, '
                  'varovalni gozdovi, požarna ogroženost, vetrolomi, podlubniki',
              'https://prostor.zgs.gov.si',
              Icons.park,
            ),
            const Divider(height: 24),
            _buildMapSourceItem(
              context,
              'Geodetska uprava RS (GURS)',
              'Ortofoto posnetki (2022-2024), kataster, katastrske občine, '
                  'občine, upravne enote, DMR',
              'https://www.e-prostor.gov.si',
              Icons.map,
            ),
            const Divider(height: 24),
            _buildMapSourceItem(
              context,
              'OpenStreetMap',
              'Osnovni zemljevid in topografski podatki',
              'https://www.openstreetmap.org',
              Icons.public,
            ),
            const Divider(height: 24),
            _buildMapSourceItem(
              context,
              'Topo LIDAR + OSM',
              'Topografski zemljevid (Seznam.cz)',
              'https://mapy.cz',
              Icons.terrain,
            ),
            const Divider(height: 24),
            _buildMapSourceItem(
              context,
              'ESRI',
              'Satelitski posnetki in topografski zemljevid',
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pogoji uporabe',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Aplikacija Gozdar je namenjena izključno informativnim namenom. '
              'Podatki o parcelah, gozdnih sestojih in drugih kartografskih '
              'slojih so povzeti iz javno dostopnih virov in morda niso '
              'posodobljeni ali popolnoma točni.',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Omejitev odgovornosti',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Razvijalec ne prevzema odgovornosti za morebitno škodo, ki bi '
              'nastala zaradi uporabe aplikacije ali podatkov v njej. Za '
              'uradne podatke o lastništvu in mejah parcel se obrnite na '
              'pristojne organe (GURS, ZGS).',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Avtorske pravice',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Kartografski podatki ZGS in GURS so last Republike Slovenije. '
              'OpenStreetMap podatki so na voljo pod licenco ODbL. '
              'ESRI podatki so last Esri Inc.',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Zasebnost',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Aplikacija zbira anonimne podatke o uporabi za izboljšanje '
              'delovanja (Firebase Analytics). Lokacijski podatki se ne '
              'pošiljajo na strežnik - vsi podatki o parcelah in hlodih '
              'se hranijo lokalno na napravi.',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenSourceCard(BuildContext context, ColorScheme colorScheme) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.code, color: colorScheme.primary),
        title: const Text('Prikaži licence'),
        subtitle: const Text('Flutter in odprtokodne knjižnice'),
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
    );
  }

  Widget _buildSupportCard(BuildContext context, ColorScheme colorScheme) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.bug_report, color: colorScheme.primary),
            title: const Text('Prijavi napako'),
            subtitle: const Text('GitHub Issues'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _launchUrl('https://github.com/dz0ny/gozdar/issues'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.email, color: colorScheme.primary),
            title: const Text('Kontakt'),
            subtitle: const Text('Pošljite povratne informacije'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _launchUrl('mailto:gozdar@dz0ny.dev'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.star, color: colorScheme.primary),
            title: const Text('Izvorna koda'),
            subtitle: const Text('Odprtokodni projekt na GitHub'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _launchUrl('https://github.com/dz0ny/gozdar'),
          ),
        ],
      ),
    );
  }
}
