import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/core/backend/run_mode_provider.dart';
import 'package:songloft_flutter/core/theme/app_dimensions.dart';
import 'package:songloft_flutter/core/theme/app_theme.dart';
import 'package:songloft_flutter/core/theme/widgets/glass_surface.dart';
import 'package:songloft_flutter/features/dlna/domain/dlna_state.dart';
import 'package:songloft_flutter/features/dlna/presentation/providers/dlna_provider.dart';
import 'package:songloft_flutter/features/library/presentation/providers/favorite_provider.dart';
import 'package:songloft_flutter/features/player/domain/mini_player_controls.dart';
import 'package:songloft_flutter/features/player/domain/player_state.dart';
import 'package:songloft_flutter/features/player/presentation/providers/audio_track_provider.dart';
import 'package:songloft_flutter/features/player/presentation/providers/mini_player_controls_provider.dart';
import 'package:songloft_flutter/features/player/presentation/providers/player_provider.dart';
import 'package:songloft_flutter/features/player/presentation/widgets/audio_track_control.dart';
import 'package:songloft_flutter/features/player/presentation/widgets/capsule_mini_player.dart';
import 'package:songloft_flutter/features/player/presentation/widgets/desktop_player.dart';
import 'package:songloft_flutter/features/player/presentation/widgets/popup_controls.dart';
import 'package:songloft_flutter/features/player/presentation/widgets/volume_control.dart';
import 'package:songloft_flutter/features/settings/presentation/providers/song_cache_provider.dart';
import 'package:songloft_flutter/l10n/app_localizations.dart';
import 'package:songloft_flutter/l10n/l10n_holder.dart';
import 'package:songloft_flutter/shared/models/song.dart';

/// 大屏胶囊迷你播放器（`navigationStyle == 'capsule'`，songloft-org/songloft-player）
///
/// 覆盖三件事：pill 几何（高 64 / 全圆角）与材质（大屏真毛玻璃、手机静态玻璃）、
/// 大屏工具栏的常驻/收纳分界（睡眠定时与倍速必须收进「更多」，且点开真的能出抽屉）、
/// 以及标准模式大屏底栏不受影响（仍是 90px + border-top）。
///
/// 进度条单独覆盖：轨道 / 填充整宽贴着 pill 顶边（miot 插件 / Lynx 客户端的形态），
/// 两端由 pill 轮廓顺着顶角弧线裁掉 —— 大屏档靠 `GlassSurface` 的 `ClipRRect`，
/// 手机档靠另补的一层 `ClipRRect`；并且点按位置要按热区宽度线性映射成 seek 位置。
void _noop() {}

/// 取像素的用例需要 `RepaintBoundary` 才能 `toImage()`；其余用例原样返回。
Widget _probe(GlobalKey? key, Widget child) =>
    key == null ? child : RepaintBoundary(key: key, child: child);

