#include "webview_window_sync.h"

#include <cwchar>

namespace {

struct MoveContext {
  HWND owner;
  LONG dx;
  LONG dy;
};

BOOL CALLBACK MoveWebViewWindow(HWND window, LPARAM parameter) {
  const auto& move = *reinterpret_cast<const MoveContext*>(parameter);
  // CreateWindowEx promotes a child HWND owner to its top-level parent. Match
  // the runner HWND, not the Flutter child, and leave other engines untouched.
  if (GetWindow(window, GW_OWNER) != move.owner) {
    return TRUE;
  }

  wchar_t class_name[32] = {};
  if (!GetClassNameW(window, class_name, 32) ||
      std::wcscmp(class_name, L"CustomPlatformView") != 0) {
    return TRUE;
  }

  RECT bounds = {};
  if (GetWindowRect(window, &bounds)) {
    // Preserve the offset computed by the plugin, including monitor DPI and
    // decoration offsets. Screen coordinates stay signed for left/top monitors.
    SetWindowPos(window, nullptr, bounds.left + move.dx, bounds.top + move.dy,
                 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
  }
  return TRUE;
}

}  // namespace

void WebViewWindowSync::Reset(HWND owner, HWND flutter_view) {
  owner_ = owner;
  flutter_view_ = flutter_view;
  last_origin_ = {};
  has_origin_ =
      owner_ && flutter_view_ && ClientToScreen(flutter_view_, &last_origin_);
}

void WebViewWindowSync::Sync() {
  // Minimized coordinates are not a useful baseline. The existing visibility
  // handler unmounts the WebView while minimized (songloft-org/songloft#293).
  if (!owner_ || !flutter_view_ || IsIconic(owner_)) {
    return;
  }

  POINT origin = {};
  if (!ClientToScreen(flutter_view_, &origin)) {
    return;
  }
  const MoveContext move = {owner_, origin.x - last_origin_.x,
                            origin.y - last_origin_.y};
  const bool had_origin = has_origin_;
  // SetWindowPos can reenter window message handlers. Advance the baseline
  // before moving any owned HWND so a nested notification cannot move it twice.
  last_origin_ = origin;
  has_origin_ = true;
  if (!had_origin || (move.dx == 0 && move.dy == 0)) {
    return;
  }

  const DWORD thread = GetWindowThreadProcessId(flutter_view_, nullptr);
  if (thread != 0) {
    EnumThreadWindows(thread, MoveWebViewWindow,
                      reinterpret_cast<LPARAM>(&move));
  }
}
