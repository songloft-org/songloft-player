import '../../../shared/widgets/scrolling_text.dart';
import '../../playlist/presentation/widgets/playlist_browse_adapters.dart'
    show PlaylistCustomTags;
import 'dart:async';

import '../../../shared/widgets/network_cover_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/utils/url_helper.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/browse_card.dart';
import '../../library/presentation/providers/songs_provider.dart';
import '../../playlist/domain/playlist.dart';
import '../../player/presentation/providers/player_provider.dart';
import '../../playlist/presentation/providers/playlist_provider.dart';
import '../domain/home_grid_config.dart';
import 'providers/home_grid_config_provider.dart';
import 'providers/home_favorites_visibility_provider.dart';
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
  /// 「不限行数」自动续拉的游标：每个 type 上次是在累积到多少条时发起 loadMore 的。
  /// 同一条数只请求一次，防止上游 hasMore 恒真（或续拉拿到 0 条）时把首页拖进
  /// 无限请求循环。刷新时清空以便重新续拉。
  final Map<String, int> _autoLoadCursor = <String, int>{};

  /// 选了「不限行数」时把后续分页补齐。
  ///
  /// 在 build 里调用、经 post-frame 才真正改 provider 状态 —— build 期间直接改
  /// 会抛。重入由三层保证：notifier 自己的 isLoadingMore 同步置位、[_autoLoadCursor]
  /// 的同条数去重、以及 [kHomeAutoLoadAllMaxItems] 的硬上限。
  void _maybeAutoLoadAll(
    String type,
    PaginatedPlaylistsState? state, {
    required bool enabled,
    int targetCount = kHomeAutoLoadAllMaxItems,
  }) {
    if (!enabled || state == null) return;
    if (!state.hasMore || state.isLoadingMore) return;
    final visibility = ref.read(homeFavoritesVisibilityProvider);
    final visibleCount = state.items.where(visibility.includes).length;
    if (visibleCount >= targetCount) return;
    if (_autoLoadCursor[type] == state.items.length) return;
    _autoLoadCursor[type] = state.items.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          (type == 'radio' && !ref.read(homeRadioVisibilityProvider))) {
        return;
      }
      ref
          .read(playlistListProvider(PlaylistListQuery(type: type)).notifier)
          .loadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 只订阅两个 typed 实例。改造前还额外订阅了 playlistListProvider(null) 并在
    // 本地按 type 拆分：pageLimit=30 是两个 section 的**共享**预算，歌单一多电台
    // section 会一条都拿不到，而可配网格的 6×5=30 上限更喂不饱。typed provider
    // 各自独立 30 条，同时少发一个 HTTP 请求（songloft-org/songloft#332）。
    final normalAsync = ref.watch(
      playlistListProvider(const PlaylistListQuery(type: 'normal')),
    );
    final showRadios = ref.watch(homeRadioVisibilityProvider);
    final radioAsync =
        showRadios
            ? ref.watch(
              playlistListProvider(const PlaylistListQuery(type: 'radio')),
            )
            : null;

    // 首次加载 = 既没数据也没错误。下拉刷新时 Riverpod 保留旧值（hasValue 仍为
    // true），因此刷新不会把内容打回骨架屏。
    // 刻意不判 isLoading：Riverpod 3 的 AsyncError 上 isLoading 仍为 true，
    // 用它会让加载失败永久停在骨架屏。
    final isFirstLoad =
        (!normalAsync.hasValue && !normalAsync.hasError) ||
        (showRadios && !radioAsync!.hasValue && !radioAsync.hasError);
    // 只有两类都失败才整页报错；一类失败另一类有数据时降级为分区内联错误。
    final bothFailed =
        normalAsync.hasError && (!showRadios || radioAsync!.hasError);

    final layout = ref
        .watch(homePlaylistLayoutProvider)
        .resolve(context.useWideLayout);
    final autoLoadAll =
        layout == HomePlaylistLayout.list ||
        (layout == HomePlaylistLayout.grid &&
            ref.watch(homeGridConfigProvider).isAllRows);
    final visibility = ref.watch(homeFavoritesVisibilityProvider);
    bool hasFilteredCard(PaginatedPlaylistsState? state) =>
        state?.items.any((playlist) => !visibility.includes(playlist)) ?? false;
    _maybeAutoLoadAll(
      'normal',
      normalAsync.value,
      enabled: autoLoadAll || hasFilteredCard(normalAsync.value),
      targetCount:
          autoLoadAll
              ? kHomeAutoLoadAllMaxItems
              : PaginatedPlaylistsNotifier.pageLimit,
    );
    _maybeAutoLoadAll(
      'radio',
      radioAsync?.value,
      enabled:
          showRadios && (autoLoadAll || hasFilteredCard(radioAsync?.value)),
      targetCount:
          autoLoadAll
              ? kHomeAutoLoadAllMaxItems
              : PaginatedPlaylistsNotifier.pageLimit,
    );

    void retryAll() {
      // 清游标：刷新后 items 退回第一页，不清的话续拉会被同条数去重挡住。
      _autoLoadCursor.clear();
      ref.invalidate(
        playlistListProvider(const PlaylistListQuery(type: 'normal')),
      );
      if (showRadios) {
        ref.invalidate(
          playlistListProvider(const PlaylistListQuery(type: 'radio')),
        );
      }
      // 底部统计面板与歌单区同一次下拉刷新：它是常驻 provider（非 autoDispose），
      // 不 invalidate 就会永远停在首次加载时的数字上。
      ref.invalidate(libraryStatsProvider);
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => retryAll(),
        child: CustomScrollView(
          slivers: [
            // 顶部问候栏
            _GreetingAppBar(),

            // 主体内容
            SliverToBoxAdapter(
              child:
                  isFirstLoad
                      ? const _LoadingContent()
                      : bothFailed
                      ? _ErrorContent(
                        error:
                            (normalAsync.error ?? radioAsync?.error).toString(),
                        onRetry: retryAll,
                      )
                      : _buildContent(
                        context,
                        ref,
                        normalPlaylists: normalAsync.value?.items ?? const [],
                        radioPlaylists: radioAsync?.value?.items ?? const [],
                        normalFailed: normalAsync.hasError,
                        radioFailed: radioAsync?.hasError ?? false,
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref, {
    required List<Playlist> normalPlaylists,
    required List<Playlist> radioPlaylists,
    required bool normalFailed,
    required bool radioFailed,
  }) {
    final l10n = AppLocalizations.of(context);
    final currentPlaylistId = ref.watch(sourcePlaylistIdProvider);
    final isPlaying = ref.watch(isPlayingProvider);

    // Filter only homepage cards before layout limits; leave the shared list and labels intact.
    final visibility = ref.watch(homeFavoritesVisibilityProvider);
    normalPlaylists = normalPlaylists.where(visibility.includes).toList();
    radioPlaylists = radioPlaylists.where(visibility.includes).toList();

    // 空状态：两类都空且都没失败（失败时走分区内联错误，别误报「还没有歌单」）
    if (normalPlaylists.isEmpty &&
        radioPlaylists.isEmpty &&
        !normalFailed &&
        !radioFailed) {
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

    final isWide = context.useWideLayout;
    final layout = ref.watch(homePlaylistLayoutProvider).resolve(isWide);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.md),

            // 我的歌单区域
            if (normalPlaylists.isNotEmpty || normalFailed) ...[
              SectionHeader(
                title: l10n.homeMyPlaylists,
                trailing: _buildLayoutMenu(context),
                actionText: l10n.homeViewAll,
                // 跳转到曲库的「全部歌单」视图；即使该视图在自定义配置里被隐藏也能到达。
                onAction:
                    () => context.go('${AppRoutes.library}?view=playlist'),
              ),
              const SizedBox(height: AppSpacing.md),
              if (normalFailed && normalPlaylists.isEmpty)
                _SectionLoadError(
                  onRetry:
                      () => ref.invalidate(
                        playlistListProvider(
                          const PlaylistListQuery(type: 'normal'),
                        ),
                      ),
                )
              else if (layout == HomePlaylistLayout.list)
                _buildPlaylistList(
                  context,
                  normalPlaylists,
                  currentPlaylistId,
                  isPlaying,
                )
              else if (layout == HomePlaylistLayout.grid)
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
            if (radioPlaylists.isNotEmpty || radioFailed) ...[
              SectionHeader(
                title: l10n.homeMyRadios,
                trailing: _buildLayoutMenu(context),
                icon: Icons.radio_rounded,
                actionText: l10n.homeViewAll,
                // 跳转到曲库的「电台歌单」视图；网格按行数截断后用户需要这个出口。
                // 即使该视图在自定义配置里被隐藏也能到达（_applyInitialViewKey 会强制选中）。
                onAction:
                    () =>
                        context.go('${AppRoutes.library}?view=playlist_radio'),
              ),
              const SizedBox(height: AppSpacing.md),
              if (radioFailed && radioPlaylists.isEmpty)
                _SectionLoadError(
                  onRetry:
                      () => ref.invalidate(
                        playlistListProvider(
                          const PlaylistListQuery(type: 'radio'),
                        ),
                      ),
                )
              else if (layout == HomePlaylistLayout.list)
                _buildPlaylistList(
                  context,
                  radioPlaylists,
                  currentPlaylistId,
                  isPlaying,
                )
              else if (layout == HomePlaylistLayout.grid)
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

            // 曲库统计面板
            const StatsStrip(),
            const SizedBox(height: AppSpacing.lg),

            // 底部安全区域
            SizedBox(height: context.navScrollInset),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(homePlaylistLayoutProvider);
    final labels = <HomePlaylistLayout, String>{
      HomePlaylistLayout.adaptive: l10n.homeLayoutAdaptive,
      HomePlaylistLayout.carousel: l10n.homeLayoutCarousel,
      HomePlaylistLayout.grid: l10n.homeLayoutGrid,
      HomePlaylistLayout.list: l10n.homeLayoutList,
    };
    return PopupMenuButton<HomePlaylistLayout>(
      tooltip: l10n.homePlaylistLayout,
      icon: const Icon(Icons.view_module_outlined),
      initialValue: selected,
      onSelected: ref.read(homePlaylistLayoutProvider.notifier).setLayout,
      itemBuilder:
          (context) => [
            for (final layout in HomePlaylistLayout.values)
              CheckedPopupMenuItem(
                value: layout,
                checked: selected == layout,
                child: Text(labels[layout]!),
              ),
          ],
    );
  }

  Widget _buildPlaylistList(
    BuildContext context,
    List<Playlist> playlists,
    int? currentPlaylistId,
    bool isPlaying,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          for (final playlist in playlists)
            BrowseCard(
              layout: BrowseCardLayout.list,
              title: playlist.name,
              chips: [
                if (playlist.labels.any((label) => label.startsWith('tag:')))
                  PlaylistCustomTags(labels: playlist.labels),
              ],
              subtitle: AppLocalizations.of(
                context,
              ).homeSongCountShort(playlist.songCount),
              coverUrl: playlist.coverImageUrl,
              placeholderIcon: Icons.queue_music,
              highlighted: playlist.id == currentPlaylistId,
              highlightTitle: playlist.id == currentPlaylistId,
              isPlaying: isPlaying && playlist.id == currentPlaylistId,
              onTap: () => context.push('/playlists/${playlist.id}'),
            ),
        ],
      ),
    );
  }
}

/// 问候栏 AppBar
class _GreetingAppBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 当前播放上下文来自某歌单时，提供一键进入该歌单的快捷定位按钮，
    // 避免该歌单不在首页可视范围（被网格 maxItems 截断 / 轮播靠后）时，
    // 用户要绕去曲库「全部歌单」翻很多页才能再次进入（songloft-org/songloft#464）。
    // 与歌单详情页「定位到正在播放」同图标，呼应「和歌单内歌曲快速定位一样」。
    final sourcePlaylistId = ref.watch(sourcePlaylistIdProvider);
    return SliverAppBar(
      expandedHeight: context.responsive<double>(
        mobile: 90,
        tablet: 100,
        desktop: 110,
        widescreen: 70,
      ),
      floating: false,
      pinned: true,
      actions: [
        if (sourcePlaylistId != null)
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: AppLocalizations.of(context).homeLocatePlayingPlaylist,
            onPressed: () => context.push('/playlists/$sourcePlaylistId'),
          ),
      ],
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

/// 首页歌单网格布局。行列数可在设置 → 外观里配置
/// （songloft-org/songloft#332）。
class _PlaylistGrid extends ConsumerWidget {
  final List<Playlist> playlists;
  final int? currentPlaylistId;
  final bool isPlaying;

  const _PlaylistGrid({
    required this.playlists,
    this.currentPlaylistId,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(homeGridConfigProvider);
    final autoColumns = context.responsive<int>(
      mobile: 2,
      tablet: 3,
      desktop: 4,
    );
    final requestedColumns = config.resolveColumns(autoColumns);

    // 卡片封面下方的固定占位：sm 间距 + bodyMedium 单行 + bodySmall 单行。
    // 走 textScalerOf 让系统大字号下封面自动让位，而不是把文字挤出溢出。
    final textScaler = MediaQuery.textScalerOf(context);
    final textBlockHeight =
        AppSpacing.sm +
        textScaler.scale(20) +
        textScaler.scale(16) +
        (playlists.any(
              (playlist) =>
                  playlist.labels.any((label) => label.startsWith('tag:')),
            )
            ? textScaler.scale(16)
            : 0);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsive<double>(
          mobile: AppSpacing.md,
          tablet: AppSpacing.lg,
          desktop: AppSpacing.lg,
        ),
      ),
      // 必须用 LayoutBuilder 拿真实可用宽度，不能用 context.screenWidth：宽屏下
      // 左侧有 NavigationRail/侧边栏，外层还套着 ConstrainedBox(maxWidth: 1200)。
      child: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = computeHomeGridMetrics(
            availableWidth: constraints.maxWidth,
            requestedColumns: requestedColumns,
            spacing: AppSpacing.md,
            textBlockHeight: textBlockHeight,
          );
          // 注意传 clamp 后的列数，否则窄窗口降列时渲染的行数会多出来。
          final limit = config.maxItems(metrics.columns);
          final itemCount =
              limit == null
                  ? playlists.length
                  : (playlists.length < limit ? playlists.length : limit);

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: metrics.columns,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: metrics.childAspectRatio,
            ),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              final isCurrent = playlist.id == currentPlaylistId;
              return _GridPlaylistCard(
                playlist: playlist,
                isCurrent: isCurrent,
                isPlaying: isPlaying && isCurrent,
                cardWidth: metrics.cardWidth,
                onTap: () => context.push('/playlists/${playlist.id}'),
              );
            },
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

  /// 由 [_PlaylistGrid] 按 gridDelegate 同一口径算出并传入，用于缩放卡片内的
  /// 图标；比在卡片里再套一层 LayoutBuilder 便宜，也不会与网格口径漂移。
  final double cardWidth;
  final VoidCallback onTap;

  const _GridPlaylistCard({
    required this.playlist,
    required this.isCurrent,
    required this.isPlaying,
    required this.cardWidth,
    required this.onTap,
  });

  /// 占位封面图标：6 列时封面只有 ~90px，48px 的图标会顶满整格。
  /// 上限 48 = 改造前的字面值，且系数让 clamp 只在 cardWidth ≲ 170 时生效
  /// ⇒ 默认（3~4 列宽窗口）渲染完全不变。
  double get _placeholderIconSize => (cardWidth * 0.28).clamp(24.0, 48.0);

  /// 播放中遮罩图标，同理，上限 32 = 改造前字面值。
  double get _playingIconSize => (cardWidth * 0.19).clamp(18.0, 32.0);

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
                      border:
                          isCurrent
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
                                size: _playingIconSize,
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
              ScrollingText(
                text: playlist.name,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isCurrent ? colorScheme.primary : null,
                ),
              ),
              PlaylistCustomTags(labels: playlist.labels),
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
      errorWidget: (context, url, error) => _buildPlaceholder(colorScheme),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: Icon(
        Icons.queue_music,
        size: _placeholderIconSize,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }
}

/// 单个 section 的内联加载失败提示：另一类歌单还有数据时不该整页报错。
/// 复用现有 l10n 键，不新增文案。
class _SectionLoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _SectionLoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 20, color: colorScheme.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.commonLoadFailed,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
        ],
      ),
    );
  }
}

/// 加载中内容
class _LoadingContent extends StatefulWidget {
  const _LoadingContent();

  @override
  State<_LoadingContent> createState() => _LoadingContentState();
}

class _LoadingContentState extends State<_LoadingContent> {
  // 加载持续超过阈值仍未出内容时，露出「网络较慢，正在重试…」提示：此时首屏请求的
  // 韧性兜底（loadWithRetry，attemptTimeout=6s）已开始重试，给用户可感知的反馈，
  // 避免长时间空骨架屏被误认为卡死（songloft-org/songloft#314）。
  bool _slow = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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
          if (_slow) ...[
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    AppLocalizations.of(context).homeLoadingSlowRetrying,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
