// Regression: prayer times used to stay on the previous day when a screen
// was left open across midnight, because PrayerTimes was computed once and
// the per-second ticker only repainted. Now the ticker must recompute
// exactly once when the date rolls over, even while the async home refresh
// is still in flight.
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thalab_app/core/theme.dart';
import 'package:thalab_app/features/rafiq/prayer_times_screen.dart';
import 'package:thalab_app/main.dart';
import 'home_screen_golden_test.dart' as home;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await home.debugSetupHarness();
    SharedPreferences.setMockInitialValues(const {});
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

  testWidgets('prayer times screen recomputes exactly once at midnight',
      (tester) async {
    var fakeNow = DateTime(2026, 11, 25, 23, 59, 50);
    final mutableClock = Clock(() => fakeNow);
    await withClock(mutableClock, () async {
      await pumpApp(tester, const PrayerTimesScreen());
      final st = tester.state(find.byType(PrayerTimesScreen)) as dynamic;
      final before = st.debugCalcCount as int;
      expect(before, greaterThan(0));

      // Cross midnight, then let several ticker seconds elapse.
      fakeNow = fakeNow.add(const Duration(minutes: 2)); // 2026-11-26 00:01:50
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(st.debugCalcCount as int, before + 1,
          reason: 'rollover must trigger exactly one recompute');
      expect(st.debugPrayerTimesDateKey as String, '2026_11_26');
      expect((st.debugFajrTime as DateTime).day, 26);
    });
  });

  testWidgets('home refresh fires once at midnight, no repeat while in flight',
      (tester) async {
    var fakeNow = DateTime(2026, 11, 25, 23, 59, 50);
    final mutableClock = Clock(() => fakeNow);
    await withClock(mutableClock, () async {
      await pumpApp(tester, const Scaffold(body: RafiqTab()));
      final st = tester.state(find.byType(RafiqTab)) as dynamic;
      final before = st.debugRefreshCount as int;
      expect(before, greaterThan(0));

      fakeNow = fakeNow.add(const Duration(minutes: 2)); // next day
      // Many ticks, including while the async refresh is still completing.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
      }

      expect(st.debugRefreshCount as int, before + 1,
          reason: 'in-flight guard must stop every-tick re-sync');
      expect(st.debugPrayerTimesDateKey as String, endsWith('_26'));
    });
  });
}
