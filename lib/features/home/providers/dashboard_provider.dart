import 'package:ch_atta_traders_billing_application/data/models/dashboard_data.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/dashboard_repository.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

/// States for dashboard data loading
enum DashboardState { initial, loading, loaded, error }

/// Provider (ViewModel) for managing dashboard data state.
///
/// Follows MVVM pattern by separating UI logic from data fetching.
/// Uses Provider for state management and reactive UI updates.
class DashboardProvider extends ChangeNotifier {
  final DashboardRepository _repository;
  StreamSubscription<DashboardData>? _dashboardSubscription;
  String? _salesmanIdentifier;

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

      // Get salesman identifier from SharedPreferences
      _salesmanIdentifier ??= await AppPreferences.instance.salesmanIdentifier;

      if (_salesmanIdentifier == null || _salesmanIdentifier!.isEmpty) {
        throw Exception('Salesman identifier not found. Please login again.');
      }

      await _startDashboardStream(
        salesmanName: _salesmanIdentifier!,
        date: _selectedDate,
      );
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
    if (_salesmanIdentifier == null || _salesmanIdentifier!.isEmpty) {
      await loadDashboardData(date: _selectedDate);
      return;
    }

    _state = DashboardState.loading;
    _errorMessage = null;
    notifyListeners();

    await _startDashboardStream(
      salesmanName: _salesmanIdentifier!,
      date: _selectedDate,
    );
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

  Future<void> _startDashboardStream({
    required String salesmanName,
    required DateTime date,
  }) async {
    await _dashboardSubscription?.cancel();

    _dashboardSubscription = _repository
        .watchDashboardData(salesmanName: salesmanName, date: date)
        .listen(
          (data) {
            _dashboardData = data;
            _state = DashboardState.loaded;
            _errorMessage = null;
            notifyListeners();
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Dashboard stream error: $error');
            debugPrint('StackTrace: $stackTrace');

            _state = DashboardState.error;
            _errorMessage = error.toString();
            _dashboardData = null;
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _dashboardSubscription?.cancel();
    super.dispose();
  }
}
