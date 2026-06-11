import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/shared/widgets/tv_focusable.dart';

void main() {
  testWidgets('TvFocusable responds to focus and selection', (WidgetTester tester) async {
    bool tapped = false;
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvFocusable(
            onSelect: () => tapped = true,
            autofocus: true,
            focusNode: focusNode,
            child: const Text('TV Item'),
          ),
        ),
      ),
    );

    // Default focus
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    // Send enter key (simulating generic selection, TV specific mapped later)
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}
