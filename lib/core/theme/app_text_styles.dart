import 'package:flutter/material.dart';

/// One-off text styles that don't come from the Material theme's
/// `TextTheme` — most text in the app should still just use
/// `Theme.of(context).textTheme.*`, this is only for the handful of
/// places that need something the theme doesn't already express.
class AppTextStyles {
  const AppTextStyles._();

  /// The large, spaced-out digits on the PIN entry screen.
  static const pinEntry = TextStyle(fontSize: 28, letterSpacing: 8);

  /// Small bold section headers inside forms (e.g. "Remind" above the
  /// member checklist in the reminder form).
  static const sectionLabel = TextStyle(fontWeight: FontWeight.bold);
}
