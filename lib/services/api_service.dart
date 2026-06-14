import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class ApiService {
  // Use 10.0.2.2 if testing via standard Android Emulator to map to your Windows localhost
  // If plugging in your real physical phone, change this to your computer's local network IP (e.g., 192.168.1.X)
  static const String _baseUrl = 'http://10.0.2.2:8000/api/v1';
  static const _apiKey = String.fromEnvironment('API_KEY');

  /// POST with up to 3 attempts and exponential backoff.
  /// Retries only on network failures and 5xx; never on 4xx (won't change).
  static Future<http.Response?> _postWithRetry(
  Uri url,
  Map<String, String> headers,
  String body, {
  int maxRetries = 3,
  Duration timeout = const Duration(seconds: 45),
  bool retryOnException = true,
}) async {
  int attempt = 0;
  while (attempt < maxRetries) {
    try {
      final response = await http.post(url, headers: headers, body: body).timeout(timeout);
      if (response.statusCode >= 500 && attempt < maxRetries - 1) {
        attempt++;
        await Future.delayed(Duration(milliseconds: 500 * (1 << attempt)));
        continue;
      }
      return response;
    } on Exception {
      if (!retryOnException) return null;   // don't re-fire a slow-but-working call
      attempt++;
      if (attempt >= maxRetries) return null;
      await Future.delayed(Duration(milliseconds: 500 * (1 << attempt)));
    }
  }
  return null;
}

  static Map<String, dynamic> _interpretError(http.Response? r) {
    if (r == null) {
      return {
        'success': false,
        'error_message': "Can't reach the server. Is the backend running?",
      };
    }
    if (r.statusCode == 401) {
      return {
        'success': false,
        'error_message': 'Authentication failed — API key mismatch.',
      };
    }
    return {
      'success': false,
      'error_message': 'Server error (${r.statusCode}). Please try again.',
    };
  }

  static Future<Map<String, dynamic>> processMealVoice({
  required String rawText,
  required String mealType,
  bool clarify = false,
}) async {
  final url = Uri.parse('$_baseUrl/process-meal');
  final headers = {'Content-Type': 'application/json', 'X-API-Key': _apiKey};
  final body = jsonEncode({'text': rawText, 'meal_type': mealType, 'clarify': clarify});

  final response = await _postWithRetry(
    url, headers, body,
    timeout: const Duration(seconds: 60),
    retryOnException: false,
  );
  if (response != null && response.statusCode == 200) {
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  return _interpretError(response);
}

  static Future<Map<String, dynamic>> estimateTdee({
    required List<Map<String, dynamic>> dailyEntries,
    required List<Map<String, dynamic>> weightEntries,
  }) async {
    final url = Uri.parse('$_baseUrl/estimate-tdee');
    final headers = {'Content-Type': 'application/json', 'X-API-Key': _apiKey};
    final body = jsonEncode({
      'daily_entries':  dailyEntries,
      'weight_entries': weightEntries,
    });

    final response = await _postWithRetry(url, headers, body);
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return _interpretError(response);
  }

  static Future<List<Map<String, dynamic>>> searchFoods(String query) async {
    final url = Uri.parse(
        '$_baseUrl/search-foods?q=${Uri.encodeQueryComponent(query)}');
    try {
      final response = await http
          .get(url, headers: {'X-API-Key': _apiKey})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['results'] as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> addCustomFood({
    required String foodName,
    required double energyKcal,
    required double proteinG,
    required double carbG,
    required double fatG,
  }) async {
    final url = Uri.parse('$_baseUrl/add-custom-food');
    final headers = {'Content-Type': 'application/json', 'X-API-Key': _apiKey};
    final body = jsonEncode({
      'food_name': foodName,
      'energy_kcal': energyKcal,
      'protein_g': proteinG,
      'carb_g': carbG,
      'fat_g': fatG,
    });
    final response = await _postWithRetry(url, headers, body);
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return _interpretError(response);
  }
}
