import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/parcel.dart';
import 'service_providers.dart';

part 'forest_provider.freezed.dart';

/// What the Gozd tab lists: the parcels and their sečnja marks.
@freezed
abstract class ForestData with _$ForestData {
  const factory ForestData({
    @Default(<Parcel>[]) List<Parcel> parcels,

    /// Sečnja marks per parcel id, for the count on each row.
    @Default(<int, int>{}) Map<int, int> secnjaCounts,
  }) = _ForestData;
}

/// Parcels for the Gozd tab, loaded from the database.
class ForestNotifier extends AsyncNotifier<ForestData> {
  @override
  Future<ForestData> build() async {
    final db = ref.watch(databaseServiceProvider);
    final parcels = await db.getAllParcels();
    final secnjaCounts = await db.getSecnjaCountsByParcel();
    return ForestData(parcels: parcels, secnjaCounts: secnjaCounts);
  }

  /// Loads again, keeping the current list on screen meanwhile. A failure
  /// ends up in the state as an error, not thrown here.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // Shown from the state's error.
    }
  }
}

final forestNotifierProvider =
    AsyncNotifierProvider<ForestNotifier, ForestData>(ForestNotifier.new);
