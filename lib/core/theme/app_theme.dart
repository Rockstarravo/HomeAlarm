import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Builds the app's single [ThemeData]. Material 3's `colorSchemeSeed`
/// derives every surface/text/error tone from [AppColors.seed], so this
/// file stays this small on purpose — see app_colors.dart to re-theme.
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    return ThemeData(
      colorSchemeSeed: AppColors.seed,
      useMaterial3: true,
    );
  }
}
