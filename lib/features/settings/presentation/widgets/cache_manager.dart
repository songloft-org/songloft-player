import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/storage/lyric_cache_service.dart';
import '../../../../core/storage/preference_sync_service.dart';
import '../../../../core/utils/web_cache_clearer.dart' as web_cache;
import '../../../../shared/utils/responsive_snackbar.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../playlist/presentation/providers/playlist_provider.dart';
import '../../data/cache_api.dart';
import '../providers/settings_provider.dart';
import '../providers/song_cache_provider.dart';

String _formatSize(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// 缓存大小档位选项
const _cacheSizeOptions = [
  (value: 100 * 1024 * 1024, label: '100 MB'),
  (value: 500 * 1024 * 1024, label: '500 MB'),
  (value: 1024 * 1024 * 1024, label: '1 GB'),
  (value: 2 * 1024 * 1024 * 1024, label: '2 GB'),
  (value: 5 * 1024 * 1024 * 1024, label: '5 GB'),
  (value: 10 * 1024 * 1024 * 1024, label: '10 GB'),
];

/// 缓存管理 Widget
///
/// 管理服务端音乐缓存和本地缓存（音频 + 图片 + 歌词）。
/// 作为设置页面的一个分组卡片内容。
class CacheManager extends ConsumerStatefulWidget {
  const CacheManager({super.key});

  @override
  ConsumerState<CacheManager> createState() => _CacheManagerState();
}

class _CacheManagerState extends ConsumerState<CacheManager> {
  bool _isCleaningServer = false;
  bool _isCleaningLocal = false;
  bool _isCleaningBrowser = false;
  bool _serverExpanded = false;
  bool _localExpanded = false;
  int _localCacheSize = 0;
  bool _localCacheSizeLoaded = false;
  int _localCacheMaxSizeIndex = 2; // 默认 1 GB（索引 2）
  bool _localConfigLoaded = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _loadLocalCacheSize();
      _loadLocalCacheConfig();
    }
  }

  /// 加载本地缓存配置
  Future<void> _loadLocalCacheConfig() async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      final maxSize = prefs.getLocalCacheMaxSize();
      if (mounted) {
        setState(() {
          _localCacheMaxSizeIndex = _findSizeIndex(maxSize);
          _localConfigLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('[CacheManager] 加载本地缓存配置失败: $e');
    }
  }

  /// 保存本地缓存大小配置
  Future<void> _saveLocalCacheMaxSize(int index) async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      final maxSize = _cacheSizeOptions[index].value;
      await prefs.setLocalCacheMaxSize(maxSize);
      pushPreferencesToServer(ref.read(dioProvider));
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context,
            message: AppLocalizations.of(context).settingsCacheSaveConfigFailed(
                e.toString()));
      }
    }
  }

  /// 加载本地缓存大小
  Future<void> _loadLocalCacheSize() async {
    int total = 0;

    // 歌词缓存大小
    total += await LyricCacheService().getCacheSize();

    // just_audio 缓存大小（临时目录中的 just_audio_cache）
    try {
      final tempDir = await getTemporaryDirectory();
      final audioCacheDir = Directory('${tempDir.path}/just_audio_cache');
      if (await audioCacheDir.exists()) {
        await for (final entity in audioCacheDir.list(recursive: true)) {
          if (entity is File) {
            total += await entity.length();
          }
        }
      }
    } catch (e) {
      debugPrint('[CacheManager] 获取音频缓存大小失败: $e');
    }

    // cached_network_image 图片缓存大小
    try {
      final tempDir = await getTemporaryDirectory();
      final imageCacheDir =
          Directory('${tempDir.path}/libCachedImageData');
      if (await imageCacheDir.exists()) {
        await for (final entity in imageCacheDir.list(recursive: true)) {
          if (entity is File) {
            total += await entity.length();
          }
        }
      }
    } catch (e) {
      debugPrint('[CacheManager] 获取图片缓存大小失败: $e');
    }

    if (mounted) {
      setState(() {
        _localCacheSize = total;
        _localCacheSizeLoaded = true;
      });
    }
  }

  /// 清理服务端缓存
  Future<void> _cleanServerCache() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _showConfirmDialog(
      title: l10n.settingsCacheCleanServerTitle,
      content: l10n.settingsCacheCleanServerContent,
    );
    if (confirmed != true) return;

    setState(() => _isCleaningServer = true);
    try {
      final cacheApi = ref.read(cacheApiProvider);
      await cacheApi.cleanCache();
      // 刷新统计数据
      ref.invalidate(serverCacheStatsProvider);
      if (mounted) {
        ResponsiveSnackBar.show(context,
            message: AppLocalizations.of(context).settingsCacheServerCleaned);
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context,
            message: AppLocalizations.of(context)
                .settingsCacheCleanFailed(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isCleaningServer = false);
    }
  }

  /// 清理本地缓存
  Future<void> _cleanLocalCache() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _showConfirmDialog(
      title: l10n.settingsCacheCleanLocalTitle,
      content: l10n.settingsCacheCleanLocalContent,
    );
    if (confirmed != true) return;

    setState(() => _isCleaningLocal = true);
    try {
      // 清理歌词缓存
      await LyricCacheService().clear();

      // 清理 just_audio 缓存
      try {
        final tempDir = await getTemporaryDirectory();
        final audioCacheDir = Directory('${tempDir.path}/just_audio_cache');
        if (await audioCacheDir.exists()) {
          await audioCacheDir.delete(recursive: true);
        }
      } catch (e) {
        debugPrint('[CacheManager] 清理音频缓存失败: $e');
      }

      // 清理 cached_network_image 图片缓存
      try {
        final tempDir = await getTemporaryDirectory();
        final imageCacheDir =
            Directory('${tempDir.path}/libCachedImageData');
        if (await imageCacheDir.exists()) {
          await imageCacheDir.delete(recursive: true);
        }
      } catch (e) {
        debugPrint('[CacheManager] 清理图片缓存失败: $e');
      }

      // 重新加载本地缓存大小
      await _loadLocalCacheSize();

      if (mounted) {
        ResponsiveSnackBar.show(context,
            message: AppLocalizations.of(context).settingsCacheLocalCleaned);
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context,
            message: AppLocalizations.of(context)
                .settingsCacheCleanFailed(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isCleaningLocal = false);
    }
  }

  /// 清理浏览器缓存（Cache Storage + Service Worker）
  Future<void> _cleanBrowserCache() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _showConfirmDialog(
      title: l10n.settingsCacheCleanBrowserTitle,
      content: l10n.settingsCacheCleanBrowserContent,
    );
    if (confirmed != true) return;

    setState(() => _isCleaningBrowser = true);
    try {
      await web_cache.clearBrowserCache();
      web_cache.reloadPage();
    } catch (e) {
      if (mounted) {
        setState(() => _isCleaningBrowser = false);
        ResponsiveSnackBar.showError(context,
            message: AppLocalizations.of(context)
                .settingsCacheCleanFailed(e.toString()));
      }
    }
  }

  /// 更新服务端缓存配置（仅 maxSize），保留其他字段
  Future<void> _updateServerCacheConfig(int maxSize) async {
    try {
      final cacheApi = ref.read(cacheApiProvider);
      final current = ref.read(serverCacheConfigProvider).value;
      await cacheApi.updateCacheConfig(CacheConfig(
        maxSize: maxSize,
        cacheDir: current?.cacheDir ?? '',
        transcodeFormat: current?.transcodeFormat ?? '',
        transcodeQuality: current?.transcodeQuality ?? '',
      ));
      ref.invalidate(serverCacheConfigProvider);
      ref.invalidate(serverCacheStatsProvider);
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context,
            message: AppLocalizations.of(context)
                .settingsCacheUpdateConfigFailed(e.toString()));
      }
    }
  }

  /// 修改缓存目录
  Future<void> _editCacheDir(CacheConfig config) async {
    final cacheApi = ref.read(cacheApiProvider);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _CacheDirDialog(
        cacheApi: cacheApi,
        currentDir: config.cacheDir,
        defaultDir: config.defaultCacheDir,
      ),
    );
    if (result == null || result == config.cacheDir) return;
    try {
      final api = ref.read(cacheApiProvider);
      await api.updateCacheConfig(CacheConfig(
        maxSize: config.maxSize,
        cacheDir: result,
        transcodeFormat: config.transcodeFormat,
        transcodeQuality: config.transcodeQuality,
      ));
      ref.invalidate(serverCacheConfigProvider);
      ref.invalidate(serverCacheStatsProvider);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ResponsiveSnackBar.show(
          context,
          message: result.isEmpty
              ? l10n.settingsCacheDirRestored
              : l10n.settingsCacheDirUpdated,
        );
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context,
            message: AppLocalizations.of(context)
                .settingsCacheUpdateFailed(e.toString()));
      }
    }
  }

  /// 修改缓存转码格式（''=原始不转码 / mp3 / m4a）
  Future<void> _editTranscodeFormat(CacheConfig config) async {
    final l10n = AppLocalizations.of(context);
    final labels = <String, String>{
      '': l10n.settingsCacheTranscodeOriginal,
      'mp3': 'MP3',
      'm4a': 'M4A',
    };
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.settingsCacheTranscodeDialogTitle),
        children: [
          RadioGroup<String>(
            groupValue: config.transcodeFormat,
            onChanged: (v) => Navigator.pop(ctx, v ?? ''),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: labels.entries
                  .map((e) => RadioListTile<String>(
                        title: Text(e.value),
                        value: e.key,
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
    if (picked == null || picked == config.transcodeFormat) return;
    await _saveTranscodeConfig(config, format: picked);
  }

  /// 修改转码码率（''=最高 / 128 / 192 / 320）
  Future<void> _editTranscodeQuality(CacheConfig config) async {
    final l10n = AppLocalizations.of(context);
    final labels = <String, String>{
      '': l10n.settingsCacheTranscodeQualityHighest,
      '128': '128 kbps',
      '192': '192 kbps',
      '320': '320 kbps',
    };
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.settingsCacheTranscodeQualityDialogTitle),
        children: [
          RadioGroup<String>(
            groupValue: config.transcodeQuality,
            onChanged: (v) => Navigator.pop(ctx, v ?? ''),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: labels.entries
                  .map((e) => RadioListTile<String>(
                        title: Text(e.value),
                        value: e.key,
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
    if (picked == null || picked == config.transcodeQuality) return;
    await _saveTranscodeConfig(config, quality: picked);
  }

  /// 保存转码设置（format/quality 二选一变更，其余字段沿用当前配置）
  Future<void> _saveTranscodeConfig(CacheConfig config,
      {String? format, String? quality}) async {
    try {
      final api = ref.read(cacheApiProvider);
      await api.updateCacheConfig(CacheConfig(
        maxSize: config.maxSize,
        cacheDir: config.cacheDir,
        transcodeFormat: format ?? config.transcodeFormat,
        transcodeQuality: quality ?? config.transcodeQuality,
      ));
      ref.invalidate(serverCacheConfigProvider);
      if (mounted) {
        ResponsiveSnackBar.show(
          context,
          message: AppLocalizations.of(context).settingsCacheTranscodeUpdated,
        );
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context,
            message: AppLocalizations.of(context)
                .settingsCacheUpdateConfigFailed(e.toString()));
      }
    }
  }

  /// 显示确认对话框
  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(l10n.settingsCacheConfirmClean),
            ),
          ],
        );
      },
    );
  }

  /// 根据 maxSize 值找到对应的档位索引
  int _findSizeIndex(int maxSize) {
    for (int i = 0; i < _cacheSizeOptions.length; i++) {
      if (_cacheSizeOptions[i].value == maxSize) return i;
    }
    // 默认 1 GB（索引 2）
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 服务端音乐缓存
          _buildServerCacheSection(theme, colorScheme),

          // 浏览器缓存（仅 Web 平台显示）
          if (kIsWeb) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            _buildBrowserCacheSection(theme, colorScheme),
          ],

          // 本地缓存（仅非 Web 平台显示）
          if (!kIsWeb) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            _buildLocalCacheSection(theme, colorScheme),
          ],

          // 本机歌曲缓存（用户手动缓存的单曲，仅非 Web，songloft-org/songloft#312）
          if (!kIsWeb) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            _buildDeviceSongCacheSection(theme, colorScheme),
          ],
        ],
      ),
    );
  }

  /// 本机歌曲缓存：展示用户手动缓存的单曲列表，可单删或整体清空。
  Widget _buildDeviceSongCacheSection(ThemeData theme, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context);
    // watch 修订号，缓存增删后刷新列表。
    ref.watch(songCacheProvider);
    final notifier = ref.read(songCacheProvider.notifier);
    final singles = notifier.manualEntries
      ..sort((a, b) => b.cachedAt.compareTo(a.cachedAt));
    final groups = notifier.playlistGroups();
    final totalSize = notifier.totalSize();
    final isEmpty = singles.isEmpty && groups.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.download_done_rounded, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.localSongCacheTitle,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              l10n.localSongCacheSummary(singles.length, _formatSize(totalSize)),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isEmpty)
          Text(
            l10n.localSongCacheEmpty,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          )
        else ...[
          // 已缓存歌单
          if (groups.isNotEmpty) ...[
            Text(
              l10n.localSongCachePlaylists,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            for (final entry in groups.entries)
              _buildPlaylistCacheTile(
                theme,
                colorScheme,
                entry.key,
                entry.value.length,
                entry.value.fold<int>(0, (s, e) => s + e.size),
                notifier,
              ),
            const SizedBox(height: 8),
          ],
          // 已缓存单曲
          if (singles.isNotEmpty)
            Text(
              l10n.localSongCacheSingles,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          for (final e in singles)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${e.artist?.isNotEmpty == true ? '${e.artist} · ' : ''}'
                '${_formatSize(e.size)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline, color: colorScheme.error),
                onPressed: () => notifier.removeSong(e.songId),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final ok = await ConfirmDialog.show(
                  context,
                  title: l10n.localSongCacheClearAll,
                  content: l10n.localSongCacheClearAllConfirm,
                  isDestructive: true,
                );
                if (ok) await notifier.clearAll();
              },
              icon: const Icon(Icons.delete_sweep_outlined),
              label: Text(l10n.localSongCacheClearAll),
            ),
          ),
        ],
      ],
    );
  }

  /// 已缓存歌单条目：名称经 playlistDetailProvider 异步解析，缺失回退「#id」。
  Widget _buildPlaylistCacheTile(
    ThemeData theme,
    ColorScheme colorScheme,
    int playlistId,
    int count,
    int size,
    SongCacheNotifier notifier,
  ) {
    final l10n = AppLocalizations.of(context);
    final nameAsync = ref.watch(playlistDetailProvider(playlistId));
    final name = nameAsync.value?.name ?? '#$playlistId';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.playlist_play_rounded),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(l10n.localSongCacheSummary(count, _formatSize(size))),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, color: colorScheme.error),
        onPressed: () => notifier.removePlaylist(playlistId),
      ),
    );
  }

  /// 构建服务端缓存区域
  Widget _buildServerCacheSection(ThemeData theme, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context);
    final statsAsync = ref.watch(serverCacheStatsProvider);
    final configAsync = ref.watch(serverCacheConfigProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.cloud_outlined, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.settingsCacheServerTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _serverExpanded = !_serverExpanded),
              icon: Icon(
                _serverExpanded ? Icons.expand_less : Icons.tune,
                size: 18,
              ),
              label:
                  Text(_serverExpanded ? l10n.collapse : l10n.settingsCacheManage),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 缓存统计
        statsAsync.when(
          data: (stats) {
            final maxSize = stats.maxSize;
            final progress =
                maxSize > 0 ? (stats.totalSize / maxSize).clamp(0.0, 1.0) : 0.0;
            final sizeText = maxSize > 0
                ? '${_formatSize(stats.totalSize)} / ${_formatSize(maxSize)}'
                : l10n.settingsCacheNoLimit(_formatSize(stats.totalSize));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(sizeText, style: theme.textTheme.bodyMedium),
                    Text(
                      l10n.settingsCacheFileCount(stats.fileCount),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (maxSize > 0)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor:
                          colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress > 0.9
                            ? colorScheme.error
                            : colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
          error: (e, _) => Text(
            l10n.settingsCacheStatsLoadFailed,
            style: TextStyle(color: colorScheme.error),
          ),
        ),

        // 折叠区域：Slider + 清理按钮
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // 缓存目录
              configAsync.when(
                data: (config) {
                  final dir = config.cacheDir.isNotEmpty
                      ? config.cacheDir
                      : config.defaultCacheDir;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(l10n.settingsCacheDirTitle),
                    subtitle: Text(
                      dir.isNotEmpty ? dir : l10n.settingsCacheNotConfigured,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _editCacheDir(config),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),

              // 缓存转码格式
              configAsync.when(
                data: (config) {
                  final fmt = config.transcodeFormat;
                  final fmtLabel = fmt.isEmpty
                      ? l10n.settingsCacheTranscodeOriginal
                      : fmt.toUpperCase();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.transform_outlined),
                        title: Text(l10n.settingsCacheTranscodeTitle),
                        subtitle: Text(
                          fmt.isEmpty
                              ? l10n.settingsCacheTranscodeDesc
                              : '$fmtLabel · ${l10n.settingsCacheTranscodeDesc}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(fmtLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                )),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => _editTranscodeFormat(config),
                      ),
                      // 转码码率（仅在开启转码后显示）
                      if (fmt.isNotEmpty)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.speed_outlined),
                          title: Text(l10n.settingsCacheTranscodeQualityTitle),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                config.transcodeQuality.isEmpty
                                    ? l10n.settingsCacheTranscodeQualityHighest
                                    : '${config.transcodeQuality} kbps',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () => _editTranscodeQuality(config),
                        ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),

              // 最大缓存大小滑动条
              configAsync.when(
                data: (config) {
                  int currentIndex = _findSizeIndex(config.maxSize);
                  return StatefulBuilder(
                    builder: (context, setSliderState) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.settingsCacheMaxSize(
                                _cacheSizeOptions[currentIndex].label),
                            style: theme.textTheme.bodyMedium,
                          ),
                          Slider(
                            value: currentIndex.toDouble(),
                            min: 0,
                            max: (_cacheSizeOptions.length - 1).toDouble(),
                            divisions: _cacheSizeOptions.length - 1,
                            label: _cacheSizeOptions[currentIndex].label,
                            semanticFormatterCallback: (value) {
                              return _cacheSizeOptions[value.round()].label;
                            },
                            onChanged: (value) {
                              setSliderState(() {
                                currentIndex = value.round();
                              });
                            },
                            onChangeEnd: (value) {
                              final newMaxSize =
                                  _cacheSizeOptions[value.round()].value;
                              _updateServerCacheConfig(newMaxSize);
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 8),

              // 清理按钮
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isCleaningServer ? null : _cleanServerCache,
                  icon: _isCleaningServer
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  label: Text(_isCleaningServer
                      ? l10n.settingsCacheCleaning
                      : l10n.settingsCacheCleanServerButton),
                ),
              ),
            ],
          ),
          crossFadeState: _serverExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  /// 构建本地缓存区域
  Widget _buildLocalCacheSection(ThemeData theme, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.phone_android_outlined,
              size: 18,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.settingsCacheLocalTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _localExpanded = !_localExpanded),
              icon: Icon(
                _localExpanded ? Icons.expand_less : Icons.tune,
                size: 18,
              ),
              label:
                  Text(_localExpanded ? l10n.collapse : l10n.settingsCacheManage),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 本地缓存大小
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.settingsCacheSize,
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              _localCacheSizeLoaded
                  ? _formatSize(_localCacheSize)
                  : l10n.settingsCacheCalculating,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.settingsCacheLocalDesc,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),

        // 折叠区域：Slider + 清理按钮
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // 最大本地缓存大小滑动条
              if (_localConfigLoaded) ...[
                Text(
                  l10n.settingsCacheMaxLocalSize(
                      _cacheSizeOptions[_localCacheMaxSizeIndex].label),
                  style: theme.textTheme.bodyMedium,
                ),
                Slider(
                  value: _localCacheMaxSizeIndex.toDouble(),
                  min: 0,
                  max: (_cacheSizeOptions.length - 1).toDouble(),
                  divisions: _cacheSizeOptions.length - 1,
                  label: _cacheSizeOptions[_localCacheMaxSizeIndex].label,
                  semanticFormatterCallback: (value) {
                    return _cacheSizeOptions[value.round()].label;
                  },
                  onChanged: (value) {
                    setState(() {
                      _localCacheMaxSizeIndex = value.round();
                    });
                  },
                  onChangeEnd: (value) {
                    _saveLocalCacheMaxSize(value.round());
                  },
                ),
              ],

              const SizedBox(height: 8),

              // 清理按钮
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isCleaningLocal ? null : _cleanLocalCache,
                  icon: _isCleaningLocal
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  label: Text(_isCleaningLocal
                      ? l10n.settingsCacheCleaning
                      : l10n.settingsCacheCleanLocalButton),
                ),
              ),
            ],
          ),
          crossFadeState: _localExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  /// 构建浏览器缓存区域（仅 Web 平台）
  Widget _buildBrowserCacheSection(ThemeData theme, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.language_outlined, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              l10n.settingsCacheBrowserTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          l10n.settingsCacheBrowserDesc,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isCleaningBrowser ? null : _cleanBrowserCache,
            icon: _isCleaningBrowser
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_outlined),
            label: Text(_isCleaningBrowser
                ? l10n.settingsCacheCleaning
                : l10n.settingsCacheCleanBrowserButton),
          ),
        ),
      ],
    );
  }
}

