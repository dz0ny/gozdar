import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'owner_lookup_service.dart';
import 'parcel_lookup_service.dart';

/// The R2 `regions.json` manifest: the GURS data date the region databases
/// were built from, the downloadable regions, and (optionally) the build
/// timestamp of the public-owners database that sits next to them.
class KatasterManifest {
  /// The decoded JSON this was parsed from (persisted between launches).
  final Map<String, dynamic> raw;
  final String? date;
  final String? source;
  final List<ParcelRegion> regions;
  final String? publicOwnersBuilt;
  final int? publicOwnersBytes;

  const KatasterManifest({
    required this.raw,
    required this.date,
    required this.source,
    required this.regions,
    this.publicOwnersBuilt,
    this.publicOwnersBytes,
  });

  factory KatasterManifest.fromJson(Map<String, dynamic> j) {
    final list = (j['regions'] as List<dynamic>? ?? const []);
    final pub = j['public_owners'];
    return KatasterManifest(
      raw: j,
      date: j['date']?.toString(),
      source: j['source']?.toString(),
      regions: list
          .map((e) => ParcelRegion.fromJson(e as Map<String, dynamic>))
          .toList(),
      publicOwnersBuilt: pub is Map ? pub['built']?.toString() : null,
      publicOwnersBytes: pub is Map ? (pub['bytes'] as num?)?.toInt() : null,
    );
  }

  /// Fetch and parse the manifest at [url]. Throws a [FormatException] with a
  /// user-facing message on HTTP errors.
  static Future<KatasterManifest> fetch(String url) async {
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      throw FormatException(
          'Seznama regij ni bilo mogoče naložiti (HTTP ${resp.statusCode}).');
    }
    final data = jsonDecode(resp.body);
    if (data is List) {
      // Legacy shape: a bare list of regions.
      return KatasterManifest.fromJson({'regions': data});
    }
    return KatasterManifest.fromJson(data as Map<String, dynamic>);
  }
}

/// What a manifest says is newer than the data on this device.
class KatasterUpdate {
  final KatasterManifest manifest;

  /// Loaded regions whose GURS data date is older than the manifest's.
  final List<ParcelRegion> outdatedRegions;

  /// Whether a public-owners DB is present locally and older than the one on R2.
  final bool publicOwnersOutdated;

  const KatasterUpdate({
    required this.manifest,
    required this.outdatedRegions,
    required this.publicOwnersOutdated,
  });

  bool get isEmpty => outdatedRegions.isEmpty && !publicOwnersOutdated;

  /// Total download size of the update, when the manifest reports sizes.
  int get bytes =>
      outdatedRegions.fold<int>(0, (s, r) => s + (r.bytes ?? 0)) +
      (publicOwnersOutdated ? (manifest.publicOwnersBytes ?? 0) : 0);

  /// Compare [manifest] against what is on the device. [loadedRegionDates]
  /// maps each loaded region file name to its `meta.date` (null when the DB
  /// carries none); [publicOwnersBuilt] is the local public-owners DB's
  /// `meta.built`, or null when it has not been downloaded yet — in which case
  /// `OwnerLookupService.initPublic` fetches it anyway, so nothing to flag.
  ///
  /// Dates are ISO-8601 strings, so plain string comparison orders them.
  static KatasterUpdate compute(
    KatasterManifest manifest, {
    required Map<String, String?> loadedRegionDates,
    required String? publicOwnersBuilt,
  }) {
    final outdated = <ParcelRegion>[];
    for (final region in manifest.regions) {
      // A region may carry its own date (data from another authority).
      final remoteDate = region.date ?? manifest.date;
      if (remoteDate == null) continue;
      if (!loadedRegionDates.containsKey(region.file)) continue;
      final local = loadedRegionDates[region.file];
      if (local == null || local.compareTo(remoteDate) < 0) {
        outdated.add(region);
      }
    }
    final remoteBuilt = manifest.publicOwnersBuilt;
    final publicOutdated = publicOwnersBuilt != null &&
        remoteBuilt != null &&
        publicOwnersBuilt.compareTo(remoteBuilt) < 0;
    return KatasterUpdate(
      manifest: manifest,
      outdatedRegions: outdated,
      publicOwnersOutdated: publicOutdated,
    );
  }
}

/// Checks R2 for newer kataster data — at most once a week, so the manifest
/// fetch and comparison never become a per-launch network hit — and remembers
/// the result for the session. The UI reads [pending] to show an update
/// prompt; [dismiss] silences it for the current manifest date.
class KatasterUpdateService {
  static const _keyLastCheck = 'kataster_update_last_check';
  static const _keyDismissedDate = 'kataster_update_dismissed_date';
  static const _keyManifest = 'kataster_update_manifest';
  static const checkInterval = Duration(days: 7);

