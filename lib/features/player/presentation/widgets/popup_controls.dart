import 'package:flutter/material.dart';

import '../../../../core/theme/responsive.dart';
import '../../domain/player_state.dart';

/// 播放模式弹出控制组件
class PopupPlayModeControl extends StatefulWidget {
  final PlayMode playMode;
  final ValueChanged<PlayMode> onPlayModeChanged;

  const PopupPlayModeControl({
    super.key,
    required this.playMode,
    required this.onPlayModeChanged,
  });

  @override
  State<PopupPlayModeControl> createState() => _PopupPlayModeControlState();
}

class _PopupPlayModeControlState extends State<PopupPlayModeControl> {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  IconData get _playModeIcon {
    switch (widget.playMode) {
      case PlayMode.order:
        return Icons.format_list_numbered_rounded;
      case PlayMode.loop:
        return Icons.repeat_rounded;
      case PlayMode.single:
        return Icons.repeat_one_rounded;
      case PlayMode.random:
        return Icons.shuffle_rounded;
      case PlayMode.singlePlay:
        return Icons.looks_one_outlined;
    }
  }

  String _getPlayModeTooltip(PlayMode mode) {
    switch (mode) {
      case PlayMode.order:
        return '顺序播放';
      case PlayMode.loop:
        return '列表循环';
      case PlayMode.single:
        return '单曲循环';
      case PlayMode.random:
        return '随机播放';
      case PlayMode.singlePlay:
        return '单曲播放';
    }
  }

