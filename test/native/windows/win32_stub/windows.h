#ifndef TEST_WIN32_STUB_WINDOWS_H_
#define TEST_WIN32_STUB_WINDOWS_H_

#include <cstdint>

struct FakeWindow;
using HWND = FakeWindow*;
using BOOL = int;
using DWORD = std::uint32_t;
using LONG = std::int32_t;
using LPARAM = std::intptr_t;
using UINT = unsigned int;
#define CALLBACK
constexpr BOOL TRUE = 1;
constexpr UINT GW_OWNER = 4;
constexpr UINT SWP_NOSIZE = 0x0001;
constexpr UINT SWP_NOZORDER = 0x0004;
constexpr UINT SWP_NOACTIVATE = 0x0010;

struct POINT {
  LONG x;
  LONG y;
};
struct RECT {
  LONG left;
  LONG top;
  LONG right;
  LONG bottom;
};
using WNDENUMPROC = BOOL(CALLBACK*)(HWND, LPARAM);

HWND GetWindow(HWND window, UINT command);
int GetClassNameW(HWND window, wchar_t* name, int capacity);
BOOL GetWindowRect(HWND window, RECT* bounds);
BOOL ClientToScreen(HWND window, POINT* point);
BOOL IsIconic(HWND window);
DWORD GetWindowThreadProcessId(HWND window, DWORD* process);
BOOL EnumThreadWindows(DWORD thread, WNDENUMPROC callback, LPARAM parameter);
BOOL SetWindowPos(HWND window, HWND after, int x, int y, int width, int height,
                  UINT flags);

#endif  // TEST_WIN32_STUB_WINDOWS_H_
