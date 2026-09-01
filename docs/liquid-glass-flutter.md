# Liquid Glass 主题（Flutter）— 计划

> 跨仓库项目的一部分。姊妹计划：Lynx 端 [`songloft-player-lynx/docs/project/plans/liquid-glass-theme.md`](https://github.com/songloft-org/songloft-player-lynx/blob/main/docs/project/plans/liquid-glass-theme.md)（已实现）。后端 `glassColor` 字段已加（`songloft-org/songloft` `internal/models/theme_pack.go`，本会话）。

## Context

给 Songloft Player (Flutter) 加 Liquid Glass 主题，与 Lynx 端对齐视觉语言。**Flutter 有真 `BackdropFilter` + `ImageFilter.blur`**（已在 `mobile_player.dart`/`desktop_full_player.dart` 的封面背景用 `sigma: 70`），所以做**真玻璃**（实时背景采样折射），不是 Lynx 那套诚实伪造。

参考：[Beans-Music](https://github.com/XIaodou0416/Beans-Music)（iOS 26 原生 `.glassEffect`，SwiftUI）—— Flutter 等价物是 `BackdropFilter(filter: ImageFilter.blur(sigmaX:, sigmaY:))` + `ClipRRect` + 半透 fill + hairline border + sheen 高光。

**与 Lynx 的关键差异**：
- Lynx 无 `backdrop-filter` → 半透 + `box-shadow: inset` 伪造；Flutter 有真模糊 → 用 `BackdropFilter`。
- 跨端共享的是 `.songloft-theme` JSON 包（含新 `glassColor` 字段）；玻璃**渲染**各端各自实现。
- `glassColor` 独立于 `seedColor`（按钮通道）——真双通道：玻璃色随 `glassColor`，按钮色随 `seedColor`。无 `glassColor` 时回落星蓝基线（light `#3BAEEF` / dark `#5BC0F5`）。

## 1. theme-pack 解析加 glassColor — `lib/features/settings/data/theme_pack_api.dart`

`ThemePackColors` 加 `Color? glassColor` + `fromJson` 读 `json['glassColor']`（`_parseColor`，缺省 null）。与后端 schema（`ThemePackColors.GlassColor`，可选 `#RRGGBB`）一致。现有包无该字段 → null → 回落基线。

## 2. 主题扩展加玻璃色 — `lib/core/theme/app_theme.dart`

`SongloftThemeExtension` 加 `Color? glassColorLight` / `Color? glassColorDark`（或单一 `glassColor` + 主题分叉），`copyWith`/`lerp` 同步。`app_theme.dart` 构建 `ThemeData` 时把 pack 的 `glassColor`（按 `Brightness` 取 light/dark）写入扩展；无 pack / 无 glassColor 时回落星蓝基线。

同时定义玻璃 token（在扩展或 `app_dimensions.dart`）：
- `glassFill`（alpha ~0.7-0.85 半透，随 brightness）
- `glassBorder`（hairline）
- `glassHighlight`（顶边高光白）
- `glassGlow`（= glassColor，个性色）
- `glassGlowFaint`（选中胶囊淡底，glassColor @ 0.10/0.14）
- `glassSheen`（sheen 彩色分量，glassColor @ 0.18/0.10）

## 3. 玻璃表面组件

新增可复用 `GlassSurface` widget（`lib/core/theme/widgets/glass_surface.dart` 或类似）：
```dart
ClipRRect(
  borderRadius: radius,
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24), // 真模糊
    child: Container(
      decoration: BoxDecoration(
        color: glassFill,                       // 半透
        border: Border.all(color: glassBorder),
        borderRadius: radius,
        gradient: LinearGradient(               // sheen 顶高光
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [glassHighlight, Colors.transparent],
        ),
        boxShadow: [BoxShadow(...)],            // 浮层阴影
      ),
      child: child,
    ),
  ),
)
```
> `BackdropFilter` 会模糊其**背后**的内容（实时采样），故玻璃浮在内容上时为真折射；性能注意：大面积高 sigma 在低端机贵，sheet/dialog 用 sigma ~24，nav 胶囊可更低。

## 4. 表面改造清单

把现有浮动表面改用 `GlassSurface`：

| 文件 | 表面 | 备注 |
|---|---|---|
| `lib/features/player/presentation/widgets/mini_player.dart`（或 mobile_player 里的 mini） | mini-player | 现有 sigma:70 是封面背景模糊，这里是胶囊本身玻璃 |
| 导航栏（`NavigationBar`/`BottomNavigationBar` 所在） | 底部 nav 胶囊 | 选中 pill 用 `glassGlowFaint` |
| 各 Dialog：`playlist_form_dialog.dart`、`playlist_edit_dialog.dart`、`upgrade_dialog.dart`、`frontend_upgrade_dialog.dart`、`github_proxy_dialog.dart` | 对话框卡片 | |
| 各 Sheet：`device_sheet.dart`、`cache_manager.dart`、`shortcut_recorder.dart` 等 | 底部 sheet | |
| 设置分类卡 `settings_category_content.dart` | 卡片（可选） | 卡片非浮层，可保持纸面或轻玻璃 |

> **toast 不玻璃化**（保留主操作语义）。与 Lynx 清单对齐。

## 5. 选中态彩色

nav 选中胶囊 / 选中行 tint 用 `glassGlowFaint`（glassColor 淡底），按钮仍用 `seedColor`（`ColorScheme.primary`）——双通道。

## 6. 测试与验证

- `flutter analyze` + `flutter test`。
- 单测：`ThemePackColors.fromJson` 读 glassColor（有/无/非法）；`SongloftThemeExtension` lerp/copyWith 含 glassColor。
- 真机/模拟器：深/浅色 × 有/无 liquid-glass 包四态截图；装包验玻璃色随 glassColor 变、按钮色随 seedColor 不变。
- 性能：低端机 sigma 过大掉帧时降 sigma 或退半透无模糊。

## 7. 不在本期范围

- Lynx 端工作（已完成，不迁移）。
- 后端 schema（本会话已加 glassColor）。

## 关键文件

- 解析：`lib/features/settings/data/theme_pack_api.dart`
- 主题：`lib/core/theme/app_theme.dart`、`app_dimensions.dart`
- 新组件：`lib/core/theme/widgets/glass_surface.dart`
- 表面：见第 4 节
- 参考：Beans-Music `Beans/Theme.swift`、`Beans/Components.swift`、`Beans/GlassBackdrop.swift`
