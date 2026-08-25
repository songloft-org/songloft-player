import 'dart:convert';

import 'package:flutter/cupertino.dart' show CupertinoTheme, CupertinoThemeData;
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webf/webf.dart';
import 'package:webf_cupertino_ui/webf_cupertino_ui.dart';

import '../../../player/domain/player_state.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../plugin_host_dispatch.dart';
import 'elements/songloft_custom_elements.dart';
import 'plugin_color_scheme.dart';
import 'plugin_file_bridge.dart';
import 'plugin_render_controller.dart';
import 'plugin_render_fonts.dart';

/// 宿主桥的 MethodChannel 方法名（JS 侧 `common.js` 必须一致）。
const String _kHostCallMethod = 'songloftHost';
const String _kRequestBackMethod = 'requestBack';

/// WebF 渲染面（songloft-org/songloft#341）。
///
/// 与 `PluginRenderSurfaceWebView` 对等：只管渲染面、宿主桥、主题下推；
/// 加载态 / 超时 / 错误 UI / 重试归 `PluginRenderView`。
///
/// 分发逻辑复用传输无关的 [PluginHostDispatcher]（与 InAppWebView、Web iframe
/// 三条链路共用），所以本文件只实现「传输」这一层。
class PluginRenderSurfaceWebF extends ConsumerStatefulWidget {
  final String url;
  final String theme;
  final VoidCallback onLoadStart;
  final VoidCallback onLoadStop;
  final void Function(String message) onError;
  final void Function(PluginRenderController controller) onControllerReady;

  const PluginRenderSurfaceWebF({
    super.key,
    required this.url,
    required this.theme,
    required this.onLoadStart,
    required this.onLoadStop,
    required this.onError,
    required this.onControllerReady,
  });

  @override
  ConsumerState<PluginRenderSurfaceWebF> createState() =>
      _PluginRenderSurfaceWebFState();
}

