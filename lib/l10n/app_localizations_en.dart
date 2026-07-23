// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get language => 'Language';

  @override
  String get languageSimplifiedChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystem => 'Follow system';

  @override
  String get themeTitle => 'Theme';

  @override
  String get themeModeTitle => 'Theme mode';

  @override
  String get themeModeSubtitle => 'Choose the app appearance';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonLoading => 'Loading';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get errorNetworkFailed => 'Network connection failed';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get deleteAlsoLocalFile => 'Also delete local file';

  @override
  String get deleteIrreversible => 'This cannot be undone';

  @override
  String get navHome => 'Home';

  @override
  String get navLibrary => 'Library';

  @override
  String get navPlaylists => 'Playlists';

  @override
  String get navSettings => 'Settings';

  @override
  String get favoriteAdded => 'Added to favorites';

  @override
  String get favoriteRemoved => 'Removed from favorites';

  @override
  String get favoriteAddFailed => 'Failed to add favorite';

  @override
  String get favoriteRemoveFailed => 'Failed to remove favorite';

  @override
  String get favorite => 'Favorite';

  @override
  String get unfavorite => 'Unfavorite';

  @override
  String get commonCreate => 'Create';

  @override
  String commonConfirmWithCount(int count) {
    return 'OK ($count)';
  }

  @override
  String get commonLoadFailed => 'Failed to load';

  @override
  String commonLoadFailedDetail(String error) {
    return 'Failed to load: $error';
  }

  @override
  String get clearSearch => 'Clear search';

  @override
  String get selectAll => 'Select all';

  @override
  String get selectFolder => 'Select folder';

  @override
  String get more => 'More';

  @override
  String get expand => 'Expand';

  @override
  String get collapse => 'Collapse';

  @override
  String get songTypeLocal => 'Local';

  @override
  String get songTypeRemote => 'Remote';

  @override
  String get songTypeRadio => 'Radio';

  @override
  String get filterAll => 'All';

  @override
  String get pickerSelectSongs => 'Select songs';

  @override
  String get pickerSearchHint => 'Search songs, artists or albums';

  @override
  String get pickerNoMatchInFolder => 'No matching songs in this folder';

  @override
  String get pickerNoMatch => 'No matching songs';

  @override
  String get pickerNoSongsInFolder => 'No songs in this folder';

  @override
  String get pickerNoSongs => 'No songs yet';

  @override
  String pickerFetchListFailed(String error) {
    return 'Failed to fetch list: $error';
  }

  @override
  String get pickerSelectingAll => 'Selecting all...';

  @override
  String pickerDeselectAllWithCount(int count) {
    return 'Deselect all ($count selected)';
  }

  @override
  String pickerSelectAllCount(int count) {
    return 'Select all $count';
  }

  @override
  String get loadFailedTapRetry => 'Failed to load, tap to retry';

  @override
  String get loadedAllHint => '— All loaded —';

  @override
  String get addToPlaylist => 'Add to playlist';

  @override
  String get newPlaylist => 'New playlist';

  @override
  String get playlistNameLabel => 'Playlist name';

  @override
  String get noPlaylists => 'No playlists yet';

  @override
  String songsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0';
  }

  @override
  String get addFailed => 'Failed to add';

  @override
  String addFailedDetail(String error) {
    return 'Failed to add: $error';
  }

  @override
  String addedToPlaylist(int added, String name) {
    return 'Added $added song(s) to \"$name\"';
  }

  @override
  String addedToPlaylistWithSkip(int added, String name, int skipped) {
    return 'Added $added to \"$name\", skipped $skipped';
  }

  @override
  String createdPlaylistAdded(String name, int added) {
    return 'Created playlist \"$name\" and added $added song(s)';
  }

  @override
  String createdPlaylistWithSkip(String name, int added, int skipped) {
    return 'Created playlist \"$name\" and added $added, skipped $skipped';
  }

  @override
  String get createPlaylistFailed => 'Failed to create playlist';

  @override
  String createPlaylistFailedDetail(String error) {
    return 'Failed to create playlist: $error';
  }

  @override
  String get selectAllFiles => 'Select all files';

  @override
  String get allSongs => 'All songs';

  @override
  String get musicDirEmpty => 'Music directory is empty';

  @override
  String get dirEmpty => 'Directory is empty';

  @override
  String loadDirFailed(String error) {
    return 'Failed to load directory: $error';
  }

  @override
  String get githubProxyDirect => 'Direct (no proxy)';

  @override
  String coreErrorConnectionTimeout(String target) {
    return 'Unable to connect to $target (connection timed out). Please check: (1) whether the backend service is running, (2) whether the URL and port are correct, (3) if accessing via ZeroTier/VPN, make sure the VPN is connected and \"global routing\" is enabled.';
  }

  @override
  String coreErrorConnectionFailed(String target) {
    return 'Unable to connect to $target. Please check that the URL is correct; if accessing via ZeroTier/VPN, make sure the VPN is enabled.';
  }

  @override
  String get coreErrorBadCertificate => 'Certificate verification failed';

  @override
  String get coreErrorRequestCancelled => 'Request cancelled';

  @override
  String get coreErrorUnknownNetwork => 'Unknown network error';

  @override
  String get coreErrorNoResponse => 'No response from server';

  @override
  String get coreErrorRequestFailed => 'Request failed';

  @override
  String get coreErrorUnauthorized =>
      'Your session has expired, please log in again';

  @override
  String get coreErrorForbidden => 'Access denied';

  @override
  String get coreErrorNotFound => 'The requested resource does not exist';

  @override
  String get coreErrorServer => 'Server error, please try again later';

  @override
  String get coreNotFoundPageTitle => 'Page not found';

  @override
  String get coreBackToHome => 'Back to home';

  @override
  String get coreNotificationChannel => 'Songloft Playback Control';

  @override
  String get coreVersionDev => 'Development build';

  @override
  String get jspluginManagerTitle => 'JS Plugin Management';

  @override
  String get jspluginManagerSubtitle => 'Manage installed JS plugins';

  @override
  String get jspluginUploadPlugin => 'Upload Plugin';

  @override
  String get jspluginUpdateAll => 'Update All';

  @override
  String get jspluginCleanupData => 'Clean Up Data';

  @override
  String get jspluginGithubProxy => 'GitHub Proxy';

  @override
  String get jspluginCustomProxy => 'Custom Proxy';

  @override
  String get jspluginCustomProxyEllipsis => 'Custom proxy...';

  @override
  String jspluginCustomProxyWith(String proxy) {
    return 'Custom: $proxy';
  }

  @override
  String get jspluginProxyHelper =>
      'Enter a proxy URL, e.g. https://ghproxy.com/';

  @override
  String get jspluginOk => 'OK';

  @override
  String get jspluginCleanupOrphanTitle => 'Clean Up Orphan Data';

  @override
  String get jspluginCleanupOrphanContent =>
      'This will remove persistent storage data left by uninstalled plugins. This action cannot be undone.';

  @override
  String get jspluginCleanup => 'Clean Up';

  @override
  String jspluginCleanupFailed(String error) {
    return 'Cleanup failed: $error';
  }

  @override
  String get jspluginNoInstalled => 'No JS plugins installed';

  @override
  String jspluginPickFileFailed(String error) {
    return 'Failed to pick file: $error';
  }

  @override
  String get jspluginCannotReadFile => 'Unable to read file data';

  @override
  String get jspluginCannotGetPath => 'Unable to get file path';

  @override
  String jspluginUploadSuccess(int count) {
    return 'Uploaded $count plugin(s) successfully';
  }

  @override
  String jspluginUploadPartial(int success, int failed, String error) {
    return '$success succeeded, $failed failed\n$error';
  }

  @override
  String jspluginUploadFailed(String error) {
    return 'Upload failed: $error';
  }

  @override
  String get jspluginUploadDialogTitle => 'Upload JS Plugin';

  @override
  String get jspluginSelectFileSemantics => 'Select a plugin file to upload';

  @override
  String get jspluginTapToSelectFile => 'Tap to select a file';

  @override
  String get jspluginUploadHint =>
      'Supports .jsplugin.zip format; uploading a plugin with the same name overwrites the existing version (manual update)';

  @override
  String get jspluginRemove => 'Remove';

  @override
  String get jspluginUploading => 'Uploading...';

  @override
  String get jspluginUpload => 'Upload';

  @override
  String jspluginOperationFailed(String error) {
    return 'Operation failed: $error';
  }

  @override
  String jspluginCannotOpenLink(String url) {
    return 'Cannot open link: $url';
  }

  @override
  String get jspluginForceUpdateSuccess => 'Plugin force-updated';

  @override
  String jspluginForceUpdateFailed(String error) {
    return 'Force update failed: $error';
  }

  @override
  String get jspluginConfirmDelete => 'Confirm Deletion';

  @override
  String jspluginDeleteConfirmContent(String name) {
    return 'Are you sure you want to delete plugin \"$name\"?';
  }

  @override
  String get jspluginKeepData => 'Keep plugin data';

  @override
  String get jspluginKeepDataSubtitle =>
      'Keep file storage data for easy reinstallation later';

  @override
  String get jspluginDeleted => 'Plugin deleted';

  @override
  String jspluginDeleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String jspluginAuthor(String author) {
    return 'Author: $author';
  }

  @override
  String get jspluginOpenHomepageSemantics => 'Open plugin homepage';

  @override
  String get jspluginStatusError => 'Error';

  @override
  String get jspluginStatusEnabled => 'Enabled';

  @override
  String get jspluginStatusDisabled => 'Disabled';

  @override
  String get jspluginMoreActions => 'More actions';

  @override
  String get jspluginOpenHomepage => 'Open Homepage';

  @override
  String get jspluginKeepAlive => 'Keep Running';

  @override
  String get jspluginCancelKeepAlive => 'Stop Keeping Running';

  @override
  String get jspluginCheckUpdate => 'Check for Updates';

  @override
  String get jspluginForceUpdate => 'Force Update';

  @override
  String get jspluginUpdate => 'Update';

  @override
  String get jspluginCheckUpdateTimeout =>
      'Update check timed out. Try switching proxy and retry.';

  @override
  String jspluginCheckUpdateFailed(String error) {
    return 'Update check failed: $error';
  }

  @override
  String get jspluginUpdateSuccess => 'Plugin updated successfully';

  @override
  String jspluginUpdateFailed(String error) {
    return 'Update failed: $error';
  }

  @override
  String get jspluginUpdateTimeout => 'Update timed out. Please retry.';

  @override
  String jspluginUpdateDialogTitle(String name) {
    return 'Update Plugin - $name';
  }

  @override
  String get jspluginCheckingUpdate => 'Checking for updates...';

  @override
  String get jspluginDownloadingUpdate => 'Downloading and updating plugin...';

  @override
  String get jspluginDoNotCloseDialog => 'Do not close this dialog';

  @override
  String get jspluginAlreadyLatest => 'Already up to date';

  @override
  String jspluginCurrentVersion(String version) {
    return 'Current version: $version';
  }

  @override
  String get jspluginNewVersionFound => 'New version available';

  @override
  String get jspluginRecheck => 'Recheck';

  @override
  String get jspluginUpdateNow => 'Update Now';

  @override
  String get jspluginClose => 'Close';

  @override
  String jspluginBatchUpdateFailed(String error) {
    return 'Batch update failed: $error';
  }

  @override
  String get jspluginBatchUpdateTimeout =>
      'Batch update timed out. Please retry.';

  @override
  String get jspluginBatchUpdating => 'Checking and updating all plugins...';

  @override
  String get jspluginStatUpdated => 'Updated';

  @override
  String get jspluginStatFailed => 'Failed';

  @override
  String get jspluginStatSkipped => 'Up to date';

  @override
  String get jspluginUpdateFailedShort => 'Update failed';

  @override
  String jspluginVersionLatest(String version) {
    return 'v$version is up to date';
  }

  @override
  String get jspluginStartUpdate => 'Start Update';

  @override
  String jspluginForceUpdateDialogTitle(String name) {
    return 'Force Update - $name';
  }

  @override
  String get jspluginForceUpdateContent =>
      'This ignores the version check and re-downloads and reinstalls the plugin.';

  @override
  String get jspluginConfirmUpdate => 'Confirm Update';

  @override
  String get jspluginStoreTitle => 'Plugin Store';

  @override
  String get jspluginRefreshList => 'Refresh plugin list';

  @override
  String get jspluginManageRegistries => 'Manage Sources';

  @override
  String get jspluginNoRegistries => 'No sources added yet';

  @override
  String get jspluginNoRegistriesHint =>
      'Add a source to browse and install plugins';

  @override
  String get jspluginAddRegistry => 'Add Source';

  @override
  String get jspluginRegistry => 'Source';

  @override
  String get jspluginOfficial => 'Official';

  @override
  String get jspluginAllSources => 'All';

  @override
  String get jspluginAutoUpdate => 'Auto-update plugins';

  @override
  String get jspluginAutoUpdateHint =>
      'Periodically check and update installed plugins in the background';

  @override
  String get jspluginSearchHint => 'Search plugins...';

  @override
  String get jspluginLoadingList => 'Loading plugin list…';

  @override
  String get jspluginNoMatch => 'No matching plugins found';

  @override
  String get jspluginRegistryEmpty => 'This source has no plugins';

  @override
  String get jspluginPrevPage => 'Previous page';

  @override
  String get jspluginNextPage => 'Next page';

  @override
  String jspluginInstallFailed(String error) {
    return 'Installation failed: $error';
  }

  @override
  String get jspluginReinstall => 'Reinstall';

  @override
  String jspluginUpdateTo(String version) {
    return 'Update to v$version';
  }

  @override
  String get jspluginInstall => 'Install';

  @override
  String jspluginSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get jspluginEditRegistry => 'Edit Source';

  @override
  String get jspluginDeleteRegistry => 'Delete Source';

  @override
  String get jspluginNameOptional => 'Name (optional)';

  @override
  String get jspluginRegistryNameHint => 'My plugin source';

  @override
  String get jspluginTokenOptional => 'Token (optional)';

  @override
  String get jspluginSave => 'Save';

  @override
  String get jspluginAdd => 'Add';

  @override
  String get jspluginAuthConfigured => 'Authentication configured';

  @override
  String get jspluginGridTitle => 'JS Plugins';

  @override
  String get jspluginCleanupDone => 'Cleanup complete';

  @override
  String get libraryPlayFailed => 'Playback failed';

  @override
  String get libraryNoPlayableSongs => 'No songs to play';

  @override
  String libraryPlayingAllSongs(int total) {
    return 'Playing all $total songs';
  }

  @override
  String get libraryDismissError => 'Dismiss';

  @override
  String get libraryExitSelection => 'Exit selection';

  @override
  String librarySelectedCount(int count) {
    return '$count selected';
  }

  @override
  String libraryDeleteWithCount(int count) {
    return 'Delete ($count)';
  }

  @override
  String get libraryDeselectAll => 'Deselect all';

  @override
  String get libraryTitle => 'Library';

  @override
  String get libraryPlayAll => 'Play all';

  @override
  String get librarySort => 'Sort';

  @override
  String get librarySortAddedAt => 'Recently added';

  @override
  String get librarySortFileTime => 'File time';

  @override
  String get libraryColumnTitle => 'Title';

  @override
  String get libraryColumnArtist => 'Artist';

  @override
  String get libraryColumnAlbum => 'Album';

  @override
  String get libraryColumnType => 'Type';

  @override
  String get libraryColumnDuration => 'Duration';

  @override
  String get librarySelectMode => 'Multi-select';

  @override
  String get libraryMore => 'More';

  @override
  String get libraryAddRemoteSong => 'Add remote song';

  @override
  String get libraryAddRadio => 'Add radio';

  @override
  String get libraryHideHiddenSongs => 'Hide hidden songs';

  @override
  String get libraryShowHiddenSongs => 'Show hidden songs';

  @override
  String get libraryCleanInvalidSongs => 'Clean invalid songs';

  @override
  String get librarySearchHint => 'Search songs...';

  @override
  String get libraryNoMatchingSongs => 'No matching songs found';

  @override
  String get libraryEmpty => 'Library is empty';

  @override
  String get libraryTryOtherKeywords => 'Try other keywords';

  @override
  String get libraryEmptyHint => 'Add some songs to get started';

  @override
  String get libraryDeleteConfirmTitle => 'Confirm deletion';

  @override
  String get libraryDeleteConfirmContent =>
      'Are you sure you want to delete this song?';

  @override
  String get libraryCleanTitle => 'Clean songs';

  @override
  String get libraryCleanContent =>
      'This will clean up invalid song records (such as local songs whose files have been deleted).';

  @override
  String libraryCleanedCount(int count) {
    return 'Cleaned $count invalid songs';
  }

  @override
  String get libraryClean => 'Clean';

  @override
  String get libraryBatchDeleteTitle => 'Batch delete';

  @override
  String libraryBatchDeleteContent(int count) {
    return 'Are you sure you want to delete the selected $count songs?';
  }

  @override
  String libraryDeletedCount(int count) {
    return 'Deleted $count songs';
  }

  @override
  String get libraryDeleteFailed => 'Delete failed';

  @override
  String librarySongCount(int count) {
    return '$count songs';
  }

  @override
  String get libraryUnknownArtist => 'Unknown artist';

  @override
  String get libraryUnknownAlbum => 'Unknown album';

  @override
  String get libraryPlay => 'Play';

  @override
  String get libraryEdit => 'Edit';

  @override
  String get libraryCustomizeViews => 'Customize views';

  @override
  String get libraryCustomizeViewsTooltip =>
      'Customize which views show and their order';

  @override
  String get libraryViewsMinOne => 'Keep at least one view visible';

  @override
  String get libraryViewPlaylistAll => 'All Playlists';

  @override
  String get categorySongsEmpty => 'No songs in this category';

  @override
  String get libraryViewGroupSongs => 'Songs';

  @override
  String get libraryViewGroupCategories => 'Categories';

  @override
  String get libraryViewGroupPlaylists => 'Playlists';

  @override
  String get libraryViewGroupMoveUp => 'Move group up';

  @override
  String get libraryViewGroupMoveDown => 'Move group down';

  @override
  String get libraryEditLocalSong => 'Edit local song';

  @override
  String get libraryEditRadio => 'Edit radio';

  @override
  String get libraryEditRemoteSong => 'Edit remote song';

  @override
  String get librarySave => 'Save';

  @override
  String get libraryFileInfoReadonly => 'File info (read-only)';

  @override
  String get libraryServerEndpointReadonly => 'Server endpoint (read-only)';

  @override
  String get libraryReadonlyFile => 'File';

  @override
  String get libraryReadonlyCover => 'Cover';

  @override
  String get libraryReadonlyLyric => 'Lyrics';

  @override
  String get libraryEditTitleLabel => 'Title *';

  @override
  String get libraryEditTitleRequired => 'Please enter a title';

  @override
  String get libraryEditArtistHint => 'Please enter an artist';

  @override
  String get libraryEditAlbumHint => 'Please enter an album';

  @override
  String get libraryRenameFileTitle => 'Rename file in sync';

  @override
  String get libraryRenameFileSubtitle =>
      'Rename the local audio file to the new title and write the title tag';

  @override
  String get libraryVideoToggleTitle => 'Video content';

  @override
  String get libraryVideoToggleSubtitle =>
      'This link contains video; when on, the player renders the picture and casting streams it as video';

  @override
  String get libraryEditSourceUrlLabel => 'Source audio URL *';

  @override
  String get libraryEditUrlLabel => 'URL *';

  @override
  String get libraryEditUrlHint => 'Please enter an audio link';

  @override
  String get libraryEditUrlRequired => 'Please enter a URL';

  @override
  String get libraryEditUrlInvalid => 'Please enter a valid URL';

  @override
  String get libraryEditSourceCoverUrlLabel => 'Source cover URL';

  @override
  String get libraryEditCoverUrlLabel => 'Cover URL';

  @override
  String get libraryEditCoverUrlHint => 'Please enter a cover image link';

  @override
  String get libraryEditDurationLabel => 'Duration (seconds)';

  @override
  String get libraryEditDurationHint => 'Please enter duration';

  @override
  String get libraryEditLyricRemoteUrlLabel => 'Lyrics remote URL';

  @override
  String get libraryEditLyricUrlLabel => 'Lyrics URL';

  @override
  String get libraryEditLyricUrlHint => 'Please enter a lyrics API link';

  @override
  String get libraryCoverPreview => 'Cover preview:';

  @override
  String get libraryCopied => 'Copied';

  @override
  String get libraryCopy => 'Copy';

  @override
  String get librarySaveSuccess => 'Saved successfully';

  @override
  String get libraryAddSuccess => 'Added successfully';

  @override
  String libraryOperationFailed(String error) {
    return 'Operation failed: $error';
  }

  @override
  String get libraryErrorBadRequest => 'Invalid request parameters';

  @override
  String get libraryErrorUnauthorized => 'Unauthorized, please log in again';

  @override
  String get libraryErrorForbidden =>
      'You do not have permission to perform this action';

  @override
  String get libraryErrorNotFound => 'Song not found';

  @override
  String get libraryErrorServer => 'Server error, please try again later';

  @override
  String libraryErrorRequestFailed(int code) {
    return 'Request failed: $code';
  }

  @override
  String get libraryErrorTimeout =>
      'Network connection timed out, please check your network';

  @override
  String get libraryErrorConnection =>
      'Network connection failed, please check your network';

  @override
  String libraryErrorNetwork(String message) {
    return 'Network error: $message';
  }

  @override
  String get libraryFavoritePlaylistNotFound =>
      'Favorites playlist does not exist';

  @override
  String get libraryRadioFavoritePlaylistNotFound =>
      'Radio favorites playlist does not exist';

  @override
  String get homeEmptyPlaylists => 'No playlists yet';

  @override
  String get homeEmptyPlaylistsSubtitle =>
      'Create your first playlist to start collecting music';

  @override
  String get homeCreatePlaylist => 'Create playlist';

  @override
  String get homeMyPlaylists => 'My Playlists';

  @override
  String get homeViewAll => 'View all';

  @override
  String get homeMyRadios => 'My Radios';

  @override
  String get homeGreetingLateNight => 'It\'s late';

  @override
  String get homeGreetingMorning => 'Good morning';

  @override
  String get homeGreetingNoon => 'Good afternoon';

  @override
  String get homeGreetingAfternoon => 'Good afternoon';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String get homeTvGreetingLateNight => 'It\'s late, how about some music';

  @override
  String get homeOpenPlaylist => 'Open playlist';

  @override
  String homeOpenPlaylistNamed(String name) {
    return 'Open playlist $name';
  }

  @override
  String homeSongCountShort(int count) {
    return '$count songs';
  }

  @override
  String homeSongCount(int count) {
    return '$count songs';
  }

  @override
  String homeStatPlaylistsCount(int count) {
    return '$count playlists';
  }

  @override
  String homeStatRadiosCount(int count) {
    return '$count radios';
  }

  @override
  String get homeStatTotal => 'Total';

  @override
  String get homeTvLocalMusic => 'Local Music';

  @override
  String get homeTvPlaylist => 'Playlists';

  @override
  String get homeTvEmptySubtitle =>
      'Use quick navigation to browse local music';

  @override
  String homeHeroSemanticLabel(String name, int count) {
    return '$name - $count songs';
  }

  @override
  String get homeNowPlaying => 'Now Playing';

  @override
  String get homeRecommendedPlaylist => 'Recommended';

  @override
  String get homePlayNow => 'Play Now';

  @override
  String get homePluginLoadTimeout =>
      'Page load timed out. Check whether the plugin is available or your network connection.';

  @override
  String get homePluginClose => 'Close';

  @override
  String get homePluginOpenInBrowser => 'Open in browser';

  @override
  String get homePluginLoadFailed => 'Failed to load page';

  @override
  String homePluginLoadFailedHttp(String status, String detail) {
    return 'Failed to load page: HTTP $status$detail';
  }

  @override
  String get homePluginUnknownError => 'Unknown error';

  @override
  String get homePluginWebOpenInNewTab =>
      'On the web, please open the plugin in a new tab';

  @override
  String get authLogin => 'Log in';

  @override
  String get authTvSubtitle => 'Log in to Songloft with your account';

  @override
  String get authLoginToContinue => 'Log in to continue';

  @override
  String get authTagline => 'Self-hosted local music service';

  @override
  String get authUsername => 'Username';

  @override
  String get authUsernameHint => 'Enter username';

  @override
  String get authUsernameRequired => 'Please enter your username';

  @override
  String get authPassword => 'Password';

  @override
  String get authPasswordHint => 'Enter password';

  @override
  String get authPasswordRequired => 'Please enter your password';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authApiUrl => 'API address';

  @override
  String get authApiUrlRequired => 'Please enter the API address';

  @override
  String get authInvalidUrl =>
      'Please enter a valid URL (starting with http:// or https://)';

  @override
  String get authServer => 'Server';

  @override
  String get authTvPressToLogin => 'Press OK to log in';

  @override
  String get authUseLocalMode => 'Use local mode';

  @override
  String authCopyright(int year) {
    return '© $year Songloft';
  }

  @override
  String get authAutoLoggingIn => 'Logging in automatically…';

  @override
  String get authStartingLocalBackend => 'Starting local backend…';

  @override
  String get authPreparing => 'Preparing…';

  @override
  String get authConnecting => 'Connecting…';

  @override
  String get authLoggingIn => 'Logging in…';

  @override
  String authAutoLoginFailed(String error) {
    return 'Auto login failed: $error';
  }

  @override
  String authLocalModeFailed(String error) {
    return 'Failed to start local mode: $error';
  }

  @override
  String authLoginFailed(String error) {
    return 'Login failed: $error';
  }

  @override
  String get authSessionExpired =>
      'Your session has expired. Please log in again.';

  @override
  String get authNoRefreshToken => 'No refresh token available';

  @override
  String get dlnaCast => 'Cast';

  @override
  String get dlnaCasting => 'Casting';

  @override
  String get dlnaDisconnect => 'Disconnect';

  @override
  String get dlnaConnected => 'Connected';

  @override
  String get dlnaSearching => 'Searching for devices...';

  @override
  String get dlnaSearchingLan => 'Searching for LAN devices...';

  @override
  String get dlnaNoDevices => 'No DLNA devices found';

  @override
  String get startupStarting => 'Starting…';

  @override
  String get startupStartingLocalBackend => 'Starting local backend…';

  @override
  String get startupConnectingLocalBackend => 'Connecting to local backend…';

  @override
  String startupConnectingTo(String target) {
    return 'Connecting to $target…';
  }

  @override
  String get playerModeOrder => 'Sequential';

  @override
  String get playerModeLoop => 'Repeat all';

  @override
  String get playerModeSingle => 'Repeat one';

  @override
  String get playerModeRandom => 'Shuffle';

  @override
  String get playerModeSinglePlay => 'Play once';

  @override
  String get playerClose => 'Close';

  @override
  String get playerSleepTimer => 'Sleep timer';

  @override
  String playerSleepTimerWithStatus(String status) {
    return 'Sleep timer: $status';
  }

  @override
  String get playerSleepTimerCancel => 'Cancel timer';

  @override
  String get playerSleepTimerByDuration => 'By duration';

  @override
  String playerHours(int count) {
    return '$count h';
  }

  @override
  String playerMinutes(int count) {
    return '$count min';
  }

  @override
  String get playerCustom => 'Custom';

  @override
  String get playerCustomDuration => 'Custom duration';

  @override
  String get playerUnitMinutes => 'min';

  @override
  String get playerSleepTimerBySongs => 'By songs';

  @override
  String playerSongsUnit(int count) {
    return '$count songs';
  }

  @override
  String get playerCustomSongCount => 'Custom song count';

  @override
  String get playerUnitSongs => 'songs';

  @override
  String playerRemainingSongs(int count) {
    return '$count songs left';
  }

  @override
  String get playerEnterNumber => 'Please enter a number';

  @override
  String get playerEnterValidInteger => 'Please enter a valid integer';

  @override
  String playerEnterIntegerInRange(int min, int max) {
    return 'Enter an integer between $min and $max';
  }

  @override
  String get playerBack => 'Back';

  @override
  String get playerNowPlaying => 'Now playing';

  @override
  String get playerNoContent => 'Nothing playing';

  @override
  String get playerUnknownArtist => 'Unknown artist';

  @override
  String get playerPlayMode => 'Play mode';

  @override
  String get playerVolumeDown => 'Volume down';

  @override
  String get playerVolumeUp => 'Volume up';

  @override
  String get playerPrevious => 'Previous';

  @override
  String get playerNext => 'Next';

  @override
  String get playerPlaylist => 'Playlist';

  @override
  String get playerBuffering => 'Buffering';

  @override
  String get playerCaching => 'Caching, please wait…';

  @override
  String get playerPause => 'Pause';

  @override
  String get playerPlay => 'Play';

  @override
  String get playerSeekHint => '← → Seek';

  @override
  String get playerProgress => 'Playback progress';

  @override
  String get playerQueueTitle => 'Play queue';

  @override
  String get playerClearPlaylist => 'Clear playlist';

  @override
  String get playerQueueEmpty => 'Queue is empty';

  @override
  String get playerDrawerEmptyHint => 'Add songs to start playing';

  @override
  String get playerQueueEmptyHint => 'Add songs to the queue to start playing';

  @override
  String playerRemovedSong(String title) {
    return 'Removed \"$title\"';
  }

  @override
  String get playerClearQueueTitle => 'Clear play queue';

  @override
  String get playerClearQueueConfirm => 'Clear the play queue?';

  @override
  String get playerClear => 'Clear';

  @override
  String get playerRemoveFromPlaylist => 'Remove from playlist';

  @override
  String get playerRemoveFromQueue => 'Remove from queue';

  @override
  String get playerMute => 'Mute';

  @override
  String get playerUnmute => 'Unmute';

  @override
  String playerVolumePercent(int value) {
    return 'Volume $value%';
  }

  @override
  String get playerVolume => 'Volume';

  @override
  String get playerCloseVolumePanel => 'Close volume panel';

  @override
  String get playerOpenFullPlayer => 'Open full-screen player';

  @override
  String get playerEqualizer => 'Equalizer';

  @override
  String get playerAudioTrack => 'Audio track';

  @override
  String get playerSelectAudioTrack => 'Select audio track';

  @override
  String playerAudioTrackNumbered(int index) {
    return 'Track $index';
  }

  @override
  String get playerLyrics => 'Lyrics';

  @override
  String get playerCollapse => 'Collapse';

  @override
  String get playerSubtitleOn => 'Show subtitles';

  @override
  String get playerSubtitleOff => 'Hide subtitles';

  @override
  String get playerEnterFullscreen => 'Fullscreen';

  @override
  String get playerExitFullscreen => 'Exit fullscreen';

  @override
  String get playerSleepTimerOn => 'Sleep timer (on)';

  @override
  String get playerDeleteCurrentSong => 'Delete current song';

  @override
  String get playerExpandPlayer => 'Expand player';

  @override
  String get playerBufferingSemantic => 'Buffering';

  @override
  String get playerLyricsLoading => 'Loading lyrics...';

  @override
  String get playerLyricsLoadFailed => 'Failed to load lyrics';

  @override
  String get playerLyricsEmpty => 'No lyrics';

  @override
  String get playerLyricsSeekTo => 'Seek to this lyric';

  @override
  String get playerAdjustLyrics => 'Adjust lyrics';

  @override
  String get playerLyricsRefetch => 'Re-fetch lyrics';

  @override
  String get playerEqNotSupported =>
      'Equalizer is not supported on this platform';

  @override
  String get playerEqPresetFlat => 'Flat';

  @override
  String get playerEqPresetRock => 'Rock';

  @override
  String get playerEqPresetPop => 'Pop';

  @override
  String get playerEqPresetJazz => 'Jazz';

  @override
  String get playerEqPresetClassical => 'Classical';

  @override
  String get playerEqPresetBassBoost => 'Bass boost';

  @override
  String get playerEqPresetTrebleBoost => 'Treble boost';

  @override
  String get playerEqPresetVocal => 'Vocal';

  @override
  String get playerEqPresetCustom => 'Custom';

  @override
  String get playerLyricSavedWritten => 'Saved and written to audio file';

  @override
  String get playerLyricSavedWriteFailed =>
      'Saved to database, but writing to the audio file failed';

  @override
  String get playerLyricSavedDbOnly => 'Saved to database (file not updated)';

  @override
  String playerSaveFailedDetail(String error) {
    return 'Save failed: $error';
  }

  @override
  String get playerDiscardChangesTitle => 'Discard changes?';

  @override
  String get playerDiscardChangesContent =>
      'Your changes haven\'t been saved. Leave anyway?';

  @override
  String get playerContinueEditing => 'Keep editing';

  @override
  String get playerDiscard => 'Discard';

  @override
  String get playerGlobalOffset => 'Global offset';

  @override
  String playerLyricOffsetSemantics(int value) {
    return 'Lyric offset $value ms';
  }

  @override
  String get playerOffsetHint =>
      'Tip: if lyrics appear too early overall, use a negative offset (-); if too late, use a positive offset (+)';

  @override
  String get playerEmptyLine => '(empty line)';

  @override
  String playerLineOffset(String offset) {
    return 'Line offset $offset';
  }

  @override
  String get playerReset => 'Reset';

  @override
  String get playerSave => 'Save';

  @override
  String get playerNoLyricsToAdjust => 'No lyrics to adjust';

  @override
  String get playerDeleteSongTitle => 'Delete song';

  @override
  String playerDeleteSongConfirm(String title) {
    return 'Delete \"$title\" from your library?';
  }

  @override
  String get playerSongDeleted => 'Song deleted';

  @override
  String get playerDeleteFailed => 'Delete failed';

  @override
  String get playerUnknownSong => 'Unknown song';

  @override
  String playerPlayFailedNamed(String title) {
    return 'Failed to play \"$title\"';
  }

  @override
  String playerConsecutiveFailures(int count) {
    return '$count songs in a row failed to play. Playback stopped—please check your network connection.';
  }

  @override
  String playerPlayFailedTryingNext(String title) {
    return 'Failed to play \"$title\", trying the next song...';
  }

  @override
  String get playerPlayFailedNoOthers =>
      'Playback failed—no other songs to play';

  @override
  String get playerPlayFailedEndOfList =>
      'Playback failed—reached the end of the playlist';

  @override
  String get playlistBack => 'Back';

  @override
  String get playlistSearch => 'Search';

  @override
  String get playlistSearchHint => 'Search songs...';

  @override
  String get playlistListSearchHint => 'Search playlists...';

  @override
  String get playlistNoMatching => 'No matching playlists found';

  @override
  String get playlistTryOtherKeywords => 'Try other keywords';

  @override
  String get playlistFilterNormal => 'Playlists';

  @override
  String get playlistFilterRadio => 'Radios';

  @override
  String get playlistMultiSelect => 'Multi-select';

  @override
  String get playlistMore => 'More';

  @override
  String get playlistDone => 'Done';

  @override
  String get playlistSort => 'Sort';

  @override
  String get playlistSortModeTitle => 'Reorder playlists';

  @override
  String get playlistSortSaved => 'Sort order saved';

  @override
  String get playlistSortSaveFailed => 'Failed to save sort order';

  @override
  String get playlistSortFailed => 'Sort failed';

  @override
  String get playlistAlreadySortedSongs => 'Songs are already in this order';

  @override
  String get playlistAlreadySortedPlaylists =>
      'Playlists are already in this order';

  @override
  String get playlistSortedByNameAsc => 'Sorted by name (A→Z)';

  @override
  String get playlistSortedByNameDesc => 'Sorted by name (Z→A)';

  @override
  String get playlistSortedByNumber => 'Sorted by number prefix';

  @override
  String get playlistSortCustom => 'Custom order';

  @override
  String get playlistSortRecentlyAdded => 'Recently added';

  @override
  String get playlistSortFileTime => 'File time';

  @override
  String get playlistSortTitle => 'Title';

  @override
  String get playlistSortArtist => 'Artist';

  @override
  String get playlistSortDuration => 'Duration';

  @override
  String get playlistSortNameAsc => 'Sort by name A→Z';

  @override
  String get playlistSortNameDesc => 'Sort by name Z→A';

  @override
  String get playlistSortNumberPrefix => 'Sort by number prefix';

  @override
  String get playlistSortManual => 'Sort manually';

  @override
  String get playlistPlayAll => 'Play all';

  @override
  String get playlistAddSongs => 'Add songs';

  @override
  String get playlistAddSongsFailed => 'Failed to add songs';

  @override
  String playlistAddedWithSkipped(int added, int skipped) {
    return 'Added $added, skipped $skipped (already exists or incompatible type)';
  }

  @override
  String playlistAddedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count songs',
      one: 'Added 1 song',
    );
    return '$_temp0';
  }

  @override
  String get playlistLoadMoreRetry => 'Failed to load more, tap to retry';

  @override
  String playlistAllLoaded(int count) {
    return '— All loaded ($count) —';
  }

  @override
  String get playlistDeselectAll => 'Deselect all';

  @override
  String get playlistRemove => 'Remove';

  @override
  String get playlistRemoveFromPlaylist => 'Remove from playlist';

  @override
  String get playlistDeleteFromLibrary => 'Delete from library';

  @override
  String playlistActionsCount(int count) {
    return 'Actions ($count)';
  }

  @override
  String get playlistBatchRemoveTitle => 'Remove in bulk';

  @override
  String playlistBatchRemoveConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remove $count songs from this playlist?',
      one: 'Remove 1 song from this playlist?',
    );
    return '$_temp0';
  }

  @override
  String playlistRemovedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Removed $count songs',
      one: 'Removed 1 song',
    );
    return '$_temp0';
  }

  @override
  String get playlistRemoveFailed => 'Failed to remove';

  @override
  String get playlistEditCover => 'Change cover';

  @override
  String get playlistEditPlaylist => 'Edit playlist';

  @override
  String get playlistEditAction => 'Edit';

  @override
  String get playlistDelete => 'Delete playlist';

  @override
  String get playlistEmptySongs => 'No songs in this playlist';

  @override
  String get playlistEmptySongsSubtitle => 'Add some music you love';

  @override
  String get playlistLabelBuiltIn => 'Built-in';

  @override
  String get playlistLabelAutoCreated => 'Auto-created';

  @override
  String get playlistLabelAuto => 'Auto';

  @override
  String get playlistLabelHidden => 'Hidden';

  @override
  String get playlistConfirmDelete => 'Confirm deletion';

  @override
  String playlistDeleteConfirm(String name) {
    return 'Delete playlist \"$name\"? This cannot be undone.';
  }

  @override
  String get playlistDeleted => 'Playlist deleted';

  @override
  String get playlistEmpty => 'Playlist is empty';

  @override
  String get playlistPlayFailed => 'Playback failed';

  @override
  String playlistPlayingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Playing all $count songs',
      one: 'Playing 1 song',
    );
    return '$_temp0';
  }

  @override
  String playlistPlayingSong(String title) {
    return 'Playing: $title';
  }

  @override
  String get playlistRemoveSongTitle => 'Remove song';

  @override
  String playlistRemoveSongConfirm(String title) {
    return 'Remove \"$title\" from this playlist?';
  }

  @override
  String get playlistSongRemoved => 'Song removed';

  @override
  String get playlistDeleteSong => 'Delete song';

  @override
  String playlistDeleteSongConfirm(String title) {
    return 'Delete \"$title\" from the library?';
  }

  @override
  String get playlistSongDeleted => 'Song deleted';

  @override
  String get playlistDeleteFailed => 'Failed to delete';

  @override
  String get playlistBatchDelete => 'Delete in bulk';

  @override
  String playlistBatchDeleteSongsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete the selected $count songs from the library?',
      one: 'Delete the selected song from the library?',
    );
    return '$_temp0';
  }

  @override
  String playlistDeletedSongsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Deleted $count songs',
      one: 'Deleted 1 song',
    );
    return '$_temp0';
  }

  @override
  String get playlistUnknownArtist => 'Unknown artist';

  @override
  String playlistPickImageFailed(String error) {
    return 'Failed to pick image: $error';
  }

  @override
  String get playlistNameRequired => 'Please enter a playlist name';

  @override
  String get playlistNameHint => 'Please enter a playlist name';

  @override
  String get playlistDescLabel => 'Playlist description';

  @override
  String get playlistDescHint => 'Enter a description (optional)';

  @override
  String get playlistCoverUploadFailed => 'Failed to upload cover';

  @override
  String playlistSaveFailed(String error) {
    return 'Failed to save: $error';
  }

  @override
  String get playlistUploadImage => 'Upload image';

  @override
  String get playlistPickFromSongs => 'Pick from songs';

  @override
  String get playlistClear => 'Clear';

  @override
  String get playlistSave => 'Save';

  @override
  String get playlistOk => 'OK';

  @override
  String get playlistTitle => 'Playlists';

  @override
  String get playlistSwitchToListView => 'Switch to list view';

  @override
  String get playlistSwitchToGridView => 'Switch to grid view';

  @override
  String get playlistCreate => 'Create playlist';

  @override
  String get playlistCreated => 'Playlist created';

  @override
  String get playlistUpdated => 'Playlist updated';

  @override
  String get playlistShowHidden => 'Show hidden playlists';

  @override
  String get playlistHideHidden => 'Hide hidden playlists';

  @override
  String get playlistEmptyHint =>
      'Tap the button in the top-right to create a playlist';

  @override
  String get playlistConfirmBatchDelete => 'Confirm bulk deletion';

  @override
  String playlistBatchDeleteConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete the selected $count playlists? This cannot be undone.',
      one: 'Delete the selected playlist? This cannot be undone.',
    );
    return '$_temp0';
  }

  @override
  String playlistDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Deleted $count playlists',
      one: 'Deleted 1 playlist',
    );
    return '$_temp0';
  }

  @override
  String get playlistHidden => 'Playlist hidden';

  @override
  String get playlistUnhidden => 'Playlist unhidden';

  @override
  String playlistPlayingMultiple(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Playing $count playlists',
      one: 'Playing 1 playlist',
    );
    return '$_temp0';
  }

  @override
  String get playlistExitMultiSelect => 'Exit selection';

  @override
  String playlistSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String playlistPlayCount(int count) {
    return 'Play ($count)';
  }

  @override
  String playlistDeleteCount(int count) {
    return 'Delete ($count)';
  }

  @override
  String get playlistTypeNormalOption => 'Regular playlist';

  @override
  String get playlistTypeRadioOption => 'Radio playlist';

  @override
  String get playlistMoreActions => 'More actions';

  @override
  String get playlistHide => 'Hide playlist';

  @override
  String get playlistUnhide => 'Unhide';

  @override
  String get playlistPickCoverTitle => 'Choose a song cover';

  @override
  String get playlistClose => 'Close';

  @override
  String get playlistNoCoveredSongs => 'No songs with covers in this playlist';

  @override
  String get playlistLoadRetry => 'Failed to load, tap to retry';

  @override
  String get playlistNoCoverLoadMore => 'No covers on this page, load more';

  @override
  String get playlistAllLoadedSimple => '— All loaded —';

  @override
  String get playlistSelectThisCover => 'Select this cover';

  @override
  String get playlistErrRequestFailed => 'Request failed';

  @override
  String get playlistErrTimeout => 'Network connection timed out';

  @override
  String get playlistErrCancelled => 'Request cancelled';

  @override
  String playlistErrNetwork(String message) {
    return 'Network error: $message';
  }

  @override
  String settingsCacheSaveConfigFailed(String error) {
    return 'Failed to save config: $error';
  }

  @override
  String get settingsCacheCleanServerTitle => 'Clear Server Cache';

  @override
  String get settingsCacheCleanServerContent =>
      'Clear all music cache on the server? Files will need to be downloaded again.';

  @override
  String get settingsCacheServerCleaned => 'Server cache cleared';

  @override
  String settingsCacheCleanFailed(String error) {
    return 'Clear failed: $error';
  }

  @override
  String get settingsCacheCleanLocalTitle => 'Clear Local Cache';

  @override
  String get settingsCacheCleanLocalContent =>
      'Clear all local cache? This includes audio, image and lyrics cache.';

  @override
  String get settingsCacheLocalCleaned => 'Local cache cleared';

  @override
  String get settingsCacheCleanBrowserTitle => 'Clear Browser Cache';

  @override
  String get settingsCacheCleanBrowserContent =>
      'This will clear all cached frontend assets and reload the page. Your login and server data will not be affected.';

  @override
  String get webUpdateAvailableTitle => 'Update available';

  @override
  String get webUpdateAvailableContent =>
      'The server has been updated, but this page is still running an older version. Tap \"Refresh now\" to clear the browser cache and load the latest version. Your login will not be affected.';

  @override
  String get webUpdateAvailableRefresh => 'Refresh now';

  @override
  String get webUpdateAvailableLater => 'Later';

  @override
  String settingsCacheUpdateConfigFailed(String error) {
    return 'Failed to update config: $error';
  }

  @override
  String get settingsCacheDirRestored => 'Default cache directory restored';

  @override
  String get settingsCacheDirUpdated => 'Cache directory updated';

  @override
  String settingsCacheUpdateFailed(String error) {
    return 'Update failed: $error';
  }

  @override
  String get settingsCacheConfirmClean => 'Confirm';

  @override
  String get settingsCacheServerTitle => 'Server Music Cache';

  @override
  String get settingsCacheManage => 'Manage';

  @override
  String settingsCacheNoLimit(String size) {
    return '$size (unlimited)';
  }

  @override
  String settingsCacheFileCount(int count) {
    return '$count files';
  }

  @override
  String get settingsCacheStatsLoadFailed => 'Failed to load cache info';

  @override
  String get settingsCacheDirTitle => 'Cache Directory';

  @override
  String get settingsCacheNotConfigured => 'Not configured';

  @override
  String settingsCacheMaxSize(String size) {
    return 'Max cache size: $size';
  }

  @override
  String get settingsCacheTranscodeTitle => 'Cache transcode format';

  @override
  String get settingsCacheTranscodeDesc =>
      'Transcode network songs to a unified format when caching, improving device compatibility (e.g. Xiao AI speakers cannot play MKV); once enabled, video content caches audio only and casting will have no picture';

  @override
  String get settingsCacheTranscodeOriginal => 'Original (no transcode)';

  @override
  String get settingsCacheTranscodeDialogTitle => 'Cache transcode format';

  @override
  String get settingsCacheTranscodeQualityTitle => 'Transcode bitrate';

  @override
  String get settingsCacheTranscodeQualityHighest => 'Highest quality';

  @override
  String get settingsCacheTranscodeQualityDialogTitle => 'Transcode bitrate';

  @override
  String get settingsCacheTranscodeUpdated =>
      'Cache transcode settings updated';

  @override
  String get settingsCacheCleaning => 'Clearing...';

  @override
  String get settingsCacheCleanServerButton => 'Clear Server Cache';

  @override
  String get settingsCacheLocalTitle => 'Local Cache';

  @override
  String get settingsCacheSize => 'Cache size';

  @override
  String get settingsCacheCalculating => 'Calculating...';

  @override
  String get settingsCacheLocalDesc => 'Includes audio, image and lyrics cache';

  @override
  String settingsCacheMaxLocalSize(String size) {
    return 'Max local cache size: $size';
  }

  @override
  String get settingsCacheCleanLocalButton => 'Clear Local Cache';

  @override
  String get settingsCacheBrowserTitle => 'Browser Cache';

  @override
  String get settingsCacheBrowserDesc =>
      'Clear cached frontend assets in the browser to fix page issues after an update';

  @override
  String get settingsCacheCleanBrowserButton => 'Clear Browser Cache';

  @override
  String get settingsCacheDirDialogDesc =>
      'Set the storage directory for the server music cache. Leave empty to use the default. Switching directories does not migrate existing cache files.';

  @override
  String get settingsCacheDirLabel => 'Cache directory (absolute path)';

  @override
  String settingsCacheDirDefault(String dir) {
    return 'Default: $dir';
  }

  @override
  String get settingsCacheValidate => 'Validate';

  @override
  String get settingsCacheRestoreDefault => 'Restore Default';

  @override
  String get settingsCacheSave => 'Save';

  @override
  String get settingsCacheDirUnavailable => 'Directory unavailable';

  @override
  String get settingsCacheDirCreated => 'Directory created automatically';

  @override
  String settingsCacheDiskTotal(String size) {
    return 'Total $size';
  }

  @override
  String settingsCacheDiskFree(String size) {
    return 'Free $size';
  }

  @override
  String get settingsCacheDirAvailable => 'Directory available';

  @override
  String get settingsMetadataUseTagTitle => 'Use tags to override title';

  @override
  String get settingsMetadataUseTagOn =>
      'Override titles with audio tags when refreshing remote song metadata';

  @override
  String get settingsMetadataUseTagOff =>
      'Keep filenames as remote song titles, do not override with tags';

  @override
  String get settingsMetadataSaved => 'Saved';

  @override
  String settingsMetadataSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get settingsMetadataRefreshTitle => 'Refresh remote song metadata';

  @override
  String get settingsMetadataRefreshSubtitle =>
      'Probe all remote songs with missing metadata';

  @override
  String get settingsMetadataStart => 'Start';

  @override
  String get settingsMetadataPreparing => 'Preparing...';

  @override
  String get settingsMetadataRefreshing => 'Refreshing metadata';

  @override
  String get settingsMetadataStatusCancelled => 'Cancelled';

  @override
  String get settingsMetadataStatusFailed => 'Failed';

  @override
  String get settingsMetadataStatusDone => 'Done';

  @override
  String settingsMetadataSuccess(int count) {
    return '$count succeeded';
  }

  @override
  String settingsMetadataFailedCount(int count) {
    return ', $count failed';
  }

  @override
  String settingsMetadataRefreshResult(String status) {
    return 'Metadata refresh $status';
  }

  @override
  String get settingsMetadataRefreshAgain => 'Refresh Again';

  @override
  String get settingsClientDownloadTitle => 'Download Client App';

  @override
  String get settingsClientDownloadIntro =>
      'Compared with the web interface, the native client supports background playback, local caching, lock-screen/notification media controls and more.';

  @override
  String get settingsClientDownloadAccelSection => 'Download Acceleration';

  @override
  String get settingsClientDownloadGithubProxy => 'GitHub Proxy';

  @override
  String get settingsClientDownloadProxyNotConfigured =>
      'Not configured (direct GitHub connection, may be slow in some regions)';

  @override
  String get settingsClientDownloadStandardSection =>
      'Standard · Connects to current server';

  @override
  String get settingsClientDownloadBundleSection =>
      'Bundle · Embedded backend, no server needed';

  @override
  String get settingsClientDownloadStandardAllVersions =>
      'All standard versions';

  @override
  String get settingsClientDownloadBundleAllVersions => 'All bundle versions';

  @override
  String settingsClientDownloadRecommendFor(String os) {
    return 'Recommended for your device: $os';
  }

  @override
  String settingsClientDownloadStandardBtn(String label) {
    return 'Standard ($label)';
  }

  @override
  String settingsClientDownloadBundleBtn(String label) {
    return 'Bundle ($label)';
  }

  @override
  String get settingsClientDownloadNoteUnsigned =>
      'Unsigned, requires manual sideloading';

  @override
  String get settingsClientDownloadProxyDialogDesc =>
      'If GitHub is slow in your region, you can choose a mirror to speed it up. This setting is shared with \"Check for updates\".';

  @override
  String get settingsClientDownloadCustomProxy => 'Custom proxy';

  @override
  String get settingsClientDownloadCustomProxyHelper =>
      'Enter a proxy address, e.g. https://ghproxy.com/';

  @override
  String get settingsClientDownloadSave => 'Save';

  @override
  String get settingsTabConfigTitle => 'Menu Settings';

  @override
  String get settingsTabConfigBuiltInSection => 'Built-in Pages';

  @override
  String get settingsTabConfigLibrary => 'Library';

  @override
  String get settingsTabConfigPlaylists => 'Playlists';

  @override
  String get settingsTabConfigPluginEntry => 'Plugin Entries';

  @override
  String get settingsTabConfigNoPlugins => 'No plugins available';

  @override
  String get settingsTabConfigNoPluginsHint =>
      'Please install and enable plugins in settings first';

  @override
  String get settingsTabConfigPluginOrder => 'Plugin Order';

  @override
  String settingsTabConfigEnabledCount(int count) {
    return '$count tab(s) enabled (Home and Settings are always shown)';
  }

  @override
  String get settingsTabConfigCollapseHint =>
      'On mobile, tabs beyond 5 will collapse into the \"More\" menu';

  @override
  String settingsTabConfigMaxTabs(int count) {
    return 'Show at most $count tabs';
  }

  @override
  String settingsTabConfigSaveFailed(String error) {
    return 'Failed to save: $error';
  }

  @override
  String get settingsUpgradeStatusStable => 'Stable';

  @override
  String get settingsUpgradeStatusDev => 'Dev';

  @override
  String get settingsUpgradeStatusDownloading => 'Downloading...';

  @override
  String get settingsUpgradeStatusTesting => 'Verifying...';

  @override
  String get settingsUpgradeStatusReplacing => 'Replacing...';

  @override
  String get settingsUpgradeStatusResetting => 'Rolling back...';

  @override
  String get settingsUpgradeStatusRestarting => 'Restarting...';

  @override
  String get settingsUpgradeStatusCompleted => 'Upgrade complete';

  @override
  String get settingsUpgradeStatusFailed => 'Upgrade failed';

  @override
  String get settingsUpgradeStatusIdle => 'Idle';

  @override
  String get settingsFrontendVerDevVersion => 'Dev version';

  @override
  String settingsFrontendVerCheckFailed(String error) {
    return 'Failed to check for client updates: $error';
  }

  @override
  String settingsScanScanFailed(String error) {
    return 'Scan failed: $error';
  }

  @override
  String settingsScanCancelFailed(String error) {
    return 'Cancel failed: $error';
  }

  @override
  String get settingsScanModeSkipDesc =>
      'Only import newly discovered music files';

  @override
  String get settingsScanModeReimportDesc =>
      'Rescan and overwrite all music info';

  @override
  String get settingsScanDismiss => 'Dismiss';

  @override
  String get settingsScanExcludeDirTitle => 'Exclude directory settings';

  @override
  String get settingsScanExcludeDirSubtitle =>
      'Configure directories to ignore during scan';

  @override
  String get settingsScanModeSkip => 'Skip existing';

  @override
  String get settingsScanModeReimport => 'Reimport';

  @override
  String get settingsScanStarting => 'Starting...';

  @override
  String get settingsScanScanLocal => 'Scan local music';

  @override
  String settingsScanScanSelectedDirs(int count) {
    return 'Scan $count selected directories';
  }

  @override
  String get settingsScanTargetDirsTitle => 'Specific directories (optional)';

  @override
  String get settingsScanTargetDirsSubtitle =>
      'Only scan selected directories; leave empty to scan the whole library';

  @override
  String settingsScanTargetDirsSelected(int count) {
    return '$count directories selected';
  }

  @override
  String get settingsScanDirsToScan => 'Directories to scan:';

  @override
  String get settingsScanClear => 'Clear';

  @override
  String get settingsScanCreatingPlaylists =>
      'Auto-creating playlists by directory...';

  @override
  String get settingsScanSplittingCue => 'Splitting whole track (CUE)...';

  @override
  String settingsScanSplittingCueProgress(int count) {
    return 'Splitting whole track (CUE): $count sources processed';
  }

  @override
  String get settingsScanDiscovering => 'Discovering files...';

  @override
  String settingsScanDiscoveringProgress(int count) {
    return 'Discovering files: $count found';
  }

  @override
  String settingsScanScanningFile(String file) {
    return 'Scanning: $file';
  }

  @override
  String settingsScanProgressStats(
    int scanned,
    int total,
    int imported,
    int skipped,
    int failed,
  ) {
    return 'Processed: $scanned/$total, imported: $imported, skipped: $skipped, failed: $failed';
  }

  @override
  String get settingsScanCancelScan => 'Cancel scan';

  @override
  String get settingsScanAutoCreatePlaylists =>
      'Auto-create playlists after scan';

  @override
  String get settingsScanAutoCreatePlaylistsDesc =>
      'Auto-generate playlists by directory structure';

  @override
  String get settingsScanLoadingConfig => 'Loading...';

  @override
  String get settingsScanReadConfigFailed => 'Failed to read config';

  @override
  String settingsScanSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get settingsScanPlaylistModeDirectory => 'By folder';

  @override
  String get settingsScanPlaylistModeDirectoryDesc =>
      'Generate a separate playlist for each folder';

  @override
  String get settingsScanPlaylistModeTopLevel => 'By top-level folder';

  @override
  String get settingsScanPlaylistModeTopLevelDesc =>
      'Merge songs from subfolders into the top-level folder playlist';

  @override
  String get settingsScanPlaylistModeBubbleUp => 'Include subdirectories';

  @override
  String get settingsScanPlaylistModeBubbleUpDesc =>
      'Songs appear in all ancestor folder playlists';

  @override
  String get settingsScanPlaylistModeTitle => 'Playlist creation mode';

  @override
  String get settingsScanPlaylistModeDisabled =>
      'Auto-create playlists is off; this option has no effect';

  @override
  String get settingsScanTitleSource => 'Use filename as title';

  @override
  String get settingsScanTitleSourceFilenameDesc =>
      'Use the filename (without extension) as the song title; suitable when filenames are already numbered';

  @override
  String get settingsScanTitleSourceTagDesc =>
      'Prefer audio tag info for the song title';

  @override
  String get settingsScanTitleSourceSaved =>
      'Saved; takes effect after scanning in \'Reimport\' mode';

  @override
  String get settingsScanInterval10Min => '10 minutes';

  @override
  String get settingsScanInterval30Min => '30 minutes';

  @override
  String get settingsScanInterval1Hour => '1 hour';

  @override
  String get settingsScanInterval3Hour => '3 hours';

  @override
  String get settingsScanInterval6Hour => '6 hours';

  @override
  String get settingsScanInterval12Hour => '12 hours';

  @override
  String get settingsScanInterval24Hour => '24 hours';

  @override
  String settingsScanIntervalSeconds(int count) {
    return '$count seconds';
  }

  @override
  String get settingsScanAutoScan => 'Auto scan';

  @override
  String settingsScanAutoScanInterval(String interval) {
    return 'Auto scan every $interval';
  }

  @override
  String get settingsScanAutoScanOff => 'Off';

  @override
  String get settingsScanScanInterval => 'Scan interval';

  @override
  String settingsScanCompletedSummary(int count) {
    return 'Scan complete, $count local songs in total';
  }

  @override
  String settingsScanCompletedStats(int imported, int skipped, int failed) {
    return 'Imported $imported, skipped $skipped, failed $failed';
  }

  @override
  String get settingsScanRescan => 'Rescan';

  @override
  String settingsScanCancelledSummary(int count) {
    return 'Scan cancelled ($count files processed)';
  }

  @override
  String get settingsScanErrorTitle => 'Scan error';

  @override
  String settingsExcludeDirLoadFailed(String error) {
    return 'Failed to load config: $error';
  }

  @override
  String get settingsExcludeDirSaved =>
      'Exclude directory settings saved; cleaning up songs in excluded directories in the background';

  @override
  String settingsExcludeDirSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get settingsExcludeDirTabName => 'By name';

  @override
  String get settingsExcludeDirTabPath => 'By path';

  @override
  String get settingsExcludeDirTabPlaylist => 'Playlist exclude';

  @override
  String get settingsExcludeDirSaving => 'Saving...';

  @override
  String get settingsExcludeDirSaveConfig => 'Save exclude settings';

  @override
  String get settingsExcludeDirSaveHint =>
      'After saving, imported songs in excluded directories will be cleaned up automatically';

  @override
  String get settingsExcludeDirInputName => 'Enter directory name';

  @override
  String get settingsExcludeDirInputHint =>
      'Type and select, or press Enter to add';

  @override
  String get settingsExcludeDirLoadingCandidates => 'Loading candidates...';

  @override
  String get settingsExcludeDirAdd => 'Add';

  @override
  String get settingsExcludeDirExcludedNames => 'Excluded directory names:';

  @override
  String get settingsExcludeDirNameHint =>
      'Any directory containing this name at any path level will be excluded';

  @override
  String settingsExcludeDirMusicDir(String path) {
    return 'Music directory: $path';
  }

  @override
  String get settingsExcludeDirExcludedPaths => 'Excluded paths:';

  @override
  String get settingsExcludeDirAutoCreateExcluded =>
      'Directories excluded from auto-created playlists:';

  @override
  String get settingsExcludeDirAutoCreateHint =>
      'Directories containing this name at any path level will not be auto-created as playlists';

  @override
  String get settingsServersTitle => 'Servers';

  @override
  String get settingsServersTestAll => 'Test all';

  @override
  String get settingsServersEmptyTitle => 'No servers added yet';

  @override
  String get settingsServersEmptyHint =>
      'Tap the \"+\" button to add an API address.\nOn startup, servers are probed in order and the first reachable one is used.';

  @override
  String get settingsServersAdd => 'Add server';

  @override
  String get settingsServersEditTitle => 'Edit server';

  @override
  String get settingsServersNameLabel => 'Name (optional)';

  @override
  String get settingsServersNameHint => 'LAN / WAN / Backup';

  @override
  String get settingsServersUrlLabel => 'API address';

  @override
  String get settingsServersUsername => 'Username';

  @override
  String get settingsServersPassword => 'Password';

  @override
  String get settingsServersSave => 'Save';

  @override
  String settingsServersSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get settingsServersDeleteTitle => 'Delete server';

  @override
  String get settingsServersDeleteCurrentConfirm =>
      'This is the server currently in use. After deletion, the remaining servers in the list will be probed again on next startup. Continue?';

  @override
  String settingsServersDeleteConfirm(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String settingsServersReachable(String name) {
    return '$name is reachable';
  }

  @override
  String settingsServersUnreachable(String name) {
    return '$name is unreachable';
  }

  @override
  String settingsServersProbeResult(int ok, int total) {
    return 'Probe complete: $ok / $total reachable';
  }

  @override
  String get settingsServersAlreadyCurrent => 'Already the current server';

  @override
  String settingsServersSwitched(String name) {
    return 'Switched to $name, please sign in again';
  }

  @override
  String get settingsServersSwitchTo => 'Switch to this';

  @override
  String get settingsServersTestConnection => 'Test connection';

  @override
  String get settingsServersEditAction => 'Edit';

  @override
  String get settingsServersLocalMode => 'Local mode';

  @override
  String get settingsServersLocalModeDesc =>
      'When enabled, the backend runs on this device so you can play local music without a network.';

  @override
  String get settingsServersMusicDir => 'Music folder';

  @override
  String get settingsServersNotSelected => 'Not selected';

  @override
  String get settingsServersSelect => 'Select';

  @override
  String get settingsServersFixedMusicDirHint =>
      'Put music into the Songloft folder via the Files app or a computer (Finder / iTunes file sharing), then rescan.';

  @override
  String settingsServersSwitchFailed(String error) {
    return 'Switch failed: $error';
  }

  @override
  String get settingsServersSwitchedLocal => 'Switched to local mode';

  @override
  String get settingsServersMusicDirUpdated => 'Music folder updated';

  @override
  String get settingsDuplicateTitle => 'Duplicate detection';

  @override
  String get settingsDuplicateDismissError => 'Dismiss';

  @override
  String get settingsDuplicateIntro =>
      'Identify duplicate files with identical content using audio fingerprints. The same song is recognized even across different file names and formats.';

  @override
  String get settingsDuplicateFingerprintStats => 'Fingerprint stats';

  @override
  String get settingsDuplicateLocalSongs => 'Local songs';

  @override
  String get settingsDuplicateComputed => 'Fingerprinted';

  @override
  String get settingsDuplicatePending => 'Pending';

  @override
  String settingsDuplicateSongCount(int count) {
    return '$count';
  }

  @override
  String get settingsDuplicateChromaprintMissing =>
      'Audio fingerprint detection requires ffmpeg with chromaprint support. Docker users can simply upgrade to the latest image.';

  @override
  String get settingsDuplicateStartCompute => 'Compute and detect';

  @override
  String get settingsDuplicateCheck => 'Detect duplicates';

  @override
  String get settingsDuplicateRecomputeAll => 'Recompute all fingerprints';

  @override
  String settingsDuplicateComputing(int computed, int total) {
    return 'Computing audio fingerprints... $computed/$total';
  }

  @override
  String settingsDuplicateFailed(int count) {
    return 'Failed: $count';
  }

  @override
  String get settingsDuplicateAutoDetect =>
      'Duplicates will be detected automatically once computation finishes';

  @override
  String get settingsDuplicateRecheck => 'Recheck';

  @override
  String get settingsDuplicateNoResults => 'No duplicate songs found';

  @override
  String get settingsDuplicateNoResultsHint => 'Your music library is clean!';

  @override
  String settingsDuplicateSummary(int groups, int songs) {
    return 'Found $groups duplicate groups ($songs songs total)';
  }

  @override
  String settingsDuplicateIgnoredCount(int count) {
    return '$count groups ignored';
  }

  @override
  String settingsDuplicateCleanAll(int count) {
    return 'Clean all duplicates (delete $count)';
  }

  @override
  String settingsDuplicateGroupLabel(int index) {
    return 'Duplicate group $index';
  }

  @override
  String get settingsDuplicateUnignore => 'Unignore';

  @override
  String get settingsDuplicateIgnore => 'Ignore this group';

  @override
  String get settingsDuplicateDeleteUnselected => 'Delete unselected';

  @override
  String get settingsDuplicateRecommended => 'Recommended';

  @override
  String get settingsDuplicateConfirmTitle => 'Confirm deletion';

  @override
  String settingsDuplicateConfirmMessage(int count) {
    return 'This will delete $count duplicate songs and their audio files, keeping the selected version in each group. This action cannot be undone.';
  }

  @override
  String settingsDuplicateDeleted(int count) {
    return 'Deleted $count duplicate songs';
  }

  @override
  String settingsDuplicateDeleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get settingsCategoryAppearanceTitle => 'Appearance';

  @override
  String get settingsCategoryAppearanceSubtitle => 'Theme, menu and display';

  @override
  String get settingsCategoryPlaybackTitle => 'Playback';

  @override
  String get settingsCategoryPlaybackSubtitle => 'Audio quality';

  @override
  String get settingsCategoryLibraryTitle => 'Library';

  @override
  String get settingsCategoryLibrarySubtitle => 'Scan, import and convert';

  @override
  String get settingsCategoryExtensionsTitle => 'Extensions';

  @override
  String get settingsCategoryExtensionsSubtitle => 'Plugin management';

  @override
  String get settingsCategoryCacheTitle => 'Cache';

  @override
  String get settingsCategoryCacheSubtitle => 'Server and local cache';

  @override
  String get settingsCategoryNetworkTitle => 'Network';

  @override
  String get settingsCategoryNetworkSubtitle => 'Proxy configuration';

  @override
  String get settingsCategoryDataTitle => 'Data';

  @override
  String get settingsCategoryDataSubtitle => 'Playlist export and import';

  @override
  String get settingsCategoryAboutTitle => 'About & Updates';

  @override
  String get settingsCategoryAboutSubtitle => 'Version and logs';

  @override
  String get settingsCategoryAccountTitle => 'Account';

  @override
  String get settingsCategoryAccountSubtitle => 'Server and login';

  @override
  String get settingsDevVersion => 'Dev build';

  @override
  String get settingsStableVersion => 'Stable';

  @override
  String get settingsLocalMode => 'Local mode';

  @override
  String get settingsManage => 'Manage';

  @override
  String get settingsMenuTitle => 'Menu settings';

  @override
  String get settingsMenuLibrary => 'Library';

  @override
  String get settingsMenuPlaylists => 'Playlists';

  @override
  String settingsTabsEnabledCount(int count) {
    return '$count tabs enabled (Home and Settings are always shown)';
  }

  @override
  String get settingsTabsCollapseHint =>
      'On mobile, tabs beyond 5 collapse into the \"More\" menu';

  @override
  String settingsMaxTabsLimit(int count) {
    return 'You can show at most $count tabs';
  }

  @override
  String settingsSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get settingsQualityOriginal => 'Original quality';

  @override
  String get settingsQualityLow => 'Low (128kbps)';

  @override
  String get settingsQualityMedium => 'Medium (192kbps)';

  @override
  String get settingsQualityHigh => 'High (320kbps)';

  @override
  String get settingsQualityTitle => 'Audio quality';

  @override
  String get settingsQualityDialogTitle => 'Select audio quality';

  @override
  String get settingsQualityOriginalDesc =>
      'No transcoding, use the file\'s original bitrate';

  @override
  String get settingsQualityTranscodeDesc =>
      'Transcode to MP3, suited for weak networks';

  @override
  String get settingsAutoPlayOnLaunchTitle => 'Auto-play on launch';

  @override
  String get settingsAutoPlayOnLaunchDesc =>
      'Resume the last playback automatically when the app opens';

  @override
  String get settingsAutoEnterLyricsOnLaunchTitle => 'Open lyrics on launch';

  @override
  String get settingsAutoEnterLyricsOnLaunchDesc =>
      'Automatically open the full-screen lyrics view when the app opens (adapts to screen size)';

  @override
  String get settingsNotificationLyricInTitleTitle =>
      'Lyrics in the notification title';

  @override
  String get settingsNotificationLyricInTitleDesc =>
      'On: the title line shows lyrics and the song name moves to the subtitle. Off: the title line shows the song name and lyrics move to the subtitle';

  @override
  String get settingsShortcutsEntryTitle => 'Keyboard shortcuts';

  @override
  String get settingsShortcutsEntrySubtitle =>
      'Customize playback control keys';

  @override
  String get settingsShortcutsPageTitle => 'Keyboard shortcuts';

  @override
  String get settingsShortcutsEnableTitle => 'Enable keyboard shortcuts';

  @override
  String get settingsShortcutsEnableSubtitle =>
      'Control playback with shortcuts inside the desktop window';

  @override
  String get settingsShortcutActionPlayPause => 'Play / Pause';

  @override
  String get settingsShortcutActionPlayNext => 'Next track';

  @override
  String get settingsShortcutActionPlayPrev => 'Previous track';

  @override
  String get settingsShortcutActionSeekForward => 'Seek forward';

  @override
  String get settingsShortcutActionSeekBackward => 'Seek backward';

  @override
  String get settingsShortcutActionVolumeUp => 'Volume up';

  @override
  String get settingsShortcutActionVolumeDown => 'Volume down';

  @override
  String get settingsShortcutActionToggleMute => 'Toggle mute';

  @override
  String get settingsShortcutRecordPrompt => 'Press a key combination…';

  @override
  String get settingsShortcutUnset => 'Not set';

  @override
  String get settingsShortcutConflictTitle => 'Shortcut conflict';

  @override
  String settingsShortcutConflict(String action) {
    return 'This combination is already used by \"$action\"';
  }

  @override
  String get settingsShortcutOverride => 'Override';

  @override
  String get settingsShortcutClear => 'Clear';

  @override
  String get settingsShortcutResetAll => 'Reset all to defaults';

  @override
  String get settingsShortcutResetAllConfirm =>
      'Reset all shortcuts to their defaults?';

  @override
  String settingsQualitySwitched(String quality) {
    return 'Audio quality switched to $quality';
  }

  @override
  String settingsSwitchFailed(String error) {
    return 'Switch failed: $error';
  }

  @override
  String get settingsLibraryDuplicateTitle => 'Duplicate detection';

  @override
  String get settingsLibraryDuplicateSubtitle =>
      'Identify duplicate files with identical content via audio fingerprint';

  @override
  String get settingsPluginStoreTitle => 'Plugin store';

  @override
  String get settingsPluginStoreSubtitle => 'Browse and install plugins';

  @override
  String get settingsExportPlaylistTitle => 'Export playlists';

  @override
  String get settingsExportPlaylistSubtitle =>
      'Back up all playlist data to a JSON file';

  @override
  String get settingsImportPlaylistTitle => 'Import playlists';

  @override
  String get settingsImportPlaylistSubtitle =>
      'Restore playlist data from a JSON backup file';

  @override
  String get settingsDownloadAppTitle => 'Download the app';

  @override
  String get settingsDownloadAppSubtitle =>
      'Get the mobile / desktop native client with background playback, caching and more';

  @override
  String get settingsWebDebugConsoleTitle => 'Debug Console';

  @override
  String get settingsWebDebugConsoleSubtitle =>
      'Enable NextConsole web debug panel (requires page reload)';

  @override
  String get settingsWebDebugConsoleEnabled =>
      'Debug console enabled, page will reload';

  @override
  String get settingsWebDebugConsoleDisabled =>
      'Debug console disabled, page will reload';

  @override
  String get settingsAboutTitle => 'About';

  @override
  String get settingsAboutSubtitle => 'Version info and license';

  @override
  String get settingsAccountServer => 'Server';

  @override
  String get settingsNoMusicDir => 'No music folder selected';

  @override
  String get settingsLogout => 'Log out';

  @override
  String get settingsLogoutConfirmTitle => 'Confirm log out';

  @override
  String get settingsLogoutConfirmContent =>
      'Are you sure you want to log out of the current account?';

  @override
  String get settingsLogoutButton => 'Log out';

  @override
  String get settingsExportNotLoggedIn => 'Not logged in, cannot export';

  @override
  String settingsExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get settingsImportReadFailed => 'Unable to read file content';

  @override
  String get settingsImportPathFailed => 'Unable to get file path';

  @override
  String settingsImportComplete(
    Object created,
    Object merged,
    Object songsCreated,
    Object songsMatched,
  ) {
    return 'Import complete: $created playlists created, $merged merged, $songsCreated songs created, $songsMatched matched';
  }

  @override
  String settingsImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get settingsCheckServerUpdate => 'Check for server updates';

  @override
  String settingsUpdateAvailable(String version) {
    return 'New version available: $version';
  }

  @override
  String settingsCurrentVersionLatest(String version) {
    return 'Current version: $version (up to date)';
  }

  @override
  String get settingsCheckingUpdate => 'Checking for updates...';

  @override
  String get settingsCheckUpdateFailed => 'Failed to check for updates';

  @override
  String get settingsCheckClientUpdate => 'Check for client updates';

  @override
  String settingsCurrentVersion(String version) {
    return 'Current version: $version';
  }

  @override
  String get settingsHlsProxyTitle => 'HLS radio backend proxy';

  @override
  String get settingsHlsProxySubtitle =>
      'When enabled, the server fetches radio m3u8 and proxies segments, bypassing Referer hotlink protection / CORS. All segments use this machine\'s bandwidth—mind the traffic cost.';

  @override
  String get settingsHlsProxyEnabled => 'HLS proxy enabled';

  @override
  String get settingsHlsProxyDisabled => 'HLS proxy disabled';

  @override
  String get settingsInsecureTlsTitle => 'Ignore SSL certificate verification';

  @override
  String get settingsInsecureTlsSubtitle =>
      'Enable when connecting to a server with a self-signed or invalid HTTPS certificate. Applies to both API requests and audio playback.';

  @override
  String get settingsInsecureTlsEnabled => 'Certificate verification ignored';

  @override
  String get settingsInsecureTlsDisabled => 'Certificate verification enabled';

  @override
  String get settingsInsecureTlsWarnTitle => 'Reduced security';

  @override
  String get settingsInsecureTlsWarnContent =>
      'Once enabled, any HTTPS certificate will be accepted, which exposes you to man-in-the-middle attacks. Use only on trusted intranets or with self-signed certificates. Enable anyway?';

  @override
  String get settingsHttpProxyTitle => 'HTTP proxy';

  @override
  String get settingsHttpProxyNotConfigured => 'Not configured (direct)';

  @override
  String get settingsHttpProxyDialogDesc =>
      'Set a global HTTP proxy. All outbound backend requests (plugin downloads, update checks, etc.) will be forwarded through it. Leave empty for a direct connection.';

  @override
  String get settingsHttpProxyAddressLabel => 'Proxy address';

  @override
  String get settingsHttpProxyHelper => 'Supports HTTP/HTTPS/SOCKS5 proxies';

  @override
  String get settingsClear => 'Clear';

  @override
  String get settingsSave => 'Save';

  @override
  String get settingsHttpProxyCleared => 'HTTP proxy cleared';

  @override
  String settingsHttpProxySet(String proxy) {
    return 'HTTP proxy set to $proxy';
  }

  @override
  String get settingsLogLevelDebug => 'Debug (verbose, for debugging)';

  @override
  String get settingsLogLevelInfo => 'Info (default)';

  @override
  String get settingsLogLevelWarn => 'Warn';

  @override
  String get settingsLogLevelError => 'Error (errors only)';

  @override
  String get settingsLogLevelTitle => 'Log level';

  @override
  String get settingsLogLevelDialogTitle => 'Select log level';

  @override
  String settingsLogLevelSwitched(String level) {
    return 'Log level switched to $level';
  }

  @override
  String get settingsExportLogsTitle => 'Export logs';

  @override
  String get settingsExportLogsSubtitle =>
      'Bundle redacted frontend & backend logs for issue reports';

  @override
  String get settingsExportLogsShareSubject => 'Songloft logs';

  @override
  String get settingsExportLogsSuccess =>
      'Logs bundled, choose how to share or save';

  @override
  String get settingsExportLogsSuccessNoBackend =>
      'Exported frontend logs (backend logs unavailable)';

  @override
  String settingsExportLogsFailed(String error) {
    return 'Failed to export logs: $error';
  }

  @override
  String get settingsAccountUrlNotConfigured => 'Not configured · Tap to add';

  @override
  String settingsAccountUrlSummary(int count, String label) {
    return '$count addresses · Current: $label';
  }

  @override
  String get settingsAccountLoading => 'Loading...';

  @override
  String get settingsAboutDesc1 =>
      'Songloft is an open-source personal music server app.';

  @override
  String get settingsAboutDesc2 =>
      'Supports local library management, online playback and plugin extensions.';

  @override
  String get settingsAboutGithubSemantics => 'Open the GitHub page';

  @override
  String get settingsUpgradeCheckTimeout =>
      'Update check timed out. Try switching the proxy and retry.';

  @override
  String settingsUpgradeCheckFailed(String error) {
    return 'Failed to check for updates: $error';
  }

  @override
  String get settingsUpgradeChannelDev => 'Dev build';

  @override
  String get settingsUpgradeChannelStable => 'Stable build';

  @override
  String settingsUpgradeVersionWithDetails(String version, String details) {
    return '$version ($details)';
  }

  @override
  String settingsUpgradeStartFailed(String error) {
    return 'Failed to start upgrade: $error';
  }

  @override
  String get settingsUpgradeConfirmReset => 'Confirm rollback';

  @override
  String get settingsUpgradeConfirmResetContent =>
      'Roll back to the base image version of the Docker image?\n\nThe service will restart automatically after rollback.';

  @override
  String settingsUpgradeResetFailed(String error) {
    return 'Rollback failed: $error';
  }

  @override
  String get settingsUpgradeTitle => 'Check for updates';

  @override
  String get settingsUpgradeChecking => 'Checking for updates...';

  @override
  String get settingsUpgradeGithubProxy => 'GitHub proxy';

  @override
  String get settingsUpgradeCustomProxy => 'Custom proxy';

  @override
  String get settingsUpgradeProxyHelper =>
      'Enter a proxy address, e.g. https://ghproxy.com/';

  @override
  String get settingsUpgradeUpToDate => 'You\'re on the latest version';

  @override
  String settingsUpgradeCurrentVersion(String version) {
    return 'Current version: $version';
  }

  @override
  String get settingsUpgradeSelectVersion => 'Select version to upgrade:';

  @override
  String settingsUpgradeBuildTime(String time) {
    return 'Build time: $time';
  }

  @override
  String get settingsUpgradeReleaseNotes => 'Release notes:';

  @override
  String get settingsUpgradeResetting => 'Rolling back...';

  @override
  String get settingsUpgradeResetButton => 'Roll back to base version';

  @override
  String get settingsUpgradeCompleted => 'Upgrade complete';

  @override
  String get settingsUpgradeRestartSoon => 'The app will restart shortly';

  @override
  String get settingsUpgradeFailed => 'Upgrade failed';

  @override
  String get settingsUpgradeClose => 'Close';

  @override
  String get settingsUpgradeRecheck => 'Check again';

  @override
  String get settingsUpgradeLater => 'Later';

  @override
  String get settingsUpgradeGoDownload => 'Go to download';

  @override
  String get settingsUpgradeUpgradeNow => 'Upgrade now';

  @override
  String get settingsFrontendUpgradeCheckTimeout =>
      'Update check timed out. Try switching the proxy and retry.';

  @override
  String get settingsFrontendUpgradeTitle => 'Client update';

  @override
  String get settingsFrontendUpgradeChecking => 'Checking for updates...';

  @override
  String get settingsFrontendUpgradeGithubProxy => 'GitHub proxy';

  @override
  String get settingsFrontendUpgradeCustomProxy => 'Custom proxy';

  @override
  String get settingsFrontendUpgradeProxyHelper =>
      'Enter a proxy address, e.g. https://ghproxy.com/';

  @override
  String get settingsFrontendUpgradeUpToDate => 'You\'re on the latest version';

  @override
  String settingsFrontendUpgradeCurrentVersion(String version) {
    return 'Current version: $version';
  }

  @override
  String settingsFrontendUpgradeLatestVersion(String version) {
    return 'Latest version: $version';
  }

  @override
  String settingsFrontendUpgradePublishedAt(String date) {
    return 'Published: $date';
  }

  @override
  String get settingsFrontendUpgradeReleaseNotes => 'Release notes:';

  @override
  String get settingsFrontendUpgradeRecheck => 'Check again';

  @override
  String get settingsFrontendUpgradeClose => 'Close';

  @override
  String get settingsFrontendUpgradeLater => 'Later';

  @override
  String get settingsFrontendUpgradeGoDownload => 'Go to download';

  @override
  String get settingsConfigTitle => 'Configuration';

  @override
  String get settingsConfigSubtitle => 'Manage system configuration items';

  @override
  String get settingsConfigAdd => 'Add config';

  @override
  String get settingsConfigRefresh => 'Refresh';

  @override
  String get settingsConfigEmpty => 'No configuration items';

  @override
  String get settingsConfigEmptyHint =>
      'Tap \"Add config\" to create a new item';

  @override
  String get settingsConfigKeyLabel => 'Config key';

  @override
  String get settingsConfigKeyHint => 'e.g. app.setting.name';

  @override
  String get settingsConfigKeyRequired => 'Please enter a config key';

  @override
  String get settingsConfigValueLabel => 'Config value';

  @override
  String get settingsConfigValueHint => 'Config value (multi-line supported)';

  @override
  String get settingsConfigValueRequired => 'Please enter a config value';

  @override
  String get settingsConfigAddButton => 'Add';

  @override
  String get settingsConfigAdded => 'Config added';

  @override
  String settingsConfigAddFailed(String error) {
    return 'Failed to add: $error';
  }

  @override
  String settingsConfigEditTitle(String key) {
    return 'Edit config: $key';
  }

  @override
  String settingsConfigKeyDisplay(String key) {
    return 'Config key: $key';
  }

  @override
  String get settingsConfigSave => 'Save';

  @override
  String get settingsConfigUpdated => 'Config updated';

  @override
  String settingsConfigUpdateFailed(String error) {
    return 'Failed to update: $error';
  }

  @override
  String get settingsConfigConfirmDelete => 'Confirm deletion';

  @override
  String settingsConfigDeleteConfirm(String key) {
    return 'Delete config \"$key\"?';
  }

  @override
  String get settingsConfigDeleted => 'Config deleted';

  @override
  String settingsConfigDeleteFailed(String error) {
    return 'Failed to delete: $error';
  }

  @override
  String get settingsConfigEdit => 'Edit';

  @override
  String get settingsTokenTitle => 'Token management';

  @override
  String get settingsTokenSubtitle => 'Manage login tokens';

  @override
  String get settingsTokenEmpty => 'No tokens';

  @override
  String get settingsTokenConfirmRevoke => 'Confirm revocation';

  @override
  String get settingsTokenRevokeConfirm =>
      'Revoking this token will invalidate the corresponding login session. Continue?';

  @override
  String get settingsTokenRevoke => 'Revoke';

  @override
  String get settingsTokenRevoked => 'Token revoked';

  @override
  String settingsTokenRevokeFailed(String error) {
    return 'Failed to revoke: $error';
  }

  @override
  String get settingsTokenStatusRevoked => 'Revoked';

  @override
  String get settingsTokenStatusExpired => 'Expired';

  @override
  String get settingsTokenStatusActive => 'Active';

  @override
  String settingsTokenType(String type) {
    return 'Type: $type';
  }

  @override
  String get settingsTokenTypeAccess => 'Access token';

  @override
  String get settingsTokenTypeRefresh => 'Refresh token';

  @override
  String settingsTokenClient(String info) {
    return 'Client: $info';
  }

  @override
  String settingsTokenExpiresAt(String time) {
    return 'Expires: $time';
  }

  @override
  String get coreTrayOpen => 'Open Songloft';

  @override
  String get coreTrayOpenLogs => 'Open log directory';

  @override
  String get coreTrayExit => 'Exit';

  @override
  String get coreUrlEmpty => 'URL cannot be empty';

  @override
  String get coreUrlInvalid =>
      'Enter a valid URL (including http:// or https://)';

  @override
  String get corePickMusicDir => 'Select music folder';

  @override
  String get categoryFieldGenre => 'Genre';

  @override
  String get categoryFieldArtist => 'Artist';

  @override
  String get categoryFieldAlbum => 'Album';

  @override
  String get categoryFieldYear => 'Year';

  @override
  String get categoryFieldDecade => 'Decade';

  @override
  String get categoryFieldLanguage => 'Language';

  @override
  String get categoryFieldStyle => 'Style';

  @override
  String get categoryValueUnknown => 'Unknown';

  @override
  String categoryValueYear(String value) {
    return '$value';
  }

  @override
  String categoryValueDecade(String value) {
    return '${value}s';
  }

  @override
  String get categoryBrowseTitle => 'Browse by Category';

  @override
  String categoryEmptyTitle(String label) {
    return 'No \"$label\" categories';
  }

  @override
  String get categoryEmptySubtitle =>
      'No songs to categorize in this dimension';

  @override
  String categorySongCount(int count) {
    return '$count songs';
  }

  @override
  String categorySearchHint(String label) {
    return 'Search $label…';
  }

  @override
  String categoryNoMatch(String label) {
    return 'No matching $label found';
  }
}
