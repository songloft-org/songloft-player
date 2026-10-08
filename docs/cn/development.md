# 开发指南

## GitHub 社区插件发现

入口：设置 → 扩展 → 插件商店 → 选源菜单 →「GitHub 发现」。这是独立发现页面，不作为订阅源保存；返回后保留商店的源和搜索状态，源设置按钮继续管理订阅源。

客户端直接搜索公开 `songloft-plugin` topic，校验根 `plugin.json`、同仓库更新链、哈希格式和对应稳定 Release 的 `.jsplugin.zip` 资产。支持搜索、排序、分页、刷新、GitHub 代理与限流提示；不合规和暂未验证分别计数。GitHub 请求不携带服务器登录凭据。

URL 校验在 Dart URI 规范化之前拒绝原始及编码的点路径段、反斜杠，与 Lynx 原生校验保持一致。安装成功的会话标记只用于刷新期间的状态同步；服务器列表刷新成功后会核对标记，防止其他页面卸载或替换插件后仍显示旧安装状态。

发布标签用于定位下载 URL 对应的真实 Release，不要求标签与清单版本相同；例如 `v0.17` 发布标签可配合 `0.17.0` 清单版本。仍核对下载 URL、实际 Release 标签与已上传资产，更新清单链的版本一致性检查保持生效。

详情显示版本、权限和最低宿主版本，安装前确认「未经 Songloft 审核」；同入口冲突需确认替换，宿主版本未知或不足、已安装信息未就绪时禁用安装。复用服务器现有插件安装接口，校验格式不代表安全审核。窄屏使用详情底部弹层，宽屏使用对话框。

服务端明确返回 `dev` 时，所有插件跳过最低宿主版本检查；正式版继续比较最低版本，版本请求失败或其他无法识别的版本仍需重试。`dev` 不跳过插件校验、已安装信息检查或安装确认。

验证：静态检查、完整 539 项测试及 Web 构建通过；中英西三语在窄屏/宽屏和大字体下的组件测试通过。Docker Chromium 实跑真实 GitHub 查询（7 个仓库：3 个有效、4 个过滤）、确认前零请求、确认后单次安装及返回商店；临时真实 Go 后端查询确认安装的版本和 Release 地址。原生 Flutter 设备尚未验证。

## 环境搭建

### 基础要求

- Flutter >= 3.41.0
- Dart SDK >= 3.7.0

### 平台额外依赖

**Linux：**

```bash
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev
```

**Android：**

```bash
sdkmanager --licenses
```

需要 Android SDK、NDK、JDK 17+。

**macOS / iOS：**

- Xcode 15+
- CocoaPods：`sudo gem install cocoapods`

**Windows：**

- Visual Studio 2022（带 C++ 桌面开发工作负载）
- Windows 10 SDK

### 首次运行

```bash
flutter pub get
flutter run -d chrome --no-web-resources-cdn   # Web standalone
flutter run -d macos                            # macOS
```

后端需要先启动：在父仓库执行 `make run`（默认 `http://localhost:58091`，账号 admin/admin）。

---

## 新增 Feature 模块

项目采用 Feature-First 架构，每个功能模块遵循三层结构：

```
features/<name>/
├── data/              # API 类（HTTP 调用）+ Repository
│   ├── <name>_api.dart
│   └── <name>_repository.dart  (可选)
├── domain/            # 状态模型 + 业务逻辑
│   └── <name>_state.dart
└── presentation/      # UI 层
    ├── <name>_page.dart
    ├── providers/
    │   └── <name>_provider.dart
    └── widgets/
        └── <name>_xxx.dart
```

### Provider 命名惯例

手写 Riverpod Provider（**不使用** code generation / build_runner）：

```dart
// API 实例（无状态）
final xxxApiProvider = Provider<XxxApi>((ref) {
  final dio = ref.watch(dioProvider);
  return XxxApi(dio);
});

// 异步数据加载
final xxxDetailProvider = FutureProvider.family<Xxx, int>((ref, id) async {
  final api = ref.watch(xxxApiProvider);
  return api.getDetail(id);
});

// 有状态的业务逻辑
final xxxProvider = NotifierProvider<XxxNotifier, XxxState>(XxxNotifier.new);

// 异步有状态
final xxxListProvider = AsyncNotifierProvider<XxxListNotifier, XxxListState>(
  XxxListNotifier.new,
);
```

