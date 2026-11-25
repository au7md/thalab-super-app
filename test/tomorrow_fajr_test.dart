// Regression: after isha, the next-prayer countdown and the last-third-of-night
// calculation used today's fajr + 24h as "tomorrow's fajr". Prayer times drift
// daily, so that approximation is off (on 2026-11-25 in Cairo the real fajr is
// 04:58 while today+24h says 04:57). Both screens must now use an exact
// adhan calculation for tomorrow's date.
import 'package:adhan/adhan.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thalab_app/core/theme.dart';
import 'package:thalab_app/features/rafiq/prayer_times_screen.dart';
import 'package:thalab_app/main.dart';
import 'home_screen_golden_test.dart' as home;

PrayerTimes _cairoTimes(DateTime date) {
  final params = CalculationMethod.egyptian.getParameters();
  params.madhab = Madhab.shafi;
  return PrayerTimes(
      Coordinates(30.0444, 31.2357), DateComponents.from(date), params);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await home.debugSetupHarness();
    SharedPreferences.setMockInitialValues(const {
      'saved_lat': 30.0444,
      'saved_lng': 31.2357,
      'saved_loc_name': 'القاهرة، مصر',
    });
  });

  Future<void> pumpApp(WidgetTester tester, Widget screen) async {
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
      theme: home.debugThemeWithRealFont(ThalabTheme.lightTheme),
      home: screen,
    ));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 400)));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  test('adhan: exact tomorrow fajr differs from today+24h on 2026-11-25', () {
    final today = _cairoTimes(DateTime(2026, 11, 25));
    final tomorrow = _cairoTimes(DateTime(2026, 11, 26));
    expect(tomorrow.fajr, DateTime(2026, 11, 26, 4, 58));
    expect(tomorrow.fajr, isNot(today.fajr.add(const Duration(days: 1))),
        reason: 'the approximation must be measurably wrong on this date');
  });

  testWidgets('prayer times screen uses exact tomorrow fajr after isha',
      (tester) async {
    final fakeNow = DateTime(2026, 11, 25, 22, 30); // after isha
    await withClock(Clock(() => fakeNow), () async {
      await pumpApp(tester, const PrayerTimesScreen());
      final st = tester.state(find.byType(PrayerTimesScreen)) as dynamic;
      final exact = _cairoTimes(DateTime(2026, 11, 26)).fajr;
      final todayFajr = _cairoTimes(DateTime(2026, 11, 25)).fajr;
      expect(st.debugTomorrowFajr as DateTime, exact);
      expect(st.debugTomorrowFajr as DateTime,
          isNot(todayFajr.add(const Duration(days: 1))));
      expect((st.debugTomorrowFajr as DateTime).day, 26);
    });
  });

  testWidgets('home tab uses exact tomorrow fajr after isha', (tester) async {
    final fakeNow = DateTime(2026, 11, 25, 22, 30);
    await withClock(Clock(() => fakeNow), () async {
      await pumpApp(tester, const Scaffold(body: RafiqTab()));
      final st = tester.state(find.byType(RafiqTab)) as dynamic;
      final exact = _cairoTimes(DateTime(2026, 11, 26)).fajr;
      expect(st.debugTomorrowFajr as DateTime, exact);
    });
  });
}
