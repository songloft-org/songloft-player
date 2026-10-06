#include "webview_window_sync.h"

#include <algorithm>
#include <cwchar>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

struct FakeWindow {
  HWND owner = nullptr;
  DWORD thread = 1;
  bool top_level = true;
  bool minimized = false;
  bool readable = true;
  std::wstring class_name = L"CustomPlatformView";
  POINT origin = {100, 200};
  RECT bounds = {120, 250, 920, 850};
};

namespace {

std::vector<HWND> windows;
int move_count = 0;
WebViewWindowSync* reentrant_sync = nullptr;

void Require(bool condition, const char* message) {
  if (!condition) {
    throw std::runtime_error(message);
  }
}

struct Fixture {
  FakeWindow owner;
  FakeWindow view;
  FakeWindow popup;
  WebViewWindowSync sync;

  Fixture() {
    move_count = 0;
    reentrant_sync = nullptr;
    owner.class_name = L"FLUTTER_RUNNER_WIN32_WINDOW";
    view.top_level = false;
    popup.owner = &owner;
    windows = {&owner, &view, &popup};
    sync.Reset(&owner, &view);
  }
};

void TestCrossMonitorMoves() {
  Fixture f;
  f.view.origin = {-1820, -880};
  f.sync.Sync();
  Require(f.popup.bounds.left == -1800 && f.popup.bounds.top == -830,
          "left/top monitors must keep signed coordinates and offsets");
  Require(f.popup.bounds.right - f.popup.bounds.left == 800 &&
              f.popup.bounds.bottom - f.popup.bounds.top == 600,
          "moving must preserve WebView dimensions");
  f.view.origin = {100, 200};
  f.sync.Sync();
  Require(f.popup.bounds.left == 120 && f.popup.bounds.top == 250,
          "moving back must not accumulate drift");
  Require(move_count == 2, "each actual move must be applied once");
}

void TestWindowFiltering() {
  Fixture f;
  FakeWindow other_owner;
  FakeWindow other_engine;
  other_engine.owner = &other_owner;
  FakeWindow dialog;
  dialog.owner = &f.owner;
  dialog.class_name = L"Dialog";
  FakeWindow other_thread;
  other_thread.owner = &f.owner;
  other_thread.thread = 2;
  FakeWindow second_webview;
  second_webview.owner = &f.owner;
  // Include a hidden owned HWND, as used by the composition controller.
  windows.insert(windows.end(),
                 {&other_engine, &dialog, &other_thread, &second_webview});
  f.view.origin.x += 50;
  f.sync.Sync();
  Require(move_count == 2, "only this engine's WebView HWNDs should move");
  Require(f.popup.bounds.left == 170 && second_webview.bounds.left == 170,
          "all owned WebView windows must follow the runner");
  Require(other_engine.bounds.left == 120 && dialog.bounds.left == 120 &&
              other_thread.bounds.left == 120,
          "other windows must keep their original positions");
}

void TestNoMoveAndReentry() {
  Fixture f;
  f.sync.Sync();
  Require(move_count == 0, "size-only/duplicate events must not move windows");
  reentrant_sync = &f.sync;
  f.view.origin.x += 80;
  f.sync.Sync();
  reentrant_sync = nullptr;
  Require(move_count == 1 && f.popup.bounds.left == 200,
          "nested window messages must not apply the delta twice");
}

void TestMinimizeAndRestore() {
  Fixture f;
  f.owner.minimized = true;
  f.view.origin = {-32000, -32000};
  f.sync.Sync();
  Require(move_count == 0, "minimized coordinates must not move the WebView");
  f.owner.minimized = false;
  f.view.origin = {400, 500};
  f.sync.Sync();
  Require(f.popup.bounds.left == 420 && f.popup.bounds.top == 550,
          "restoring must use the last non-minimized origin");
}

void TestPluginPositionUpdates() {
  Fixture f;
  f.view.origin = {200, 300};
  f.sync.Sync();
  // A click or DPI/layout update can independently reposition the native HWND.
  f.popup.bounds = {235, 360, 1435, 1260};
  f.view.origin = {-1700, 100};
  f.sync.Sync();
  Require(f.popup.bounds.left == -1665 && f.popup.bounds.top == 160,
          "movement must preserve the latest plugin-computed offset");
  Require(f.popup.bounds.right - f.popup.bounds.left == 1200,
          "movement must not undo a plugin DPI/size update");
}

void TestCreationAndTeardown() {
  Fixture f;
  windows = {&f.owner, &f.view};
  f.view.origin.x += 100;
  f.sync.Sync();
  // A newly created WebView starts at the current, not the initial position.
  f.popup.bounds = {220, 250, 1020, 850};
  windows.push_back(&f.popup);
  f.view.origin.x += 30;
  f.sync.Sync();
  Require(f.popup.bounds.left == 250 && move_count == 1,
          "movement before WebView creation must not leave a stale baseline");
  f.sync.Reset(nullptr, nullptr);
  f.view.origin.x += 40;
  f.sync.Sync();
  Require(move_count == 1, "teardown must disable synchronization");
}

void TestUnavailableGeometry() {
  Fixture f;
  f.view.readable = false;
  f.view.origin.x += 80;
  f.sync.Sync();
  Require(move_count == 0, "failed origin queries must not move windows");
  f.view.readable = true;
  f.sync.Sync();
  Require(f.popup.bounds.left == 200,
          "failed queries must not overwrite the last valid baseline");
  f.popup.readable = false;
  f.view.origin.x += 20;
  f.sync.Sync();
  Require(move_count == 1, "unavailable/destroyed HWNDs must be skipped");
}

}  // namespace