  static final KatasterUpdateService instance = KatasterUpdateService._(
    fetchManifest: () =>
        KatasterManifest.fetch(ParcelLookupService.regionsManifestUrl),
    loadedRegionDates: () => ParcelLookupService.instance.loadedDataDates,
    publicOwnersBuilt: () => OwnerLookupService.instance.publicBuilt,
    clock: DateTime.now,
  );

  /// Data sources, injectable for tests.
  @visibleForTesting
  final Future<KatasterManifest> Function() fetchManifest;
  @visibleForTesting
  final Map<String, String?> Function() loadedRegionDates;
  @visibleForTesting
  final String? Function() publicOwnersBuilt;
  @visibleForTesting
  final DateTime Function() clock;

  SharedPreferences? _prefs;
  KatasterManifest? _manifest;
  KatasterUpdate? _update;
  Future<KatasterUpdate?>? _inFlight;

  KatasterUpdateService._({
    required this.fetchManifest,
    required this.loadedRegionDates,
    required this.publicOwnersBuilt,
    required this.clock,
  });

  @visibleForTesting
  factory KatasterUpdateService.forTesting({
    required Future<KatasterManifest> Function() fetchManifest,
    required Map<String, String?> Function() loadedRegionDates,
    required String? Function() publicOwnersBuilt,
    required DateTime Function() clock,
  }) =>
      KatasterUpdateService._(
        fetchManifest: fetchManifest,
        loadedRegionDates: loadedRegionDates,
        publicOwnersBuilt: publicOwnersBuilt,
        clock: clock,
      );

  Future<void> init() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
    // Restore the last fetched manifest so a pending update survives restarts
    // within the weekly window without another network call.
    final saved = _prefs!.getString(_keyManifest);
    if (saved != null) {
      try {
        _manifest = KatasterManifest.fromJson(
            jsonDecode(saved) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('KatasterUpdateService: discarding saved manifest: $e');
      }
    }
  }

  /// The last manifest fetched this session, if any.
  KatasterManifest? get manifest => _manifest;

  /// The update the user has not yet applied or dismissed, or null.
  KatasterUpdate? get pending {
    final u = _update;
    if (u == null || u.isEmpty) return null;
    if (_prefs?.getString(_keyDismissedDate) == u.manifest.date) return null;
    return u;
  }

  /// Fetch the manifest and compare it with the device — unless a check ran
  /// within [checkInterval], in which case the manifest saved by that check is
  /// compared again without touching the network. [force] skips
  /// the guard (explicit user action). A failed fetch does not count as a
  /// check, so an offline launch retries next time. Never throws.
  Future<KatasterUpdate?> check({bool force = false}) {
    return _inFlight ??= _check(force).whenComplete(() => _inFlight = null);
  }

  Future<KatasterUpdate?> _check(bool force) async {
    await init();
    final prefs = _prefs!;
    final now = clock();
    if (!force) {
      final last = prefs.getInt(_keyLastCheck);
      if (last != null) {
        final lastAt = DateTime.fromMillisecondsSinceEpoch(last, isUtc: true);
        if (now.toUtc().difference(lastAt) < checkInterval) {
          // No network inside the window; re-compare the saved manifest with
          // whatever is on the device now (a region may have been added).
          recompute();
          return pending;
        }
      }
    }
    try {
      _manifest = await fetchManifest();
    } catch (e) {
      debugPrint('KatasterUpdateService.check failed: $e');
      recompute();
      return pending;
    }
    await prefs.setInt(_keyLastCheck, now.toUtc().millisecondsSinceEpoch);
    await prefs.setString(_keyManifest, jsonEncode(_manifest!.raw));
    recompute();
    return pending;
  }

  /// Re-run the comparison against the current local data using the last
  /// fetched manifest (after a region or the owners DB was re-downloaded).
  void recompute() {
    final m = _manifest;
    if (m == null) return;
    _update = KatasterUpdate.compute(
      m,
      loadedRegionDates: loadedRegionDates(),
      publicOwnersBuilt: publicOwnersBuilt(),
    );
  }

  /// Hide the pending update until a manifest with a newer date shows up.
  Future<void> dismiss() async {
    final date = _update?.manifest.date;
    if (date == null) return;
    await init();
    await _prefs!.setString(_keyDismissedDate, date);
  }
}
