import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/rafiq_notifications_service.dart';
import 'features/rafiq/hijri_events_screen.dart';
import 'features/rafiq/prayer_times_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RafiqNotificationsService.instance.init();
  await RafiqNotificationsService.instance.scheduleDailyAzkar(
    id: 201,
    title: 'أذكار الصباح',
    body: 'حصّن يومك بذكر الله — افتح واحة رفيق',
    hour: 6,
    minute: 30,
  );
  await RafiqNotificationsService.instance.scheduleDailyAzkar(
    id: 202,
    title: 'أذكار المساء',
    body: 'موعد أذكار المساء وطمأنينة القلب',
    hour: 17,
    minute: 30,
  );
  runApp(const AlThaalabApp());
}

class AlThaalabApp extends StatelessWidget {
  const AlThaalabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'الثعلب',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1E6F5C),
        brightness: Brightness.dark,
        textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
      ),
      home: const MainShellScreen(),
    );
  }
}

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const RafiqHubScreen(),
      const _PlaceholderSection(title: 'معرض الصور والفيديو', icon: Icons.photo_library_outlined),
      const _PlaceholderSection(title: 'الموسيقى والصوتيات', icon: Icons.library_music_outlined),
      const _PlaceholderSection(title: 'المزيد من الأدوات', icon: Icons.grid_view_rounded),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.mosque_outlined), label: 'رفيق'),
          NavigationDestination(icon: Icon(Icons.photo_outlined), label: 'المعرض'),
          NavigationDestination(icon: Icon(Icons.music_note_outlined), label: 'الموسيقى'),
          NavigationDestination(icon: Icon(Icons.apps_rounded), label: 'المزيد'),
        ],
      ),
    );
  }
}

class RafiqHubScreen extends StatefulWidget {
  const RafiqHubScreen({super.key});

  @override
  State<RafiqHubScreen> createState() => _RafiqHubScreenState();
}

class _RafiqHubScreenState extends State<RafiqHubScreen> {
  int _tasbihCount = 0;
  int _tasbihIndex = 0;

  final List<String> _azkarList = const [
    'سبحان الله وبحمده',
    'أستغفر الله العظيم وأتوب إليه',
    'لا إله إلا الله وحده لا شريك له',
    'اللهم صلِّ وسلم على نبينا محمد',
  ];

  @override
  void initState() {
    super.initState();
    _loadCounter();
  }

  Future<void> _loadCounter() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _tasbihCount = prefs.getInt('rafiq_tasbih_count') ?? 0;
    });
  }

  Future<void> _incrementTasbih() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _tasbihCount++);
    await prefs.setInt('rafiq_tasbih_count', _tasbihCount);
  }

  Future<void> _resetTasbih() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _tasbihCount = 0);
    await prefs.setInt('rafiq_tasbih_count', 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('واحة رفيق الإيمانية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _QuickNavCard(
                  title: 'مواقيت الصلاة',
                  subtitle: 'العداد الحي والأذان',
                  icon: Icons.access_time_filled_rounded,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrayerTimesScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickNavCard(
                  title: 'التقويم الهجري',
                  subtitle: 'المناسبات القادمة',
                  icon: Icons.calendar_month_rounded,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HijriEventsScreen()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'المسبحة الإلكترونية',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      tooltip: 'تصفير العداد',
                      onPressed: _resetTasbih,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _tasbihIndex,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: List.generate(
                    _azkarList.length,
                    (i) => DropdownMenuItem(value: i, child: Text(_azkarList[i])),
                  ),
                  onChanged: (val) {
                    if (val != null) setState(() => _tasbihIndex = val);
                  },
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _incrementTasbih,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F3D3E), Color(0xFF1E6F5C)],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$_tasbihCount',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('اضغط على الدائرة للتسبيح', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickNavCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickNavCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF1E6F5C), size: 28),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderSection extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderSection({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: const Color(0xFF1E6F5C)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
