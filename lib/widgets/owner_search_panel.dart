import 'package:flutter/material.dart';

import '../services/owner_lookup_service.dart';
import 'owner_search_controller.dart';

/// Name/address fields plus the result list for an owner search. The caller
/// builds each result row, since the sheet and the import screen act on a
/// hit differently.
class OwnerSearchPanel extends StatelessWidget {
  const OwnerSearchPanel({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.message,
  });

  final OwnerSearchController controller;
  final Widget Function(BuildContext context, OwnerSearchHit hit) itemBuilder;

  /// Optional message (e.g. an error) shown above the results.
  final Widget? message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final result = controller.result;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  TextField(
                    controller: controller.name,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => controller.queryChanged(),
                    decoration: const InputDecoration(
                      labelText: 'Ime lastnika',
                      prefixIcon: Icon(Icons.person_search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller.address,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => controller.queryChanged(),
                    decoration: const InputDecoration(
                      labelText: 'Naslov',
                      prefixIcon: Icon(Icons.home_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            ?message,
            if (result.truncated && controller.hasQuery)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Prikazanih prvih ${controller.limit} zadetkov — '
                        'natančneje določite iskanje.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            // Thin progress line instead of the divider while searching.
            SizedBox(
              height: 2,
              child: controller.searching
                  ? const LinearProgressIndicator()
                  : const Divider(height: 1),
            ),
            Expanded(child: _results(context, result)),
          ],
        );
      },
    );
  }

  Widget _results(BuildContext context, OwnerSearchResult result) {
    if (!controller.hasQuery) {
      return _hint(
        context,
        Icons.search,
        'Vnesite ime lastnika in/ali naslov za iskanje parcel.',
      );
    }
    if (result.tooShort) {
      return _hint(
        context,
        Icons.keyboard,
        'Vnesite vsaj ${OwnerLookupService.minQueryLength} znake.',
      );
    }
    if (result.hits.isEmpty) {
      return controller.searching
          ? const SizedBox.shrink()
          : _hint(context, Icons.person_off, 'Ni zadetkov.');
    }
    return ListView.separated(
      itemCount: result.hits.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) => itemBuilder(context, result.hits[i]),
    );
  }

  Widget _hint(BuildContext context, IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
