class AppConstants {
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  static const String favoritePlaylistId = '1';
  static const String radioFavoritePlaylistId = '2';

  // 播放模式
  static const String playModeOrder = 'order';
  static const String playModeLoop = 'loop';
  static const String playModeSingle = 'single';
  static const String playModeRandom = 'random';

  // 歌曲类型
  static const String songTypeAllMusic = 'local,remote';
  static const String songTypeLocal = 'local';
  static const String songTypeRemote = 'remote';
  static const String songTypeRadio = 'radio';
  static const String musicExcludePlaylistLabels = 'hidden,audiobook';
  static const String musicExcludePlaylistLabelsWithHidden = 'audiobook';

  // 歌单类型
  static const String playlistTypeNormal = 'normal';
  static const String playlistTypeRadio = 'radio';
}
