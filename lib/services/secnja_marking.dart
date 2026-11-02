import 'package:latlong2/latlong.dart';

import '../l10n/l10n.dart';
import '../models/map_location.dart';
import '../widgets/secnja_marking_panel.dart';
import 'database_service.dart';

/// Saves a sečnja mark at [point]. The parcel and the number in the name
/// come from the parcel under [point] now, not from an earlier map position.
Future<MapLocation> markSecnjaAt(
  LatLng point, {
  String? species,
  required AppLocalizations l10n,
  DatabaseService? db,
}) async {
  final database = db ?? DatabaseService();
  final parcelId = await database.parcelIdAt(point);
  final existing = parcelId == null
      ? await database.countSecnjaWithoutParcel()
      : (await database.getSecnjaByParcel(parcelId)).length;
  final mark = MapLocation(
    name: nextSecnjaName(species: species, existing: existing, l10n: l10n),
    latitude: point.latitude,
    longitude: point.longitude,
    type: LocationType.secnja,
    parcelId: parcelId,
  );
  mark.id = await database.insertLocation(mark);
  return mark;
}
