import 'package:flutter/material.dart';

import '../../core/theme/responsive.dart';
import '../../l10n/app_localizations.dart';

class DeleteSongResult {
  final bool deleteFiles;

  const DeleteSongResult({required this.deleteFiles});
}

class DeleteSongDialog extends StatefulWidget {
  final String title;
  final String content;
  final bool showDeleteFilesOption;

  const DeleteSongDialog({
    super.key,
    required this.title,
    required this.content,
    this.showDeleteFilesOption = true,
  });

  @override
  State<DeleteSongDialog> createState() => _DeleteSongDialogState();

  static Future<DeleteSongResult?> show(
    BuildContext context, {
    required String title,
    required String content,
    bool showDeleteFilesOption = true,
  }) async {
    return showDialog<DeleteSongResult>(
      context: context,
      builder: (context) => DeleteSongDialog(
        title: title,
        content: content,
        showDeleteFilesOption: showDeleteFilesOption,
      ),
    );
  }
}

class _DeleteSongDialogState extends State<DeleteSongDialog> {
  bool _deleteFiles = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: context.responsiveDialogMaxWidth,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.content),
            if (widget.showDeleteFilesOption) ...[
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _deleteFiles,
                onChanged: (v) => setState(() => _deleteFiles = v ?? false),
                title: Text(l10n.deleteAlsoLocalFile),
                subtitle: Text(
                  l10n.deleteIrreversible,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 12,
                  ),
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            DeleteSongResult(deleteFiles: _deleteFiles),
          ),
          style: TextButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
            foregroundColor: theme.colorScheme.error,
          ),
          child: Text(l10n.commonDelete),
        ),
      ],
    );
  }
}
