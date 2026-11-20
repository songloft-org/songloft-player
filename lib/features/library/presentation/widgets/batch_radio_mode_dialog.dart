import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/song.dart';

class BatchRadioModeResult {
  final RadioMode radioMode;
  final bool updateVideo;
  final bool isVideo;

  const BatchRadioModeResult({
    required this.radioMode,
    required this.updateVideo,
    required this.isVideo,
  });
}

Future<BatchRadioModeResult?> showBatchRadioModeDialog(
  BuildContext context, {
  required int count,
}) {
  return showDialog<BatchRadioModeResult>(
    context: context,
    builder: (_) => _BatchRadioModeDialog(count: count),
  );
}

class _BatchRadioModeDialog extends StatefulWidget {
  final int count;

  const _BatchRadioModeDialog({required this.count});

  @override
  State<_BatchRadioModeDialog> createState() => _BatchRadioModeDialogState();
}

class _BatchRadioModeDialogState extends State<_BatchRadioModeDialog> {
  RadioMode _radioMode = RadioMode.automatic;
  bool _updateVideo = false;
  bool _isVideo = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final audioOnly = _radioMode == RadioMode.audioOnly;

    return AlertDialog(
      title: Text(l10n.libraryBatchRadioModeTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.libraryBatchRadioModeMessage(widget.count)),
            const SizedBox(height: 12),
            RadioGroup<RadioMode>(
              groupValue: _radioMode,
              onChanged: _selectMode,
              child: Column(
                children: [
                  RadioListTile<RadioMode>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.libraryRadioModeAuto),
                    value: RadioMode.automatic,
                  ),
                  RadioListTile<RadioMode>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.libraryRadioModeHls),
                    value: RadioMode.hls,
                  ),
                  RadioListTile<RadioMode>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.libraryRadioModeAudioOnly),
                    value: RadioMode.audioOnly,
                  ),
                  RadioListTile<RadioMode>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.libraryRadioModeFlv),
                    value: RadioMode.flv,
                  ),
                ],
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.libraryBatchRadioModeUpdateVideo),
              value: _updateVideo,
              onChanged:
                  (value) => setState(() => _updateVideo = value ?? false),
            ),
            if (_updateVideo && !audioOnly)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.libraryVideoToggleTitle),
                value: _isVideo,
                onChanged: (value) => setState(() => _isVideo = value),
              ),
            if (audioOnly)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.libraryBatchRadioModeAudioHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed:
              () => Navigator.of(context).pop(
                BatchRadioModeResult(
                  radioMode: _radioMode,
                  updateVideo: _updateVideo,
                  isVideo: _isVideo,
                ),
              ),
          child: Text(l10n.commonConfirm),
        ),
      ],
    );
  }

  void _selectMode(RadioMode? value) {
    if (value == null) return;
    setState(() {
      _radioMode = value;
      if (value == RadioMode.audioOnly) _isVideo = false;
    });
  }
}
