#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "desktop_multi_window/desktop_multi_window_plugin.h"
#include "screen_retriever_windows/screen_retriever_windows_plugin_c_api.h"
#include "window_manager/window_manager_plugin.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  // 桌面歌词悬浮窗（songloft-org/songloft#318）：desktop_multi_window 为每个新窗口
  // 创建独立 Flutter engine，插件必须按 engine 各注册一次，否则悬浮窗里调不到。
  //
  // 这里**只注册悬浮窗真正用到的插件**，绝对不能图省事调 RegisterPlugins() 全量注册：
  // media_kit_video 的插件构造函数会把自己写进进程级静态 instance_，并用
  // SetWindowLongPtr(GWLP_WNDPROC) 劫持所在窗口的消息过程，而它那个静态
  // WindowProcDelegate 统一通过 instance_ 回落到 original_window_proc_。一旦第二个
  // engine 也注册它，instance_ 就被改写成悬浮窗那份，**主窗口**的消息随即被转发进
  // desktop_multi_window 自己的 window class 过程，把主窗口 GWLP_USERDATA 上的
  // runner Win32Window* 当成插件的 Win32Window* 用——类型混淆，进程当场崩溃。
  // 这正是「打开桌面歌词开关后程序秒退」的成因。
  //
  // 悬浮窗需要：window_manager（无边框/置顶/位置/点击穿透/拖动）、
  // screen_retriever（多屏坐标）。desktop_multi_window 自身的 channel 由插件在
  // MultiWindowManager::Create 内部注册；shared_preferences / path_provider 在
  // Windows 上是纯 Dart 实现，都不需要在这里出现。新增悬浮窗能力时按需**单独**加，
  // 加之前先确认该插件不会碰进程级静态状态或窗口消息过程。
  DesktopMultiWindowSetWindowCreatedCallback([](void* controller) {
    auto* flutter_view_controller =
        reinterpret_cast<flutter::FlutterViewController*>(controller);
    auto* registry = flutter_view_controller->engine();
    WindowManagerPluginRegisterWithRegistrar(
        registry->GetRegistrarForPlugin("WindowManagerPlugin"));
    ScreenRetrieverWindowsPluginCApiRegisterWithRegistrar(
        registry->GetRegistrarForPlugin("ScreenRetrieverWindowsPluginCApi"));
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  webview_window_sync_.Reset(GetHandle(),
                             flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([this]() {
    this->Show();
    // Showing the top-level window can apply its final monitor DPI. Correct the
    // Flutter child only when that changed the client size; unconditional
    // top-level resize jitter can leave the Windows surface on a stale frame.
    if (this->RefreshChildContentBounds()) {
      flutter_controller_->ForceRedraw();
    }
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  webview_window_sync_.Reset(nullptr, nullptr);
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // The WebView's independent HWND otherwise stays at the old screen position
  // and intercepts desktop input after a move (songloft-org/songloft#499).
  // Observe the applied position, including keyboard moves and DPI transitions,
  // before a plugin can consume the message and skip the default WM_MOVE path.
  if (message == WM_WINDOWPOSCHANGED) {
    webview_window_sync_.Sync();
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
