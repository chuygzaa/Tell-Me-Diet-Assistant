import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _clarifyKey = 'clarify_enabled';

  static Future<bool> getClarifyEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_clarifyKey) ?? true;
  }

  static Future<void> setClarifyEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_clarifyKey, value);
  }
}