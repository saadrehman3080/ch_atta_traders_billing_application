import 'package:ch_atta_traders_billing_application/data/models/dashboard_data.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/dashboard_repository.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';
import 'package:flutter/foundation.dart';

/// States for dashboard data loading
enum DashboardState { initial, loading, loaded, error }

/// Provider (ViewModel) for managing dashboard data state.
///
/// Follows MVVM pattern by separating UI logic from data fetching.
/// Uses Provider for state management and reactive UI updates.
class DashboardProvider extends ChangeNotifier {
  final DashboardRepository _repository;

  DashboardProvider({DashboardRepository? repository})
    : _repository = repository ?? DashboardRepository();

  DashboardState _state = DashboardState.initial;
  DashboardData? _dashboardData;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();

  // Getters
  DashboardState get state => _state;
  DashboardData? get dashboardData => _dashboardData;
  String? get errorMessage => _errorMessage;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _state == DashboardState.loading;
  bool get hasError => _state == DashboardState.error;
  bool get hasData => _state == DashboardState.loaded && _dashboardData != null;

  /// Loads dashboard data for the selected date
  Future<void> loadDashboardData({DateTime? date}) async {
    try {
      _state = DashboardState.loading;
      _errorMessage = null;

      if (date != null) {
        _selectedDate = date;
      }

      notifyListeners();

      // Get salesman name from SharedPreferences
      final salesmanName = await AppPreferences.instance.salesmanName;

      if (salesmanName == null || salesmanName.isEmpty) {
        throw Exception('Salesman name not found. Please login again.');
      }

      // Fetch dashboard data from repository
      _dashboardData = await _repository.fetchDashboardData(
        salesmanName: salesmanName,
        date: _selectedDate,
      );

      _state = DashboardState.loaded;
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('Error loading dashboard data: $e');
      debugPrint('StackTrace: $stackTrace');

      _state = DashboardState.error;
      _errorMessage = e.toString();
      _dashboardData = null;
      notifyListeners();
    }
  }

  /// Refreshes dashboard data (pulls latest from Firebase)
  Future<void> refreshDashboardData() async {
    await loadDashboardData(date: _selectedDate);
  }

  /// Changes the selected date and reloads data
  Future<void> changeDate(DateTime newDate) async {
    _selectedDate = newDate;
    await loadDashboardData(date: newDate);
  }

  /// Resets to today's date and reloads data
  Future<void> resetToToday() async {
    _selectedDate = DateTime.now();
    await loadDashboardData(date: _selectedDate);
  }
}
