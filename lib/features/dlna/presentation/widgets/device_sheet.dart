import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
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

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.cast),
                const SizedBox(width: 12),
                Text(
                  l10n.dlnaCast,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
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
          if (dlnaState.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                dlnaState.error!,
                style: TextStyle(color: colorScheme.error),
              ),
            ),
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
                  dlnaState.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
                onPressed: () {
                  ref.read(dlnaStateProvider.notifier).togglePlay();
                },
              ),
            ),
          if (!dlnaState.isCasting) ...[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: dlnaState.devices.isEmpty
                  ? _buildEmptyState(dlnaState.isDiscovering)
                  : _buildDeviceList(dlnaState.devices),
            ),
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
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(l10n.dlnaSearching),
                ],
              ),
            ),
          const SizedBox(height: 8),
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

  Widget _buildDeviceList(List<DlnaDeviceInfo> devices) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
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
      },
    );
  }
}
