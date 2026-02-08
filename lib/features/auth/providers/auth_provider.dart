import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ch_atta_traders_billing_application/data/models/salesman.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/salesman_repository.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';

/// Authentication state enum
enum AuthState { initial, loading, authenticated, failed, error, noAccess }

/// ViewModel for authentication operations.
///
/// This class follows the MVVM pattern, managing authentication state
/// and coordinating between the View and Repository layers.
class AuthProvider extends ChangeNotifier {
  final SalesmanRepository _repository;

  AuthProvider({SalesmanRepository? repository})
    : _repository = repository ?? SalesmanRepository();

  // ========== State Management ==========
  AuthState _state = AuthState.initial;
  Salesman? _currentSalesman;
  String? _errorMessage;

  /// Current authentication state
  AuthState get state => _state;

  /// Currently authenticated salesman
  Salesman? get currentSalesman => _currentSalesman;

  /// Error message if authentication failed
  String? get errorMessage => _errorMessage;

  /// Whether authentication is in progress
  bool get isLoading => _state == AuthState.loading;

  /// Whether user is authenticated
  bool get isAuthenticated => _state == AuthState.authenticated;

  /// Whether the current salesman is an admin
  bool get isAdmin => _currentSalesman?.isAdmin ?? false;

  // ========== Authentication Methods ==========

  /// Checks internet connectivity
  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult.any(
        (result) =>
            result == ConnectivityResult.mobile ||
            result == ConnectivityResult.wifi ||
            result == ConnectivityResult.ethernet,
      );
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }

  /// Attempts to authenticate a salesman with the provided credentials.
  ///
  /// [salesmanId] - The salesman ID entered by the user
  /// [password] - The password entered by the user
  ///
  /// Returns true if authentication was successful, false otherwise.
  Future<bool> login(int salesmanId, int password) async {
    _setState(AuthState.loading);
    _errorMessage = null;

    // Check internet connectivity first
    final hasConnection = await _checkConnectivity();
    if (!hasConnection) {
      _errorMessage =
          'No internet connection. Please check your network settings and try again.';
      _setState(AuthState.failed);
      debugPrint('Login failed: No internet connection');
      return false;
    }

    try {
      final salesman = await _repository.validateCredentials(
        salesmanId,
        password,
      );

      if (salesman != null) {
        _currentSalesman = salesman;
        _setState(AuthState.authenticated);

        // Store salesman data in shared preferences
        await AppPreferences.instance.setSalesmanName(salesman.name);
        await AppPreferences.instance.setSalesmanId(salesman.salesmanId);
        await AppPreferences.instance.setIsAdmin(salesman.isAdmin);
        await AppPreferences.instance.setSalesmanDocId(salesman.id);

        debugPrint('Login successful for: ${salesman.name}');
        return true;
      } else {
        _errorMessage =
            'Invalid credentials. Please check your Salesman ID and Password.';
        _setState(AuthState.failed);
        debugPrint('Login failed: Invalid credentials');
        return false;
      }
    } on NoAccessException catch (e) {
      // Specific handling when user does not have system access
      _errorMessage = 'Sorry, you do not have access to the system.';
      _setState(AuthState.noAccess);
      debugPrint('Login failed: No access - $e');
      return false;
    } catch (e) {
      _errorMessage =
          'Unable to connect to server. Please check your internet connection and try again.';
      _setState(AuthState.error);
      debugPrint('Login error: $e');
      return false;
    }
  }

  /// Logs out the current user.
  void logout() {
    _currentSalesman = null;
    _errorMessage = null;
    _setState(AuthState.initial);
    debugPrint('User logged out');
  }

  /// Revalidates access control by fetching the latest data from Firestore.
  ///
  /// This should be called during fingerprint/biometric login to ensure
  /// the user still has access and to update isAdmin status.
  ///
  /// [salesmanId] - The salesman ID stored in preferences
  ///
  /// Returns true if the user has valid access, false otherwise.
  Future<bool> revalidateAccess(int salesmanId) async {
    _setState(AuthState.loading);
    _errorMessage = null;

    // Check internet connectivity first
    final hasConnection = await _checkConnectivity();
    if (!hasConnection) {
      // Allow access with cached data when offline
      debugPrint('No internet - using cached access data');
      _setState(AuthState.authenticated);
      return true;
    }

    try {
      final salesman = await _repository.getSalesmanById(salesmanId);

      if (salesman != null) {
        _currentSalesman = salesman;
        _setState(AuthState.authenticated);

        // Update cached preferences with latest values from Firestore
        await AppPreferences.instance.setSalesmanName(salesman.name);
        await AppPreferences.instance.setIsAdmin(salesman.isAdmin);
        await AppPreferences.instance.setSalesmanDocId(salesman.id);

        debugPrint('Access revalidated for: ${salesman.name}');
        debugPrint('isAdmin updated to: ${salesman.isAdmin}');
        return true;
      } else {
        _errorMessage = 'User not found. Please login with credentials.';
        _setState(AuthState.failed);
        return false;
      }
    } on NoAccessException catch (e) {
      _errorMessage = 'Sorry, you no longer have access to the system.';
      _setState(AuthState.noAccess);
      debugPrint('Access revalidation failed: No access - $e');
      return false;
    } catch (e) {
      // On error, allow access with cached data
      debugPrint('Error revalidating access: $e - using cached data');
      _setState(AuthState.authenticated);
      return true;
    }
  }

  /// Resets the authentication state to initial.
  void resetState() {
    _errorMessage = null;
    _setState(AuthState.initial);
  }

  // ========== Private Methods ==========

  void _setState(AuthState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    debugPrint('AuthProvider disposed');
    super.dispose();
  }
}
