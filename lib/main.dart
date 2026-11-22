import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:adhan/adhan.dart';
import 'core/theme.dart';
import 'core/storage_service.dart';
import 'core/rafiq_notifications_service.dart';
import 'widgets/floating_nav_bar.dart';
import 'features/rafiq/tasbih_screen.dart';
import 'features/rafiq/adhkar_screen.dart';
import 'features/rafiq/prayer_times_screen.dart';
import 'features/rafiq/quran_screen.dart';
import 'features/rafiq/qibla_screen.dart';
import 'features/rafiq/hijri_events_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  final prefs = await SharedPreferences.getInstance();
  final lat = prefs.getDouble('prayer_lat') ?? 30.0444;
  final lng = prefs.getDouble('prayer_lng') ?? 31.2357;
  await RafiqNotificationsService.syncAllScheduledNotifications(
    lat: lat,
    lng: lng,
    params: CalculationMethod.egyptian.getParameters(),
  );
  runApp(const ThalabApp());
}

class ThalabApp extends StatelessWidget {
  const ThalabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'الثعلب',
      debugShowCheckedModeBanner: false,
      theme: ThalabTheme.lightTheme,
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomeDashboardTab(),
    RafiqTab(),
    MediaTab(),
    MusicTab(),
    MoreToolsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: _pages[_selectedIndex],
        ),
      ),
      bottomNavigationBar: ThalabFloatingNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}

