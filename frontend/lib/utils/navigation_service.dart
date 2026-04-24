import 'package:flutter/material.dart';

/// Global navigator access for situations where a local BuildContext
/// is no longer valid (e.g., right after a route pop) but we need to
/// show a dialog/snackbar from anywhere.
class AppNavigator {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static BuildContext? get context => navigatorKey.currentContext;
}
