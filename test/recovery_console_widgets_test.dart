import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powernet_staff/theme/app_theme.dart';
import 'package:powernet_staff/widgets/recovery_console_widgets.dart';

void main() {
  testWidgets('RecoveryHeroCard renders on narrow width without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(
          body: RecoveryHeroCard(
            areaName: 'Test Area',
            totalDue: 2071200,
            billCount: 911,
            collectedTodayAmount: 1600,
            overdueCount: 0,
            partialCount: 1,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Collect, note, sync'), findsOneWidget);
    expect(find.textContaining('Rs. 2071200'), findsOneWidget);
    expect(find.text('911'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RecoverySegmentedTabs renders billing tabs', (tester) async {
    late TabController controller;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: DefaultTabController(
          length: 5,
          child: Builder(
            builder: (context) {
              controller = DefaultTabController.of(context);
              return Scaffold(
                body: RecoverySegmentedTabs(
                  controller: controller,
                  background: Colors.white,
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Partial'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Visits'), findsOneWidget);
  });
}
