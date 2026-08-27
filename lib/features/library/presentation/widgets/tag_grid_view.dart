import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/utils/responsive_snackbar.dart';
import '../../../../shared/widgets/browse_card.dart';
import '../../../../shared/widgets/browse_collection_view.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../playlist/presentation/providers/playlist_view_provider.dart';
import '../../data/song_tags_api.dart';
import '../providers/song_tag_provider.dart';

class TagGridView extends ConsumerStatefulWidget {
  const TagGridView({super.key});

  @override
  ConsumerState<TagGridView> createState() => _TagGridViewState();
}

class _TagGridViewState extends ConsumerState<TagGridView> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.text =
        ref.read(songTagListProvider).value?.keyword ?? '';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(songTagListProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(songTagListProvider.notifier).search(value);
    });
  }

  Future<void> _renameTag(SongTag tag) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: tag.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.renameTag),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.createTagHint),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == tag.name) return;
    if (!mounted) return;
    try {
      final api = ref.read(songTagsApiProvider);
      await api.update(tag.id, name: newName);
      ref.invalidate(songTagListProvider);
      if (mounted) {
        ResponsiveSnackBar.showSuccess(context, message: l10n.tagRenamed);
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: e.toString());
      }
    }
  }

  Future<void> _deleteTag(SongTag tag) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.commonDelete),
        content: Text(l10n.deleteTagConfirm(tag.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final api = ref.read(songTagsApiProvider);
      await api.delete(tag.id);
      ref.invalidate(songTagListProvider);
      if (mounted) {
        ResponsiveSnackBar.showSuccess(context, message: l10n.tagDeleted);
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(songTagListProvider);

    return Column(
      children: [
        _buildSearchBar(context),
        Expanded(
          child: asyncState.when(
            data: (state) => _buildContent(context, state),
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (error, _) => ErrorView(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(songTagListProvider),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final horizontalPadding = context.responsive<double>(
      mobile: AppSpacing.md,
      tablet: AppSpacing.lg,
      desktop: AppSpacing.xl,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        AppSpacing.sm,
        horizontalPadding,
        0,
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: l10n.categorySearchHint(l10n.songTags),
          prefixIcon: const Icon(Icons.search),
          suffixIcon:
              _searchController.text.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: l10n.clearSearch,
                    onPressed: () {
                      _searchController.clear();
                      ref.read(songTagListProvider.notifier).search('');
                    },
                  )
                  : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildContent(BuildContext context, SongTagListState state) {
    final l10n = AppLocalizations.of(context);

    if (state.items.isEmpty) {
      if (state.keyword.trim().isNotEmpty) {
        return EmptyState(
          icon: Icons.search_off,
          title: l10n.categoryNoMatch(l10n.songTags),
          subtitle: l10n.libraryTryOtherKeywords,
        );
      }
      return EmptyState(
        icon: Icons.label_off_outlined,
        title: l10n.noTags,
        subtitle: '',
      );
    }

    final layout =
        ref.watch(playlistViewModeProvider) == PlaylistViewMode.list
            ? BrowseCardLayout.list
            : BrowseCardLayout.grid;

    return BrowseCollectionView(
      layout: layout,
      itemCount: state.items.length,
      scrollController: _scrollController,
      isLoadingMore: state.isLoadingMore,
      onRefresh: () async => ref.invalidate(songTagListProvider),
      cardBuilder: (context, index) {
        final tag = state.items[index];
        return BrowseCard(
          layout: layout,
          coverUrl: tag.coverUrl.isNotEmpty ? tag.coverUrl : null,
          placeholderIcon: Icons.label_outline,
          title: tag.name,
          subtitle: l10n.categorySongCount(tag.songCount),
          menuActions: [
            BrowseCardAction(
              value: 'rename',
              icon: Icons.edit_outlined,
              label: l10n.renameTag,
              onTap: () => _renameTag(tag),
            ),
            BrowseCardAction(
              value: 'delete',
              icon: Icons.delete_outline,
              label: l10n.commonDelete,
              onTap: () => _deleteTag(tag),
              destructive: true,
            ),
          ],
          onTap: () {
            context.push(
              Uri(
                path: '/library/tags/${tag.id}',
                queryParameters: {
                  'name': tag.name,
                  if (tag.coverUrl.isNotEmpty) 'cover': tag.coverUrl,
                },
              ).toString(),
            );
          },
        );
      },
    );
  }
}
