import 'dart:async';

class FavoriteChange {
  final String cursor;
  final bool changed;
  const FavoriteChange(this.cursor, this.changed);
}

/// One hanging request at a time. Cursor advances only after cache refresh.
class FavoriteChangeWatcher {
  final Future<FavoriteChange> Function(String? cursor) poll;
  final Future<void> Function() refresh;
  final void Function()? cancelPoll;
  final bool Function(Object error)? unsupported;
  final Duration retryDelay;
  bool _stopped = false;
  Timer? _retryTimer;
  Completer<void>? _retry;

  FavoriteChangeWatcher({
    required this.poll,
    required this.refresh,
    this.cancelPoll,
    this.unsupported,
    this.retryDelay = const Duration(seconds: 1),
  });

  Future<void> run() async {
    String? cursor;
    var failures = 0;
    while (!_stopped) {
      try {
        final change = await poll(cursor);
        if (_stopped) return;
        if (change.changed) await refresh();
        if (_stopped) return;
        cursor = change.cursor;
        failures = 0;
      } catch (error) {
        if (_stopped || unsupported?.call(error) == true) return;
        cursor = null; // Reconcile after reconnect or a failed refresh.
        final multiplier = 1 << failures.clamp(0, 5);
        failures++;
        _retry = Completer<void>();
        _retryTimer = Timer(retryDelay * multiplier, () => _retry?.complete());
        await _retry!.future;
        _retry = null;
        _retryTimer = null;
      }
    }
  }

  void stop() {
    _stopped = true;
    cancelPoll?.call();
    _retryTimer?.cancel();
    if (_retry != null && !_retry!.isCompleted) _retry!.complete();
  }
}
