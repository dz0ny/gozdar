import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _keyOnboardingCompleted = 'onboarding_completed';

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

  bool get isOnboardingCompleted => _prefs.getBool(_keyOnboardingCompleted) ?? false;

  Future<void> setOnboardingCompleted() async {
    await _prefs.setBool(_keyOnboardingCompleted, true);
  }

  Future<void> resetOnboarding() async {
    await _prefs.setBool(_keyOnboardingCompleted, false);
  }
}
