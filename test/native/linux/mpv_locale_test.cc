// Run with GTK, libmpv, and an X display (e.g. xvfb-run). Tests the runner's
// actual locale helper against a real libmpv after GTK changes LC_ALL.
#include <gtk/gtk.h>
#include <mpv/client.h>

#include <cassert>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <unistd.h>

#include "mpv_locale.h"

static std::string CreateAudioFixture() {
  char path[] = "/tmp/songloft-mpv-audio-XXXXXX";
  const int fd = mkstemp(path);
  assert(fd >= 0);
  std::FILE* file = fdopen(fd, "wb");
  assert(file != nullptr);
  // 100 ms of unsigned 8-bit PCM silence, mono, 8000 Hz.
  const unsigned char header[] = {
      'R', 'I', 'F', 'F', 0x44, 0x03, 0, 0, 'W', 'A', 'V', 'E',
      'f', 'm', 't', ' ', 16, 0, 0, 0, 1, 0, 1, 0,
      0x40, 0x1f, 0, 0, 0x40, 0x1f, 0, 0, 1, 0, 8, 0,
      'd', 'a', 't', 'a', 0x20, 0x03, 0, 0};
  assert(std::fwrite(header, 1, sizeof(header), file) == sizeof(header));
  for (int i = 0; i < 800; ++i) assert(std::fputc(128, file) != EOF);
  assert(std::fclose(file) == 0);
  return path;
}

static void VerifyPlayback(mpv_handle* handle) {
  const auto path = CreateAudioFixture();
  const char* command[] = {"loadfile", path.c_str(), nullptr};
  assert(mpv_command(handle, command) >= 0);
  const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(10);
  bool loaded = false;
  bool finished = false;
  while (std::chrono::steady_clock::now() < deadline && !finished) {
    const auto* event = mpv_wait_event(handle, 0.5);
    assert(event != nullptr);
    if (event->event_id == MPV_EVENT_FILE_LOADED) loaded = true;
    if (event->event_id == MPV_EVENT_END_FILE) {
      const auto* end = static_cast<const mpv_event_end_file*>(event->data);
      assert(end->reason == MPV_END_FILE_REASON_EOF);
      assert(end->error >= 0);
      finished = true;
    }
  }
  assert(loaded && finished);
  assert(std::remove(path.c_str()) == 0);
  std::puts("Audio loaded and decoded to EOF with ao=null");
}

int main(int argc, char** argv) {
  gtk_init(&argc, &argv);
  const std::string numeric_before = std::setlocale(LC_NUMERIC, nullptr);
  const std::string ctype_before = std::setlocale(LC_CTYPE, nullptr);
  const std::string messages_before = std::setlocale(LC_MESSAGES, nullptr);
  const char* requested = std::getenv("LC_ALL");
  if (requested != nullptr &&
      (std::string(requested) == "en_US.UTF-8" ||
       std::string(requested) == "zh_CN.UTF-8")) {
    // Missing locale data must not silently turn this into another C test.
    assert(numeric_before == requested);
  }
  mpv_handle* before = mpv_create();
  std::printf("GTK locale=%s, mpv_create before fix=%p\n",
              numeric_before.c_str(), static_cast<void*>(before));
  if (before != nullptr) mpv_destroy(before);
  if (numeric_before != "C" && numeric_before != "C.UTF-8") {
    assert(before == nullptr);
  }

  assert(EnsureMpvNumericLocale());
  assert(std::string(std::setlocale(LC_NUMERIC, nullptr)) == "C");
  assert(std::string(std::setlocale(LC_CTYPE, nullptr)) == ctype_before);
  assert(std::string(std::setlocale(LC_MESSAGES, nullptr)) == messages_before);
  mpv_handle* handle = mpv_create();
  assert(handle != nullptr);
  assert(mpv_set_option_string(handle, "vid", "no") >= 0);
  assert(mpv_set_option_string(handle, "ao", "null") >= 0);
  assert(mpv_initialize(handle) >= 0);
  std::printf("mpv_create after fix=%p, initialization succeeded; "
              "LC_CTYPE=%s, LC_MESSAGES=%s preserved\n",
              static_cast<void*>(handle), ctype_before.c_str(),
              messages_before.c_str());
  VerifyPlayback(handle);
  mpv_terminate_destroy(handle);
  return 0;
}
