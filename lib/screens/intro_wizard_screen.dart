import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/l10n.dart';
import '../router/route_names.dart';
import '../services/onboarding_service.dart';

class IntroWizardScreen extends StatefulWidget {
  const IntroWizardScreen({super.key});

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

  /// Skipping jumps to the terms page instead of finishing, so the terms are
  /// always shown before onboarding completes.
  void _skipToTerms() {
    _pageController.animateToPage(
      _totalPages - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding({bool skipped = true}) async {
    await OnboardingService.instance.setOnboardingCompleted();
    if (mounted) {
      context.go(AppRoutes.forest);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button: jumps to the terms page; hidden there (keeps its space)
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Visibility(
                  visible: _currentPage < _totalPages - 1,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TextButton(
                    onPressed: _skipToTerms,
                    child: Text(
                      context.l10n.introSkip,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
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
                          label: Text(context.l10n.commonBack),
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
                      _currentPage == _totalPages - 1
                          ? context.l10n.introStart
                          : context.l10n.commonContinue,
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
            context.l10n.introWelcomeTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.introWelcomeBody,
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
            context.l10n.introNavTitle,
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
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map),
                  label: context.l10n.navTabMap,
                ),
                NavigationDestination(
                  icon: Icon(Icons.park_outlined),
                  selectedIcon: Icon(Icons.park),
                  label: context.l10n.navTabForest,
                ),
                NavigationDestination(
                  icon: Icon(Icons.forest_outlined),
                  selectedIcon: Icon(Icons.forest),
                  label: context.l10n.navTabLogs,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoCard([
            _buildInfoRow(Icons.map, context.l10n.navTabMap, context.l10n.introNavMapDesc),
            _buildInfoRow(Icons.park, context.l10n.navTabForest, context.l10n.introNavForestDesc),
            _buildInfoRow(Icons.forest, context.l10n.navTabLogs, context.l10n.introNavLogsDesc),
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
            context.l10n.introLogsTitle,
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
                    Text(context.l10n.introLogsDiameter),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.height, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(context.l10n.introLogsLength),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Icon(Icons.calculate, color: Colors.green[300]),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.introLogsVolume,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[200],
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
              context.l10n.introLogsSpecies,
              context.l10n.introLogsSpeciesDesc,
            ),
            _buildInfoRow(
              Icons.calculate,
              context.l10n.introLogsAutoCalc,
              context.l10n.introLogsAutoCalcDesc,
            ),
            _buildInfoRow(
              Icons.group,
              context.l10n.introLogsGrouping,
              context.l10n.introLogsGroupingDesc,
            ),
            _buildInfoRow(
              Icons.settings,
              context.l10n.introLogsManage,
              context.l10n.introLogsManageDesc,
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
            context.l10n.introLongPressTitle,
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
              Icons.add_location_alt,
              context.l10n.introLongPressAddPoint,
              context.l10n.introLongPressAddPointDesc,
              iconColor: Colors.red,
            ),
            _buildInfoRow(
              Icons.forest,
              context.l10n.introLongPressAddLogs,
              context.l10n.introLongPressAddLogsDesc,
              iconColor: Colors.brown,
            ),
            _buildInfoRow(
              Icons.carpenter,
              context.l10n.introLongPressMarkCut,
              context.l10n.introLongPressMarkCutDesc,
              iconColor: Colors.deepOrange,
            ),
            _buildInfoRow(
              Icons.download,
              context.l10n.introLongPressImport,
              context.l10n.introLongPressImportDesc,
              iconColor: Colors.blue,
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
                    context.l10n.introLongPressHint,
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
            context.l10n.introMarkersTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          // Marker examples
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMarkerExample(Icons.location_on, Colors.red, context.l10n.introMarkerPoint),
              _buildMarkerExample(Icons.circle, Colors.brown, context.l10n.introMarkerLog),
              _buildMarkerExample(Icons.carpenter, Colors.deepOrange, context.l10n.introMarkerCut),
            ],
          ),
          const SizedBox(height: 32),
          _buildInfoCard([
            _buildInfoRow(Icons.location_on, context.l10n.introMarkersRed, context.l10n.introMarkersRedDesc),
            _buildInfoRow(Icons.circle, context.l10n.introMarkersBrown, context.l10n.introMarkersBrownDesc),
            _buildInfoRow(Icons.carpenter, context.l10n.introMarkersOrange, context.l10n.introMarkersOrangeDesc),
          ]),
          const SizedBox(height: 16),
          Text(
            context.l10n.introMarkersLinked,
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
            context.l10n.introLayersTitle,
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
                Text(context.l10n.introLayersButtonHint),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoCard([
            _buildInfoRow(Icons.satellite_alt, 'Ortofoto', context.l10n.introLayersOrthoDesc),
            _buildInfoRow(Icons.grid_on, 'Kataster', context.l10n.introLayersCadastreDesc),
            _buildInfoRow(Icons.park, context.l10n.introLayersStands, context.l10n.introLayersStandsDesc),
            _buildInfoRow(Icons.map, context.l10n.introLayersTopo, context.l10n.introLayersTopoDesc),
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
            context.l10n.introOfflineTitle,
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
              context.l10n.introOfflineAutoCache,
              context.l10n.introOfflineAutoCacheDesc,
            ),
            _buildInfoRow(
              Icons.search,
              context.l10n.introOfflineOnSearch,
              context.l10n.introOfflineOnSearchDesc,
            ),
            _buildInfoRow(
              Icons.download_for_offline,
              context.l10n.introOfflineManual,
              context.l10n.introOfflineManualDesc,
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
                    context.l10n.introOfflineHint,
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
            context.l10n.introCompassTitle,
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.navigation, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.introCompassMarker,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
              context.l10n.introCompassStep1,
              context.l10n.introCompassStep1Desc,
            ),
            _buildInfoRow(
              Icons.location_on,
              context.l10n.introCompassStep2,
              context.l10n.introCompassStep2Desc,
            ),
            _buildInfoRow(
              Icons.navigation,
              context.l10n.introCompassStep3,
              context.l10n.introCompassStep3Desc,
            ),
            _buildInfoRow(
              Icons.explore,
              context.l10n.introCompassStep4,
              context.l10n.introCompassStep4Desc,
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
              color: Theme.of(context).colorScheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.policy,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            context.l10n.introTermsTitle,
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
                  TextSpan(text: context.l10n.introTermsBody),
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
