import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/song_cache_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart' show audioHandlerProvider;
import '../../../../shared/utils/responsive_snackbar.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../providers/song_cache_provider.dart';

/// Android device storage controls; server cache settings are a separate UI.
class DeviceCacheDirectory extends ConsumerStatefulWidget {
  const DeviceCacheDirectory({super.key});

  @override
  ConsumerState<DeviceCacheDirectory> createState() =>
      _DeviceCacheDirectoryState();
}

class _DeviceCacheDirectoryState extends ConsumerState<DeviceCacheDirectory> {
  late final SongCacheService _service;
  bool _ready = false;
  bool _supported = false;
  bool _busy = false;
  bool _unavailable = false;
  CancelToken? _migration;
  int _done = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _service = ref.read(songCacheServiceProvider);
    _init();
  }

  Future<void> _init() async {
    try {
      await _service.load();
      _supported = await _service.supportsDirectorySelection();
      if (_supported) await _service.validateDirectory();
    } catch (_) {
      _unavailable = true;
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _migration?.cancel('cache settings closed');
    super.dispose();
  }

  Future<void> _perform(
    Future<bool> Function() action, {
    bool migrating = false,
  }) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    if (_service.isBusy) {
      ResponsiveSnackBar.showError(
        context,
        message: l10n.deviceCacheDirectoryBusy,
      );
      return;
    }
    final notifier = ref.read(songCacheProvider.notifier);
    setState(() => _busy = true);
    try {
      if (!await action()) return;
      _unavailable = false;
      if (mounted) {
        ResponsiveSnackBar.showSuccess(
          context,
          message:
              migrating
                  ? l10n.deviceCacheMigrationDone
                  : l10n.deviceCacheDirectorySaved,
        );
      }
    } catch (e) {
      if (!mounted) return;
      final cancelled =
          e is DioException && CancelToken.isCancel(e) ||
          e is PlatformException && e.code == 'cancelled';
      final message =
          cancelled
              ? l10n.deviceCacheMigrationCancelled
              : e is SongCacheBusy
              ? l10n.deviceCacheDirectoryBusy
              : migrating
              ? l10n.deviceCacheMigrationFailed
              : l10n.deviceCacheDirectoryUnavailable;
      ResponsiveSnackBar.showError(context, message: message);
    } finally {
      if (mounted) {
        notifier.bump();
        setState(() {
          _busy = false;
          _migration = null;
        });
      }
    }
  }

  Future<void> _pick() => _perform(() async {
    final selected = await _service.pickDirectory();
    if (selected == null) return false;
    await _service.setDirectory(selected['uri'], selected['label']);
    return true;
  });

  Future<void> _migrate() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmDialog.show(
      context,
      title: l10n.deviceCacheMigrate,
      content: l10n.deviceCacheMigrationConfirm,
    );
    if (!confirmed || !mounted) return;
    await _perform(() async {
      final token = CancelToken();
      _migration = token;
      final handler = ref.read(audioHandlerProvider);
      if (handler.lastPlaybackSource == PlaybackSource.localCache) {
        await handler.stop();
      }
      await _service.migrate(
        cancelToken: token,
        onProgress: (done, total) {
          if (mounted) {
            setState(() {
              _done = done;
              _total = total;
            });
          }
        },
      );
      return true;
    }, migrating: true);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(songCacheProvider);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.folder_open),
          title: Text(l10n.deviceCacheDirectoryTitle),
          subtitle: Text(
            _service.directoryLabel ?? l10n.deviceCacheDirectoryDefault,
          ),
          trailing:
              !_ready || _busy
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : null,
        ),
        Text(
          l10n.deviceCacheDirectoryHelp,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_ready && !_supported)
          Text(
            l10n.deviceCacheDirectoryUpgrade,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_unavailable)
          Text(
            l10n.deviceCacheDirectoryUnavailable,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: _ready && _supported && !_busy ? _pick : null,
              icon: const Icon(Icons.folder_open),
              label: Text(l10n.deviceCacheChooseDirectory),
            ),
            if (_service.directory != null)
              TextButton(
                onPressed:
                    !_busy && _ready
                        ? () => _perform(() async {
                          await _service.setDirectory(null, null);
                          return true;
                        })
                        : null,
                child: Text(l10n.deviceCacheRestoreDefault),
              ),
            TextButton(
              onPressed:
                  _ready && _supported && !_busy && _service.totalSize() > 0
                      ? _migrate
                      : null,
              child: Text(l10n.deviceCacheMigrate),
            ),
          ],
        ),
        if (_migration != null) ...[
          LinearProgressIndicator(value: _total > 0 ? _done / _total : null),
          Text(l10n.deviceCacheMigrationProgress(_done, _total)),
          TextButton(
            onPressed: () => _migration?.cancel('user cancelled migration'),
            child: Text(l10n.songCacheCancel),
          ),
        ],
      ],
    );
  }
}
