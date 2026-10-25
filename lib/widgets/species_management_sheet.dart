import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../services/species_service.dart';

/// Bottom sheet for managing tree species
class SpeciesManagementSheet extends StatefulWidget {
  const SpeciesManagementSheet({super.key});

  @override
  State<SpeciesManagementSheet> createState() => _SpeciesManagementSheetState();
}

class _SpeciesManagementSheetState extends State<SpeciesManagementSheet> {
  final _speciesService = SpeciesService();
  List<String> _species = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSpecies();
  }

  Future<void> _loadSpecies() async {
    setState(() => _isLoading = true);
    final species = await _speciesService.getSpecies();
    setState(() {
      _species = species;
      _isLoading = false;
    });
  }

  Future<void> _addSpecies() async {
    final controller = TextEditingController();
    final newSpecies = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.l10n.logsSpeciesAddTitle),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: context.l10n.logsSpeciesNameLabel,
              hintText: context.l10n.logsSpeciesNameHint,
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: Text(context.l10n.commonAdd),
            ),
          ],
        );
      },
    );

    if (newSpecies != null && newSpecies.isNotEmpty) {
      await _speciesService.addSpecies(newSpecies);
      await _loadSpecies();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.logsSpeciesAdded(newSpecies))),
        );
      }
    }
  }

  Future<void> _deleteSpecies(String species) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.logsSpeciesRemoveTitle),
        content: Text(context.l10n.logsSpeciesRemoveConfirm(species)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.l10n.logsSpeciesRemoveButton),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _speciesService.removeSpecies(species);
      await _loadSpecies();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.logsSpeciesRemoved(species))),
        );
      }
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.logsSpeciesResetTitle),
        content: Text(context.l10n.logsSpeciesResetConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(context.l10n.logsSpeciesResetButton),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _speciesService.resetToDefaults();
      await _loadSpecies();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.logsSpeciesResetDone)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  context.l10n.logsMenuManageSpecies,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _addSpecies,
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.logsSpeciesAddTitle),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _resetToDefaults,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.logsSpeciesResetButton),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.logsSpeciesCount(_species.length),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _species.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.forest_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.logsSpeciesNone,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _species.length,
                      itemBuilder: (context, index) {
                        final species = _species[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              Icons.forest,
                              color: Colors.green[700],
                            ),
                            title: Text(species),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.red[400],
                              onPressed: () => _deleteSpecies(species),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            ],
          ],
        ),
    );
  }
}
