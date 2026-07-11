import 'package:flutter/material.dart';

import '../../../../core/theme/responsive.dart';
import '../../../../l10n/app_localizations.dart';

/// 音量控制组件
class VolumeControl extends StatefulWidget {
  final double volume; // 0-100
  final ValueChanged<double> onVolumeChanged;
  final bool showSlider; // 桌面端显示滑块，移动端可只显示图标
  final double sliderWidth;

  const VolumeControl({
    super.key,
    required this.volume,
    required this.onVolumeChanged,
    this.showSlider = true,
    this.sliderWidth = 100,
  });

  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl> {
  double? _previousVolume;

  /// 获取音量图标
  IconData get _volumeIcon {
    if (widget.volume <= 0) {
      return Icons.volume_off_rounded;
    } else if (widget.volume < 30) {
      return Icons.volume_mute_rounded;
    } else if (widget.volume < 70) {
      return Icons.volume_down_rounded;
    } else {
      return Icons.volume_up_rounded;
    }
  }

  /// 切换静音/恢复
  void _toggleMute() {
    if (widget.volume > 0) {
      // 静音
      _previousVolume = widget.volume;
      widget.onVolumeChanged(0);
    } else {
      // 恢复
      widget.onVolumeChanged(_previousVolume ?? 50);
      _previousVolume = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!widget.showSlider) {
      return IconButton(
        onPressed: _toggleMute,
        icon: Icon(_volumeIcon),
        tooltip: widget.volume > 0
            ? AppLocalizations.of(context).playerMute
            : AppLocalizations.of(context).playerUnmute,
      );
    }

    // 响应式滑块最小宽度（平板改用 PopupVolumeControl，此值仅备用）
    final sliderMinWidth = context.responsive<double>(
      mobile: 80,
      tablet: 80,
      desktop: 140,
      tv: 200,
    );

    // 响应式滑块尺寸
    final thumbRadius = context.responsive<double>(
      mobile: 6,
      tablet: 6,
      desktop: 6,
      tv: 10,
    );
    final overlayRadius = context.responsive<double>(
      mobile: 12,
      tablet: 12,
      desktop: 12,
      tv: 18,
    );
    final trackHeight = context.responsive<double>(
      mobile: 4,
      tablet: 4,
      desktop: 4,
      tv: 6,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _toggleMute,
          icon: Icon(_volumeIcon),
          tooltip: widget.volume > 0
            ? AppLocalizations.of(context).playerMute
            : AppLocalizations.of(context).playerUnmute,
          style: IconButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurfaceVariant,
          ),
          visualDensity: VisualDensity.compact,
        ),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: sliderMinWidth,
              maxWidth:
                  widget.sliderWidth > sliderMinWidth
                      ? widget.sliderWidth
                      : sliderMinWidth,
            ),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: trackHeight,
                thumbShape: RoundSliderThumbShape(
                  enabledThumbRadius: thumbRadius,
                ),
                overlayShape: RoundSliderOverlayShape(
                  overlayRadius: overlayRadius,
                ),
                activeTrackColor: theme.colorScheme.primary,
                inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
                thumbColor: theme.colorScheme.primary,
                overlayColor: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: widget.volume,
                min: 0,
                max: 100,
                onChanged: widget.onVolumeChanged,
                semanticFormatterCallback: (value) =>
                    AppLocalizations.of(context).playerVolumePercent(value.round()),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 弹出式音量控制（用于移动端，使用内联下拉面板）
class PopupVolumeControl extends StatefulWidget {
  final double volume;
  final ValueChanged<double> onVolumeChanged;

  const PopupVolumeControl({
    super.key,
    required this.volume,
    required this.onVolumeChanged,
  });

  @override
  State<PopupVolumeControl> createState() => _PopupVolumeControlState();
}

class _PopupVolumeControlState extends State<PopupVolumeControl> {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  double? _previousVolume;

  IconData get _volumeIcon {
    if (widget.volume <= 0) {
      return Icons.volume_off_rounded;
    } else if (widget.volume < 30) {
      return Icons.volume_mute_rounded;
    } else if (widget.volume < 70) {
      return Icons.volume_down_rounded;
    } else {
      return Icons.volume_up_rounded;
    }
  }

  /// 切换静音/恢复
  void _toggleMute() {
    if (widget.volume > 0) {
      _previousVolume = widget.volume;
      widget.onVolumeChanged(0);
    } else {
      widget.onVolumeChanged(_previousVolume ?? 50);
      _previousVolume = null;
    }
    _overlayEntry?.markNeedsBuild();
  }

  void _showVolumePanel() {
    _removeOverlay();

    final RenderBox? renderBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder:
          (context) => _VolumeOverlayPanel(
            volume: widget.volume,
            onVolumeChanged: (value) {
              widget.onVolumeChanged(value);
              // 强制重建 overlay 以更新音量值
              _overlayEntry?.markNeedsBuild();
            },
            onToggleMute: _toggleMute,
            onDismiss: _removeOverlay,
            anchorPosition: position,
            anchorSize: size,
            volumeIcon: _volumeIcon,
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void didUpdateWidget(PopupVolumeControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.volume != widget.volume) {
      _overlayEntry?.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: _buttonKey,
      onPressed: _showVolumePanel,
      icon: Icon(_volumeIcon),
      tooltip: AppLocalizations.of(context).playerVolume,
    );
  }
}

/// 响应式音量控制组件
/// 自动根据可用空间选择显示模式：
/// - 宽度 >= 160px：显示完整的音量控制（图标+水平滑块）
/// - 宽度 < 160px：显示弹出式音量控制（仅图标，点击弹出垂直面板）
class ResponsiveVolumeControl extends StatelessWidget {
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final double threshold;

