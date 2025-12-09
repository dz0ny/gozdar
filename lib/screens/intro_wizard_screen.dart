import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/onboarding_service.dart';
import '../services/analytics_service.dart';

class IntroWizardScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const IntroWizardScreen({super.key, required this.onComplete});

  @override
  State<IntroWizardScreen> createState() => _IntroWizardScreenState();
}

class _IntroWizardScreenState extends State<IntroWizardScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 9;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding(skipped: false);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding({bool skipped = true}) async {
    await OnboardingService.instance.setOnboardingCompleted();
    if (skipped) {
      AnalyticsService().logOnboardingSkipped(pageIndex: _currentPage);
    } else {
      AnalyticsService().logOnboardingCompleted();
    }
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    'Preskoči',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildWelcomePage(),
                  _buildNavigationPage(),
                  _buildLogsPage(),
                  _buildLongPressPage(),
                  _buildMarkersPage(),
                  _buildLayersPage(),
                  _buildOfflinePage(),
                  _buildCompassPage(),
                  _buildTermsPage(),
                ],
              ),
            ),

            // Page indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalPages, (index) => _buildDot(index)),
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _currentPage > 0
                      ? TextButton.icon(
                          onPressed: _previousPage,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Nazaj'),
                        )
                      : const SizedBox(width: 100),
                  FilledButton.icon(
                    onPressed: _nextPage,
                    icon: Icon(
                      _currentPage == _totalPages - 1
                          ? Icons.check
                          : Icons.arrow_forward,
                    ),
                    label: Text(
                      _currentPage == _totalPages - 1 ? 'Začni' : 'Naprej',
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

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.forest,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Dobrodošli v Gozdar',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            'Aplikacija za upravljanje gozdnih parcel v Sloveniji.\n\n'
            'Sledite poseku, beležite hlodovino in uporabljajte GPS za delo na terenu.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Navigacija',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          // Real NavigationBar preview
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: NavigationBar(
              selectedIndex: 1,
              onDestinationSelected: (_) {},
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map),
                  label: 'Karta',
                ),
                NavigationDestination(
                  icon: Icon(Icons.forest_outlined),
                  selectedIcon: Icon(Icons.forest),
                  label: 'Gozd',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: 'Hlodi',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoCard([
            _buildInfoRow(Icons.map, 'Karta', 'Interaktivni zemljevid z vašimi parcelami'),
            _buildInfoRow(Icons.forest, 'Gozd', 'Seznam parcel in iskanje v katastru'),
            _buildInfoRow(Icons.inventory_2, 'Hlodi', 'Beleženje hlodovine z izračunom volumna'),
          ]),
        ],
      ),
    );
  }

  Widget _buildLogsPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Beleženje hlodovine',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          // Log entry visualization
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.straighten, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text('Premer: 45 cm'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.height, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text('Dolžina: 4.5 m'),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Icon(Icons.calculate, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Volumen: 0.716 m³',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoCard([
            _buildInfoRow(
              Icons.forest,
              'Drevesne vrste',
              'Beležite vrsto lesa (Smreka, Bukev, Jelka, ...)',
            ),
            _buildInfoRow(
              Icons.calculate,
              'Samodejni izračun',
              'Aplikacija izračuna volumen iz premera in dolžine',
            ),
            _buildInfoRow(
              Icons.group,
              'Razvrščanje',
              'Hlodi se samodejno razvrstijo po vrstah',
            ),
            _buildInfoRow(
              Icons.settings,
              'Upravljanje vrst',
              'Dodajte ali odstranite vrste v meniju ⋮',
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildLongPressPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Dolg pritisk na karti',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          // Icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.touch_app,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoCard([
            _buildInfoRow(
              Icons.search,
              'Išči parcelo',
              'Najdi parcelo v katastru (KO + številka)',
              iconColor: Colors.blue,
            ),
            _buildInfoRow(
              Icons.add_location_alt,
              'Dodaj točko',
              'Shrani lokacijo (mejnik, skladišče)',
              iconColor: Colors.red,
            ),
            _buildInfoRow(
              Icons.forest,
              'Dodaj hlodovino',
              'Beleženje hloda z GPS koordinatami',
              iconColor: Colors.brown,
            ),
            _buildInfoRow(
              Icons.carpenter,
              'Označi sečnjo',
              'Označi drevo za posek na karti',
              iconColor: Colors.deepOrange,
            ),
            _buildInfoRow(
              Icons.download,
              'Uvozi parcelo',
              'Pridobi parcelo iz katastra na trenutni lokaciji',
              iconColor: Colors.green,
            ),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Držite prst na karti za prikaz menija',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkersPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Označbe na karti',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          // Marker examples
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMarkerExample(Icons.location_on, Colors.red, 'Točka'),
              _buildMarkerExample(Icons.circle, Colors.brown, 'Hlod'),
              _buildMarkerExample(Icons.carpenter, Colors.deepOrange, 'Sečnja'),
            ],
          ),
          const SizedBox(height: 32),
          _buildInfoCard([
            _buildInfoRow(Icons.location_on, 'Rdeče', 'Shranjene lokacije (mejniki, skladišča)'),
            _buildInfoRow(Icons.circle, 'Rjave', 'Hlodovina z GPS lokacijo'),
            _buildInfoRow(Icons.carpenter, 'Oranžne', 'Drevesa označena za sečnjo'),
          ]),
          const SizedBox(height: 16),
          Text(
            'Hlodi in sečnje se samodejno povežejo s parcelo',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLayersPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Sloji na karti',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          // Layer button preview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  onPressed: null,
                  heroTag: 'layers_demo',
                  child: const Icon(Icons.layers),
                ),
                const SizedBox(width: 16),
                const Text('Pritisnite za izbiro slojev'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoCard([
            _buildInfoRow(Icons.satellite_alt, 'Ortofoto', 'Satelitski posnetki Slovenije'),
            _buildInfoRow(Icons.grid_on, 'Kataster', 'Meje parcel iz katastra'),
            _buildInfoRow(Icons.park, 'Gozdni sestoji', 'Podatki Zavoda za gozdove'),
            _buildInfoRow(Icons.map, 'Topografija', 'DTK in druge karte'),
          ]),
        ],
      ),
    );
  }

  Widget _buildOfflinePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Delo brez povezave',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          // Offline icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.offline_bolt,
              size: 52,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoCard([
            _buildInfoRow(
              Icons.cached,
              'Samodejno predpomnjenje',
              'Ogljedane karte se shranijo za kasnejšo uporabo',
            ),
            _buildInfoRow(
              Icons.search,
              'Ob iskanju parcele',
              'Karte za območje parcele se prenesejo samodejno',
            ),
            _buildInfoRow(
              Icons.download_for_offline,
              'Ročni prenos',
              'Uporabite gumb za sloje na karti za prenos območja',
            ),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Karte delujejo tudi v gozdu brez signala!',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompassPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Navigacija do mejnika',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          // Compass and navigation line preview
          Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.explore,
                  size: 52,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.deepOrange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.navigation, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Mejnik 1 • 45m',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoCard([
            _buildInfoRow(
              Icons.forest,
              'Odprite parcelo',
              'V zavihku Gozd izberite parcelo',
            ),
            _buildInfoRow(
              Icons.location_on,
              'Tapnite mejno točko',
              'Izberite točko na karti parcele',
            ),
            _buildInfoRow(
              Icons.navigation,
              'Aktivirajte kompas',
              'Tapnite oranžni navigacijski trak',
            ),
            _buildInfoRow(
              Icons.explore,
              'Sledite smeri',
              'Kompas kaže smer in razdaljo do točke',
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildTermsPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.policy, size: 52, color: Colors.indigo),
          ),
          const SizedBox(height: 32),
          Text(
            'Pogoji uporabe',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7),
                children: [
                  const TextSpan(
                    text: 'Aplikacija uporablja javne podatke Zavoda za gozdove Slovenije.\n\n'
                        'Z uporabo te aplikacije se strinjate s pogoji uporabe podatkov:\n\n',
                  ),
                  TextSpan(
                    text: 'prostor.zgs.gov.si/pregledovalnik',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w500,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        launchUrl(
                          Uri.parse('https://prostor.zgs.gov.si/pregledovalnik/'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkerExample(IconData icon, Color color, String label) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String subtitle, {Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor ?? Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  subtitle,
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
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: _currentPage == index ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: _currentPage == index
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
