// Failure injection for Dart FFI initialization tests. No audio hardware needed.
#include <stdint.h>
#include <assert.h>

struct fake_handle {
  int event_pending;
  void (*wakeup_callback)(void*);
  void* wakeup_data;
};

struct mpv_event {
  int event_id;
  int error;
  uint64_t reply_userdata;
  void* data;
};

static int mode;
static struct fake_handle handles[128];
static int next_handle;
static struct fake_handle* current_handle;
static int counters[5];
static struct mpv_event no_event;
static struct mpv_event queued_event = {1, 0, 0, 0};

void fake_mpv_reset(int new_mode) {
  mode = new_mode;
  current_handle = 0;
  for (int i = 0; i < 5; ++i) counters[i] = 0;
}

int fake_mpv_count(int index) { return counters[index]; }

void fake_mpv_trigger_event(void) {
  assert(current_handle);
  current_handle->event_pending = 1;
  if (current_handle->wakeup_callback) {
    current_handle->wakeup_callback(current_handle->wakeup_data);
  }
}

void* mpv_create(void) {
  ++counters[0];
  if (mode == 1) return 0;
  assert(next_handle < 128);
  current_handle = &handles[next_handle++];
  return current_handle;
}

int mpv_set_option_string(void* ctx, const char* name, const char* value) {
  (void)name;
  (void)value;
  ++counters[1];
  return ctx ? 0 : -1;
}

int mpv_initialize(void* ctx) {
  ++counters[2];
  return ctx && mode != 2 ? 0 : -3;
}

const char* mpv_error_string(int error) {
  (void)error;
  return "injected initialization failure";
}

void mpv_destroy(void* ctx) {
  (void)ctx;
  ++counters[3];
}

void mpv_terminate_destroy(void* ctx) { mpv_destroy(ctx); }

void mpv_set_wakeup_callback(void* ctx, void (*callback)(void*), void* data) {
  struct fake_handle* handle = ctx;
  handle->wakeup_callback = callback;
  handle->wakeup_data = data;
  ++counters[4];
}

struct mpv_event* mpv_wait_event(void* ctx, double timeout) {
  struct fake_handle* handle = ctx;
  (void)timeout;
  if (handle->event_pending) {
    handle->event_pending = 0;
    return &queued_event;
  }
  return &no_event;
}

void mpv_wakeup(void* ctx) { (void)ctx; }
