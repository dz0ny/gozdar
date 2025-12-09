import 'package:flutter/material.dart';
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
          title: const Text('Dodaj novo vrsto'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Ime vrste',
              hintText: 'Npr. Hrast',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Prekliči'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: const Text('Dodaj'),
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
          SnackBar(content: Text('Vrsta "$newSpecies" dodana')),
        );
      }
    }
  }

  Future<void> _deleteSpecies(String species) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odstrani vrsto'),
        content: Text('Ali ste prepričani, da želite odstraniti "$species"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Prekliči'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Odstrani'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _speciesService.removeSpecies(species);
      await _loadSpecies();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vrsta "$species" odstranjena')),
        );
      }
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ponastavi na privzeto'),
        content: const Text(
          'Ali ste prepričani, da želite ponastaviti vrste na privzete vrednosti?\n\n'
          'Vse dodane vrste bodo odstranjene.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Prekliči'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Ponastavi'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _speciesService.resetToDefaults();
      await _loadSpecies();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vrste ponastavljene na privzete')),
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
                const Text(
                  'Upravljanje vrst',
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
                    label: const Text('Dodaj novo vrsto'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _resetToDefaults,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Ponastavi'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${_species.length} vrst',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
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
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ni dodanih vrst',
                            style: TextStyle(color: Colors.grey[600]),
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
