import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 错误视图组件
/// 用于显示错误状态和重试按钮
class ErrorView extends StatelessWidget {
  /// 错误消息
  final String? message;

  /// 重试回调
  final VoidCallback? onRetry;

  /// 是否为网络错误
  final bool isNetworkError;

  /// 图标大小
  final double iconSize;

  const ErrorView({
    super.key,
    this.message,
    this.onRetry,
    this.isNetworkError = false,
    this.iconSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNetworkError ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: iconSize,
              color: theme.colorScheme.error.withAlpha(180),
            ),
            const SizedBox(height: 16),
            Text(
              isNetworkError ? l10n.errorNetworkFailed : l10n.errorGeneric,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.commonRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
