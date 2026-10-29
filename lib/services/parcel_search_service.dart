import 'package:latlong2/latlong.dart';

import 'ko_locator.dart';
import 'owner_lookup_service.dart';
import 'parcel_lookup_service.dart';
import '../l10n/l10n.dart';

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

    // "1650 1000" or "1650 100/2": KO code, then the parcel number, the way
    // GURS writes it. A typed code beats the selected KO, so it comes first;
    // the other reading follows.
    final codeFirst = _koCodeThenParcel(query);
    if (codeFirst != null) out.add(_parcelFor(codeFirst.$1, codeFirst.$2));

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

  /// Owner matches for the free text of [query]: every word may match the
  /// owner name, the address or (with several words) the KO name, in any
  /// order. Empty when no owners database is open, nothing long enough was
  /// typed, or a parcel number was typed.
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
    final words = parsed.words.split(RegExp(r'\s+'));
    final terms = [
      for (final w in words)
        OwnerSearchTerm(
          w,
          // A lone word is better served by the KO suggestion row.
          words.length > 1 && w.length >= 3
              ? [for (final k in KoLocator.instance.search(w, limit: 40)) k.sifko]
              : const [],
        ),
    ];
    final result = await OwnerLookupService.instance.searchAnyAsync(
      terms,
      onlySifko: ko?.sifko,
      limit: limit,
    );
    final out = <ParcelSuggestion>[];
    for (final hit in result.hits) {
      final koName = hit.koName ?? KoLocator.instance.bySifko(hit.sifko)?.name;
      final owners = hit.owners.take(2).join(', ');
      out.add(ParcelSuggestion(
        kind: ParcelSuggestionKind.owner,
        title: L10n.current.parcelFoundTitle(hit.parcela),
        subtitle: [
          L10n.current.parcelFoundKo(koName ?? '${hit.sifko}'),
          if (owners.isNotEmpty) owners,
          if (hit.address != null) hit.address!,
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

  /// The KO and parcel number of a query written as "šifra KO, parcel",
  /// or null when it is not two such tokens or the code names no KO.
  static (KoInfo, String)? _koCodeThenParcel(String query) {
    final tokens = query.trim().split(RegExp(r'\s+'));
    if (tokens.length != 2) return null;
    final code = int.tryParse(tokens[0]);
    if (code == null ||
        !ParsedParcelQuery._parcelToken.hasMatch(tokens[1])) {
      return null;
    }
    final k = KoLocator.instance.bySifko(code);
    return k == null ? null : (k, tokens[1].toLowerCase());
  }

  static ParcelSuggestion _parcelFor(KoInfo k, String number) =>
      ParcelSuggestion(
        kind: ParcelSuggestionKind.parcel,
        title: L10n.current.parcelFoundTitle(number),
        subtitle: L10n.current.parcelFoundKo(k.label),
        sifko: k.sifko,
        parcela: number,
        ko: k,
      );

  static ParcelSuggestion _koSuggestion(KoInfo k) => ParcelSuggestion(
        kind: ParcelSuggestionKind.ko,
        title: k.name,
        subtitle: L10n.current.parcelSearchKoSubtitle(k.sifko),
        ko: k,
      );
}