---

## 路由添加

路由配置在 `lib/core/router/app_router.dart`：

1. 在 `AppRoutes` 类中添加路径常量：

```dart
class AppRoutes {
  static const String myFeature = '/my-feature';
}
```

2. 在 `routerProvider` 的 `GoRouter` 中添加路由（Shell 内或独立）：

```dart
GoRoute(
  path: AppRoutes.myFeature,
  builder: (context, state) => const MyFeaturePage(),
),
```

3. 认证守卫自动工作：`redirect` 检查 `authStateProvider`，未登录时重定向到 `/login`，`/login` 路径不受守卫保护。

---

## API 对接

### HTTP 客户端

Dio 封装在 `lib/core/network/api_client.dart`：

- `dioProvider` — 带认证拦截器的 Dio 实例
- `publicDioProvider` — 无认证的 Dio（用于登录等公开接口）
- `apiClientProvider` — 高级封装（较少直接使用）

### JWT 双 Token

`AuthInterceptor`（`lib/core/network/auth_interceptor.dart`）自动处理：

- 请求时自动注入 `Authorization: Bearer <accessToken>`
- 401 响应时自动用 refreshToken 刷新
- 并发刷新保护（多个 401 只触发一次刷新）
- 刷新失败时回调 `onTokenExpired` 触发登出

### 资源 URL

`UrlHelper`（`lib/core/utils/url_helper.dart`）构建封面、音频等资源 URL，自动拼接 baseUrl + token。

### 新增 API 类

```dart
class MyFeatureApi {
  final Dio _dio;
  MyFeatureApi(this._dio);

  Future<MyModel> getData(int id) async {
    final response = await _dio.get('/api/v1/my-feature/$id');
    return MyModel.fromJson(response.data);
  }
}
```

---

## 条件导入

Web 平台不支持某些原生功能（如 WebView），使用条件导入 stub 文件模式：

```dart
// plugin_webview_page.dart（入口文件）
export 'plugin_webview_page_stub.dart'
    if (dart.library.io) 'plugin_webview_page_native.dart';
```

```dart
// plugin_webview_page_stub.dart（Web 平台 — 显示占位或替代 UI）
class PluginWebViewPage extends StatelessWidget { ... }

// plugin_webview_page_native.dart（原生平台 — 使用 WebView）
class PluginWebViewPage extends StatelessWidget { ... }
```

项目中使用此模式的文件：

- `plugin_webview_page.dart` / `_native.dart` / `_stub.dart`
- `plugin_tab_page.dart` / `_native.dart` / `_stub.dart`
- `web_cache_clearer.dart` / `_stub.dart`

---

## Lint 规则

`analysis_options.yaml` 中的关键规则：

| 规则 | 说明 |
|------|------|
| `prefer_const_constructors` | Widget 实例化时尽量加 `const` |
| `prefer_const_declarations` | 可以为 `const` 的变量声明为 `const` |
| `prefer_single_quotes` | 统一使用单引号 |
| `avoid_print` | 禁止 `print()`，使用 `debugPrint()` |

排除规则：`*.g.dart` 和 `*.freezed.dart` 不检查。

---

## 测试

```bash
flutter test                                    # 运行全部测试
flutter test test/core/env/tv_detector_test.dart # 运行单个文件
```

测试文件放在 `test/` 下，对应 `lib/` 的路径结构。

### GitHub 发现：跨仓库发布包（2026-10-08）

允许清单的下载地址和公开更新清单来自其他 GitHub 仓库。客户端按下载地址验证目标仓库的稳定 Release 和真实非空资产，保留版本、入口、哈希和 URL 校验。详情显示下载地址，安装确认显示发布包来源；已安装与更新状态按实际发布包仓库判断。

### GitHub 发现：根清单空哈希（2026-10-08）

根目录 plugin.json 的 entryHash、zipHash 可省略或留空；非空值继续校验格式。发现页不要求构建产物哈希回写到源码根清单，实际安装包仍由服务器校验。
