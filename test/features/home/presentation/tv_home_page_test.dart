import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/home/presentation/tv_home_page.dart';

void main() {
  testWidgets('TvHomePage renders a horizontal list of categories', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TvHomePage(),
      ),
    );

    expect(find.byType(ListView), findsOneWidget);
    
    final listView = tester.widget<ListView>(find.byType(ListView));
    expect(listView.scrollDirection, Axis.horizontal);
    
    expect(find.text('本地音乐'), findsOneWidget);
    expect(find.text('播放列表'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