void main() {
  Song testSong() => Song(
    id: 1,
    type: 'local',
    title: '胶囊测试歌曲',
    artist: '测试艺术家',
    duration: 200,
    addedAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  /// 受控的假 Notifier：跳过真实 build 副作用（音频后端 / 存储 / 订阅），
  /// 只把测试关心的字段摆进 state。切歌 / 调音量等动作在测试里不触发。
  PlayerState buildState({
    bool hasSong = true,
    Duration currentTime = Duration.zero,
    Duration duration = const Duration(seconds: 200),
    bool hasPrevNextQueue = true,
  }) {
    final song = testSong();
    return PlayerState(
      currentSong: hasSong ? song : null,
      // 队列长度 >1 且 index 居中 → hasPrev / hasNext 同时为真
      playlist: hasSong && hasPrevNextQueue ? [song, song, song] : const [],
      currentIndex: hasSong && hasPrevNextQueue ? 1 : -1,
      currentTime: currentTime,
      duration: duration,
    );
  }

  Future<void> pumpCapsule(
    WidgetTester tester, {
    required Widget capsule,
    PlayerState? state,
    MiniPlayerControls controls = MiniPlayerControls.prevNext,
    String navigationStyle = 'capsule',
    Size viewport = const Size(1200, 800),
    _SeekRecorder? notifier,
    GlobalKey? probeKey,
    ThemeData? themeOverride,
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final playerState = state ?? buildState();
    final container = ProviderContainer(
      overrides: [
        playerStateProvider.overrideWith(
          () => notifier ?? _FakePlayerNotifier(playerState),
        ),
        miniPlayerControlsProvider.overrideWith(
          () => _FixedMiniControls(controls),
        ),
        audioTrackProvider.overrideWith(_FixedAudioTrack.new),
        dlnaStateProvider.overrideWith(_FixedDlna.new),
        runModeProvider.overrideWith(_FixedRunMode.new),
        songCacheProvider.overrideWith(_FixedSongCache.new),
        favoriteProvider.overrideWith(_FixedFavorite.new),
      ],
    );
    addTearDown(container.dispose);

    final theme =
        themeOverride ??
        ThemeData(
          extensions: [
            SongloftThemeExtension(navigationStyle: navigationStyle),
          ],
        );
    // 部分子组件（PopupPlayModeControl / PopupSpeedControl）走全局 l10n 访问器，
    // 那是 MaterialApp.builder 在每帧刷新的；测试里手动喂一次。
    updateGlobalL10n(lookupAppLocalizations(const Locale('zh')));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: theme,
          // 只测底部这一条：用 Stack + Positioned 复刻 AdaptiveScaffold
          // 浮起胶囊给到的紧宽度约束（Align 会给松约束，量出来的宽度没意义）
          home: _probe(
            probeKey,
            Scaffold(
              // 取像素的用例要一个已知的纯色背景，默认 surface 不是纯白
              backgroundColor: probeKey == null ? null : Colors.white,
              body: Stack(
                children: [
                  Positioned(left: 0, right: 0, bottom: 0, child: capsule),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// pill 全圆角在该高度处的轮廓（相对 pill 左边缘的 x）。
  ///
  /// 胶囊半径 = 高度 / 2，顶边那一段轮廓仍在往回收；轨道 / 填充的左右端点都必须
  /// 落在轮廓内侧（即端点 x >= 轮廓 x），否则会被 pill 的 `ClipRRect` 削掉。
  double pillEdgeAt(double height, double y) {
    final radius = height / 2;
    if (y >= radius) return radius;
    final dy = radius - y;
    return radius - math.sqrt(radius * radius - dy * dy);
  }

  testWidgets('大屏胶囊：pill 高 64、全圆角 32、真毛玻璃 sigma 20', (tester) async {
    await pumpCapsule(tester, capsule: const CapsuleMiniPlayer());

    final pill = tester.widget<GlassSurface>(find.byType(GlassSurface));
    expect(pill.borderRadius, BorderRadius.circular(32));
    expect(pill.sigma, 20);

    // 紧宽度约束下 pill 横跨整屏（左右各留 16）
    final size = tester.getSize(find.byKey(CapsuleMiniPlayer.pillKey));
    expect(size.height, AppCapsulePlayer.heightDesktop);
    expect(size.height, 64);
    expect(size.width, 1200 - AppCapsulePlayer.marginHorizontalDesktop * 2);

    // 真毛玻璃只在大屏档：手机档刻意省掉一次 saveLayer
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('大屏胶囊：落影只画在轮廓之外，玻璃顶边不被压暗', (tester) async {
    await pumpCapsule(tester, capsule: const CapsuleMiniPlayer());

    // (1) `GlassSurface` 自带的 boxShadow 画在它自己的 ClipRRect 里，只能把半透玻璃
    // 压灰、起不到投影作用 —— 大屏档必须显式关掉，改由外层 painter 在轮廓外落影
    final glass = tester.widget<GlassSurface>(find.byType(GlassSurface));
    expect(glass.boxShadow, isEmpty);

    // 外层不再用 DecoratedBox(boxShadow:)（那样阴影会铺进胶囊内部）
    final outer =
        tester
            .widgetList<DecoratedBox>(
              find.ancestor(
                of: find.byKey(CapsuleMiniPlayer.pillKey),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((w) => w.decoration)
            .whereType<BoxDecoration>();
    expect(outer.every((d) => d.boxShadow == null), isTrue);

    // (2) 唯一的落影来自 painter，且画在轮廓之外（painter 里做了 difference 裁剪）
    final paint = tester.widget<CustomPaint>(
      find
          .ancestor(
            of: find.byType(GlassSurface),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    expect(paint.painter, isA<CapsuleShadowPainter>());
  });

  testWidgets('大屏胶囊：落影不渗到进度条那一侧（胶囊顶边以上零着色）', (tester) async {
    final probeKey = GlobalKey();
    await pumpCapsule(
      tester,
      capsule: const CapsuleMiniPlayer(),
      probeKey: probeKey,
    );

    final pill = tester.getRect(find.byKey(CapsuleMiniPlayer.pillKey));
    final origin = tester.getTopLeft(find.byKey(probeKey));

    late List<int> px;
    late int imgWidth;
    await tester.runAsync(() async {
      final boundary =
          probeKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      imgWidth = image.width;
      final data =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      px = data.buffer.asUint8List();
    });

    int red(int x, int y) => px[((y * imgWidth) + x) << 2];
    int col(double x) => (x - origin.dx).round();
    int row(double y) => (y - origin.dy).round();

    // 进度条整条压在胶囊顶边上：顶边往上一律不能被落影染灰，否则看着就是
    // 「进度条自带一圈很重的阴影」（背景在该用例里是纯白 255）
    var aboveDirty = 0;
    for (var y = row(pill.top) - 8; y <= row(pill.top) - 2; y++) {
      for (var x = 0; x < imgWidth; x++) {
        if (red(x, y) != 255) aboveDirty++;
      }
    }
    expect(aboveDirty, 0, reason: '胶囊顶边以上必须零着色（进度条就在顶边上）');

    // 反过来：落影没有一并被砍光 —— 底边外侧仍要有一道肉眼可见的柔和投影
    var belowDarkest = 255;
    for (var y = row(pill.bottom) + 2; y <= row(pill.bottom) + 10; y++) {
      for (var x = col(pill.left) - 20; x <= col(pill.right) + 20; x++) {
        if (red(x, y) < belowDarkest) belowDarkest = red(x, y);
      }
    }
    expect(belowDarkest, lessThan(252), reason: '底边外侧仍要有落影，浮起感不能丢');
  });

  testWidgets('玻璃高光渐变不能插值到透明黑（顶边暗带的根因）', (tester) async {
    const highlight = Color(0x99FFFFFF);

    /// 胶囊玻璃的高光渐变（大屏在 `GlassSurface` 内层，手机在静态玻璃上）
    List<Gradient> gradientsUnder(WidgetTester tester, Finder root) =>
        tester
            .widgetList<DecoratedBox>(
              find.descendant(of: root, matching: find.byType(DecoratedBox)),
            )
            .map((w) => w.decoration)
            .whereType<BoxDecoration>()
            .map((d) => d.gradient)
            .whereType<Gradient>()
            .toList();

    // 渐变色按未预乘的 RGBA 逐通道插值：`Colors.transparent` 是透明**黑**，
    // 白 60% → 透明黑 会在中途插出灰 30%，落在半透玻璃上就是顶边那条很重的暗带
    // （也正是进度条所在的一行）。终点必须用同色透明。
    void expectSameHueFade(List<Gradient> gradients) {
      expect(gradients, hasLength(1));
      expect(gradients.single, isA<LinearGradient>());
      final colors = (gradients.single as LinearGradient).colors;
      expect(colors, hasLength(2));
      expect(colors.first, highlight);
      expect(colors.last.a, 0);
      expect(
        colors.last,
        isNot(Colors.transparent),
        reason: '终点必须用 Color.withValues(alpha: 0)，不能用 Colors.transparent',
      );
    }

    // 大屏档：GlassSurface 内层的高光
    await pumpCapsule(tester, capsule: const CapsuleMiniPlayer());
    expectSameHueFade(gradientsUnder(tester, find.byType(GlassSurface)));

    // 手机档：静态玻璃
    await pumpCapsule(
      tester,
      capsule: const CapsuleMiniPlayer.compact(),
      viewport: const Size(400, 800),
    );
    expectSameHueFade(
      gradientsUnder(tester, find.byKey(CapsuleMiniPlayer.pillKey)),
    );
  });

  testWidgets('高对比度下无歌词按钮仍可用且不降低前景透明度', (tester) async {
    for (final theme in [
      AppTheme.lightTheme(increaseContrast: true),
      AppTheme.darkTheme(increaseContrast: true),
    ]) {
      await pumpCapsule(
        tester,
        capsule: const CapsuleMiniPlayer(),
        themeOverride: theme,
      );
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.lyrics_rounded),
      );
      expect(button.onPressed, isNotNull);
      expect((button.icon as Icon).color, isNull);
      expect(find.byType(BackdropFilter), findsNothing);
      await pumpCapsule(
        tester,
        capsule: const DesktopPlayer(),
        themeOverride: theme,
      );
      final standardButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.lyrics_rounded),
      );
      expect(standardButton.onPressed, isNotNull);
      expect((standardButton.icon as Icon).color, isNull);
    }
  });

  testWidgets('大屏胶囊：常驻工具栏五项齐全，睡眠定时/倍速/均衡器收进「更多」', (tester) async {
    await pumpCapsule(tester, capsule: const CapsuleMiniPlayer());

    // 常驻五项
    expect(find.byType(PopupPlayModeControl), findsOneWidget);
    expect(find.byType(ResponsiveVolumeControl), findsOneWidget);
    expect(find.byTooltip('歌词'), findsOneWidget);
    expect(find.byTooltip('播放列表'), findsOneWidget);
    expect(find.byTooltip('更多'), findsOneWidget);

    // 投屏 / 音轨是条件项（CastButton 原生端常驻、音轨单轨自动隐藏），不计入五项
    expect(find.byType(AudioTrackControl), findsOneWidget);

    // 均衡器 / 睡眠定时 / 倍速都不在栏上直出
    expect(find.byTooltip('均衡器'), findsNothing);
    expect(find.byIcon(Icons.bedtime_outlined), findsNothing);
    expect(find.byIcon(Icons.speed_rounded), findsNothing);

    // 「更多」菜单里三样俱全
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(find.text('均衡器'), findsOneWidget);
    expect(find.text('睡眠定时'), findsOneWidget);
    expect(find.text('倍速'), findsOneWidget);
    expect(find.text('歌曲信息'), findsOneWidget);
  });

  testWidgets('大屏胶囊：更多 → 倍速 弹出档位抽屉（无锚点场景走底部抽屉）', (tester) async {
    await pumpCapsule(tester, capsule: const CapsuleMiniPlayer());

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('倍速'));
    await tester.pumpAndSettle();

    // 抽屉标题 + 档位列表（0.5x / 正常 / 2.0x，与标准模式浮层同一份文案）
    expect(find.byType(SpeedOptionsList), findsOneWidget);
    expect(find.text('正常'), findsOneWidget);
    expect(find.text('0.5x'), findsOneWidget);
    expect(find.text('2.0x'), findsOneWidget);
  });

  testWidgets('大屏胶囊：宽度不足时收起时间文本，宽裕时显示', (tester) async {
    await pumpCapsule(
      tester,
      capsule: const CapsuleMiniPlayer(),
      state: buildState(currentTime: const Duration(seconds: 65)),
    );
    expect(find.text('01:05 / 03:20'), findsOneWidget);

    // 800 宽平板：768 - 32 = 736 的行宽 >= 620 阈值 → 时间正常显示
    tester.view.physicalSize = const Size(800, 1000);
    await tester.pump();
    expect(find.text('01:05 / 03:20'), findsOneWidget);

    // 600 宽（tablet 断点下沿）：568 - 32 = 536 < 620 → 让位给标题
    tester.view.physicalSize = const Size(600, 1000);
    await tester.pump();
    expect(find.text('01:05 / 03:20'), findsNothing);

    // 标题被挤到只剩几十像素后会触发 ScrollingText 的滚动，它先挂一个
    // pauseDuration(2s) 的定时器；先卸载再放行，否则 teardown 会报
    // "A Timer is still pending even after the widget tree was disposed"。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  /// 量取顶边进度的 pill / 轨道 / 填充 / 承托轨道的 `Stack`，坐标相对 pill 左上角。
  ///
  /// `box` 是承托轨道的 `Stack`（默认 `Clip.hardEdge`）：它必须完整罩住轨道，否则
  /// 轨道会被整条裁掉——手机档曾把轨道放在只有 3px 高的 Stack 里 `top: 3` 的位置，
  /// 于是顶边进度在手机上完全不可见。
  ({Rect pill, Rect track, Rect fill, Rect box}) measureProgress(
    WidgetTester tester,
  ) {
    final pill = tester.getRect(find.byKey(CapsuleMiniPlayer.pillKey));
    Rect rel(Rect r) => Rect.fromLTRB(
      r.left - pill.left,
      r.top - pill.top,
      r.right - pill.left,
      r.bottom - pill.top,
    );

    return (
      pill: rel(pill),
      track: rel(
        tester.getRect(find.byKey(CapsuleMiniPlayer.progressTrackKey)),
      ),
      fill: rel(tester.getRect(find.byKey(CapsuleMiniPlayer.progressFillKey))),
      box: rel(
        tester.getRect(
          find
              .ancestor(
                of: find.byKey(CapsuleMiniPlayer.progressTrackKey),
                matching: find.byType(Stack),
              )
              .first,
        ),
      ),
    );
  }

  testWidgets('大屏胶囊：顶边进度整宽贴顶，两端交给 pill 顶角弧线裁', (tester) async {
    await pumpCapsule(
      tester,
      capsule: const CapsuleMiniPlayer(),
      state: buildState(
        currentTime: const Duration(seconds: 100),
        duration: const Duration(seconds: 200),
      ),
    );

    const trackHeight = AppCapsulePlayer.progressTrackHeight;

    final m = measureProgress(tester);
    expect(m.pill.height, AppCapsulePlayer.heightDesktop);
    // GlassSurface 的 0.5px 描边会以 Container padding 的形式内缩，故留 1px 容差
    expect(m.track.top, closeTo(0, 1)); // 轨道外缘就是胶囊顶边框
    expect(m.track.height, trackHeight);
    expect(m.track.left, closeTo(0, 1)); // 整宽：左右都不留 inset
    expect(m.track.right, closeTo(m.pill.width, 1));

    // 填充条：100 / 200 = 50%，左端与轨道对齐、按轨道宽线性展开
    expect(m.fill.left, m.track.left);
    expect(m.fill.top, m.track.top);
    expect(m.fill.height, trackHeight);
    expect(m.fill.width, closeTo(m.track.width / 2, 0.01));

    // 整宽轨道靠 pill 轮廓收边：顶行（y = 0）轮廓收到 radius = 32 > 轨道左端，
    // 底行（y = 3）收到 18.5 —— 两端于是是一段圆弧，而不是两个方块。
    expect(pillEdgeAt(m.pill.height, 0), 32);
    expect(pillEdgeAt(m.pill.height, trackHeight), greaterThan(0));
    // 负责这一刀的是 `GlassSurface` 的 `ClipRRect`（半径 = pill 半径），
    // 与 miot 插件 `.player-bar-shell { overflow: hidden }` 同一个机制
    final clip = tester.widget<ClipRRect>(
      find
          .ancestor(
            of: find.byKey(CapsuleMiniPlayer.progressTrackKey),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    expect(clip.borderRadius, BorderRadius.circular(32));
  });

  testWidgets('胶囊：内容行相对胶囊垂直居中（封面 / 按钮上下留白等分）', (tester) async {
    // 封面盒：占位图标（测试歌曲没有封面 URL）的最近 `Container` 祖先就是封面
    Rect coverRect(WidgetTester tester) => tester.getRect(
      find
          .ancestor(
            of: find.byIcon(Icons.music_note_rounded),
            matching: find.byType(Container),
          )
          .first,
    );

    /// 上下留白等分，且中心与胶囊中心重合。
    ///
    /// 容差 1px：`GlassSurface` 的 0.5px 描边以「Container 边框 padding」的形式
    /// 内缩内容盒，实际会把内容行整体推下 0.5。曾经的 `Column[热区, 行]` 结构则是
    /// 整块推下 8~16px（行中心落到胶囊 56% 处），远在容差之外。
    void expectCentered(Rect pill, Rect box, String label, double hitHeight) {
      final top = box.top - pill.top;
      final bottom = pill.bottom - box.bottom;
      expect(top, greaterThan(0), reason: '$label 上留白');
      expect(top, closeTo(bottom, 1.0), reason: '$label 上下留白应当等分');
      expect(
        (box.top + box.bottom) / 2 - (pill.top + pill.bottom) / 2,
        closeTo(0, 1.0),
        reason: '$label 中心应当与胶囊中心重合',
      );
      // 内容行不再被顶边热区挤下去：上留白不得超出热区高度（顶多齐平 + 0.5 描边）
      expect(top, lessThan(hitHeight + 2), reason: '$label 不应被顶边热区推下去');
    }

    // 大屏：64 里放 44 的封面 → 上下各 10
    await pumpCapsule(tester, capsule: const CapsuleMiniPlayer());
    var pill = tester.getRect(find.byKey(CapsuleMiniPlayer.pillKey));
    expect(pill.height, AppCapsulePlayer.heightDesktop);
    var cover = coverRect(tester);
    expect(cover.height, AppCapsulePlayer.coverSizeDesktop);
    expectCentered(
      pill,
      cover,
      '大屏封面',
      AppCapsulePlayer.progressHitHeightDesktop,
    );

    // 控制按钮（命中框 44）同样居中
    final prev = tester.getRect(find.byTooltip('上一首'));
    expectCentered(
      pill,
      prev,
      '大屏上一首',
      AppCapsulePlayer.progressHitHeightDesktop,
    );
    final play = tester.getRect(find.byTooltip('播放'));
    expectCentered(
      pill,
      play,
      '大屏播放按钮',
      AppCapsulePlayer.progressHitHeightDesktop,
    );
    // 播放 / 切歌三键的纵向中心必须相互重合（否则一排按钮看着高高低低）
    expect(
      (play.top + play.bottom) / 2,
      closeTo((prev.top + prev.bottom) / 2, 0.01),
    );
    expect(
      (cover.top + cover.bottom) / 2,
      closeTo((play.top + play.bottom) / 2, 0.01),
    );

    // 手机：59 里放 36 的封面 → 上下各 11.5
    await pumpCapsule(
      tester,
      capsule: const CapsuleMiniPlayer.compact(),
      viewport: const Size(400, 800),
    );
    pill = tester.getRect(find.byKey(CapsuleMiniPlayer.pillKey));
    expect(pill.height, AppCapsulePlayer.heightMobile);
    cover = coverRect(tester);
    expect(cover.height, AppCapsulePlayer.coverSizeMobile);
    expectCentered(
      pill,
      cover,
      '手机封面',
      AppCapsulePlayer.progressHitHeightMobile,
    );
  });

  testWidgets('大屏胶囊：热区与胶囊等宽，点按按宽度线性 seek（顶角既不 seek 也不打开全屏）', (tester) async {
    final recorder = _SeekRecorder(
      buildState(duration: const Duration(seconds: 200)),
    );
    var pillTaps = 0;
    await pumpCapsule(
      tester,
      capsule: CapsuleMiniPlayer(onTap: () => pillTaps++),
      notifier: recorder,
    );

    final pill = tester.getRect(find.byKey(CapsuleMiniPlayer.pillKey));
    final m = measureProgress(tester);
    // 热区整宽：与胶囊等宽（顶边进度整宽铺满，不再缩进）
    expect(m.box.left, closeTo(0, 1));
    expect(m.box.right, closeTo(m.pill.width, 1));

    // 取热区下沿：顶角轮廓在 y = 0 处收到 32、y = 15 处只剩 4.9，
    // 靠下沿取点，「热区最左端」才落在 pill 轮廓之内
    final y = pill.top + m.box.height - 1;

    // 胶囊顶角的透明区不在 pill 轮廓内（`_RoundedHitClip` 挡住）→ 不产生 seek，
    // 也不该把点击交给胶囊本体（否则会打开全屏播放器）
    await tester.tapAt(Offset(pill.left + 1, pill.top + 1));
    await tester.pump();
    expect(recorder.seeks, isEmpty);
    expect(pillTaps, 0);

    // 保底：点胶囊正文（进度热区之外的标题行）仍然打开全屏播放器
    await tester.tapAt(Offset(pill.left + 200, pill.center.dy));
    await tester.pump();
    expect(pillTaps, 1);

    // 热区就是那个 Stack：tap 的横向位置一律从它的左边界量起
    Future<void> tapAtX(double x) async {
      await tester.tapAt(Offset(x, y));
      await tester.pump();
    }

    double expectedMs(double x) =>
        200000 * (x - pill.left - m.box.left) / m.box.width;

    // 左 / 右端的可达点（贴角处轮廓已收进去，取轮廓内侧 3px）→ 线性映射到极小 /
    // 极大位置，既不越界也不是负值 / NaN
    final corner = pillEdgeAt(m.pill.height, y - pill.top) + 3;
    final leftX = pill.left + corner;
    await tapAtX(leftX);
    expect(recorder.seeks.last, greaterThan(Duration.zero));
    expect(recorder.seeks.last.inMilliseconds, closeTo(expectedMs(leftX), 50));

    final rightX = pill.left + m.box.right - corner;
    await tapAtX(rightX);
    expect(recorder.seeks.last, lessThan(const Duration(seconds: 200)));
    expect(recorder.seeks.last.inMilliseconds, closeTo(expectedMs(rightX), 50));

    // 热区正中 → 总时长的一半
    await tapAtX(pill.left + m.box.left + m.box.width / 2);
    expect(recorder.seeks.last, const Duration(seconds: 100));
  });

  testWidgets('手机胶囊：顶边进度整宽贴顶、两端被顶角裁掉且可拖拽', (tester) async {
    const trackHeight = AppCapsulePlayer.progressTrackHeight;

    // 热区必须容得下轨道本体（曾经比轨道还矮 → 轨道被推出热区并被 Stack 裁掉）
    expect(
      AppCapsulePlayer.progressHitHeightMobile,
      greaterThanOrEqualTo(trackHeight),
    );

    final recorder = _SeekRecorder(
      buildState(duration: const Duration(seconds: 200)),
    );
    await pumpCapsule(
      tester,
      capsule: const CapsuleMiniPlayer.compact(onTap: _noop),
      viewport: const Size(400, 800),
      notifier: recorder,
    );

    final m = measureProgress(tester);
    expect(m.pill.height, AppCapsulePlayer.heightMobile);
    expect(m.pill.height, 59);
    expect(m.track.top, 0); // 静态玻璃的描边不占内容盒 → 轨道顶边与 pill 顶边严格重合
    expect(m.track.height, trackHeight);
    expect(m.track.left, 0); // 整宽：左右都不留 inset
    expect(m.track.right, m.pill.width);
    expect(m.track.width, greaterThan(300));

    // 轨道落在承托它的 Stack 盒子里 → 不会被 Stack 的 hardEdge 裁掉
    expect(m.track.top, greaterThanOrEqualTo(m.box.top));
    expect(m.track.bottom, lessThanOrEqualTo(m.box.bottom));

    // 手机档的可见圆角画在 `BoxDecoration` 上（不裁绘制），整宽轨道靠另补的一层
    // `ClipRRect` 顺着顶角收进去 —— 顶角轮廓在轨道顶行已收到 radius = 29.5
    expect(pillEdgeAt(m.pill.height, 0), 29.5);
    expect(pillEdgeAt(m.pill.height, trackHeight), greaterThan(0));
    final clip = tester.widget<ClipRRect>(
      find
          .ancestor(
            of: find.byKey(CapsuleMiniPlayer.progressTrackKey),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    expect(clip.borderRadius, BorderRadius.circular(29.5));

    // 热区与胶囊等宽：点正中 → 一半时长（手机档同样可拖拽）
    final pill = tester.getRect(find.byKey(CapsuleMiniPlayer.pillKey));
    await tester.tapAt(Offset(pill.center.dx, pill.top + trackHeight));
    await tester.pump();
    expect(recorder.seeks.last, const Duration(seconds: 100));
  });

  testWidgets('大屏胶囊：无歌曲时整条不渲染', (tester) async {
    await pumpCapsule(
      tester,
      capsule: const CapsuleMiniPlayer(),
      state: buildState(hasSong: false),
    );

    expect(find.byType(GlassSurface), findsNothing);
    // Positioned 给了紧宽度，故只断言高度归零（整条不占位）
    expect(tester.getSize(find.byType(CapsuleMiniPlayer)).height, 0);
  });

  testWidgets('大屏胶囊：playOnly 隐藏上一首/下一首，prevNext 显示', (tester) async {
    await pumpCapsule(
      tester,
      capsule: const CapsuleMiniPlayer(),
      controls: MiniPlayerControls.playOnly,
    );
    expect(find.byTooltip('上一首'), findsNothing);
    expect(find.byTooltip('下一首'), findsNothing);

    await pumpCapsule(
      tester,
      capsule: const CapsuleMiniPlayer(),
      controls: MiniPlayerControls.prevNext,
    );
    expect(find.byTooltip('上一首'), findsOneWidget);
    expect(find.byTooltip('下一首'), findsOneWidget);
  });

  testWidgets('手机胶囊：静态半透玻璃（无 BackdropFilter）、高 59、收藏与工具栏都不出现', (tester) async {
    await pumpCapsule(
      tester,
      capsule: const CapsuleMiniPlayer.compact(),
      controls: MiniPlayerControls.prevNextMode,
      viewport: const Size(400, 800),
    );

    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(GlassSurface), findsNothing);

    final size = tester.getSize(find.byKey(CapsuleMiniPlayer.pillKey));
    expect(size.height, AppCapsulePlayer.heightMobile);
    expect(size.height, 59);

    // 全圆角 pill：手机档的可见圆角由静态玻璃的描边 BoxDecoration 提供
    // （大屏档由 GlassSurface 提供，手机档没有 BackdropFilter 那层 ClipRRect）
    final glass = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byKey(CapsuleMiniPlayer.pillKey),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((w) => w.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.border != null);
    expect(glass.borderRadius, BorderRadius.circular(29.5));

    // 窄屏：收藏 / 播放模式 / 音量 / 歌词 / 队列 / 更多 全部让位给标题
    expect(find.byTooltip('收藏'), findsNothing);
    expect(find.byType(PopupPlayModeControl), findsNothing);
    expect(find.byType(ResponsiveVolumeControl), findsNothing);
    expect(find.byTooltip('更多'), findsNothing);
    expect(find.text('01:05 / 03:20'), findsNothing);
    // 手机档仍有播放/切歌
    expect(find.byTooltip('上一首'), findsOneWidget);
    expect(find.byTooltip('下一首'), findsOneWidget);
  });

  testWidgets('标准模式大屏仍是 90px 底栏 + border-top（不受胶囊重构影响）', (tester) async {
    final theme = ThemeData(
      extensions: const [SongloftThemeExtension(navigationStyle: 'standard')],
    );
    await pumpCapsule(
      tester,
      capsule: const DesktopPlayer(),
      navigationStyle: 'standard',
      state: buildState(hasPrevNextQueue: false),
    );

    expect(find.byType(CapsuleMiniPlayer), findsNothing);

    final bar = tester.widget<Container>(
      find.byWidgetPredicate(
        (w) => w is Container && w.constraints?.maxHeight == 90,
      ),
    );
    final decoration = bar.decoration! as BoxDecoration;
    expect(decoration.color, theme.colorScheme.surface);
    final border = decoration.border! as Border;
    expect(border.top.width, 1);
    expect(border.top.color, theme.colorScheme.outlineVariant);
  });
}

class _FakePlayerNotifier extends PlayerNotifier {
  _FakePlayerNotifier(this._initial);

  final PlayerState _initial;

  @override
  PlayerState build() => _initial;
}

/// 假 Notifier + seek 记录，用来验证热区坐标 → seek 位置的映射。
class _SeekRecorder extends _FakePlayerNotifier {
  _SeekRecorder(super._initial);

  final List<Duration> seeks = [];

  @override
  Future<void> seek(Duration position) async => seeks.add(position);
}

class _FixedMiniControls extends MiniPlayerControlsNotifier {
  _FixedMiniControls(this._value);

  final MiniPlayerControls _value;

  @override
  MiniPlayerControls build() => _value;
}

class _FixedAudioTrack extends AudioTrackNotifier {
  @override
  AudioTrackState build() => const AudioTrackState();
}

class _FixedDlna extends DlnaNotifier {
  @override
  DlnaState build() => const DlnaState();
}

class _FixedRunMode extends RunModeNotifier {
  @override
  RunMode build() => RunMode.remote;
}

class _FixedSongCache extends SongCacheNotifier {
  @override
  int build() => 0;
}

class _FixedFavorite extends FavoriteNotifier {
  @override
  FavoriteState build() => const FavoriteState();
}
