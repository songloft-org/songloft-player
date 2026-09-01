import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/song.dart';
import '../../data/songs_api.dart';
import 'songs_provider.dart';

class FolderContentState {
  final List<FolderInfo> folders;
  final List<Song> songs;
  final String musicPath;
  final String parentPath;
  final String keyword;

  const FolderContentState({
    this.folders = const [],
    this.songs = const [],
    this.musicPath = '',
    this.parentPath = '',
    this.keyword = '',
  });

  FolderContentState copyWith({
    List<FolderInfo>? folders,
    List<Song>? songs,
    String? musicPath,
    String? parentPath,
    String? keyword,
  }) => FolderContentState(
    folders: folders ?? this.folders,
    songs: songs ?? this.songs,
    musicPath: musicPath ?? this.musicPath,
    parentPath: parentPath ?? this.parentPath,
    keyword: keyword ?? this.keyword,
  );
}

class FolderContentNotifier extends AsyncNotifier<FolderContentState> {
  FolderContentNotifier(this._path);

  final String _path;

  @override
  Future<FolderContentState> build() => _fetch('');

  Future<FolderContentState> _fetch(String keyword) async {
    final api = ref.read(songsApiProvider);
    final result = await api.getFolders(path: _path, keyword: keyword);
    return FolderContentState(
      folders: result.folders,
      songs: result.songs,
      musicPath: result.musicPath,
      parentPath: result.parentPath,
      keyword: keyword,
    );
  }

  Future<void> search(String keyword) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch(keyword));
  }

  Future<void> refresh() async {
    final kw = state.value?.keyword ?? '';
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch(kw));
  }
}

final folderContentProvider = AsyncNotifierProvider.family<
  FolderContentNotifier,
  FolderContentState,
  String
>(FolderContentNotifier.new);