  void _showPlayModePanel() {
    _removeOverlay();

    final RenderBox? renderBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder:
          (context) => _PlayModeOverlayPanel(
            playMode: widget.playMode,
            onPlayModeChanged: (mode) {
              widget.onPlayModeChanged(mode);
              _removeOverlay();
            },
            onDismiss: _removeOverlay,
            anchorPosition: position,
            anchorSize: size,
            getIcon: _getPlayModeIconForMode,
            getTooltip: _getPlayModeTooltip,
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  IconData _getPlayModeIconForMode(PlayMode mode) {
    switch (mode) {
      case PlayMode.order:
        return Icons.format_list_numbered_rounded;
      case PlayMode.loop:
        return Icons.repeat_rounded;
      case PlayMode.single:
        return Icons.repeat_one_rounded;
      case PlayMode.random:
        return Icons.shuffle_rounded;
      case PlayMode.singlePlay:
        return Icons.looks_one_outlined;
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      key: _buttonKey,
      onPressed: _showPlayModePanel,
      icon: Icon(
        _playModeIcon,
        size: 20,
        color:
            widget.playMode != PlayMode.order
                ? theme.colorScheme.primary
                : null,
      ),
      tooltip: _getPlayModeTooltip(widget.playMode),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// 播放模式弹出面板
class _PlayModeOverlayPanel extends StatelessWidget {
  final PlayMode playMode;
  final ValueChanged<PlayMode> onPlayModeChanged;
  final VoidCallback onDismiss;
  final Offset anchorPosition;
  final Size anchorSize;
  final IconData Function(PlayMode) getIcon;
  final String Function(PlayMode) getTooltip;

  const _PlayModeOverlayPanel({
    required this.playMode,
    required this.onPlayModeChanged,
    required this.onDismiss,
    required this.anchorPosition,
    required this.anchorSize,
    required this.getIcon,
    required this.getTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    // 响应式面板尺寸
    final itemHeight = context.responsive<double>(
      mobile: 44,
      tablet: 48,
      desktop: 48,
      tv: 56,
    );
    final panelWidth = context.responsive<double>(
      mobile: 140,
      tablet: 160,
      desktop: 160,
      tv: 200,
    );
    final iconSize = context.responsive<double>(
      mobile: 20,
      tablet: 20,
      desktop: 20,
      tv: 24,
    );
    final fontSize = context.responsive<double>(
      mobile: 14,
      tablet: 14,
      desktop: 14,
      tv: 16,
    );

    final panelHeight = PlayMode.values.length * itemHeight + 16;

    // 计算面板位置（居中对齐按钮）
    double left = anchorPosition.dx + anchorSize.width / 2 - panelWidth / 2;
    // 确保不超出屏幕
    if (left < 16) left = 16;
    if (left + panelWidth > screenSize.width - 16) {
      left = screenSize.width - panelWidth - 16;
    }

    // 面板从按钮上方弹出
    double top = anchorPosition.dy - panelHeight - 8;

    // 如果面板会超出屏幕可见区域，显示在按钮下方
    final safeAreaTop = MediaQuery.of(context).padding.top;
    if (top < safeAreaTop + 16) {
      top = anchorPosition.dy + anchorSize.height + 8;
    }

    return Stack(
      children: [
        // 透明背景层，点击关闭
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        // 播放模式面板
        Positioned(
          left: left,
          top: top,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerHigh,
            child: Container(
              width: panelWidth,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final mode in PlayMode.values)
                    InkWell(
                      onTap: () => onPlayModeChanged(mode),
                      child: Container(
                        width: double.infinity,
                        height: itemHeight,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              getIcon(mode),
                              size: iconSize,
                              color:
                                  playMode == mode
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              getTooltip(mode),
                              style: TextStyle(
                                fontSize: fontSize,
                                color:
                                    playMode == mode
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface,
                                fontWeight:
                                    playMode == mode
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 睡眠定时入口按钮：桌面/平板/TV 用按钮上方浮层；移动端用底部抽屉 BottomSheet
class PopupSleepTimerControl extends StatefulWidget {
  final SleepTimerStatus? status;

  /// 当前播放的是否为直播流。直播流没有「歌曲结束」事件，
  /// 「按歌曲」相关选项会被隐藏。
  final bool isLive;
  final ValueChanged<Duration> onSetDuration;
  final ValueChanged<int> onSetAfterSongs;
  final VoidCallback onCancel;

  const PopupSleepTimerControl({
    super.key,
    required this.status,
    required this.isLive,
    required this.onSetDuration,
    required this.onSetAfterSongs,
    required this.onCancel,
  });

  @override
  State<PopupSleepTimerControl> createState() => _PopupSleepTimerControlState();
}

class _PopupSleepTimerControlState extends State<PopupSleepTimerControl> {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  bool get _hasTimer => widget.status != null;

  void _onPressed() {
    if (context.isMobile) {
      _removeOverlay();
      SleepTimerSheet.show(
        context,
        status: widget.status,
        isLive: widget.isLive,
        onSetDuration: widget.onSetDuration,
        onSetAfterSongs: widget.onSetAfterSongs,
        onCancel: widget.onCancel,
      );
    } else {
      _showSleepTimerPanel();
    }
  }

  void _showSleepTimerPanel() {
    _removeOverlay();

    final RenderBox? renderBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder:
          (overlayContext) => _SleepTimerOverlayPanel(
            status: widget.status,
            isLive: widget.isLive,
            onSetDuration: (d) {
              widget.onSetDuration(d);
              _removeOverlay();
            },
            onSetAfterSongs: (n) {
              widget.onSetAfterSongs(n);
              _removeOverlay();
            },
            onCancel: () {
              widget.onCancel();
              _removeOverlay();
            },
            onDismiss: _removeOverlay,
            anchorPosition: position,
            anchorSize: size,
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      key: _buttonKey,
      onPressed: _onPressed,
      icon: Icon(
        _hasTimer ? Icons.alarm_on_rounded : Icons.alarm_rounded,
        size: 20,
        color: _hasTimer ? theme.colorScheme.primary : null,
      ),
      tooltip:
          widget.status == null
              ? '睡眠定时'
              : '睡眠定时：${sleepTimerStatusLabel(widget.status!)}',
      visualDensity: VisualDensity.compact,
    );
  }
}

/// 睡眠定时浮层（桌面/平板/TV）
class _SleepTimerOverlayPanel extends StatelessWidget {
  final SleepTimerStatus? status;
  final bool isLive;
  final ValueChanged<Duration> onSetDuration;
  final ValueChanged<int> onSetAfterSongs;
  final VoidCallback onCancel;
  final VoidCallback onDismiss;
  final Offset anchorPosition;
  final Size anchorSize;

  const _SleepTimerOverlayPanel({
    required this.status,
    required this.isLive,
    required this.onSetDuration,
    required this.onSetAfterSongs,
    required this.onCancel,
    required this.onDismiss,
    required this.anchorPosition,
    required this.anchorSize,
  });

  static const double _panelWidth = 280;
  static const double _maxPanelHeight = 480;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    // 水平居中对齐按钮，越界回弹
    double left = anchorPosition.dx + anchorSize.width / 2 - _panelWidth / 2;
    if (left < 16) left = 16;
    if (left + _panelWidth > screenSize.width - 16) {
      left = screenSize.width - _panelWidth - 16;
    }

    // 优先向上弹，空间不足则向下
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final spaceAbove = anchorPosition.dy - safeAreaTop - 16;
    final spaceBelow =
        screenSize.height - anchorPosition.dy - anchorSize.height - 16;
    final preferAbove = spaceAbove >= 240 || spaceAbove >= spaceBelow;
    final availableHeight =
        (preferAbove ? spaceAbove : spaceBelow).clamp(120.0, _maxPanelHeight);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          left: left,
          top: preferAbove ? null : anchorPosition.dy + anchorSize.height + 8,
          bottom:
              preferAbove
                  ? screenSize.height - anchorPosition.dy + 8
                  : null,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerHigh,
            child: Container(
              width: _panelWidth,
              constraints: BoxConstraints(maxHeight: availableHeight),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SingleChildScrollView(
                child: SleepTimerContent(
                  status: status,
                  isLive: isLive,
                  onSetDuration: onSetDuration,
                  onSetAfterSongs: onSetAfterSongs,
                  onCancel: onCancel,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 把当前定时状态格式化成短文案（用于 tooltip / 状态条）
String sleepTimerStatusLabel(SleepTimerStatus status) {
  switch (status.mode) {
    case SleepTimerMode.duration:
      final d = status.remaining ?? Duration.zero;
      final m = d.inMinutes;
      final s = d.inSeconds % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    case SleepTimerMode.afterSongs:
      return '剩余 ${status.remainingSongs ?? 0} 首';
  }
}

/// 睡眠定时内容布局（桌面浮层 / 移动端 BottomSheet 共用）
class SleepTimerContent extends StatelessWidget {
  final SleepTimerStatus? status;

  /// 当前播放的是否为直播流。直播流没有「歌曲结束」事件，
  /// 「按歌曲」整组选项会被隐藏。
  final bool isLive;
  final ValueChanged<Duration> onSetDuration;
  final ValueChanged<int> onSetAfterSongs;
  final VoidCallback onCancel;

  const SleepTimerContent({
    super.key,
    required this.status,
    required this.isLive,
    required this.onSetDuration,
    required this.onSetAfterSongs,
    required this.onCancel,
  });

  static const _durationOptions = [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
  ];

  static const _songCountOptions = [1, 3, 5];

  // 时长档位不高亮：倒计时会让 remaining 秒级递减，与档位的稳定值不再相等；
  // 用户选完档位浮层即关闭，反馈通过顶部状态条「剩余 X:XX」给出。
  bool _isSongCountSelected(int n) =>
      status?.mode == SleepTimerMode.afterSongs &&
      status?.remainingSongs == n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status != null) ...[
          // 已设定状态条
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(
              children: [
                Icon(Icons.alarm_on_rounded,
                    size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sleepTimerStatusLabel(status!),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('取消定时'),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
        ],
        const _SectionHeader(icon: Icons.schedule_rounded, title: '按时长'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in _durationOptions)
                ChoiceChip(
                  label: Text(
                    d.inMinutes >= 60
                        ? '${d.inHours} 小时'
                        : '${d.inMinutes} 分钟',
                  ),
                  selected: false,
                  onSelected: (_) => onSetDuration(d),
                ),
              ActionChip(
                avatar: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('自定义'),
                onPressed: () async {
                  final minutes = await _showNumberInputDialog(
                    context,
                    title: '自定义时长',
                    unit: '分钟',
                    min: 1,
                    max: 999,
                  );
                  if (minutes != null) {
                    onSetDuration(Duration(minutes: minutes));
                  }
                },
              ),
            ],
          ),
        ),
        if (!isLive) ...[
          Divider(height: 1, color: colorScheme.outlineVariant),
          const _SectionHeader(icon: Icons.queue_music_rounded, title: '按歌曲'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in _songCountOptions)
                  ChoiceChip(
                    label: Text('$n 首'),
                    selected: _isSongCountSelected(n),
                    onSelected: (_) => onSetAfterSongs(n),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('自定义'),
                  onPressed: () async {
                    final count = await _showNumberInputDialog(
                      context,
                      title: '自定义首数',
                      unit: '首',
                      min: 1,
                      max: 99,
                    );
                    if (count != null) {
                      onSetAfterSongs(count);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 数字输入对话框（用于自定义时长 / 自定义首数）
Future<int?> _showNumberInputDialog(
  BuildContext context, {
  required String title,
  required String unit,
  required int min,
  required int max,
}) {
  final controller = TextEditingController();
  String? errorText;

  return showDialog<int>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          int? parseAndValidate() {
            final raw = controller.text.trim();
            if (raw.isEmpty) {
              setState(() => errorText = '请输入数字');
              return null;
            }
            final v = int.tryParse(raw);
            if (v == null) {
              setState(() => errorText = '请输入有效整数');
              return null;
            }
            if (v < min || v > max) {
              setState(() => errorText = '请输入 $min - $max 之间的整数');
              return null;
            }
            return v;
          }

          return AlertDialog(
            title: Text(title),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ctx.responsiveDialogMaxWidth,
              ),
              child: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  suffixText: unit,
                  errorText: errorText,
                  hintText: '$min - $max',
                ),
                onSubmitted: (_) {
                  final v = parseAndValidate();
                  if (v != null) Navigator.of(dialogContext).pop(v);
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: TextButton.styleFrom(
                  minimumSize: ctx.responsiveButtonMinSize,
                ),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  final v = parseAndValidate();
                  if (v != null) Navigator.of(dialogContext).pop(v);
                },
                style: TextButton.styleFrom(
                  minimumSize: ctx.responsiveButtonMinSize,
                ),
                child: const Text('确定'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// 睡眠定时底部抽屉（移动端）
class SleepTimerSheet extends StatelessWidget {
  final SleepTimerStatus? status;
  final bool isLive;
  final ValueChanged<Duration> onSetDuration;
  final ValueChanged<int> onSetAfterSongs;
  final VoidCallback onCancel;

  const SleepTimerSheet({
    super.key,
    required this.status,
    required this.isLive,
    required this.onSetDuration,
    required this.onSetAfterSongs,
    required this.onCancel,
  });

  static Future<void> show(
    BuildContext context, {
    required SleepTimerStatus? status,
    required bool isLive,
    required ValueChanged<Duration> onSetDuration,
    required ValueChanged<int> onSetAfterSongs,
    required VoidCallback onCancel,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return SleepTimerSheet(
          status: status,
          isLive: isLive,
          onSetDuration: (d) {
            onSetDuration(d);
            Navigator.of(sheetContext).pop();
          },
          onSetAfterSongs: (n) {
            onSetAfterSongs(n);
            Navigator.of(sheetContext).pop();
          },
          onCancel: () {
            onCancel();
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withAlpha(100),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  '睡眠定时',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              child: SleepTimerContent(
                status: status,
                isLive: isLive,
                onSetDuration: onSetDuration,
                onSetAfterSongs: onSetAfterSongs,
                onCancel: onCancel,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
