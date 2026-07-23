import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// 设置页-语言分区标题
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @languageSimplifiedChinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get languageSimplifiedChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageSystem;

  /// No description provided for @themeTitle.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get themeTitle;

  /// No description provided for @themeModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get themeModeTitle;

  /// No description provided for @themeModeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择应用的主题外观'**
  String get themeModeSubtitle;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统'**
  String get themeSystem;

  /// No description provided for @commonConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get commonConfirm;

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get commonDelete;

  /// No description provided for @commonRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get commonRetry;

  /// No description provided for @commonLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在加载'**
  String get commonLoading;

  /// No description provided for @commonUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get commonUnknown;

  /// No description provided for @errorNetworkFailed.
  ///
  /// In zh, this message translates to:
  /// **'网络连接失败'**
  String get errorNetworkFailed;

  /// No description provided for @errorGeneric.
  ///
  /// In zh, this message translates to:
  /// **'出错了'**
  String get errorGeneric;

  /// No description provided for @deleteAlsoLocalFile.
  ///
  /// In zh, this message translates to:
  /// **'同时删除本地文件'**
  String get deleteAlsoLocalFile;

  /// No description provided for @deleteIrreversible.
  ///
  /// In zh, this message translates to:
  /// **'删除后无法恢复'**
  String get deleteIrreversible;

  /// No description provided for @navHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get navHome;

  /// No description provided for @navLibrary.
  ///
  /// In zh, this message translates to:
  /// **'曲库'**
  String get navLibrary;

  /// No description provided for @navPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'歌单'**
  String get navPlaylists;

  /// No description provided for @navSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navSettings;

  /// No description provided for @favoriteAdded.
  ///
  /// In zh, this message translates to:
  /// **'已添加到收藏'**
  String get favoriteAdded;

  /// No description provided for @favoriteRemoved.
  ///
  /// In zh, this message translates to:
  /// **'已取消收藏'**
  String get favoriteRemoved;

  /// No description provided for @favoriteAddFailed.
  ///
  /// In zh, this message translates to:
  /// **'收藏失败'**
  String get favoriteAddFailed;

  /// No description provided for @favoriteRemoveFailed.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏失败'**
  String get favoriteRemoveFailed;

  /// No description provided for @favorite.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get favorite;

  /// No description provided for @unfavorite.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get unfavorite;

  /// No description provided for @commonCreate.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get commonCreate;

  /// No description provided for @commonConfirmWithCount.
  ///
  /// In zh, this message translates to:
  /// **'确定({count})'**
  String commonConfirmWithCount(int count);

  /// No description provided for @commonLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get commonLoadFailed;

  /// No description provided for @commonLoadFailedDetail.
  ///
  /// In zh, this message translates to:
  /// **'加载失败: {error}'**
  String commonLoadFailedDetail(String error);

  /// No description provided for @clearSearch.
  ///
  /// In zh, this message translates to:
  /// **'清除搜索'**
  String get clearSearch;

  /// No description provided for @selectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get selectAll;

  /// No description provided for @selectFolder.
  ///
  /// In zh, this message translates to:
  /// **'选择文件夹'**
  String get selectFolder;

  /// No description provided for @more.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get more;

  /// No description provided for @expand.
  ///
  /// In zh, this message translates to:
  /// **'展开'**
  String get expand;

  /// No description provided for @collapse.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get collapse;

  /// No description provided for @songTypeLocal.
  ///
  /// In zh, this message translates to:
  /// **'本地'**
  String get songTypeLocal;

  /// No description provided for @songTypeRemote.
  ///
  /// In zh, this message translates to:
  /// **'网络'**
  String get songTypeRemote;

  /// No description provided for @songTypeRadio.
  ///
  /// In zh, this message translates to:
  /// **'电台'**
  String get songTypeRadio;

  /// No description provided for @filterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get filterAll;

  /// No description provided for @pickerSelectSongs.
  ///
  /// In zh, this message translates to:
  /// **'选择歌曲'**
  String get pickerSelectSongs;

  /// No description provided for @pickerSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索歌曲、艺术家或专辑'**
  String get pickerSearchHint;

  /// No description provided for @pickerNoMatchInFolder.
  ///
  /// In zh, this message translates to:
  /// **'该目录下未找到匹配的歌曲'**
  String get pickerNoMatchInFolder;

  /// No description provided for @pickerNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配的歌曲'**
  String get pickerNoMatch;

  /// No description provided for @pickerNoSongsInFolder.
  ///
  /// In zh, this message translates to:
  /// **'该目录下无歌曲'**
  String get pickerNoSongsInFolder;

  /// No description provided for @pickerNoSongs.
  ///
  /// In zh, this message translates to:
  /// **'暂无歌曲'**
  String get pickerNoSongs;

  /// No description provided for @pickerFetchListFailed.
  ///
  /// In zh, this message translates to:
  /// **'获取列表失败: {error}'**
  String pickerFetchListFailed(String error);

  /// No description provided for @pickerSelectingAll.
  ///
  /// In zh, this message translates to:
  /// **'正在选择全部...'**
  String get pickerSelectingAll;

  /// No description provided for @pickerDeselectAllWithCount.
  ///
  /// In zh, this message translates to:
  /// **'取消全选（已选 {count}）'**
  String pickerDeselectAllWithCount(int count);

  /// No description provided for @pickerSelectAllCount.
  ///
  /// In zh, this message translates to:
  /// **'全选 {count} 首'**
  String pickerSelectAllCount(int count);

  /// No description provided for @loadFailedTapRetry.
  ///
  /// In zh, this message translates to:
  /// **'加载失败，点击重试'**
  String get loadFailedTapRetry;

  /// No description provided for @loadedAllHint.
  ///
  /// In zh, this message translates to:
  /// **'— 已加载全部 —'**
  String get loadedAllHint;

  /// No description provided for @addToPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'添加到歌单'**
  String get addToPlaylist;

  /// No description provided for @newPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'新建歌单'**
  String get newPlaylist;

  /// No description provided for @playlistNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'歌单名称'**
  String get playlistNameLabel;

  /// No description provided for @noPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'暂无歌单'**
  String get noPlaylists;

  /// No description provided for @songsCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 首歌曲'**
  String songsCount(int count);

  /// No description provided for @addFailed.
  ///
  /// In zh, this message translates to:
  /// **'添加失败'**
  String get addFailed;

  /// No description provided for @addFailedDetail.
  ///
  /// In zh, this message translates to:
  /// **'添加失败: {error}'**
  String addFailedDetail(String error);

  /// No description provided for @addedToPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'已添加 {added} 首歌曲到「{name}」'**
  String addedToPlaylist(int added, String name);

  /// No description provided for @addedToPlaylistWithSkip.
  ///
  /// In zh, this message translates to:
  /// **'已添加 {added} 首到「{name}」，跳过 {skipped} 首'**
  String addedToPlaylistWithSkip(int added, String name, int skipped);

  /// No description provided for @createdPlaylistAdded.
  ///
  /// In zh, this message translates to:
  /// **'已创建歌单「{name}」并添加 {added} 首歌曲'**
  String createdPlaylistAdded(String name, int added);

  /// No description provided for @createdPlaylistWithSkip.
  ///
  /// In zh, this message translates to:
  /// **'已创建歌单「{name}」并添加 {added} 首，跳过 {skipped} 首'**
  String createdPlaylistWithSkip(String name, int added, int skipped);

  /// No description provided for @createPlaylistFailed.
  ///
  /// In zh, this message translates to:
  /// **'创建歌单失败'**
  String get createPlaylistFailed;

  /// No description provided for @createPlaylistFailedDetail.
  ///
  /// In zh, this message translates to:
  /// **'创建歌单失败: {error}'**
  String createPlaylistFailedDetail(String error);

  /// No description provided for @selectAllFiles.
  ///
  /// In zh, this message translates to:
  /// **'选择全部文件'**
  String get selectAllFiles;

  /// No description provided for @allSongs.
  ///
  /// In zh, this message translates to:
  /// **'全部歌曲'**
  String get allSongs;

  /// No description provided for @musicDirEmpty.
  ///
  /// In zh, this message translates to:
  /// **'音乐目录为空'**
  String get musicDirEmpty;

  /// No description provided for @dirEmpty.
  ///
  /// In zh, this message translates to:
  /// **'目录为空'**
  String get dirEmpty;

  /// No description provided for @loadDirFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载目录失败：{error}'**
  String loadDirFailed(String error);

  /// No description provided for @githubProxyDirect.
  ///
  /// In zh, this message translates to:
  /// **'直连 (不使用代理)'**
  String get githubProxyDirect;

  /// No description provided for @coreErrorConnectionTimeout.
  ///
  /// In zh, this message translates to:
  /// **'无法连接到 {target}（连接超时）。请检查：①后端服务是否运行 ②URL 与端口是否正确 ③若通过 ZeroTier/VPN 访问，请确认 VPN 已连接并启用「全局路由」'**
  String coreErrorConnectionTimeout(String target);

  /// No description provided for @coreErrorConnectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法连接到 {target}。请检查 URL 是否正确；若通过 ZeroTier/VPN 访问，请确认 VPN 已启用'**
  String coreErrorConnectionFailed(String target);

  /// No description provided for @coreErrorBadCertificate.
  ///
  /// In zh, this message translates to:
  /// **'证书验证失败'**
  String get coreErrorBadCertificate;

  /// No description provided for @coreErrorRequestCancelled.
  ///
  /// In zh, this message translates to:
  /// **'请求已取消'**
  String get coreErrorRequestCancelled;

  /// No description provided for @coreErrorUnknownNetwork.
  ///
  /// In zh, this message translates to:
  /// **'未知网络错误'**
  String get coreErrorUnknownNetwork;

  /// No description provided for @coreErrorNoResponse.
  ///
  /// In zh, this message translates to:
  /// **'服务器无响应'**
  String get coreErrorNoResponse;

  /// No description provided for @coreErrorRequestFailed.
  ///
  /// In zh, this message translates to:
  /// **'请求失败'**
  String get coreErrorRequestFailed;

  /// No description provided for @coreErrorUnauthorized.
  ///
  /// In zh, this message translates to:
  /// **'登录已过期，请重新登录'**
  String get coreErrorUnauthorized;

  /// No description provided for @coreErrorForbidden.
  ///
  /// In zh, this message translates to:
  /// **'没有权限访问'**
  String get coreErrorForbidden;

  /// No description provided for @coreErrorNotFound.
  ///
  /// In zh, this message translates to:
  /// **'请求的资源不存在'**
  String get coreErrorNotFound;

  /// No description provided for @coreErrorServer.
  ///
  /// In zh, this message translates to:
  /// **'服务器错误，请稍后重试'**
  String get coreErrorServer;

  /// No description provided for @coreNotFoundPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'页面未找到'**
  String get coreNotFoundPageTitle;

  /// No description provided for @coreBackToHome.
  ///
  /// In zh, this message translates to:
  /// **'返回首页'**
  String get coreBackToHome;

  /// No description provided for @coreNotificationChannel.
  ///
  /// In zh, this message translates to:
  /// **'Songloft 播放控制'**
  String get coreNotificationChannel;

  /// No description provided for @coreVersionDev.
  ///
  /// In zh, this message translates to:
  /// **'开发版本'**
  String get coreVersionDev;

  /// No description provided for @jspluginManagerTitle.
  ///
  /// In zh, this message translates to:
  /// **'JS 插件管理'**
  String get jspluginManagerTitle;

  /// No description provided for @jspluginManagerSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'管理已安装的 JS 插件'**
  String get jspluginManagerSubtitle;

  /// No description provided for @jspluginUploadPlugin.
  ///
  /// In zh, this message translates to:
  /// **'上传插件'**
  String get jspluginUploadPlugin;

  /// No description provided for @jspluginUpdateAll.
  ///
  /// In zh, this message translates to:
  /// **'全部更新'**
  String get jspluginUpdateAll;

  /// No description provided for @jspluginCleanupData.
  ///
  /// In zh, this message translates to:
  /// **'清理数据'**
  String get jspluginCleanupData;

  /// No description provided for @jspluginGithubProxy.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 代理'**
  String get jspluginGithubProxy;

  /// No description provided for @jspluginCustomProxy.
  ///
  /// In zh, this message translates to:
  /// **'自定义代理'**
  String get jspluginCustomProxy;

  /// No description provided for @jspluginCustomProxyEllipsis.
  ///
  /// In zh, this message translates to:
  /// **'自定义代理...'**
  String get jspluginCustomProxyEllipsis;

  /// No description provided for @jspluginCustomProxyWith.
  ///
  /// In zh, this message translates to:
  /// **'自定义: {proxy}'**
  String jspluginCustomProxyWith(String proxy);

  /// No description provided for @jspluginProxyHelper.
  ///
  /// In zh, this message translates to:
  /// **'输入代理地址，如 https://ghproxy.com/'**
  String get jspluginProxyHelper;

  /// No description provided for @jspluginOk.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get jspluginOk;

  /// No description provided for @jspluginCleanupOrphanTitle.
  ///
  /// In zh, this message translates to:
  /// **'清理孤儿数据'**
  String get jspluginCleanupOrphanTitle;

  /// No description provided for @jspluginCleanupOrphanContent.
  ///
  /// In zh, this message translates to:
  /// **'将清理已卸载插件遗留的持久化存储数据，此操作不可撤销。'**
  String get jspluginCleanupOrphanContent;

  /// No description provided for @jspluginCleanup.
  ///
  /// In zh, this message translates to:
  /// **'清理'**
  String get jspluginCleanup;

  /// No description provided for @jspluginCleanupFailed.
  ///
  /// In zh, this message translates to:
  /// **'清理失败: {error}'**
  String jspluginCleanupFailed(String error);

  /// No description provided for @jspluginNoInstalled.
  ///
  /// In zh, this message translates to:
  /// **'暂无已安装的 JS 插件'**
  String get jspluginNoInstalled;

  /// No description provided for @jspluginPickFileFailed.
  ///
  /// In zh, this message translates to:
  /// **'选择文件失败: {error}'**
  String jspluginPickFileFailed(String error);

  /// No description provided for @jspluginCannotReadFile.
  ///
  /// In zh, this message translates to:
  /// **'无法读取文件数据'**
  String get jspluginCannotReadFile;

  /// No description provided for @jspluginCannotGetPath.
  ///
  /// In zh, this message translates to:
  /// **'无法获取文件路径'**
  String get jspluginCannotGetPath;

  /// No description provided for @jspluginUploadSuccess.
  ///
  /// In zh, this message translates to:
  /// **'上传成功：{count} 个插件'**
  String jspluginUploadSuccess(int count);

  /// No description provided for @jspluginUploadPartial.
  ///
  /// In zh, this message translates to:
  /// **'成功 {success} 个，失败 {failed} 个\n{error}'**
  String jspluginUploadPartial(int success, int failed, String error);

  /// No description provided for @jspluginUploadFailed.
  ///
  /// In zh, this message translates to:
  /// **'上传失败: {error}'**
  String jspluginUploadFailed(String error);

  /// No description provided for @jspluginUploadDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'上传 JS 插件'**
  String get jspluginUploadDialogTitle;

  /// No description provided for @jspluginSelectFileSemantics.
  ///
  /// In zh, this message translates to:
  /// **'选择插件文件上传'**
  String get jspluginSelectFileSemantics;

  /// No description provided for @jspluginTapToSelectFile.
  ///
  /// In zh, this message translates to:
  /// **'点击选择文件'**
  String get jspluginTapToSelectFile;

  /// No description provided for @jspluginUploadHint.
  ///
  /// In zh, this message translates to:
  /// **'支持 .jsplugin.zip 格式；上传同名插件将覆盖现有版本（手动更新）'**
  String get jspluginUploadHint;

  /// No description provided for @jspluginRemove.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get jspluginRemove;

  /// No description provided for @jspluginUploading.
  ///
  /// In zh, this message translates to:
  /// **'上传中...'**
  String get jspluginUploading;

  /// No description provided for @jspluginUpload.
  ///
  /// In zh, this message translates to:
  /// **'上传'**
  String get jspluginUpload;

  /// No description provided for @jspluginOperationFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败: {error}'**
  String jspluginOperationFailed(String error);

  /// No description provided for @jspluginCannotOpenLink.
  ///
  /// In zh, this message translates to:
  /// **'无法打开链接: {url}'**
  String jspluginCannotOpenLink(String url);

  /// No description provided for @jspluginForceUpdateSuccess.
  ///
  /// In zh, this message translates to:
  /// **'插件已强制更新'**
  String get jspluginForceUpdateSuccess;

  /// No description provided for @jspluginForceUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'强制更新失败: {error}'**
  String jspluginForceUpdateFailed(String error);

  /// No description provided for @jspluginConfirmDelete.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get jspluginConfirmDelete;

  /// No description provided for @jspluginDeleteConfirmContent.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除插件 \"{name}\" 吗？'**
  String jspluginDeleteConfirmContent(String name);

  /// No description provided for @jspluginKeepData.
  ///
  /// In zh, this message translates to:
  /// **'保留插件数据'**
  String get jspluginKeepData;

  /// No description provided for @jspluginKeepDataSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'保留文件存储数据，方便日后重装'**
  String get jspluginKeepDataSubtitle;

  /// No description provided for @jspluginDeleted.
  ///
  /// In zh, this message translates to:
  /// **'插件已删除'**
  String get jspluginDeleted;

  /// No description provided for @jspluginDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败: {error}'**
  String jspluginDeleteFailed(String error);

  /// No description provided for @jspluginAuthor.
  ///
  /// In zh, this message translates to:
  /// **'作者: {author}'**
  String jspluginAuthor(String author);

  /// No description provided for @jspluginOpenHomepageSemantics.
  ///
  /// In zh, this message translates to:
  /// **'打开插件主页'**
  String get jspluginOpenHomepageSemantics;

  /// No description provided for @jspluginStatusError.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get jspluginStatusError;

  /// No description provided for @jspluginStatusEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已启用'**
  String get jspluginStatusEnabled;

  /// No description provided for @jspluginStatusDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已禁用'**
  String get jspluginStatusDisabled;

  /// No description provided for @jspluginMoreActions.
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get jspluginMoreActions;

  /// No description provided for @jspluginOpenHomepage.
  ///
  /// In zh, this message translates to:
  /// **'打开主页'**
  String get jspluginOpenHomepage;

  /// No description provided for @jspluginKeepAlive.
  ///
  /// In zh, this message translates to:
  /// **'常驻运行'**
  String get jspluginKeepAlive;

  /// No description provided for @jspluginCancelKeepAlive.
  ///
  /// In zh, this message translates to:
  /// **'取消常驻运行'**
  String get jspluginCancelKeepAlive;

  /// No description provided for @jspluginCheckUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get jspluginCheckUpdate;

  /// No description provided for @jspluginForceUpdate.
  ///
  /// In zh, this message translates to:
  /// **'强制更新'**
  String get jspluginForceUpdate;

  /// No description provided for @jspluginUpdate.
  ///
  /// In zh, this message translates to:
  /// **'更新'**
  String get jspluginUpdate;

  /// No description provided for @jspluginCheckUpdateTimeout.
  ///
  /// In zh, this message translates to:
  /// **'检查更新超时，请尝试切换代理后重试'**
  String get jspluginCheckUpdateTimeout;

  /// No description provided for @jspluginCheckUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败: {error}'**
  String jspluginCheckUpdateFailed(String error);

  /// No description provided for @jspluginUpdateSuccess.
  ///
  /// In zh, this message translates to:
  /// **'插件更新成功'**
  String get jspluginUpdateSuccess;

  /// No description provided for @jspluginUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'更新失败: {error}'**
  String jspluginUpdateFailed(String error);

  /// No description provided for @jspluginUpdateTimeout.
  ///
  /// In zh, this message translates to:
  /// **'更新超时，请重试'**
  String get jspluginUpdateTimeout;

  /// No description provided for @jspluginUpdateDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'更新插件 - {name}'**
  String jspluginUpdateDialogTitle(String name);

  /// No description provided for @jspluginCheckingUpdate.
  ///
  /// In zh, this message translates to:
  /// **'正在检查更新...'**
  String get jspluginCheckingUpdate;

  /// No description provided for @jspluginDownloadingUpdate.
  ///
  /// In zh, this message translates to:
  /// **'正在下载并更新插件...'**
  String get jspluginDownloadingUpdate;

  /// No description provided for @jspluginDoNotCloseDialog.
  ///
  /// In zh, this message translates to:
  /// **'请勿关闭此对话框'**
  String get jspluginDoNotCloseDialog;

  /// No description provided for @jspluginAlreadyLatest.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get jspluginAlreadyLatest;

  /// No description provided for @jspluginCurrentVersion.
  ///
  /// In zh, this message translates to:
  /// **'当前版本: {version}'**
  String jspluginCurrentVersion(String version);

  /// No description provided for @jspluginNewVersionFound.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本'**
  String get jspluginNewVersionFound;

  /// No description provided for @jspluginRecheck.
  ///
  /// In zh, this message translates to:
  /// **'重新检查'**
  String get jspluginRecheck;

  /// No description provided for @jspluginUpdateNow.
  ///
  /// In zh, this message translates to:
  /// **'立即更新'**
  String get jspluginUpdateNow;

  /// No description provided for @jspluginClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get jspluginClose;

  /// No description provided for @jspluginBatchUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'批量更新失败: {error}'**
  String jspluginBatchUpdateFailed(String error);

  /// No description provided for @jspluginBatchUpdateTimeout.
  ///
  /// In zh, this message translates to:
  /// **'批量更新超时，请重试'**
  String get jspluginBatchUpdateTimeout;

  /// No description provided for @jspluginBatchUpdating.
  ///
  /// In zh, this message translates to:
  /// **'正在检查并更新所有插件...'**
  String get jspluginBatchUpdating;

  /// No description provided for @jspluginStatUpdated.
  ///
  /// In zh, this message translates to:
  /// **'已更新'**
  String get jspluginStatUpdated;

  /// No description provided for @jspluginStatFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get jspluginStatFailed;

  /// No description provided for @jspluginStatSkipped.
  ///
  /// In zh, this message translates to:
  /// **'无需更新'**
  String get jspluginStatSkipped;

  /// No description provided for @jspluginUpdateFailedShort.
  ///
  /// In zh, this message translates to:
  /// **'更新失败'**
  String get jspluginUpdateFailedShort;

  /// No description provided for @jspluginVersionLatest.
  ///
  /// In zh, this message translates to:
  /// **'v{version} 已是最新'**
  String jspluginVersionLatest(String version);

  /// No description provided for @jspluginStartUpdate.
  ///
  /// In zh, this message translates to:
  /// **'开始更新'**
  String get jspluginStartUpdate;

  /// No description provided for @jspluginForceUpdateDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'强制更新 - {name}'**
  String jspluginForceUpdateDialogTitle(String name);

  /// No description provided for @jspluginForceUpdateContent.
  ///
  /// In zh, this message translates to:
  /// **'将忽略版本检查，重新下载并安装插件。'**
  String get jspluginForceUpdateContent;

  /// No description provided for @jspluginConfirmUpdate.
  ///
  /// In zh, this message translates to:
  /// **'确认更新'**
  String get jspluginConfirmUpdate;

  /// No description provided for @jspluginStoreTitle.
  ///
  /// In zh, this message translates to:
  /// **'插件商店'**
  String get jspluginStoreTitle;

  /// No description provided for @jspluginRefreshList.
  ///
  /// In zh, this message translates to:
  /// **'刷新插件列表'**
  String get jspluginRefreshList;

  /// No description provided for @jspluginManageRegistries.
  ///
  /// In zh, this message translates to:
  /// **'管理订阅源'**
  String get jspluginManageRegistries;

  /// No description provided for @jspluginNoRegistries.
  ///
  /// In zh, this message translates to:
  /// **'还没有添加订阅源'**
  String get jspluginNoRegistries;

  /// No description provided for @jspluginNoRegistriesHint.
  ///
  /// In zh, this message translates to:
  /// **'添加订阅源后即可浏览和安装插件'**
  String get jspluginNoRegistriesHint;

  /// No description provided for @jspluginAddRegistry.
  ///
  /// In zh, this message translates to:
  /// **'添加订阅源'**
  String get jspluginAddRegistry;

  /// No description provided for @jspluginRegistry.
  ///
  /// In zh, this message translates to:
  /// **'订阅源'**
  String get jspluginRegistry;

  /// No description provided for @jspluginOfficial.
  ///
  /// In zh, this message translates to:
  /// **'官方'**
  String get jspluginOfficial;

  /// No description provided for @jspluginAllSources.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get jspluginAllSources;

  /// No description provided for @jspluginAutoUpdate.
  ///
  /// In zh, this message translates to:
  /// **'自动更新插件'**
  String get jspluginAutoUpdate;

  /// No description provided for @jspluginAutoUpdateHint.
  ///
  /// In zh, this message translates to:
  /// **'后台定时检查并更新已安装的插件'**
  String get jspluginAutoUpdateHint;

  /// No description provided for @jspluginSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索插件...'**
  String get jspluginSearchHint;

  /// No description provided for @jspluginLoadingList.
  ///
  /// In zh, this message translates to:
  /// **'正在加载插件列表…'**
  String get jspluginLoadingList;

  /// No description provided for @jspluginNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'没有找到匹配的插件'**
  String get jspluginNoMatch;

  /// No description provided for @jspluginRegistryEmpty.
  ///
  /// In zh, this message translates to:
  /// **'该订阅源暂无插件'**
  String get jspluginRegistryEmpty;

  /// No description provided for @jspluginPrevPage.
  ///
  /// In zh, this message translates to:
  /// **'上一页'**
  String get jspluginPrevPage;

  /// No description provided for @jspluginNextPage.
  ///
  /// In zh, this message translates to:
  /// **'下一页'**
  String get jspluginNextPage;

  /// No description provided for @jspluginInstallFailed.
  ///
  /// In zh, this message translates to:
  /// **'安装失败: {error}'**
  String jspluginInstallFailed(String error);

  /// No description provided for @jspluginReinstall.
  ///
  /// In zh, this message translates to:
  /// **'重新安装'**
  String get jspluginReinstall;

  /// No description provided for @jspluginUpdateTo.
  ///
  /// In zh, this message translates to:
  /// **'更新至 v{version}'**
  String jspluginUpdateTo(String version);

  /// No description provided for @jspluginInstall.
  ///
  /// In zh, this message translates to:
  /// **'安装'**
  String get jspluginInstall;

  /// No description provided for @jspluginSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败: {error}'**
  String jspluginSaveFailed(String error);

  /// No description provided for @jspluginEditRegistry.
  ///
  /// In zh, this message translates to:
  /// **'编辑订阅源'**
  String get jspluginEditRegistry;

  /// No description provided for @jspluginDeleteRegistry.
  ///
  /// In zh, this message translates to:
  /// **'删除订阅源'**
  String get jspluginDeleteRegistry;

  /// No description provided for @jspluginNameOptional.
  ///
  /// In zh, this message translates to:
  /// **'名称（可选）'**
  String get jspluginNameOptional;

  /// No description provided for @jspluginRegistryNameHint.
  ///
  /// In zh, this message translates to:
  /// **'我的插件源'**
  String get jspluginRegistryNameHint;

  /// No description provided for @jspluginTokenOptional.
  ///
  /// In zh, this message translates to:
  /// **'Token（可选）'**
  String get jspluginTokenOptional;

  /// No description provided for @jspluginSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get jspluginSave;

  /// No description provided for @jspluginAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get jspluginAdd;

  /// No description provided for @jspluginAuthConfigured.
  ///
  /// In zh, this message translates to:
  /// **'已配置认证'**
  String get jspluginAuthConfigured;

  /// No description provided for @jspluginGridTitle.
  ///
  /// In zh, this message translates to:
  /// **'JS 插件'**
  String get jspluginGridTitle;

  /// No description provided for @jspluginCleanupDone.
  ///
  /// In zh, this message translates to:
  /// **'清理完成'**
  String get jspluginCleanupDone;

  /// No description provided for @libraryPlayFailed.
  ///
  /// In zh, this message translates to:
  /// **'播放失败'**
  String get libraryPlayFailed;

  /// No description provided for @libraryNoPlayableSongs.
  ///
  /// In zh, this message translates to:
  /// **'没有可播放的歌曲'**
  String get libraryNoPlayableSongs;

  /// No description provided for @libraryPlayingAllSongs.
  ///
  /// In zh, this message translates to:
  /// **'播放全部 {total} 首歌曲'**
  String libraryPlayingAllSongs(int total);

  /// No description provided for @libraryDismissError.
  ///
  /// In zh, this message translates to:
  /// **'关闭提示'**
  String get libraryDismissError;

  /// No description provided for @libraryExitSelection.
  ///
  /// In zh, this message translates to:
  /// **'退出多选'**
  String get libraryExitSelection;

  /// No description provided for @librarySelectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已选择 {count} 首'**
  String librarySelectedCount(int count);

  /// No description provided for @libraryDeleteWithCount.
  ///
  /// In zh, this message translates to:
  /// **'删除({count})'**
  String libraryDeleteWithCount(int count);

  /// No description provided for @libraryDeselectAll.
  ///
  /// In zh, this message translates to:
  /// **'取消全选'**
  String get libraryDeselectAll;

  /// No description provided for @libraryTitle.
  ///
  /// In zh, this message translates to:
  /// **'曲库'**
  String get libraryTitle;

  /// No description provided for @libraryPlayAll.
  ///
  /// In zh, this message translates to:
  /// **'播放全部'**
  String get libraryPlayAll;

  /// No description provided for @librarySort.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get librarySort;

  /// No description provided for @librarySortAddedAt.
  ///
  /// In zh, this message translates to:
  /// **'最近加入'**
  String get librarySortAddedAt;

  /// No description provided for @librarySortFileTime.
  ///
  /// In zh, this message translates to:
  /// **'文件时间'**
  String get librarySortFileTime;

  /// No description provided for @libraryColumnTitle.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get libraryColumnTitle;

  /// No description provided for @libraryColumnArtist.
  ///
  /// In zh, this message translates to:
  /// **'艺术家'**
  String get libraryColumnArtist;

  /// No description provided for @libraryColumnAlbum.
  ///
  /// In zh, this message translates to:
  /// **'专辑'**
  String get libraryColumnAlbum;

  /// No description provided for @libraryColumnType.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get libraryColumnType;

  /// No description provided for @libraryColumnDuration.
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get libraryColumnDuration;

  /// No description provided for @librarySelectMode.
  ///
  /// In zh, this message translates to:
  /// **'多选'**
  String get librarySelectMode;

  /// No description provided for @libraryMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get libraryMore;

  /// No description provided for @libraryAddRemoteSong.
  ///
  /// In zh, this message translates to:
  /// **'添加网络歌曲'**
  String get libraryAddRemoteSong;

  /// No description provided for @libraryAddRadio.
  ///
  /// In zh, this message translates to:
  /// **'添加电台'**
  String get libraryAddRadio;

  /// No description provided for @libraryHideHiddenSongs.
  ///
  /// In zh, this message translates to:
  /// **'隐藏已隐藏歌曲'**
  String get libraryHideHiddenSongs;

  /// No description provided for @libraryShowHiddenSongs.
  ///
  /// In zh, this message translates to:
  /// **'显示隐藏歌曲'**
  String get libraryShowHiddenSongs;

  /// No description provided for @libraryCleanInvalidSongs.
  ///
  /// In zh, this message translates to:
  /// **'清理无效歌曲'**
  String get libraryCleanInvalidSongs;

  /// No description provided for @librarySearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索歌曲...'**
  String get librarySearchHint;

  /// No description provided for @libraryNoMatchingSongs.
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配的歌曲'**
  String get libraryNoMatchingSongs;

  /// No description provided for @libraryEmpty.
  ///
  /// In zh, this message translates to:
  /// **'曲库为空'**
  String get libraryEmpty;

  /// No description provided for @libraryTryOtherKeywords.
  ///
  /// In zh, this message translates to:
  /// **'尝试其他关键词'**
  String get libraryTryOtherKeywords;

  /// No description provided for @libraryEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'添加一些歌曲开始吧'**
  String get libraryEmptyHint;

  /// No description provided for @libraryDeleteConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get libraryDeleteConfirmTitle;

  /// No description provided for @libraryDeleteConfirmContent.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除这首歌曲吗？'**
  String get libraryDeleteConfirmContent;

  /// No description provided for @libraryCleanTitle.
  ///
  /// In zh, this message translates to:
  /// **'清理歌曲'**
  String get libraryCleanTitle;

  /// No description provided for @libraryCleanContent.
  ///
  /// In zh, this message translates to:
  /// **'将清理无效的歌曲记录（如文件已删除的本地歌曲）。'**
  String get libraryCleanContent;

  /// No description provided for @libraryCleanedCount.
  ///
  /// In zh, this message translates to:
  /// **'已清理 {count} 首无效歌曲'**
  String libraryCleanedCount(int count);

  /// No description provided for @libraryClean.
  ///
  /// In zh, this message translates to:
  /// **'清理'**
  String get libraryClean;

  /// No description provided for @libraryBatchDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'批量删除'**
  String get libraryBatchDeleteTitle;

  /// No description provided for @libraryBatchDeleteContent.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除选中的 {count} 首歌曲吗？'**
  String libraryBatchDeleteContent(int count);

  /// No description provided for @libraryDeletedCount.
  ///
  /// In zh, this message translates to:
  /// **'已删除 {count} 首歌曲'**
  String libraryDeletedCount(int count);

  /// No description provided for @libraryDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败'**
  String get libraryDeleteFailed;

  /// No description provided for @librarySongCount.
  ///
  /// In zh, this message translates to:
  /// **'{count}首'**
  String librarySongCount(int count);

  /// No description provided for @libraryUnknownArtist.
  ///
  /// In zh, this message translates to:
  /// **'未知艺术家'**
  String get libraryUnknownArtist;

  /// No description provided for @libraryUnknownAlbum.
  ///
  /// In zh, this message translates to:
  /// **'未知专辑'**
  String get libraryUnknownAlbum;

  /// No description provided for @libraryPlay.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get libraryPlay;

  /// No description provided for @libraryEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get libraryEdit;

  /// No description provided for @libraryCustomizeViews.
  ///
  /// In zh, this message translates to:
  /// **'自定义视图'**
  String get libraryCustomizeViews;

  /// No description provided for @libraryCustomizeViewsTooltip.
  ///
  /// In zh, this message translates to:
  /// **'自定义显示的视图与顺序'**
  String get libraryCustomizeViewsTooltip;

  /// No description provided for @libraryViewsMinOne.
  ///
  /// In zh, this message translates to:
  /// **'至少保留一个可见视图'**
  String get libraryViewsMinOne;

  /// No description provided for @libraryViewPlaylistAll.
  ///
  /// In zh, this message translates to:
  /// **'全部歌单'**
  String get libraryViewPlaylistAll;

  /// No description provided for @categorySongsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'该分类下暂无歌曲'**
  String get categorySongsEmpty;

  /// No description provided for @libraryViewGroupSongs.
  ///
  /// In zh, this message translates to:
  /// **'歌曲'**
  String get libraryViewGroupSongs;

  /// No description provided for @libraryViewGroupCategories.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get libraryViewGroupCategories;

  /// No description provided for @libraryViewGroupPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'歌单'**
  String get libraryViewGroupPlaylists;

  /// No description provided for @libraryViewGroupMoveUp.
  ///
  /// In zh, this message translates to:
  /// **'上移分组'**
  String get libraryViewGroupMoveUp;

  /// No description provided for @libraryViewGroupMoveDown.
  ///
  /// In zh, this message translates to:
  /// **'下移分组'**
  String get libraryViewGroupMoveDown;

  /// No description provided for @libraryEditLocalSong.
  ///
  /// In zh, this message translates to:
  /// **'编辑本地歌曲'**
  String get libraryEditLocalSong;

  /// No description provided for @libraryEditRadio.
  ///
  /// In zh, this message translates to:
  /// **'编辑电台'**
  String get libraryEditRadio;

  /// No description provided for @libraryEditRemoteSong.
  ///
  /// In zh, this message translates to:
  /// **'编辑网络歌曲'**
  String get libraryEditRemoteSong;

  /// No description provided for @librarySave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get librarySave;

  /// No description provided for @libraryFileInfoReadonly.
  ///
  /// In zh, this message translates to:
  /// **'文件信息（只读）'**
  String get libraryFileInfoReadonly;

  /// No description provided for @libraryServerEndpointReadonly.
  ///
  /// In zh, this message translates to:
  /// **'服务端端点（只读）'**
  String get libraryServerEndpointReadonly;

  /// No description provided for @libraryReadonlyFile.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get libraryReadonlyFile;

  /// No description provided for @libraryReadonlyCover.
  ///
  /// In zh, this message translates to:
  /// **'封面'**
  String get libraryReadonlyCover;

  /// No description provided for @libraryReadonlyLyric.
  ///
  /// In zh, this message translates to:
  /// **'歌词'**
  String get libraryReadonlyLyric;

  /// No description provided for @libraryEditTitleLabel.
  ///
  /// In zh, this message translates to:
  /// **'标题 *'**
  String get libraryEditTitleLabel;

  /// No description provided for @libraryEditTitleRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入标题'**
  String get libraryEditTitleRequired;

  /// No description provided for @libraryEditArtistHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入艺术家'**
  String get libraryEditArtistHint;

  /// No description provided for @libraryEditAlbumHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入专辑'**
  String get libraryEditAlbumHint;

  /// No description provided for @libraryRenameFileTitle.
  ///
  /// In zh, this message translates to:
  /// **'同步重命名文件'**
  String get libraryRenameFileTitle;

  /// No description provided for @libraryRenameFileSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'按新标题重命名本地音频文件，同时写入 title 标签'**
  String get libraryRenameFileSubtitle;

  /// No description provided for @libraryVideoToggleTitle.
  ///
  /// In zh, this message translates to:
  /// **'视频内容'**
  String get libraryVideoToggleTitle;

  /// No description provided for @libraryVideoToggleSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'此链接含视频画面，开启后播放页渲染画面、投屏按视频推送'**
  String get libraryVideoToggleSubtitle;

  /// No description provided for @libraryEditSourceUrlLabel.
  ///
  /// In zh, this message translates to:
  /// **'源音频 URL *'**
  String get libraryEditSourceUrlLabel;

  /// No description provided for @libraryEditUrlLabel.
  ///
  /// In zh, this message translates to:
  /// **'URL *'**
  String get libraryEditUrlLabel;

  /// No description provided for @libraryEditUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入音频链接'**
  String get libraryEditUrlHint;

  /// No description provided for @libraryEditUrlRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入 URL'**
  String get libraryEditUrlRequired;

  /// No description provided for @libraryEditUrlInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的 URL'**
  String get libraryEditUrlInvalid;

  /// No description provided for @libraryEditSourceCoverUrlLabel.
  ///
  /// In zh, this message translates to:
  /// **'源封面 URL'**
  String get libraryEditSourceCoverUrlLabel;

  /// No description provided for @libraryEditCoverUrlLabel.
  ///
  /// In zh, this message translates to:
  /// **'封面 URL'**
  String get libraryEditCoverUrlLabel;

  /// No description provided for @libraryEditCoverUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入封面图片链接'**
  String get libraryEditCoverUrlHint;

  /// No description provided for @libraryEditDurationLabel.
  ///
  /// In zh, this message translates to:
  /// **'时长（秒）'**
  String get libraryEditDurationLabel;

  /// No description provided for @libraryEditDurationHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入时长'**
  String get libraryEditDurationHint;

  /// No description provided for @libraryEditLyricRemoteUrlLabel.
  ///
  /// In zh, this message translates to:
  /// **'歌词远程 URL'**
  String get libraryEditLyricRemoteUrlLabel;

  /// No description provided for @libraryEditLyricUrlLabel.
  ///
  /// In zh, this message translates to:
  /// **'歌词 URL'**
  String get libraryEditLyricUrlLabel;

  /// No description provided for @libraryEditLyricUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入歌词接口链接'**
  String get libraryEditLyricUrlHint;

  /// No description provided for @libraryCoverPreview.
  ///
  /// In zh, this message translates to:
  /// **'封面预览：'**
  String get libraryCoverPreview;

  /// No description provided for @libraryCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get libraryCopied;

  /// No description provided for @libraryCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get libraryCopy;

  /// No description provided for @librarySaveSuccess.
  ///
  /// In zh, this message translates to:
  /// **'保存成功'**
  String get librarySaveSuccess;

  /// No description provided for @libraryAddSuccess.
  ///
  /// In zh, this message translates to:
  /// **'添加成功'**
  String get libraryAddSuccess;

  /// No description provided for @libraryOperationFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败: {error}'**
  String libraryOperationFailed(String error);

  /// No description provided for @libraryErrorBadRequest.
  ///
  /// In zh, this message translates to:
  /// **'请求参数错误'**
  String get libraryErrorBadRequest;

  /// No description provided for @libraryErrorUnauthorized.
  ///
  /// In zh, this message translates to:
  /// **'未授权，请重新登录'**
  String get libraryErrorUnauthorized;

  /// No description provided for @libraryErrorForbidden.
  ///
  /// In zh, this message translates to:
  /// **'没有权限执行此操作'**
  String get libraryErrorForbidden;

  /// No description provided for @libraryErrorNotFound.
  ///
  /// In zh, this message translates to:
  /// **'歌曲不存在'**
  String get libraryErrorNotFound;

  /// No description provided for @libraryErrorServer.
  ///
  /// In zh, this message translates to:
  /// **'服务器错误，请稍后重试'**
  String get libraryErrorServer;

  /// No description provided for @libraryErrorRequestFailed.
  ///
  /// In zh, this message translates to:
  /// **'请求失败：{code}'**
  String libraryErrorRequestFailed(int code);

  /// No description provided for @libraryErrorTimeout.
  ///
  /// In zh, this message translates to:
  /// **'网络连接超时，请检查网络'**
  String get libraryErrorTimeout;

  /// No description provided for @libraryErrorConnection.
  ///
  /// In zh, this message translates to:
  /// **'网络连接失败，请检查网络'**
  String get libraryErrorConnection;

  /// No description provided for @libraryErrorNetwork.
  ///
  /// In zh, this message translates to:
  /// **'网络错误：{message}'**
  String libraryErrorNetwork(String message);

  /// No description provided for @libraryFavoritePlaylistNotFound.
  ///
  /// In zh, this message translates to:
  /// **'收藏歌单不存在'**
  String get libraryFavoritePlaylistNotFound;

  /// No description provided for @libraryRadioFavoritePlaylistNotFound.
  ///
  /// In zh, this message translates to:
  /// **'电台收藏歌单不存在'**
  String get libraryRadioFavoritePlaylistNotFound;

  /// No description provided for @homeEmptyPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'暂无歌单'**
  String get homeEmptyPlaylists;

  /// No description provided for @homeEmptyPlaylistsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'创建你的第一个歌单开始收藏音乐'**
  String get homeEmptyPlaylistsSubtitle;

  /// No description provided for @homeCreatePlaylist.
  ///
  /// In zh, this message translates to:
  /// **'创建歌单'**
  String get homeCreatePlaylist;

  /// No description provided for @homeMyPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'我的歌单'**
  String get homeMyPlaylists;

  /// No description provided for @homeViewAll.
  ///
  /// In zh, this message translates to:
  /// **'查看全部'**
  String get homeViewAll;

  /// No description provided for @homeMyRadios.
  ///
  /// In zh, this message translates to:
  /// **'我的电台'**
  String get homeMyRadios;

  /// No description provided for @homeGreetingLateNight.
  ///
  /// In zh, this message translates to:
  /// **'夜深了'**
  String get homeGreetingLateNight;

  /// No description provided for @homeGreetingMorning.
  ///
  /// In zh, this message translates to:
  /// **'早上好'**
  String get homeGreetingMorning;

  /// No description provided for @homeGreetingNoon.
  ///
  /// In zh, this message translates to:
  /// **'中午好'**
  String get homeGreetingNoon;

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In zh, this message translates to:
  /// **'下午好'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In zh, this message translates to:
  /// **'晚上好'**
  String get homeGreetingEvening;

  /// No description provided for @homeTvGreetingLateNight.
  ///
  /// In zh, this message translates to:
  /// **'夜深了，听点音乐吧'**
  String get homeTvGreetingLateNight;

  /// No description provided for @homeOpenPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'打开歌单'**
  String get homeOpenPlaylist;

  /// No description provided for @homeOpenPlaylistNamed.
  ///
  /// In zh, this message translates to:
  /// **'打开歌单 {name}'**
  String homeOpenPlaylistNamed(String name);

  /// No description provided for @homeSongCountShort.
  ///
  /// In zh, this message translates to:
  /// **'{count} 首'**
  String homeSongCountShort(int count);

  /// No description provided for @homeSongCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 首歌曲'**
  String homeSongCount(int count);

  /// No description provided for @homeStatPlaylistsCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 歌单'**
  String homeStatPlaylistsCount(int count);

  /// No description provided for @homeStatRadiosCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 电台'**
  String homeStatRadiosCount(int count);

  /// No description provided for @homeStatTotal.
  ///
  /// In zh, this message translates to:
  /// **'总计'**
  String get homeStatTotal;

  /// No description provided for @homeTvLocalMusic.
  ///
  /// In zh, this message translates to:
  /// **'本地音乐'**
  String get homeTvLocalMusic;

  /// No description provided for @homeTvPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'播放列表'**
  String get homeTvPlaylist;

  /// No description provided for @homeTvEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'使用快捷导航浏览本地音乐'**
  String get homeTvEmptySubtitle;

  /// No description provided for @homeHeroSemanticLabel.
  ///
  /// In zh, this message translates to:
  /// **'{name} - {count} 首歌曲'**
  String homeHeroSemanticLabel(String name, int count);

  /// No description provided for @homeNowPlaying.
  ///
  /// In zh, this message translates to:
  /// **'正在播放'**
  String get homeNowPlaying;

  /// No description provided for @homeRecommendedPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'推荐歌单'**
  String get homeRecommendedPlaylist;

  /// No description provided for @homePlayNow.
  ///
  /// In zh, this message translates to:
  /// **'立即播放'**
  String get homePlayNow;

  /// No description provided for @homePluginLoadTimeout.
  ///
  /// In zh, this message translates to:
  /// **'页面加载超时，请检查插件是否可用或网络连接'**
  String get homePluginLoadTimeout;

  /// No description provided for @homePluginClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get homePluginClose;

  /// No description provided for @homePluginOpenInBrowser.
  ///
  /// In zh, this message translates to:
  /// **'在浏览器中打开'**
  String get homePluginOpenInBrowser;

  /// No description provided for @homePluginLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'页面加载失败'**
  String get homePluginLoadFailed;

  /// No description provided for @homePluginLoadFailedHttp.
  ///
  /// In zh, this message translates to:
  /// **'页面加载失败: HTTP {status}{detail}'**
  String homePluginLoadFailedHttp(String status, String detail);

  /// No description provided for @homePluginUnknownError.
  ///
  /// In zh, this message translates to:
  /// **'未知错误'**
  String get homePluginUnknownError;

  /// No description provided for @homePluginWebOpenInNewTab.
  ///
  /// In zh, this message translates to:
  /// **'Web 平台请在新标签页中打开插件'**
  String get homePluginWebOpenInNewTab;

  /// No description provided for @authLogin.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get authLogin;

  /// No description provided for @authTvSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'使用您的账号登录 Songloft'**
  String get authTvSubtitle;

  /// No description provided for @authLoginToContinue.
  ///
  /// In zh, this message translates to:
  /// **'登录以继续'**
  String get authLoginToContinue;

  /// No description provided for @authTagline.
  ///
  /// In zh, this message translates to:
  /// **'自托管本地音乐服务'**
  String get authTagline;

  /// No description provided for @authUsername.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get authUsername;

  /// No description provided for @authUsernameHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名'**
  String get authUsernameHint;

  /// No description provided for @authUsernameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名'**
  String get authUsernameRequired;

  /// No description provided for @authPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get authPassword;

  /// No description provided for @authPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get authPasswordHint;

  /// No description provided for @authPasswordRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get authPasswordRequired;

  /// No description provided for @authShowPassword.
  ///
  /// In zh, this message translates to:
  /// **'显示密码'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In zh, this message translates to:
  /// **'隐藏密码'**
  String get authHidePassword;

  /// No description provided for @authApiUrl.
  ///
  /// In zh, this message translates to:
  /// **'API 地址'**
  String get authApiUrl;

  /// No description provided for @authApiUrlRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入 API 地址'**
  String get authApiUrlRequired;

  /// No description provided for @authInvalidUrl.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的 URL（以 http:// 或 https:// 开头）'**
  String get authInvalidUrl;

  /// No description provided for @authServer.
  ///
  /// In zh, this message translates to:
  /// **'服务器'**
  String get authServer;

  /// No description provided for @authTvPressToLogin.
  ///
  /// In zh, this message translates to:
  /// **'按确认键登录'**
  String get authTvPressToLogin;

  /// No description provided for @authUseLocalMode.
  ///
  /// In zh, this message translates to:
  /// **'使用本地模式'**
  String get authUseLocalMode;

  /// No description provided for @authCopyright.
  ///
  /// In zh, this message translates to:
  /// **'© {year} Songloft'**
  String authCopyright(int year);

  /// No description provided for @authAutoLoggingIn.
  ///
  /// In zh, this message translates to:
  /// **'正在自动登录…'**
  String get authAutoLoggingIn;

  /// No description provided for @authStartingLocalBackend.
  ///
  /// In zh, this message translates to:
  /// **'正在启动本地后端…'**
  String get authStartingLocalBackend;

  /// No description provided for @authPreparing.
  ///
  /// In zh, this message translates to:
  /// **'正在准备…'**
  String get authPreparing;

  /// No description provided for @authConnecting.
  ///
  /// In zh, this message translates to:
  /// **'正在连接…'**
  String get authConnecting;

  /// No description provided for @authLoggingIn.
  ///
  /// In zh, this message translates to:
  /// **'正在登录…'**
  String get authLoggingIn;

  /// No description provided for @authAutoLoginFailed.
  ///
  /// In zh, this message translates to:
  /// **'自动登录失败：{error}'**
  String authAutoLoginFailed(String error);

  /// No description provided for @authLocalModeFailed.
  ///
  /// In zh, this message translates to:
  /// **'本地模式启动失败：{error}'**
  String authLocalModeFailed(String error);

  /// No description provided for @authLoginFailed.
  ///
  /// In zh, this message translates to:
  /// **'登录失败：{error}'**
  String authLoginFailed(String error);

  /// No description provided for @authSessionExpired.
  ///
  /// In zh, this message translates to:
  /// **'登录已过期，请重新登录'**
  String get authSessionExpired;

  /// No description provided for @authNoRefreshToken.
  ///
  /// In zh, this message translates to:
  /// **'没有可用的刷新令牌'**
  String get authNoRefreshToken;

  /// No description provided for @dlnaCast.
  ///
  /// In zh, this message translates to:
  /// **'投屏'**
  String get dlnaCast;

  /// No description provided for @dlnaCasting.
  ///
  /// In zh, this message translates to:
  /// **'投屏中'**
  String get dlnaCasting;

  /// No description provided for @dlnaDisconnect.
  ///
  /// In zh, this message translates to:
  /// **'断开'**
  String get dlnaDisconnect;

  /// No description provided for @dlnaConnected.
  ///
  /// In zh, this message translates to:
  /// **'已连接'**
  String get dlnaConnected;

  /// No description provided for @dlnaSearching.
  ///
  /// In zh, this message translates to:
  /// **'正在搜索设备...'**
  String get dlnaSearching;

  /// No description provided for @dlnaSearchingLan.
  ///
  /// In zh, this message translates to:
  /// **'正在搜索局域网设备...'**
  String get dlnaSearchingLan;

  /// No description provided for @dlnaNoDevices.
  ///
  /// In zh, this message translates to:
  /// **'未发现 DLNA 设备'**
  String get dlnaNoDevices;

  /// No description provided for @startupStarting.
  ///
  /// In zh, this message translates to:
  /// **'正在启动…'**
  String get startupStarting;

  /// No description provided for @startupStartingLocalBackend.
  ///
  /// In zh, this message translates to:
  /// **'正在启动本地后端…'**
  String get startupStartingLocalBackend;

  /// No description provided for @startupConnectingLocalBackend.
  ///
  /// In zh, this message translates to:
  /// **'正在连接本地后端…'**
  String get startupConnectingLocalBackend;

  /// No description provided for @startupConnectingTo.
  ///
  /// In zh, this message translates to:
  /// **'正在连接 {target}…'**
  String startupConnectingTo(String target);

  /// No description provided for @playerModeOrder.
  ///
  /// In zh, this message translates to:
  /// **'顺序播放'**
  String get playerModeOrder;

  /// No description provided for @playerModeLoop.
  ///
  /// In zh, this message translates to:
  /// **'列表循环'**
  String get playerModeLoop;

  /// No description provided for @playerModeSingle.
  ///
  /// In zh, this message translates to:
  /// **'单曲循环'**
  String get playerModeSingle;

  /// No description provided for @playerModeRandom.
  ///
  /// In zh, this message translates to:
  /// **'随机播放'**
  String get playerModeRandom;

  /// No description provided for @playerModeSinglePlay.
  ///
  /// In zh, this message translates to:
  /// **'单曲播放'**
  String get playerModeSinglePlay;

  /// No description provided for @playerClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get playerClose;

  /// No description provided for @playerSleepTimer.
  ///
  /// In zh, this message translates to:
  /// **'睡眠定时'**
  String get playerSleepTimer;

  /// No description provided for @playerSleepTimerWithStatus.
  ///
  /// In zh, this message translates to:
  /// **'睡眠定时：{status}'**
  String playerSleepTimerWithStatus(String status);

  /// No description provided for @playerSleepTimerCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消定时'**
  String get playerSleepTimerCancel;

  /// No description provided for @playerSleepTimerByDuration.
  ///
  /// In zh, this message translates to:
  /// **'按时长'**
  String get playerSleepTimerByDuration;

  /// No description provided for @playerHours.
  ///
  /// In zh, this message translates to:
  /// **'{count} 小时'**
  String playerHours(int count);

  /// No description provided for @playerMinutes.
  ///
  /// In zh, this message translates to:
  /// **'{count} 分钟'**
  String playerMinutes(int count);

  /// No description provided for @playerCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get playerCustom;

  /// No description provided for @playerCustomDuration.
  ///
  /// In zh, this message translates to:
  /// **'自定义时长'**
  String get playerCustomDuration;

  /// No description provided for @playerUnitMinutes.
  ///
  /// In zh, this message translates to:
  /// **'分钟'**
  String get playerUnitMinutes;

  /// No description provided for @playerSleepTimerBySongs.
  ///
  /// In zh, this message translates to:
  /// **'按歌曲'**
  String get playerSleepTimerBySongs;

  /// No description provided for @playerSongsUnit.
  ///
  /// In zh, this message translates to:
  /// **'{count} 首'**
  String playerSongsUnit(int count);

  /// No description provided for @playerCustomSongCount.
  ///
  /// In zh, this message translates to:
  /// **'自定义首数'**
  String get playerCustomSongCount;

  /// No description provided for @playerUnitSongs.
  ///
  /// In zh, this message translates to:
  /// **'首'**
  String get playerUnitSongs;

  /// No description provided for @playerRemainingSongs.
  ///
  /// In zh, this message translates to:
  /// **'剩余 {count} 首'**
  String playerRemainingSongs(int count);

  /// No description provided for @playerEnterNumber.
  ///
  /// In zh, this message translates to:
  /// **'请输入数字'**
  String get playerEnterNumber;

  /// No description provided for @playerEnterValidInteger.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效整数'**
  String get playerEnterValidInteger;

  /// No description provided for @playerEnterIntegerInRange.
  ///
  /// In zh, this message translates to:
  /// **'请输入 {min} - {max} 之间的整数'**
  String playerEnterIntegerInRange(int min, int max);

  /// No description provided for @playerBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get playerBack;

  /// No description provided for @playerNowPlaying.
  ///
  /// In zh, this message translates to:
  /// **'正在播放'**
  String get playerNowPlaying;

  /// No description provided for @playerNoContent.
  ///
  /// In zh, this message translates to:
  /// **'无播放内容'**
  String get playerNoContent;

  /// No description provided for @playerUnknownArtist.
  ///
  /// In zh, this message translates to:
  /// **'未知艺术家'**
  String get playerUnknownArtist;

  /// No description provided for @playerPlayMode.
  ///
  /// In zh, this message translates to:
  /// **'播放模式'**
  String get playerPlayMode;

  /// No description provided for @playerVolumeDown.
  ///
  /// In zh, this message translates to:
  /// **'音量-'**
  String get playerVolumeDown;

  /// No description provided for @playerVolumeUp.
  ///
  /// In zh, this message translates to:
  /// **'音量+'**
  String get playerVolumeUp;

  /// No description provided for @playerPrevious.
  ///
  /// In zh, this message translates to:
  /// **'上一首'**
  String get playerPrevious;

  /// No description provided for @playerNext.
  ///
  /// In zh, this message translates to:
  /// **'下一首'**
  String get playerNext;

  /// No description provided for @playerPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'播放列表'**
  String get playerPlaylist;

  /// No description provided for @playerBuffering.
  ///
  /// In zh, this message translates to:
  /// **'缓冲中'**
  String get playerBuffering;

  /// No description provided for @playerCaching.
  ///
  /// In zh, this message translates to:
  /// **'正在缓存，请稍候…'**
  String get playerCaching;

  /// No description provided for @playerPause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get playerPause;

  /// No description provided for @playerPlay.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get playerPlay;

  /// No description provided for @playerSeekHint.
  ///
  /// In zh, this message translates to:
  /// **'← → 快进/快退'**
  String get playerSeekHint;

  /// No description provided for @playerProgress.
  ///
  /// In zh, this message translates to:
  /// **'播放进度'**
  String get playerProgress;

  /// No description provided for @playerQueueTitle.
  ///
  /// In zh, this message translates to:
  /// **'播放队列'**
  String get playerQueueTitle;

  /// No description provided for @playerClearPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'清空播放列表'**
  String get playerClearPlaylist;

  /// No description provided for @playerQueueEmpty.
  ///
  /// In zh, this message translates to:
  /// **'播放队列为空'**
  String get playerQueueEmpty;

  /// No description provided for @playerDrawerEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'添加歌曲开始播放'**
  String get playerDrawerEmptyHint;

  /// No description provided for @playerQueueEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'添加歌曲到播放队列开始播放'**
  String get playerQueueEmptyHint;

  /// No description provided for @playerRemovedSong.
  ///
  /// In zh, this message translates to:
  /// **'已移除「{title}」'**
  String playerRemovedSong(String title);

  /// No description provided for @playerClearQueueTitle.
  ///
  /// In zh, this message translates to:
  /// **'清空播放队列'**
  String get playerClearQueueTitle;

  /// No description provided for @playerClearQueueConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要清空播放队列吗？'**
  String get playerClearQueueConfirm;

  /// No description provided for @playerClear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get playerClear;

  /// No description provided for @playerRemoveFromPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'从播放列表移除'**
  String get playerRemoveFromPlaylist;

  /// No description provided for @playerRemoveFromQueue.
  ///
  /// In zh, this message translates to:
  /// **'从队列移除'**
  String get playerRemoveFromQueue;

  /// No description provided for @playerMute.
  ///
  /// In zh, this message translates to:
  /// **'静音'**
  String get playerMute;

  /// No description provided for @playerUnmute.
  ///
  /// In zh, this message translates to:
  /// **'恢复音量'**
  String get playerUnmute;

  /// No description provided for @playerVolumePercent.
  ///
  /// In zh, this message translates to:
  /// **'音量 {value}%'**
  String playerVolumePercent(int value);

  /// No description provided for @playerVolume.
  ///
  /// In zh, this message translates to:
  /// **'音量'**
  String get playerVolume;

  /// No description provided for @playerCloseVolumePanel.
  ///
  /// In zh, this message translates to:
  /// **'关闭音量面板'**
  String get playerCloseVolumePanel;

  /// No description provided for @playerOpenFullPlayer.
  ///
  /// In zh, this message translates to:
  /// **'打开全屏播放器'**
  String get playerOpenFullPlayer;

  /// No description provided for @playerEqualizer.
  ///
  /// In zh, this message translates to:
  /// **'均衡器'**
  String get playerEqualizer;

  /// No description provided for @playerAudioTrack.
  ///
  /// In zh, this message translates to:
  /// **'音轨'**
  String get playerAudioTrack;

  /// No description provided for @playerSelectAudioTrack.
  ///
  /// In zh, this message translates to:
  /// **'选择音轨'**
  String get playerSelectAudioTrack;

  /// No description provided for @playerAudioTrackNumbered.
  ///
  /// In zh, this message translates to:
  /// **'音轨 {index}'**
  String playerAudioTrackNumbered(int index);

  /// No description provided for @playerLyrics.
  ///
  /// In zh, this message translates to:
  /// **'歌词'**
  String get playerLyrics;

  /// No description provided for @playerCollapse.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get playerCollapse;

  /// No description provided for @playerSubtitleOn.
  ///
  /// In zh, this message translates to:
  /// **'显示字幕'**
  String get playerSubtitleOn;

  /// No description provided for @playerSubtitleOff.
  ///
  /// In zh, this message translates to:
  /// **'隐藏字幕'**
  String get playerSubtitleOff;

  /// No description provided for @playerEnterFullscreen.
  ///
  /// In zh, this message translates to:
  /// **'全屏'**
  String get playerEnterFullscreen;

  /// No description provided for @playerExitFullscreen.
  ///
  /// In zh, this message translates to:
  /// **'退出全屏'**
  String get playerExitFullscreen;

  /// No description provided for @playerSleepTimerOn.
  ///
  /// In zh, this message translates to:
  /// **'睡眠定时 (已开启)'**
  String get playerSleepTimerOn;

  /// No description provided for @playerDeleteCurrentSong.
  ///
  /// In zh, this message translates to:
  /// **'删除当前歌曲'**
  String get playerDeleteCurrentSong;

  /// No description provided for @playerExpandPlayer.
  ///
  /// In zh, this message translates to:
  /// **'展开播放器'**
  String get playerExpandPlayer;

  /// No description provided for @playerBufferingSemantic.
  ///
  /// In zh, this message translates to:
  /// **'正在缓冲'**
  String get playerBufferingSemantic;

  /// No description provided for @playerLyricsLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在加载歌词...'**
  String get playerLyricsLoading;

  /// No description provided for @playerLyricsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'歌词加载失败'**
  String get playerLyricsLoadFailed;

  /// No description provided for @playerLyricsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无歌词'**
  String get playerLyricsEmpty;

  /// No description provided for @playerLyricsSeekTo.
  ///
  /// In zh, this message translates to:
  /// **'跳转到此歌词位置'**
  String get playerLyricsSeekTo;

  /// No description provided for @playerAdjustLyrics.
  ///
  /// In zh, this message translates to:
  /// **'调整歌词'**
  String get playerAdjustLyrics;

  /// No description provided for @playerLyricsRefetch.
  ///
  /// In zh, this message translates to:
  /// **'重新抓取歌词'**
  String get playerLyricsRefetch;

  /// No description provided for @playerEqNotSupported.
  ///
  /// In zh, this message translates to:
  /// **'当前平台暂不支持均衡器'**
  String get playerEqNotSupported;

  /// No description provided for @playerEqPresetFlat.
  ///
  /// In zh, this message translates to:
  /// **'平坦'**
  String get playerEqPresetFlat;

  /// No description provided for @playerEqPresetRock.
  ///
  /// In zh, this message translates to:
  /// **'摇滚'**
  String get playerEqPresetRock;

  /// No description provided for @playerEqPresetPop.
  ///
  /// In zh, this message translates to:
  /// **'流行'**
  String get playerEqPresetPop;

  /// No description provided for @playerEqPresetJazz.
  ///
  /// In zh, this message translates to:
  /// **'爵士'**
  String get playerEqPresetJazz;

  /// No description provided for @playerEqPresetClassical.
  ///
  /// In zh, this message translates to:
  /// **'古典'**
  String get playerEqPresetClassical;

  /// No description provided for @playerEqPresetBassBoost.
  ///
  /// In zh, this message translates to:
  /// **'低音增强'**
  String get playerEqPresetBassBoost;

  /// No description provided for @playerEqPresetTrebleBoost.
  ///
  /// In zh, this message translates to:
  /// **'高音增强'**
  String get playerEqPresetTrebleBoost;

  /// No description provided for @playerEqPresetVocal.
  ///
  /// In zh, this message translates to:
  /// **'人声'**
  String get playerEqPresetVocal;

  /// No description provided for @playerEqPresetCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get playerEqPresetCustom;

  /// No description provided for @playerLyricSavedWritten.
  ///
  /// In zh, this message translates to:
  /// **'已保存，已写入音频文件'**
  String get playerLyricSavedWritten;

  /// No description provided for @playerLyricSavedWriteFailed.
  ///
  /// In zh, this message translates to:
  /// **'已保存到数据库，但写入音频文件失败'**
  String get playerLyricSavedWriteFailed;

  /// No description provided for @playerLyricSavedDbOnly.
  ///
  /// In zh, this message translates to:
  /// **'已保存到数据库（文件未更新）'**
  String get playerLyricSavedDbOnly;

  /// No description provided for @playerSaveFailedDetail.
  ///
  /// In zh, this message translates to:
  /// **'保存失败：{error}'**
  String playerSaveFailedDetail(String error);

  /// No description provided for @playerDiscardChangesTitle.
  ///
  /// In zh, this message translates to:
  /// **'放弃修改？'**
  String get playerDiscardChangesTitle;

  /// No description provided for @playerDiscardChangesContent.
  ///
  /// In zh, this message translates to:
  /// **'当前调整尚未保存，确定要离开吗？'**
  String get playerDiscardChangesContent;

  /// No description provided for @playerContinueEditing.
  ///
  /// In zh, this message translates to:
  /// **'继续编辑'**
  String get playerContinueEditing;

  /// No description provided for @playerDiscard.
  ///
  /// In zh, this message translates to:
  /// **'放弃'**
  String get playerDiscard;

  /// No description provided for @playerGlobalOffset.
  ///
  /// In zh, this message translates to:
  /// **'全局偏移'**
  String get playerGlobalOffset;

  /// No description provided for @playerLyricOffsetSemantics.
  ///
  /// In zh, this message translates to:
  /// **'歌词偏移 {value} 毫秒'**
  String playerLyricOffsetSemantics(int value);

  /// No description provided for @playerOffsetHint.
  ///
  /// In zh, this message translates to:
  /// **'提示：歌词整体早出现，用负偏移（-）；整体晚出现，用正偏移（+）'**
  String get playerOffsetHint;

  /// No description provided for @playerEmptyLine.
  ///
  /// In zh, this message translates to:
  /// **'(空行)'**
  String get playerEmptyLine;

  /// No description provided for @playerLineOffset.
  ///
  /// In zh, this message translates to:
  /// **'行偏移 {offset}'**
  String playerLineOffset(String offset);

  /// No description provided for @playerReset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get playerReset;

  /// No description provided for @playerSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get playerSave;

  /// No description provided for @playerNoLyricsToAdjust.
  ///
  /// In zh, this message translates to:
  /// **'暂无可调整的歌词'**
  String get playerNoLyricsToAdjust;

  /// No description provided for @playerDeleteSongTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除歌曲'**
  String get playerDeleteSongTitle;

  /// No description provided for @playerDeleteSongConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要从曲库中删除「{title}」吗？'**
  String playerDeleteSongConfirm(String title);

  /// No description provided for @playerSongDeleted.
  ///
  /// In zh, this message translates to:
  /// **'歌曲已删除'**
  String get playerSongDeleted;

  /// No description provided for @playerDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败'**
  String get playerDeleteFailed;

  /// No description provided for @playerUnknownSong.
  ///
  /// In zh, this message translates to:
  /// **'未知歌曲'**
  String get playerUnknownSong;

  /// No description provided for @playerPlayFailedNamed.
  ///
  /// In zh, this message translates to:
  /// **'\"{title}\" 播放失败'**
  String playerPlayFailedNamed(String title);

  /// No description provided for @playerConsecutiveFailures.
  ///
  /// In zh, this message translates to:
  /// **'连续 {count} 首歌曲播放失败，已停止播放，请检查网络连接'**
  String playerConsecutiveFailures(int count);

  /// No description provided for @playerPlayFailedTryingNext.
  ///
  /// In zh, this message translates to:
  /// **'\"{title}\" 播放失败，正在尝试下一首...'**
  String playerPlayFailedTryingNext(String title);

  /// No description provided for @playerPlayFailedNoOthers.
  ///
  /// In zh, this message translates to:
  /// **'播放失败，无其他可播放的歌曲'**
  String get playerPlayFailedNoOthers;

  /// No description provided for @playerPlayFailedEndOfList.
  ///
  /// In zh, this message translates to:
  /// **'播放失败，已到播放列表末尾'**
  String get playerPlayFailedEndOfList;

  /// No description provided for @playlistBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get playlistBack;

  /// No description provided for @playlistSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get playlistSearch;

  /// No description provided for @playlistSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索歌曲...'**
  String get playlistSearchHint;

  /// No description provided for @playlistListSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索歌单...'**
  String get playlistListSearchHint;

  /// No description provided for @playlistNoMatching.
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配的歌单'**
  String get playlistNoMatching;

  /// No description provided for @playlistTryOtherKeywords.
  ///
  /// In zh, this message translates to:
  /// **'尝试其他关键词'**
  String get playlistTryOtherKeywords;

  /// No description provided for @playlistFilterNormal.
  ///
  /// In zh, this message translates to:
  /// **'普通歌单'**
  String get playlistFilterNormal;

  /// No description provided for @playlistFilterRadio.
  ///
  /// In zh, this message translates to:
  /// **'电台歌单'**
  String get playlistFilterRadio;

  /// No description provided for @playlistMultiSelect.
  ///
  /// In zh, this message translates to:
  /// **'多选'**
  String get playlistMultiSelect;

  /// No description provided for @playlistMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get playlistMore;

  /// No description provided for @playlistDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get playlistDone;

  /// No description provided for @playlistSort.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get playlistSort;

  /// No description provided for @playlistSortModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'排序歌单'**
  String get playlistSortModeTitle;

  /// No description provided for @playlistSortSaved.
  ///
  /// In zh, this message translates to:
  /// **'排序已保存'**
  String get playlistSortSaved;

  /// No description provided for @playlistSortSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'排序保存失败'**
  String get playlistSortSaveFailed;

  /// No description provided for @playlistSortFailed.
  ///
  /// In zh, this message translates to:
  /// **'排序失败'**
  String get playlistSortFailed;

  /// No description provided for @playlistAlreadySortedSongs.
  ///
  /// In zh, this message translates to:
  /// **'歌曲已是该排序顺序'**
  String get playlistAlreadySortedSongs;

  /// No description provided for @playlistAlreadySortedPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'歌单已是该排序顺序'**
  String get playlistAlreadySortedPlaylists;

  /// No description provided for @playlistSortedByNameAsc.
  ///
  /// In zh, this message translates to:
  /// **'已按名称升序排列'**
  String get playlistSortedByNameAsc;

  /// No description provided for @playlistSortedByNameDesc.
  ///
  /// In zh, this message translates to:
  /// **'已按名称降序排列'**
  String get playlistSortedByNameDesc;

  /// No description provided for @playlistSortedByNumber.
  ///
  /// In zh, this message translates to:
  /// **'已按数字前缀排序'**
  String get playlistSortedByNumber;

  /// No description provided for @playlistSortCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义顺序'**
  String get playlistSortCustom;

  /// No description provided for @playlistSortRecentlyAdded.
  ///
  /// In zh, this message translates to:
  /// **'最近加入'**
  String get playlistSortRecentlyAdded;

  /// No description provided for @playlistSortFileTime.
  ///
  /// In zh, this message translates to:
  /// **'文件时间'**
  String get playlistSortFileTime;

  /// No description provided for @playlistSortTitle.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get playlistSortTitle;

  /// No description provided for @playlistSortArtist.
  ///
  /// In zh, this message translates to:
  /// **'艺术家'**
  String get playlistSortArtist;

  /// No description provided for @playlistSortDuration.
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get playlistSortDuration;

  /// No description provided for @playlistSortNameAsc.
  ///
  /// In zh, this message translates to:
  /// **'按名称排序 A→Z'**
  String get playlistSortNameAsc;

  /// No description provided for @playlistSortNameDesc.
  ///
  /// In zh, this message translates to:
  /// **'按名称排序 Z→A'**
  String get playlistSortNameDesc;

  /// No description provided for @playlistSortNumberPrefix.
  ///
  /// In zh, this message translates to:
  /// **'按数字前缀排序'**
  String get playlistSortNumberPrefix;

  /// No description provided for @playlistSortManual.
  ///
  /// In zh, this message translates to:
  /// **'手动排序'**
  String get playlistSortManual;

  /// No description provided for @playlistPlayAll.
  ///
  /// In zh, this message translates to:
  /// **'播放全部'**
  String get playlistPlayAll;

  /// No description provided for @playlistAddSongs.
  ///
  /// In zh, this message translates to:
  /// **'添加歌曲'**
  String get playlistAddSongs;

  /// No description provided for @playlistAddSongsFailed.
  ///
  /// In zh, this message translates to:
  /// **'添加歌曲失败'**
  String get playlistAddSongsFailed;

  /// No description provided for @playlistAddedWithSkipped.
  ///
  /// In zh, this message translates to:
  /// **'已添加 {added} 首，跳过 {skipped} 首（已存在或类型不兼容）'**
  String playlistAddedWithSkipped(int added, int skipped);

  /// No description provided for @playlistAddedCount.
  ///
  /// In zh, this message translates to:
  /// **'已添加 {count} 首歌曲'**
  String playlistAddedCount(int count);

  /// No description provided for @playlistLoadMoreRetry.
  ///
  /// In zh, this message translates to:
  /// **'加载更多失败，点击重试'**
  String get playlistLoadMoreRetry;

  /// No description provided for @playlistAllLoaded.
  ///
  /// In zh, this message translates to:
  /// **'— 已全部加载（{count}） —'**
  String playlistAllLoaded(int count);

  /// No description provided for @playlistDeselectAll.
  ///
  /// In zh, this message translates to:
  /// **'取消全选'**
  String get playlistDeselectAll;

  /// No description provided for @playlistRemove.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get playlistRemove;

  /// No description provided for @playlistRemoveFromPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'从歌单移除'**
  String get playlistRemoveFromPlaylist;

  /// No description provided for @playlistDeleteFromLibrary.
  ///
  /// In zh, this message translates to:
  /// **'从曲库删除'**
  String get playlistDeleteFromLibrary;

  /// No description provided for @playlistActionsCount.
  ///
  /// In zh, this message translates to:
  /// **'操作({count})'**
  String playlistActionsCount(int count);

  /// No description provided for @playlistBatchRemoveTitle.
  ///
  /// In zh, this message translates to:
  /// **'批量移除'**
  String get playlistBatchRemoveTitle;

  /// No description provided for @playlistBatchRemoveConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要从歌单中移除 {count} 首歌曲吗？'**
  String playlistBatchRemoveConfirm(int count);

  /// No description provided for @playlistRemovedCount.
  ///
  /// In zh, this message translates to:
  /// **'已移除 {count} 首歌曲'**
  String playlistRemovedCount(int count);

  /// No description provided for @playlistRemoveFailed.
  ///
  /// In zh, this message translates to:
  /// **'移除失败'**
  String get playlistRemoveFailed;

  /// No description provided for @playlistEditCover.
  ///
  /// In zh, this message translates to:
  /// **'修改封面'**
  String get playlistEditCover;

  /// No description provided for @playlistEditPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'编辑歌单'**
  String get playlistEditPlaylist;

  /// No description provided for @playlistEditAction.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get playlistEditAction;

  /// No description provided for @playlistDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除歌单'**
  String get playlistDelete;

  /// No description provided for @playlistEmptySongs.
  ///
  /// In zh, this message translates to:
  /// **'歌单暂无歌曲'**
  String get playlistEmptySongs;

  /// No description provided for @playlistEmptySongsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'添加一些喜欢的音乐吧'**
  String get playlistEmptySongsSubtitle;

  /// No description provided for @playlistLabelBuiltIn.
  ///
  /// In zh, this message translates to:
  /// **'内置'**
  String get playlistLabelBuiltIn;

  /// No description provided for @playlistLabelAutoCreated.
  ///
  /// In zh, this message translates to:
  /// **'自动创建'**
  String get playlistLabelAutoCreated;

  /// No description provided for @playlistLabelAuto.
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get playlistLabelAuto;

  /// No description provided for @playlistLabelHidden.
  ///
  /// In zh, this message translates to:
  /// **'已隐藏'**
  String get playlistLabelHidden;

  /// No description provided for @playlistConfirmDelete.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get playlistConfirmDelete;

  /// No description provided for @playlistDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除歌单「{name}」吗？此操作不可恢复。'**
  String playlistDeleteConfirm(String name);

  /// No description provided for @playlistDeleted.
  ///
  /// In zh, this message translates to:
  /// **'歌单已删除'**
  String get playlistDeleted;

  /// No description provided for @playlistEmpty.
  ///
  /// In zh, this message translates to:
  /// **'歌单为空'**
  String get playlistEmpty;

  /// No description provided for @playlistPlayFailed.
  ///
  /// In zh, this message translates to:
  /// **'播放失败'**
  String get playlistPlayFailed;

  /// No description provided for @playlistPlayingCount.
  ///
  /// In zh, this message translates to:
  /// **'播放全部 {count} 首歌曲'**
  String playlistPlayingCount(int count);

  /// No description provided for @playlistPlayingSong.
  ///
  /// In zh, this message translates to:
  /// **'播放：{title}'**
  String playlistPlayingSong(String title);

  /// No description provided for @playlistRemoveSongTitle.
  ///
  /// In zh, this message translates to:
  /// **'移除歌曲'**
  String get playlistRemoveSongTitle;

  /// No description provided for @playlistRemoveSongConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要从歌单中移除「{title}」吗？'**
  String playlistRemoveSongConfirm(String title);

  /// No description provided for @playlistSongRemoved.
  ///
  /// In zh, this message translates to:
  /// **'歌曲已移除'**
  String get playlistSongRemoved;

  /// No description provided for @playlistDeleteSong.
  ///
  /// In zh, this message translates to:
  /// **'删除歌曲'**
  String get playlistDeleteSong;

  /// No description provided for @playlistDeleteSongConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要从曲库中删除「{title}」吗？'**
  String playlistDeleteSongConfirm(String title);

  /// No description provided for @playlistSongDeleted.
  ///
  /// In zh, this message translates to:
  /// **'歌曲已删除'**
  String get playlistSongDeleted;

  /// No description provided for @playlistDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败'**
  String get playlistDeleteFailed;

  /// No description provided for @playlistBatchDelete.
  ///
  /// In zh, this message translates to:
  /// **'批量删除'**
  String get playlistBatchDelete;

  /// No description provided for @playlistBatchDeleteSongsConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要从曲库中删除选中的 {count} 首歌曲吗？'**
  String playlistBatchDeleteSongsConfirm(int count);

  /// No description provided for @playlistDeletedSongsCount.
  ///
  /// In zh, this message translates to:
  /// **'已删除 {count} 首歌曲'**
  String playlistDeletedSongsCount(int count);

  /// No description provided for @playlistUnknownArtist.
  ///
  /// In zh, this message translates to:
  /// **'未知艺术家'**
  String get playlistUnknownArtist;

  /// No description provided for @playlistPickImageFailed.
  ///
  /// In zh, this message translates to:
  /// **'选择图片失败: {error}'**
  String playlistPickImageFailed(String error);

  /// No description provided for @playlistNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入歌单名称'**
  String get playlistNameRequired;

  /// No description provided for @playlistNameHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入歌单名称'**
  String get playlistNameHint;

  /// No description provided for @playlistDescLabel.
  ///
  /// In zh, this message translates to:
  /// **'歌单描述'**
  String get playlistDescLabel;

  /// No description provided for @playlistDescHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入歌单描述（可选）'**
  String get playlistDescHint;

  /// No description provided for @playlistCoverUploadFailed.
  ///
  /// In zh, this message translates to:
  /// **'封面上传失败'**
  String get playlistCoverUploadFailed;

  /// No description provided for @playlistSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败: {error}'**
  String playlistSaveFailed(String error);

  /// No description provided for @playlistUploadImage.
  ///
  /// In zh, this message translates to:
  /// **'上传图片'**
  String get playlistUploadImage;

  /// No description provided for @playlistPickFromSongs.
  ///
  /// In zh, this message translates to:
  /// **'从歌曲选择'**
  String get playlistPickFromSongs;

  /// No description provided for @playlistClear.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get playlistClear;

  /// No description provided for @playlistSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get playlistSave;

  /// No description provided for @playlistOk.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get playlistOk;

  /// No description provided for @playlistTitle.
  ///
  /// In zh, this message translates to:
  /// **'歌单'**
  String get playlistTitle;

  /// No description provided for @playlistSwitchToListView.
  ///
  /// In zh, this message translates to:
  /// **'切换到列表视图'**
  String get playlistSwitchToListView;

  /// No description provided for @playlistSwitchToGridView.
  ///
  /// In zh, this message translates to:
  /// **'切换到卡片视图'**
  String get playlistSwitchToGridView;

  /// No description provided for @playlistCreate.
  ///
  /// In zh, this message translates to:
  /// **'创建歌单'**
  String get playlistCreate;

  /// No description provided for @playlistCreated.
  ///
  /// In zh, this message translates to:
  /// **'歌单创建成功'**
  String get playlistCreated;

  /// No description provided for @playlistUpdated.
  ///
  /// In zh, this message translates to:
  /// **'歌单更新成功'**
  String get playlistUpdated;

  /// No description provided for @playlistShowHidden.
  ///
  /// In zh, this message translates to:
  /// **'显示已隐藏歌单'**
  String get playlistShowHidden;

  /// No description provided for @playlistHideHidden.
  ///
  /// In zh, this message translates to:
  /// **'隐藏已隐藏歌单'**
  String get playlistHideHidden;

  /// No description provided for @playlistEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'点击右上角按钮创建歌单'**
  String get playlistEmptyHint;

  /// No description provided for @playlistConfirmBatchDelete.
  ///
  /// In zh, this message translates to:
  /// **'确认批量删除'**
  String get playlistConfirmBatchDelete;

  /// No description provided for @playlistBatchDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除选中的 {count} 个歌单吗？此操作不可恢复。'**
  String playlistBatchDeleteConfirm(int count);

  /// No description provided for @playlistDeletedCount.
  ///
  /// In zh, this message translates to:
  /// **'已删除 {count} 个歌单'**
  String playlistDeletedCount(int count);

  /// No description provided for @playlistHidden.
  ///
  /// In zh, this message translates to:
  /// **'歌单已隐藏'**
  String get playlistHidden;

  /// No description provided for @playlistUnhidden.
  ///
  /// In zh, this message translates to:
  /// **'歌单已取消隐藏'**
  String get playlistUnhidden;

  /// No description provided for @playlistPlayingMultiple.
  ///
  /// In zh, this message translates to:
  /// **'正在播放 {count} 个歌单'**
  String playlistPlayingMultiple(int count);

  /// No description provided for @playlistExitMultiSelect.
  ///
  /// In zh, this message translates to:
  /// **'退出多选'**
  String get playlistExitMultiSelect;

  /// No description provided for @playlistSelectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已选择 {count} 个'**
  String playlistSelectedCount(int count);

  /// No description provided for @playlistPlayCount.
  ///
  /// In zh, this message translates to:
  /// **'播放({count})'**
  String playlistPlayCount(int count);

  /// No description provided for @playlistDeleteCount.
  ///
  /// In zh, this message translates to:
  /// **'删除({count})'**
  String playlistDeleteCount(int count);

  /// No description provided for @playlistTypeNormalOption.
  ///
  /// In zh, this message translates to:
  /// **'普通歌单'**
  String get playlistTypeNormalOption;

  /// No description provided for @playlistTypeRadioOption.
  ///
  /// In zh, this message translates to:
  /// **'电台歌单'**
  String get playlistTypeRadioOption;

  /// No description provided for @playlistMoreActions.
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get playlistMoreActions;

  /// No description provided for @playlistHide.
  ///
  /// In zh, this message translates to:
  /// **'隐藏歌单'**
  String get playlistHide;

  /// No description provided for @playlistUnhide.
  ///
  /// In zh, this message translates to:
  /// **'取消隐藏'**
  String get playlistUnhide;

  /// No description provided for @playlistPickCoverTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择歌曲封面'**
  String get playlistPickCoverTitle;

  /// No description provided for @playlistClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get playlistClose;

  /// No description provided for @playlistNoCoveredSongs.
  ///
  /// In zh, this message translates to:
  /// **'歌单中没有带封面的歌曲'**
  String get playlistNoCoveredSongs;

  /// No description provided for @playlistLoadRetry.
  ///
  /// In zh, this message translates to:
  /// **'加载失败，点击重试'**
  String get playlistLoadRetry;

  /// No description provided for @playlistNoCoverLoadMore.
  ///
  /// In zh, this message translates to:
  /// **'当前页无带封面歌曲，加载更多'**
  String get playlistNoCoverLoadMore;

  /// No description provided for @playlistAllLoadedSimple.
  ///
  /// In zh, this message translates to:
  /// **'— 已加载全部 —'**
  String get playlistAllLoadedSimple;

  /// No description provided for @playlistSelectThisCover.
  ///
  /// In zh, this message translates to:
  /// **'选择此封面'**
  String get playlistSelectThisCover;

  /// No description provided for @playlistErrRequestFailed.
  ///
  /// In zh, this message translates to:
  /// **'请求失败'**
  String get playlistErrRequestFailed;

  /// No description provided for @playlistErrTimeout.
  ///
  /// In zh, this message translates to:
  /// **'网络连接超时'**
  String get playlistErrTimeout;

  /// No description provided for @playlistErrCancelled.
  ///
  /// In zh, this message translates to:
  /// **'请求已取消'**
  String get playlistErrCancelled;

  /// No description provided for @playlistErrNetwork.
  ///
  /// In zh, this message translates to:
  /// **'网络错误: {message}'**
  String playlistErrNetwork(String message);

  /// No description provided for @settingsCacheSaveConfigFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存配置失败: {error}'**
  String settingsCacheSaveConfigFailed(String error);

  /// No description provided for @settingsCacheCleanServerTitle.
  ///
  /// In zh, this message translates to:
  /// **'清理服务端缓存'**
  String get settingsCacheCleanServerTitle;

  /// No description provided for @settingsCacheCleanServerContent.
  ///
  /// In zh, this message translates to:
  /// **'确定要清理服务端的所有音乐缓存吗？清理后需要重新下载。'**
  String get settingsCacheCleanServerContent;

  /// No description provided for @settingsCacheServerCleaned.
  ///
  /// In zh, this message translates to:
  /// **'服务端缓存已清理'**
  String get settingsCacheServerCleaned;

  /// No description provided for @settingsCacheCleanFailed.
  ///
  /// In zh, this message translates to:
  /// **'清理失败: {error}'**
  String settingsCacheCleanFailed(String error);

  /// No description provided for @settingsCacheCleanLocalTitle.
  ///
  /// In zh, this message translates to:
  /// **'清理本地缓存'**
  String get settingsCacheCleanLocalTitle;

  /// No description provided for @settingsCacheCleanLocalContent.
  ///
  /// In zh, this message translates to:
  /// **'确定要清理所有本地缓存吗？包括音频缓存、图片缓存和歌词缓存。'**
  String get settingsCacheCleanLocalContent;

  /// No description provided for @settingsCacheLocalCleaned.
  ///
  /// In zh, this message translates to:
  /// **'本地缓存已清理'**
  String get settingsCacheLocalCleaned;

  /// No description provided for @settingsCacheCleanBrowserTitle.
  ///
  /// In zh, this message translates to:
  /// **'清理浏览器缓存'**
  String get settingsCacheCleanBrowserTitle;

  /// No description provided for @settingsCacheCleanBrowserContent.
  ///
  /// In zh, this message translates to:
  /// **'将清除所有前端静态资源缓存并刷新页面。不会影响登录状态和服务端数据。'**
  String get settingsCacheCleanBrowserContent;

  /// No description provided for @webUpdateAvailableTitle.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本'**
  String get webUpdateAvailableTitle;

  /// No description provided for @webUpdateAvailableContent.
  ///
  /// In zh, this message translates to:
  /// **'检测到服务端已更新，当前页面仍是旧版本。点击「立即刷新」将清理浏览器缓存并加载最新版本，不会影响登录状态。'**
  String get webUpdateAvailableContent;

  /// No description provided for @webUpdateAvailableRefresh.
  ///
  /// In zh, this message translates to:
  /// **'立即刷新'**
  String get webUpdateAvailableRefresh;

  /// No description provided for @webUpdateAvailableLater.
  ///
  /// In zh, this message translates to:
  /// **'稍后'**
  String get webUpdateAvailableLater;

  /// No description provided for @settingsCacheUpdateConfigFailed.
  ///
  /// In zh, this message translates to:
  /// **'更新配置失败: {error}'**
  String settingsCacheUpdateConfigFailed(String error);

  /// No description provided for @settingsCacheDirRestored.
  ///
  /// In zh, this message translates to:
  /// **'已恢复默认缓存目录'**
  String get settingsCacheDirRestored;

  /// No description provided for @settingsCacheDirUpdated.
  ///
  /// In zh, this message translates to:
  /// **'缓存目录已更新'**
  String get settingsCacheDirUpdated;

  /// No description provided for @settingsCacheUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'更新失败: {error}'**
  String settingsCacheUpdateFailed(String error);

  /// No description provided for @settingsCacheConfirmClean.
  ///
  /// In zh, this message translates to:
  /// **'确认清理'**
  String get settingsCacheConfirmClean;

  /// No description provided for @settingsCacheServerTitle.
  ///
  /// In zh, this message translates to:
  /// **'服务端音乐缓存'**
  String get settingsCacheServerTitle;

  /// No description provided for @settingsCacheManage.
  ///
  /// In zh, this message translates to:
  /// **'管理'**
  String get settingsCacheManage;

  /// No description provided for @settingsCacheNoLimit.
  ///
  /// In zh, this message translates to:
  /// **'{size} (无上限)'**
  String settingsCacheNoLimit(String size);

  /// No description provided for @settingsCacheFileCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个文件'**
  String settingsCacheFileCount(int count);

  /// No description provided for @settingsCacheStatsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'获取缓存信息失败'**
  String get settingsCacheStatsLoadFailed;

  /// No description provided for @settingsCacheDirTitle.
  ///
  /// In zh, this message translates to:
  /// **'缓存目录'**
  String get settingsCacheDirTitle;

  /// No description provided for @settingsCacheNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get settingsCacheNotConfigured;

  /// No description provided for @settingsCacheMaxSize.
  ///
  /// In zh, this message translates to:
  /// **'最大缓存大小: {size}'**
  String settingsCacheMaxSize(String size);

  /// No description provided for @settingsCacheTranscodeTitle.
  ///
  /// In zh, this message translates to:
  /// **'缓存转码格式'**
  String get settingsCacheTranscodeTitle;

  /// No description provided for @settingsCacheTranscodeDesc.
  ///
  /// In zh, this message translates to:
  /// **'网络歌曲缓存时统一转码，提升设备兼容性（如小爱音箱无法播放 MKV）；视频类内容开启后将仅缓存音频、投屏无画面'**
  String get settingsCacheTranscodeDesc;

  /// No description provided for @settingsCacheTranscodeOriginal.
  ///
  /// In zh, this message translates to:
  /// **'原始（不转码）'**
  String get settingsCacheTranscodeOriginal;

  /// No description provided for @settingsCacheTranscodeDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'缓存转码格式'**
  String get settingsCacheTranscodeDialogTitle;

  /// No description provided for @settingsCacheTranscodeQualityTitle.
  ///
  /// In zh, this message translates to:
  /// **'转码码率'**
  String get settingsCacheTranscodeQualityTitle;

  /// No description provided for @settingsCacheTranscodeQualityHighest.
  ///
  /// In zh, this message translates to:
  /// **'最高质量'**
  String get settingsCacheTranscodeQualityHighest;

  /// No description provided for @settingsCacheTranscodeQualityDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'转码码率'**
  String get settingsCacheTranscodeQualityDialogTitle;

  /// No description provided for @settingsCacheTranscodeUpdated.
  ///
  /// In zh, this message translates to:
  /// **'缓存转码设置已更新'**
  String get settingsCacheTranscodeUpdated;

  /// No description provided for @settingsCacheCleaning.
  ///
  /// In zh, this message translates to:
  /// **'清理中...'**
  String get settingsCacheCleaning;

  /// No description provided for @settingsCacheCleanServerButton.
  ///
  /// In zh, this message translates to:
  /// **'清理服务端缓存'**
  String get settingsCacheCleanServerButton;

  /// No description provided for @settingsCacheLocalTitle.
  ///
  /// In zh, this message translates to:
  /// **'本地缓存'**
  String get settingsCacheLocalTitle;

  /// No description provided for @settingsCacheSize.
  ///
  /// In zh, this message translates to:
  /// **'缓存大小'**
  String get settingsCacheSize;

  /// No description provided for @settingsCacheCalculating.
  ///
  /// In zh, this message translates to:
  /// **'计算中...'**
  String get settingsCacheCalculating;

  /// No description provided for @settingsCacheLocalDesc.
  ///
  /// In zh, this message translates to:
  /// **'包含音频缓存、图片缓存和歌词缓存'**
  String get settingsCacheLocalDesc;

  /// No description provided for @settingsCacheMaxLocalSize.
  ///
  /// In zh, this message translates to:
  /// **'最大本地缓存大小: {size}'**
  String settingsCacheMaxLocalSize(String size);

  /// No description provided for @settingsCacheCleanLocalButton.
  ///
  /// In zh, this message translates to:
  /// **'清理本地缓存'**
  String get settingsCacheCleanLocalButton;

  /// No description provided for @settingsCacheBrowserTitle.
  ///
  /// In zh, this message translates to:
  /// **'浏览器缓存'**
  String get settingsCacheBrowserTitle;

  /// No description provided for @settingsCacheBrowserDesc.
  ///
  /// In zh, this message translates to:
  /// **'清除浏览器中缓存的前端资源文件，解决更新后页面异常的问题'**
  String get settingsCacheBrowserDesc;

  /// No description provided for @settingsCacheCleanBrowserButton.
  ///
  /// In zh, this message translates to:
  /// **'清理浏览器缓存'**
  String get settingsCacheCleanBrowserButton;

  /// No description provided for @settingsCacheDirDialogDesc.
  ///
  /// In zh, this message translates to:
  /// **'设置服务端音乐缓存的存储目录。留空则使用默认目录。切换目录不会自动迁移旧缓存文件。'**
  String get settingsCacheDirDialogDesc;

  /// No description provided for @settingsCacheDirLabel.
  ///
  /// In zh, this message translates to:
  /// **'缓存目录（绝对路径）'**
  String get settingsCacheDirLabel;

  /// No description provided for @settingsCacheDirDefault.
  ///
  /// In zh, this message translates to:
  /// **'默认: {dir}'**
  String settingsCacheDirDefault(String dir);

  /// No description provided for @settingsCacheValidate.
  ///
  /// In zh, this message translates to:
  /// **'验证'**
  String get settingsCacheValidate;

  /// No description provided for @settingsCacheRestoreDefault.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get settingsCacheRestoreDefault;

  /// No description provided for @settingsCacheSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get settingsCacheSave;

  /// No description provided for @settingsCacheDirUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'目录不可用'**
  String get settingsCacheDirUnavailable;

  /// No description provided for @settingsCacheDirCreated.
  ///
  /// In zh, this message translates to:
  /// **'目录已自动创建'**
  String get settingsCacheDirCreated;

  /// No description provided for @settingsCacheDiskTotal.
  ///
  /// In zh, this message translates to:
  /// **'磁盘总量 {size}'**
  String settingsCacheDiskTotal(String size);

  /// No description provided for @settingsCacheDiskFree.
  ///
  /// In zh, this message translates to:
  /// **'可用 {size}'**
  String settingsCacheDiskFree(String size);

  /// No description provided for @settingsCacheDirAvailable.
  ///
  /// In zh, this message translates to:
  /// **'目录可用'**
  String get settingsCacheDirAvailable;

  /// No description provided for @settingsMetadataUseTagTitle.
  ///
  /// In zh, this message translates to:
  /// **'使用标签覆盖标题'**
  String get settingsMetadataUseTagTitle;

  /// No description provided for @settingsMetadataUseTagOn.
  ///
  /// In zh, this message translates to:
  /// **'网络歌曲元数据刷新时用音频标签覆盖标题'**
  String get settingsMetadataUseTagOn;

  /// No description provided for @settingsMetadataUseTagOff.
  ///
  /// In zh, this message translates to:
  /// **'网络歌曲标题保持文件名，不使用标签覆盖'**
  String get settingsMetadataUseTagOff;

  /// No description provided for @settingsMetadataSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get settingsMetadataSaved;

  /// No description provided for @settingsMetadataSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败: {error}'**
  String settingsMetadataSaveFailed(String error);

  /// No description provided for @settingsMetadataRefreshTitle.
  ///
  /// In zh, this message translates to:
  /// **'刷新网络歌曲元数据'**
  String get settingsMetadataRefreshTitle;

  /// No description provided for @settingsMetadataRefreshSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'探测所有元数据缺失的网络歌曲'**
  String get settingsMetadataRefreshSubtitle;

  /// No description provided for @settingsMetadataStart.
  ///
  /// In zh, this message translates to:
  /// **'开始'**
  String get settingsMetadataStart;

  /// No description provided for @settingsMetadataPreparing.
  ///
  /// In zh, this message translates to:
  /// **'准备中...'**
  String get settingsMetadataPreparing;

  /// No description provided for @settingsMetadataRefreshing.
  ///
  /// In zh, this message translates to:
  /// **'正在刷新元数据'**
  String get settingsMetadataRefreshing;

  /// No description provided for @settingsMetadataStatusCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get settingsMetadataStatusCancelled;

  /// No description provided for @settingsMetadataStatusFailed.
  ///
  /// In zh, this message translates to:
  /// **'执行失败'**
  String get settingsMetadataStatusFailed;

  /// No description provided for @settingsMetadataStatusDone.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get settingsMetadataStatusDone;

  /// No description provided for @settingsMetadataSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功 {count} 首'**
  String settingsMetadataSuccess(int count);

  /// No description provided for @settingsMetadataFailedCount.
  ///
  /// In zh, this message translates to:
  /// **'，失败 {count} 首'**
  String settingsMetadataFailedCount(int count);

  /// No description provided for @settingsMetadataRefreshResult.
  ///
  /// In zh, this message translates to:
  /// **'刷新元数据{status}'**
  String settingsMetadataRefreshResult(String status);

  /// No description provided for @settingsMetadataRefreshAgain.
  ///
  /// In zh, this message translates to:
  /// **'重新刷新'**
  String get settingsMetadataRefreshAgain;

  /// No description provided for @settingsClientDownloadTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载客户端 App'**
  String get settingsClientDownloadTitle;

  /// No description provided for @settingsClientDownloadIntro.
  ///
  /// In zh, this message translates to:
  /// **'相比 Web 界面，原生客户端支持后台播放、本地缓存、锁屏/通知栏媒体控制等能力。'**
  String get settingsClientDownloadIntro;

  /// No description provided for @settingsClientDownloadAccelSection.
  ///
  /// In zh, this message translates to:
  /// **'下载加速'**
  String get settingsClientDownloadAccelSection;

  /// No description provided for @settingsClientDownloadGithubProxy.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 加速代理'**
  String get settingsClientDownloadGithubProxy;

  /// No description provided for @settingsClientDownloadProxyNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置（直连 GitHub，国内可能较慢）'**
  String get settingsClientDownloadProxyNotConfigured;

  /// No description provided for @settingsClientDownloadStandardSection.
  ///
  /// In zh, this message translates to:
  /// **'标准版 · 连接当前服务器'**
  String get settingsClientDownloadStandardSection;

  /// No description provided for @settingsClientDownloadBundleSection.
  ///
  /// In zh, this message translates to:
  /// **'Bundle 版 · 内嵌后端，无需服务器'**
  String get settingsClientDownloadBundleSection;

  /// No description provided for @settingsClientDownloadStandardAllVersions.
  ///
  /// In zh, this message translates to:
  /// **'标准版全部版本'**
  String get settingsClientDownloadStandardAllVersions;

  /// No description provided for @settingsClientDownloadBundleAllVersions.
  ///
  /// In zh, this message translates to:
  /// **'Bundle 版全部版本'**
  String get settingsClientDownloadBundleAllVersions;

  /// No description provided for @settingsClientDownloadRecommendFor.
  ///
  /// In zh, this message translates to:
  /// **'为你的设备推荐：{os}'**
  String settingsClientDownloadRecommendFor(String os);

  /// No description provided for @settingsClientDownloadStandardBtn.
  ///
  /// In zh, this message translates to:
  /// **'标准版（{label}）'**
  String settingsClientDownloadStandardBtn(String label);

  /// No description provided for @settingsClientDownloadBundleBtn.
  ///
  /// In zh, this message translates to:
  /// **'Bundle 版（{label}）'**
  String settingsClientDownloadBundleBtn(String label);

  /// No description provided for @settingsClientDownloadNoteUnsigned.
  ///
  /// In zh, this message translates to:
  /// **'未签名，需自行侧载'**
  String get settingsClientDownloadNoteUnsigned;

  /// No description provided for @settingsClientDownloadProxyDialogDesc.
  ///
  /// In zh, this message translates to:
  /// **'国内访问 GitHub 较慢时可选择镜像加速。此设置与「检查更新」共用。'**
  String get settingsClientDownloadProxyDialogDesc;

  /// No description provided for @settingsClientDownloadCustomProxy.
  ///
  /// In zh, this message translates to:
  /// **'自定义代理'**
  String get settingsClientDownloadCustomProxy;

  /// No description provided for @settingsClientDownloadCustomProxyHelper.
  ///
  /// In zh, this message translates to:
  /// **'输入代理地址，如 https://ghproxy.com/'**
  String get settingsClientDownloadCustomProxyHelper;

  /// No description provided for @settingsClientDownloadSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get settingsClientDownloadSave;

  /// No description provided for @settingsTabConfigTitle.
  ///
  /// In zh, this message translates to:
  /// **'菜单设置'**
  String get settingsTabConfigTitle;

  /// No description provided for @settingsTabConfigBuiltInSection.
  ///
  /// In zh, this message translates to:
  /// **'内置页面'**
  String get settingsTabConfigBuiltInSection;

  /// No description provided for @settingsTabConfigLibrary.
  ///
  /// In zh, this message translates to:
  /// **'曲库'**
  String get settingsTabConfigLibrary;

  /// No description provided for @settingsTabConfigPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'歌单'**
  String get settingsTabConfigPlaylists;

  /// No description provided for @settingsTabConfigPluginEntry.
  ///
  /// In zh, this message translates to:
  /// **'插件入口'**
  String get settingsTabConfigPluginEntry;

  /// No description provided for @settingsTabConfigNoPlugins.
  ///
  /// In zh, this message translates to:
  /// **'暂无可用插件'**
  String get settingsTabConfigNoPlugins;

  /// No description provided for @settingsTabConfigNoPluginsHint.
  ///
  /// In zh, this message translates to:
  /// **'请先在设置中安装并启用插件'**
  String get settingsTabConfigNoPluginsHint;

  /// No description provided for @settingsTabConfigPluginOrder.
  ///
  /// In zh, this message translates to:
  /// **'插件排序'**
  String get settingsTabConfigPluginOrder;

  /// No description provided for @settingsTabConfigEnabledCount.
  ///
  /// In zh, this message translates to:
  /// **'已启用 {count} 个标签（首页和设置固定显示）'**
  String settingsTabConfigEnabledCount(int count);

  /// No description provided for @settingsTabConfigCollapseHint.
  ///
  /// In zh, this message translates to:
  /// **'移动端超出 5 个时将折叠到「更多」菜单'**
  String get settingsTabConfigCollapseHint;

  /// No description provided for @settingsTabConfigMaxTabs.
  ///
  /// In zh, this message translates to:
  /// **'最多显示 {count} 个标签'**
  String settingsTabConfigMaxTabs(int count);

  /// No description provided for @settingsTabConfigSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败: {error}'**
  String settingsTabConfigSaveFailed(String error);

  /// No description provided for @settingsUpgradeStatusStable.
  ///
  /// In zh, this message translates to:
  /// **'稳定版'**
  String get settingsUpgradeStatusStable;

  /// No description provided for @settingsUpgradeStatusDev.
  ///
  /// In zh, this message translates to:
  /// **'开发版'**
  String get settingsUpgradeStatusDev;

  /// No description provided for @settingsUpgradeStatusDownloading.
  ///
  /// In zh, this message translates to:
  /// **'正在下载...'**
  String get settingsUpgradeStatusDownloading;

  /// No description provided for @settingsUpgradeStatusTesting.
  ///
  /// In zh, this message translates to:
  /// **'正在验证...'**
  String get settingsUpgradeStatusTesting;

  /// No description provided for @settingsUpgradeStatusReplacing.
  ///
  /// In zh, this message translates to:
  /// **'正在替换...'**
  String get settingsUpgradeStatusReplacing;

  /// No description provided for @settingsUpgradeStatusResetting.
  ///
  /// In zh, this message translates to:
  /// **'正在回退...'**
  String get settingsUpgradeStatusResetting;

  /// No description provided for @settingsUpgradeStatusRestarting.
  ///
  /// In zh, this message translates to:
  /// **'正在重启...'**
  String get settingsUpgradeStatusRestarting;

  /// No description provided for @settingsUpgradeStatusCompleted.
  ///
  /// In zh, this message translates to:
  /// **'升级完成'**
  String get settingsUpgradeStatusCompleted;

  /// No description provided for @settingsUpgradeStatusFailed.
  ///
  /// In zh, this message translates to:
  /// **'升级失败'**
  String get settingsUpgradeStatusFailed;

  /// No description provided for @settingsUpgradeStatusIdle.
  ///
  /// In zh, this message translates to:
  /// **'空闲'**
  String get settingsUpgradeStatusIdle;

  /// No description provided for @settingsFrontendVerDevVersion.
  ///
  /// In zh, this message translates to:
  /// **'开发版本'**
  String get settingsFrontendVerDevVersion;

  /// No description provided for @settingsFrontendVerCheckFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查前端更新失败: {error}'**
  String settingsFrontendVerCheckFailed(String error);

  /// No description provided for @settingsScanScanFailed.
  ///
  /// In zh, this message translates to:
  /// **'扫描失败: {error}'**
  String settingsScanScanFailed(String error);

  /// No description provided for @settingsScanCancelFailed.
  ///
  /// In zh, this message translates to:
  /// **'取消失败: {error}'**
  String settingsScanCancelFailed(String error);

  /// No description provided for @settingsScanModeSkipDesc.
  ///
  /// In zh, this message translates to:
  /// **'仅导入新发现的音乐文件'**
  String get settingsScanModeSkipDesc;

  /// No description provided for @settingsScanModeReimportDesc.
  ///
  /// In zh, this message translates to:
  /// **'重新扫描并覆盖所有音乐信息'**
  String get settingsScanModeReimportDesc;

  /// No description provided for @settingsScanDismiss.
  ///
  /// In zh, this message translates to:
  /// **'关闭提示'**
  String get settingsScanDismiss;

  /// No description provided for @settingsScanExcludeDirTitle.
  ///
  /// In zh, this message translates to:
  /// **'排除目录设置'**
  String get settingsScanExcludeDirTitle;

  /// No description provided for @settingsScanExcludeDirSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'配置扫描时需要忽略的目录'**
  String get settingsScanExcludeDirSubtitle;

  /// No description provided for @settingsScanModeSkip.
  ///
  /// In zh, this message translates to:
  /// **'跳过已存在'**
  String get settingsScanModeSkip;

  /// No description provided for @settingsScanModeReimport.
  ///
  /// In zh, this message translates to:
  /// **'重新导入'**
  String get settingsScanModeReimport;

  /// No description provided for @settingsScanStarting.
  ///
  /// In zh, this message translates to:
  /// **'正在启动...'**
  String get settingsScanStarting;

  /// No description provided for @settingsScanScanLocal.
  ///
  /// In zh, this message translates to:
  /// **'扫描本地音乐'**
  String get settingsScanScanLocal;

  /// No description provided for @settingsScanScanSelectedDirs.
  ///
  /// In zh, this message translates to:
  /// **'扫描选中的 {count} 个目录'**
  String settingsScanScanSelectedDirs(int count);

  /// No description provided for @settingsScanTargetDirsTitle.
  ///
  /// In zh, this message translates to:
  /// **'指定目录（可选）'**
  String get settingsScanTargetDirsTitle;

  /// No description provided for @settingsScanTargetDirsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'仅扫描选中的目录，留空则扫描整个音乐库'**
  String get settingsScanTargetDirsSubtitle;

  /// No description provided for @settingsScanTargetDirsSelected.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 个目录'**
  String settingsScanTargetDirsSelected(int count);

  /// No description provided for @settingsScanDirsToScan.
  ///
  /// In zh, this message translates to:
  /// **'将扫描的目录:'**
  String get settingsScanDirsToScan;

  /// No description provided for @settingsScanClear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get settingsScanClear;

  /// No description provided for @settingsScanCreatingPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'正在按目录自动创建歌单...'**
  String get settingsScanCreatingPlaylists;

  /// No description provided for @settingsScanSplittingCue.
  ///
  /// In zh, this message translates to:
  /// **'正在切分整轨(CUE)...'**
  String get settingsScanSplittingCue;

  /// No description provided for @settingsScanSplittingCueProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在切分整轨(CUE): 已处理 {count} 个来源'**
  String settingsScanSplittingCueProgress(int count);

  /// No description provided for @settingsScanDiscovering.
  ///
  /// In zh, this message translates to:
  /// **'正在发现文件...'**
  String get settingsScanDiscovering;

  /// No description provided for @settingsScanDiscoveringProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在发现文件: 已发现 {count} 个'**
  String settingsScanDiscoveringProgress(int count);

  /// No description provided for @settingsScanScanningFile.
  ///
  /// In zh, this message translates to:
  /// **'正在扫描: {file}'**
  String settingsScanScanningFile(String file);

  /// No description provided for @settingsScanProgressStats.
  ///
  /// In zh, this message translates to:
  /// **'已处理: {scanned}/{total}, 导入: {imported}, 跳过: {skipped}, 失败: {failed}'**
  String settingsScanProgressStats(
    int scanned,
    int total,
    int imported,
    int skipped,
    int failed,
  );

  /// No description provided for @settingsScanCancelScan.
  ///
  /// In zh, this message translates to:
  /// **'取消扫描'**
  String get settingsScanCancelScan;

  /// No description provided for @settingsScanAutoCreatePlaylists.
  ///
  /// In zh, this message translates to:
  /// **'扫描后自动创建歌单'**
  String get settingsScanAutoCreatePlaylists;

  /// No description provided for @settingsScanAutoCreatePlaylistsDesc.
  ///
  /// In zh, this message translates to:
  /// **'按目录结构自动生成歌单'**
  String get settingsScanAutoCreatePlaylistsDesc;

  /// No description provided for @settingsScanLoadingConfig.
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get settingsScanLoadingConfig;

  /// No description provided for @settingsScanReadConfigFailed.
  ///
  /// In zh, this message translates to:
  /// **'读取配置失败'**
  String get settingsScanReadConfigFailed;

  /// No description provided for @settingsScanSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败: {error}'**
  String settingsScanSaveFailed(String error);

  /// No description provided for @settingsScanPlaylistModeDirectory.
  ///
  /// In zh, this message translates to:
  /// **'按文件夹'**
  String get settingsScanPlaylistModeDirectory;

  /// No description provided for @settingsScanPlaylistModeDirectoryDesc.
  ///
  /// In zh, this message translates to:
  /// **'每个文件夹生成独立歌单'**
  String get settingsScanPlaylistModeDirectoryDesc;

  /// No description provided for @settingsScanPlaylistModeTopLevel.
  ///
  /// In zh, this message translates to:
  /// **'按顶层文件夹'**
  String get settingsScanPlaylistModeTopLevel;

  /// No description provided for @settingsScanPlaylistModeTopLevelDesc.
  ///
  /// In zh, this message translates to:
  /// **'子文件夹的歌曲合并到一级文件夹歌单'**
  String get settingsScanPlaylistModeTopLevelDesc;

  /// No description provided for @settingsScanPlaylistModeBubbleUp.
  ///
  /// In zh, this message translates to:
  /// **'包含子目录'**
  String get settingsScanPlaylistModeBubbleUp;

  /// No description provided for @settingsScanPlaylistModeBubbleUpDesc.
  ///
  /// In zh, this message translates to:
  /// **'歌曲同时出现在所有上级文件夹歌单'**
  String get settingsScanPlaylistModeBubbleUpDesc;

  /// No description provided for @settingsScanPlaylistModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'歌单创建方式'**
  String get settingsScanPlaylistModeTitle;

  /// No description provided for @settingsScanPlaylistModeDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已关闭自动创建歌单，此项不生效'**
  String get settingsScanPlaylistModeDisabled;

  /// No description provided for @settingsScanTitleSource.
  ///
  /// In zh, this message translates to:
  /// **'使用文件名作为标题'**
  String get settingsScanTitleSource;

  /// No description provided for @settingsScanTitleSourceFilenameDesc.
  ///
  /// In zh, this message translates to:
  /// **'歌曲标题使用文件名（不含扩展名），适合文件名已编号的情况'**
  String get settingsScanTitleSourceFilenameDesc;

  /// No description provided for @settingsScanTitleSourceTagDesc.
  ///
  /// In zh, this message translates to:
  /// **'歌曲标题优先使用音频标签信息'**
  String get settingsScanTitleSourceTagDesc;

  /// No description provided for @settingsScanTitleSourceSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存，需以「重新导入」模式扫描后生效'**
  String get settingsScanTitleSourceSaved;

  /// No description provided for @settingsScanInterval10Min.
  ///
  /// In zh, this message translates to:
  /// **'10 分钟'**
  String get settingsScanInterval10Min;

  /// No description provided for @settingsScanInterval30Min.
  ///
  /// In zh, this message translates to:
  /// **'30 分钟'**
  String get settingsScanInterval30Min;

  /// No description provided for @settingsScanInterval1Hour.
  ///
  /// In zh, this message translates to:
  /// **'1 小时'**
  String get settingsScanInterval1Hour;

  /// No description provided for @settingsScanInterval3Hour.
  ///
  /// In zh, this message translates to:
  /// **'3 小时'**
  String get settingsScanInterval3Hour;

  /// No description provided for @settingsScanInterval6Hour.
  ///
  /// In zh, this message translates to:
  /// **'6 小时'**
  String get settingsScanInterval6Hour;

  /// No description provided for @settingsScanInterval12Hour.
  ///
  /// In zh, this message translates to:
  /// **'12 小时'**
  String get settingsScanInterval12Hour;

  /// No description provided for @settingsScanInterval24Hour.
  ///
  /// In zh, this message translates to:
  /// **'24 小时'**
  String get settingsScanInterval24Hour;

  /// No description provided for @settingsScanIntervalSeconds.
  ///
  /// In zh, this message translates to:
  /// **'{count} 秒'**
  String settingsScanIntervalSeconds(int count);

  /// No description provided for @settingsScanAutoScan.
  ///
  /// In zh, this message translates to:
  /// **'自动扫描'**
  String get settingsScanAutoScan;

  /// No description provided for @settingsScanAutoScanInterval.
  ///
  /// In zh, this message translates to:
  /// **'每 {interval} 自动扫描一次'**
  String settingsScanAutoScanInterval(String interval);

  /// No description provided for @settingsScanAutoScanOff.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get settingsScanAutoScanOff;

  /// No description provided for @settingsScanScanInterval.
  ///
  /// In zh, this message translates to:
  /// **'扫描间隔'**
  String get settingsScanScanInterval;

  /// No description provided for @settingsScanCompletedSummary.
  ///
  /// In zh, this message translates to:
  /// **'扫描完成，本地歌曲共 {count} 首'**
  String settingsScanCompletedSummary(int count);

  /// No description provided for @settingsScanCompletedStats.
  ///
  /// In zh, this message translates to:
  /// **'本次导入 {imported} 首，跳过 {skipped} 首，失败 {failed} 个'**
  String settingsScanCompletedStats(int imported, int skipped, int failed);

  /// No description provided for @settingsScanRescan.
  ///
  /// In zh, this message translates to:
  /// **'重新扫描'**
  String get settingsScanRescan;

  /// No description provided for @settingsScanCancelledSummary.
  ///
  /// In zh, this message translates to:
  /// **'扫描已取消 (已处理 {count} 个文件)'**
  String settingsScanCancelledSummary(int count);

  /// No description provided for @settingsScanErrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'扫描出错'**
  String get settingsScanErrorTitle;

  /// No description provided for @settingsExcludeDirLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载配置失败: {error}'**
  String settingsExcludeDirLoadFailed(String error);

  /// No description provided for @settingsExcludeDirSaved.
  ///
  /// In zh, this message translates to:
  /// **'排除目录配置已保存，后台正在清理被排除目录中的歌曲'**
  String get settingsExcludeDirSaved;

  /// No description provided for @settingsExcludeDirSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败: {error}'**
  String settingsExcludeDirSaveFailed(String error);

  /// No description provided for @settingsExcludeDirTabName.
  ///
  /// In zh, this message translates to:
  /// **'名称排除'**
  String get settingsExcludeDirTabName;

  /// No description provided for @settingsExcludeDirTabPath.
  ///
  /// In zh, this message translates to:
  /// **'路径排除'**
  String get settingsExcludeDirTabPath;

  /// No description provided for @settingsExcludeDirTabPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'歌单排除'**
  String get settingsExcludeDirTabPlaylist;

  /// No description provided for @settingsExcludeDirSaving.
  ///
  /// In zh, this message translates to:
  /// **'保存中...'**
  String get settingsExcludeDirSaving;

  /// No description provided for @settingsExcludeDirSaveConfig.
  ///
  /// In zh, this message translates to:
  /// **'保存排除配置'**
  String get settingsExcludeDirSaveConfig;

  /// No description provided for @settingsExcludeDirSaveHint.
  ///
  /// In zh, this message translates to:
  /// **'保存后将自动清理被排除目录中的已导入歌曲'**
  String get settingsExcludeDirSaveHint;

  /// No description provided for @settingsExcludeDirInputName.
  ///
  /// In zh, this message translates to:
  /// **'输入目录名称'**
  String get settingsExcludeDirInputName;

  /// No description provided for @settingsExcludeDirInputHint.
  ///
  /// In zh, this message translates to:
  /// **'输入并选择或按回车添加'**
  String get settingsExcludeDirInputHint;

  /// No description provided for @settingsExcludeDirLoadingCandidates.
  ///
  /// In zh, this message translates to:
  /// **'正在加载候选列表...'**
  String get settingsExcludeDirLoadingCandidates;

  /// No description provided for @settingsExcludeDirAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get settingsExcludeDirAdd;

  /// No description provided for @settingsExcludeDirExcludedNames.
  ///
  /// In zh, this message translates to:
  /// **'已排除的目录名称:'**
  String get settingsExcludeDirExcludedNames;

  /// No description provided for @settingsExcludeDirNameHint.
  ///
  /// In zh, this message translates to:
  /// **'路径中任何层级包含该名称的目录都会被排除'**
  String get settingsExcludeDirNameHint;

  /// No description provided for @settingsExcludeDirMusicDir.
  ///
  /// In zh, this message translates to:
  /// **'音乐目录: {path}'**
  String settingsExcludeDirMusicDir(String path);

  /// No description provided for @settingsExcludeDirExcludedPaths.
  ///
  /// In zh, this message translates to:
  /// **'已排除的路径:'**
  String get settingsExcludeDirExcludedPaths;

  /// No description provided for @settingsExcludeDirAutoCreateExcluded.
  ///
  /// In zh, this message translates to:
  /// **'自动创建歌单时不纳入的目录:'**
  String get settingsExcludeDirAutoCreateExcluded;

  /// No description provided for @settingsExcludeDirAutoCreateHint.
  ///
  /// In zh, this message translates to:
  /// **'路径中任何层级包含该名称的目录都不会被自动创建歌单'**
  String get settingsExcludeDirAutoCreateHint;

  /// No description provided for @settingsServersTitle.
  ///
  /// In zh, this message translates to:
  /// **'服务器'**
  String get settingsServersTitle;

  /// No description provided for @settingsServersTestAll.
  ///
  /// In zh, this message translates to:
  /// **'全部测试'**
  String get settingsServersTestAll;

  /// No description provided for @settingsServersEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'尚未添加服务器'**
  String get settingsServersEmptyTitle;

  /// No description provided for @settingsServersEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'点击右下角「+」添加 API 地址。\n启动时会按顺序探测，优先使用排在前面的可达项。'**
  String get settingsServersEmptyHint;

  /// No description provided for @settingsServersAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加服务器'**
  String get settingsServersAdd;

  /// No description provided for @settingsServersEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑服务器'**
  String get settingsServersEditTitle;

  /// No description provided for @settingsServersNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'名称（可选）'**
  String get settingsServersNameLabel;

  /// No description provided for @settingsServersNameHint.
  ///
  /// In zh, this message translates to:
  /// **'局域网 / 广域网 / 备用'**
  String get settingsServersNameHint;

  /// No description provided for @settingsServersUrlLabel.
  ///
  /// In zh, this message translates to:
  /// **'API 地址'**
  String get settingsServersUrlLabel;

  /// No description provided for @settingsServersUsername.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get settingsServersUsername;

  /// No description provided for @settingsServersPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get settingsServersPassword;

  /// No description provided for @settingsServersSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get settingsServersSave;

  /// No description provided for @settingsServersSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败: {error}'**
  String settingsServersSaveFailed(String error);

  /// No description provided for @settingsServersDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除服务器'**
  String get settingsServersDeleteTitle;

  /// No description provided for @settingsServersDeleteCurrentConfirm.
  ///
  /// In zh, this message translates to:
  /// **'此为当前正在使用的服务器，删除后下次启动将重新探测列表中其他项。是否继续？'**
  String get settingsServersDeleteCurrentConfirm;

  /// No description provided for @settingsServersDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除「{name}」吗？'**
  String settingsServersDeleteConfirm(String name);

  /// No description provided for @settingsServersReachable.
  ///
  /// In zh, this message translates to:
  /// **'{name} 可达'**
  String settingsServersReachable(String name);

  /// No description provided for @settingsServersUnreachable.
  ///
  /// In zh, this message translates to:
  /// **'{name} 不可达'**
  String settingsServersUnreachable(String name);

  /// No description provided for @settingsServersProbeResult.
  ///
  /// In zh, this message translates to:
  /// **'探测完成：{ok} / {total} 可达'**
  String settingsServersProbeResult(int ok, int total);

  /// No description provided for @settingsServersAlreadyCurrent.
  ///
  /// In zh, this message translates to:
  /// **'已是当前使用的服务器'**
  String get settingsServersAlreadyCurrent;

  /// No description provided for @settingsServersSwitched.
  ///
  /// In zh, this message translates to:
  /// **'已切换到 {name}，请重新登录'**
  String settingsServersSwitched(String name);

  /// No description provided for @settingsServersSwitchTo.
  ///
  /// In zh, this message translates to:
  /// **'切换到此项'**
  String get settingsServersSwitchTo;

  /// No description provided for @settingsServersTestConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get settingsServersTestConnection;

  /// No description provided for @settingsServersEditAction.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get settingsServersEditAction;

  /// No description provided for @settingsServersLocalMode.
  ///
  /// In zh, this message translates to:
  /// **'本地模式'**
  String get settingsServersLocalMode;

  /// No description provided for @settingsServersLocalModeDesc.
  ///
  /// In zh, this message translates to:
  /// **'开启后在设备上运行后端，无需网络即可播放本地音乐。'**
  String get settingsServersLocalModeDesc;

  /// No description provided for @settingsServersMusicDir.
  ///
  /// In zh, this message translates to:
  /// **'音乐目录'**
  String get settingsServersMusicDir;

  /// No description provided for @settingsServersNotSelected.
  ///
  /// In zh, this message translates to:
  /// **'未选择'**
  String get settingsServersNotSelected;

  /// No description provided for @settingsServersSelect.
  ///
  /// In zh, this message translates to:
  /// **'选择'**
  String get settingsServersSelect;

  /// No description provided for @settingsServersFixedMusicDirHint.
  ///
  /// In zh, this message translates to:
  /// **'通过「文件」App 或电脑（Finder / iTunes 文件共享）把音乐放入 Songloft 文件夹，然后重新扫描。'**
  String get settingsServersFixedMusicDirHint;

  /// No description provided for @settingsServersSwitchFailed.
  ///
  /// In zh, this message translates to:
  /// **'切换失败：{error}'**
  String settingsServersSwitchFailed(String error);

  /// No description provided for @settingsServersSwitchedLocal.
  ///
  /// In zh, this message translates to:
  /// **'已切换到本地模式'**
  String get settingsServersSwitchedLocal;

  /// No description provided for @settingsServersMusicDirUpdated.
  ///
  /// In zh, this message translates to:
  /// **'音乐目录已更新'**
  String get settingsServersMusicDirUpdated;

  /// No description provided for @settingsDuplicateTitle.
  ///
  /// In zh, this message translates to:
  /// **'重复歌曲检测'**
  String get settingsDuplicateTitle;

  /// No description provided for @settingsDuplicateDismissError.
  ///
  /// In zh, this message translates to:
  /// **'关闭提示'**
  String get settingsDuplicateDismissError;

  /// No description provided for @settingsDuplicateIntro.
  ///
  /// In zh, this message translates to:
  /// **'通过音频指纹识别内容相同的重复文件。不同文件名、不同格式的同一首歌都能被识别。'**
  String get settingsDuplicateIntro;

  /// No description provided for @settingsDuplicateFingerprintStats.
  ///
  /// In zh, this message translates to:
  /// **'指纹统计'**
  String get settingsDuplicateFingerprintStats;

  /// No description provided for @settingsDuplicateLocalSongs.
  ///
  /// In zh, this message translates to:
  /// **'本地歌曲'**
  String get settingsDuplicateLocalSongs;

  /// No description provided for @settingsDuplicateComputed.
  ///
  /// In zh, this message translates to:
  /// **'已有指纹'**
  String get settingsDuplicateComputed;

  /// No description provided for @settingsDuplicatePending.
  ///
  /// In zh, this message translates to:
  /// **'待计算'**
  String get settingsDuplicatePending;

  /// No description provided for @settingsDuplicateSongCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 首'**
  String settingsDuplicateSongCount(int count);

  /// No description provided for @settingsDuplicateChromaprintMissing.
  ///
  /// In zh, this message translates to:
  /// **'需要安装 ffmpeg（含 chromaprint 支持）才能使用音频指纹检测。Docker 用户升级到最新镜像即可。'**
  String get settingsDuplicateChromaprintMissing;

  /// No description provided for @settingsDuplicateStartCompute.
  ///
  /// In zh, this message translates to:
  /// **'开始计算并检测'**
  String get settingsDuplicateStartCompute;

  /// No description provided for @settingsDuplicateCheck.
  ///
  /// In zh, this message translates to:
  /// **'检测重复'**
  String get settingsDuplicateCheck;

  /// No description provided for @settingsDuplicateRecomputeAll.
  ///
  /// In zh, this message translates to:
  /// **'重新计算全部指纹'**
  String get settingsDuplicateRecomputeAll;

  /// No description provided for @settingsDuplicateComputing.
  ///
  /// In zh, this message translates to:
  /// **'正在计算音频指纹... {computed}/{total}'**
  String settingsDuplicateComputing(int computed, int total);

  /// No description provided for @settingsDuplicateFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败: {count}'**
  String settingsDuplicateFailed(int count);

  /// No description provided for @settingsDuplicateAutoDetect.
  ///
  /// In zh, this message translates to:
  /// **'计算完成后将自动检测重复歌曲'**
  String get settingsDuplicateAutoDetect;

  /// No description provided for @settingsDuplicateRecheck.
  ///
  /// In zh, this message translates to:
  /// **'重新检测'**
  String get settingsDuplicateRecheck;

  /// No description provided for @settingsDuplicateNoResults.
  ///
  /// In zh, this message translates to:
  /// **'未发现重复歌曲'**
  String get settingsDuplicateNoResults;

  /// No description provided for @settingsDuplicateNoResultsHint.
  ///
  /// In zh, this message translates to:
  /// **'音乐库很干净！'**
  String get settingsDuplicateNoResultsHint;

  /// No description provided for @settingsDuplicateSummary.
  ///
  /// In zh, this message translates to:
  /// **'发现 {groups} 组重复（共 {songs} 首歌曲）'**
  String settingsDuplicateSummary(int groups, int songs);

  /// No description provided for @settingsDuplicateIgnoredCount.
  ///
  /// In zh, this message translates to:
  /// **'已忽略 {count} 组'**
  String settingsDuplicateIgnoredCount(int count);

  /// No description provided for @settingsDuplicateCleanAll.
  ///
  /// In zh, this message translates to:
  /// **'清理全部重复（删除 {count} 首）'**
  String settingsDuplicateCleanAll(int count);

  /// No description provided for @settingsDuplicateGroupLabel.
  ///
  /// In zh, this message translates to:
  /// **'重复组 {index}'**
  String settingsDuplicateGroupLabel(int index);

  /// No description provided for @settingsDuplicateUnignore.
  ///
  /// In zh, this message translates to:
  /// **'取消忽略'**
  String get settingsDuplicateUnignore;

  /// No description provided for @settingsDuplicateIgnore.
  ///
  /// In zh, this message translates to:
  /// **'忽略此组'**
  String get settingsDuplicateIgnore;

  /// No description provided for @settingsDuplicateDeleteUnselected.
  ///
  /// In zh, this message translates to:
  /// **'删除未选中'**
  String get settingsDuplicateDeleteUnselected;

  /// No description provided for @settingsDuplicateRecommended.
  ///
  /// In zh, this message translates to:
  /// **'推荐'**
  String get settingsDuplicateRecommended;

  /// No description provided for @settingsDuplicateConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get settingsDuplicateConfirmTitle;

  /// No description provided for @settingsDuplicateConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'将删除 {count} 首重复歌曲及其对应的音频文件，保留每组中选中的版本。此操作不可撤销。'**
  String settingsDuplicateConfirmMessage(int count);

  /// No description provided for @settingsDuplicateDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除 {count} 首重复歌曲'**
  String settingsDuplicateDeleted(int count);

  /// No description provided for @settingsDuplicateDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败: {error}'**
  String settingsDuplicateDeleteFailed(String error);

  /// No description provided for @settingsCategoryAppearanceTitle.
  ///
  /// In zh, this message translates to:
  /// **'外观设置'**
  String get settingsCategoryAppearanceTitle;

  /// No description provided for @settingsCategoryAppearanceSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'主题、菜单和显示'**
  String get settingsCategoryAppearanceSubtitle;

  /// No description provided for @settingsCategoryPlaybackTitle.
  ///
  /// In zh, this message translates to:
  /// **'播放设置'**
  String get settingsCategoryPlaybackTitle;

  /// No description provided for @settingsCategoryPlaybackSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'音质'**
  String get settingsCategoryPlaybackSubtitle;

  /// No description provided for @settingsCategoryLibraryTitle.
  ///
  /// In zh, this message translates to:
  /// **'音乐库管理'**
  String get settingsCategoryLibraryTitle;

  /// No description provided for @settingsCategoryLibrarySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'扫描、导入和转换'**
  String get settingsCategoryLibrarySubtitle;

  /// No description provided for @settingsCategoryExtensionsTitle.
  ///
  /// In zh, this message translates to:
  /// **'扩展'**
  String get settingsCategoryExtensionsTitle;

  /// No description provided for @settingsCategoryExtensionsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'插件管理'**
  String get settingsCategoryExtensionsSubtitle;

  /// No description provided for @settingsCategoryCacheTitle.
  ///
  /// In zh, this message translates to:
  /// **'缓存管理'**
  String get settingsCategoryCacheTitle;

  /// No description provided for @settingsCategoryCacheSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'服务端和本地缓存'**
  String get settingsCategoryCacheSubtitle;

  /// No description provided for @settingsCategoryNetworkTitle.
  ///
  /// In zh, this message translates to:
  /// **'网络设置'**
  String get settingsCategoryNetworkTitle;

  /// No description provided for @settingsCategoryNetworkSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'代理配置'**
  String get settingsCategoryNetworkSubtitle;

  /// No description provided for @settingsCategoryDataTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据管理'**
  String get settingsCategoryDataTitle;

  /// No description provided for @settingsCategoryDataSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'歌单导出与导入'**
  String get settingsCategoryDataSubtitle;

  /// No description provided for @settingsCategoryAboutTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于与更新'**
  String get settingsCategoryAboutTitle;

  /// No description provided for @settingsCategoryAboutSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'版本和日志'**
  String get settingsCategoryAboutSubtitle;

  /// No description provided for @settingsCategoryAccountTitle.
  ///
  /// In zh, this message translates to:
  /// **'账户'**
  String get settingsCategoryAccountTitle;

  /// No description provided for @settingsCategoryAccountSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'服务器和登录'**
  String get settingsCategoryAccountSubtitle;

  /// No description provided for @settingsDevVersion.
  ///
  /// In zh, this message translates to:
  /// **'开发版'**
  String get settingsDevVersion;

  /// No description provided for @settingsStableVersion.
  ///
  /// In zh, this message translates to:
  /// **'正式版'**
  String get settingsStableVersion;

  /// No description provided for @settingsLocalMode.
  ///
  /// In zh, this message translates to:
  /// **'本地模式'**
  String get settingsLocalMode;

  /// No description provided for @settingsManage.
  ///
  /// In zh, this message translates to:
  /// **'管理'**
  String get settingsManage;

  /// No description provided for @settingsMenuTitle.
  ///
  /// In zh, this message translates to:
  /// **'菜单设置'**
  String get settingsMenuTitle;

  /// No description provided for @settingsMenuLibrary.
  ///
  /// In zh, this message translates to:
  /// **'曲库'**
  String get settingsMenuLibrary;

  /// No description provided for @settingsMenuPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'歌单'**
  String get settingsMenuPlaylists;

  /// No description provided for @settingsTabsEnabledCount.
  ///
  /// In zh, this message translates to:
  /// **'已启用 {count} 个标签（首页和设置固定显示）'**
  String settingsTabsEnabledCount(int count);

  /// No description provided for @settingsTabsCollapseHint.
  ///
  /// In zh, this message translates to:
  /// **'移动端超出 5 个时将折叠到「更多」菜单'**
  String get settingsTabsCollapseHint;

  /// No description provided for @settingsMaxTabsLimit.
  ///
  /// In zh, this message translates to:
  /// **'最多显示 {count} 个标签'**
  String settingsMaxTabsLimit(int count);

  /// No description provided for @settingsSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败: {error}'**
  String settingsSaveFailed(String error);

  /// No description provided for @settingsQualityOriginal.
  ///
  /// In zh, this message translates to:
  /// **'原始音质'**
  String get settingsQualityOriginal;

  /// No description provided for @settingsQualityLow.
  ///
  /// In zh, this message translates to:
  /// **'低 (128kbps)'**
  String get settingsQualityLow;

  /// No description provided for @settingsQualityMedium.
  ///
  /// In zh, this message translates to:
  /// **'中 (192kbps)'**
  String get settingsQualityMedium;

  /// No description provided for @settingsQualityHigh.
  ///
  /// In zh, this message translates to:
  /// **'高 (320kbps)'**
  String get settingsQualityHigh;

  /// No description provided for @settingsQualityTitle.
  ///
  /// In zh, this message translates to:
  /// **'音质'**
  String get settingsQualityTitle;

  /// No description provided for @settingsQualityDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择音质'**
  String get settingsQualityDialogTitle;

  /// No description provided for @settingsQualityOriginalDesc.
  ///
  /// In zh, this message translates to:
  /// **'不转码，使用文件原始码率'**
  String get settingsQualityOriginalDesc;

  /// No description provided for @settingsQualityTranscodeDesc.
  ///
  /// In zh, this message translates to:
  /// **'转码为 MP3，适合弱网环境'**
  String get settingsQualityTranscodeDesc;

  /// No description provided for @settingsAutoPlayOnLaunchTitle.
  ///
  /// In zh, this message translates to:
  /// **'打开后自动播放'**
  String get settingsAutoPlayOnLaunchTitle;

  /// No description provided for @settingsAutoPlayOnLaunchDesc.
  ///
  /// In zh, this message translates to:
  /// **'启动客户端后自动继续上次的播放'**
  String get settingsAutoPlayOnLaunchDesc;

  /// No description provided for @settingsAutoEnterLyricsOnLaunchTitle.
  ///
  /// In zh, this message translates to:
  /// **'打开后自动进入歌词'**
  String get settingsAutoEnterLyricsOnLaunchTitle;

  /// No description provided for @settingsAutoEnterLyricsOnLaunchDesc.
  ///
  /// In zh, this message translates to:
  /// **'启动客户端后自动进入全屏歌词界面（按屏幕自动适配）'**
  String get settingsAutoEnterLyricsOnLaunchDesc;

  /// No description provided for @settingsNotificationLyricInTitleTitle.
  ///
  /// In zh, this message translates to:
  /// **'通知栏歌词占用标题行'**
  String get settingsNotificationLyricInTitleTitle;

  /// No description provided for @settingsNotificationLyricInTitleDesc.
  ///
  /// In zh, this message translates to:
  /// **'开启：标题行显示歌词、歌名归副标题；关闭：标题行显示歌名、副标题显示歌词'**
  String get settingsNotificationLyricInTitleDesc;

  /// No description provided for @settingsShortcutsEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'键盘快捷键'**
  String get settingsShortcutsEntryTitle;

  /// No description provided for @settingsShortcutsEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义播放控制按键'**
  String get settingsShortcutsEntrySubtitle;

  /// No description provided for @settingsShortcutsPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'键盘快捷键'**
  String get settingsShortcutsPageTitle;

  /// No description provided for @settingsShortcutsEnableTitle.
  ///
  /// In zh, this message translates to:
  /// **'启用键盘快捷键'**
  String get settingsShortcutsEnableTitle;

  /// No description provided for @settingsShortcutsEnableSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在桌面窗口内使用快捷键控制播放'**
  String get settingsShortcutsEnableSubtitle;

  /// No description provided for @settingsShortcutActionPlayPause.
  ///
  /// In zh, this message translates to:
  /// **'播放 / 暂停'**
  String get settingsShortcutActionPlayPause;

  /// No description provided for @settingsShortcutActionPlayNext.
  ///
  /// In zh, this message translates to:
  /// **'下一首'**
  String get settingsShortcutActionPlayNext;

  /// No description provided for @settingsShortcutActionPlayPrev.
  ///
  /// In zh, this message translates to:
  /// **'上一首'**
  String get settingsShortcutActionPlayPrev;

  /// No description provided for @settingsShortcutActionSeekForward.
  ///
  /// In zh, this message translates to:
  /// **'快进'**
  String get settingsShortcutActionSeekForward;

  /// No description provided for @settingsShortcutActionSeekBackward.
  ///
  /// In zh, this message translates to:
  /// **'快退'**
  String get settingsShortcutActionSeekBackward;

  /// No description provided for @settingsShortcutActionVolumeUp.
  ///
  /// In zh, this message translates to:
  /// **'音量 +'**
  String get settingsShortcutActionVolumeUp;

  /// No description provided for @settingsShortcutActionVolumeDown.
  ///
  /// In zh, this message translates to:
  /// **'音量 -'**
  String get settingsShortcutActionVolumeDown;

  /// No description provided for @settingsShortcutActionToggleMute.
  ///
  /// In zh, this message translates to:
  /// **'静音切换'**
  String get settingsShortcutActionToggleMute;

  /// No description provided for @settingsShortcutRecordPrompt.
  ///
  /// In zh, this message translates to:
  /// **'请按下快捷键组合…'**
  String get settingsShortcutRecordPrompt;

  /// No description provided for @settingsShortcutUnset.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get settingsShortcutUnset;

  /// No description provided for @settingsShortcutConflictTitle.
  ///
  /// In zh, this message translates to:
  /// **'快捷键冲突'**
  String get settingsShortcutConflictTitle;

  /// No description provided for @settingsShortcutConflict.
  ///
  /// In zh, this message translates to:
  /// **'该组合键已被「{action}」占用'**
  String settingsShortcutConflict(String action);

  /// No description provided for @settingsShortcutOverride.
  ///
  /// In zh, this message translates to:
  /// **'覆盖'**
  String get settingsShortcutOverride;

  /// No description provided for @settingsShortcutClear.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get settingsShortcutClear;

  /// No description provided for @settingsShortcutResetAll.
  ///
  /// In zh, this message translates to:
  /// **'恢复全部默认'**
  String get settingsShortcutResetAll;

  /// No description provided for @settingsShortcutResetAllConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要将所有快捷键恢复为默认值吗？'**
  String get settingsShortcutResetAllConfirm;

  /// No description provided for @settingsQualitySwitched.
  ///
  /// In zh, this message translates to:
  /// **'音质已切换为{quality}'**
  String settingsQualitySwitched(String quality);

  /// No description provided for @settingsSwitchFailed.
  ///
  /// In zh, this message translates to:
  /// **'切换失败: {error}'**
  String settingsSwitchFailed(String error);

  /// No description provided for @settingsLibraryDuplicateTitle.
  ///
  /// In zh, this message translates to:
  /// **'重复歌曲检测'**
  String get settingsLibraryDuplicateTitle;

  /// No description provided for @settingsLibraryDuplicateSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'通过音频指纹识别内容相同的重复文件'**
  String get settingsLibraryDuplicateSubtitle;

  /// No description provided for @settingsPluginStoreTitle.
  ///
  /// In zh, this message translates to:
  /// **'插件商店'**
  String get settingsPluginStoreTitle;

  /// No description provided for @settingsPluginStoreSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'浏览和安装插件'**
  String get settingsPluginStoreSubtitle;

  /// No description provided for @settingsExportPlaylistTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出歌单'**
  String get settingsExportPlaylistTitle;

  /// No description provided for @settingsExportPlaylistSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'将所有歌单数据备份为 JSON 文件'**
  String get settingsExportPlaylistSubtitle;

  /// No description provided for @settingsImportPlaylistTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入歌单'**
  String get settingsImportPlaylistTitle;

  /// No description provided for @settingsImportPlaylistSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'从 JSON 备份文件还原歌单数据'**
  String get settingsImportPlaylistSubtitle;

  /// No description provided for @settingsDownloadAppTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载客户端 App'**
  String get settingsDownloadAppTitle;

  /// No description provided for @settingsDownloadAppSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'获取手机 / 桌面原生客户端，支持后台播放、缓存等'**
  String get settingsDownloadAppSubtitle;

  /// No description provided for @settingsWebDebugConsoleTitle.
  ///
  /// In zh, this message translates to:
  /// **'调试控制台'**
  String get settingsWebDebugConsoleTitle;

  /// No description provided for @settingsWebDebugConsoleSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'启用 NextConsole 网页调试面板（需刷新页面）'**
  String get settingsWebDebugConsoleSubtitle;

  /// No description provided for @settingsWebDebugConsoleEnabled.
  ///
  /// In zh, this message translates to:
  /// **'调试控制台已启用，页面将刷新'**
  String get settingsWebDebugConsoleEnabled;

  /// No description provided for @settingsWebDebugConsoleDisabled.
  ///
  /// In zh, this message translates to:
  /// **'调试控制台已关闭，页面将刷新'**
  String get settingsWebDebugConsoleDisabled;

  /// No description provided for @settingsAboutTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsAboutTitle;

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'版本信息和许可证'**
  String get settingsAboutSubtitle;

  /// No description provided for @settingsAccountServer.
  ///
  /// In zh, this message translates to:
  /// **'服务器'**
  String get settingsAccountServer;

  /// No description provided for @settingsNoMusicDir.
  ///
  /// In zh, this message translates to:
  /// **'未选择音乐目录'**
  String get settingsNoMusicDir;

  /// No description provided for @settingsLogout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get settingsLogout;

  /// No description provided for @settingsLogoutConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认退出'**
  String get settingsLogoutConfirmTitle;

  /// No description provided for @settingsLogoutConfirmContent.
  ///
  /// In zh, this message translates to:
  /// **'确定要退出当前账户吗？'**
  String get settingsLogoutConfirmContent;

  /// No description provided for @settingsLogoutButton.
  ///
  /// In zh, this message translates to:
  /// **'确认退出'**
  String get settingsLogoutButton;

  /// No description provided for @settingsExportNotLoggedIn.
  ///
  /// In zh, this message translates to:
  /// **'未登录，无法导出'**
  String get settingsExportNotLoggedIn;

  /// No description provided for @settingsExportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败: {error}'**
  String settingsExportFailed(String error);

  /// No description provided for @settingsImportReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取文件内容'**
  String get settingsImportReadFailed;

  /// No description provided for @settingsImportPathFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法获取文件路径'**
  String get settingsImportPathFailed;

  /// No description provided for @settingsImportComplete.
  ///
  /// In zh, this message translates to:
  /// **'导入完成: 新建歌单 {created}, 合并歌单 {merged}, 新建歌曲 {songsCreated}, 匹配歌曲 {songsMatched}'**
  String settingsImportComplete(
    Object created,
    Object merged,
    Object songsCreated,
    Object songsMatched,
  );

  /// No description provided for @settingsImportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败: {error}'**
  String settingsImportFailed(String error);

  /// No description provided for @settingsCheckServerUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查服务端更新'**
  String get settingsCheckServerUpdate;

  /// No description provided for @settingsUpdateAvailable.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本: {version}'**
  String settingsUpdateAvailable(String version);

  /// No description provided for @settingsCurrentVersionLatest.
  ///
  /// In zh, this message translates to:
  /// **'当前版本: {version} (已是最新)'**
  String settingsCurrentVersionLatest(String version);

  /// No description provided for @settingsCheckingUpdate.
  ///
  /// In zh, this message translates to:
  /// **'正在检查更新...'**
  String get settingsCheckingUpdate;

  /// No description provided for @settingsCheckUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败'**
  String get settingsCheckUpdateFailed;

  /// No description provided for @settingsCheckClientUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查客户端更新'**
  String get settingsCheckClientUpdate;

  /// No description provided for @settingsCurrentVersion.
  ///
  /// In zh, this message translates to:
  /// **'当前版本: {version}'**
  String settingsCurrentVersion(String version);

  /// No description provided for @settingsHlsProxyTitle.
  ///
  /// In zh, this message translates to:
  /// **'HLS 电台后端代理'**
  String get settingsHlsProxyTitle;

  /// No description provided for @settingsHlsProxySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开启后服务端拉取电台 m3u8 并代理切片,可绕过 Referer 防盗链 / CORS。所有切片走本机带宽,注意流量成本'**
  String get settingsHlsProxySubtitle;

  /// No description provided for @settingsHlsProxyEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启 HLS 代理'**
  String get settingsHlsProxyEnabled;

  /// No description provided for @settingsHlsProxyDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已关闭 HLS 代理'**
  String get settingsHlsProxyDisabled;

  /// No description provided for @settingsInsecureTlsTitle.
  ///
  /// In zh, this message translates to:
  /// **'忽略 SSL 证书校验'**
  String get settingsInsecureTlsTitle;

  /// No description provided for @settingsInsecureTlsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'连接使用自签或无效 HTTPS 证书的服务器时开启。同时对接口请求和音频播放生效'**
  String get settingsInsecureTlsSubtitle;

  /// No description provided for @settingsInsecureTlsEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启忽略证书校验'**
  String get settingsInsecureTlsEnabled;

  /// No description provided for @settingsInsecureTlsDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已关闭忽略证书校验'**
  String get settingsInsecureTlsDisabled;

  /// No description provided for @settingsInsecureTlsWarnTitle.
  ///
  /// In zh, this message translates to:
  /// **'降低安全性'**
  String get settingsInsecureTlsWarnTitle;

  /// No description provided for @settingsInsecureTlsWarnContent.
  ///
  /// In zh, this message translates to:
  /// **'开启后将接受任意 HTTPS 证书，可能遭受中间人攻击。请仅在信任的内网或自签证书场景使用。确定开启吗？'**
  String get settingsInsecureTlsWarnContent;

  /// No description provided for @settingsHttpProxyTitle.
  ///
  /// In zh, this message translates to:
  /// **'HTTP 代理'**
  String get settingsHttpProxyTitle;

  /// No description provided for @settingsHttpProxyNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置（直连）'**
  String get settingsHttpProxyNotConfigured;

  /// No description provided for @settingsHttpProxyDialogDesc.
  ///
  /// In zh, this message translates to:
  /// **'设置全局 HTTP 代理，所有后端外发请求（插件下载、升级检查等）将通过此代理转发。留空则直连。'**
  String get settingsHttpProxyDialogDesc;

  /// No description provided for @settingsHttpProxyAddressLabel.
  ///
  /// In zh, this message translates to:
  /// **'代理地址'**
  String get settingsHttpProxyAddressLabel;

  /// No description provided for @settingsHttpProxyHelper.
  ///
  /// In zh, this message translates to:
  /// **'支持 HTTP/HTTPS/SOCKS5 代理'**
  String get settingsHttpProxyHelper;

  /// No description provided for @settingsClear.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get settingsClear;

  /// No description provided for @settingsSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get settingsSave;

  /// No description provided for @settingsHttpProxyCleared.
  ///
  /// In zh, this message translates to:
  /// **'已清除 HTTP 代理'**
  String get settingsHttpProxyCleared;

  /// No description provided for @settingsHttpProxySet.
  ///
  /// In zh, this message translates to:
  /// **'HTTP 代理已设置为 {proxy}'**
  String settingsHttpProxySet(String proxy);

  /// No description provided for @settingsLogLevelDebug.
  ///
  /// In zh, this message translates to:
  /// **'Debug（详细，调试用）'**
  String get settingsLogLevelDebug;

  /// No description provided for @settingsLogLevelInfo.
  ///
  /// In zh, this message translates to:
  /// **'Info（默认）'**
  String get settingsLogLevelInfo;

  /// No description provided for @settingsLogLevelWarn.
  ///
  /// In zh, this message translates to:
  /// **'Warn'**
  String get settingsLogLevelWarn;

  /// No description provided for @settingsLogLevelError.
  ///
  /// In zh, this message translates to:
  /// **'Error（仅错误）'**
  String get settingsLogLevelError;

  /// No description provided for @settingsLogLevelTitle.
  ///
  /// In zh, this message translates to:
  /// **'日志等级'**
  String get settingsLogLevelTitle;

  /// No description provided for @settingsLogLevelDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择日志等级'**
  String get settingsLogLevelDialogTitle;

  /// No description provided for @settingsLogLevelSwitched.
  ///
  /// In zh, this message translates to:
  /// **'日志等级已切换为 {level}'**
  String settingsLogLevelSwitched(String level);

  /// No description provided for @settingsExportLogsTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出日志'**
  String get settingsExportLogsTitle;

  /// No description provided for @settingsExportLogsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'打包前后端日志（已脱敏）用于提交问题反馈'**
  String get settingsExportLogsSubtitle;

  /// No description provided for @settingsExportLogsShareSubject.
  ///
  /// In zh, this message translates to:
  /// **'Songloft 日志'**
  String get settingsExportLogsShareSubject;

  /// No description provided for @settingsExportLogsSuccess.
  ///
  /// In zh, this message translates to:
  /// **'日志已打包，请选择分享或保存方式'**
  String get settingsExportLogsSuccess;

  /// No description provided for @settingsExportLogsSuccessNoBackend.
  ///
  /// In zh, this message translates to:
  /// **'已导出前端日志（未获取到后端日志）'**
  String get settingsExportLogsSuccessNoBackend;

  /// No description provided for @settingsExportLogsFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出日志失败: {error}'**
  String settingsExportLogsFailed(String error);

  /// No description provided for @settingsAccountUrlNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置 · 点击添加'**
  String get settingsAccountUrlNotConfigured;

  /// No description provided for @settingsAccountUrlSummary.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个地址 · 当前: {label}'**
  String settingsAccountUrlSummary(int count, String label);

  /// No description provided for @settingsAccountLoading.
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get settingsAccountLoading;

  /// No description provided for @settingsAboutDesc1.
  ///
  /// In zh, this message translates to:
  /// **'Songloft 是一个开源的个人音乐服务器应用。'**
  String get settingsAboutDesc1;

  /// No description provided for @settingsAboutDesc2.
  ///
  /// In zh, this message translates to:
  /// **'支持本地音乐库管理、在线播放和插件扩展。'**
  String get settingsAboutDesc2;

  /// No description provided for @settingsAboutGithubSemantics.
  ///
  /// In zh, this message translates to:
  /// **'打开 GitHub 页面'**
  String get settingsAboutGithubSemantics;

  /// No description provided for @settingsUpgradeCheckTimeout.
  ///
  /// In zh, this message translates to:
  /// **'检查更新超时，请尝试切换代理后重试'**
  String get settingsUpgradeCheckTimeout;

  /// No description provided for @settingsUpgradeCheckFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败: {error}'**
  String settingsUpgradeCheckFailed(String error);

  /// No description provided for @settingsUpgradeChannelDev.
  ///
  /// In zh, this message translates to:
  /// **'开发版'**
  String get settingsUpgradeChannelDev;

  /// No description provided for @settingsUpgradeChannelStable.
  ///
  /// In zh, this message translates to:
  /// **'正式版'**
  String get settingsUpgradeChannelStable;

  /// No description provided for @settingsUpgradeVersionWithDetails.
  ///
  /// In zh, this message translates to:
  /// **'{version} ({details})'**
  String settingsUpgradeVersionWithDetails(String version, String details);

  /// No description provided for @settingsUpgradeStartFailed.
  ///
  /// In zh, this message translates to:
  /// **'启动升级失败: {error}'**
  String settingsUpgradeStartFailed(String error);

  /// No description provided for @settingsUpgradeConfirmReset.
  ///
  /// In zh, this message translates to:
  /// **'确认回退'**
  String get settingsUpgradeConfirmReset;

  /// No description provided for @settingsUpgradeConfirmResetContent.
  ///
  /// In zh, this message translates to:
  /// **'确定要回退到 Docker 镜像的底包版本吗？\n\n回退后服务将自动重启。'**
  String get settingsUpgradeConfirmResetContent;

  /// No description provided for @settingsUpgradeResetFailed.
  ///
  /// In zh, this message translates to:
  /// **'回退失败: {error}'**
  String settingsUpgradeResetFailed(String error);

  /// No description provided for @settingsUpgradeTitle.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get settingsUpgradeTitle;

  /// No description provided for @settingsUpgradeChecking.
  ///
  /// In zh, this message translates to:
  /// **'正在检查更新...'**
  String get settingsUpgradeChecking;

  /// No description provided for @settingsUpgradeGithubProxy.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 代理'**
  String get settingsUpgradeGithubProxy;

  /// No description provided for @settingsUpgradeCustomProxy.
  ///
  /// In zh, this message translates to:
  /// **'自定义代理'**
  String get settingsUpgradeCustomProxy;

  /// No description provided for @settingsUpgradeProxyHelper.
  ///
  /// In zh, this message translates to:
  /// **'输入代理地址，如 https://ghproxy.com/'**
  String get settingsUpgradeProxyHelper;

  /// No description provided for @settingsUpgradeUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get settingsUpgradeUpToDate;

  /// No description provided for @settingsUpgradeCurrentVersion.
  ///
  /// In zh, this message translates to:
  /// **'当前版本: {version}'**
  String settingsUpgradeCurrentVersion(String version);

  /// No description provided for @settingsUpgradeSelectVersion.
  ///
  /// In zh, this message translates to:
  /// **'选择升级版本:'**
  String get settingsUpgradeSelectVersion;

  /// No description provided for @settingsUpgradeBuildTime.
  ///
  /// In zh, this message translates to:
  /// **'构建时间: {time}'**
  String settingsUpgradeBuildTime(String time);

  /// No description provided for @settingsUpgradeReleaseNotes.
  ///
  /// In zh, this message translates to:
  /// **'更新说明:'**
  String get settingsUpgradeReleaseNotes;

  /// No description provided for @settingsUpgradeResetting.
  ///
  /// In zh, this message translates to:
  /// **'正在回退...'**
  String get settingsUpgradeResetting;

  /// No description provided for @settingsUpgradeResetButton.
  ///
  /// In zh, this message translates to:
  /// **'回退到底包版本'**
  String get settingsUpgradeResetButton;

  /// No description provided for @settingsUpgradeCompleted.
  ///
  /// In zh, this message translates to:
  /// **'升级完成'**
  String get settingsUpgradeCompleted;

  /// No description provided for @settingsUpgradeRestartSoon.
  ///
  /// In zh, this message translates to:
  /// **'应用即将重启'**
  String get settingsUpgradeRestartSoon;

  /// No description provided for @settingsUpgradeFailed.
  ///
  /// In zh, this message translates to:
  /// **'升级失败'**
  String get settingsUpgradeFailed;

  /// No description provided for @settingsUpgradeClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get settingsUpgradeClose;

  /// No description provided for @settingsUpgradeRecheck.
  ///
  /// In zh, this message translates to:
  /// **'重新检查'**
  String get settingsUpgradeRecheck;

  /// No description provided for @settingsUpgradeLater.
  ///
  /// In zh, this message translates to:
  /// **'稍后'**
  String get settingsUpgradeLater;

  /// No description provided for @settingsUpgradeGoDownload.
  ///
  /// In zh, this message translates to:
  /// **'前往下载'**
  String get settingsUpgradeGoDownload;

  /// No description provided for @settingsUpgradeUpgradeNow.
  ///
  /// In zh, this message translates to:
  /// **'立即升级'**
  String get settingsUpgradeUpgradeNow;

  /// No description provided for @settingsFrontendUpgradeCheckTimeout.
  ///
  /// In zh, this message translates to:
  /// **'检查更新超时，请尝试切换代理后重试'**
  String get settingsFrontendUpgradeCheckTimeout;

  /// No description provided for @settingsFrontendUpgradeTitle.
  ///
  /// In zh, this message translates to:
  /// **'客户端更新'**
  String get settingsFrontendUpgradeTitle;

  /// No description provided for @settingsFrontendUpgradeChecking.
  ///
  /// In zh, this message translates to:
  /// **'正在检查更新...'**
  String get settingsFrontendUpgradeChecking;

  /// No description provided for @settingsFrontendUpgradeGithubProxy.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 代理'**
  String get settingsFrontendUpgradeGithubProxy;

  /// No description provided for @settingsFrontendUpgradeCustomProxy.
  ///
  /// In zh, this message translates to:
  /// **'自定义代理'**
  String get settingsFrontendUpgradeCustomProxy;

  /// No description provided for @settingsFrontendUpgradeProxyHelper.
  ///
  /// In zh, this message translates to:
  /// **'输入代理地址，如 https://ghproxy.com/'**
  String get settingsFrontendUpgradeProxyHelper;

  /// No description provided for @settingsFrontendUpgradeUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get settingsFrontendUpgradeUpToDate;

  /// No description provided for @settingsFrontendUpgradeCurrentVersion.
  ///
  /// In zh, this message translates to:
  /// **'当前版本: {version}'**
  String settingsFrontendUpgradeCurrentVersion(String version);

  /// No description provided for @settingsFrontendUpgradeLatestVersion.
  ///
  /// In zh, this message translates to:
  /// **'最新版本: {version}'**
  String settingsFrontendUpgradeLatestVersion(String version);

  /// No description provided for @settingsFrontendUpgradePublishedAt.
  ///
  /// In zh, this message translates to:
  /// **'发布时间: {date}'**
  String settingsFrontendUpgradePublishedAt(String date);

  /// No description provided for @settingsFrontendUpgradeReleaseNotes.
  ///
  /// In zh, this message translates to:
  /// **'更新说明:'**
  String get settingsFrontendUpgradeReleaseNotes;

  /// No description provided for @settingsFrontendUpgradeRecheck.
  ///
  /// In zh, this message translates to:
  /// **'重新检查'**
  String get settingsFrontendUpgradeRecheck;

  /// No description provided for @settingsFrontendUpgradeClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get settingsFrontendUpgradeClose;

  /// No description provided for @settingsFrontendUpgradeLater.
  ///
  /// In zh, this message translates to:
  /// **'稍后'**
  String get settingsFrontendUpgradeLater;

  /// No description provided for @settingsFrontendUpgradeGoDownload.
  ///
  /// In zh, this message translates to:
  /// **'前往下载'**
  String get settingsFrontendUpgradeGoDownload;

  /// No description provided for @settingsConfigTitle.
  ///
  /// In zh, this message translates to:
  /// **'配置管理'**
  String get settingsConfigTitle;

  /// No description provided for @settingsConfigSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'管理系统配置项'**
  String get settingsConfigSubtitle;

  /// No description provided for @settingsConfigAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加配置'**
  String get settingsConfigAdd;

  /// No description provided for @settingsConfigRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get settingsConfigRefresh;

  /// No description provided for @settingsConfigEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无配置项'**
  String get settingsConfigEmpty;

  /// No description provided for @settingsConfigEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'点击「添加配置」创建新的配置项'**
  String get settingsConfigEmptyHint;

  /// No description provided for @settingsConfigKeyLabel.
  ///
  /// In zh, this message translates to:
  /// **'配置键'**
  String get settingsConfigKeyLabel;

  /// No description provided for @settingsConfigKeyHint.
  ///
  /// In zh, this message translates to:
  /// **'例如: app.setting.name'**
  String get settingsConfigKeyHint;

  /// No description provided for @settingsConfigKeyRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入配置键'**
  String get settingsConfigKeyRequired;

  /// No description provided for @settingsConfigValueLabel.
  ///
  /// In zh, this message translates to:
  /// **'配置值'**
  String get settingsConfigValueLabel;

  /// No description provided for @settingsConfigValueHint.
  ///
  /// In zh, this message translates to:
  /// **'配置值（支持多行）'**
  String get settingsConfigValueHint;

  /// No description provided for @settingsConfigValueRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入配置值'**
  String get settingsConfigValueRequired;

  /// No description provided for @settingsConfigAddButton.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get settingsConfigAddButton;

  /// No description provided for @settingsConfigAdded.
  ///
  /// In zh, this message translates to:
  /// **'配置已添加'**
  String get settingsConfigAdded;

  /// No description provided for @settingsConfigAddFailed.
  ///
  /// In zh, this message translates to:
  /// **'添加失败: {error}'**
  String settingsConfigAddFailed(String error);

  /// No description provided for @settingsConfigEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑配置: {key}'**
  String settingsConfigEditTitle(String key);

  /// No description provided for @settingsConfigKeyDisplay.
  ///
  /// In zh, this message translates to:
  /// **'配置键: {key}'**
  String settingsConfigKeyDisplay(String key);

  /// No description provided for @settingsConfigSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get settingsConfigSave;

  /// No description provided for @settingsConfigUpdated.
  ///
  /// In zh, this message translates to:
  /// **'配置已更新'**
  String get settingsConfigUpdated;

  /// No description provided for @settingsConfigUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'更新失败: {error}'**
  String settingsConfigUpdateFailed(String error);

  /// No description provided for @settingsConfigConfirmDelete.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get settingsConfigConfirmDelete;

  /// No description provided for @settingsConfigDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除配置 \"{key}\" 吗？'**
  String settingsConfigDeleteConfirm(String key);

  /// No description provided for @settingsConfigDeleted.
  ///
  /// In zh, this message translates to:
  /// **'配置已删除'**
  String get settingsConfigDeleted;

  /// No description provided for @settingsConfigDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败: {error}'**
  String settingsConfigDeleteFailed(String error);

  /// No description provided for @settingsConfigEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get settingsConfigEdit;

  /// No description provided for @settingsTokenTitle.
  ///
  /// In zh, this message translates to:
  /// **'令牌管理'**
  String get settingsTokenTitle;

  /// No description provided for @settingsTokenSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'管理登录令牌'**
  String get settingsTokenSubtitle;

  /// No description provided for @settingsTokenEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无令牌'**
  String get settingsTokenEmpty;

  /// No description provided for @settingsTokenConfirmRevoke.
  ///
  /// In zh, this message translates to:
  /// **'确认撤销'**
  String get settingsTokenConfirmRevoke;

  /// No description provided for @settingsTokenRevokeConfirm.
  ///
  /// In zh, this message translates to:
  /// **'撤销此令牌后，对应的登录会话将失效。确定继续吗？'**
  String get settingsTokenRevokeConfirm;

  /// No description provided for @settingsTokenRevoke.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get settingsTokenRevoke;

  /// No description provided for @settingsTokenRevoked.
  ///
  /// In zh, this message translates to:
  /// **'令牌已撤销'**
  String get settingsTokenRevoked;

  /// No description provided for @settingsTokenRevokeFailed.
  ///
  /// In zh, this message translates to:
  /// **'撤销失败: {error}'**
  String settingsTokenRevokeFailed(String error);

  /// No description provided for @settingsTokenStatusRevoked.
  ///
  /// In zh, this message translates to:
  /// **'已撤销'**
  String get settingsTokenStatusRevoked;

  /// No description provided for @settingsTokenStatusExpired.
  ///
  /// In zh, this message translates to:
  /// **'已过期'**
  String get settingsTokenStatusExpired;

  /// No description provided for @settingsTokenStatusActive.
  ///
  /// In zh, this message translates to:
  /// **'活跃'**
  String get settingsTokenStatusActive;

  /// No description provided for @settingsTokenType.
  ///
  /// In zh, this message translates to:
  /// **'类型: {type}'**
  String settingsTokenType(String type);

  /// No description provided for @settingsTokenTypeAccess.
  ///
  /// In zh, this message translates to:
  /// **'访问令牌'**
  String get settingsTokenTypeAccess;

  /// No description provided for @settingsTokenTypeRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新令牌'**
  String get settingsTokenTypeRefresh;

  /// No description provided for @settingsTokenClient.
  ///
  /// In zh, this message translates to:
  /// **'客户端: {info}'**
  String settingsTokenClient(String info);

  /// No description provided for @settingsTokenExpiresAt.
  ///
  /// In zh, this message translates to:
  /// **'过期时间: {time}'**
  String settingsTokenExpiresAt(String time);

  /// No description provided for @coreTrayOpen.
  ///
  /// In zh, this message translates to:
  /// **'打开 Songloft'**
  String get coreTrayOpen;

  /// No description provided for @coreTrayOpenLogs.
  ///
  /// In zh, this message translates to:
  /// **'打开日志目录'**
  String get coreTrayOpenLogs;

  /// No description provided for @coreTrayExit.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get coreTrayExit;

  /// No description provided for @coreUrlEmpty.
  ///
  /// In zh, this message translates to:
  /// **'URL 不能为空'**
  String get coreUrlEmpty;

  /// No description provided for @coreUrlInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的 URL（包含 http:// 或 https://）'**
  String get coreUrlInvalid;

  /// No description provided for @corePickMusicDir.
  ///
  /// In zh, this message translates to:
  /// **'选择音乐文件夹'**
  String get corePickMusicDir;

  /// No description provided for @categoryFieldGenre.
  ///
  /// In zh, this message translates to:
  /// **'流派'**
  String get categoryFieldGenre;

  /// No description provided for @categoryFieldArtist.
  ///
  /// In zh, this message translates to:
  /// **'歌手'**
  String get categoryFieldArtist;

  /// No description provided for @categoryFieldAlbum.
  ///
  /// In zh, this message translates to:
  /// **'专辑'**
  String get categoryFieldAlbum;

  /// No description provided for @categoryFieldYear.
  ///
  /// In zh, this message translates to:
  /// **'年份'**
  String get categoryFieldYear;

  /// No description provided for @categoryFieldDecade.
  ///
  /// In zh, this message translates to:
  /// **'年代'**
  String get categoryFieldDecade;

  /// No description provided for @categoryFieldLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语种'**
  String get categoryFieldLanguage;

  /// No description provided for @categoryFieldStyle.
  ///
  /// In zh, this message translates to:
  /// **'风格'**
  String get categoryFieldStyle;

  /// No description provided for @categoryValueUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get categoryValueUnknown;

  /// No description provided for @categoryValueYear.
  ///
  /// In zh, this message translates to:
  /// **'{value} 年'**
  String categoryValueYear(String value);

  /// No description provided for @categoryValueDecade.
  ///
  /// In zh, this message translates to:
  /// **'{value} 年代'**
  String categoryValueDecade(String value);

  /// No description provided for @categoryBrowseTitle.
  ///
  /// In zh, this message translates to:
  /// **'分类浏览'**
  String get categoryBrowseTitle;

  /// No description provided for @categoryEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无「{label}」分类'**
  String categoryEmptyTitle(String label);

  /// No description provided for @categoryEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'该维度下还没有可归类的歌曲'**
  String get categoryEmptySubtitle;

  /// No description provided for @categorySongCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 首'**
  String categorySongCount(int count);

  /// No description provided for @categorySearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索{label}…'**
  String categorySearchHint(String label);

  /// No description provided for @categoryNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配的{label}'**
  String categoryNoMatch(String label);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
