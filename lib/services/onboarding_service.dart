import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _keyOnboardingVersion = 'onboarding_version';

  /// Current onboarding version. Increment this when onboarding content changes.
  /// Users who completed an older version will see the wizard again.
  static const int currentVersion = 3;

  static OnboardingService? _instance;
  late SharedPreferences _prefs;

  OnboardingService._();

  static Future<OnboardingService> initialize() async {
    if (_instance == null) {
      _instance = OnboardingService._();
      _instance!._prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  static OnboardingService get instance {
    if (_instance == null) {
      throw StateError('OnboardingService not initialized. Call initialize() first.');
    }
    return _instance!;
  }

  /// Returns the version of onboarding the user has completed (0 if never completed)
  int get completedVersion => _prefs.getInt(_keyOnboardingVersion) ?? 0;

  /// Returns true if user has completed the current onboarding version
  bool get isOnboardingCompleted => completedVersion >= currentVersion;

  /// Mark onboarding as completed with the current version
  Future<void> setOnboardingCompleted() async {
    await _prefs.setInt(_keyOnboardingVersion, currentVersion);
  }

  /// Reset onboarding to show again (sets version to 0)
  Future<void> resetOnboarding() async {
    await _prefs.setInt(_keyOnboardingVersion, 0);
  }
}
