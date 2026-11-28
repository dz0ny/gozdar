import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';

/// The Google Group whose members may join the closed test in Google Play.
/// A person joins the group on their own, so the app sends nothing.
final testerGroupUrl = Uri.parse('https://groups.google.com/g/gozdar-testers');

/// Where a member of the group becomes a tester and gets the Play version.
final testerOptInUrl = Uri.parse(
  'https://play.google.com/apps/testing/dev.dz0ny.gozdar',
);

/// Row that explains how to become a tester of Gozdar in Google Play.
/// Google publishes an app only after enough people test it for two weeks.
class TesterSignupTile extends StatelessWidget {
  const TesterSignupTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.how_to_reg,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(context.l10n.testerSignupTitle),
      subtitle: Text(context.l10n.testerSignupDesc),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => const _TesterSignupDialog(),
      ),
    );
  }
}

class _TesterSignupDialog extends StatelessWidget {
  const _TesterSignupDialog();

  Future<void> _open(Uri url) async {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.testerSignupTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.testerSignupBody),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _open(testerGroupUrl),
              icon: const Icon(Icons.group_add),
              label: Text(l10n.testerSignupJoinGroup),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () => _open(testerOptInUrl),
              icon: const Icon(Icons.shop),
              label: Text(l10n.testerSignupOptIn),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.testerSignupAccountNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.testerSignupClose),
        ),
      ],
    );
  }
}
