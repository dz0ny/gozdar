import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full-featured About screen with app info, map sources, and legal information
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _packageInfo = info);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('O aplikaciji'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App header
          _buildAppHeader(context, colorScheme),
          const SizedBox(height: 24),

          // Version info
          _buildVersionCard(context, colorScheme),
          const SizedBox(height: 16),

          // Map sources
          _buildSectionTitle(context, 'Viri kartografskih podatkov'),
          _buildMapSourcesCard(context, colorScheme),
          const SizedBox(height: 16),

          // Legal section
          _buildSectionTitle(context, 'Pravne informacije'),
          _buildLegalCard(context, colorScheme),
          const SizedBox(height: 16),

          // Open source libraries
          _buildSectionTitle(context, 'Odprtokodne knjiznice'),
          _buildOpenSourceCard(context, colorScheme),
          const SizedBox(height: 16),

          // Contact & Support
          _buildSectionTitle(context, 'Podpora'),
          _buildSupportCard(context, colorScheme),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAppHeader(BuildContext context, ColorScheme colorScheme) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'icon.png',
              width: 96,
              height: 96,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Gozdar',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Aplikacija za lastnike gozdov in gozdarske delavce v Sloveniji',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildVersionCard(BuildContext context, ColorScheme colorScheme) {
    final version = _packageInfo?.version ?? '...';
    final buildNumber = _packageInfo?.buildNumber ?? '...';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Informacije o aplikaciji',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('Verzija', version),
            _buildInfoRow('Stevilka gradnje', buildNumber),
            _buildInfoRow('Paket', _packageInfo?.packageName ?? '...'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _buildMapSourcesCard(BuildContext context, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMapSourceItem(
              context,
              'Zavod za gozdove Slovenije (ZGS)',
              'Gozdarski sloji, sestoji, odseki, revirji, gozdni rezervati, '
                  'varovalni gozdovi, pozarna ogrozenost, vetrolomi, podlubniki',
              'https://prostor.zgs.gov.si',
              Icons.park,
            ),
            const Divider(height: 24),
            _buildMapSourceItem(
              context,
              'Geodetska uprava RS (GURS)',
              'Ortofoto posnetki (2022-2024), kataster, katastrske obcine, '
                  'obcine, upravne enote, DMR',
              'https://www.e-prostor.gov.si',
              Icons.map,
            ),
            const Divider(height: 24),
            _buildMapSourceItem(
              context,
              'OpenStreetMap',
              'Osnovni zemljevid in topografski podatki',
              'https://www.openstreetmap.org',
              Icons.public,
            ),
            const Divider(height: 24),
            _buildMapSourceItem(
              context,
              'OpenTopoMap',
              'Topografski zemljevid',
              'https://opentopomap.org',
              Icons.terrain,
            ),
            const Divider(height: 24),
            _buildMapSourceItem(
              context,
              'ESRI',
              'Satelitski posnetki in topografski zemljevid',
              'https://www.esri.com',
              Icons.satellite_alt,
            ),
            const Divider(height: 24),
            _buildMapSourceItem(
              context,
              'Google',
              'Hibridni zemljevid (satelit + oznake)',
              'https://www.google.com/maps',
              Icons.location_on,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSourceItem(
    BuildContext context,
    String name,
    String description,
    String url,
    IconData icon,
  ) {
    return InkWell(
      onTap: () => _launchUrl(url),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalCard(BuildContext context, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pogoji uporabe',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aplikacija Gozdar je namenjena izkljucno informativnim namenom. '
              'Podatki o parcelah, gozdnih sestojih in drugih kartografskih '
              'slojih so povzeti iz javno dostopnih virov in morda niso '
              'posodobljeni ali popolnoma tocni.',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Omejitev odgovornosti',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Razvijalec ne prevzema odgovornosti za morebitno skodo, ki bi '
              'nastala zaradi uporabe aplikacije ali podatkov v njej. Za '
              'uradne podatke o lastnistvu in mejah parcel se obrnite na '
              'pristojne organe (GURS, ZGS).',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Avtorske pravice',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kartografski podatki ZGS in GURS so last Republike Slovenije. '
              'OpenStreetMap podatki so na voljo pod licenco ODbL. '
              'ESRI podatki so last Esri Inc.',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Zasebnost',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aplikacija zbira anonimne podatke o uporabi za izboljsanje '
              'delovanja (Firebase Analytics). Lokacijski podatki se ne '
              'posiljajo na streznik - vsi podatki o parcelah in hlodih '
              'se hranijo lokalno na napravi.',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenSourceCard(BuildContext context, ColorScheme colorScheme) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.code, color: colorScheme.primary),
        title: const Text('Prikazi licence'),
        subtitle: const Text('Flutter in odprtokodne knjiznice'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          showLicensePage(
            context: context,
            applicationName: 'Gozdar',
            applicationVersion: _packageInfo?.version,
            applicationIcon: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'icon.png',
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSupportCard(BuildContext context, ColorScheme colorScheme) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.bug_report, color: colorScheme.primary),
            title: const Text('Prijavi napako'),
            subtitle: const Text('GitHub Issues'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _launchUrl('https://github.com/dz0ny/gozdar/issues'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.email, color: colorScheme.primary),
            title: const Text('Kontakt'),
            subtitle: const Text('Posiljite povratne informacije'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _launchUrl('mailto:gozdar@dz0ny.dev'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.star, color: colorScheme.primary),
            title: const Text('Izvorna koda'),
            subtitle: const Text('Odprtokodni projekt na GitHub'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _launchUrl('https://github.com/dz0ny/gozdar'),
          ),
        ],
      ),
    );
  }
}
