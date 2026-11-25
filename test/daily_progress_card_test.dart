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

  testWidgets('share button captures the RTL card as a real PNG',
      (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '/tmp/gfonts',
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (call) async => '',
    );

    // Phone-sized viewport and ambient RTL, matching the real home screen.
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    Uint8List? shared;
    DailyProgressCardState.debugShareSink = (bytes) async => shared = bytes;
    addTearDown(() => DailyProgressCardState.debugShareSink = null);

    await tester.pumpWidget(MaterialApp(
      theme: ThalabTheme.darkTheme,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DailyProgressCard(
                progress: sample,
                onOpenAdhkar: () {},
                onOpenTasbih: () {},
                onOpenQuran: () {},
                onOpenHabits: () {},
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    // Real tap path: tap -> post-frame wait -> capture -> sink.
    await tester.tap(find.byTooltip('مشاركة إنجاز اليوم'));
    await tester.pump(); // runs the post-frame callback, then capture
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    await tester.pump();

    expect(shared, isNotNull);
    expect(shared!.length, greaterThan(1000));
    expect(shared!.sublist(0, 4), equals(const [0x89, 0x50, 0x4E, 0x47]));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

}
