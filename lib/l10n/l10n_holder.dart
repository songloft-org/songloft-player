import 'app_localizations.dart';

/// 全局 [AppLocalizations] 访问器。
///
/// 用于 data / provider / service 等**没有 BuildContext** 的场景（如仓储抛出的
/// 错误消息、状态标签）获取当前语言的翻译。由 `SongloftApp` 的 MaterialApp
/// `builder` 在每帧用 `AppLocalizations.of(context)` 刷新（locale 切换后
/// MaterialApp 重建，builder 会拿到新的 AppLocalizations 实例）。
AppLocalizations? _current;

/// 当前的 [AppLocalizations] 实例；首帧渲染前可能为 null。
AppLocalizations? get l10nOrNull => _current;

/// 当前的 [AppLocalizations] 实例。仅在确定 UI 已挂载后使用。
AppLocalizations get l10n => _current!;

/// 由 MaterialApp builder 调用，刷新全局引用。
void updateGlobalL10n(AppLocalizations value) {
  _current = value;
}
