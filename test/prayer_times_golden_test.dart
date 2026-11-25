import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:thalab_app/core/theme.dart';
import 'package:thalab_app/features/rafiq/prayer_times_screen.dart';

import 'home_screen_golden_test.dart' as home;

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator()
      : super(Uri.file(
            '${Directory.current.path}/test/prayer_times_golden_test.dart'));

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    goldenFileComparator = _TolerantComparator();
  });

  testWidgets('prayer times screen in dark mode with real fonts',
      (tester) => withClock(home.debugFixedClock, () async {
    await home.debugSetupHarness();
    SharedPreferences.setMockInitialValues({
      'saved_lat': 30.0444,
      'saved_lng': 31.2357,
      'saved_loc_name': 'القاهرة، مصر',
      'user_name': 'أحمد',
    });

    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: home.debugThemeWithRealFont(ThalabTheme.darkTheme),
      debugShowCheckedModeBanner: false,
      home: const PrayerTimesScreen(initialTab: 0),
    ));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await home.debugReloadAmiri();
    await tester.pump();

    await expectLater(
      find.byType(PrayerTimesScreen),
      matchesGoldenFile('goldens/prayer_times_dark.png'),
    );

    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 600)));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }));
}
