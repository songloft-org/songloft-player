// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get language => '语言';

  @override
  String get languageSimplifiedChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get themeTitle => '主题';

  @override
  String get themeModeTitle => '主题模式';

  @override
  String get themeModeSubtitle => '选择应用的主题外观';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeSystem => '系统';

  @override
  String get commonConfirm => '确认';

  @override
  String get commonCancel => '取消';

  @override
  String get commonDelete => '删除';

  @override
  String get commonRetry => '重试';

  @override
  String get commonLoading => '正在加载';

  @override
  String get commonUnknown => '未知';

  @override
  String get errorNetworkFailed => '网络连接失败';

  @override
  String get errorGeneric => '出错了';

  @override
  String get deleteAlsoLocalFile => '同时删除本地文件';

  @override
  String get deleteIrreversible => '删除后无法恢复';

  @override
  String get navHome => '首页';

  @override
  String get navLibrary => '曲库';

  @override
  String get navPlaylists => '歌单';

  @override
  String get navSettings => '设置';

  @override
  String get favoriteAdded => '已添加到收藏';

  @override
  String get favoriteRemoved => '已取消收藏';

  @override
  String get favoriteAddFailed => '收藏失败';

  @override
  String get favoriteRemoveFailed => '取消收藏失败';

  @override
  String get favorite => '收藏';

  @override
  String get unfavorite => '取消收藏';

  @override
  String get commonCreate => '创建';

  @override
  String commonConfirmWithCount(int count) {
    return '确定($count)';
  }

  @override
  String get commonLoadFailed => '加载失败';

  @override
  String commonLoadFailedDetail(String error) {
    return '加载失败: $error';
  }

  @override
  String get clearSearch => '清除搜索';

  @override
  String get selectAll => '全选';

  @override
  String get selectFolder => '选择文件夹';

  @override
  String get more => '更多';

  @override
  String get expand => '展开';

  @override
  String get collapse => '收起';

  @override
  String get songTypeLocal => '本地';

  @override
  String get songTypeRemote => '网络';

  @override
  String get songTypeRadio => '电台';

  @override
  String get filterAll => '全部';

  @override
  String get pickerSelectSongs => '选择歌曲';

  @override
  String get pickerSearchHint => '搜索歌曲、艺术家或专辑';

  @override
  String get pickerNoMatchInFolder => '该目录下未找到匹配的歌曲';

  @override
  String get pickerNoMatch => '未找到匹配的歌曲';

  @override
  String get pickerNoSongsInFolder => '该目录下无歌曲';

  @override
  String get pickerNoSongs => '暂无歌曲';

  @override
  String pickerFetchListFailed(String error) {
    return '获取列表失败: $error';
  }

  @override
  String get pickerSelectingAll => '正在选择全部...';

  @override
  String pickerDeselectAllWithCount(int count) {
    return '取消全选（已选 $count）';
  }

  @override
  String pickerSelectAllCount(int count) {
    return '全选 $count 首';
  }

  @override
  String get loadFailedTapRetry => '加载失败，点击重试';

  @override
  String get loadedAllHint => '— 已加载全部 —';

  @override
  String get addToPlaylist => '添加到歌单';

  @override
  String get newPlaylist => '新建歌单';

  @override
  String get playlistNameLabel => '歌单名称';

  @override
  String get noPlaylists => '暂无歌单';

  @override
  String songsCount(int count) {
    return '$count 首歌曲';
  }

  @override
  String get addFailed => '添加失败';

  @override
  String addFailedDetail(String error) {
    return '添加失败: $error';
  }

  @override
  String addedToPlaylist(int added, String name) {
    return '已添加 $added 首歌曲到「$name」';
  }

  @override
  String addedToPlaylistWithSkip(int added, String name, int skipped) {
    return '已添加 $added 首到「$name」，跳过 $skipped 首';
  }

  @override
  String createdPlaylistAdded(String name, int added) {
    return '已创建歌单「$name」并添加 $added 首歌曲';
  }

  @override
  String createdPlaylistWithSkip(String name, int added, int skipped) {
    return '已创建歌单「$name」并添加 $added 首，跳过 $skipped 首';
  }

  @override
  String get createPlaylistFailed => '创建歌单失败';

  @override
  String createPlaylistFailedDetail(String error) {
    return '创建歌单失败: $error';
  }

  @override
  String get selectAllFiles => '选择全部文件';

  @override
  String get allSongs => '全部歌曲';

  @override
  String get musicDirEmpty => '音乐目录为空';

  @override
  String get dirEmpty => '目录为空';

  @override
  String loadDirFailed(String error) {
    return '加载目录失败：$error';
  }

  @override
  String get githubProxyDirect => '直连 (不使用代理)';

  @override
  String coreErrorConnectionTimeout(String target) {
    return '无法连接到 $target（连接超时）。请检查：①后端服务是否运行 ②URL 与端口是否正确 ③若通过 ZeroTier/VPN 访问，请确认 VPN 已连接并启用「全局路由」';
  }

  @override
  String coreErrorConnectionFailed(String target) {
    return '无法连接到 $target。请检查 URL 是否正确；若通过 ZeroTier/VPN 访问，请确认 VPN 已启用';
  }

  @override
  String get coreErrorBadCertificate => '证书验证失败';

  @override
  String get coreErrorRequestCancelled => '请求已取消';

  @override
  String get coreErrorUnknownNetwork => '未知网络错误';

  @override
  String get coreErrorNoResponse => '服务器无响应';

  @override
  String get coreErrorRequestFailed => '请求失败';

  @override
  String get coreErrorUnauthorized => '登录已过期，请重新登录';

  @override
  String get coreErrorForbidden => '没有权限访问';

  @override
  String get coreErrorNotFound => '请求的资源不存在';

  @override
  String get coreErrorServer => '服务器错误，请稍后重试';

  @override
  String get coreNotFoundPageTitle => '页面未找到';

  @override
  String get coreBackToHome => '返回首页';

  @override
  String get coreNotificationChannel => 'Songloft 播放控制';

  @override
  String get coreVersionDev => '开发版本';

  @override
  String get jspluginManagerTitle => 'JS 插件管理';

  @override
  String get jspluginManagerSubtitle => '管理已安装的 JS 插件';

  @override
  String get jspluginUploadPlugin => '上传插件';

  @override
  String get jspluginUpdateAll => '全部更新';

  @override
  String get jspluginCleanupData => '清理数据';

  @override
  String get jspluginGithubProxy => 'GitHub 代理';

  @override
  String get jspluginCustomProxy => '自定义代理';

  @override
  String get jspluginCustomProxyEllipsis => '自定义代理...';

  @override
  String jspluginCustomProxyWith(String proxy) {
    return '自定义: $proxy';
  }

  @override
  String get jspluginProxyHelper => '输入代理地址，如 https://ghproxy.com/';

  @override
  String get jspluginOk => '确定';

  @override
  String get jspluginCleanupOrphanTitle => '清理孤儿数据';

  @override
  String get jspluginCleanupOrphanContent => '将清理已卸载插件遗留的持久化存储数据，此操作不可撤销。';

  @override
  String get jspluginCleanup => '清理';

  @override
  String jspluginCleanupFailed(String error) {
    return '清理失败: $error';
  }

  @override
  String get jspluginNoInstalled => '暂无已安装的 JS 插件';

  @override
  String jspluginPickFileFailed(String error) {
    return '选择文件失败: $error';
  }

  @override
  String get jspluginCannotReadFile => '无法读取文件数据';

  @override
  String get jspluginCannotGetPath => '无法获取文件路径';

  @override
  String jspluginUploadSuccess(int count) {
    return '上传成功：$count 个插件';
  }

  @override
  String jspluginUploadPartial(int success, int failed, String error) {
    return '成功 $success 个，失败 $failed 个\n$error';
  }

  @override
  String jspluginUploadFailed(String error) {
    return '上传失败: $error';
  }

  @override
  String get jspluginUploadDialogTitle => '上传 JS 插件';

  @override
  String get jspluginSelectFileSemantics => '选择插件文件上传';

  @override
  String get jspluginTapToSelectFile => '点击选择文件';

  @override
  String get jspluginUploadHint => '支持 .jsplugin.zip 格式；上传同名插件将覆盖现有版本（手动更新）';

  @override
  String get jspluginRemove => '移除';

  @override
  String get jspluginUploading => '上传中...';

  @override
  String get jspluginUpload => '上传';

  @override
  String jspluginOperationFailed(String error) {
    return '操作失败: $error';
  }

  @override
  String jspluginCannotOpenLink(String url) {
    return '无法打开链接: $url';
  }

  @override
  String get jspluginForceUpdateSuccess => '插件已强制更新';

  @override
  String jspluginForceUpdateFailed(String error) {
    return '强制更新失败: $error';
  }

  @override
  String get jspluginConfirmDelete => '确认删除';

  @override
  String jspluginDeleteConfirmContent(String name) {
    return '确定要删除插件 \"$name\" 吗？';
  }

  @override
  String get jspluginKeepData => '保留插件数据';

  @override
  String get jspluginKeepDataSubtitle => '保留文件存储数据，方便日后重装';

  @override
  String get jspluginDeleted => '插件已删除';

  @override
  String jspluginDeleteFailed(String error) {
    return '删除失败: $error';
  }

  @override
  String jspluginAuthor(String author) {
    return '作者: $author';
  }

  @override
  String get jspluginOpenHomepageSemantics => '打开插件主页';

  @override
  String get jspluginStatusError => '错误';

  @override
  String get jspluginStatusEnabled => '已启用';

  @override
  String get jspluginStatusDisabled => '已禁用';

  @override
  String get jspluginMoreActions => '更多操作';

  @override
  String get jspluginOpenHomepage => '打开主页';

  @override
  String get jspluginKeepAlive => '常驻运行';

  @override
  String get jspluginCancelKeepAlive => '取消常驻运行';

  @override
  String get jspluginCheckUpdate => '检查更新';

  @override
  String get jspluginForceUpdate => '强制更新';

  @override
  String get jspluginUpdate => '更新';

  @override
  String get jspluginCheckUpdateTimeout => '检查更新超时，请尝试切换代理后重试';

  @override
  String jspluginCheckUpdateFailed(String error) {
    return '检查更新失败: $error';
  }

  @override
  String get jspluginUpdateSuccess => '插件更新成功';

  @override
  String jspluginUpdateFailed(String error) {
    return '更新失败: $error';
  }

  @override
  String get jspluginUpdateTimeout => '更新超时，请重试';

  @override
  String jspluginUpdateDialogTitle(String name) {
    return '更新插件 - $name';
  }

  @override
  String get jspluginCheckingUpdate => '正在检查更新...';

  @override
  String get jspluginDownloadingUpdate => '正在下载并更新插件...';

  @override
  String get jspluginDoNotCloseDialog => '请勿关闭此对话框';

  @override
  String get jspluginAlreadyLatest => '已是最新版本';

  @override
  String jspluginCurrentVersion(String version) {
    return '当前版本: $version';
  }

  @override
  String get jspluginNewVersionFound => '发现新版本';

  @override
  String get jspluginRecheck => '重新检查';

  @override
  String get jspluginUpdateNow => '立即更新';

  @override
  String get jspluginClose => '关闭';

  @override
  String jspluginBatchUpdateFailed(String error) {
    return '批量更新失败: $error';
  }

  @override
  String get jspluginBatchUpdateTimeout => '批量更新超时，请重试';

  @override
  String get jspluginBatchUpdating => '正在检查并更新所有插件...';

  @override
  String get jspluginStatUpdated => '已更新';

  @override
  String get jspluginStatFailed => '失败';

  @override
  String get jspluginStatSkipped => '无需更新';

  @override
  String get jspluginUpdateFailedShort => '更新失败';

  @override
  String jspluginVersionLatest(String version) {
    return 'v$version 已是最新';
  }

  @override
  String get jspluginStartUpdate => '开始更新';

  @override
  String jspluginForceUpdateDialogTitle(String name) {
    return '强制更新 - $name';
  }

  @override
  String get jspluginForceUpdateContent => '将忽略版本检查，重新下载并安装插件。';

  @override
  String get jspluginConfirmUpdate => '确认更新';

  @override
  String get jspluginStoreTitle => '插件商店';

  @override
  String get jspluginRefreshList => '刷新插件列表';

  @override
  String get jspluginManageRegistries => '管理订阅源';

  @override
  String get jspluginNoRegistries => '还没有添加订阅源';

  @override
  String get jspluginNoRegistriesHint => '添加订阅源后即可浏览和安装插件';

  @override
  String get jspluginAddRegistry => '添加订阅源';

  @override
  String get jspluginRegistry => '订阅源';

  @override
  String get jspluginOfficial => '官方';

  @override
  String get jspluginAllSources => '全部';

  @override
  String get jspluginAutoUpdate => '自动更新插件';

  @override
  String get jspluginAutoUpdateHint => '后台定时检查并更新已安装的插件';

  @override
  String get jspluginSearchHint => '搜索插件...';

  @override
  String get jspluginLoadingList => '正在加载插件列表…';

  @override
  String get jspluginNoMatch => '没有找到匹配的插件';

  @override
  String get jspluginRegistryEmpty => '该订阅源暂无插件';

  @override
  String get jspluginPrevPage => '上一页';

  @override
  String get jspluginNextPage => '下一页';

  @override
  String jspluginInstallFailed(String error) {
    return '安装失败: $error';
  }

  @override
  String get jspluginReinstall => '重新安装';

  @override
  String jspluginUpdateTo(String version) {
    return '更新至 v$version';
  }

  @override
  String get jspluginInstall => '安装';

  @override
  String jspluginSaveFailed(String error) {
    return '保存失败: $error';
  }

  @override
  String get jspluginEditRegistry => '编辑订阅源';

  @override
  String get jspluginDeleteRegistry => '删除订阅源';

  @override
  String get jspluginNameOptional => '名称（可选）';

  @override
  String get jspluginRegistryNameHint => '我的插件源';

  @override
  String get jspluginTokenOptional => 'Token（可选）';

  @override
  String get jspluginSave => '保存';

  @override
  String get jspluginAdd => '添加';

  @override
  String get jspluginAuthConfigured => '已配置认证';

  @override
  String get jspluginGridTitle => 'JS 插件';

  @override
  String get jspluginCleanupDone => '清理完成';

  @override
  String get libraryPlayFailed => '播放失败';

  @override
  String get libraryNoPlayableSongs => '没有可播放的歌曲';

  @override
  String libraryPlayingAllSongs(int total) {
    return '播放全部 $total 首歌曲';
  }

  @override
  String get libraryDismissError => '关闭提示';

  @override
  String get libraryExitSelection => '退出多选';

  @override
  String librarySelectedCount(int count) {
    return '已选择 $count 首';
  }

  @override
  String libraryDeleteWithCount(int count) {
    return '删除($count)';
  }

  @override
  String get libraryDeselectAll => '取消全选';

  @override
  String get libraryTitle => '曲库';

  @override
  String get libraryPlayAll => '播放全部';

  @override
  String get librarySort => '排序';

  @override
  String get librarySortAddedAt => '最近加入';

  @override
  String get librarySortFileTime => '文件时间';

  @override
  String get libraryColumnTitle => '标题';

  @override
  String get libraryColumnArtist => '艺术家';

  @override
  String get libraryColumnAlbum => '专辑';

  @override
  String get libraryColumnType => '类型';

  @override
  String get libraryColumnDuration => '时长';

  @override
  String get librarySelectMode => '多选';

  @override
  String get libraryMore => '更多';

  @override
  String get libraryAddRemoteSong => '添加网络歌曲';

  @override
  String get libraryAddRadio => '添加电台';

  @override
  String get libraryHideHiddenSongs => '隐藏已隐藏歌曲';

  @override
  String get libraryShowHiddenSongs => '显示隐藏歌曲';

  @override
  String get libraryCleanInvalidSongs => '清理无效歌曲';

  @override
  String get librarySearchHint => '搜索歌曲...';

  @override
  String get libraryNoMatchingSongs => '未找到匹配的歌曲';

  @override
  String get libraryEmpty => '曲库为空';

  @override
  String get libraryTryOtherKeywords => '尝试其他关键词';

  @override
  String get libraryEmptyHint => '添加一些歌曲开始吧';

  @override
  String get libraryDeleteConfirmTitle => '确认删除';

  @override
  String get libraryDeleteConfirmContent => '确定要删除这首歌曲吗？';

  @override
  String get libraryCleanTitle => '清理歌曲';

  @override
  String get libraryCleanContent => '将清理无效的歌曲记录（如文件已删除的本地歌曲）。';

  @override
  String libraryCleanedCount(int count) {
    return '已清理 $count 首无效歌曲';
  }

  @override
  String get libraryClean => '清理';

  @override
  String get libraryBatchDeleteTitle => '批量删除';

  @override
  String libraryBatchDeleteContent(int count) {
    return '确定要删除选中的 $count 首歌曲吗？';
  }

  @override
  String libraryDeletedCount(int count) {
    return '已删除 $count 首歌曲';
  }

  @override
  String get libraryDeleteFailed => '删除失败';

  @override
  String librarySongCount(int count) {
    return '$count首';
  }

  @override
  String get libraryUnknownArtist => '未知艺术家';

  @override
  String get libraryUnknownAlbum => '未知专辑';

  @override
  String get libraryPlay => '播放';

  @override
  String get libraryEdit => '编辑';

  @override
  String get libraryCustomizeViews => '自定义视图';

  @override
  String get libraryCustomizeViewsTooltip => '自定义显示的视图与顺序';

  @override
  String get libraryViewsMinOne => '至少保留一个可见视图';

  @override
  String get libraryViewPlaylistAll => '全部歌单';

  @override
  String get categorySongsEmpty => '该分类下暂无歌曲';

  @override
  String get libraryViewGroupSongs => '歌曲';

  @override
  String get libraryViewGroupCategories => '分类';

  @override
  String get libraryViewGroupPlaylists => '歌单';

  @override
  String get libraryViewGroupMoveUp => '上移分组';

  @override
  String get libraryViewGroupMoveDown => '下移分组';

  @override
  String get libraryEditLocalSong => '编辑本地歌曲';

  @override
  String get libraryEditRadio => '编辑电台';

  @override
  String get libraryEditRemoteSong => '编辑网络歌曲';

  @override
  String get librarySave => '保存';

  @override
  String get libraryFileInfoReadonly => '文件信息（只读）';

  @override
  String get libraryServerEndpointReadonly => '服务端端点（只读）';

  @override
  String get libraryReadonlyFile => '文件';

  @override
  String get libraryReadonlyCover => '封面';

  @override
  String get libraryReadonlyLyric => '歌词';

  @override
  String get libraryEditTitleLabel => '标题 *';

  @override
  String get libraryEditTitleRequired => '请输入标题';

  @override
  String get libraryEditArtistHint => '请输入艺术家';

  @override
  String get libraryEditAlbumHint => '请输入专辑';

  @override
  String get libraryRenameFileTitle => '同步重命名文件';

  @override
  String get libraryRenameFileSubtitle => '按新标题重命名本地音频文件，同时写入 title 标签';

  @override
  String get libraryVideoToggleTitle => '视频内容';

  @override
  String get libraryVideoToggleSubtitle => '此链接含视频画面，开启后播放页渲染画面、投屏按视频推送';

  @override
  String get libraryEditSourceUrlLabel => '源音频 URL *';

  @override
  String get libraryEditUrlLabel => 'URL *';

  @override
  String get libraryEditUrlHint => '请输入音频链接';

  @override
  String get libraryEditUrlRequired => '请输入 URL';

  @override
  String get libraryEditUrlInvalid => '请输入有效的 URL';

  @override
  String get libraryEditSourceCoverUrlLabel => '源封面 URL';

  @override
  String get libraryEditCoverUrlLabel => '封面 URL';

  @override
  String get libraryEditCoverUrlHint => '请输入封面图片链接';

  @override
  String get libraryEditDurationLabel => '时长（秒）';

  @override
  String get libraryEditDurationHint => '请输入时长';

  @override
  String get libraryEditLyricRemoteUrlLabel => '歌词远程 URL';

  @override
  String get libraryEditLyricUrlLabel => '歌词 URL';

  @override
  String get libraryEditLyricUrlHint => '请输入歌词接口链接';

  @override
  String get libraryCoverPreview => '封面预览：';

  @override
  String get libraryCopied => '已复制';

  @override
  String get libraryCopy => '复制';

  @override
  String get librarySaveSuccess => '保存成功';

  @override
  String get libraryAddSuccess => '添加成功';

  @override
  String libraryOperationFailed(String error) {
    return '操作失败: $error';
  }

  @override
  String get libraryErrorBadRequest => '请求参数错误';

  @override
  String get libraryErrorUnauthorized => '未授权，请重新登录';

  @override
  String get libraryErrorForbidden => '没有权限执行此操作';

  @override
  String get libraryErrorNotFound => '歌曲不存在';

  @override
  String get libraryErrorServer => '服务器错误，请稍后重试';

  @override
  String libraryErrorRequestFailed(int code) {
    return '请求失败：$code';
  }

  @override
  String get libraryErrorTimeout => '网络连接超时，请检查网络';

  @override
  String get libraryErrorConnection => '网络连接失败，请检查网络';

  @override
  String libraryErrorNetwork(String message) {
    return '网络错误：$message';
  }

  @override
  String get libraryFavoritePlaylistNotFound => '收藏歌单不存在';

  @override
  String get libraryRadioFavoritePlaylistNotFound => '电台收藏歌单不存在';

  @override
  String get homeEmptyPlaylists => '暂无歌单';

  @override
  String get homeEmptyPlaylistsSubtitle => '创建你的第一个歌单开始收藏音乐';

  @override
  String get homeCreatePlaylist => '创建歌单';

  @override
  String get homeMyPlaylists => '我的歌单';

  @override
  String get homeViewAll => '查看全部';

  @override
  String get homeMyRadios => '我的电台';

  @override
  String get homeGreetingLateNight => '夜深了';

  @override
  String get homeGreetingMorning => '早上好';

  @override
  String get homeGreetingNoon => '中午好';

  @override
  String get homeGreetingAfternoon => '下午好';

  @override
  String get homeGreetingEvening => '晚上好';

  @override
  String get homeTvGreetingLateNight => '夜深了，听点音乐吧';

  @override
  String get homeOpenPlaylist => '打开歌单';

  @override
  String homeOpenPlaylistNamed(String name) {
    return '打开歌单 $name';
  }

  @override
  String homeSongCountShort(int count) {
    return '$count 首';
  }

  @override
  String homeSongCount(int count) {
    return '$count 首歌曲';
  }

  @override
  String homeStatPlaylistsCount(int count) {
    return '$count 歌单';
  }

  @override
  String homeStatRadiosCount(int count) {
    return '$count 电台';
  }

  @override
  String get homeStatTotal => '总计';

  @override
  String get homeTvLocalMusic => '本地音乐';

  @override
  String get homeTvPlaylist => '播放列表';

  @override
  String get homeTvEmptySubtitle => '使用快捷导航浏览本地音乐';

  @override
  String homeHeroSemanticLabel(String name, int count) {
    return '$name - $count 首歌曲';
  }

  @override
  String get homeNowPlaying => '正在播放';

  @override
  String get homeRecommendedPlaylist => '推荐歌单';

  @override
  String get homePlayNow => '立即播放';

  @override
  String get homePluginLoadTimeout => '页面加载超时，请检查插件是否可用或网络连接';

  @override
  String get homePluginClose => '关闭';

  @override
  String get homePluginOpenInBrowser => '在浏览器中打开';

  @override
  String get homePluginLoadFailed => '页面加载失败';

  @override
  String homePluginLoadFailedHttp(String status, String detail) {
    return '页面加载失败: HTTP $status$detail';
  }

  @override
  String get homePluginUnknownError => '未知错误';

  @override
  String get homePluginWebOpenInNewTab => 'Web 平台请在新标签页中打开插件';

  @override
  String get authLogin => '登录';

  @override
  String get authTvSubtitle => '使用您的账号登录 Songloft';

  @override
  String get authLoginToContinue => '登录以继续';

  @override
  String get authTagline => '自托管本地音乐服务';

  @override
  String get authUsername => '用户名';

  @override
  String get authUsernameHint => '请输入用户名';

  @override
  String get authUsernameRequired => '请输入用户名';

  @override
  String get authPassword => '密码';

  @override
  String get authPasswordHint => '请输入密码';

  @override
  String get authPasswordRequired => '请输入密码';

  @override
  String get authShowPassword => '显示密码';

  @override
  String get authHidePassword => '隐藏密码';

  @override
  String get authApiUrl => 'API 地址';

  @override
  String get authApiUrlRequired => '请输入 API 地址';

  @override
  String get authInvalidUrl => '请输入有效的 URL（以 http:// 或 https:// 开头）';

  @override
  String get authServer => '服务器';

  @override
  String get authTvPressToLogin => '按确认键登录';

  @override
  String get authUseLocalMode => '使用本地模式';

  @override
  String authCopyright(int year) {
    return '© $year Songloft';
  }

  @override
  String get authAutoLoggingIn => '正在自动登录…';

  @override
  String get authStartingLocalBackend => '正在启动本地后端…';

  @override
  String get authPreparing => '正在准备…';

  @override
  String get authConnecting => '正在连接…';

  @override
  String get authLoggingIn => '正在登录…';

  @override
  String authAutoLoginFailed(String error) {
    return '自动登录失败：$error';
  }

  @override
  String authLocalModeFailed(String error) {
    return '本地模式启动失败：$error';
  }

  @override
  String authLoginFailed(String error) {
    return '登录失败：$error';
  }

  @override
  String get authSessionExpired => '登录已过期，请重新登录';

  @override
  String get authNoRefreshToken => '没有可用的刷新令牌';

  @override
  String get dlnaCast => '投屏';

  @override
  String get dlnaCasting => '投屏中';

  @override
  String get dlnaDisconnect => '断开';

  @override
  String get dlnaConnected => '已连接';

  @override
  String get dlnaSearching => '正在搜索设备...';

  @override
  String get dlnaSearchingLan => '正在搜索局域网设备...';

  @override
  String get dlnaNoDevices => '未发现 DLNA 设备';

  @override
  String get startupStarting => '正在启动…';

  @override
  String get startupStartingLocalBackend => '正在启动本地后端…';

  @override
  String get startupConnectingLocalBackend => '正在连接本地后端…';

  @override
  String startupConnectingTo(String target) {
    return '正在连接 $target…';
  }

  @override
  String get playerModeOrder => '顺序播放';

  @override
  String get playerModeLoop => '列表循环';

  @override
  String get playerModeSingle => '单曲循环';

  @override
  String get playerModeRandom => '随机播放';

  @override
  String get playerModeSinglePlay => '单曲播放';

  @override
  String get playerClose => '关闭';

  @override
  String get playerSleepTimer => '睡眠定时';

  @override
  String playerSleepTimerWithStatus(String status) {
    return '睡眠定时：$status';
  }

  @override
  String get playerSleepTimerCancel => '取消定时';

  @override
  String get playerSleepTimerByDuration => '按时长';

  @override
  String playerHours(int count) {
    return '$count 小时';
  }

  @override
  String playerMinutes(int count) {
    return '$count 分钟';
  }

  @override
  String get playerCustom => '自定义';

  @override
  String get playerCustomDuration => '自定义时长';

  @override
  String get playerUnitMinutes => '分钟';

  @override
  String get playerSleepTimerBySongs => '按歌曲';

  @override
  String playerSongsUnit(int count) {
    return '$count 首';
  }

  @override
  String get playerCustomSongCount => '自定义首数';

  @override
  String get playerUnitSongs => '首';

  @override
  String playerRemainingSongs(int count) {
    return '剩余 $count 首';
  }

  @override
  String get playerEnterNumber => '请输入数字';

  @override
  String get playerEnterValidInteger => '请输入有效整数';

  @override
  String playerEnterIntegerInRange(int min, int max) {
    return '请输入 $min - $max 之间的整数';
  }

  @override
  String get playerBack => '返回';

  @override
  String get playerNowPlaying => '正在播放';

  @override
  String get playerNoContent => '无播放内容';

  @override
  String get playerUnknownArtist => '未知艺术家';

  @override
  String get playerPlayMode => '播放模式';

  @override
  String get playerVolumeDown => '音量-';

  @override
  String get playerVolumeUp => '音量+';

  @override
  String get playerPrevious => '上一首';

  @override
  String get playerNext => '下一首';

  @override
  String get playerPlaylist => '播放列表';

  @override
  String get playerBuffering => '缓冲中';

  @override
  String get playerCaching => '正在缓存，请稍候…';

  @override
  String get playerPause => '暂停';

  @override
  String get playerPlay => '播放';

  @override
  String get playerSeekHint => '← → 快进/快退';

  @override
  String get playerProgress => '播放进度';

  @override
  String get playerQueueTitle => '播放队列';

  @override
  String get playerClearPlaylist => '清空播放列表';

  @override
  String get playerQueueEmpty => '播放队列为空';

  @override
  String get playerDrawerEmptyHint => '添加歌曲开始播放';

  @override
  String get playerQueueEmptyHint => '添加歌曲到播放队列开始播放';

  @override
  String playerRemovedSong(String title) {
    return '已移除「$title」';
  }

  @override
  String get playerClearQueueTitle => '清空播放队列';

  @override
  String get playerClearQueueConfirm => '确定要清空播放队列吗？';

  @override
  String get playerClear => '清空';

  @override
  String get playerRemoveFromPlaylist => '从播放列表移除';

  @override
  String get playerRemoveFromQueue => '从队列移除';

  @override
  String get playerMute => '静音';

  @override
  String get playerUnmute => '恢复音量';

  @override
  String playerVolumePercent(int value) {
    return '音量 $value%';
  }

  @override
  String get playerVolume => '音量';

  @override
  String get playerCloseVolumePanel => '关闭音量面板';

  @override
  String get playerOpenFullPlayer => '打开全屏播放器';

  @override
  String get playerEqualizer => '均衡器';

  @override
  String get playerAudioTrack => '音轨';

  @override
  String get playerSelectAudioTrack => '选择音轨';

  @override
  String playerAudioTrackNumbered(int index) {
    return '音轨 $index';
  }

  @override
  String get playerLyrics => '歌词';

  @override
  String get playerCollapse => '收起';

  @override
  String get playerSubtitleOn => '显示字幕';

  @override
  String get playerSubtitleOff => '隐藏字幕';

  @override
  String get playerEnterFullscreen => '全屏';

  @override
  String get playerExitFullscreen => '退出全屏';

  @override
  String get playerSleepTimerOn => '睡眠定时 (已开启)';

  @override
  String get playerDeleteCurrentSong => '删除当前歌曲';

  @override
  String get playerExpandPlayer => '展开播放器';

  @override
  String get playerBufferingSemantic => '正在缓冲';

  @override
  String get playerLyricsLoading => '正在加载歌词...';

  @override
  String get playerLyricsLoadFailed => '歌词加载失败';

  @override
  String get playerLyricsEmpty => '暂无歌词';

  @override
  String get playerLyricsSeekTo => '跳转到此歌词位置';

  @override
  String get playerAdjustLyrics => '调整歌词';

  @override
  String get playerLyricsRefetch => '重新抓取歌词';

  @override
  String get playerEqNotSupported => '当前平台暂不支持均衡器';

  @override
  String get playerEqPresetFlat => '平坦';

  @override
  String get playerEqPresetRock => '摇滚';

  @override
  String get playerEqPresetPop => '流行';

  @override
  String get playerEqPresetJazz => '爵士';

  @override
  String get playerEqPresetClassical => '古典';

  @override
  String get playerEqPresetBassBoost => '低音增强';

  @override
  String get playerEqPresetTrebleBoost => '高音增强';

  @override
  String get playerEqPresetVocal => '人声';

  @override
  String get playerEqPresetCustom => '自定义';

  @override
  String get playerLyricSavedWritten => '已保存，已写入音频文件';

  @override
  String get playerLyricSavedWriteFailed => '已保存到数据库，但写入音频文件失败';

  @override
  String get playerLyricSavedDbOnly => '已保存到数据库（文件未更新）';

  @override
  String playerSaveFailedDetail(String error) {
    return '保存失败：$error';
  }

  @override
  String get playerDiscardChangesTitle => '放弃修改？';

  @override
  String get playerDiscardChangesContent => '当前调整尚未保存，确定要离开吗？';

  @override
  String get playerContinueEditing => '继续编辑';

  @override
  String get playerDiscard => '放弃';

  @override
  String get playerGlobalOffset => '全局偏移';

  @override
  String playerLyricOffsetSemantics(int value) {
    return '歌词偏移 $value 毫秒';
  }

  @override
  String get playerOffsetHint => '提示：歌词整体早出现，用负偏移（-）；整体晚出现，用正偏移（+）';

  @override
  String get playerEmptyLine => '(空行)';

  @override
  String playerLineOffset(String offset) {
    return '行偏移 $offset';
  }

  @override
  String get playerReset => '重置';

  @override
  String get playerSave => '保存';

  @override
  String get playerNoLyricsToAdjust => '暂无可调整的歌词';

  @override
  String get playerDeleteSongTitle => '删除歌曲';

  @override
  String playerDeleteSongConfirm(String title) {
    return '确定要从曲库中删除「$title」吗？';
  }

  @override
  String get playerSongDeleted => '歌曲已删除';

  @override
  String get playerDeleteFailed => '删除失败';

  @override
  String get playerUnknownSong => '未知歌曲';

  @override
  String playerPlayFailedNamed(String title) {
    return '\"$title\" 播放失败';
  }

  @override
  String playerConsecutiveFailures(int count) {
    return '连续 $count 首歌曲播放失败，已停止播放，请检查网络连接';
  }

  @override
  String playerPlayFailedTryingNext(String title) {
    return '\"$title\" 播放失败，正在尝试下一首...';
  }

  @override
  String get playerPlayFailedNoOthers => '播放失败，无其他可播放的歌曲';

  @override
  String get playerPlayFailedEndOfList => '播放失败，已到播放列表末尾';

  @override
  String get playlistBack => '返回';

  @override
  String get playlistSearch => '搜索';

  @override
  String get playlistSearchHint => '搜索歌曲...';

  @override
  String get playlistListSearchHint => '搜索歌单...';

  @override
  String get playlistNoMatching => '未找到匹配的歌单';

  @override
  String get playlistTryOtherKeywords => '尝试其他关键词';

  @override
  String get playlistFilterNormal => '普通歌单';

  @override
  String get playlistFilterRadio => '电台歌单';

  @override
  String get playlistMultiSelect => '多选';

  @override
  String get playlistMore => '更多';

  @override
  String get playlistDone => '完成';

  @override
  String get playlistSort => '排序';

  @override
  String get playlistSortModeTitle => '排序歌单';

  @override
  String get playlistSortSaved => '排序已保存';

  @override
  String get playlistSortSaveFailed => '排序保存失败';

  @override
  String get playlistSortFailed => '排序失败';

  @override
  String get playlistAlreadySortedSongs => '歌曲已是该排序顺序';

  @override
  String get playlistAlreadySortedPlaylists => '歌单已是该排序顺序';

  @override
  String get playlistSortedByNameAsc => '已按名称升序排列';

  @override
  String get playlistSortedByNameDesc => '已按名称降序排列';

  @override
  String get playlistSortedByNumber => '已按数字前缀排序';

  @override
  String get playlistSortCustom => '自定义顺序';

  @override
  String get playlistSortRecentlyAdded => '最近加入';

  @override
  String get playlistSortFileTime => '文件时间';

  @override
  String get playlistSortTitle => '标题';

  @override
  String get playlistSortArtist => '艺术家';

  @override
  String get playlistSortDuration => '时长';

  @override
  String get playlistSortNameAsc => '按名称排序 A→Z';

  @override
  String get playlistSortNameDesc => '按名称排序 Z→A';

  @override
  String get playlistSortNumberPrefix => '按数字前缀排序';

  @override
  String get playlistSortManual => '手动排序';

  @override
  String get playlistPlayAll => '播放全部';

  @override
  String get playlistAddSongs => '添加歌曲';

  @override
  String get playlistAddSongsFailed => '添加歌曲失败';

  @override
  String playlistAddedWithSkipped(int added, int skipped) {
    return '已添加 $added 首，跳过 $skipped 首（已存在或类型不兼容）';
  }

  @override
  String playlistAddedCount(int count) {
    return '已添加 $count 首歌曲';
  }

  @override
  String get playlistLoadMoreRetry => '加载更多失败，点击重试';

  @override
  String playlistAllLoaded(int count) {
    return '— 已全部加载（$count） —';
  }

  @override
  String get playlistDeselectAll => '取消全选';

  @override
  String get playlistRemove => '移除';

  @override
  String get playlistRemoveFromPlaylist => '从歌单移除';

  @override
  String get playlistDeleteFromLibrary => '从曲库删除';

  @override
  String playlistActionsCount(int count) {
    return '操作($count)';
  }

  @override
  String get playlistBatchRemoveTitle => '批量移除';

  @override
  String playlistBatchRemoveConfirm(int count) {
    return '确定要从歌单中移除 $count 首歌曲吗？';
  }

  @override
  String playlistRemovedCount(int count) {
    return '已移除 $count 首歌曲';
  }

  @override
  String get playlistRemoveFailed => '移除失败';

  @override
  String get playlistEditCover => '修改封面';

  @override
  String get playlistEditPlaylist => '编辑歌单';

  @override
  String get playlistEditAction => '编辑';

  @override
  String get playlistDelete => '删除歌单';

  @override
  String get playlistEmptySongs => '歌单暂无歌曲';

  @override
  String get playlistEmptySongsSubtitle => '添加一些喜欢的音乐吧';

  @override
  String get playlistLabelBuiltIn => '内置';

  @override
  String get playlistLabelAutoCreated => '自动创建';

  @override
  String get playlistLabelAuto => '自动';

  @override
  String get playlistLabelHidden => '已隐藏';

  @override
  String get playlistConfirmDelete => '确认删除';

  @override
  String playlistDeleteConfirm(String name) {
    return '确定要删除歌单「$name」吗？此操作不可恢复。';
  }

  @override
  String get playlistDeleted => '歌单已删除';

  @override
  String get playlistEmpty => '歌单为空';

  @override
  String get playlistPlayFailed => '播放失败';

  @override
  String playlistPlayingCount(int count) {
    return '播放全部 $count 首歌曲';
  }

  @override
  String playlistPlayingSong(String title) {
    return '播放：$title';
  }

  @override
  String get playlistRemoveSongTitle => '移除歌曲';

  @override
  String playlistRemoveSongConfirm(String title) {
    return '确定要从歌单中移除「$title」吗？';
  }

  @override
  String get playlistSongRemoved => '歌曲已移除';

  @override
  String get playlistDeleteSong => '删除歌曲';

  @override
  String playlistDeleteSongConfirm(String title) {
    return '确定要从曲库中删除「$title」吗？';
  }

  @override
  String get playlistSongDeleted => '歌曲已删除';

  @override
  String get playlistDeleteFailed => '删除失败';

  @override
  String get playlistBatchDelete => '批量删除';

  @override
  String playlistBatchDeleteSongsConfirm(int count) {
    return '确定要从曲库中删除选中的 $count 首歌曲吗？';
  }

  @override
  String playlistDeletedSongsCount(int count) {
    return '已删除 $count 首歌曲';
  }

  @override
  String get playlistUnknownArtist => '未知艺术家';

  @override
  String playlistPickImageFailed(String error) {
    return '选择图片失败: $error';
  }

  @override
  String get playlistNameRequired => '请输入歌单名称';

  @override
  String get playlistNameHint => '请输入歌单名称';

  @override
  String get playlistDescLabel => '歌单描述';

  @override
  String get playlistDescHint => '请输入歌单描述（可选）';

  @override
  String get playlistCoverUploadFailed => '封面上传失败';

  @override
  String playlistSaveFailed(String error) {
    return '保存失败: $error';
  }

  @override
  String get playlistUploadImage => '上传图片';

  @override
  String get playlistPickFromSongs => '从歌曲选择';

  @override
  String get playlistClear => '清除';

  @override
  String get playlistSave => '保存';

  @override
  String get playlistOk => '确定';

  @override
  String get playlistTitle => '歌单';

  @override
  String get playlistSwitchToListView => '切换到列表视图';

  @override
  String get playlistSwitchToGridView => '切换到卡片视图';

  @override
  String get playlistCreate => '创建歌单';

  @override
  String get playlistCreated => '歌单创建成功';

  @override
  String get playlistUpdated => '歌单更新成功';

  @override
  String get playlistShowHidden => '显示已隐藏歌单';

  @override
  String get playlistHideHidden => '隐藏已隐藏歌单';

  @override
  String get playlistEmptyHint => '点击右上角按钮创建歌单';

  @override
  String get playlistConfirmBatchDelete => '确认批量删除';

  @override
  String playlistBatchDeleteConfirm(int count) {
    return '确定要删除选中的 $count 个歌单吗？此操作不可恢复。';
  }

  @override
  String playlistDeletedCount(int count) {
    return '已删除 $count 个歌单';
  }

  @override
  String get playlistHidden => '歌单已隐藏';

  @override
  String get playlistUnhidden => '歌单已取消隐藏';

  @override
  String playlistPlayingMultiple(int count) {
    return '正在播放 $count 个歌单';
  }

  @override
  String get playlistExitMultiSelect => '退出多选';

  @override
  String playlistSelectedCount(int count) {
    return '已选择 $count 个';
  }

  @override
  String playlistPlayCount(int count) {
    return '播放($count)';
  }

  @override
  String playlistDeleteCount(int count) {
    return '删除($count)';
  }

  @override
  String get playlistTypeNormalOption => '普通歌单';

  @override
  String get playlistTypeRadioOption => '电台歌单';

  @override
  String get playlistMoreActions => '更多操作';

  @override
  String get playlistHide => '隐藏歌单';

  @override
  String get playlistUnhide => '取消隐藏';

  @override
  String get playlistPickCoverTitle => '选择歌曲封面';

  @override
  String get playlistClose => '关闭';

  @override
  String get playlistNoCoveredSongs => '歌单中没有带封面的歌曲';

  @override
  String get playlistLoadRetry => '加载失败，点击重试';

  @override
  String get playlistNoCoverLoadMore => '当前页无带封面歌曲，加载更多';

  @override
  String get playlistAllLoadedSimple => '— 已加载全部 —';

  @override
  String get playlistSelectThisCover => '选择此封面';

  @override
  String get playlistErrRequestFailed => '请求失败';

  @override
  String get playlistErrTimeout => '网络连接超时';

  @override
  String get playlistErrCancelled => '请求已取消';

  @override
  String playlistErrNetwork(String message) {
    return '网络错误: $message';
  }

  @override
  String settingsCacheSaveConfigFailed(String error) {
    return '保存配置失败: $error';
  }

  @override
  String get settingsCacheCleanServerTitle => '清理服务端缓存';

  @override
  String get settingsCacheCleanServerContent => '确定要清理服务端的所有音乐缓存吗？清理后需要重新下载。';

  @override
  String get settingsCacheServerCleaned => '服务端缓存已清理';

  @override
  String settingsCacheCleanFailed(String error) {
    return '清理失败: $error';
  }

  @override
  String get settingsCacheCleanLocalTitle => '清理本地缓存';

  @override
  String get settingsCacheCleanLocalContent => '确定要清理所有本地缓存吗？包括音频缓存、图片缓存和歌词缓存。';

  @override
  String get settingsCacheLocalCleaned => '本地缓存已清理';

  @override
  String get settingsCacheCleanBrowserTitle => '清理浏览器缓存';

  @override
  String get settingsCacheCleanBrowserContent =>
      '将清除所有前端静态资源缓存并刷新页面。不会影响登录状态和服务端数据。';

  @override
  String get webUpdateAvailableTitle => '发现新版本';

  @override
  String get webUpdateAvailableContent =>
      '检测到服务端已更新，当前页面仍是旧版本。点击「立即刷新」将清理浏览器缓存并加载最新版本，不会影响登录状态。';

  @override
  String get webUpdateAvailableRefresh => '立即刷新';

  @override
  String get webUpdateAvailableLater => '稍后';

  @override
  String settingsCacheUpdateConfigFailed(String error) {
    return '更新配置失败: $error';
  }

  @override
  String get settingsCacheDirRestored => '已恢复默认缓存目录';

  @override
  String get settingsCacheDirUpdated => '缓存目录已更新';

  @override
  String settingsCacheUpdateFailed(String error) {
    return '更新失败: $error';
  }

  @override
  String get settingsCacheConfirmClean => '确认清理';

  @override
  String get settingsCacheServerTitle => '服务端音乐缓存';

  @override
  String get settingsCacheManage => '管理';

  @override
  String settingsCacheNoLimit(String size) {
    return '$size (无上限)';
  }

  @override
  String settingsCacheFileCount(int count) {
    return '$count 个文件';
  }

  @override
  String get settingsCacheStatsLoadFailed => '获取缓存信息失败';

  @override
  String get settingsCacheDirTitle => '缓存目录';

  @override
  String get settingsCacheNotConfigured => '未配置';

  @override
  String settingsCacheMaxSize(String size) {
    return '最大缓存大小: $size';
  }

  @override
  String get settingsCacheTranscodeTitle => '缓存转码格式';

  @override
  String get settingsCacheTranscodeDesc =>
      '网络歌曲缓存时统一转码，提升设备兼容性（如小爱音箱无法播放 MKV）；视频类内容开启后将仅缓存音频、投屏无画面';

  @override
  String get settingsCacheTranscodeOriginal => '原始（不转码）';

  @override
  String get settingsCacheTranscodeDialogTitle => '缓存转码格式';

  @override
  String get settingsCacheTranscodeQualityTitle => '转码码率';

  @override
  String get settingsCacheTranscodeQualityHighest => '最高质量';

  @override
  String get settingsCacheTranscodeQualityDialogTitle => '转码码率';

  @override
  String get settingsCacheTranscodeUpdated => '缓存转码设置已更新';

  @override
  String get settingsCacheCleaning => '清理中...';

  @override
  String get settingsCacheCleanServerButton => '清理服务端缓存';

  @override
  String get settingsCacheLocalTitle => '本地缓存';

  @override
  String get settingsCacheSize => '缓存大小';

  @override
  String get settingsCacheCalculating => '计算中...';

  @override
  String get settingsCacheLocalDesc => '包含音频缓存、图片缓存和歌词缓存';

  @override
  String settingsCacheMaxLocalSize(String size) {
    return '最大本地缓存大小: $size';
  }

  @override
  String get settingsCacheCleanLocalButton => '清理本地缓存';

  @override
  String get settingsCacheBrowserTitle => '浏览器缓存';

  @override
  String get settingsCacheBrowserDesc => '清除浏览器中缓存的前端资源文件，解决更新后页面异常的问题';

  @override
  String get settingsCacheCleanBrowserButton => '清理浏览器缓存';

  @override
  String get settingsCacheDirDialogDesc =>
      '设置服务端音乐缓存的存储目录。留空则使用默认目录。切换目录不会自动迁移旧缓存文件。';

  @override
  String get settingsCacheDirLabel => '缓存目录（绝对路径）';

  @override
  String settingsCacheDirDefault(String dir) {
    return '默认: $dir';
  }

  @override
  String get settingsCacheValidate => '验证';

  @override
  String get settingsCacheRestoreDefault => '恢复默认';

  @override
  String get settingsCacheSave => '保存';

  @override
  String get settingsCacheDirUnavailable => '目录不可用';

  @override
  String get settingsCacheDirCreated => '目录已自动创建';

  @override
  String settingsCacheDiskTotal(String size) {
    return '磁盘总量 $size';
  }

  @override
  String settingsCacheDiskFree(String size) {
    return '可用 $size';
  }

  @override
  String get settingsCacheDirAvailable => '目录可用';

  @override
  String get settingsMetadataUseTagTitle => '使用标签覆盖标题';

  @override
  String get settingsMetadataUseTagOn => '网络歌曲元数据刷新时用音频标签覆盖标题';

  @override
  String get settingsMetadataUseTagOff => '网络歌曲标题保持文件名，不使用标签覆盖';

  @override
  String get settingsMetadataSaved => '已保存';

  @override
  String settingsMetadataSaveFailed(String error) {
    return '保存失败: $error';
  }

  @override
  String get settingsMetadataRefreshTitle => '刷新网络歌曲元数据';

  @override
  String get settingsMetadataRefreshSubtitle => '探测所有元数据缺失的网络歌曲';

  @override
  String get settingsMetadataStart => '开始';

  @override
  String get settingsMetadataPreparing => '准备中...';

  @override
  String get settingsMetadataRefreshing => '正在刷新元数据';

  @override
  String get settingsMetadataStatusCancelled => '已取消';

  @override
  String get settingsMetadataStatusFailed => '执行失败';

  @override
  String get settingsMetadataStatusDone => '已完成';

  @override
  String settingsMetadataSuccess(int count) {
    return '成功 $count 首';
  }

  @override
  String settingsMetadataFailedCount(int count) {
    return '，失败 $count 首';
  }

  @override
  String settingsMetadataRefreshResult(String status) {
    return '刷新元数据$status';
  }

  @override
  String get settingsMetadataRefreshAgain => '重新刷新';

  @override
  String get settingsClientDownloadTitle => '下载客户端 App';

  @override
  String get settingsClientDownloadIntro =>
      '相比 Web 界面，原生客户端支持后台播放、本地缓存、锁屏/通知栏媒体控制等能力。';

  @override
  String get settingsClientDownloadAccelSection => '下载加速';

  @override
  String get settingsClientDownloadGithubProxy => 'GitHub 加速代理';

  @override
  String get settingsClientDownloadProxyNotConfigured =>
      '未配置（直连 GitHub，国内可能较慢）';

  @override
  String get settingsClientDownloadStandardSection => '标准版 · 连接当前服务器';

  @override
  String get settingsClientDownloadBundleSection => 'Bundle 版 · 内嵌后端，无需服务器';

  @override
  String get settingsClientDownloadStandardAllVersions => '标准版全部版本';

  @override
  String get settingsClientDownloadBundleAllVersions => 'Bundle 版全部版本';

  @override
  String settingsClientDownloadRecommendFor(String os) {
    return '为你的设备推荐：$os';
  }

  @override
  String settingsClientDownloadStandardBtn(String label) {
    return '标准版（$label）';
  }

  @override
  String settingsClientDownloadBundleBtn(String label) {
    return 'Bundle 版（$label）';
  }

  @override
  String get settingsClientDownloadNoteUnsigned => '未签名，需自行侧载';

  @override
  String get settingsClientDownloadProxyDialogDesc =>
      '国内访问 GitHub 较慢时可选择镜像加速。此设置与「检查更新」共用。';

  @override
  String get settingsClientDownloadCustomProxy => '自定义代理';

  @override
  String get settingsClientDownloadCustomProxyHelper =>
      '输入代理地址，如 https://ghproxy.com/';

  @override
  String get settingsClientDownloadSave => '保存';

  @override
  String get settingsTabConfigTitle => '菜单设置';

  @override
  String get settingsTabConfigBuiltInSection => '内置页面';

  @override
  String get settingsTabConfigLibrary => '曲库';

  @override
  String get settingsTabConfigPlaylists => '歌单';

  @override
  String get settingsTabConfigPluginEntry => '插件入口';

  @override
  String get settingsTabConfigNoPlugins => '暂无可用插件';

  @override
  String get settingsTabConfigNoPluginsHint => '请先在设置中安装并启用插件';

  @override
  String get settingsTabConfigPluginOrder => '插件排序';

  @override
  String settingsTabConfigEnabledCount(int count) {
    return '已启用 $count 个标签（首页和设置固定显示）';
  }

  @override
  String get settingsTabConfigCollapseHint => '移动端超出 5 个时将折叠到「更多」菜单';

  @override
  String settingsTabConfigMaxTabs(int count) {
    return '最多显示 $count 个标签';
  }

  @override
  String settingsTabConfigSaveFailed(String error) {
    return '保存失败: $error';
  }

  @override
  String get settingsUpgradeStatusStable => '稳定版';

  @override
  String get settingsUpgradeStatusDev => '开发版';

  @override
  String get settingsUpgradeStatusDownloading => '正在下载...';

  @override
  String get settingsUpgradeStatusTesting => '正在验证...';

  @override
  String get settingsUpgradeStatusReplacing => '正在替换...';

  @override
  String get settingsUpgradeStatusResetting => '正在回退...';

  @override
  String get settingsUpgradeStatusRestarting => '正在重启...';

  @override
  String get settingsUpgradeStatusCompleted => '升级完成';

  @override
  String get settingsUpgradeStatusFailed => '升级失败';

  @override
  String get settingsUpgradeStatusIdle => '空闲';

  @override
  String get settingsFrontendVerDevVersion => '开发版本';

  @override
  String settingsFrontendVerCheckFailed(String error) {
    return '检查前端更新失败: $error';
  }

  @override
  String settingsScanScanFailed(String error) {
    return '扫描失败: $error';
  }

  @override
  String settingsScanCancelFailed(String error) {
    return '取消失败: $error';
  }

  @override
  String get settingsScanModeSkipDesc => '仅导入新发现的音乐文件';

  @override
  String get settingsScanModeReimportDesc => '重新扫描并覆盖所有音乐信息';

  @override
  String get settingsScanDismiss => '关闭提示';

  @override
  String get settingsScanExcludeDirTitle => '排除目录设置';

  @override
  String get settingsScanExcludeDirSubtitle => '配置扫描时需要忽略的目录';

  @override
  String get settingsScanModeSkip => '跳过已存在';

  @override
  String get settingsScanModeReimport => '重新导入';

  @override
  String get settingsScanStarting => '正在启动...';

  @override
  String get settingsScanScanLocal => '扫描本地音乐';

  @override
  String settingsScanScanSelectedDirs(int count) {
    return '扫描选中的 $count 个目录';
  }

  @override
  String get settingsScanTargetDirsTitle => '指定目录（可选）';

  @override
  String get settingsScanTargetDirsSubtitle => '仅扫描选中的目录，留空则扫描整个音乐库';

  @override
  String settingsScanTargetDirsSelected(int count) {
    return '已选 $count 个目录';
  }

  @override
  String get settingsScanDirsToScan => '将扫描的目录:';

  @override
  String get settingsScanClear => '清空';

  @override
  String get settingsScanCreatingPlaylists => '正在按目录自动创建歌单...';

  @override
  String get settingsScanSplittingCue => '正在切分整轨(CUE)...';

  @override
  String settingsScanSplittingCueProgress(int count) {
    return '正在切分整轨(CUE): 已处理 $count 个来源';
  }

  @override
  String get settingsScanDiscovering => '正在发现文件...';

  @override
  String settingsScanDiscoveringProgress(int count) {
    return '正在发现文件: 已发现 $count 个';
  }

  @override
  String settingsScanScanningFile(String file) {
    return '正在扫描: $file';
  }

  @override
  String settingsScanProgressStats(
    int scanned,
    int total,
    int imported,
    int skipped,
    int failed,
  ) {
    return '已处理: $scanned/$total, 导入: $imported, 跳过: $skipped, 失败: $failed';
  }

  @override
  String get settingsScanCancelScan => '取消扫描';

  @override
  String get settingsScanAutoCreatePlaylists => '扫描后自动创建歌单';

  @override
  String get settingsScanAutoCreatePlaylistsDesc => '按目录结构自动生成歌单';

  @override
  String get settingsScanLoadingConfig => '加载中...';

  @override
  String get settingsScanReadConfigFailed => '读取配置失败';

  @override
  String settingsScanSaveFailed(String error) {
    return '保存失败: $error';
  }

  @override
  String get settingsScanPlaylistModeDirectory => '按文件夹';

  @override
  String get settingsScanPlaylistModeDirectoryDesc => '每个文件夹生成独立歌单';

  @override
  String get settingsScanPlaylistModeTopLevel => '按顶层文件夹';

  @override
  String get settingsScanPlaylistModeTopLevelDesc => '子文件夹的歌曲合并到一级文件夹歌单';

  @override
  String get settingsScanPlaylistModeBubbleUp => '包含子目录';

  @override
  String get settingsScanPlaylistModeBubbleUpDesc => '歌曲同时出现在所有上级文件夹歌单';

  @override
  String get settingsScanPlaylistModeTitle => '歌单创建方式';

  @override
  String get settingsScanPlaylistModeDisabled => '已关闭自动创建歌单，此项不生效';

  @override
  String get settingsScanTitleSource => '使用文件名作为标题';

  @override
  String get settingsScanTitleSourceFilenameDesc =>
      '歌曲标题使用文件名（不含扩展名），适合文件名已编号的情况';

  @override
  String get settingsScanTitleSourceTagDesc => '歌曲标题优先使用音频标签信息';

  @override
  String get settingsScanTitleSourceSaved => '已保存，需以「重新导入」模式扫描后生效';

  @override
  String get settingsScanInterval10Min => '10 分钟';

  @override
  String get settingsScanInterval30Min => '30 分钟';

  @override
  String get settingsScanInterval1Hour => '1 小时';

  @override
  String get settingsScanInterval3Hour => '3 小时';

  @override
  String get settingsScanInterval6Hour => '6 小时';

  @override
  String get settingsScanInterval12Hour => '12 小时';

  @override
  String get settingsScanInterval24Hour => '24 小时';

  @override
  String settingsScanIntervalSeconds(int count) {
    return '$count 秒';
  }

  @override
  String get settingsScanAutoScan => '自动扫描';

  @override
  String settingsScanAutoScanInterval(String interval) {
    return '每 $interval 自动扫描一次';
  }

  @override
  String get settingsScanAutoScanOff => '关闭';

  @override
  String get settingsScanScanInterval => '扫描间隔';

  @override
  String settingsScanCompletedSummary(int count) {
    return '扫描完成，本地歌曲共 $count 首';
  }

  @override
  String settingsScanCompletedStats(int imported, int skipped, int failed) {
    return '本次导入 $imported 首，跳过 $skipped 首，失败 $failed 个';
  }

  @override
  String get settingsScanRescan => '重新扫描';

  @override
  String settingsScanCancelledSummary(int count) {
    return '扫描已取消 (已处理 $count 个文件)';
  }

  @override
  String get settingsScanErrorTitle => '扫描出错';

  @override
  String settingsExcludeDirLoadFailed(String error) {
    return '加载配置失败: $error';
  }

  @override
  String get settingsExcludeDirSaved => '排除目录配置已保存，后台正在清理被排除目录中的歌曲';

  @override
  String settingsExcludeDirSaveFailed(String error) {
    return '保存失败: $error';
  }

  @override
  String get settingsExcludeDirTabName => '名称排除';

  @override
  String get settingsExcludeDirTabPath => '路径排除';

  @override
  String get settingsExcludeDirTabPlaylist => '歌单排除';

  @override
  String get settingsExcludeDirSaving => '保存中...';

  @override
  String get settingsExcludeDirSaveConfig => '保存排除配置';

  @override
  String get settingsExcludeDirSaveHint => '保存后将自动清理被排除目录中的已导入歌曲';

  @override
  String get settingsExcludeDirInputName => '输入目录名称';

  @override
  String get settingsExcludeDirInputHint => '输入并选择或按回车添加';

  @override
  String get settingsExcludeDirLoadingCandidates => '正在加载候选列表...';

  @override
  String get settingsExcludeDirAdd => '添加';

  @override
  String get settingsExcludeDirExcludedNames => '已排除的目录名称:';

  @override
  String get settingsExcludeDirNameHint => '路径中任何层级包含该名称的目录都会被排除';

  @override
  String settingsExcludeDirMusicDir(String path) {
    return '音乐目录: $path';
  }

  @override
  String get settingsExcludeDirExcludedPaths => '已排除的路径:';

  @override
  String get settingsExcludeDirAutoCreateExcluded => '自动创建歌单时不纳入的目录:';

  @override
  String get settingsExcludeDirAutoCreateHint => '路径中任何层级包含该名称的目录都不会被自动创建歌单';

  @override
  String get settingsServersTitle => '服务器';

  @override
  String get settingsServersTestAll => '全部测试';

  @override
  String get settingsServersEmptyTitle => '尚未添加服务器';

  @override
  String get settingsServersEmptyHint =>
      '点击右下角「+」添加 API 地址。\n启动时会按顺序探测，优先使用排在前面的可达项。';

  @override
  String get settingsServersAdd => '添加服务器';

  @override
  String get settingsServersEditTitle => '编辑服务器';

  @override
  String get settingsServersNameLabel => '名称（可选）';

  @override
  String get settingsServersNameHint => '局域网 / 广域网 / 备用';

  @override
  String get settingsServersUrlLabel => 'API 地址';

  @override
  String get settingsServersUsername => '用户名';

  @override
  String get settingsServersPassword => '密码';

  @override
  String get settingsServersSave => '保存';

  @override
  String settingsServersSaveFailed(String error) {
    return '保存失败: $error';
  }

  @override
  String get settingsServersDeleteTitle => '删除服务器';

  @override
  String get settingsServersDeleteCurrentConfirm =>
      '此为当前正在使用的服务器，删除后下次启动将重新探测列表中其他项。是否继续？';

  @override
  String settingsServersDeleteConfirm(String name) {
    return '确定要删除「$name」吗？';
  }

  @override
  String settingsServersReachable(String name) {
    return '$name 可达';
  }

  @override
  String settingsServersUnreachable(String name) {
    return '$name 不可达';
  }

  @override
  String settingsServersProbeResult(int ok, int total) {
    return '探测完成：$ok / $total 可达';
  }

  @override
  String get settingsServersAlreadyCurrent => '已是当前使用的服务器';

  @override
  String settingsServersSwitched(String name) {
    return '已切换到 $name，请重新登录';
  }

  @override
  String get settingsServersSwitchTo => '切换到此项';

  @override
  String get settingsServersTestConnection => '测试连接';

  @override
  String get settingsServersEditAction => '编辑';

  @override
  String get settingsServersLocalMode => '本地模式';

  @override
  String get settingsServersLocalModeDesc => '开启后在设备上运行后端，无需网络即可播放本地音乐。';

  @override
  String get settingsServersMusicDir => '音乐目录';

  @override
  String get settingsServersNotSelected => '未选择';

  @override
  String get settingsServersSelect => '选择';

  @override
  String get settingsServersFixedMusicDirHint =>
      '通过「文件」App 或电脑（Finder / iTunes 文件共享）把音乐放入 Songloft 文件夹，然后重新扫描。';

  @override
  String settingsServersSwitchFailed(String error) {
    return '切换失败：$error';
  }

  @override
  String get settingsServersSwitchedLocal => '已切换到本地模式';

  @override
  String get settingsServersMusicDirUpdated => '音乐目录已更新';

  @override
  String get settingsDuplicateTitle => '重复歌曲检测';

  @override
  String get settingsDuplicateDismissError => '关闭提示';

  @override
  String get settingsDuplicateIntro =>
      '通过音频指纹识别内容相同的重复文件。不同文件名、不同格式的同一首歌都能被识别。';

  @override
  String get settingsDuplicateFingerprintStats => '指纹统计';

  @override
  String get settingsDuplicateLocalSongs => '本地歌曲';

  @override
  String get settingsDuplicateComputed => '已有指纹';

  @override
  String get settingsDuplicatePending => '待计算';

  @override
  String settingsDuplicateSongCount(int count) {
    return '$count 首';
  }

  @override
  String get settingsDuplicateChromaprintMissing =>
      '需要安装 ffmpeg（含 chromaprint 支持）才能使用音频指纹检测。Docker 用户升级到最新镜像即可。';

  @override
  String get settingsDuplicateStartCompute => '开始计算并检测';

  @override
  String get settingsDuplicateCheck => '检测重复';

  @override
  String get settingsDuplicateRecomputeAll => '重新计算全部指纹';

  @override
  String settingsDuplicateComputing(int computed, int total) {
    return '正在计算音频指纹... $computed/$total';
  }

  @override
  String settingsDuplicateFailed(int count) {
    return '失败: $count';
  }

  @override
  String get settingsDuplicateAutoDetect => '计算完成后将自动检测重复歌曲';

  @override
  String get settingsDuplicateRecheck => '重新检测';

  @override
  String get settingsDuplicateNoResults => '未发现重复歌曲';

  @override
  String get settingsDuplicateNoResultsHint => '音乐库很干净！';

  @override
  String settingsDuplicateSummary(int groups, int songs) {
    return '发现 $groups 组重复（共 $songs 首歌曲）';
  }

  @override
  String settingsDuplicateIgnoredCount(int count) {
    return '已忽略 $count 组';
  }

  @override
  String settingsDuplicateCleanAll(int count) {
    return '清理全部重复（删除 $count 首）';
  }

  @override
  String settingsDuplicateGroupLabel(int index) {
    return '重复组 $index';
  }

  @override
  String get settingsDuplicateUnignore => '取消忽略';

  @override
  String get settingsDuplicateIgnore => '忽略此组';

  @override
  String get settingsDuplicateDeleteUnselected => '删除未选中';

  @override
  String get settingsDuplicateRecommended => '推荐';

  @override
  String get settingsDuplicateConfirmTitle => '确认删除';

  @override
  String settingsDuplicateConfirmMessage(int count) {
    return '将删除 $count 首重复歌曲及其对应的音频文件，保留每组中选中的版本。此操作不可撤销。';
  }

  @override
  String settingsDuplicateDeleted(int count) {
    return '已删除 $count 首重复歌曲';
  }

  @override
  String settingsDuplicateDeleteFailed(String error) {
    return '删除失败: $error';
  }

  @override
  String get settingsCategoryAppearanceTitle => '外观设置';

  @override
  String get settingsCategoryAppearanceSubtitle => '主题、菜单和显示';

  @override
  String get settingsCategoryPlaybackTitle => '播放设置';

  @override
  String get settingsCategoryPlaybackSubtitle => '音质';

  @override
  String get settingsCategoryLibraryTitle => '音乐库管理';

  @override
  String get settingsCategoryLibrarySubtitle => '扫描、导入和转换';

  @override
  String get settingsCategoryExtensionsTitle => '扩展';

  @override
  String get settingsCategoryExtensionsSubtitle => '插件管理';

  @override
  String get settingsCategoryCacheTitle => '缓存管理';

  @override
  String get settingsCategoryCacheSubtitle => '服务端和本地缓存';

  @override
  String get settingsCategoryNetworkTitle => '网络设置';

  @override
  String get settingsCategoryNetworkSubtitle => '代理配置';

  @override
  String get settingsCategoryDataTitle => '数据管理';

  @override
  String get settingsCategoryDataSubtitle => '歌单导出与导入';

  @override
  String get settingsCategoryAboutTitle => '关于与更新';

  @override
  String get settingsCategoryAboutSubtitle => '版本和日志';

  @override
  String get settingsCategoryAccountTitle => '账户';

  @override
  String get settingsCategoryAccountSubtitle => '服务器和登录';

  @override
  String get settingsDevVersion => '开发版';

  @override
  String get settingsStableVersion => '正式版';

  @override
  String get settingsLocalMode => '本地模式';

  @override
  String get settingsManage => '管理';

  @override
  String get settingsMenuTitle => '菜单设置';

  @override
  String get settingsMenuLibrary => '曲库';

  @override
  String get settingsMenuPlaylists => '歌单';

  @override
  String settingsTabsEnabledCount(int count) {
    return '已启用 $count 个标签（首页和设置固定显示）';
  }

  @override
  String get settingsTabsCollapseHint => '移动端超出 5 个时将折叠到「更多」菜单';

  @override
  String settingsMaxTabsLimit(int count) {
    return '最多显示 $count 个标签';
  }

  @override
  String settingsSaveFailed(String error) {
    return '保存失败: $error';
  }

  @override
  String get settingsQualityOriginal => '原始音质';

  @override
  String get settingsQualityLow => '低 (128kbps)';

  @override
  String get settingsQualityMedium => '中 (192kbps)';

  @override
  String get settingsQualityHigh => '高 (320kbps)';

  @override
  String get settingsQualityTitle => '音质';

  @override
  String get settingsQualityDialogTitle => '选择音质';

  @override
  String get settingsQualityOriginalDesc => '不转码，使用文件原始码率';

  @override
  String get settingsQualityTranscodeDesc => '转码为 MP3，适合弱网环境';

  @override
  String get settingsAutoPlayOnLaunchTitle => '打开后自动播放';

  @override
  String get settingsAutoPlayOnLaunchDesc => '启动客户端后自动继续上次的播放';

  @override
  String get settingsAutoEnterLyricsOnLaunchTitle => '打开后自动进入歌词';

  @override
  String get settingsAutoEnterLyricsOnLaunchDesc => '启动客户端后自动进入全屏歌词界面（按屏幕自动适配）';

  @override
  String get settingsNotificationLyricInTitleTitle => '通知栏歌词占用标题行';

  @override
  String get settingsNotificationLyricInTitleDesc =>
      '开启：标题行显示歌词、歌名归副标题；关闭：标题行显示歌名、副标题显示歌词';

  @override
  String get settingsShortcutsEntryTitle => '键盘快捷键';

  @override
  String get settingsShortcutsEntrySubtitle => '自定义播放控制按键';

  @override
  String get settingsShortcutsPageTitle => '键盘快捷键';

  @override
  String get settingsShortcutsEnableTitle => '启用键盘快捷键';

  @override
  String get settingsShortcutsEnableSubtitle => '在桌面窗口内使用快捷键控制播放';

  @override
  String get settingsShortcutActionPlayPause => '播放 / 暂停';

  @override
  String get settingsShortcutActionPlayNext => '下一首';

  @override
  String get settingsShortcutActionPlayPrev => '上一首';

  @override
  String get settingsShortcutActionSeekForward => '快进';

  @override
  String get settingsShortcutActionSeekBackward => '快退';

  @override
  String get settingsShortcutActionVolumeUp => '音量 +';

  @override
  String get settingsShortcutActionVolumeDown => '音量 -';

  @override
  String get settingsShortcutActionToggleMute => '静音切换';

  @override
  String get settingsShortcutRecordPrompt => '请按下快捷键组合…';

  @override
  String get settingsShortcutUnset => '未设置';

  @override
  String get settingsShortcutConflictTitle => '快捷键冲突';

  @override
  String settingsShortcutConflict(String action) {
    return '该组合键已被「$action」占用';
  }

  @override
  String get settingsShortcutOverride => '覆盖';

  @override
  String get settingsShortcutClear => '清除';

  @override
  String get settingsShortcutResetAll => '恢复全部默认';

  @override
  String get settingsShortcutResetAllConfirm => '确定要将所有快捷键恢复为默认值吗？';

  @override
  String settingsQualitySwitched(String quality) {
    return '音质已切换为$quality';
  }

  @override
  String settingsSwitchFailed(String error) {
    return '切换失败: $error';
  }

  @override
  String get settingsLibraryDuplicateTitle => '重复歌曲检测';

  @override
  String get settingsLibraryDuplicateSubtitle => '通过音频指纹识别内容相同的重复文件';

  @override
  String get settingsPluginStoreTitle => '插件商店';

  @override
  String get settingsPluginStoreSubtitle => '浏览和安装插件';

  @override
  String get settingsExportPlaylistTitle => '导出歌单';

  @override
  String get settingsExportPlaylistSubtitle => '将所有歌单数据备份为 JSON 文件';

  @override
  String get settingsImportPlaylistTitle => '导入歌单';

  @override
  String get settingsImportPlaylistSubtitle => '从 JSON 备份文件还原歌单数据';

  @override
  String get settingsDownloadAppTitle => '下载客户端 App';

  @override
  String get settingsDownloadAppSubtitle => '获取手机 / 桌面原生客户端，支持后台播放、缓存等';

  @override
  String get settingsWebDebugConsoleTitle => '调试控制台';

  @override
  String get settingsWebDebugConsoleSubtitle => '启用 NextConsole 网页调试面板（需刷新页面）';

  @override
  String get settingsWebDebugConsoleEnabled => '调试控制台已启用，页面将刷新';

  @override
  String get settingsWebDebugConsoleDisabled => '调试控制台已关闭，页面将刷新';

  @override
  String get settingsAboutTitle => '关于';

  @override
  String get settingsAboutSubtitle => '版本信息和许可证';

  @override
  String get settingsAccountServer => '服务器';

  @override
  String get settingsNoMusicDir => '未选择音乐目录';

  @override
  String get settingsLogout => '退出登录';

  @override
  String get settingsLogoutConfirmTitle => '确认退出';

  @override
  String get settingsLogoutConfirmContent => '确定要退出当前账户吗？';

  @override
  String get settingsLogoutButton => '确认退出';

  @override
  String get settingsExportNotLoggedIn => '未登录，无法导出';

  @override
  String settingsExportFailed(String error) {
    return '导出失败: $error';
  }

  @override
  String get settingsImportReadFailed => '无法读取文件内容';

  @override
  String get settingsImportPathFailed => '无法获取文件路径';

  @override
  String settingsImportComplete(
    Object created,
    Object merged,
    Object songsCreated,
    Object songsMatched,
  ) {
    return '导入完成: 新建歌单 $created, 合并歌单 $merged, 新建歌曲 $songsCreated, 匹配歌曲 $songsMatched';
  }

  @override
  String settingsImportFailed(String error) {
    return '导入失败: $error';
  }

  @override
  String get settingsCheckServerUpdate => '检查服务端更新';

  @override
  String settingsUpdateAvailable(String version) {
    return '发现新版本: $version';
  }

  @override
  String settingsCurrentVersionLatest(String version) {
    return '当前版本: $version (已是最新)';
  }

  @override
  String get settingsCheckingUpdate => '正在检查更新...';

  @override
  String get settingsCheckUpdateFailed => '检查更新失败';

  @override
  String get settingsCheckClientUpdate => '检查客户端更新';

  @override
  String settingsCurrentVersion(String version) {
    return '当前版本: $version';
  }

  @override
  String get settingsHlsProxyTitle => 'HLS 电台后端代理';

  @override
  String get settingsHlsProxySubtitle =>
      '开启后服务端拉取电台 m3u8 并代理切片,可绕过 Referer 防盗链 / CORS。所有切片走本机带宽,注意流量成本';

  @override
  String get settingsHlsProxyEnabled => '已开启 HLS 代理';

  @override
  String get settingsHlsProxyDisabled => '已关闭 HLS 代理';

  @override
  String get settingsInsecureTlsTitle => '忽略 SSL 证书校验';

  @override
  String get settingsInsecureTlsSubtitle =>
      '连接使用自签或无效 HTTPS 证书的服务器时开启。同时对接口请求和音频播放生效';

  @override
  String get settingsInsecureTlsEnabled => '已开启忽略证书校验';

  @override
  String get settingsInsecureTlsDisabled => '已关闭忽略证书校验';

  @override
  String get settingsInsecureTlsWarnTitle => '降低安全性';

  @override
  String get settingsInsecureTlsWarnContent =>
      '开启后将接受任意 HTTPS 证书，可能遭受中间人攻击。请仅在信任的内网或自签证书场景使用。确定开启吗？';

  @override
  String get settingsHttpProxyTitle => 'HTTP 代理';

  @override
  String get settingsHttpProxyNotConfigured => '未配置（直连）';

  @override
  String get settingsHttpProxyDialogDesc =>
      '设置全局 HTTP 代理，所有后端外发请求（插件下载、升级检查等）将通过此代理转发。留空则直连。';

  @override
  String get settingsHttpProxyAddressLabel => '代理地址';

  @override
  String get settingsHttpProxyHelper => '支持 HTTP/HTTPS/SOCKS5 代理';

  @override
  String get settingsClear => '清除';

  @override
  String get settingsSave => '保存';

  @override
  String get settingsHttpProxyCleared => '已清除 HTTP 代理';

  @override
  String settingsHttpProxySet(String proxy) {
    return 'HTTP 代理已设置为 $proxy';
  }

  @override
  String get settingsLogLevelDebug => 'Debug（详细，调试用）';

  @override
  String get settingsLogLevelInfo => 'Info（默认）';

  @override
  String get settingsLogLevelWarn => 'Warn';

  @override
  String get settingsLogLevelError => 'Error（仅错误）';

  @override
  String get settingsLogLevelTitle => '日志等级';

  @override
  String get settingsLogLevelDialogTitle => '选择日志等级';

  @override
  String settingsLogLevelSwitched(String level) {
    return '日志等级已切换为 $level';
  }

  @override
  String get settingsExportLogsTitle => '导出日志';

  @override
  String get settingsExportLogsSubtitle => '打包前后端日志（已脱敏）用于提交问题反馈';

  @override
  String get settingsExportLogsShareSubject => 'Songloft 日志';

  @override
  String get settingsExportLogsSuccess => '日志已打包，请选择分享或保存方式';

  @override
  String get settingsExportLogsSuccessNoBackend => '已导出前端日志（未获取到后端日志）';

  @override
  String settingsExportLogsFailed(String error) {
    return '导出日志失败: $error';
  }

  @override
  String get settingsAccountUrlNotConfigured => '未配置 · 点击添加';

  @override
  String settingsAccountUrlSummary(int count, String label) {
    return '$count 个地址 · 当前: $label';
  }

  @override
  String get settingsAccountLoading => '加载中...';

  @override
  String get settingsAboutDesc1 => 'Songloft 是一个开源的个人音乐服务器应用。';

  @override
  String get settingsAboutDesc2 => '支持本地音乐库管理、在线播放和插件扩展。';

  @override
  String get settingsAboutGithubSemantics => '打开 GitHub 页面';

  @override
  String get settingsUpgradeCheckTimeout => '检查更新超时，请尝试切换代理后重试';

  @override
  String settingsUpgradeCheckFailed(String error) {
    return '检查更新失败: $error';
  }

  @override
  String get settingsUpgradeChannelDev => '开发版';

  @override
  String get settingsUpgradeChannelStable => '正式版';

  @override
  String settingsUpgradeVersionWithDetails(String version, String details) {
    return '$version ($details)';
  }

  @override
  String settingsUpgradeStartFailed(String error) {
    return '启动升级失败: $error';
  }

  @override
  String get settingsUpgradeConfirmReset => '确认回退';

  @override
  String get settingsUpgradeConfirmResetContent =>
      '确定要回退到 Docker 镜像的底包版本吗？\n\n回退后服务将自动重启。';

  @override
  String settingsUpgradeResetFailed(String error) {
    return '回退失败: $error';
  }

  @override
  String get settingsUpgradeTitle => '检查更新';

  @override
  String get settingsUpgradeChecking => '正在检查更新...';

  @override
  String get settingsUpgradeGithubProxy => 'GitHub 代理';

  @override
  String get settingsUpgradeCustomProxy => '自定义代理';

  @override
  String get settingsUpgradeProxyHelper => '输入代理地址，如 https://ghproxy.com/';

  @override
  String get settingsUpgradeUpToDate => '已是最新版本';

  @override
  String settingsUpgradeCurrentVersion(String version) {
    return '当前版本: $version';
  }

  @override
  String get settingsUpgradeSelectVersion => '选择升级版本:';

  @override
  String settingsUpgradeBuildTime(String time) {
    return '构建时间: $time';
  }

  @override
  String get settingsUpgradeReleaseNotes => '更新说明:';

  @override
  String get settingsUpgradeResetting => '正在回退...';

  @override
  String get settingsUpgradeResetButton => '回退到底包版本';

  @override
  String get settingsUpgradeCompleted => '升级完成';

  @override
  String get settingsUpgradeRestartSoon => '应用即将重启';

  @override
  String get settingsUpgradeFailed => '升级失败';

  @override
  String get settingsUpgradeClose => '关闭';

  @override
  String get settingsUpgradeRecheck => '重新检查';

  @override
  String get settingsUpgradeLater => '稍后';

  @override
  String get settingsUpgradeGoDownload => '前往下载';

  @override
  String get settingsUpgradeUpgradeNow => '立即升级';

  @override
  String get settingsFrontendUpgradeCheckTimeout => '检查更新超时，请尝试切换代理后重试';

  @override
  String get settingsFrontendUpgradeTitle => '客户端更新';

  @override
  String get settingsFrontendUpgradeChecking => '正在检查更新...';

  @override
  String get settingsFrontendUpgradeGithubProxy => 'GitHub 代理';

  @override
  String get settingsFrontendUpgradeCustomProxy => '自定义代理';

  @override
  String get settingsFrontendUpgradeProxyHelper =>
      '输入代理地址，如 https://ghproxy.com/';

  @override
  String get settingsFrontendUpgradeUpToDate => '已是最新版本';

  @override
  String settingsFrontendUpgradeCurrentVersion(String version) {
    return '当前版本: $version';
  }

  @override
  String settingsFrontendUpgradeLatestVersion(String version) {
    return '最新版本: $version';
  }

  @override
  String settingsFrontendUpgradePublishedAt(String date) {
    return '发布时间: $date';
  }

  @override
  String get settingsFrontendUpgradeReleaseNotes => '更新说明:';

  @override
  String get settingsFrontendUpgradeRecheck => '重新检查';

  @override
  String get settingsFrontendUpgradeClose => '关闭';

  @override
  String get settingsFrontendUpgradeLater => '稍后';

  @override
  String get settingsFrontendUpgradeGoDownload => '前往下载';

  @override
  String get settingsConfigTitle => '配置管理';

  @override
  String get settingsConfigSubtitle => '管理系统配置项';

  @override
  String get settingsConfigAdd => '添加配置';

  @override
  String get settingsConfigRefresh => '刷新';

  @override
  String get settingsConfigEmpty => '暂无配置项';

  @override
  String get settingsConfigEmptyHint => '点击「添加配置」创建新的配置项';

  @override
  String get settingsConfigKeyLabel => '配置键';

  @override
  String get settingsConfigKeyHint => '例如: app.setting.name';

  @override
  String get settingsConfigKeyRequired => '请输入配置键';

  @override
  String get settingsConfigValueLabel => '配置值';

  @override
  String get settingsConfigValueHint => '配置值（支持多行）';

  @override
  String get settingsConfigValueRequired => '请输入配置值';

  @override
  String get settingsConfigAddButton => '添加';

  @override
  String get settingsConfigAdded => '配置已添加';

  @override
  String settingsConfigAddFailed(String error) {
    return '添加失败: $error';
  }

  @override
  String settingsConfigEditTitle(String key) {
    return '编辑配置: $key';
  }

  @override
  String settingsConfigKeyDisplay(String key) {
    return '配置键: $key';
  }

  @override
  String get settingsConfigSave => '保存';

  @override
  String get settingsConfigUpdated => '配置已更新';

  @override
  String settingsConfigUpdateFailed(String error) {
    return '更新失败: $error';
  }

  @override
  String get settingsConfigConfirmDelete => '确认删除';

  @override
  String settingsConfigDeleteConfirm(String key) {
    return '确定要删除配置 \"$key\" 吗？';
  }

  @override
  String get settingsConfigDeleted => '配置已删除';

  @override
  String settingsConfigDeleteFailed(String error) {
    return '删除失败: $error';
  }

  @override
  String get settingsConfigEdit => '编辑';

  @override
  String get settingsTokenTitle => '令牌管理';

  @override
  String get settingsTokenSubtitle => '管理登录令牌';

  @override
  String get settingsTokenEmpty => '暂无令牌';

  @override
  String get settingsTokenConfirmRevoke => '确认撤销';

  @override
  String get settingsTokenRevokeConfirm => '撤销此令牌后，对应的登录会话将失效。确定继续吗？';

  @override
  String get settingsTokenRevoke => '撤销';

  @override
  String get settingsTokenRevoked => '令牌已撤销';

  @override
  String settingsTokenRevokeFailed(String error) {
    return '撤销失败: $error';
  }

  @override
  String get settingsTokenStatusRevoked => '已撤销';

  @override
  String get settingsTokenStatusExpired => '已过期';

  @override
  String get settingsTokenStatusActive => '活跃';

  @override
  String settingsTokenType(String type) {
    return '类型: $type';
  }

  @override
  String get settingsTokenTypeAccess => '访问令牌';

  @override
  String get settingsTokenTypeRefresh => '刷新令牌';

  @override
  String settingsTokenClient(String info) {
    return '客户端: $info';
  }

  @override
  String settingsTokenExpiresAt(String time) {
    return '过期时间: $time';
  }

  @override
  String get coreTrayOpen => '打开 Songloft';

  @override
  String get coreTrayOpenLogs => '打开日志目录';

  @override
  String get coreTrayExit => '退出';

  @override
  String get coreUrlEmpty => 'URL 不能为空';

  @override
  String get coreUrlInvalid => '请输入有效的 URL（包含 http:// 或 https://）';

  @override
  String get corePickMusicDir => '选择音乐文件夹';

  @override
  String get categoryFieldGenre => '流派';

  @override
  String get categoryFieldArtist => '歌手';

  @override
  String get categoryFieldAlbum => '专辑';

  @override
  String get categoryFieldYear => '年份';

  @override
  String get categoryFieldDecade => '年代';

  @override
  String get categoryFieldLanguage => '语种';

  @override
  String get categoryFieldStyle => '风格';

  @override
  String get categoryValueUnknown => '未知';

  @override
  String categoryValueYear(String value) {
    return '$value 年';
  }

  @override
  String categoryValueDecade(String value) {
    return '$value 年代';
  }

  @override
  String get categoryBrowseTitle => '分类浏览';

  @override
  String categoryEmptyTitle(String label) {
    return '暂无「$label」分类';
  }

  @override
  String get categoryEmptySubtitle => '该维度下还没有可归类的歌曲';

  @override
  String categorySongCount(int count) {
    return '$count 首';
  }

  @override
  String categorySearchHint(String label) {
    return '搜索$label…';
  }

  @override
  String categoryNoMatch(String label) {
    return '未找到匹配的$label';
  }
}
