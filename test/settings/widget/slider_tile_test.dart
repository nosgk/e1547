import 'package:e1547/settings/widget/slider_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('slider tile clamps manual input and syncs the field', (
    tester,
  ) async {
    double value = 304;
    final changes = <double>[];

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          home: Scaffold(
            body: SliderSettingTile(
              title: 'Drawer width',
              icon: Icons.menu_open,
              min: 200,
              max: 480,
              value: value,
              onChanged: (changed) {
                changes.add(changed);
                setState(() => value = changed);
              },
              format: (value) => '${value.round()}',
              parse: (text) => double.tryParse(text),
              suffix: 'dp',
            ),
          ),
        ),
      ),
    );
    expect(find.text('304'), findsOneWidget);

    // Out-of-range input is clamped to the maximum and the field shows the
    // clamped value again.
    await tester.enterText(find.byType(TextField), '999');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(changes, [480]);
    expect(find.text('480'), findsOneWidget);

    // Submitting the same text again does not emit a duplicate change.
    await tester.enterText(find.byType(TextField), '480');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(changes, [480]);

    // Empty input is rejected and the field reverts to the current value.
    await tester.enterText(find.byType(TextField), '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(changes, [480]);
    expect(find.text('480'), findsOneWidget);
  });

  testWidgets('slider tile drives percentage style conversions', (
    tester,
  ) async {
    double scale = 1;
    final changes = <double>[];

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          home: Scaffold(
            body: SliderSettingTile(
              title: 'Font size',
              icon: Icons.format_size,
              min: 0.7,
              max: 1.8,
              value: scale,
              onChanged: (changed) {
                changes.add(changed);
                setState(() => scale = changed);
              },
              format: (value) => '${(value * 100).round()}',
              parse: (text) => switch (double.tryParse(text)) {
                null => null,
                final percent => percent / 100,
              },
              suffix: '%',
            ),
          ),
        ),
      ),
    );
    expect(find.text('100'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '180');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(changes, [1.8]);
    expect(find.text('180'), findsOneWidget);
  });
}