/// 缓存目录编辑对话框（含验证按钮和磁盘空间显示）
class _CacheDirDialog extends StatefulWidget {
  final CacheApi cacheApi;
  final String currentDir;
  final String defaultDir;

  const _CacheDirDialog({
    required this.cacheApi,
    required this.currentDir,
    required this.defaultDir,
  });

  @override
  State<_CacheDirDialog> createState() => _CacheDirDialogState();
}

class _CacheDirDialogState extends State<_CacheDirDialog> {
  late final TextEditingController _controller;
  bool _validating = false;
  DirValidateResult? _validateResult;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentDir);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    final path = _controller.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _validating = true;
      _validateResult = null;
    });
    try {
      final result = await widget.cacheApi.validateCacheDir(path);
      if (mounted) setState(() => _validateResult = result);
    } catch (e) {
      if (mounted) {
        setState(() => _validateResult = DirValidateResult(
          valid: false,
          created: false,
          totalSize: 0,
          freeSize: 0,
          error: e.toString(),
        ));
      }
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(l10n.settingsCacheDirTitle),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settingsCacheDirDialogDesc),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: l10n.settingsCacheDirLabel,
                      hintText: widget.defaultDir,
                      helperText: l10n.settingsCacheDirDefault(widget.defaultDir),
                      helperMaxLines: 2,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      setState(() => _validateResult = null);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: OutlinedButton(
                    onPressed: _validating || _controller.text.trim().isEmpty
                        ? null
                        : _validate,
                    child: _validating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.settingsCacheValidate),
                  ),
                ),
              ],
            ),
            if (_validateResult != null) ...[
              const SizedBox(height: 12),
              _buildValidateResult(colorScheme, textTheme),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        if (widget.currentDir.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text(l10n.settingsCacheRestoreDefault),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(l10n.settingsCacheSave),
        ),
      ],
    );
  }

  Widget _buildValidateResult(ColorScheme colorScheme, TextTheme textTheme) {
    final l10n = AppLocalizations.of(context);
    final result = _validateResult!;
    if (!result.valid) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result.error ?? l10n.settingsCacheDirUnavailable,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final parts = <String>[];
    if (result.created) parts.add(l10n.settingsCacheDirCreated);
    if (result.totalSize > 0) {
      parts.add(l10n.settingsCacheDiskTotal(_formatSize(result.totalSize)));
      parts.add(l10n.settingsCacheDiskFree(_formatSize(result.freeSize)));
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${l10n.settingsCacheDirAvailable}${parts.isNotEmpty ? '  ·  ${parts.join('  ·  ')}' : ''}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
