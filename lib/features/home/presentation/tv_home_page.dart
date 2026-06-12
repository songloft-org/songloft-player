import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/tv_focusable.dart';

class TvHomePage extends StatelessWidget {
  const TvHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface, // Follow theme
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0), // Overscan padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Songloft TV',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // TODO: The target pages (library, playlists, settings) currently lack D-Pad focus optimization.
                    // This will be implemented in subsequent phases of the TV adaptation.
                    _buildTvCard(context, '本地音乐', Icons.library_music, autofocus: true, onSelect: () => context.go(AppRoutes.library)),
                    const SizedBox(width: 24),
                    _buildTvCard(context, '播放列表', Icons.queue_music, onSelect: () => context.go(AppRoutes.playlists)),
                    const SizedBox(width: 24),
                    _buildTvCard(context, '设置', Icons.settings, onSelect: () => context.go(AppRoutes.settings)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTvCard(BuildContext context, String title, IconData icon, {bool autofocus = false, VoidCallback? onSelect}) {
    return TvFocusable(
      autofocus: autofocus,
      onSelect: onSelect,
      child: Container(
        width: 240,
        height: 180,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 24),
            ),
          ],
        ),
      ),
    );
  }
}
