import '../../../shared/widgets/network_cover_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/updater/shorebird_update_prompt.dart';
import '../../../core/utils/url_helper.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../playlist/domain/playlist.dart';
import '../../player/presentation/providers/player_provider.dart';
import '../../playlist/presentation/providers/playlist_provider.dart';
import 'widgets/playlist_carousel.dart';
import 'widgets/section_header.dart';
import 'widgets/stats_strip.dart';
import '../../../features/jsplugin/presentation/widgets/jsplugin_grid.dart';
import '../../../shared/widgets/loading_indicator.dart';

/// 首页
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  /// 每个 App 会话只提示一次，避免每次回到首页都弹「重启生效」。
  static bool _patchChecked = false;

  @override
  void initState() {
    super.initState();
    // 首帧渲染后再触发，确保 Navigator/context 就绪可弹对话框。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeCheckUpdate();
    });
  }

  /// Shorebird 主动式更新流程：发现新版本 → 下载 → 提示重启。每会话检查一次。
  /// 非 Shorebird 构建（dev/web/desktop）下静默跳过。
  Future<void> _maybeCheckUpdate() async {
    if (_patchChecked) return;
    _patchChecked = true;
    if (!mounted) return;
    await maybePromptShorebirdUpdate(context);
  }

  @override
  Widget build(BuildContext context) {
    final playlistsAsync = ref.watch(playlistListProvider(null));
    final normalPlaylistsAsync = ref.watch(playlistListProvider('normal'));
    final radioPlaylistsAsync = ref.watch(playlistListProvider('radio'));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(playlistListProvider(null));
          ref.invalidate(playlistListProvider('normal'));
          ref.invalidate(playlistListProvider('radio'));
        },
        child: CustomScrollView(
          slivers: [
            // 顶部问候栏
            _GreetingAppBar(),

            // 主体内容
            SliverToBoxAdapter(
              child: playlistsAsync.when(
                data:
                    (state) => _buildContent(
                      context,
                      ref,
                      state.items,
                      normalTotalCount:
                          normalPlaylistsAsync.value?.totalCount ?? 0,
                      radioTotalCount:
                          radioPlaylistsAsync.value?.totalCount ?? 0,
                    ),
                loading: () => const _LoadingContent(),
                error:
                    (error, stack) => _ErrorContent(
                      error: error.toString(),
                      onRetry: () => ref.invalidate(playlistListProvider(null)),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<Playlist> playlists, {
    required int normalTotalCount,
    required int radioTotalCount,
  }) {
    final l10n = AppLocalizations.of(context);
    final currentPlaylistId = ref.watch(sourcePlaylistIdProvider);
    final isPlaying = ref.watch(isPlayingProvider);

    // 分离普通歌单和电台歌单
    final normalPlaylists = playlists.where((p) => p.type == 'normal').toList();
    final radioPlaylists = playlists.where((p) => p.type == 'radio').toList();

    // 空状态
    if (playlists.isEmpty) {
      return EmptyState(
        icon: Icons.library_music_outlined,
        title: l10n.homeEmptyPlaylists,
        subtitle: l10n.homeEmptyPlaylistsSubtitle,
        action: FilledButton.tonal(
          onPressed: () => context.go(AppRoutes.playlists),
          child: Text(l10n.homeCreatePlaylist),
        ),
      );
    }

    // 全站统一的宽屏布局判断（宽屏走网格，窄屏走轮播），见 context.useWideLayout
    final isWide = context.useWideLayout;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),

        // 我的歌单区域
        if (normalPlaylists.isNotEmpty) ...[
          SectionHeader(
            title: l10n.homeMyPlaylists,
            actionText: l10n.homeViewAll,
            // 跳转到曲库的「全部歌单」视图；即使该视图在自定义配置里被隐藏也能到达。
            onAction: () => context.go('${AppRoutes.library}?view=playlist'),
          ),
          const SizedBox(height: AppSpacing.md),
          if (isWide)
            _PlaylistGrid(
              playlists: normalPlaylists,
              currentPlaylistId: currentPlaylistId,
              isPlaying: isPlaying,
            )
          else
            PlaylistCarousel(
              playlists: normalPlaylists,
              currentPlaylistId: currentPlaylistId,
              isPlaying: isPlaying,
              onPlaylistTap: (playlist) {
                context.push('/playlists/${playlist.id}');
              },
            ),
          SizedBox(height: isWide ? AppSpacing.xl : AppSpacing.lg),
        ],

        // 电台歌单区域
        if (radioPlaylists.isNotEmpty) ...[
          SectionHeader(
            title: l10n.homeMyRadios,
            icon: Icons.radio_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          if (isWide)
            _PlaylistGrid(
              playlists: radioPlaylists,
              currentPlaylistId: currentPlaylistId,
              isPlaying: isPlaying,
            )
          else
            PlaylistCarousel(
              playlists: radioPlaylists,
              currentPlaylistId: currentPlaylistId,
              isPlaying: isPlaying,
              onPlaylistTap: (playlist) {
                context.push('/playlists/${playlist.id}');
              },
            ),
          SizedBox(height: isWide ? AppSpacing.xl : AppSpacing.lg),
        ],

        // JS 插件入口区域
        const JSPluginGrid(),
        const SizedBox(height: AppSpacing.lg),

        // 统计信息条
        StatsStrip(
          normalCount: normalTotalCount,
          radioCount: radioTotalCount,
        ),
        const SizedBox(height: AppSpacing.lg),

        // 底部安全区域
        SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
      ],
    ),
      ),
    );
  }

}

