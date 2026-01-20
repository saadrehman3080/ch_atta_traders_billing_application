import 'package:intl/intl.dart';

/// Centralized date formatting utilities for Firebase paths.
///
/// These formatters always use English locale to ensure consistent
/// path naming across all devices regardless of their locale settings.
class DateFormatters {
  DateFormatters._();

  /// Formats a date for Firebase document paths.
  /// Format: dd-MMM-yyyy (e.g., "01-Jan-2026")
  ///
  /// Always uses English locale for consistency.
  static String formatForFirebase(DateTime date) {
    return DateFormat('dd-MMM-yyyy', 'en_US').format(date);
  }

  /// Formats a date for deleted history paths.
  /// Format: d-MMM-yyyy (e.g., "1-Jan-2026")
  ///
  /// Always uses English locale for consistency.
  static String formatForDeleteHistory(DateTime date) {
    return DateFormat('d-MMM-yyyy', 'en_US').format(date);
  }
}
