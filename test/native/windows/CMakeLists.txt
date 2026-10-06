cmake_minimum_required(VERSION 3.14)
project(webview_window_sync_test LANGUAGES CXX)

# Exercise the runner's movement logic on any host. This Win32 stub models HWND
# ownership and geometry; it does not replace a Windows/WebView2 smoke test.
add_executable(webview_window_sync_test
  webview_window_sync_test.cpp
  ../../../windows/runner/webview_window_sync.cpp
)
target_compile_features(webview_window_sync_test PRIVATE cxx_std_17)
target_include_directories(webview_window_sync_test PRIVATE
  win32_stub
  ../../../windows/runner
)
if(MSVC)
  target_compile_options(webview_window_sync_test PRIVATE /W4 /WX)
else()
  target_compile_options(webview_window_sync_test PRIVATE -Wall -Wextra -Werror)
endif()
enable_testing()
add_test(NAME webview_window_sync COMMAND webview_window_sync_test)
