import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thalab_app/core/daily_progress.dart';
import 'package:thalab_app/core/theme.dart';
import 'package:thalab_app/widgets/daily_progress_card.dart';

Widget _wrap(ThemeData theme, DailyProgress p) {
  return MaterialApp(
    theme: theme,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DailyProgressCard(
              progress: p,
              onOpenAdhkar: () {},
              onOpenTasbih: () {},
              onOpenQuran: () {},
              onOpenHabits: () {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  const sample = DailyProgress(
    adhkarCompleted: 5,
    tasbihToday: 100,
    khatmahPages: 42,
    habitsDone: 2,
    habitsTotal: 3,
    pomodorosToday: 1,
  );

  testWidgets('shows all section stats and active-section badge',
      (tester) async {
    await tester.pumpWidget(_wrap(ThalabTheme.lightTheme, sample));
    expect(find.text('يومك في الثعلب'), findsOneWidget);
    expect(find.text('5 أقسام نشطة'), findsOneWidget);
    expect(find.text('5'), findsOneWidget); // أذكار
    expect(find.text('100'), findsOneWidget); // تسبيح
    expect(find.text('42'), findsOneWidget); // ختمة
    expect(find.text('2 من 3'), findsOneWidget); // عادات
    expect(find.text('أذكار'), findsOneWidget);
    expect(find.text('تسبيح'), findsOneWidget);
    expect(find.text('صفحات الختمة'), findsOneWidget);
    expect(find.text('عادات'), findsOneWidget);
    expect(find.text('جلسات تركيز'), findsOneWidget);
  });

  testWidgets('empty day prompts to start', (tester) async {
    const empty = DailyProgress(
      adhkarCompleted: 0,
      tasbihToday: 0,
      khatmahPages: 0,
      habitsDone: 0,
      habitsTotal: 3,
      pomodorosToday: 0,
    );
    await tester.pumpWidget(_wrap(ThalabTheme.lightTheme, empty));
    expect(find.text('ابدأ يومك'), findsOneWidget);
  });

  testWidgets('share button captures the card as a real PNG', (tester) async {
    await tester.pumpWidget(_wrap(ThalabTheme.lightTheme, sample));

    // The share affordance is present and enabled.
    expect(find.byTooltip('مشاركة إنجاز اليوم'), findsOneWidget);

    final state = tester.state<DailyProgressCardState>(
        find.byType(DailyProgressCard));
    await tester.pump(); // complete a paint pass
    final bytes = await tester.runAsync(() => state.capturePng());

    // The shared payload is a real rendered PNG, not an empty stub.
    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(1000));
    expect(bytes.sublist(0, 4), equals(const [0x89, 0x50, 0x4E, 0x47]));
  });

}
