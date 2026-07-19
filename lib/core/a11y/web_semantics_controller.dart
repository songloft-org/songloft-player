import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/semantics.dart';

/// Web 端语义树（无障碍）句柄管理。
///
/// Songloft Web 端默认常驻语义树（`ensureSemantics()`，见无障碍改进
/// songloft-org/songloft#186），让读屏器无需用户先点「Enable accessibility」。
///
/// 但插件 Tab 是内嵌 iframe 的**平台视图**（HtmlElementView）。当语义树常驻时，
/// Flutter 引擎的残留 bug（[flutter/flutter#175119]）会把语义节点卡在
/// `pointer-events: auto` 并叠在插件平台视图之上，抢走本该落到 iframe 的点击，
/// 导致插件完全无法操作（songloft-org/songloft#295）。引擎主修复 #182167 已在
/// 当前 Flutter 版本中，但未完全覆盖此场景。
///
/// 方案：**进入插件 Tab 时临时释放我们持有的语义句柄**——若此时没有读屏器
/// （普通鼠标用户），语义树句柄计数归零、整棵语义 DOM 被拆除，残留的遮挡节点随之
/// 消失，iframe 恢复可点击；**离开插件 Tab 时重新获取句柄**恢复常驻语义树。
/// 插件内容本身是独立文档、自带无障碍，故主 App 的无障碍能力不受影响。
///
/// 注意：读屏器激活时平台会持有**另一个**独立语义句柄（见 SemanticsBinding
/// `_handleSemanticsEnabledChanged`），此时释放我们的句柄不会关闭语义树——读屏器
/// 用户的无障碍始终可用，只是仍可能命中该引擎 bug（属少数场景，可接受）。
///
/// 非 Web 平台所有方法均为 no-op。
class WebSemanticsController {
  WebSemanticsController._();

  static final WebSemanticsController instance = WebSemanticsController._();

  /// 我们主动持有的语义树句柄（仅 Web）。为空表示当前未持有。
  SemanticsHandle? _handle;

  /// 是否处于「默认应常驻语义树」的状态（启动后置真）。用于确保 [resume] 只在
  /// 我们本就希望常驻时才重新获取句柄，避免在插件 Tab 之外的意外调用打开语义树。
  bool _wantEnabledByDefault = false;

  /// 应用启动时调用一次：Web 端默认启用（常驻）语义树。
  void enableByDefault() {
    if (!kIsWeb) return;
    _wantEnabledByDefault = true;
    _acquire();
  }

  /// 进入插件 Tab（iframe 平台视图激活）时调用：临时释放语义句柄，避免残留语义
  /// 节点遮挡 iframe（songloft-org/songloft#295）。
  void suspendForPlugin() {
    if (!kIsWeb || !_wantEnabledByDefault) return;
    _release();
  }

  /// 离开插件 Tab 时调用：恢复常驻语义树。
  void resume() {
    if (!kIsWeb || !_wantEnabledByDefault) return;
    _acquire();
  }

  void _acquire() {
    _handle ??= SemanticsBinding.instance.ensureSemantics();
  }

  void _release() {
    _handle?.dispose();
    _handle = null;
  }
}
