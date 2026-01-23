import 'package:intl/intl.dart';

/// Formats a date to "1-Jan-2026" format (day without leading zero)
String formatDateShort(DateTime date) {
  final day = date.day; // No leading zero
  final month = DateFormat('MMM').format(date); // Abbreviated month
  final year = date.year;
  return '$day $month $year';
}

/// Truncates a bill ID to show first few characters followed by ellipsis
/// Example: "08bd292c-1d7c-4db3-be5e-9bdb7f8553d6" → "08bd292c......"
String truncateBillId(String billId, {int maxLength = 8}) {
  if (billId.length <= maxLength) {
    return billId;
  }
  return '${billId.substring(0, maxLength)}......';
}

/// Converts a string to title case
/// Example: "saad ur rehman" → "Saad Ur Rehman"
String toTitleCase(String text) {
  if (text.isEmpty) return text;

  return text
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      })
      .join(' ');
}

/// Formats customer name - if it's a UUID (bill ID), shows first 8 characters with ellipsis,
/// otherwise applies toTitleCase
/// Example: "08bd292c-1d7c-4db3-be5e-9bdb7f8553d6" → "08bd292c......"
/// Example: "saad ur rehman" → "Saad Ur Rehman"
String formatCustomerName(String name, {int maxLength = 8}) {
  // Check if name looks like a UUID (contains hyphens and is long)
  final isUuid = name.contains('-') && name.length > 30;
  if (isUuid) {
    if (name.length <= maxLength) {
      return name;
    }
    return 'Bill # ${name.substring(0, maxLength)}......';
  }
  return toTitleCase(name);
}

/// Formats a cash amount by adding commas as thousand separators.
///
/// This method is used across the application to display
/// cash values such as:
/// - Grand Total
/// - Total Cash Recovered
/// - Other monetary amounts
///
/// Example:
/// - 2500 → "2,500"
/// - 1250000 → "1,250,000"
String formatCashAmount(int amount) {
  return amount.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
}
