#ifndef RUNNER_MPV_LOCALE_H_
#define RUNNER_MPV_LOCALE_H_

#include <clocale>

// Call after GTK startup and before any Flutter/libmpv worker is created.
inline bool EnsureMpvNumericLocale() {
  return std::setlocale(LC_NUMERIC, "C") != nullptr;
}

#endif  // RUNNER_MPV_LOCALE_H_
