import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Shared "something went wrong" view for any screen backed by a Firestore
/// future/stream — keeps error states across the app looking and behaving
/// the same instead of each screen inventing its own.
///
/// Pass [onRetry] for a one-shot `Future` (a retry button makes sense);
/// leave it null for a live `Stream` that will recover on its own once
/// connectivity returns.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.offline, size: 48),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
