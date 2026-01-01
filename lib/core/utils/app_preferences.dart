import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// A singleton service for managing application preferences using SharedPreferences.
///
/// This class provides a type-safe, cached, and error-handled interface to
/// interact with SharedPreferences. It follows the singleton pattern to ensure
/// only one instance exists and the SharedPreferences instance is cached for
/// optimal performance.
///
/// Usage:
/// ```dart
/// // Initialize once at app startup
/// await AppPreferences.init();
///
/// // Access anywhere
/// final prefs = AppPreferences.instance;
/// final isFirstLogin = await prefs.isFirstLogin;
/// await prefs.setIsFirstLogin(false);
/// ```
class AppPreferences {
  // ========== Singleton Pattern ==========
  AppPreferences._internal();
  static final AppPreferences _instance = AppPreferences._internal();

  /// Returns the singleton instance of [AppPreferences].
  static AppPreferences get instance => _instance;

  // ========== Private Members ==========
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // ========== Preference Keys ==========
  /// Key for storing the first login flag
  static const String _keyFirstLogin = 'is_first_login';

  /// Key for storing the salesman name
  static const String _keySalesmanName = 'salesman_name';

  /// Key for storing the salesman ID
  static const String _keySalesmanId = 'salesman_id';

  // ========== Initialization ==========

  /// Initializes the SharedPreferences instance.
  ///
  /// This method must be called once before accessing any preferences,
  /// typically during app startup in main().
  ///
  /// Returns `true` if initialization was successful, `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await AppPreferences.init();
  ///   runApp(MyApp());
  /// }
  /// ```
  static Future<bool> init() async {
    try {
      _instance._prefs = await SharedPreferences.getInstance();
      _instance._isInitialized = true;
      debugPrint('AppPreferences initialized successfully');
      return true;
    } catch (e, stackTrace) {
      debugPrint('Failed to initialize AppPreferences: $e');
      debugPrint('StackTrace: $stackTrace');
      return false;
    }
  }

  /// Checks if the preferences have been initialized.
  bool get isInitialized => _isInitialized;

  /// Throws an exception if preferences are not initialized.
  void _ensureInitialized() {
    if (!_isInitialized || _prefs == null) {
      throw StateError(
        'AppPreferences not initialized. Call AppPreferences.init() first.',
      );
    }
  }

  // ========== First Login Management ==========

  /// Returns `true` if this is the user's first login, `false` otherwise.
  ///
  /// Defaults to `true` if the value has never been set.
  ///
  /// Throws [StateError] if preferences are not initialized.
  Future<bool> get isFirstLogin async {
    _ensureInitialized();
    try {
      return _prefs!.getBool(_keyFirstLogin) ?? true;
    } catch (e) {
      debugPrint('Error reading first login status: $e');
      return true; // Fail-safe default
    }
  }

  /// Sets the first login flag.
  ///
  /// [isFirst] - `true` to mark as first login, `false` otherwise.
  ///
  /// Returns `true` if the operation was successful, `false` otherwise.
  ///
  /// Throws [StateError] if preferences are not initialized.
  Future<bool> setIsFirstLogin(bool isFirst) async {
    _ensureInitialized();
    try {
      final result = await _prefs!.setBool(_keyFirstLogin, isFirst);
      if (result) {
        debugPrint('First login status updated to: $isFirst');
      }
      return result;
    } catch (e) {
      debugPrint('Error setting first login status: $e');
      return false;
    }
  }

  /// Marks that the user has completed their first login.
  ///
  /// This is a convenience method that calls [setIsFirstLogin] with `false`.
  ///
  /// Returns `true` if the operation was successful, `false` otherwise.
  Future<bool> markLoginCompleted() async {
    return setIsFirstLogin(false);
  }

  /// Resets the first login flag to `true`.
  ///
  /// Useful for testing or when a user logs out and you want to
  /// show onboarding again.
  ///
  /// Returns `true` if the operation was successful, `false` otherwise.
  Future<bool> resetFirstLogin() async {
    return setIsFirstLogin(true);
  }

  // ========== Salesman Data Management ==========

  /// Gets the salesman name from shared preferences.
  ///
  /// Returns the salesman name or null if not set.
  Future<String?> get salesmanName async {
    _ensureInitialized();
    try {
      return _prefs!.getString(_keySalesmanName);
    } catch (e) {
      debugPrint('Error reading salesman name: $e');
      return null;
    }
  }

  /// Stores the salesman name.
  ///
  /// Returns `true` if the operation was successful, `false` otherwise.
  Future<bool> setSalesmanName(String name) async {
    _ensureInitialized();
    try {
      final result = await _prefs!.setString(_keySalesmanName, name);
      if (result) {
        debugPrint('Salesman name stored: $name');
      }
      return result;
    } catch (e) {
      debugPrint('Error storing salesman name: $e');
      return false;
    }
  }

  /// Stores the salesman ID.
  ///
  /// Returns `true` if the operation was successful, `false` otherwise.
  Future<bool> setSalesmanId(int id) async {
    _ensureInitialized();
    try {
      final result = await _prefs!.setInt(_keySalesmanId, id);
      if (result) {
        debugPrint('Salesman ID stored: $id');
      }
      return result;
    } catch (e) {
      debugPrint('Error storing salesman ID: $e');
      return false;
    }
  }

  // ========== Utility Methods ==========

  /// Clears all application preferences.
  ///
  /// WARNING: This will remove ALL stored preferences.
  ///
  /// Returns `true` if the operation was successful, `false` otherwise.
  ///
  /// Throws [StateError] if preferences are not initialized.
  Future<bool> clearAll() async {
    _ensureInitialized();
    try {
      final result = await _prefs!.clear();
      if (result) {
        debugPrint('All preferences cleared');
      }
      return result;
    } catch (e) {
      debugPrint('Error clearing preferences: $e');
      return false;
    }
  }

  /// Removes a specific preference by key.
  ///
  /// Returns `true` if the operation was successful, `false` otherwise.
  ///
  /// Throws [StateError] if preferences are not initialized.
  Future<bool> remove(String key) async {
    _ensureInitialized();
    try {
      final result = await _prefs!.remove(key);
      if (result) {
        debugPrint('Preference removed: $key');
      }
      return result;
    } catch (e) {
      debugPrint('Error removing preference $key: $e');
      return false;
    }
  }

  /// Checks if a preference key exists.
  ///
  /// Throws [StateError] if preferences are not initialized.
  bool containsKey(String key) {
    _ensureInitialized();
    return _prefs!.containsKey(key);
  }

  /// Reloads all preferences from persistent storage.
  ///
  /// Useful when preferences might have been changed by another isolate
  /// or external process.
  ///
  /// Throws [StateError] if preferences are not initialized.
  Future<void> reload() async {
    _ensureInitialized();
    try {
      await _prefs!.reload();
      debugPrint('Preferences reloaded');
    } catch (e) {
      debugPrint('Error reloading preferences: $e');
    }
  }

  // ========== Debugging & Testing ==========

  /// Gets all stored preference keys (for debugging purposes).
  ///
  /// Throws [StateError] if preferences are not initialized.
  Set<String> getAllKeys() {
    _ensureInitialized();
    return _prefs!.getKeys();
  }

  /// Prints all stored preferences (for debugging purposes).
  ///
  /// Only available in debug mode.
  void debugPrintAll() {
    if (kDebugMode) {
      _ensureInitialized();
      final keys = _prefs!.getKeys();
      debugPrint('=== All Stored Preferences ===');
      for (final key in keys) {
        debugPrint('$key: ${_prefs!.get(key)}');
      }
      debugPrint('==============================');
    }
  }
}
