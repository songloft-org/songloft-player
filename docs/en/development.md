# Development Guide

## Environment Setup

### Prerequisites

- Flutter >= 3.29.0
- Dart SDK >= 3.7.0

### Platform-Specific Dependencies

**Linux:**

```bash
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev
```

**Android:**

```bash
sdkmanager --licenses
```

Requires Android SDK, NDK, and JDK 17+.

**macOS / iOS:**

- Xcode 15+
- CocoaPods: `sudo gem install cocoapods`

**Windows:**

- Visual Studio 2022 (with C++ Desktop Development workload)
- Windows 10 SDK

### First Run

```bash
flutter pub get
flutter run -d chrome --no-web-resources-cdn   # Web standalone
flutter run -d macos                            # macOS
```

The backend must be started first: run `make run` in the parent repository (default `http://localhost:58091`, credentials admin/admin).

---

## Adding a Feature Module

The project follows a Feature-First architecture. Each feature module has a three-layer structure:

```
features/<name>/
├── data/              # API classes (HTTP calls) + Repository
│   ├── <name>_api.dart
│   └── <name>_repository.dart  (optional)
├── domain/            # State models + business logic
│   └── <name>_state.dart
└── presentation/      # UI layer
    ├── <name>_page.dart
    ├── providers/
    │   └── <name>_provider.dart
    └── widgets/
        └── <name>_xxx.dart
```

### Provider Naming Conventions

Providers are written by hand using Riverpod (**no** code generation / build_runner):

```dart
// API instance (stateless)
final xxxApiProvider = Provider<XxxApi>((ref) {
  final dio = ref.watch(dioProvider);
  return XxxApi(dio);
});

// Async data loading
final xxxDetailProvider = FutureProvider.family<Xxx, int>((ref, id) async {
  final api = ref.watch(xxxApiProvider);
  return api.getDetail(id);
});

// Stateful business logic
final xxxProvider = NotifierProvider<XxxNotifier, XxxState>(XxxNotifier.new);

// Async stateful
final xxxListProvider = AsyncNotifierProvider<XxxListNotifier, XxxListState>(
  XxxListNotifier.new,
);
```

---

## Adding Routes

Routes are configured in `lib/core/router/app_router.dart`:

1. Add a path constant in the `AppRoutes` class:

```dart
class AppRoutes {
  static const String myFeature = '/my-feature';
}
```

2. Add the route to the `GoRouter` inside `routerProvider` (either within the Shell or as a standalone route):

```dart
GoRoute(
  path: AppRoutes.myFeature,
  builder: (context, state) => const MyFeaturePage(),
),
```

3. The auth guard works automatically: `redirect` checks `authStateProvider` and redirects to `/login` when unauthenticated. The `/login` path is not protected by the guard.

---

## API Integration

### HTTP Client

Dio is wrapped in `lib/core/network/api_client.dart`:

- `dioProvider` — Dio instance with auth interceptor
- `publicDioProvider` — Dio without auth (for public endpoints like login)
- `apiClientProvider` — Higher-level wrapper (rarely used directly)

### JWT Dual-Token

`AuthInterceptor` (`lib/core/network/auth_interceptor.dart`) handles automatically:

- Injects `Authorization: Bearer <accessToken>` on each request
- Refreshes the token using refreshToken on 401 responses
- Concurrent refresh protection (multiple 401s trigger only one refresh)
- Calls `onTokenExpired` callback to trigger logout on refresh failure

### Resource URLs

`UrlHelper` (`lib/core/utils/url_helper.dart`) constructs cover image, audio, and other resource URLs by appending baseUrl + token automatically.

### Adding an API Class

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

## Conditional Imports

Web does not support certain native features (e.g. WebView). Use the conditional import stub pattern:

```dart
// plugin_webview_page.dart (entry file)
export 'plugin_webview_page_stub.dart'
    if (dart.library.io) 'plugin_webview_page_native.dart';
```

```dart
// plugin_webview_page_stub.dart (Web — show placeholder or alternative UI)
class PluginWebViewPage extends StatelessWidget { ... }

// plugin_webview_page_native.dart (native — use WebView)
class PluginWebViewPage extends StatelessWidget { ... }
```

Files in the project using this pattern:

- `plugin_webview_page.dart` / `_native.dart` / `_stub.dart`
- `plugin_tab_page.dart` / `_native.dart` / `_stub.dart`
- `web_cache_clearer.dart` / `_stub.dart`

---

## Lint Rules

Key rules in `analysis_options.yaml`:

| Rule | Description |
|------|-------------|
| `prefer_const_constructors` | Add `const` to widget instantiation where possible |
| `prefer_const_declarations` | Declare variables as `const` when applicable |
| `prefer_single_quotes` | Use single quotes consistently |
| `avoid_print` | Disallow `print()`; use `debugPrint()` instead |

Excluded: `*.g.dart` and `*.freezed.dart` files are not checked.

---

## Testing

```bash
flutter test                                    # Run all tests
flutter test test/core/env/tv_detector_test.dart # Run a specific file
```

Test files live under `test/`, mirroring the path structure of `lib/`.
