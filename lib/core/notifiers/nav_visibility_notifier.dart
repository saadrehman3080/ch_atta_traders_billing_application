import 'package:flutter/material.dart';

/// A singleton [ValueNotifier] that controls the visibility of the bottom
/// navigation bar. Set to `false` to hide, `true` to show.
class NavVisibilityNotifier {
  NavVisibilityNotifier._();

  static final ValueNotifier<bool> isVisible = ValueNotifier<bool>(true);
}