HWND GetWindow(HWND window, UINT command) {
  Require(command == GW_OWNER, "lookup must use owner, not parent");
  return window->owner;
}

int GetClassNameW(HWND window, wchar_t* name, int capacity) {
  if (!window->readable || capacity <= 0) {
    return 0;
  }
  const auto size = std::min(window->class_name.size(),
                             static_cast<std::size_t>(capacity - 1));
  std::wmemcpy(name, window->class_name.c_str(), size);
  name[size] = L'\0';
  return static_cast<int>(size);
}

BOOL GetWindowRect(HWND window, RECT* bounds) {
  if (!window->readable) {
    return 0;
  }
  *bounds = window->bounds;
  return TRUE;
}

BOOL ClientToScreen(HWND window, POINT* point) {
  if (!window->readable) {
    return 0;
  }
  point->x += window->origin.x;
  point->y += window->origin.y;
  return TRUE;
}

BOOL IsIconic(HWND window) { return window->minimized; }

DWORD GetWindowThreadProcessId(HWND window, DWORD*) { return window->thread; }

BOOL EnumThreadWindows(DWORD thread, WNDENUMPROC callback, LPARAM parameter) {
  for (const auto window : windows) {
    if (window->top_level && window->thread == thread &&
        !callback(window, parameter)) {
      return 0;
    }
  }
  return TRUE;
}

BOOL SetWindowPos(HWND window, HWND after, int x, int y, int width, int height,
                  UINT flags) {
  Require(after == nullptr && width == 0 && height == 0 &&
              flags == (SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE),
          "synchronization must not resize, reorder or activate windows");
  const LONG dx = x - window->bounds.left;
  const LONG dy = y - window->bounds.top;
  window->bounds = {x, y, window->bounds.right + dx,
                    window->bounds.bottom + dy};
  ++move_count;
  if (reentrant_sync) {
    reentrant_sync->Sync();
  }
  return TRUE;
}

int main() {
  try {
    TestCrossMonitorMoves();
    TestWindowFiltering();
    TestNoMoveAndReentry();
    TestMinimizeAndRestore();
    TestPluginPositionUpdates();
    TestCreationAndTeardown();
    TestUnavailableGeometry();
    std::cout << "7 WebView window synchronization tests passed\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
