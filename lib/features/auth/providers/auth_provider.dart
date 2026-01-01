import 'package:flutter/foundation.dart';
import 'package:ch_atta_traders_billing_application/data/models/salesman.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/salesman_repository.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';

/// Authentication state enum
enum AuthState { initial, loading, authenticated, failed, error }

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

  // ========== Authentication Methods ==========

  /// Attempts to authenticate a salesman with the provided credentials.
  ///
  /// [salesmanId] - The salesman ID entered by the user
  /// [password] - The password entered by the user
  ///
  /// Returns true if authentication was successful, false otherwise.
  Future<bool> login(int salesmanId, int password) async {
    _setState(AuthState.loading);
    _errorMessage = null;

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

        debugPrint('Login successful for: ${salesman.name}');
        return true;
      } else {
        _errorMessage =
            'Invalid credentials. Please check your Salesman ID and Password.';
        _setState(AuthState.failed);
        debugPrint('Login failed: Invalid credentials');
        return false;
      }
    } catch (e) {
      _errorMessage = 'An error occurred during login. Please try again.';
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
