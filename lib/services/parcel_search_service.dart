import 'package:latlong2/latlong.dart';

import 'ko_locator.dart';
import 'owner_lookup_service.dart';
import 'parcel_lookup_service.dart';

enum ParcelSuggestionKind { parcel, owner, ko }

/// One row in the parcel-search suggestion list.
class ParcelSuggestion {
  final ParcelSuggestionKind kind;

  /// Primary line, e.g. "Parcela 123/4" or "BABNO POLJE".
  final String title;

  /// Secondary line, e.g. the KO for a parcel or the owners of an owner hit.
  final String? subtitle;

  /// Cadastral key (parcel and owner suggestions).
  final int? sifko;
  final String? parcela;

  /// The KO to select (KO suggestions).
  final KoInfo? ko;

  const ParcelSuggestion({
    required this.kind,
    required this.title,
    this.subtitle,
    this.sifko,
    this.parcela,
    this.ko,
  });

  @override
  bool operator ==(Object other) =>
      other is ParcelSuggestion &&
      other.kind == kind &&
      other.sifko == sifko &&
      other.parcela == parcela &&
      other.title == title;

  @override
  int get hashCode => Object.hash(kind, sifko, parcela, title);
}

/// A search query split into its parcel-number token and the remaining words.
class ParsedParcelQuery {
  const ParsedParcelQuery(this.words, this.parcelNumber);

  /// Free text (KO or owner name), without the parcel number.
  final String words;

  /// "123", "123/4" or "123/4a", or null when the query has none.
  final String? parcelNumber;

  static final _parcelToken = RegExp(r'^\d+(?:/\d+)?[A-Za-z]?$');

  factory ParsedParcelQuery.parse(String input) {
    final tokens = input.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    String? number;
    final words = <String>[];
    for (final t in tokens) {
      if (number == null && _parcelToken.hasMatch(t)) {
        number = t.toLowerCase();
      } else {
        words.add(t);
      }
    }
    return ParsedParcelQuery(words.join(' '), number);
  }
}

/// Builds autocomplete suggestions for the parcel search from the bundled KO
/// index and the owners database.
class ParcelSearchService {
  const ParcelSearchService._();

  /// Fewest characters worth matching against KO names.
  static const minKoQueryLength = 2;

  /// Suggestions that need no I/O: the parcel number in the selected KO (or in
  /// the KOs the typed words name) and matching KO names.
  static List<ParcelSuggestion> instant(String query, {KoInfo? ko}) {
    final parsed = ParsedParcelQuery.parse(query);
    final locator = KoLocator.instance;
    final out = <ParcelSuggestion>[];

    final number = parsed.parcelNumber;
    final wordsKos = parsed.words.length >= minKoQueryLength
        ? locator.search(parsed.words, limit: 6)
        : const <KoInfo>[];

    if (number != null) {
      final targets = ko != null
          ? [ko]
          : wordsKos.take(3).toList();
      for (final k in targets) {
        out.add(_parcelFor(k, number));
      }
      // A bare number may also be a KO code ("1651").
      if (parsed.words.isEmpty && number.length >= minKoQueryLength) {
        for (final k in locator.search(number, limit: 4)) {
          out.add(_koSuggestion(k));
        }
      }
    }
    if (number == null || parsed.words.isNotEmpty) {
      for (final k in wordsKos) {
        if (number != null && ko == null) continue; // already a parcel row
        out.add(_koSuggestion(k));
      }
    }
    return out;
  }

  /// Owner matches for the free-text part of [query]. Empty when no owners
  /// database is open, the text is too short, or a parcel number was typed.
  static Future<List<ParcelSuggestion>> owners(
    String query, {
    KoInfo? ko,
    int limit = 15,
  }) async {
    final parsed = ParsedParcelQuery.parse(query);
    if (parsed.parcelNumber != null ||
        parsed.words.length < OwnerLookupService.minQueryLength ||
        !OwnerLookupService.instance.isAvailable) {
      return const [];
    }
    final result = await OwnerLookupService.instance.searchOwnersAsync(
      name: parsed.words,
      limit: ko == null ? limit : 300,
    );
    final out = <ParcelSuggestion>[];
    for (final hit in result.hits) {
      if (ko != null && hit.sifko != ko.sifko) continue;
      final koName = hit.koName ?? KoLocator.instance.bySifko(hit.sifko)?.name;
      final owners = hit.owners.take(2).join(', ');
      out.add(ParcelSuggestion(
        kind: ParcelSuggestionKind.owner,
        title: 'Parcela ${hit.parcela}',
        subtitle: [
          if (koName != null) 'KO $koName' else 'KO ${hit.sifko}',
          if (owners.isNotEmpty) owners,
        ].join(' • '),
        sifko: hit.sifko,
        parcela: hit.parcela,
      ));
      if (out.length >= limit) break;
    }
    return out;
  }

  /// The KO the map is looking at. Uses the exact offline parcel data when a
  /// region is loaded, otherwise the bundled KO boundaries (works everywhere,
  /// no network).
  static Future<KoInfo?> koForPoint(LatLng point) async {
    final locator = KoLocator.instance;
    await locator.ensureLoaded();
    final parcels = ParcelLookupService.instance;
    if (parcels.isAvailable) {
      final sifko = parcels.parcelAt(point)?.cadastralMunicipality;
      final exact = locator.bySifko(sifko);
      if (exact != null) return exact;
    }
    return locator.koAt(point);
  }

  static ParcelSuggestion _parcelFor(KoInfo k, String number) =>
      ParcelSuggestion(
        kind: ParcelSuggestionKind.parcel,
        title: 'Parcela $number',
        subtitle: 'KO ${k.label}',
        sifko: k.sifko,
        parcela: number,
        ko: k,
      );

  static ParcelSuggestion _koSuggestion(KoInfo k) => ParcelSuggestion(
        kind: ParcelSuggestionKind.ko,
        title: k.name,
        subtitle: 'Katastrska občina ${k.sifko}',
        ko: k,
      );
}