// 1. تبويب الرئيسية
class HomeDashboardTab extends StatelessWidget {
  const HomeDashboardTab({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أهلاً بك في الثعلب',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  'مساحتك الذكية الهادئة والمتكاملة',
                  style: TextStyle(fontSize: 13, color: ThalabTheme.mutedSlate),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ThalabTheme.cardSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: ThalabTheme.softBorder),
              ),
              child: const Icon(Icons.pets_rounded, color: ThalabTheme.foxOrange, size: 28),
            ),
          ],
        ),
        const SizedBox(height: 22),
        GestureDetector(
          onTap: () => _open(context, const AdhkarScreen()),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: ThalabTheme.foxOrange.withOpacity(0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('رفيقك اليومي', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      SizedBox(height: 4),
                      Text(
                        'وِرد اليوم والأذكار',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'اضغط لفتح حصن المسلم بالعداد التفاعلي',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                Icon(Icons.mosque_rounded, color: Colors.white, size: 46),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Text('الوصول السريع', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            _QuickCard(
              title: 'المصحف الشريف',
              subtitle: 'متابعة الختمة والقراءة',
              icon: Icons.menu_book_rounded,
              onTap: () => _open(context, const QuranScreen()),
            ),
            _QuickCard(
              title: 'السبحة الذكية',
              subtitle: 'تصفير تلقائي للهدف',
              icon: Icons.adjust_rounded,
              onTap: () => _open(context, const TasbihScreen()),
            ),
            _QuickCard(
              title: 'مواقيت الصلاة',
              subtitle: 'المواقيت والسنن الرواتب',
              icon: Icons.access_time_filled_rounded,
              onTap: () => _open(context, const PrayerTimesScreen()),
            ),
            _QuickCard(
              title: 'التقويم الهجري',
              subtitle: 'المناسبات والعد التنازلي',
              icon: Icons.calendar_month_rounded,
              onTap: () => _open(context, const HijriEventsScreen()),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ThalabTheme.cardSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: ThalabTheme.softBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: ThalabTheme.foxOrange, size: 26),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(subtitle, style: const TextStyle(color: ThalabTheme.mutedSlate, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// 2. تبويب رفيق (الواحة الإيمانية المتكاملة)
class RafiqTab extends StatefulWidget {
  const RafiqTab({super.key});

  @override
  State<RafiqTab> createState() => _RafiqTabState();
}

class _RafiqTabState extends State<RafiqTab> {
  int _khatmahRead = 0;
  int _hijriOffset = 0;

  static const List<String> _hijriMonthsAr = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  @override
  void initState() {
    super.initState();
    _refreshWidgets();
  }

  Future<void> _refreshWidgets() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _khatmahRead = prefs.getInt('khatmah_pages_read') ?? 0;
      _hijriOffset = prefs.getInt('hijri_day_offset') ?? 0;
    });
  }

  void _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _refreshWidgets();
  }

  (String title, String subtitle, IconData icon, int tabIndex) _getTimelyDhikrInfo() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 12) {
      return ('أذكار الصباح', 'وقت الصباح المبارك الآن', Icons.wb_sunny_rounded, 0);
    } else if (hour >= 15 && hour < 21) {
      return ('أذكار المساء', 'وقت المساء وحفظ النفس', Icons.nights_stay_rounded, 1);
    } else if (hour >= 21 || hour < 4) {
      return ('أذكار النوم', 'حصّن نفسك قبل المنام', Icons.bedtime_rounded, 3);
    } else {
      return ('حصن المسلم', 'أذكار اليوم والليلة', Icons.auto_stories_rounded, 5);
    }
  }

  int _daysUntilRamadan() {
    final now = DateTime.now().add(Duration(days: _hijriOffset));
    final todayH = HijriCalendar.fromDate(now);
    int targetYear = todayH.hYear;
    if (9 < todayH.hMonth || (9 == todayH.hMonth && 1 < todayH.hDay)) {
      targetYear++;
    }
    final ramadanG = HijriCalendar().hijriToGregorian(targetYear, 9, 1);
    final todayClean = DateTime(now.year, now.month, now.day);
    final targetClean = DateTime(ramadanG.year, ramadanG.month, ramadanG.day);
    return targetClean.difference(todayClean).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final double khatmahPct = (_khatmahRead / 604).clamp(0.0, 1.0);
    final timely = _getTimelyDhikrInfo();
    final todayH = HijriCalendar.fromDate(DateTime.now().add(Duration(days: _hijriOffset)));
    final monthName = _hijriMonthsAr[(todayH.hMonth - 1).clamp(0, 11)];
    final ramadanDays = _daysUntilRamadan();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('رفيق — الواحة الإيمانية', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            IconButton(
              tooltip: 'منظومة الإشعارات الذكية',
              icon: const Icon(Icons.notifications_active_rounded, color: ThalabTheme.foxOrange),
              onPressed: () => _open(const HijriEventsScreen(initialTab: 2)),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _open(const QuranScreen()),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.menu_book_rounded, color: Colors.white),
                          Text('الختمة', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${(khatmahPct * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$_khatmahRead / 604 صفحة',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => _open(AdhkarScreen(initialTabIndex: timely.$4)),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ThalabTheme.cardSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: ThalabTheme.foxOrange.withOpacity(0.5), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(timely.$3, color: ThalabTheme.foxOrange),
                          const Text('الآن', style: TextStyle(color: ThalabTheme.foxOrange, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        timely.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ThalabTheme.darkSlate,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timely.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: ThalabTheme.mutedSlate, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _open(const HijriEventsScreen(initialTab: 1)),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: ThalabTheme.cardSurface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: ThalabTheme.softBorder, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.calendar_month_rounded, color: ThalabTheme.foxOrange, size: 22),
                          Text('الهجري', style: TextStyle(color: ThalabTheme.mutedSlate, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${todayH.hDay} $monthName',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '${todayH.hYear} هـ • الأيام البيض',
                        style: const TextStyle(color: ThalabTheme.mutedSlate, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => _open(const HijriEventsScreen(initialTab: 0)),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: ThalabTheme.cardSurface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: ThalabTheme.softBorder, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.nights_stay_rounded, color: ThalabTheme.foxOrange, size: 22),
                          Text('المناسبات', style: TextStyle(color: ThalabTheme.mutedSlate, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        ramadanDays == 0 ? 'رمضان كريم!' : 'رمضان: $ramadanDays يوم',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const Text(
                        'اضغط لعرض كل المناسبات',
                        style: TextStyle(color: ThalabTheme.mutedSlate, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        GestureDetector(
          onTap: () => _open(const PrayerTimesScreen()),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThalabTheme.cardSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: ThalabTheme.softBorder, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ThalabTheme.foxOrange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.mosque_rounded, color: ThalabTheme.foxOrange, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('مواقيت الصلاة والسنن والنوافل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                      Text(
                        'الرواتب، الضحى، الثلث الأخير + 27 محافظة',
                        style: TextStyle(color: ThalabTheme.mutedSlate, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// 3. تبويب المعرض
class MediaTab extends StatelessWidget {
  const MediaTab({super.key});
  @override
  Widget build(BuildContext context) => _SectionGridTemplate(
        title: 'المعرض',
        items: [
          _GridToolItem('الفيديوهات', Icons.video_library_rounded, null),
          _GridToolItem('الصور', Icons.photo_library_rounded, null),
          _GridToolItem('قص الفيديو', Icons.content_cut_rounded, null),
          _GridToolItem('استخراج الصوت', Icons.audiotrack_rounded, null),
        ],
      );
}

// 4. تبويب الموسيقى
class MusicTab extends StatelessWidget {
  const MusicTab({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('الموسيقى'));
}

// 5. تبويب المزيد
class MoreToolsTab extends StatelessWidget {
  const MoreToolsTab({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('المزيد'));
}

// قالب الشبكة
class _SectionGridTemplate extends StatelessWidget {
  final String title;
  final List<_GridToolItem> items;
  const _SectionGridTemplate({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            for (final item in items)
              _QuickCard(
                title: item.title,
                subtitle: 'اضغط للفتح',
                icon: item.icon,
                onTap: () {},
              ),
          ],
        ),
      ],
    );
  }
}

class _GridToolItem {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;
  const _GridToolItem(this.title, this.icon, this.onTap);
}
