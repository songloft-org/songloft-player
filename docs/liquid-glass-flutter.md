# Liquid Glass 主题（Flutter）

> 基础主题已实现；下文保留原设计结构。姊妹计划：Lynx 端 [液态玻璃主题设计](https://github.com/songloft-org/songloft-player-lynx/blob/main/docs/archive/plans/liquid-glass-theme.md)。后端主题包 `glassColor` 字段见 `songloft-org/songloft` 的 `internal/models/theme_pack.go`。

## 辅助功能设置（2026-10）

“设置 → 外观”提供“减少透明度”和“增强对比度”，均默认关闭，分别以 `reduce_transparency` / `increase_contrast` 保存在当前设备，不参与用户偏好服务器同步。读取偏好期间玻璃保持实心，读取失败使用默认设置；写入串行执行，快速切换不会让旧值最后落盘。

减少透明度使用实心填充、移除玻璃高光并卸载背景模糊。增强对比度使用 Material 的 `contrastLevel: 1` 色板、实心填充和可访问的图标/描边；主题包 seed 与圆角保留，背景与玻璃 tint 覆盖不再覆盖高对比度角色色。增强对比度取本机开关与 `MediaQuery.highContrastOf` 的 OR，系统开启时本机关闭不会抵消它。系统减少透明度未接原生桥，所有平台提供手动选择。

公共 `GlassBackdropFilter` 控制玻璃组件、侧栏与弹窗；封面自身的装饰模糊不作为透明玻璃处理。入口与响应式主题重建均传递偏好，`SongloftThemeExtension` 携带有效状态，切为实心时不插入半透明的材质过渡帧。`songloft-theme.appearance` 下推 `reduceTransparency` / `increaseContrast` 与最终玻璃填充，原生 WebView、独立插件页与插件 Tab iframe 均沿用原有消息去重和加载后重放机制；旧公共资源可忽略新字段。

验证入口：`flutter analyze`、`flutter test`；新增测试覆盖偏好恢复/竞争/销毁、实际设置点击与系统 OR、手机/桌面响应式主题、亮暗默认与自定义主题包对比度、模糊卸载和插件消息。跨平台手动开关不代表各平台系统辅助功能信号都可用，光学质量与性能需设备验证。

2026-10 实施验证：格式化无差异，`flutter analyze` 无问题，完整 `flutter test` 557 项通过，embedded Web 生产构建成功。Docker Chrome 使用隔离 Go 服务与 MIoT 模拟音箱验证 6 个场景：默认玻璃、减少透明度、本机偏好刷新恢复、增强对比度、深色高对比度、375px 手机布局关闭后恢复模糊；断言同时检查本机存储与插件实际材质，页面运行时异常为零。原生 WebView 用模拟平台验证同一 widget/控制器随 Theme 依赖变化实时推送并去重；移除实时推送或系统 OR 的反向测试会失败。本批未构建 Flutter 原生安装包，也未实测各平台的系统高对比度信号。

## Context

Songloft Player (Flutter) 使用 `BackdropFilter` + `ImageFilter.blur` 做背景采样模糊，叠加半透明填充、描边和高光。背景模糊不等同于原生液态玻璃的折射；各客户端共享主题包字段，分别实现平台材质。

参考：[Beans-Music](https://github.com/XIaodou0416/Beans-Music)（iOS 26 原生 `.glassEffect`，SwiftUI）。本项目在 Flutter 中用 `BackdropFilter(filter: ImageFilter.blur(sigmaX:, sigmaY:))` + `ClipRRect` + 半透 fill + hairline border + sheen 高光实现视觉材质。

**与 Lynx 的关键差异**：
- Lynx 4 支持按宿主/系统能力门控的 themed blur 与原生 glass；Flutter 本项目使用 `BackdropFilter`，不宣称等同 iOS 原生 glass。
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
| `lib/features/player/presentation/widgets/capsule_mini_player.dart` | **大屏胶囊迷你播放器**（capsule 主题下 tablet / desktop 的浮起胶囊条） | `GlassSurface` **sigma 20**（`AppCapsulePlayer.blurSigma`）；手机档（`CapsuleMiniPlayer.compact`）共用同一骨架但**不做真模糊**，只保留半透填充 + 内高光 |
| `lib/features/player/presentation/widgets/mini_player.dart` | mini-player（standard 模式的底栏） | 现有 sigma:70 是封面背景模糊，这里是胶囊本身玻璃；capsule 模式下它直接转发给 `CapsuleMiniPlayer.compact` |
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
