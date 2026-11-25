import 'dart:io';

import 'package:clock/clock.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Test-only override of the google_fonts HTTP client so goldens render the
// real Readex Pro font offline. The served bytes are the exact files
// google_fonts pins (sha256 + length verified at download time).
// ignore: implementation_imports
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as gfb;

import 'package:thalab_app/main.dart';
import 'package:thalab_app/core/theme.dart';

const _gstaticHashes = [
  '870a3330a3749a6f77ae6869705a73e7cac177a535bebe60323fc706f632267c', // w200
  '38b0632b8ef49efc7781f129be6231d9e8f2191fe9522a7af3c63f514a1db7c8', // w300
  '7782ff7d5dea5d731043a6a9485f9c129227a140122a8d5b066a4139b6db2dcb', // w400
  'dd123b1e15265f38bb1e7ea3130a5b50529e1dd2701fd815a7a2c5ebd773cbf7', // w500
  'd6416f2670653f40b5d522b959fa9cef26de93f1eb07383cd74add81cd540223', // w600
  'ea6ca5c476dff3996be03d6f357b8fc79d536b3324a74a2b8cd8d95b0c2d7cec', // w700
];

const _gstaticWeights = ['w200', 'w300', 'w400', 'w500', 'w600', 'w700'];

// Hashes pinned by google_fonts 6.3.3 for Amiri / Amiri Quran, served from
// test/fonts/*.ttf whose sha256 was verified against these exact values.
const _amiriHashes = {
  '82b49c37cfb90dd8fff8aab7508c2078bb32a200648acb2237dc02c30f4492ad':
      'Amiri-Regular.ttf',
  '53c460187d4f6d8fa2bde7a1a6587ca6487f807c31b094037164bb58e3b2bd4c':
      'Amiri-Bold.ttf',
  '6fb463ac2d53b77b67d274bec99e39a4288a2d0a962437c7b1c1f6e9a9ee799f':
      'AmiriQuran-Regular.ttf',
};

void _installFontHttpMock() {
  final bytesByHash = <String, List<int>>{};
  for (var i = 0; i < _gstaticHashes.length; i++) {
    bytesByHash[_gstaticHashes[i]] =
        File('test/fonts/gstatic/${_gstaticWeights[i]}.ttf').readAsBytesSync();
  }
  // Amiri/AmiriQuran runtime loads must SUCCEED (a failed fetch throws
  // asynchronously and fails the test) and must pass google_fonts' pinned
  // integrity check, so serve the original gstatic subset bytes. Those
  // subsets have empty Latin/punctuation outlines, so AFTER the runtime
  // registration settles, callers re-register the full-outline builds via
  // debugReloadAmiri() before any golden capture.
  _amiriHashes.forEach((hash, file) {
    bytesByHash[hash] = File('test/fonts/subset/$hash.ttf').readAsBytesSync();
  });
  gfb.httpClient = MockClient((request) async {
    final hash = request.url.pathSegments.isEmpty
        ? ''
        : request.url.pathSegments.last.replaceAll('.ttf', '');
    final bytes = bytesByHash[hash];
    if (bytes == null) return http.Response('not found', 404);
    return http.Response.bytes(bytes, 200);
  });
}

Future<void> _loadRealFonts() async {
  final readex = FontLoader('ReadexPro');
  for (final w in ['400', '600', '700']) {
    final bytes = File('test/fonts/ReadexPro-$w.ttf').readAsBytesSync();
    readex.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await readex.load();

  final iconBytes =
      File('test/fonts/MaterialIcons-Regular.otf').readAsBytesSync();
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(iconBytes.buffer)));
  await icons.load();

  // Amiri / Amiri Quran (dhikr, tasbih, quran screens). Full-outline
  // builds from the google/fonts repo (the gstatic files google_fonts pins
  // are subsets with empty Latin/punctuation glyphs -> boxes). Registered
  // under both the plain family and the dynamic names google_fonts 6.2.1
  // generates ('<family>_<weight>'), so no glyph falls back to a box.
  for (final entry in {
    'Amiri': ['Amiri-Regular.ttf', 'Amiri-Bold.ttf'],
    'Amiri_regular': ['Amiri-Regular.ttf'],
    'Amiri_700': ['Amiri-Bold.ttf'],
    'AmiriQuran': ['AmiriQuran-Regular.ttf'],
    'AmiriQuran_regular': ['AmiriQuran-Regular.ttf'],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      final bytes = File('test/fonts/$file').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
}

/// Pins every theme text style to the synchronously-loaded ReadexPro family
/// so golden rasterization never depends on async google_fonts fetches.
ThemeData _withRealFont(ThemeData base) {
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'ReadexPro'),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle:
          base.appBarTheme.titleTextStyle?.copyWith(fontFamily: 'ReadexPro'),
    ),
  );
}

