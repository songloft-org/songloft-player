import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/library/presentation/providers/favorite_provider.dart';
import 'package:songloft_flutter/features/library/presentation/widgets/song_list_tile.dart';
import 'package:songloft_flutter/l10n/app_localizations.dart';
import 'package:songloft_flutter/shared/models/song.dart';

Song _localSong() => Song(
  id: 1,
  type: 'local',
  title: '测试本地歌曲',
  artist: '艺术家',
  album: '专辑',
  duration: 200,
  filePath: 'music/test.mp3',
  addedAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<void> _pump(WidgetTester tester, double width) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        isSongFavoritedProvider.overrideWith((ref, id) => false),
        isRadioFavoritedProvider.overrideWith((ref, id) => false),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: SongListTile(
                song: _localSong(),
                index: 0,
                onEdit: () {},
                onTap: () {},
                onDelete: () {},
                onAddToPlaylist: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('本地歌曲桌面布局：编辑按钮可见且无溢出', (tester) async {
    await _pump(tester, 1000); // 桌面宽度，触发 _buildDesktopLayout

    // 不应有 RenderFlex 溢出异常
    expect(tester.takeException(), isNull);

    // 编辑按钮（tooltip=编辑）应存在
    expect(find.byTooltip('编辑'), findsOneWidget);
  });
}
