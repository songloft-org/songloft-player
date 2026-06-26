import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/equalizer_setting.dart';
import '../providers/equalizer_provider.dart';

class EqualizerPanel extends ConsumerWidget {
  const EqualizerPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(equalizerProvider);
    final notifier = ref.read(equalizerProvider.notifier);
    final theme = Theme.of(context);
    final supported = notifier.isSupported;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(context, setting, notifier, theme),
        if (!supported)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '当前平台暂不支持均衡器',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (supported) ...[
          const SizedBox(height: 8),
          _buildPresetSelector(context, setting, notifier, theme),
          const SizedBox(height: 16),
          _buildBands(context, setting, notifier, theme),
        ],
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    EqualizerSetting setting,
    EqualizerNotifier notifier,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Icon(Icons.equalizer, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text('均衡器', style: theme.textTheme.titleMedium),
        const Spacer(),
        Switch(
          value: setting.enabled,
          onChanged: notifier.isSupported ? notifier.setEnabled : null,
        ),
      ],
    );
  }

  Widget _buildPresetSelector(
    BuildContext context,
    EqualizerSetting setting,
    EqualizerNotifier notifier,
    ThemeData theme,
  ) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: EqualizerSetting.presetLabels.entries.map((entry) {
          final isSelected = setting.preset == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: isSelected,
              onSelected: entry.key == 'custom'
                  ? null
                  : (_) => notifier.setPreset(entry.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBands(
    BuildContext context,
    EqualizerSetting setting,
    EqualizerNotifier notifier,
    ThemeData theme,
  ) {
    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(EqualizerSetting.bandCount, (index) {
          return Expanded(
            child: _BandSlider(
              index: index,
              gain: setting.bands[index],
              enabled: setting.enabled,
              onChanged: (value) => notifier.setBandGain(index, value),
            ),
          );
        }),
      ),
    );
  }
}

class _BandSlider extends StatelessWidget {
  final int index;
  final double gain;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _BandSlider({
    required this.index,
    required this.gain,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = EqualizerSetting.frequencyLabel(index);

    return Column(
      children: [
        Text(
          '${gain.round()}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: enabled
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withValues(alpha: 0.38),
          ),
        ),
        Expanded(
          child: RotatedBox(
            quarterTurns: -1,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                ),
              ),
              child: Slider(
                value: gain,
                min: EqualizerSetting.minGain,
                max: EqualizerSetting.maxGain,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: enabled
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurface.withValues(alpha: 0.38),
          ),
        ),
      ],
    );
  }
}

void showEqualizerSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => const Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: EqualizerPanel(),
    ),
  );
}
