import '../l10n/l10n.dart';
import '../models/parcel.dart';
import '../services/ko_locator.dart';
import '../services/owner_lookup_service.dart';

/// Name of cadastral municipality [sifko], or null when no data knows it.
String? koNameOf(int? sifko) =>
    OwnerLookupService.instance.koName(sifko) ??
    KoLocator.instance.bySifko(sifko)?.name;

/// "DELNICE (304549)", or "KO 304549" when the name is unknown.
String koLabel(int sifko, {String? koName}) {
  final name = koName ?? koNameOf(sifko);
  return name != null && name.isNotEmpty
      ? '$name ($sifko)'
      : L10n.current.parcelFoundKo('$sifko');
}

/// True when the parcel still has the name an import gives it,
/// "DELNICE - 10000", with the k.o. as a name or a number.
bool hasDefaultName(Parcel parcel, {String? koName}) {
  final number = parcel.parcelNumber;
  if (number == null || number.isEmpty) return false;
  final sifko = parcel.cadastralMunicipality;
  final prefixes = {
    ?koName,
    OwnerLookupService.instance.koName(sifko),
    KoLocator.instance.bySifko(sifko)?.name,
    '$sifko',
  }.whereType<String>();
  final name = parcel.name.trim().toLowerCase();
  return prefixes.any(
    (ko) => name == '${ko.toLowerCase()} - ${number.toLowerCase()}',
  );
}

/// Short title of a parcel: its number when the name is the default one,
/// else the name the owner gave it.
String parcelTitle(Parcel parcel, {String? koName}) =>
    hasDefaultName(parcel, koName: koName) ? parcel.parcelNumber! : parcel.name;
