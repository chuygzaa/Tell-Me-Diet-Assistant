import 'package:shared_preferences/shared_preferences.dart';

class ProfileService {
  static const _nameKey      = 'profile_name';
  static const _sexKey       = 'profile_sex';
  static const _onboardedKey = 'onboarding_complete';

  static Future<String> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nameKey) ?? '';
  }

  static Future<String> getSex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sexKey) ?? '';
  }

  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardedKey) ?? false;
  }

  static Future<void> saveProfile({
    required String name,
    required String sex,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
    await prefs.setString(_sexKey, sex);
  }

  static Future<void> setOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardedKey, true);
  }
}