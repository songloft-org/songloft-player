import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../shared/utils/responsive_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Token 列表 Provider
final tokenListProvider = FutureProvider<TokenListResponse>((ref) async {
  final authApi = ref.watch(authApiProvider);
  return authApi.getTokens(limit: 50, offset: 0);
});

/// 令牌管理组件
class TokenManager extends ConsumerWidget {
  const TokenManager({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokensAsync = ref.watch(tokenListProvider);
    final l10n = AppLocalizations.of(context);

    return ExpansionTile(
      leading: const Icon(Icons.key),
      title: Text(l10n.settingsTokenTitle),
      subtitle: Text(l10n.settingsTokenSubtitle),
      children: [
        tokensAsync.when(
          data: (response) => _buildTokenList(context, ref, response.tokens),
          loading:
              () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
          error:
              (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      error is ApiException
                          ? error.message
                          : AppLocalizations.of(context).commonLoadFailed,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.invalidate(tokenListProvider),
                      child: Text(AppLocalizations.of(context).commonRetry),
                    ),
                  ],
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildTokenList(
    BuildContext context,
    WidgetRef ref,
    List<TokenInfo> tokens,
  ) {
    if (tokens.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(AppLocalizations.of(context).settingsTokenEmpty),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tokens.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final token = tokens[index];
        return _TokenItem(token: token);
      },
    );
  }
}

class _TokenItem extends ConsumerStatefulWidget {
  final TokenInfo token;

  const _TokenItem({required this.token});

  @override
  ConsumerState<_TokenItem> createState() => _TokenItemState();
}

class _TokenItemState extends ConsumerState<_TokenItem> {
  bool _isRevoking = false;

  Future<void> _revokeToken() async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.settingsTokenConfirmRevoke),
            content: Text(l10n.settingsTokenRevokeConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.settingsTokenRevoke),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _isRevoking = true);

    try {
      final authApi = ref.read(authApiProvider);
      await authApi.revokeToken(widget.token.tokenId);
      // 刷新列表
      ref.invalidate(tokenListProvider);
      if (mounted) {
        ResponsiveSnackBar.showSuccess(
          context,
          message: AppLocalizations.of(context).settingsTokenRevoked,
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(context).settingsTokenRevokeFailed(
            e.message,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(
            context,
          ).settingsTokenRevokeFailed('$e'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRevoking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.token;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    // 状态颜色
    Color statusColor;
    String statusText;
    if (token.isRevoked) {
      statusColor = colorScheme.error;
      statusText = l10n.settingsTokenStatusRevoked;
    } else if (token.isExpired) {
      statusColor = colorScheme.outline;
      statusText = l10n.settingsTokenStatusExpired;
    } else {
      statusColor = Colors.green;
      statusText = l10n.settingsTokenStatusActive;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.2),
        child: Icon(
          token.tokenType == 'access' ? Icons.vpn_key : Icons.refresh,
          color: statusColor,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              _truncateTokenId(token.tokenId),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusText,
              style: theme.textTheme.labelSmall?.copyWith(color: statusColor),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            l10n.settingsTokenType(
              token.tokenType == 'access'
                  ? l10n.settingsTokenTypeAccess
                  : l10n.settingsTokenTypeRefresh,
            ),
          ),
          if (token.clientInfo != null)
            Text(l10n.settingsTokenClient('${token.clientInfo}')),
          Text(l10n.settingsTokenExpiresAt(_formatDateTime(token.expiresAt))),
        ],
      ),
      trailing:
          token.isValid
              ? IconButton(
                icon:
                    _isRevoking
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.block),
                onPressed: _isRevoking ? null : _revokeToken,
                tooltip: l10n.settingsTokenRevoke,
              )
              : null,
      isThreeLine: true,
    );
  }

  String _truncateTokenId(String tokenId) {
    if (tokenId.length <= 16) return tokenId;
    return '${tokenId.substring(0, 8)}...${tokenId.substring(tokenId.length - 8)}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
