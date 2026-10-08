import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:songloft_flutter/core/theme/app_theme.dart';
import 'package:songloft_flutter/core/theme/widgets/glass_capsule_bar.dart';
import 'package:songloft_flutter/core/theme/widgets/liquid_glass_surface.dart';
import 'package:songloft_flutter/l10n/app_localizations.dart';
import 'package:songloft_flutter/shared/layouts/adaptive_scaffold.dart';

void main() {
  Widget harness({
    required Widget child,
    bool ready = true,
    bool opaque = false,
    bool increaseContrast = false,
    bool dark = false,
    bool reduceMotion = false,
  }) => LiquidGlassWidgets.wrap(
    brightnessResolver: Theme.maybeBrightnessOf,
    child: MaterialApp(
      theme:
          dark
              ? AppTheme.darkTheme(
                reduceTransparency: opaque,
                increaseContrast: increaseContrast,
              )
              : AppTheme.lightTheme(
                reduceTransparency: opaque,
                increaseContrast: increaseContrast,
              ),
      themeAnimationDuration: Duration.zero,
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: SongloftGlassScope(enabled: ready, child: Center(child: child)),
      ),
    ),
  );

  for (final dark in [false, true]) {
    testWidgets(
      'opaque policy removes shaders and blur then restores (dark=$dark)',
      (tester) async {
        const child = LiquidGlassSurface(
          borderRadius: BorderRadius.all(Radius.circular(28)),
          child: SizedBox(width: 300, height: 56, child: Text('Glass content')),
        );
        for (final flags in [
          (false, false),
          (true, false),
          (false, true),
          (false, false),
        ]) {
          final opaque = flags.$1 || flags.$2;
          await tester.pumpWidget(
            harness(
              child: child,
              opaque: flags.$1,
              increaseContrast: flags.$2,
              dark: dark,
            ),
          );
          expect(
            find.byType(GlassContainer),
            opaque ? findsNothing : findsOneWidget,
          );
          if (opaque) expect(find.byType(BackdropFilter), findsNothing);
          expect(
            tester.getSize(find.byType(LiquidGlassSurface)),
            const Size(300, 56),
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets('shader startup failure keeps fallback controls usable', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      harness(
        ready: false,
        child: LiquidGlassSurface(
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            width: 300,
            height: 56,
            child: TextButton(
              onPressed: () => taps++,
              child: const Text('Play'),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(GlassContainer), findsNothing);
    expect(find.byType(BackdropFilter), findsOneWidget);
    await tester.tap(find.text('Play'));
    expect(taps, 1);
  });

  const destinations = [
    GlassCapsuleDestination(
      label: '首页',
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
    ),
    GlassCapsuleDestination(
      label: '曲库',
      icon: Icon(Icons.library_music_outlined),
      selectedIcon: Icon(Icons.library_music),
    ),
  ];

  testWidgets('glass navigation selects tabs and keeps its height', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      harness(
        child: Scaffold(
          bottomNavigationBar: GlassCapsuleBar(
            selectedIndex: selected,
            onDestinationSelected: (index) => selected = index,
            destinations: destinations,
          ),
        ),
      ),
    );
    final bar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
    expect(bar.barHeight, 56);
    await tester.tap(find.text('曲库').first);
    await tester.pump();
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion disables fallback navigation animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        ready: false,
        reduceMotion: true,
        child: Scaffold(
          bottomNavigationBar: GlassCapsuleBar(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: destinations,
          ),
        ),
      ),
    );
    expect(find.byType(AnimatedContainer), findsNWidgets(2));
    for (final container in tester.widgetList<AnimatedContainer>(
      find.byType(AnimatedContainer),
    )) {
      expect(container.duration, Duration.zero);
    }
  });

  testWidgets('plugin layout uses opaque navigation without blur or shaders', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    final theme = AppTheme.lightTheme();
    await tester.pumpWidget(
      harness(
        child: Theme(
          data: theme.copyWith(
            extensions: [
              theme.extension<SongloftThemeExtension>()!.copyWith(
                navigationStyle: 'capsule',
              ),
            ],
          ),
          child: AdaptiveScaffold(
            allowExtendBody: false,
            body: const Text('Plugin'),
            currentIndex: 0,
            onDestinationSelected: (_) {},
            destinations: const [
              NavDestination(
                label: '首页',
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
              ),
              NavDestination(
                label: '曲库',
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(GlassTabBar), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).extendBody, isFalse);
  });

  testWidgets('glass navigation overflow menu selects the hidden destination', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    var selected = 0;
    final theme = AppTheme.lightTheme();
    await tester.pumpWidget(
      harness(
        child: Theme(
          data: theme.copyWith(
            extensions: [
              theme.extension<SongloftThemeExtension>()!.copyWith(
                navigationStyle: 'capsule',
              ),
            ],
          ),
          child: AdaptiveScaffold(
            body: const Text('Content'),
            currentIndex: 0,
            onDestinationSelected: (index) => selected = index,
            destinations: [
              for (final label in ['首页', '曲库', '歌单', '电台', '插件', '设置'])
                NavDestination(
                  label: label,
                  icon: const Icon(Icons.music_note_outlined),
                  selectedIcon: const Icon(Icons.music_note),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('更多').first);
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsOneWidget);
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(selected, 5);
    expect(find.text('设置'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