/// Hard-fails with setup instructions when the pinned font files are absent,
/// so the golden suite is never silently skipped or rendered with fallback
/// fonts. Fonts are not committed (binary); fetch them once per checkout.
void _requireFontFiles() {
  const required = [
    'test/fonts/MaterialIcons-Regular.otf',
    'test/fonts/ReadexPro-400.ttf',
    'test/fonts/ReadexPro-600.ttf',
    'test/fonts/ReadexPro-700.ttf',
    'test/fonts/gstatic/w400.ttf',
    'test/fonts/gstatic/w600.ttf',
    'test/fonts/gstatic/w700.ttf',
    'test/fonts/Amiri-Regular.ttf',
    'test/fonts/Amiri-Bold.ttf',
    'test/fonts/AmiriQuran-Regular.ttf',
  ];
  final missing = required.where((p) => !File(p).existsSync()).toList();
  if (missing.isNotEmpty) {
    fail('Golden font files are missing: $missing\n'
        'Run `bash test/fonts/download_fonts.sh` from the repo root '
        '(pinned URLs, sha256-verified), then re-run the tests.');
  }
}

void _mockPluginChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('dexterous.com/flutter/local_notifications'),
    (call) async {
      if (call.method == 'pendingNotificationRequests') return <dynamic>[];
      // bool-returning plugin calls must not get null (init crashes).
      if (call.method == 'initialize' ||
          call.method == 'requestNotificationsPermission' ||
          call.method == 'requestExactAlarmsPermission' ||
          call.method == 'canScheduleExactNotifications') return true;
      return null;
    },
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async {
      // google_fonts caches fetched fonts under this directory; it must
      // exist on a clean machine or the async font save races throw
      // PathNotFoundException mid-test.
      Directory('/tmp/gfonts').createSync(recursive: true);
      return '/tmp/gfonts';
    },
  );
}

String _todayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The hero card shows a live countdown that ticks between runs; tolerate
/// tiny pixel deltas (the digits) while still catching real regressions.
class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator()
      : super(Uri.file(
            '${Directory.current.path}/test/home_screen_golden_test.dart'));

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

  for (final cfg in [
    ('light', () => _withRealFont(ThalabTheme.lightTheme)),
    ('dark', () => _withRealFont(ThalabTheme.darkTheme)),
  ]) {
    testWidgets('home screen renders with real Arabic font (${cfg.$1})',
        (tester) => withClock(debugFixedClock, () async {
      _requireFontFiles();
      _mockPluginChannels();
      _installFontHttpMock();
      await _loadRealFonts();

      final today = _todayKey(clock.now());
      SharedPreferences.setMockInitialValues({
        'tasbih_daily_count': 47,
        'tasbih_daily_date': today,
        'pomodoro_count': 3,
        'pomodoro_count_date': today,
        'thalab_habits_v2_json':
            '[{"name":"ورد القرآن","done_date":"$today"},{"name":"صلاة الضحى","done_date":"$today"},{"name":"الاستغفار","done_date":""},{"name":"مشي ٣٠ دقيقة","done_date":""}]',
        'khatmah_pages_read': 120,
        'user_name': 'أحمد',
        'saved_loc_name': 'القاهرة، مصر',
      });

      // Narrow phone viewport: 390x844 logical at 2x.
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: cfg.$2(),
          debugShowCheckedModeBanner: false,
          home: const Scaffold(body: RafiqTab()),
        ),
      );
      // Let _refreshWidgets (prefs + prayer times) settle without
      // pumpAndSettle: the tab keeps a 1s live timer running.
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 400)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      await expectLater(
        find.byType(RafiqTab),
        matchesGoldenFile('goldens/home_${cfg.$1}.png'),
      );

      // Let any in-flight font loads finish, then dispose the tab so its
      // periodic timer is cancelled.
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 600)));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }));
  }
}


/// Deterministic wall clock for golden/smoke captures: 2026-11-25 14:30.
final Clock debugFixedClock = Clock.fixed(DateTime(2026, 11, 25, 14, 30));

/// Shared harness entry for sibling golden tests: fonts + plugin mocks.
Future<void> debugSetupHarness() async {
  _requireFontFiles();
  _mockPluginChannels();
  _installFontHttpMock();
  await _loadRealFonts();
}

/// Public wrapper around [_withRealFont] for sibling golden tests.
ThemeData debugThemeWithRealFont(ThemeData base) => _withRealFont(base);

/// Re-registers the full-outline Amiri/AmiriQuran builds under the dynamic
/// '<family>_<weight>' names AFTER the google_fonts runtime load has settled
/// (the runtime registers subsetted bytes; the last registration wins, so
/// this must run after the settle pumps and before the golden capture).
Future<void> debugReloadAmiri() async {
  for (final entry in {
    'Amiri': ['Amiri-Regular.ttf', 'Amiri-Bold.ttf'],
    'Amiri_regular': ['Amiri-Regular.ttf'],
    'Amiri_700': ['Amiri-Bold.ttf'],
    'AmiriQuran': ['AmiriQuran-Regular.ttf'],
    'AmiriQuran_regular': ['AmiriQuran-Regular.ttf'],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      final bytes = File('test/fonts/$file').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
}
