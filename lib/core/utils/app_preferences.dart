import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const String _firstLoginKey = 'is_first_login';

  /// Returns true if this is the user's first login, false otherwise.
  static Future<bool> isFirstLogin() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to true if the key does not exist
    return prefs.getBool(_firstLoginKey) ?? true;
  }

  /// Call this after the user has completed their first login.
  static Future<void> setNotFirstLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLoginKey, false);
  }

  /// Optionally, reset the first login flag (for testing or logout)
  static Future<void> resetFirstLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLoginKey, true);
  }
}