  const ResponsiveVolumeControl({
    super.key,
    required this.volume,
    required this.onVolumeChanged,
    this.threshold = 160,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 宽度足够时显示完整的音量控制；
        // 无界约束（FittedBox / 横向滚动等场景）下退化为弹出式，避免内部 Flexible 报错
        if (constraints.maxWidth.isFinite && constraints.maxWidth >= threshold) {
          return VolumeControl(
            volume: volume,
            onVolumeChanged: onVolumeChanged,
            showSlider: true,
            sliderWidth: constraints.maxWidth - 48, // 减去图标按钮宽度
          );
        }
        // 宽度不足时显示弹出式控制
        return PopupVolumeControl(
          volume: volume,
          onVolumeChanged: onVolumeChanged,
        );
      },
    );
  }
}

/// 音量控制弹出面板（垂直布局）
class _VolumeOverlayPanel extends StatefulWidget {
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onToggleMute;
  final VoidCallback onDismiss;
  final Offset anchorPosition;
  final Size anchorSize;
  final IconData volumeIcon;

  const _VolumeOverlayPanel({
    required this.volume,
    required this.onVolumeChanged,
    required this.onToggleMute,
    required this.onDismiss,
    required this.anchorPosition,
    required this.anchorSize,
    required this.volumeIcon,
  });

  @override
  State<_VolumeOverlayPanel> createState() => _VolumeOverlayPanelState();
}

class _VolumeOverlayPanelState extends State<_VolumeOverlayPanel> {
  late double _currentVolume;

  @override
  void initState() {
    super.initState();
    _currentVolume = widget.volume;
  }

  @override
  void didUpdateWidget(_VolumeOverlayPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.volume != widget.volume) {
      _currentVolume = widget.volume;
    }
  }

  IconData get _volumeIcon {
    if (_currentVolume <= 0) {
      return Icons.volume_off_rounded;
    } else if (_currentVolume < 30) {
      return Icons.volume_mute_rounded;
    } else if (_currentVolume < 70) {
      return Icons.volume_down_rounded;
    } else {
      return Icons.volume_up_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    // 响应式面板尺寸
    final panelWidth = context.responsive<double>(
      mobile: 56,
      tablet: 60,
      desktop: 64,
      tv: 80,
    );
    final panelHeight = context.responsive<double>(
      mobile: 180,
      tablet: 200,
      desktop: 200,
      tv: 240,
    );

    // 响应式滑块尺寸（TV 模式下更大便于操作）
    final thumbRadius = context.responsive<double>(
      mobile: 8,
      tablet: 8,
      desktop: 8,
      tv: 12,
    );
    final overlayRadius = context.responsive<double>(
      mobile: 14,
      tablet: 14,
      desktop: 14,
      tv: 20,
    );
    final trackHeight = context.responsive<double>(
      mobile: 4,
      tablet: 4,
      desktop: 4,
      tv: 6,
    );
    final iconSize = context.responsive<double>(
      mobile: 20,
      tablet: 20,
      desktop: 20,
      tv: 28,
    );

    // 计算面板位置（居中对齐按钮）
    double left =
        widget.anchorPosition.dx + widget.anchorSize.width / 2 - panelWidth / 2;
    // 确保不超出屏幕
    if (left < 16) left = 16;
    if (left + panelWidth > screenSize.width - 16) {
      left = screenSize.width - panelWidth - 16;
    }

    // 面板从按钮上方弹出
    double top = widget.anchorPosition.dy - panelHeight - 8;

    // 如果面板会超出屏幕可见区域，显示在按钮下方
    final safeAreaTop = MediaQuery.of(context).padding.top;
    if (top < safeAreaTop + 16) {
      top = widget.anchorPosition.dy + widget.anchorSize.height + 8;
    }

    return Stack(
      children: [
        // 透明背景层，点击关闭
        Positioned.fill(
          child: Semantics(
            label: AppLocalizations.of(context).playerCloseVolumePanel,
            child: GestureDetector(
              onTap: widget.onDismiss,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        // 垂直音量控制面板
        Positioned(
          left: left,
          top: top,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerHigh,
            child: Container(
              width: panelWidth,
              height: panelHeight,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: FocusScope(
                autofocus: true,
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 顶部：音量百分比
                  Text(
                    '${_currentVolume.round()}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 中间：垂直滑块
                  Expanded(
                    child: RotatedBox(
                      quarterTurns: 3, // 旋转270度，让滑块垂直显示
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: trackHeight,
                          thumbShape: RoundSliderThumbShape(
                            enabledThumbRadius: thumbRadius,
                          ),
                          overlayShape: RoundSliderOverlayShape(
                            overlayRadius: overlayRadius,
                          ),
                          activeTrackColor: theme.colorScheme.primary,
                          inactiveTrackColor:
                              theme.colorScheme.surfaceContainerHighest,
                          thumbColor: theme.colorScheme.primary,
                          overlayColor: theme.colorScheme.primary.withValues(
                            alpha: 0.2,
                          ),
                        ),
                        child: Slider(
                          value: _currentVolume,
                          min: 0,
                          max: 100,
                          onChanged: (value) {
                            setState(() => _currentVolume = value);
                            widget.onVolumeChanged(value);
                          },
                          semanticFormatterCallback: (value) =>
                    AppLocalizations.of(context).playerVolumePercent(value.round()),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 底部：静音按钮
                  IconButton(
                    onPressed: widget.onToggleMute,
                    icon: Icon(_volumeIcon, color: theme.colorScheme.onSurface),
                    iconSize: iconSize,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: _currentVolume > 0
                        ? AppLocalizations.of(context).playerMute
                        : AppLocalizations.of(context).playerUnmute,
                  ),
                ],
              ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
