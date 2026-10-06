import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/widgets/glass_surface.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/dlna_log.dart';
import '../../domain/dlna_state.dart';
import '../providers/dlna_provider.dart';

class DlnaDeviceSheet extends ConsumerStatefulWidget {
  const DlnaDeviceSheet({super.key});

  @override
  ConsumerState<DlnaDeviceSheet> createState() => _DlnaDeviceSheetState();
}

class _DlnaDeviceSheetState extends ConsumerState<DlnaDeviceSheet> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(dlnaStateProvider.notifier).startDiscovery();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dlnaState = ref.watch(dlnaStateProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return GlassSurface(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      strong: true,
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.cast),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.dlnaCast,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (dlnaState.isCasting)
                        TextButton(
                          onPressed: () {
                            ref.read(dlnaStateProvider.notifier).disconnect();
                            Navigator.pop(context);
                          },
                          child: Text(l10n.dlnaDisconnect),
                        ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      if (dlnaState.error != null)
                        _buildError(dlnaState.error!),
                      if (dlnaState.isCasting && dlnaState.activeDevice != null)
                        ListTile(
                          leading: Icon(
                            Icons.cast_connected,
                            color: colorScheme.primary,
                          ),
                          title: Text(dlnaState.activeDevice!.name),
                          subtitle: Text(l10n.dlnaConnected),
                          trailing: IconButton(
                            icon: Icon(
                              dlnaState.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                            ),
                            onPressed: () {
                              ref.read(dlnaStateProvider.notifier).togglePlay();
                            },
                          ),
                        ),
                      if (!dlnaState.isCasting) ...[
                        if (dlnaState.devices.isEmpty)
                          _buildEmptyState(dlnaState.isDiscovering)
                        else
                          ...dlnaState.devices.map(_buildDeviceTile),
                      ],
                      if (dlnaState.isDiscovering)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(child: Text(l10n.dlnaSearching)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: colors.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.dlnaError,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
              IconButton(
                tooltip: l10n.dlnaErrorDetails,
                color: colors.onErrorContainer,
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showErrorDetails(error),
              ),
              IconButton(
                tooltip: l10n.dlnaDismissError,
                color: colors.onErrorContainer,
                icon: const Icon(Icons.close),
                onPressed:
                    () => ref.read(dlnaStateProvider.notifier).clearError(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDetails(String error) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.dlnaErrorDetails),
            scrollable: true,
            content: SelectableText(redactDlnaTokens(error)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.dlnaClose),
              ),
            ],
          ),
    );
  }

  Widget _buildEmptyState(bool isDiscovering) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cast,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              isDiscovering
                  ? AppLocalizations.of(context).dlnaSearchingLan
                  : AppLocalizations.of(context).dlnaNoDevices,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTile(DlnaDeviceInfo device) {
    return ListTile(
      leading: const Icon(Icons.speaker_outlined),
      title: Text(device.name),
      subtitle: Text(
        Uri.parse(device.location).host,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () {
        ref.read(dlnaStateProvider.notifier).castToDevice(device);
        Navigator.pop(context);
      },
    );
  }
}
