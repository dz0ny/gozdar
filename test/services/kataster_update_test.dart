import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/kataster_update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _manifestJson = {
  'date': '2026-10-11',
  'source': 'GURS KN parcele (SLO)',
  'public_owners': {
    'file': 'public_owners.sqlite',
    'bytes': 92303360,
    'built': '2026-10-13T09:41:18Z',
  },
  'regions': [
    {
      'code': 'kr',
      'name': 'Gorenjska',
      'file': 'parcels-gorenjska.sqlite',
      'bytes': 114053120,
      'rows': 387220,
    },
    {
      'code': 'za',
      'name': 'Zasavska',
      'file': 'parcels-zasavska.sqlite',
      'bytes': 41218048,
      'rows': 134970,
    },
  ],
};

void main() {
  group('KatasterManifest.fromJson', () {
    test('parses date, regions and public owners', () {
      final m = KatasterManifest.fromJson(_manifestJson);
      expect(m.date, '2026-10-11');
      expect(m.regions.map((r) => r.code), ['kr', 'za']);
      expect(m.publicOwnersBuilt, '2026-10-13T09:41:18Z');
      expect(m.publicOwnersBytes, 92303360);
    });

    test('tolerates a manifest without public owners', () {
      final m = KatasterManifest.fromJson({
        'date': '2026-05-31',
        'regions': _manifestJson['regions'],
      });
      expect(m.publicOwnersBuilt, isNull);
      expect(m.regions, hasLength(2));
    });
  });

  group('KatasterUpdate.compute', () {
    final manifest = KatasterManifest.fromJson(_manifestJson);

    test('flags loaded regions older than the manifest date', () {
      final u = KatasterUpdate.compute(
        manifest,
        loadedRegionDates: {
          'parcels-gorenjska.sqlite': '2026-05-31',
          'parcels-zasavska.sqlite': '2026-10-11',
        },
        publicOwnersBuilt: '2026-10-13T09:41:18Z',
      );
      expect(u.outdatedRegions.map((r) => r.file), ['parcels-gorenjska.sqlite']);
      expect(u.publicOwnersOutdated, isFalse);
      expect(u.isEmpty, isFalse);
    });

    test('treats a region without a date as outdated', () {
      final u = KatasterUpdate.compute(
        manifest,
        loadedRegionDates: {'parcels-zasavska.sqlite': null},
        publicOwnersBuilt: null,
      );
      expect(u.outdatedRegions.map((r) => r.file), ['parcels-zasavska.sqlite']);
    });

    test('ignores regions not in the manifest and newer local data', () {
      final u = KatasterUpdate.compute(
        manifest,
        loadedRegionDates: {
          'parcels-custom.sqlite': '2020-01-01',
          'parcels-gorenjska.sqlite': '2027-01-01',
        },
        publicOwnersBuilt: null,
      );
      expect(u.outdatedRegions, isEmpty);
    });

    test('flags public owners only when a local build is older', () {
      KatasterUpdate run(String? built) => KatasterUpdate.compute(
            manifest,
            loadedRegionDates: const {},
            publicOwnersBuilt: built,
          );
      // Not downloaded yet: initPublic fetches it on its own, nothing to update.
      expect(run(null).publicOwnersOutdated, isFalse);
      expect(run('2026-06-02T14:33:42Z').publicOwnersOutdated, isTrue);
      expect(run('2026-10-13T09:41:18Z').publicOwnersOutdated, isFalse);
      expect(run('2026-06-02T14:33:42Z').isEmpty, isFalse);
    });

    test('is empty when nothing is loaded', () {
      final u = KatasterUpdate.compute(
        manifest,
        loadedRegionDates: const {},
        publicOwnersBuilt: null,
      );
      expect(u.isEmpty, isTrue);
    });
  });

  group('KatasterUpdateService weekly guard', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('fetches once, then stays quiet for a week', () async {
      var fetches = 0;
      final now = DateTime.utc(2026, 10, 13, 12);
      final service = KatasterUpdateService.forTesting(
        fetchManifest: () async {
          fetches++;
          return KatasterManifest.fromJson(_manifestJson);
        },
        loadedRegionDates: () => {'parcels-zasavska.sqlite': '2026-05-31'},
        publicOwnersBuilt: () => null,
        clock: () => now,
      );
      await service.init();

      final first = await service.check();
      expect(fetches, 1);
      expect(first?.outdatedRegions.map((r) => r.file),
          ['parcels-zasavska.sqlite']);
      expect(service.pending, isNotNull);

      // Same week: no network, cached result is reused.
      final second = await service.check();
      expect(fetches, 1);
      expect(second, isNotNull);

      // Persisted across restarts: a fresh instance in the same week skips the
      // network but still reports the update from the saved manifest.
      final restarted = KatasterUpdateService.forTesting(
        fetchManifest: () async {
          fetches++;
          return KatasterManifest.fromJson(_manifestJson);
        },
        loadedRegionDates: () => {'parcels-zasavska.sqlite': '2026-05-31'},
        publicOwnersBuilt: () => null,
        clock: () => now.add(const Duration(days: 6)),
      );
      await restarted.init();
      expect((await restarted.check())?.outdatedRegions, hasLength(1));
      expect(fetches, 1);

      // A week later it fetches again.
      final later = KatasterUpdateService.forTesting(
        fetchManifest: () async {
          fetches++;
          return KatasterManifest.fromJson(_manifestJson);
        },
        loadedRegionDates: () => {'parcels-zasavska.sqlite': '2026-05-31'},
        publicOwnersBuilt: () => null,
        clock: () => now.add(const Duration(days: 8)),
      );
      await later.init();
      expect(await later.check(), isNotNull);
      expect(fetches, 2);
    });

    test('force bypasses the guard and a failed fetch does not arm it',
        () async {
      var fetches = 0;
      var fail = true;
      final service = KatasterUpdateService.forTesting(
        fetchManifest: () async {
          fetches++;
          if (fail) throw Exception('offline');
          return KatasterManifest.fromJson(_manifestJson);
        },
        loadedRegionDates: () => {'parcels-zasavska.sqlite': '2026-05-31'},
        publicOwnersBuilt: () => null,
        clock: DateTime.now,
      );
      await service.init();
      expect(await service.check(), isNull);
      expect(fetches, 1);
      // Failure must not count as a check: the next attempt fetches again.
      fail = false;
      expect(await service.check(), isNotNull);
      expect(fetches, 2);
      expect(await service.check(force: true), isNotNull);
      expect(fetches, 3);
    });

    test('dismiss hides the update for that manifest date only', () async {
      final service = KatasterUpdateService.forTesting(
        fetchManifest: () async => KatasterManifest.fromJson(_manifestJson),
        loadedRegionDates: () => {'parcels-zasavska.sqlite': '2026-05-31'},
        publicOwnersBuilt: () => null,
        clock: DateTime.now,
      );
      await service.init();
      await service.check();
      expect(service.pending, isNotNull);
      await service.dismiss();
      expect(service.pending, isNull);
      // Re-checking the same manifest keeps it dismissed.
      await service.check(force: true);
      expect(service.pending, isNull);
    });

    test('recompute clears the update once local data is current', () async {
      var local = '2026-05-31';
      final service = KatasterUpdateService.forTesting(
        fetchManifest: () async => KatasterManifest.fromJson(_manifestJson),
        loadedRegionDates: () => {'parcels-zasavska.sqlite': local},
        publicOwnersBuilt: () => null,
        clock: DateTime.now,
      );
      await service.init();
      await service.check();
      expect(service.pending, isNotNull);
      local = '2026-10-11';
      service.recompute();
      expect(service.pending, isNull);
    });
  });
}
