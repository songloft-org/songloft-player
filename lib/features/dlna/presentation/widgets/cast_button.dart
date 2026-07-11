import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/dlna_provider.dart';
import 'device_sheet.dart';


class CastButton extends ConsumerWidget {
  final double? iconSize;
  final VisualDensity? visualDensity;

  const CastButton({super.key, this.iconSize, this.visualDensity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb) return const SizedBox.shrink();

    final isCasting = ref.watch(
      dlnaStateProvider.select((s) => s.isCasting),
    );

    return IconButton(
      icon: Icon(
        isCasting ? Icons.cast_connected : Icons.cast,
        color: isCasting
            ? Theme.of(context).colorScheme.primary
            : null,
      ),
      iconSize: iconSize,
      visualDensity: visualDensity,
      tooltip: isCasting
          ? AppLocalizations.of(context).dlnaCasting
          : AppLocalizations.of(context).dlnaCast,
      onPressed: () => _onPressed(context, ref, isCasting),
    );
  }

  void _onPressed(BuildContext context, WidgetRef ref, bool isCasting) {
    showModalBottomSheet(
      context: context,
      builder: (_) => const DlnaDeviceSheet(),
    );
  }
}
