import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../l10n/app_localizations.dart';

/// 加载指示器组件
class LoadingIndicator extends StatelessWidget {
  /// 加载提示文字（可选）
  final String? message;

  /// 指示器大小
  final double size;

  const LoadingIndicator({super.key, this.message, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 骨架屏加载组件
/// 使用 shimmer 闪烁效果模拟内容加载
class SkeletonLoader extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({super.key, this.width, this.height, this.borderRadius});

  /// 卡片骨架预设
  static Widget card({double size = 140}) {
    return SkeletonLoader(
      width: size,
      height: size,
      borderRadius: AppRadius.mdAll,
    );
  }

  /// 列表项骨架预设
  static Widget listTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          SkeletonLoader(width: 48, height: 48, borderRadius: AppRadius.smAll),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(height: 14, borderRadius: AppRadius.smAll),
                const SizedBox(height: AppSpacing.sm),
                SkeletonLoader(
                  height: 10,
                  width: 120,
                  borderRadius: AppRadius.smAll,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 圆形骨架预设
  static Widget circle({double size = 48}) {
    return SkeletonLoader(
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 2),
    );
  }

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surfaceContainerHighest;
    final highlightColor = colorScheme.surface;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? AppRadius.mdAll,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 加载遮罩组件
/// 在子组件上方叠加半透明遮罩和加载指示器
class LoadingOverlay extends StatelessWidget {
  /// 是否显示加载状态
  final bool isLoading;

  /// 子组件
  final Widget child;

  /// 加载提示文字
  final String? message;

  /// 遮罩颜色
  final Color? overlayColor;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.overlayColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: Container(
              color:
                  overlayColor ??
                  Theme.of(context).colorScheme.surface.withAlpha(200),
              child: Semantics(
                label: AppLocalizations.of(context).commonLoading,
                child: LoadingIndicator(message: message),
              ),
            ),
          ),
      ],
    );
  }
}
