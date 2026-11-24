import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:thalab_app/core/theme.dart';
import 'package:thalab_app/features/rafiq/adhkar_screen.dart';
import 'package:thalab_app/features/rafiq/quran_screen.dart';
import 'package:thalab_app/features/rafiq/tasbih_screen.dart';

import 'home_screen_golden_test.dart' as home;

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator()
      : super(Uri.file(
            '${Directory.current.path}/test/rafiq_dark_goldens_test.dart'));

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (!result.passed && result.diffPercent <= 1.0) return true;
    return result.passed;
  }
}

Widget _darkApp(Widget screen) {
  return MaterialApp(
    locale: const Locale('ar', 'EG'),
    supportedLocales: const [Locale('ar', 'EG')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: home.debugThemeWithRealFont(ThalabTheme.darkTheme),
    debugShowCheckedModeBanner: false,
    home: screen,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    goldenFileComparator = _TolerantComparator();
  });

  Future<void> pumpDark(WidgetTester tester, Widget screen) async {
    home.debugSetupHarness();
    SharedPreferences.setMockInitialValues(const {'user_name': 'أحمد'});

    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_darkApp(screen));
    await tester
        .runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
  }

  Future<void> settleDown(WidgetTester tester) async {
    await tester
        .runAsync(() => Future.delayed(const Duration(milliseconds: 600)));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('adhkar screen in dark mode with real fonts', (tester) async {
    await pumpDark(tester, const AdhkarScreen());
    await expectLater(
      find.byType(AdhkarScreen),
      matchesGoldenFile('goldens/adhkar_dark.png'),
    );
    await settleDown(tester);
  });

  testWidgets('tasbih screen in dark mode with real fonts', (tester) async {
    await pumpDark(tester, const TasbihScreen());
    await expectLater(
      find.byType(TasbihScreen),
      matchesGoldenFile('goldens/tasbih_dark.png'),
    );
    await settleDown(tester);
  });

  testWidgets('quran screen in dark mode with real fonts', (tester) async {
    await pumpDark(tester, const QuranScreen());
    await expectLater(
      find.byType(QuranScreen),
      matchesGoldenFile('goldens/quran_dark.png'),
    );
    await settleDown(tester);
  });
}
