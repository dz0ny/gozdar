import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'sheet_parts.dart';

/// Name of the next sečnja mark: "Smreka 3" with a species, else "Drevo 3".
/// [existing] is the number of marks already on that parcel.
String nextSecnjaName({
  String? species,
  required int existing,
  required AppLocalizations l10n,
}) {
  final n = existing + 1;
  return species == null ? l10n.secnjaDefaultName(n) : '$species $n';
}

/// Bottom panel of the sečnja marking mode. The user aims the crosshair at a
/// tree and taps Označi. The species chip stays selected for the next tree.
class SecnjaMarkingPanel extends StatelessWidget {
  final String title;
  final int count;
  final List<String> species;
  final String? selectedSpecies;

  /// Gets the tapped species, or null when the user taps the selected chip.
  final ValueChanged<String?> onSpeciesSelected;
  final VoidCallback onAddSpecies;

  /// Null disables the undo tile.
  final VoidCallback? onUndo;
  final VoidCallback onMark;
  final VoidCallback onLocate;
  final VoidCallback onFinish;

  const SecnjaMarkingPanel({
    super.key,
    required this.title,
    required this.count,
    required this.species,
    required this.selectedSpecies,
    required this.onSpeciesSelected,
    required this.onAddSpecies,
    required this.onUndo,
    required this.onMark,
    required this.onLocate,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Material(
      elevation: 8,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      color: cs.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(),
              SheetHeader(
                icon: Icons.carpenter,
                color: Colors.deepOrange,
                title: title,
                subtitle: l10n.secnjaMarkedCount(count),
                onBack: onFinish,
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final s in species)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(s),
                          selected: s == selectedSpecies,
                          selectedColor: Colors.deepOrange.withValues(alpha: 0.25),
                          onSelected: (_) =>
                              onSpeciesSelected(s == selectedSpecies ? null : s),
                        ),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: Text(l10n.commonAdd),
                      onPressed: onAddSpecies,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SheetTileRow([
                SheetTile(
                  icon: Icons.undo,
                  label: l10n.mapTabUndo,
                  color: cs.onSurfaceVariant,
                  onTap: onUndo,
                ),
                SheetTile(
                  icon: Icons.my_location,
                  label: l10n.secnjaHere,
                  color: cs.onSurfaceVariant,
                  onTap: onLocate,
                ),
                SheetTile(
                  icon: Icons.carpenter,
                  label: l10n.secnjaMarkAction,
                  color: Colors.deepOrange,
                  onTap: onMark,
                ),
                SheetTile(
                  icon: Icons.check,
                  label: l10n.secnjaFinish,
                  color: Colors.green.shade400,
                  onTap: onFinish,
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
