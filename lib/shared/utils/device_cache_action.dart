import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'responsive_snackbar.dart';

/// Keep failures from detached volumes visible at every cache removal entry.
Future<void> runDeviceCacheRemoval(
  BuildContext context,
  Future<void> Function() action, {
  String? successMessage,
}) async {
  final l10n = AppLocalizations.of(context);
  try {
    await action();
    if (context.mounted && successMessage != null) {
      ResponsiveSnackBar.showSuccess(context, message: successMessage);
    }
  } catch (_) {
    if (context.mounted) {
      ResponsiveSnackBar.showError(
        context,
        message: l10n.deviceCacheClearFailed,
      );
    }
  }
}
