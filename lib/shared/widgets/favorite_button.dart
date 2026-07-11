import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../features/library/presentation/providers/favorite_provider.dart';
import '../../l10n/app_localizations.dart';
import '../utils/responsive_snackbar.dart';

class FavoriteButton extends ConsumerStatefulWidget {
  final int songId;
  final String songType;
  final double size;
  final void Function(bool isFavorited)? onToggle;

  const FavoriteButton({
    super.key,
    required this.songId,
    this.songType = 'local',
    this.size = 24,
    this.onToggle,
  });

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.3,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool get _isRadio => widget.songType == AppConstants.songTypeRadio;

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    _animationController.forward(from: 0);

    final isFavorited = _isRadio
        ? ref.read(isRadioFavoritedProvider(widget.songId))
        : ref.read(isSongFavoritedProvider(widget.songId));

    try {
      final notifier = ref.read(favoriteProvider.notifier);
      final newState = _isRadio
          ? await notifier.toggleRadioFavorite(widget.songId)
          : await notifier.toggleFavorite(widget.songId);

      widget.onToggle?.call(newState);

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ResponsiveSnackBar.show(
          context,
          message: newState ? l10n.favoriteAdded : l10n.favoriteRemoved,
          duration: const Duration(seconds: 1),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ResponsiveSnackBar.showError(
          context,
          message: isFavorited ? l10n.favoriteRemoveFailed : l10n.favoriteAddFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFavorited = _isRadio
        ? ref.watch(isRadioFavoritedProvider(widget.songId))
        : ref.watch(isSongFavoritedProvider(widget.songId));

    return ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        onPressed: _isLoading ? null : _toggleFavorite,
        iconSize: widget.size,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          minWidth: widget.size + 8,
          minHeight: widget.size + 8,
        ),
        icon: Icon(
          isFavorited ? Icons.favorite : Icons.favorite_border,
          color:
              isFavorited
                  ? Colors.red
                  : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        tooltip:
            isFavorited
                ? AppLocalizations.of(context).unfavorite
                : AppLocalizations.of(context).favorite,
      ),
    );
  }
}
