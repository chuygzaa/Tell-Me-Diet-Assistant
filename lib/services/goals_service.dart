import 'package:shared_preferences/shared_preferences.dart';

class GoalsService {
  static const _calKey  = 'goal_calories';
  static const _protKey = 'goal_protein';
  static const _carbKey = 'goal_carbs';
  static const _fatKey  = 'goal_fat';

  static Future<Map<String, double>> getGoals() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'calories': prefs.getDouble(_calKey)  ?? 0.0,
      'protein':  prefs.getDouble(_protKey) ?? 0.0,
      'carbs':    prefs.getDouble(_carbKey) ?? 0.0,
      'fat':      prefs.getDouble(_fatKey)  ?? 0.0,
    };
  }

  static Future<void> saveGoals({
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_calKey,  calories);
    await prefs.setDouble(_protKey, protein);
    await prefs.setDouble(_carbKey, carbs);
    await prefs.setDouble(_fatKey,  fat);
  }
}