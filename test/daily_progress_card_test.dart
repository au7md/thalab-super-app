import 'package:flutter/material.dart';
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
    expect(find.text('2/3'), findsOneWidget); // عادات
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

  testWidgets('golden: light and dark card', (tester) async {
    await tester.pumpWidget(_wrap(ThalabTheme.lightTheme, sample));
    await tester.pumpAndSettle();
    await expectLater(find.byType(DailyProgressCard),
        matchesGoldenFile('goldens/daily_card_light.png'));
    await tester.pumpWidget(_wrap(ThalabTheme.darkTheme, sample));
    await tester.pumpAndSettle();
    await expectLater(find.byType(DailyProgressCard),
        matchesGoldenFile('goldens/daily_card_dark.png'));
  }, tags: 'golden');
}
