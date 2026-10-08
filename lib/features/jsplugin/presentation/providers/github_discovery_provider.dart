import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/base_url_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../data/github_discovery_api.dart';
import '../../domain/github_plugin.dart';
import 'jsplugin_provider.dart';

final githubDiscoveryApiProvider = Provider<GithubDiscoveryApi>((ref) {
  final api = GithubDiscoveryApi();
  ref.onDispose(api.close);
  return api;
});

class GithubDiscoveryState {
  final String search, sort;
  final List<GithubDiscoveryPageData> pages;
  final bool loading;
  final Object? error;
  const GithubDiscoveryState({
    this.search = '',
    this.sort = 'updated',
    this.pages = const [],
    this.loading = false,
    this.error,
  });

  List<GithubPlugin> get plugins =>
      {
        for (final page in pages)
          for (final plugin in page.plugins) plugin.repository.id: plugin,
      }.values.toList();
  int get checked => pages.fold(0, (sum, page) => sum + page.checked);
  int count(DiscoveryFailure reason) =>
      pages.fold(0, (sum, page) => sum + (page.failures[reason] ?? 0));
  int get excluded =>
      count(DiscoveryFailure.invalidManifest) +
      count(DiscoveryFailure.invalidRelease) +
      count(DiscoveryFailure.unpublished);
  int get unverified =>
      count(DiscoveryFailure.unavailable) + count(DiscoveryFailure.rateLimited);
  bool get limited =>
      count(DiscoveryFailure.rateLimited) > 0 ||
      error is GithubDiscoveryException &&
          (error as GithubDiscoveryException).reason ==
              DiscoveryFailure.rateLimited;
  DateTime? get retryAt {
    for (final page in pages) {
      if (page.retryAt != null) return page.retryAt;
    }
    return error is GithubDiscoveryException
        ? (error as GithubDiscoveryException).retryAt
        : null;
  }

  int? get nextPage => pages.isEmpty ? null : pages.last.nextPage;
}

final githubDiscoveryProvider =
    NotifierProvider.autoDispose<GithubDiscoveryNotifier, GithubDiscoveryState>(
      GithubDiscoveryNotifier.new,
    );

class GithubDiscoveryNotifier extends Notifier<GithubDiscoveryState> {
  CancelToken? _cancel;
  Timer? _debounce;
  int _generation = 0;

  @override
  GithubDiscoveryState build() {
    ref.watch(baseUrlProvider);
    final proxy = ref.watch(githubProxyProvider);
    final generation = ++_generation;
    _cancel?.cancel();
    _debounce?.cancel();
    ref.onDispose(() {
      ++_generation;
      _cancel?.cancel();
      _debounce?.cancel();
    });
    if (!proxy.isLoading) {
      Future.microtask(() {
        if (ref.mounted && generation == _generation) _load();
      });
    }
    return const GithubDiscoveryState(loading: true);
  }

  void search(String value) {
    _cancel?.cancel();
    _debounce?.cancel();
    ++_generation;
    state = GithubDiscoveryState(
      search: value,
      sort: state.sort,
      loading: true,
    );
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _debounce = null;
      _load();
    });
  }

  void sort(String value) {
    if (value == state.sort) return;
    _debounce?.cancel();
    _debounce = null;
    state = GithubDiscoveryState(search: state.search, sort: value);
    _load();
  }

  void refresh() {
    _debounce?.cancel();
    _debounce = null;
    _load(force: true);
  }

  void loadMore() {
    if (!state.loading && _debounce == null && state.nextPage != null) {
      _load(append: true);
    }
  }

  Future<void> _load({bool force = false, bool append = false}) async {
    _cancel?.cancel();
    final token = _cancel = CancelToken();
    final generation = ++_generation;
    final previous = state;
    final base = append ? previous.pages : <GithubDiscoveryPageData>[];
    final pageNumber = append ? previous.nextPage! : 1;
    final api = ref.read(githubDiscoveryApiProvider);
    final proxy = ref.read(githubProxyProvider).value ?? '';
    void update(
      List<GithubDiscoveryPageData> pages,
      bool loading, [
      Object? error,
    ]) {
      if (!ref.mounted || token.isCancelled || generation != _generation) {
        return;
      }
      state = GithubDiscoveryState(
        search: previous.search,
        sort: previous.sort,
        pages: List.unmodifiable(pages),
        loading: loading,
        error: error,
      );
    }

    update(base, true);
    try {
      final result = await api.discover(
        page: pageNumber,
        search: previous.search,
        sort: previous.sort,
        proxy: proxy,
        force: force,
        cancelToken: token,
        onProgress: (progress) => update([...base, progress], true),
      );
      update([...base, result], false);
    } catch (error) {
      // Append failures retain the completed pages and retry the same next page.
      update(base, false, error);
    }
  }
}

/// Session-only successful installs, scoped to the server identity.
final githubDiscoveryInstallsProvider =
    NotifierProvider<GithubDiscoveryInstalls, Map<String, GithubPlugin>>(
      GithubDiscoveryInstalls.new,
    );

class GithubDiscoveryInstalls extends Notifier<Map<String, GithubPlugin>> {
  @override
  Map<String, GithubPlugin> build() {
    ref.watch(baseUrlProvider);
    ref.listen(jsPluginsProvider, (_, next) {
      // The marker bridges the install response and the next server refresh.
      // Once authoritative data arrives, do not retain stale installs after
      // an uninstall, replacement, or update elsewhere in the application.
      if (!next.hasValue || next.isLoading || next.hasError || state.isEmpty) {
        return;
      }
      final retained = <String, GithubPlugin>{};
      for (final entry in state.entries) {
        final installed =
            next.requireValue
                .where((item) => item.entryPath == entry.key)
                .firstOrNull;
        if (entry.value.installedFrom(installed) &&
            installed?.version == entry.value.manifest.version) {
          retained[entry.key] = entry.value;
        }
      }
      if (retained.length != state.length) state = retained;
    });
    return {};
  }

  bool installed(GithubPlugin plugin, {required String server}) {
    if (!ref.mounted || ref.read(baseUrlProvider) != server) return false;
    state = {...state, plugin.manifest.entryPath: plugin};
    ref.invalidate(jsPluginsProvider);
    return true;
  }

  void clear(String entryPath) {
    state = {...state}..remove(entryPath);
  }
}
