// Regression: a corrupt stored khatmah goal of 0 days divided by zero in
// build() ((604 / _khatmahGoalDays).ceil() throws on Infinity). The stored
// value is now clamped to 1..365 on load.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thalab_app/core/theme.dart';
import 'package:thalab_app/features/rafiq/quran_screen.dart';
import 'home_screen_golden_test.dart' as home;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('quran screen survives a corrupt zero khatmah goal',
      (tester) async {
    await home.debugSetupHarness();
    SharedPreferences.setMockInitialValues(const {'khatmah_goal_days': 0});
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
      home: const QuranScreen(),
    ));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 400)));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.byType(QuranScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
