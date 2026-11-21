import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  /// Default Gemini API Key placeholder (empty in version control for security)
  static const String defaultGeminiApiKey = '';

  static const String _prefKeyGeminiKey = 'gemini_api_key';

  /// Primary model for high-speed, 100% precision multimodal OCR
  static const String geminiModel = 'gemini-3.8-flash';

  /// Fallback model
  static const String geminiFallbackModel = 'gemini-3.5-flash';

  /// Maximum timeout for API request in seconds
  static const int requestTimeoutSeconds = 18;

  /// Retrieves the active API key:
  /// 1. Checks SharedPreferences
  /// 2. Checks local assets/secrets/gemini_key.json via rootBundle (packaged securely)
  /// 3. Checks direct file assets/secrets/gemini_key.json
  /// 4. Checks dart-define environment variable
  static Future<String> getApiKey() async {
    // 1. SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString(_prefKeyGeminiKey);
      if (savedKey != null && savedKey.trim().isNotEmpty) {
        return savedKey.trim();
      }
    } catch (_) {}

    // 2. rootBundle (Flutter Asset)
    try {
      final jsonStr =
          await rootBundle.loadString('assets/secrets/gemini_key.json');
      final data = jsonDecode(jsonStr);
      final key = data['gemini_api_key']?.toString();
      if (key != null && key.trim().isNotEmpty) {
        return key.trim();
      }
    } catch (_) {}

    // 3. Direct File (Desktop / Testing)
    try {
      final file = File('assets/secrets/gemini_key.json');
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        final key = data['gemini_api_key']?.toString();
        if (key != null && key.trim().isNotEmpty) {
          return key.trim();
        }
      }
    } catch (_) {}

    // 4. dart-define
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) return envKey.trim();

    return defaultGeminiApiKey.trim();
  }

  /// Saves user's API key to local storage
  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyGeminiKey, key.trim());
  }

  /// Verifies whether key matches the official Google AI Studio format (AIzaSy...)
  static bool isAiStudioKey(String key) {
    return key.trim().startsWith('AIzaSy') && key.trim().length >= 35;
  }

  /// Checks if a non-empty key is configured
  static bool isValidKey(String key) {
    return key.trim().isNotEmpty &&
        key.trim() != 'YOUR_GEMINI_API_KEY_HERE' &&
        key.trim().length > 15;
  }
}
