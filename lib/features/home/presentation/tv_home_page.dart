import 'package:flutter/material.dart';
import '../../../shared/widgets/tv_focusable.dart';

class TvHomePage extends StatelessWidget {
  const TvHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Typical for TV
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0), // Overscan padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Songloft TV',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildTvCard(context, '本地音乐', Icons.library_music, autofocus: true),
                    const SizedBox(width: 24),
                    _buildTvCard(context, '播放列表', Icons.queue_music),
                    const SizedBox(width: 24),
                    _buildTvCard(context, '设置', Icons.settings),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTvCard(BuildContext context, String title, IconData icon, {bool autofocus = false}) {
    return TvFocusable(
      autofocus: autofocus,
      onSelect: () {
        // Handle selection
      },
      child: Container(
        width: 240,
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
          ],
        ),
      ),
    );
  }
}
