import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/core/network/api_client.dart';
import 'package:songloft_flutter/features/auth/domain/auth_state.dart';
import 'package:songloft_flutter/features/auth/presentation/providers/auth_provider.dart';
import 'package:songloft_flutter/features/library/presentation/providers/favorite_provider.dart';

class _Authenticated extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
}

ResponseBody jsonBody(Object data) => ResponseBody.fromString(
  jsonEncode(data),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class FavoriteAdapter implements HttpClientAdapter {
  var ids = <int>[];
  var radioIds = <int>[];
  var cursor = 0;
  Completer<ResponseBody>? pending;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/favorites/changes')) {
      if (options.queryParameters['cursor'] != '$cursor') {
        return jsonBody({'cursor': '$cursor', 'changed': true});
      }
      pending = Completer<ResponseBody>();
      final current = pending!;
      cancelFuture?.then((_) {
        if (!current.isCompleted) {
          current.complete(jsonBody({'cursor': '$cursor', 'changed': false}));
        }
      });
      return current.future;
    }
    if (path.endsWith('/playlists')) {
      return jsonBody({
        'playlists': [
          for (final id in [1, 2])
            {
              'id': id,
              'name': id == 1 ? '收藏' : '电台收藏',
              'type': id == 1 ? 'normal' : 'radio',
              'labels': ['built_in'],
              'created_at': '2026-01-01T00:00:00Z',
              'updated_at': '2026-01-01T00:00:00Z',
            },
        ],
        'total': 2,
      });
    }
    if (path.endsWith('/song-ids')) {
      return jsonBody({'ids': path.contains('/1/') ? ids : radioIds});
    }
    return jsonBody({'songs': [], 'total': 0});
  }

  void change() {
    cursor++;
    final current = pending;
    pending = null;
    if (current != null && !current.isCompleted) {
      current.complete(jsonBody({'cursor': '$cursor', 'changed': true}));
    }
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'server-side add/remove refresh both heart caches without a local toggle',
    () async {
      final adapter = FavoriteAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://server.test'))
        ..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(dio),
          authStateProvider.overrideWith(_Authenticated.new),
        ],
      );
      addTearDown(container.dispose);
      container.listen(favoriteProvider, (_, _) {});
      Future<void> waitFor(bool Function() condition) async {
        final deadline = DateTime.now().add(const Duration(seconds: 3));
        while (!condition()) {
          if (DateTime.now().isAfter(deadline)) {
            fail('favorite update timed out');
          }
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      }

      await waitFor(() => adapter.pending != null);
      adapter.ids = [7, 8];
      adapter.radioIds = [9];
      adapter.change();
      await waitFor(
        () => container.read(favoriteProvider).favoriteSongIds.contains(7),
      );
      expect(container.read(favoriteProvider).favoriteRadioIds, {9});
      await waitFor(() => adapter.pending != null);
      adapter.ids = [8];
      adapter.radioIds = [];
      adapter.change();
      await waitFor(
        () => !container.read(favoriteProvider).favoriteSongIds.contains(7),
      );
      expect(container.read(favoriteProvider).favoriteSongIds, {8});
      expect(container.read(favoriteProvider).favoriteRadioIds, isEmpty);
    },
  );
}
