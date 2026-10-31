import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/parcel.dart';
import '../services/ko_locator.dart';
import '../services/owner_lookup_service.dart';
import '../services/si_valuation_service.dart';
import '../utils/formats.dart';
import 'sheet_parts.dart';
import '../screens/forest_tab.dart';
import '../l10n/l10n.dart';
import 'owner_list.dart';

/// One fact about the parcel: a tinted icon, a small label and the value in
/// large type, so it reads at arm's length outdoors.
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: cs.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Parcel info card showing basic parcel information
class ParcelInfoCard extends StatelessWidget {
  final Parcel parcel;
  final VoidCallback onEditForestType;

  const ParcelInfoCard({
    super.key,
    required this.parcel,
    required this.onEditForestType,
  });

  /// KO name with its number, e.g. "STARI TRG (1650)", from the owners DB or
  /// the bundled KO index (which covers Croatia too); the bare number when
  /// neither knows it.
  String _koValue(int? sifko) {
    final name = OwnerLookupService.instance.koName(sifko) ??
        KoLocator.instance.bySifko(sifko)?.name;
    return name != null ? '$name ($sifko)' : sifko.toString();
  }

  String _forestTypeLabel(BuildContext context) => switch (parcel.forestType) {
        ForestType.deciduous => context.l10n.parcelForestTypeDeciduous,
        ForestType.coniferous => context.l10n.parcelForestTypeConiferous,
        ForestType.mixed => context.l10n.parcelForestTypeMixed,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: onEditForestType,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: getForestTypeIcon(
                        parcel.forestType,
                      ).$2.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      getForestTypeIcon(parcel.forestType).$1,
                      size: 32,
                      color: getForestTypeIcon(parcel.forestType).$2,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parcel.areaFormatted,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      // Forest type next to its (tappable) icon; the vertex
                      // count meant nothing to an owner.
                      Text(
                        _forestTypeLabel(context),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(
              height: 24,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            if (parcel.isCadastral) ...[
              // The KO index loads lazily; rebuild with the name once it has.
              FutureBuilder<void>(
                future: KoLocator.instance.ensureLoaded(),
                builder: (context, _) => _InfoTile(
                  icon: Icons.location_city,
                  label: context.l10n.parcelInfoKo,
                  value: _koValue(parcel.cadastralMunicipality),
                ),
              ),
              _InfoTile(
                icon: Icons.tag,
                label: context.l10n.parcelInfoParcel,
                value: parcel.parcelNumber!,
              ),
            ],
            _InfoTile(
              icon: Icons.calendar_today,
              label: context.l10n.parcelInfoAdded,
              value: Fmt.date(parcel.createdAt),
            ),
          ],
        ),
      ),
    );
  }
}

/// Owner information card: one row per owner (with share and address when
/// known), the first few inline and the rest behind "Pokaži vse".
class ParcelOwnerCard extends StatelessWidget {
  /// Owners typed in or saved on import, joined with [OwnerInfo.separator].
  final String? owner;
  final VoidCallback onEdit;

  /// Owners looked up from the cadastre. Their names show when [owner] is
  /// empty; their shares and addresses fill in the rows either way.
  final OwnerInfo? lookedUp;

  static const _inline = 3;

