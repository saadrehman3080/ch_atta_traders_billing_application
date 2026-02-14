import 'package:flutter/services.dart';

/// Utility class for haptic feedback on user interactions.
/// Provides consistent tactile feedback across the app.
class AppHaptics {
  /// Light impact — for normal button taps, card selections
  static void lightImpact() {
    HapticFeedback.lightImpact();
  }

  /// Medium impact — for confirmations, toggles, important actions
  static void mediumImpact() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy impact — for destructive actions (delete, logout)
  static void heavyImpact() {
    HapticFeedback.heavyImpact();
  }

  /// Selection click — for tab switches, option selections
  static void selectionClick() {
    HapticFeedback.selectionClick();
  }

  /// Vibrate — for errors, warnings
  static void vibrate() {
    HapticFeedback.vibrate();
  }
}
