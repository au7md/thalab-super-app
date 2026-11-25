// Smoke coverage for every screen that had no test until now: first render in
// both themes at phone size must not throw (overflows, null errors, bad state).
import 'dart:io';
import 'dart:typed_data';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thalab_app/core/theme.dart';
import 'package:thalab_app/features/media/gallery_screen.dart';
import 'package:thalab_app/features/more/more_hub_screen.dart';
import 'package:thalab_app/features/more/pro_tools_screens.dart';
import 'package:thalab_app/features/more/productivity_pro_screens.dart';
import 'package:thalab_app/features/more/student_hub_screen.dart';
import 'package:thalab_app/features/music/music_studio_screen.dart';
import 'package:thalab_app/features/rafiq/qibla_screen.dart';
import 'home_screen_golden_test.dart' as home;

void _mockChannel(String name, [dynamic result]) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(MethodChannel(name), (call) async => result);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    home.debugSetupHarness();
    SharedPreferences.setMockInitialValues(const {});
    _mockChannel('dev.fluttercommunity.plus/share', '');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => '/tmp/thalab_test_cache');
    _mockChannel('com.ryanheise.just_audio.methods');
    _mockChannel('flutter.baseflow.com/geolocator');
    _mockChannel('hemanthraj/flutter_compass');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.fluttercandies/photo_manager'),
            (call) async => call.method == 'requestPermissionExtend'
                ? 2 // denied: screen renders its no-permission state and stops
                : null);
  });

  Future<void> pumpPhone(WidgetTester tester, Widget screen, bool dark) =>
      withClock(home.debugFixedClock, () async {
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
      theme: home.debugThemeWithRealFont(
          dark ? ThalabTheme.darkTheme : ThalabTheme.lightTheme),
      home: screen,
    ));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 400)));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  });

  final screens = <String, Widget Function()>{
    'qibla': () => const QiblaScreen(),
    'music_studio': () => const MusicStudioScreen(),
    'gallery': () => const GalleryScreen(),
    'more_hub': () => const MoreHubScreen(),
    'user_profile': () => const UserProfileScreen(),
    'app_settings': () => const AppSettingsScreen(),
    'zakat_calc': () => const ZakatCalculatorScreen(),
    'unit_converter': () => const UnitConverterScreen(),
    'age_calc': () => const AgeCalculatorScreen(),
    'password_gen': () => const PasswordGeneratorScreen(),
    'text_analyzer': () => const TextAnalyzerScreen(),
    'student_hub': () => const StudentHubScreen(),
    'pomodoro_pro': () => const PomodoroProScreen(),
    'notes_vault': () => const SecureNotesVaultScreen(),
    'habit_integrated': () => const IntegratedHabitScreen(),
  };

  for (final dark in [true, false]) {
    for (final entry in screens.entries) {
      testWidgets('smoke ${entry.key} ${dark ? "dark" : "light"}', (tester) async {
        await pumpPhone(tester, entry.value(), dark);
        final errors = <Object>[];
        Object? e;
        while ((e = tester.takeException()) != null) {
          errors.add(e!);
        }
        expect(errors, isEmpty,
            reason: '${entry.key} threw on first render: \$errors');
      });
    }
  }
}