  const ParcelOwnerCard({
    super.key,
    required this.owner,
    required this.onEdit,
    this.lookedUp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manual = OwnerInfo.split(owner);
    final lookedUpOwners = lookedUp?.owners ?? const <String>[];
    final names = manual.isNotEmpty ? manual : lookedUpOwners;
    final fromCadastre = manual.isEmpty && lookedUpOwners.isNotEmpty;
    final hasHolderAddresses =
        lookedUp?.holders.any((h) => h.address != null) ?? false;
    // A parcel-level address (Slovenian owners DB) when there are no
    // per-owner ones.
    final address = hasHolderAddresses ? null : lookedUp?.address;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // No leading icon: each owner row below already has one.
          ListTile(
            title: Text(
              names.length > 1
                  ? context.l10n.ownersTitle(names.length)
                  : context.l10n.parcelOwnerTitle,
            ),
            subtitle: names.isEmpty ? Text(context.l10n.parcelNotSet) : null,
            trailing: const Icon(Icons.edit),
            onTap: onEdit,
          ),
          if (names.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final name in names.take(_inline))
                    OwnerTile(
                      holder: lookedUp?.holder(name) ?? OwnerHolder(name),
                      dense: true,
                    ),
                  if (names.length > _inline)
                    TextButton.icon(
                      onPressed: () => OwnersSheet.show(
                        context,
                        owners: names,
                        info: lookedUp,
                      ),
                      icon: const Icon(Icons.people_outline),
                      label: Text(context.l10n.ownersShowAll(names.length)),
                    ),
                  if (address != null && address.isNotEmpty)
                    Text(address, style: muted),
                  if (fromCadastre || address != null)
                    Text(
                      context.l10n.parcelFromCadastre,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Whole euros above 10, cents below, as GURS shows them.
String euros(BuildContext context, num value) {
  final digits = value.abs() < 10 ? 2 : 0;
  return NumberFormat.decimalPatternDigits(
    locale: context.l10n.localeName,
    decimalDigits: digits,
  ).format(value);
}

/// "3.190 € · 0,91 €/m²" for one-line places.
String valuationSummary(BuildContext context, ParcelValuation v) {
  final perM2 = v.perSquareMeter;
  return [
    '${euros(context, v.total)} €',
    if (perM2 != null) context.l10n.valuationPerM2(euros(context, perM2)),
  ].join(' · ');
}

String _modelName(BuildContext context, String model) {
  final l10n = context.l10n;
  return switch (model) {
    'GOZ' => l10n.valuationModelGOZ,
    'KME' => l10n.valuationModelKME,
    'STZ' => l10n.valuationModelSTZ,
    'ZPS' => l10n.valuationModelZPS,
    'DRZ' => l10n.valuationModelDRZ,
    _ => model,
  };
}

/// "Parc. 456/4" with "KO 1650 BABNA POLICA" on the line under it.
String _parcelLine(BuildContext context, ParcelValuation v) {
  final name = KoLocator.instance.bySifko(v.sifko)?.name;
  return '${context.l10n.mapTabParcelShort(v.parcela)}\n'
      '${name != null ? '$name (${v.sifko})' : context.l10n.parcelFoundKo('${v.sifko}')}';
}

/// GURS generalised market value of a Slovenian parcel on the parcel page:
/// a card around [ParcelValuationView]. Hidden when GURS has no answer.
class ParcelValuationCard extends StatelessWidget {
  final Future<ParcelValuation?> valuation;

  const ParcelValuationCard({super.key, required this.valuation});

  /// The full breakdown of [v] in a sheet, for places that show only the
  /// one-line summary (the map's long-press quick view, the search result).
  static Future<void> show(BuildContext context, ParcelValuation v) {
    return showModalBottomSheet<void>(
      context: context,
      // Above the tab bar, not inside the tab's navigator.
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              SheetHeader(
                icon: Icons.euro,
                title: context.l10n.valuationTitle,
                subtitle: _parcelLine(context, v),
              ),
              const SizedBox(height: 12),
              ParcelValuationView(valuation: v),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ParcelValuation?>(
      future: valuation,
      builder: (context, snapshot) {
        final v = snapshot.data;
        if (v != null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.euro,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          context.l10n.valuationTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ParcelValuationView(valuation: v),
                  ],
                ),
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text(context.l10n.valuationTitle),
              subtitle: Text(context.l10n.valuationLoading),
            ),
          ),
        );
      },
    );
  }
}

/// The valuation itself: the total and €/m² in large type with the kind of
/// land under it, a row per kind only when there are several, the forest
/// factors with a plain-words line each, and the source with a link to GURS.
class ParcelValuationView extends StatelessWidget {
  final ParcelValuation valuation;

  const ParcelValuationView({super.key, required this.valuation});

  /// "Gozd · raven 6 od 10".
  static String _partLine(BuildContext context, ValuationPart part) => [
        _modelName(context, part.model),
        if (part.level != null)
          context.l10n.valuationLevel(part.level!.replaceAll('/', ' od ')),
      ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final v = valuation;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant,
    );
    final perM2 = v.perSquareMeter;
    final date = v.modelDate;
    final single = v.parts.length == 1;
    final shareFormat = NumberFormat.decimalPatternDigits(
      locale: l10n.localeName,
      decimalDigits: 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (v.isUnvalued)
          Text(l10n.valuationUnvalued, style: theme.textTheme.bodyLarge)
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${euros(context, v.total)} €',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 12),
              if (perM2 != null)
                Text(
                  l10n.valuationPerM2(euros(context, perM2)),
                  style: theme.textTheme.titleMedium,
                ),
            ],
          ),
          if (single)
            Text(_partLine(context, v.parts.single), style: muted),
        ],
        // Several kinds of land: each with its share and value.
        if (!single) ...[
          const SizedBox(height: 8),
          for (final part in v.parts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _partLine(context, part),
                          style: theme.textTheme.bodyLarge,
                        ),
                        Text(
                          '${shareFormat.format(part.sharePercent)} %',
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                  // Land under a building is valued with the building.
                  if (!part.isUnderBuilding)
                    Text(
                      '${euros(context, part.value)} €',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
        ],
        if (v.isForest) ...[
          const SizedBox(height: 8),
          Divider(height: 16, color: cs.outlineVariant),
          if (v.boniteta != null)
            _factor(context, l10n.valuationBoniteta,
                l10n.valuationBonitetaHint, '${v.boniteta}'),
          if (v.siteIndex != null)
            _factor(context, l10n.valuationSiteIndex,
                l10n.valuationSiteIndexHint, '${v.siteIndex}'),
          if (v.openness != null)
            _factor(context, l10n.valuationOpenness,
                l10n.valuationOpennessHint, '${v.openness} %'),
        ],
        Divider(height: 32, color: cs.outlineVariant),
        Text(
          date != null
              ? l10n.valuationSource(
                  DateFormat('MMMM yyyy', l10n.localeName).format(date),
                )
              : l10n.valuationSourceUndated,
          style: muted,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => launchUrl(
              Uri.parse(v.gursUrl),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(l10n.valuationOpenGurs),
          ),
        ),
      ],
    );
  }

  /// One forest factor: label with a plain-words line under it, value right.
  Widget _factor(
    BuildContext context,
    String label,
    String hint,
    String value,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyLarge),
                Text(
                  hint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Notes card
class ParcelNotesCard extends StatelessWidget {
  final String? notes;
  final VoidCallback onEdit;

  const ParcelNotesCard({super.key, required this.notes, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.note),
        title: Text(context.l10n.parcelNotesTitle),
        subtitle: Text(notes ?? context.l10n.parcelNoNotes),
        trailing: const Icon(Icons.edit),
        onTap: onEdit,
      ),
    );
  }
}
