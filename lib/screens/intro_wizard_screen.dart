import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/onboarding_service.dart';

class IntroWizardScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const IntroWizardScreen({super.key, required this.onComplete});

  @override
  State<IntroWizardScreen> createState() => _IntroWizardScreenState();
}

class _IntroWizardScreenState extends State<IntroWizardScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_WizardPage> _pages = [
    _WizardPage(
      icon: Icons.forest,
      title: 'Dobrodošli v Gozdar',
      description:
          'Aplikacija za upravljanje gozdnih parcel v Sloveniji. '
          'Sledite poseku, beležite hlodovino in uporabljajte GPS za delo na terenu.',
      color: Colors.green,
    ),
    _WizardPage(
      icon: Icons.navigation,
      title: 'Navigacija',
      description:
          'Aplikacija ima tri zavihke:\n\n'
          '• Karta - Interaktivni zemljevid z vašimi parcelami\n'
          '• Gozd - Seznam parcel s sledenjem poseku\n'
          '• Hlodi - Beleženje hlodovine z izračunom volumna',
      color: Colors.blue,
    ),
    _WizardPage(
      icon: Icons.touch_app,
      title: 'Dolg pritisk na karti',
      description:
          'Z dolgim pritiskom na karti odprete meni z možnostmi:\n\n'
          '• Dodaj točko - Shranite lokacijo (npr. mejnik)\n'
          '• Dodaj hlodovino - Zabeležite hlode na GPS lokaciji\n'
          '• Označi sečnjo - Označite drevo za posek\n'
          '• Uvozi parcelo - Prenesite parcelo iz katastra',
      color: Colors.orange,
    ),
    _WizardPage(
      icon: Icons.inventory_2,
      title: 'Hlodovina in parcele',
      description:
          'Ko dodate hlodovino z GPS lokacijo, se samodejno poveže s parcelo.\n\n'
          'V podrobnostih parcele vidite:\n'
          '• Ročno beležen posek (m³ in število dreves)\n'
          '• Vse hlode znotraj parcele (rjavi markerji)\n'
          '• Označena drevesa za sečnjo (oranžni markerji)\n'
          '• Shranjene točke (mejniki, skladišča)',
      color: Colors.brown,
    ),
    _WizardPage(
      icon: Icons.file_download,
      title: 'Uvoz in izvoz',
      description:
          'Uvoz parcel:\n'
          '• Dolg pritisk na karti → "Uvozi parcelo" iz katastra\n'
          '• Zavihek Gozd → meni → "Uvozi KML"\n\n'
          'Izvoz parcele s podatki:\n'
          '• Odprite parcelo → meni → "Izvozi KML"\n'
          '• Izvozi parcelo z vsemi hlodi, sečnjami in točkami',
      color: Colors.purple,
    ),
    _WizardPage(
      icon: Icons.layers,
      title: 'Sloji na karti',
      description:
          'Pritisnite ikono slojev v zgornjem desnem kotu za izbiro kart:\n\n'
          '• Google, ESRI, OpenStreetMap\n'
          '• Slovenski Ortofoto in topografske karte\n'
          '• Kataster, gozdni sestoji, odseki in več\n\n'
          'Kombinirajte osnovne in prekrivne sloje po želji.',
      color: Colors.teal,
    ),
    _WizardPage(
      icon: Icons.explore,
      title: 'Kompas do mejnika',
      description:
          'Pojdite na parcelo v zavihku Gozd in odprite mejne točke.\n\n'
          'Tapnite na mejnik za navigacijo - '
          'prikaže se oranžni trak z imenom točke.\n\n'
          'Tapnite na trak za odprtje kompasa, ki vas vodi do izbrane točke v naravi.',
      color: Colors.deepOrange,
    ),
    _WizardPage(
      icon: Icons.policy,
      title: 'Pogoji uporabe',
      description:
          'Aplikacija uporablja javne podatke Zavoda za gozdove Slovenije.\n\n'
          'Z uporabo te aplikacije se strinjate s pogoji uporabe podatkov, '
          'ki so na voljo na:',
      color: Colors.indigo,
      linkUrl: 'https://prostor.zgs.gov.si/pregledovalnik/',
      linkText: 'prostor.zgs.gov.si/pregledovalnik',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
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

  Future<void> _completeOnboarding() async {
    await OnboardingService.instance.setOnboardingCompleted();
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
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            // Page indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => _buildDot(index),
                ),
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  _currentPage > 0
                      ? TextButton.icon(
                          onPressed: _previousPage,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Nazaj'),
                        )
                      : const SizedBox(width: 100),

                  // Next/Finish button
                  FilledButton.icon(
                    onPressed: _nextPage,
                    icon: Icon(
                      _currentPage == _pages.length - 1
                          ? Icons.check
                          : Icons.arrow_forward,
                    ),
                    label: Text(
                      _currentPage == _pages.length - 1 ? 'Začni' : 'Naprej',
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

  Widget _buildPage(_WizardPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with colored background
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 52, color: page.color),
          ),
          const SizedBox(height: 32),

          // Title
          Text(
            page.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Description card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: page.color.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: page.linkUrl != null
                ? RichText(
                    textAlign: TextAlign.left,
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.9),
                        height: 1.7,
                        fontSize: 17,
                      ),
                      children: [
                        TextSpan(text: page.description),
                        const TextSpan(text: '\n\n'),
                        TextSpan(
                          text: page.linkText ?? page.linkUrl,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w500,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              launchUrl(
                                Uri.parse(page.linkUrl!),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                        ),
                      ],
                    ),
                  )
                : Text(
                    page.description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.9),
                      height: 1.7,
                      fontSize: 17,
                    ),
                    textAlign: TextAlign.left,
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

class _WizardPage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final String? linkUrl;
  final String? linkText;

  const _WizardPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    this.linkUrl,
    this.linkText,
  });
}
