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

  /// Key for storing the salesman admin status
  static const String _keyIsAdmin = 'is_admin';

  /// Key for storing the salesman Firestore document ID
  static const String _keySalesmanDocId = 'salesman_doc_id';

  /// Key for storing the connected printer address
  static const String _keyPrinterAddress = 'printer_address';

  /// Key for storing the anonymous print mode
  static const String _keyAnonymousPrint = 'anonymous_print';

  /// Key for storing whether anonymous print is currently enabled
  static const String _keyAnonymousPrintEnabled = 'anonymous_print_enabled';

  /// Key for storing whether skip customer name is enabled by default
  static const String _keySkipCustomerName = 'skip_customer_name_default';

  /// Key for storing the selected shop route filter
  static const String _keySelectedShopRoute = 'selected_shop_route';

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

  /// Gets the salesman ID from shared preferences.
  ///
  /// Returns the salesman ID or null if not set.
  Future<int?> get salesmanId async {
    _ensureInitialized();
    try {
      return _prefs!.getInt(_keySalesmanId);
    } catch (e) {
      debugPrint('Error reading salesman ID: $e');
      return null;
    }
  }

  /// Gets the unique salesman identifier (combination of ID and name).
  ///
  /// Format: "{salesmanId}_{salesmanName}" (e.g., "1_Khawar")
  /// This ensures unique paths in Firebase even if names are duplicated.
  ///
  /// Returns null if either salesman ID or name is not set.
  Future<String?> get salesmanIdentifier async {
    _ensureInitialized();
    try {
      final id = _prefs!.getInt(_keySalesmanId);
      final name = _prefs!.getString(_keySalesmanName);

      if (id == null || name == null || name.isEmpty) {
        debugPrint('Salesman identifier not available: id=$id, name=$name');
        return null;
      }

      final identifier = '${id}_$name';
      debugPrint('Salesman identifier: $identifier');
      return identifier;
    } catch (e) {
      debugPrint('Error getting salesman identifier: $e');
      return null;
    }
  }

  /// Gets the salesman admin status from shared preferences.
  ///
  /// Returns `true` if the salesman is an admin, `false` otherwise.
  /// Defaults to `false` if not set.
  Future<bool> get isAdmin async {
    _ensureInitialized();
    try {
      return _prefs!.getBool(_keyIsAdmin) ?? false;
    } catch (e) {
      debugPrint('Error reading admin status: $e');
      return false; // Fail-safe default
    }
  }

  /// Stores the salesman admin status.
  ///
  /// [isAdmin] - `true` if the salesman is an admin, `false` otherwise.
  ///
  /// Returns `true` if the operation was successful, `false` otherwise.
  Future<bool> setIsAdmin(bool isAdmin) async {
    _ensureInitialized();
    try {
      final result = await _prefs!.setBool(_keyIsAdmin, isAdmin);
      if (result) {
        debugPrint('Admin status stored: $isAdmin');
      }
      return result;
    } catch (e) {
      debugPrint('Error storing admin status: $e');
      return false;
    }
  }

  // ========== Salesman Firestore Doc ID ==========

  /// Gets the salesman Firestore document ID from shared preferences.
  ///
  /// This is the auto-generated Firestore document ID for the salesman
  /// used in paths like /salesmen/{docId}/daily_sales/.
  ///
  /// Returns the document ID or null if not set.
  Future<String?> get salesmanDocId async {
    _ensureInitialized();
    try {
      return _prefs!.getString(_keySalesmanDocId);
    } catch (e) {
      debugPrint('Error reading salesman doc ID: $e');
      return null;
    }
  }

  /// Stores the salesman Firestore document ID.
  ///
  /// Returns `true` if the operation was successful, `false` otherwise.
  Future<bool> setSalesmanDocId(String docId) async {
    _ensureInitialized();
    try {
      final result = await _prefs!.setString(_keySalesmanDocId, docId);
      if (result) {
        debugPrint('Salesman doc ID stored: $docId');
      }
      return result;
    } catch (e) {
      debugPrint('Error storing salesman doc ID: $e');
      return false;
    }
  }

  // ========== Anonymous Print Management ==========

  /// Gets the anonymous print access from shared preferences (from Firebase).
  /// This controls whether the user has access to the anonymous print feature.
  ///
  /// Returns `true` if user has access to anonymous print, `false` otherwise.
  /// Defaults to `false` if not set.
  Future<bool> get hasAnonymousPrintAccess async {
    _ensureInitialized();
    try {
      return _prefs!.getBool(_keyAnonymousPrint) ?? false;
    } catch (e) {
      debugPrint('Error reading anonymous print access: $e');
      return false;
    }
  }

  /// Stores the anonymous print access (from Firebase).
  ///
  /// [hasAccess] - `true` if user has access to anonymous print, `false` otherwise.
  ///
  /// Returns `true` if the operation was successful, `false` otherwise.
  Future<bool> setAnonymousPrint(bool hasAccess) async {
    _ensureInitialized();
    try {
      final result = await _prefs!.setBool(_keyAnonymousPrint, hasAccess);
      if (result) {
        debugPrint('Anonymous print access stored: $hasAccess');
      }
      return result;
    } catch (e) {
      debugPrint('Error storing anonymous print access: $e');
      return false;
    }
  }

  /// Gets whether anonymous print is currently enabled (toggle state).
  ///
  /// Returns `true` if anonymous print is enabled, `false` otherwise.
  /// Defaults to `false` if not set.
  Future<bool> get isAnonymousPrintEnabled async {
    _ensureInitialized();
    try {
      return _prefs!.getBool(_keyAnonymousPrintEnabled) ?? false;
    } catch (e) {
      debugPrint('Error reading anonymous print enabled status: $e');
      return false;
    }
  }

  /// Stores whether anonymous print is currently enabled (toggle state).
  ///
  /// [enabled] - `true` to enable anonymous print, `false` otherwise.
  ///
  /// Returns `true` if the operation was successful, `false` otherwise.
  Future<bool> setAnonymousPrintEnabled(bool enabled) async {
    _ensureInitialized();
    try {
      final result = await _prefs!.setBool(_keyAnonymousPrintEnabled, enabled);
      if (result) {
        debugPrint('Anonymous print enabled status stored: $enabled');
      }
      return result;
    } catch (e) {
      debugPrint('Error storing anonymous print enabled status: $e');
      return false;
    }
  }

  // ========== Skip Customer Name Default ==========

  /// Gets whether skip customer name is enabled by default.
  ///
  /// Returns `true` if skip customer name is enabled by default, `false` otherwise.
  /// Defaults to `false` if not set.
  Future<bool> get isSkipCustomerNameDefault async {
    _ensureInitialized();
    try {
      return _prefs!.getBool(_keySkipCustomerName) ?? false;
    } catch (e) {
      debugPrint('Error reading skip customer name default: $e');
      return false;
    }
  }

  /// Stores whether skip customer name should be enabled by default.
  ///
  /// [enabled] - `true` to enable skip customer name by default, `false` otherwise.
  ///
  /// Returns `true` if the operation was successful, `false` otherwise.
  Future<bool> setSkipCustomerNameDefault(bool enabled) async {
    _ensureInitialized();
    try {
      final result = await _prefs!.setBool(_keySkipCustomerName, enabled);
      if (result) {
        debugPrint('Skip customer name default stored: $enabled');
      }
      return result;
    } catch (e) {
      debugPrint('Error storing skip customer name default: $e');
      return false;
    }
  }

  // ========== Shop Route Selection ==========

  /// Gets the selected shop route from shared preferences.
  ///
  /// Returns the route title (e.g., "KALLAR SYEDAN-1") or null if not set.
  /// Defaults to "KALLAR SYEDAN-1" if not set.
  Future<String> get selectedShopRoute async {
    _ensureInitialized();
    try {
      return _prefs!.getString(_keySelectedShopRoute) ?? 'KALLAR SYEDAN-1';
    } catch (e) {
      debugPrint('Error reading selected shop route: $e');
      return 'KALLAR SYEDAN-1';
    }
  }

  /// Stores the selected shop route.
  ///
  /// [route] - The route title (e.g., "KALLAR SYEDAN-1").
  ///
  /// Returns `true` if the operation was successful, `false` otherwise.
  Future<bool> setSelectedShopRoute(String route) async {
    _ensureInitialized();
    try {
      final result = await _prefs!.setString(_keySelectedShopRoute, route);
      if (result) {
        debugPrint('Selected shop route stored: $route');
      }
      return result;
    } catch (e) {
      debugPrint('Error storing selected shop route: $e');
      return false;
    }
  }

  // ========== Printer Management ==========

  /// Gets the saved printer address from shared preferences.
  ///
  /// Returns the printer MAC address or null if not set.
  Future<String?> get printerAddress async {
    _ensureInitialized();
    try {
      return _prefs!.getString(_keyPrinterAddress);
    } catch (e) {
      debugPrint('Error reading printer address: $e');
      return null;
    }
  }

  /// Stores the printer address.
  ///
  /// Returns `true` if the operation was successful, `false` otherwise.
  Future<bool> setPrinterAddress(String address) async {
    _ensureInitialized();
    try {
      final result = await _prefs!.setString(_keyPrinterAddress, address);
      if (result) {
        debugPrint('Printer address stored: $address');
      }
      return result;
    } catch (e) {
      debugPrint('Error storing printer address: $e');
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