/// 问候栏 AppBar
class _GreetingAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: context.responsive<double>(
        mobile: 90,
        tablet: 100,
        desktop: 110,
        auto_: 70,
      ),
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          _getGreeting(context),
          style: TextStyle(
            fontSize: context.responsive<double>(
              mobile: 20,
              tablet: 22,
              desktop: 24,
            ),
            fontWeight: FontWeight.w600,
          ),
        ),
        titlePadding: EdgeInsets.only(
          left: context.responsive<double>(
            mobile: AppSpacing.md,
            desktop: AppSpacing.lg,
          ),
          bottom: 14,
        ),
      ),
    );
  }

  /// 获取问候语
  String _getGreeting(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hour = DateTime.now().hour;
    if (hour < 6) {
      return l10n.homeGreetingLateNight;
    } else if (hour < 12) {
      return l10n.homeGreetingMorning;
    } else if (hour < 14) {
      return l10n.homeGreetingNoon;
    } else if (hour < 18) {
      return l10n.homeGreetingAfternoon;
    } else {
      return l10n.homeGreetingEvening;
    }
  }
}

/// Tablet/Desktop 歌单网格布局
class _PlaylistGrid extends StatelessWidget {
  final List<Playlist> playlists;
  final int? currentPlaylistId;
  final bool isPlaying;

  const _PlaylistGrid({
    required this.playlists,
    this.currentPlaylistId,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = context.responsive<int>(
      mobile: 2,
      tablet: 3,
      desktop: 4,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsive<double>(
          mobile: AppSpacing.md,
          tablet: AppSpacing.lg,
          desktop: AppSpacing.lg,
        ),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.82,
        ),
        itemCount: playlists.length > crossAxisCount * 2
            ? crossAxisCount * 2
            : playlists.length,
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          final isCurrent = playlist.id == currentPlaylistId;
          return _GridPlaylistCard(
            playlist: playlist,
            isCurrent: isCurrent,
            isPlaying: isPlaying && isCurrent,
            onTap: () => context.push('/playlists/${playlist.id}'),
          );
        },
      ),
    );
  }
}

/// 网格布局中的歌单卡片
class _GridPlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;

  const _GridPlaylistCard({
    required this.playlist,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: l10n.homeOpenPlaylistNamed(playlist.name),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mdAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.mdAll,
                      color: colorScheme.surfaceContainerHighest,
                      border: isCurrent
                          ? Border.all(color: colorScheme.primary, width: 2)
                          : null,
                      boxShadow: AppShadows.light,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        playlist.coverImageUrl != null
                            ? _buildNetworkImage(
                                playlist.coverImageUrl!,
                                colorScheme,
                              )
                            : _buildPlaceholder(colorScheme),
                        if (isPlaying)
                          Container(
                            color: Colors.black54,
                            child: Center(
                              child: Icon(
                                Icons.equalizer_rounded,
                                size: 32,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // 歌单名称
              Text(
                playlist.name,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isCurrent ? colorScheme.primary : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // 歌曲数
              Text(
                l10n.homeSongCountShort(playlist.songCount),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkImage(String coverUrl, ColorScheme colorScheme) {
    return NetworkCoverImage(
      imageUrl: UrlHelper.buildCoverUrl(coverUrl),
      fit: BoxFit.cover,
      placeholder: (context, url) => _buildPlaceholder(colorScheme),
      errorWidget:
          (context, url, error) => _buildPlaceholder(colorScheme),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: Icon(
        Icons.queue_music,
        size: 48,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }
}

/// 加载中内容
class _LoadingContent extends StatelessWidget {
  const _LoadingContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题骨架
          SkeletonLoader(height: 20, width: 100, borderRadius: AppRadius.smAll),
          const SizedBox(height: AppSpacing.md),
          // 歌单卡片骨架行
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder:
                  (_, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader.card(size: 140),
                      const SizedBox(height: AppSpacing.sm),
                      SkeletonLoader(
                        height: 12,
                        width: 100,
                        borderRadius: AppRadius.smAll,
                      ),
                    ],
                  ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // 第二组骨架
          SkeletonLoader(height: 20, width: 80, borderRadius: AppRadius.smAll),
          const SizedBox(height: AppSpacing.md),
          // 列表骨架
          for (int i = 0; i < 3; i++) SkeletonLoader.listTile(),
        ],
      ),
    );
  }
}

/// 错误内容
class _ErrorContent extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorContent({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(l10n.commonLoadFailed, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              error,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
