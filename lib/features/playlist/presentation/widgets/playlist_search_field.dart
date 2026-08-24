import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';

/// 歌单详情页搜索框。
///
/// visible=false 时不渲染 TextField（从 widget tree 中移除），确保每次打开搜索时
/// 平台都收到全新的 TextInput 客户端注册，Windows IME 能正确初始化。
/// 外层 [SliverToBoxAdapter] 始终存在以保持 Sliver 位置稳定。
class PlaylistSearchField extends StatefulWidget {
  const PlaylistSearchField({
    super.key,
    required this.visible,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final bool visible;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<PlaylistSearchField> createState() => _PlaylistSearchFieldState();
}

class _PlaylistSearchFieldState extends State<PlaylistSearchField> {
  bool _showClearButton = false;

  @override
  void initState() {
    super.initState();
    _showClearButton = widget.controller.text.isNotEmpty;
    widget.controller.addListener(_onTextChanged);
    if (widget.visible) _ensureFocus();
  }

  @override
  void didUpdateWidget(covariant PlaylistSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
      _showClearButton = widget.controller.text.isNotEmpty;
    }
    if (!oldWidget.visible && widget.visible) {
      // 仅在「切入搜索模式」这一次请求焦点。父级 rebuild 时不再补聚焦：
      // 焦点丢失的真正原因是滚动条 overlay 翻转导致子树被重建
      // (songloft-org/songloft#361)，已在 DraggableScrollbarOverlay 根治。
      // 在这里无条件抢焦点会把用户点到别处（歌曲行、菜单）的焦点强行拽回，
      // 并让 requestFocus 每帧连发，反而打断 IME 组合。
      _ensureFocus();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText != _showClearButton) {
      setState(() => _showClearButton = hasText);
    }
  }

  /// 在 autofocus 之后的若干帧验证焦点是否成功，不成功则重试。
  /// Windows 上 autofocus 可能因为 AppBar 搜索按钮持有平台焦点而失败。
  /// 重试间隔 1 帧，最多 10 次；一旦拿到焦点立即停止。
  void _ensureFocus() {
    _retryFocus(0);
  }

  void _retryFocus(int attempt) {
    if (attempt >= 10) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.visible) return;
      if (widget.focusNode.hasFocus) return;
      // 组合输入进行中绝不重新请求焦点，否则会重建输入连接、打断 IME。
      final composing = widget.controller.value.composing;
      if (composing.isValid && !composing.isCollapsed) return;
      widget.focusNode.requestFocus();
      _retryFocus(attempt + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        autofocus: true,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          suffixIcon:
              _showClearButton
                  ? IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: l10n.clearSearch,
                    onPressed: widget.onClear,
                  )
                  : null,
          hintText: l10n.playlistSearchHint,
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}
