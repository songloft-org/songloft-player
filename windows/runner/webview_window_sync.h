#ifndef RUNNER_WEBVIEW_WINDOW_SYNC_H_
#define RUNNER_WEBVIEW_WINDOW_SYNC_H_

#include <windows.h>

// flutter_inappwebview_windows 0.6.0 renders a texture but also creates an
// independent, owned CustomPlatformView HWND. Keep that HWND's screen position
// in sync without recreating the WebView or losing its JavaScript state.
class WebViewWindowSync {
 public:
  void Reset(HWND owner, HWND flutter_view);
  void Sync();

 private:
  HWND owner_ = nullptr;
  HWND flutter_view_ = nullptr;
  POINT last_origin_ = {};
  bool has_origin_ = false;
};

#endif  // RUNNER_WEBVIEW_WINDOW_SYNC_H_