class _PluginRenderSurfaceWebFState
    extends ConsumerState<PluginRenderSurfaceWebF>
    implements PluginRenderController {
  /// WebF 的三项**进程级**一次性设置。三者都必须在创建任何 controller 之前
  /// 完成，所以放在同一个入口里一次做完。
  static bool _processSetupDone = false;

  static void _ensureWebFProcessSetup() {
    if (_processSetupDone) return;
    _processSetupDone = true;

    // ① 实例限额。
    //
    // 刻意不用默认的 `maxAliveInstances: 5`：插件 Tab 数可能超过 5，而超出
    // `maxAliveInstances` 会 **dispose** controller，之后重新挂载虽然会自动重建
    // （用缓存的初始化参数重放），但页面内 JS 状态归零、还会闪一下 loading。
    // 超出 `maxAttachedInstances` 只是 detach、状态保留，代价小得多。
    WebFControllerManager.instance.initialize(
      const WebFControllerManagerConfig(
        maxAliveInstances: 8,
        maxAttachedInstances: 3,
      ),
    );

    // ② 自定义元素（`<songloft-progress-ring>` 等）。
    //
    // 与限额同一类约束：写的是进程级全局注册表、重复注册会抛、且必须早于
    // controller —— controller 初始化期就会预取 widget 元素的形状与属性默认值，
    // 注册晚了那一页只能拿到 `_UnknownHTMLElement`。详见
    // `elements/songloft_custom_elements.dart` 的头注释。
    SongloftCustomElements.ensureRegistered();

    // ③ webf-ui 的 Cupertino 原生元素（`<flutter-cupertino-*>`，31 个）。
    //
    // 为什么不放进 `elements/songloft_custom_elements.dart`：那个目录有铁律
    // 「只能 import `flutter` 与 `webf`」（`scripts/webf-verify` 要跨 package 拷它），
    // 而这里要 import `webf_cupertino_ui`。本函数与它是同一类进程级一次性设置、
    // 已有 `_processSetupDone` 幂等闸，正好是这个调用的落点。
    //
    // **必须整体包 try/catch**：`installWebFCupertinoUI()` 内部是 31 条连续的
    // `WebF.defineCustomElement(...)`，**没有逐元素 try/catch**；而
    // `defineCustomElement` 对重复注册是**抛异常**（热重启后进程级 registry 仍在）。
    // 任何一条抛出，后面的元素就全部注册不上。理由与
    // `SongloftCustomElements._define` 逐个包 try/catch 完全一致：一个元素失败
    // 只该让**那一个标签**退回 `_UnknownHTMLElement`，不该连带打掉其它元素。
    //
    // 插件侧对「元素没注册上」有兜底：`useNativeUI` 特性探测（探
    // `document.createElement('flutter-cupertino-switch').checked !== undefined`）
    // 失败时走 HTML 分支，所以这里失败不会让插件页变成空白。
    try {
      installWebFCupertinoUI();
    } catch (e) {
      debugPrint('[plugin][element] installWebFCupertinoUI failed: $e');
    }
  }

  WebFController? _controller;
  PluginHostDispatcher? _dispatcher;
  String? _lastPushedStateSig;
  bool _pageReady = false;

  /// 缓存住 WebF 子树的 **widget 实例**，让本渲染面的 rebuild 不再穿透进去。
  ///
  /// 本 widget 会随**任何祖先 rebuild** 一起重建 —— 播放中迷你播放器的进度更新
  /// 就足以让它每秒重建好几次。而 `AutoManagedWebFState.build()` 里的
  /// `FutureBuilder(future: _getOrCreateController())` 把 future **在 build 里现造**，
  /// widget 实例一换就重新订阅、多跑一次异步 controller 查找，并打一行
  /// `WebF: loading with controller: ...` —— 用户日志里刷屏的正是它。
  ///
  /// 返回**同一个 widget 实例**时 `Element.updateChild` 会直接短路整棵子树
  /// （`if (child.widget == newWidget) return child;`），既省掉那次查找也不再刷日志。
  ///
  /// 子树本身**不会**因此拿到过期数据：它只依赖 `url`（→ bundle 与
  /// `_controllerName`），而 `url` 变化时 `didUpdateWidget` 会把这里置空重建；
  /// 其余回调都是闭包捕获 `this`，State 不变即恒为最新。
  ///
  /// 顺带说明：`FutureBuilder` 换 future 时用的是 `_snapshot.inState(waiting)`，
  /// **data 会被保留**，所以旧实例被替换时并不会闪回 `loadingWidget`、也不会把
  /// 已挂载的 WebF 子树拆掉。这里省的是重复的异步查找与日志，不是修拆树。
  Widget? _webfChild;

  /// 最近一次从 `MediaQuery` 读到的安全区，与最近一次**已推给页面**的签名。
  ///
  /// 分成两个字段而不是一个：build() 每次都会更新前者（此时页面可能还没 ready，
  /// 推不出去），`_pageReady` 转 true 时要拿它补推首屏值。
  EdgeInsets _safeAreaInsets = EdgeInsets.zero;
  String? _lastPushedInsetsSig;

  /// 同上的两段式，用于「亮暗标记 + 真实色板」下推（见 `plugin_color_scheme.dart`）。
  /// `build()` 里读 `Theme.of(context)` 存下来，`_markPageReady()` 那种拿不到
  /// context 的地方复用。
  ColorScheme? _colorScheme;
  String? _lastPushedThemeSig;

  /// controller 缓存键。用**去掉 query 的 URL**：`?theme=` 会随主题变化，
  /// 带上它会让切主题变成「换了一个插件」从而整页重载。
  static String _controllerNameFor(String url) =>
      'plugin:${Uri.parse(url).replace(query: '').toString()}';

  late final String _controllerName = _controllerNameFor(widget.url);

  PluginHostDispatcher get _hostDispatcher =>
      _dispatcher ??= PluginHostDispatcher(ref, platformName: _platformName());

  /// controllerName → 当前**归属**该 controller 的渲染面。
  ///
  /// 这张表决定「谁有权在 dispose 时把缓存里的 controller 一起销毁」，
  /// 不只是诊断用。见 `dispose()`。
  ///
  /// 之所以需要它：同一 URL 的新旧渲染面在**同一帧内交接**时，新面的
  /// `initState` 早于旧面的 `dispose` —— Flutter 先在 build 阶段 inflate 新子树，
  /// 到帧末 `BuildOwner.finalizeTree()` 才拆掉 inactive 元素。若旧面无条件销毁
  /// controller，销毁掉的正是新面刚在 `_adoptPreloadedController()` 里认领的那个。
  /// 新面 `initState` 时会把这里改写成自己，旧面据此让权。
  static final Map<String, State> _liveSurfacesByController = {};

  @override
  void initState() {
    super.initState();
    _liveSurfacesByController[_controllerName] = this;
    _adoptPreloadedController();
  }

  @override
  void dispose() {
    // 只在「登记的还是自己」时才处理：同帧交接场景下后来者已把值改成它自己，
    // 此时既不能移除记录、更不能销毁 controller（那是新面正在用的）。
    if (_liveSurfacesByController[_controllerName] == this) {
      _liveSurfacesByController.remove(_controllerName);
      _dropCachedController(_controllerName);
    }
    super.dispose();
  }

  /// 渲染面销毁时**连带销毁**进程内缓存的 controller，即「不跨渲染面生命周期复用」。
  ///
  /// 起因：桌面端（Windows/macOS/Linux）插件 Tab **切走即销毁**
  /// （`shared/layouts/shell_layout.dart`，规避 #246 的 WebView2 残留灰块），
  /// 所以每次离开再回来都是一次完整的 dispose + 重新挂载。而重新挂载时 controller
  /// 命中缓存（`evaluated: true`），于是 `createController` / `onLoad` /
  /// `onLoadError` / `onJSLog` **一个都不跑**，`_adoptPreloadedController()` 又
  /// 无条件上报「加载完成」—— 这条路径上**任何**失败都必然表现为
  /// 「整页白屏 + 日志里一个字都没有」。实测正是如此：日志里白屏总是紧随第二条
  /// `WebF: start for loading ...(evaluated: true)`，且该次会话零异常
  /// （songloft-org/songloft#341）。
  ///
  /// 主动丢掉缓存后，每次挂载都退回**正常路径**：有 loading、有 20s 超时、有错误
  /// UI、有 console 转发。代价是页面 JS 状态（筛选项、滚动位置）会归零、bundle 要
  /// 重取 —— 这与 webview 分支在桌面端的行为**一致**（原生 WebView 被销毁后同样
  /// 重载），所以两条渲染路径不会再出现「行为不对称」这种更难排查的情况。
  ///
  /// 附带修掉两条长期拖慢排查的坑：重装插件后不必再完全退出客户端才能看到新 bundle；
  /// `[plugin][console]` 转发不再因命中缓存而静默失效。
  ///
  /// **不要**改成 `forceLoad: true` 来达到同样效果：那只是每次重新取 bundle，
  /// 缓存里那个 controller 仍然留着不放，内存与 `maxAliveInstances` 配额照旧被占。
  static void _dropCachedController(String name) {
    // 异步且无需等待：本方法从 dispose() 调用，不能 await。
    // 失败只吞掉——此时页面已经在拆了，抛出去只会盖掉真正的错误。
    WebFControllerManager.instance.removeAndDisposeController(name).catchError((
      Object e,
    ) {
      debugPrint('[plugin][webf] dispose cached controller "$name" failed: $e');
    });
  }

  /// 认领**已经在进程内缓存里**的 controller。
  ///
  /// `WebF.fromControllerName` 的 `onControllerCreated` **只在新建分支里回调**：
  /// webf 0.24.27 的 `AutoManagedWebFState._getOrCreateController()` 里那句
  /// `widget.onControllerCreated!(newController)` 位于
  /// `if (bundle != null && (controller == null || forceLoad))` 之内。命中缓存时
  /// 它、`createController`、`onLoad` **一个都不跑**（日志上的表征是
  /// `evaluated: true, status: PreloadingStatus.done`）。于是二次进入插件页时：
  ///
  ///   ① `onLoadStop` 永远不被调用 → `PluginRenderView` 的 20s 超时定时器必然烧到，
  ///      把**已经画好的页面**整个换成「页面加载失败 · 页面加载超时」。这不是偶发，
  ///      是同一进程内第二次进入必然复现（songloft-org/songloft#341 实测）；
  ///   ② `_controller` 恒为 null → 安全区与播放器状态推不下去、返回键问不到页面；
  ///   ③ `onControllerReady` 不回调 → 宿主拿不到本渲染面引用。
  ///
  /// 所以这三件在这里自己补上。
  ///
  /// ⚠️ **这条路径已降级为兜底。** `dispose()` 现在会连带销毁缓存里的 controller
  /// （见 `_dropCachedController`），因为「渲染面重新挂载 + controller 命中缓存」
  /// 会把任何失败都变成静默白屏。正常情况下这里查不到缓存、直接 return；
  /// 仍保留它是为了两种残留情形：同一 URL 的新旧渲染面在同一帧内交接（旧面让权、
  /// 不销毁），以及 Web/移动端 Offstage 保活下同插件出现第二个渲染面。
  void _adoptPreloadedController() {
    final cached = WebFControllerManager.instance.getControllerSync(
      _controllerName,
    );
    // 只认已经 evaluate 完的那份。还在 preloading 的交给正常路径的 `onLoad` 收尾 ——
    // 提前报「加载完成」会把 spinner 早收掉、露出还没画完的页面。
    if (cached == null || cached.disposed || !cached.evaluated) return;
    _controller = cached;
    // 桥与 delegate 挂在 controller 实例上，缓存命中拿到的是同一个实例、原本的
    // 赋值仍在。这里重设是因为**本 State 是新的**：闭包必须指向新 State 的方法，
    // 否则回调打到已 dispose 的旧 State 上。
    cached.javascriptChannel.onMethodCall = _onMethodCall;
    _installNavigationDelegate(cached);
    // onLoadStop 会 setState 父级，不能在 initState 里同步调。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 主题（亮暗 + 色板）必须补推一次：页面没有重载，而离开这段时间里用户可能
      // 换过主题，URL 的 ?theme= 只在真正加载时起作用，`didUpdateWidget` 也不会为
      // 「新 State 的首帧」触发。补推由紧随其后的 `_markPageReady()` 完成 ——
      // 它清签名再调 `_syncTheme()`，本 State 是新的所以必然真推一次。
      widget.onControllerReady(this);
      _markPageReady();
    });
  }

  /// 把「页面已就绪」这件事落地：推安全区 + 通知宿主收掉 loading。
  ///
  /// **必须幂等**，有两个原因：
  ///   ① 三个调用点（`onBuildSuccess` / `onLoad` / `_adoptPreloadedController`）
  ///      谁先到都算数；
  ///   ② `onBuildSuccess` 每次 `buildRootView()` 都回调，而 `widget.onLoadStop()`
  ///      会 setState 祖先（`PluginRenderView`）→ 重建 → WebF 重建 → 又一次
  ///      `buildRootView` → 又一次回调。**不守卫就是无限重建循环。**
  ///
  /// `onLoadError` 会把 `_pageReady` 打回 false，所以出错后再成功仍能重新上报。
  void _markPageReady() {
    if (!mounted || _pageReady) return;
    _pageReady = true;
    // 安全区必须在这里补推一次，两个理由：
    //   ① 首屏 —— build() 早于就绪回调，那时 `_pageReady` 还是 false 推不出去；
    //   ② 重挂 —— 页面 JS 状态归零，「注入过一次就不管」会让重挂后永久丢掉安全区。
    // 清签名而不是直接推：让 `_syncSafeArea` 里那条去重判断照常生效。
    _lastPushedInsetsSig = null;
    _syncSafeArea(_safeAreaInsets);
    // 色板同理，而且比安全区更不能省：它**没有** URL 兜底通道（`?theme=` 只带
    // light/dark），页面重挂后不补推就永久停在 common.css 的静态色上。
    _lastPushedThemeSig = null;
    _syncTheme();
    widget.onLoadStop();
  }

  @override
  void didUpdateWidget(covariant PluginRenderSurfaceWebF oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 首屏亮暗靠 URL 的 ?theme=、首屏色板靠 common.css 兜底，这里只处理运行中的
    // 切换。无条件调用，由 `_syncTheme` 内部去重（切主题包时 `widget.theme` 可能
    // 不变而色板变了，按 theme 比较会漏推）。
    _syncTheme();
    // 换插件才需要换整棵 WebF 子树（缓存理由见 `_webfChild`）。
    //
    // 判据刻意是**去掉 query 的 URL**，不是 `widget.url` 整串：`?theme=` 与
    // `access_token` 都会在原地变（切一次主题就变一次），而它们既不影响
    // `_controllerName`、也不影响已缓存的 controller —— `bundle` 只在**新建**
    // controller 时才被读取。按整串判会让每次切主题都白白重建一次子树，
    // 正好抵消掉缓存的意义。
    //
    // 真的换了插件时其实走不到这里（`_controllerName` 是 late final，宿主是靠
    // `ValueKey(_reloadSeq)` 或换页面来重建整个 State 的），这条只是自愈兜底。
    if (_controllerNameFor(widget.url) != _controllerName) _webfChild = null;
  }

  // ── PluginRenderController ──────────────────────────────────────────
  /// WebF 没有 `canGoBack`（`module/history.dart` 的 case 列表里只有
  /// length/state/back/forward/pushState/replaceState/go，controller 上也没有
  /// `goBack()`），所以「能否回退」只能问页面自己：`common.js` 注册的
  /// `requestBack` handler 判断 `history.length` 后回报是否已消费。
  @override
  Future<bool> goBackIfPossible() async {
    final controller = _controller;
    if (controller == null || !_pageReady) return false;
    try {
      final result = await controller.javascriptChannel.invokeMethod(
        _kRequestBackMethod,
        null,
      );
      final decoded = _decodeBool(result);
      if (decoded) {
        // webf 在 methodChannel 回调里改了 DOM、渲染树已脏，但没有任何
        // 指针事件/动画去 scheduleFrame，Flutter 不会发起新帧→画面冻结
        // （「逻辑消费成功、截图逐字节不变」）。这里主动请求一帧让脏树重绘。
        SchedulerBinding.instance.scheduleFrame();
      }
      return decoded;
    } catch (e) {
      // 页面没注册 handler（老插件 / common.js 未更新）或调用超时：
      // 当作「没消费」，由宿主退出路由，不能把返回键卡死。
      return false;
    }
  }

  /// WebF 是纯 Flutter 渲染、没有独立原生表面，不存在「原生 WebView 在系统层面
  /// 抢走键盘焦点」的问题（那是 #293 一类 platform view 才有的），故为空实现。
  @override
  void clearFocus() {}

  /// 直接驱动 WebF 自己的 `document.visibilityChange` —— 它会同步 `visibilityState`
  /// / `hidden` 两个 getter **并**派发 `visibilitychange` 事件，所以插件侧用的是
  /// 标准 Web API，不需要 Songloft 私有协议（也因此**不依赖服务端那份 common.js
  /// 的版本**，修复不受用户升不升级服务端影响）。
  ///
  /// 刻意**不**顺带调 `rootController.pause()` / `resume()`：WebF 在 App 级
  /// lifecycle 里是连着调的，但那是「整个应用进后台、可以停掉计时器与动画」的语义。
  /// 插件 Tab 被 Offstage 只是不可见，页面里的轮询/定时任务仍应继续跑（miot 的
  /// 播放状态轮询就靠它），停掉会让切回来时状态是过期的。
  @override
  void setPageVisible(bool visible) {
    // `view` getter 是 `_view!`，页面没加载完时会抛；`_pageReady` 同时兜住了
    // 「controller 已建但 document 还没 evaluate」这段窗口。
    final controller = _controller;
    if (controller == null || controller.disposed || !_pageReady) return;
    try {
      controller.view.document.visibilityChange(
        visible ? VisibilityState.visible : VisibilityState.hidden,
      );
    } catch (e) {
      // 可见性只是给页面的一条提示，推失败不能影响 Tab 切换本身。
      debugPrint('[PluginWebF] setPageVisible($visible) failed: $e');
    }
  }

  // ── 桥 ──────────────────────────────────────────────────────────────
  String _platformName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }

  /// JS → Dart。
  ///
  /// 请求体在两端都做 JSON 字符串化：WebF 的 method channel 对复杂对象的
  /// 序列化形态没有稳定契约，字符串是唯一两端都确定的载体。因此这里对
  /// String 与 Map 都做兼容解析，不假定其中一种。
  Future<dynamic> _onMethodCall(String method, dynamic args) async {
    if (method != _kHostCallMethod) return null;
    final req = _decodeRequest(args);
    if (req == null) {
      return jsonEncode({'ok': false, 'error': 'malformed host call payload'});
    }
    // `files` 命名空间只在 WebF 路径上存在，所以在这里截住、不进
    // `PluginHostDispatcher`（那个文件刻意 web-safe，而文件读取必然要 dart:io）。
    // 理由与作用域的完整说明见 `plugin_file_bridge.dart` 的头注释。
    if (req['ns'] == 'files') {
      try {
        final data = await PluginFileBridge.handle(
          req['method'] as String?,
          (req['params'] is Map)
              ? Map<String, dynamic>.from(req['params'] as Map)
              : <String, dynamic>{},
        );
        return jsonEncode({'ok': true, 'data': data});
      } catch (e) {
        return jsonEncode({'ok': false, 'error': e.toString()});
      }
    }
    final result = await _hostDispatcher.handleCall(req);
    return jsonEncode(result);
  }

  // ── 外链导航（songloft-org/songloft#341 Step 6）──────────────────────
  /// `window.open` 与 `<a href>` 点击的决策处理器。
  ///
  /// ## 为什么需要它（归因，与「window.open 是 no-op」的表面现象不同）
  ///
  /// WebF 的 `Window.open` 在 Dart 侧**是有实现的**（`dom/window.dart:71-74`）：
  /// 它调 `view.handleNavigationAction(...)`，而那里第一件事就是问
  /// `navigationDelegate`；产品没设 delegate 时拿到的是一个用默认处理器的新
  /// delegate，而默认处理器 **无条件返回 `cancel`**
  /// （`module/navigation.dart:85-106`）。所以「什么都没发生」不是 C++ 桥吞掉了
  /// 调用，而是被默认导航策略拦下了。
  ///
  /// 「C++ 到底有没有把 `window.open` 转发到 Dart」无法从 pub 包源码核实
  /// （`bridge/core/frame/window.cc` 不随包发布），**已在验证容器里实测确认转发**：
  /// 装上 delegate 后 `window.open('…/sl-open-1')` 与
  /// `window.open('…/sl-open-2','_blank')` 两种调用形态都各触发一次决策回调，
  /// 拿到的 `action.target` 与传入 URL 逐字符相同（WebF 的 Dart 绑定只声明了
  /// `args[0]`，多余的 `'_blank'` 无害）。→ 因此**不需要任何 JS 垫片**。
  ///
  /// ## 三档决策与各自的理由
  ///
  /// 1. **`#` 开头 → `allow`**。`handleNavigationAction` 里 hash 的
  ///    `pushState` + `HashChangeEvent` 处理**排在 cancel 检查之后**
  ///    （`view_controller.dart:1126-1134`），一刀切 cancel 会让页内锚点跳转
  ///    彻底失灵。
  /// 2. **同源 http(s) → `cancel` + 一条 warn**。刻意**不放行**：`navigate` 分支是
  ///    `rootController.load(target)`（`:1138-1143`），会把整个插件页替换掉 ——
  ///    而 URL 上带着 `access_token`、宿主那边的 loading / 20s 超时 / 返回键状态
  ///    全部错位。也刻意**不丢给系统浏览器**：那是插件自己的页面，扔到浏览器里
  ///    既没有 token 也不该脱离宿主。留一条 warn 让插件作者知道「WebF 下别做
  ///    多页跳转」。
  /// 3. **外部 http(s) / mailto / tel → 系统浏览器 + `cancel`**。这正是 miot
  ///    账号二次验证要的行为（它的登录页是第三方站点，本来就不该在插件页里开）。
  ///
  /// 其余 scheme（相对路径、`javascript:`、自定义 scheme）一律 `cancel` + 日志。
  /// **一律以 cancel 收尾**是唯一安全的默认：任何 `allow` 都意味着整页被换掉。
  Future<WebFNavigationActionPolicy> _decideNavigation(
    WebFNavigationAction action,
  ) async {
    final target = action.target.trim();
    if (target.startsWith('#')) {
      return WebFNavigationActionPolicy.allow;
    }
    final uri = Uri.tryParse(target);
    if (uri == null || !uri.hasScheme) {
      debugPrint('[plugin][nav] blocked relative navigation: $target');
      return WebFNavigationActionPolicy.cancel;
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'http' || scheme == 'https') {
      if (_isSameOrigin(uri, action.source)) {
        debugPrint(
          '[plugin][nav] blocked in-page navigation (WebF 下插件页不支持整页跳转): '
          '$target',
        );
        return WebFNavigationActionPolicy.cancel;
      }
    } else if (scheme != 'mailto' && scheme != 'tel') {
      debugPrint('[plugin][nav] blocked unsupported scheme: $target');
      return WebFNavigationActionPolicy.cancel;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      debugPrint('[plugin][nav] launched externally ok=$ok: $target');
    } catch (e) {
      debugPrint('[plugin][nav] launch failed: $target ($e)');
    }
    return WebFNavigationActionPolicy.cancel;
  }

  /// 同源判定：scheme + host + port 严格相等（与后端 HLS 反代的同源判定同一种
  /// 保守写法）。`source` 拿不到时按「非同源」处理 —— 那会把它交给系统浏览器，
  /// 比误判成同源后 cancel 掉、用户点了没反应要好。
  static bool _isSameOrigin(Uri target, String? source) {
    if (source == null || source.isEmpty) return false;
    final src = Uri.tryParse(source);
    if (src == null) return false;
    return target.scheme == src.scheme &&
        target.host == src.host &&
        target.port == src.port;
  }

  /// 装 delegate。
  ///
  /// **必须在 controller 构造之后**：`navigationDelegate` 不是构造参数
  /// （`launcher/controller.dart:799-828` 的参数列表里没有它 —— 上游
  /// `navigation.dart:96-103` 的文档示例写成 `WebFController(navigationDelegate:)`
  /// 是过时/错误的文档），它是构造后可写的属性，setter 会把值同步到已经建好的
  /// view（`controller.dart:288-294`）。
  ///
  /// 两个调用点都要装：`_createController()`（首次）与 `onControllerCreated`
  /// （被 `WebFControllerManager` 淘汰后重建时 `createController` 不一定再跑，
  /// 与那里兜住 `_controller` 引用和桥是同一个理由）。
  void _installNavigationDelegate(WebFController controller) {
    final delegate = WebFNavigationDelegate();
    delegate.setDecisionHandler(_decideNavigation);
    controller.navigationDelegate = delegate;
  }

  static Map<String, dynamic>? _decodeRequest(dynamic args) {
    // JS 侧 invokeMethod(method, payload) 会把参数摊成 List
    dynamic payload = args;
    if (payload is List) {
      if (payload.isEmpty) return null;
      payload = payload.first;
    }
    if (payload is String) {
      try {
        payload = jsonDecode(payload);
      } catch (_) {
        return null;
      }
    }
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return null;
  }

  static bool _decodeBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      if (value == 'true') return true;
      if (value == 'false') return false;
      try {
        return jsonDecode(value) == true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Dart → JS。沿用既有的 `window.postMessage` 协议 —— WebF 的
  /// `window.postMessage` 是同窗口自发自收（直接在同一 window 上 dispatch
  /// MessageEvent），所以 `common.js` 的**接收侧一行都不用改**。
  void _pushToPage(String messageLiteral) {
    // evaluateJavaScripts 返回 Future<void>，拿不到返回值；这里两处推送
    // 都不需要返回值。
    _controller?.view.evaluateJavaScripts(
      'window.postMessage($messageLiteral,"*")',
    );
  }

  /// 安全区（刘海屏 / 圆角屏 / 手势条）下推 —— WebF 不实现
  /// `env(safe-area-inset-*)`（songloft-org/songloft#341）。
  ///
  /// WebF 里 `css/keywords.dart` 那 6 个 `SAFE_AREA_INSET*` / `ENV` 常量是全库
  /// 无引用的死常量，连解析入口都没有，所以插件页写 `env()` 在 WebF 下会顶到状态栏
  /// 或被下巴切掉。宿主这边负责把真实 inset 注入成 CSS 变量 `--sl-safe-*`，
  /// 插件侧统一写 `var(--sl-safe-bottom)`（默认值与三种环境下的取值见
  /// `internal/jsplugin/assets/common.css` 里那段注释）。
  ///
  /// 用 `viewPadding` 而不是 `padding`：前者是「不扣掉键盘遮挡」的安全区，
  /// 与浏览器 `env(safe-area-inset-*)` 的语义一致（软键盘弹出时 `env()` 不变）。
  /// 注意插件页外层是 `SafeArea`（`plugin_tab_page_native.dart` 是
  /// `SafeArea(bottom: false)`），而 Flutter 的 `MediaQuery.removePadding` 会把
  /// `viewPadding` 一并按已消费的 `padding` 扣减，所以这里读到的正是**剩给页面
  /// 自己处理**的那部分 —— 上层已经让开的边不会被重复内缩。
  /// 亮暗标记 + 宿主真实色板下推。
  ///
  /// 色板必须走消息而不能走 URL：`?theme=` 只带 light/dark 两个字，而
  /// `ColorScheme` 有三十来个角色色、还会被 ThemePack 整体换掉。首帧靠
  /// `common.css` 的静态兜底（值由同一个默认 seed 导出，所以不会闪成另一套颜色）。
  ///
  /// **载荷本身就是去重签名** —— 与 `_insetsSignature` 同一手法，两者不可能不一致。
  /// 去重是必需的：`Theme` 是 InheritedWidget，祖先任何重建都会让 `build()` 再跑，
  /// 不去重就是每帧一次 `evaluateJavaScripts`（一次还带三十几个颜色的 JSON）。
  void _syncTheme() {
    if (!_pageReady) return;
    final cs = _colorScheme;
    // cs 为 null 只可能是「ready 回调跑在首次 build 之前」这种理论情况；
    // 此时退化成只推亮暗标记，颜色留给 common.css 的兜底值，不能因此不推主题。
    final colors =
        cs == null ? '' : ',colors:${jsonEncode(pluginColorSchemeMap(cs))}';
    final payload = "{type:'songloft-theme',theme:'${widget.theme}'$colors}";
    if (payload == _lastPushedThemeSig) return;
    _lastPushedThemeSig = payload;
    _pushToPage(payload);
  }

  void _syncSafeArea(EdgeInsets insets) {
    _safeAreaInsets = insets;
    if (!_pageReady) return;
    final sig = _insetsSignature(insets);
    // 去重：MediaQuery 依赖变化会让 build() 反复跑（转屏、进退全屏、键盘），
    // 不去重就是每帧一次 evaluateJavaScripts。
    if (sig == _lastPushedInsetsSig) return;
    _lastPushedInsetsSig = sig;
    _pushToPage("{type:'songloft-safe-area',insets:$sig}");
  }

  /// 既当去重签名又当推送载荷 —— 两者用同一份字符串，不可能不一致。
  static String _insetsSignature(EdgeInsets i) {
    String n(double v) => v.toStringAsFixed(2);
    return '{top:${n(i.top)},right:${n(i.right)},'
        'bottom:${n(i.bottom)},left:${n(i.left)}}';
  }

  void _listenPlayerState() {
    ref.listen<PlayerState>(playerStateProvider, (prev, next) {
      final sig = _hostDispatcher.stateSignature(next);
      if (sig == _lastPushedStateSig) return;
      _lastPushedStateSig = sig;
      if (!_pageReady) return;
      final json = jsonEncode(_hostDispatcher.stateToJson(next));
      _pushToPage("{type:'songloft-player-state',state:$json}");
    });
  }

  // ── 渲染 ────────────────────────────────────────────────────────────
  WebFController _createController() {
    _ensureWebFProcessSetup();
    widget.onLoadStart();
    final controller = WebFController(
      // 关掉 WebF 自己的 HTTP 缓存（songloft-org/songloft#341）。
      //
      // 实测日志里反复出现 `WebF.HttpCache Cache validation failed / Missing
      // cache files`，并伴随 `Bytecode are not valid to execute.` —— 因果链是：
      // 缓存吐出残缺的脚本内容 → dumpQuickjsByteCode 编译出无效字节码 →
      // script.dart 的 isBytecode 分支**没有回退**（同为字节码执行的
      // to_native.dart 那条有「失败即删缓存、退回原始 JS」的自愈），于是脚本
      // 静默不执行、整个插件页功能缺失。
      //
      // 代价极小：插件静态资源本来就是内容哈希文件名（app.bundle.<hash>.js），
      // 缓存命中率的收益有限，而缓存损坏的代价是整页不可用。
      networkOptions: const WebFNetworkOptions(enableHttpCache: false),
      // 就绪的**次要**信号。主信号是 `onBuildSuccess`（见 build() 里的注释）——
      // `onLoad` 在「同一页面第二次挂载」时会不来。两条都指向幂等的 `_markPageReady`，
      // 谁先到算谁。
      onLoad: (_) => _markPageReady(),
      onLoadError: (error, stack) {
        _pageReady = false;
        _lastPushedInsetsSig = null;
        widget.onError(error.message);
      },
      // 页面内的 JS 异常必须落日志。
      //
      // 实测教训（songloft-org/songloft#341）：WebF 的
      // `Bytecode are not valid to execute.` 是**次级症状** —— 前面有未捕获的
      // JS 异常污染了 QuickJS 上下文，之后的脚本编译才整体失败。而那条报错既不
      // 带 URL 也不带原始异常，只看它无法归因。没有这里的转发，用户日志里就只
      // 剩下那句无用的字节码报错，真正的第一现场丢失。
      onJSError: (message) {
        debugPrint('[plugin][js-error] $message');
      },
    );
    // onJSLog 是字段而非构造参数，只能构造后赋值。
    // 插件页的 console 输出同样要能进日志，否则排查只能靠猜。
    controller.onJSLog = (level, message) {
      debugPrint('[plugin][console] $message');
    };
    controller.javascriptChannel.onMethodCall = _onMethodCall;
    _installNavigationDelegate(controller);
    _controller = controller;
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    _listenPlayerState();
    // 在 build() 里读，是为了建立 MediaQuery 依赖：转屏 / 进退全屏 / 键盘弹出
    // 都会让本 widget 重建，从而自动重推。去重在 `_syncSafeArea` 内部做。
    _syncSafeArea(MediaQuery.viewPaddingOf(context));
    // 同理建立 Theme 依赖：切亮暗 / 换主题包都会让本 widget 重建并自动重推。
    _colorScheme = Theme.of(context).colorScheme;
    _syncTheme();

    return FutureBuilder<void>(
      // 图标字体必须在渲染面出字之前注册好，否则首屏图标是豆腐块。
      // ensureLoaded 幂等，只有首次真正做事。
      future: PluginRenderFonts.ensureLoaded(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.expand();
        }
        // 复用同一个 widget 实例，理由见 `_webfChild` 的注释。
        final webfChild =
            _webfChild ??= WebF.fromControllerName(
              controllerName: _controllerName,
              bundle: WebFBundle.fromUrl(widget.url),
              createController: _createController,
              // ⚠️ 只在**新建** controller 时回调，命中进程内缓存时不会跑。
              // 缓存命中那条路由 `_adoptPreloadedController()` 处理，两边要一起改。
              onControllerCreated: (controller) {
                // 被淘汰后重建时 createController 不一定再跑，这里兜住引用与桥。
                _controller = controller;
                controller.javascriptChannel.onMethodCall = _onMethodCall;
                // delegate 同理要重设：没有它页面里的外链会退回上游那个「无条件
                // cancel」的默认处理器 —— 表现是「重挂之后点外链没反应」，
                // 而首次挂载时是好的，极难归因。
                _installNavigationDelegate(controller);
                widget.onControllerReady(this);
              },
              // 「页面已就绪」的**主信号**，不要只依赖 `onLoad`。
              //
              // `onLoad` 由 `checkCompleted()` → `dispatchWindowLoadEvent()` 触发，而
              // `checkCompleted()`（webf `controller.dart:1718`）有四道 early-return：
              // `document.parsing` / `isDelayingDOMContentLoadedEvent` /
              // `hasPendingRequest` / `isDelayingLoadEvent`。任一条命中就直接 return，
              // 之后**没有任何东西保证它会被再调一次** —— 实测同一个页面首次挂载
              // `onLoad` 正常、第二次挂载（响应从 ~279ms 变成 ~6ms）就再也不来，
              // 表现是页面其实画好了、JS 也跑完了，却被 20s 超时定时器换成
              // 「页面加载失败」（songloft-org/songloft#341）。
              //
              // `onBuildSuccess` 相反：它在 `buildRootView()` 真的把根视图建出来之后
              // post-frame 回调，且**只在成功分支**调（webf `widget/webf.dart:673 / :723`，
              // 各种 error 分支都不调）。这正是我们要表达的语义 —— 「页面画出来了」。
              //
              // 会重复回调（每次 `buildRootView` 都调），`onLoadStop` 与
              // `_markPageReady` 都是幂等的。
              onBuildSuccess: _markPageReady,
              loadingWidget: const SizedBox.expand(),
              errorBuilder: (context, error) {
                // 交给 PluginRenderView 统一的错误 UI，这里不自绘。
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    widget.onError(error?.toString() ?? 'WebF error');
                  }
                });
                return const SizedBox.expand();
              },
            );

        // ── 让 webf-ui 原生控件跟随**插件页主题**，而不是操作系统外观 ──────────
        //
        // `<flutter-cupertino-*>` 是真正的 Cupertino widget，它们的默认色是
        // `CupertinoColors.systemGrey6.resolveFrom(context)` 这类**动态色**
        // （`webf_cupertino_ui/input.dart:330`：输入框无 CSS 背景时的底色）。
        // `resolveFrom` 先读 `CupertinoTheme.maybeBrightnessOf(context)`，取不到
        // 才回落 `MediaQuery.platformBrightness`（= 操作系统的深浅色）。
        //
        // 而这条渲染路径此前**没有任何 CupertinoTheme 祖先**，于是原生控件一律按
        // **系统外观**取色：系统深色 + 应用浅色主题时，输入框是深的、页面 CSS
        // （`--md-*`，跟随应用主题）是浅的 —— 半亮半暗；且切换应用主题时原生控件
        // 纹丝不动（`platformBrightness` 只随系统变），只有重启客户端（重新加载、
        // 首帧就带对的系统/主题组合）才碰巧一致（songloft-org/songloft#341）。
        //
        // 在此注入一个 brightness = 插件页主题 的 `CupertinoTheme`：
        //   · `resolveFrom` 命中它 → 原生控件底色/描边跟随 `widget.theme`；
        //   · 它是 InheritedWidget，切主题时 `widget.theme` 变 → 本 widget 重建 →
        //     新的 CupertinoThemeData → 依赖它的原生控件收到通知重算，实时跟随；
        //   · 包在**外层**、child 仍是缓存的 `_webfChild` 同一实例 →
        //     `Element.updateChild` 照旧短路 WebF 子树，缓存语义不受影响
        //     （只是多一层极轻的 InheritedWidget）。
        // 只设 brightness：primaryColor 等留默认。downloader 的按钮走 plain + CSS
        // 配色（见主仓 docs/webf/handoff.md 第 23 条），开关主色由插件用
        // getColorScheme() 显式喂 activeColor，都不依赖 CupertinoTheme.primaryColor。
        return CupertinoTheme(
          data: CupertinoThemeData(
            brightness:
                widget.theme == 'dark' ? Brightness.dark : Brightness.light,
          ),
          child: webfChild,
        );
      },
    );
  }
}
