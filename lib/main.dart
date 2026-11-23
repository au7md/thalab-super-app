import 'dart:async';
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
import 'features/media/gallery_screen.dart';
import 'features/music/music_studio_screen.dart';
import 'features/more/more_hub_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RafiqNotificationsService.instance.init();
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

// =========================================================================
// 1. تبويب الرئيسية
// =========================================================================
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
              subtitle: 'المواقيت والأذان المباشر',
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

// =========================================================================
// 2. تبويب رفيق (الواحة الإيمانية المتكاملة — الترتيب المحدث)
// =========================================================================
class RafiqTab extends StatefulWidget {
  const RafiqTab({super.key});

  @override
  State<RafiqTab> createState() => _RafiqTabState();
}

class _RafiqTabState extends State<RafiqTab> {
  int _khatmahRead = 0;
  int _hijriOffset = 0;
  String _locationName = 'القاهرة، مصر';
  PrayerTimes? _prayerTimes;
  Timer? _liveTimer;

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
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshWidgets() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('saved_lat') ?? prefs.getDouble('prayer_lat') ?? 30.0444;
    final lng = prefs.getDouble('saved_lng') ?? prefs.getDouble('prayer_lng') ?? 31.2357;
    final locLabel = prefs.getString('saved_loc_name') ?? 'القاهرة، مصر';

    final params = CalculationMethod.egyptian.getParameters();
    params.madhab = Madhab.shafi;
    final pt = PrayerTimes(Coordinates(lat, lng), DateComponents.from(DateTime.now()), params);

    if (!mounted) return;
    setState(() {
      _khatmahRead = prefs.getInt('khatmah_pages_read') ?? 0;
      _hijriOffset = prefs.getInt('hijri_day_offset') ?? 0;
      _locationName = locLabel;
      _prayerTimes = pt;
    });
  }

  Future<void> _open(Widget screen, {bool isKhatmah = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('quran_is_khatmah_entry', isKhatmah);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _refreshWidgets();
  }

  /// بيانات وهوية بطاقة الذكر التلقائي بخلفية متدرجة تناسب كل ذكر ووقته
  ({
    String title,
    String subtitle,
    String badge,
    IconData icon,
    int tabIndex,
    List<Color> gradient,
  }) _getTimelyDhikrVisual() {
    final now = DateTime.now();
    final pt = _prayerTimes;

    if (pt != null) {
      final fardList = [
        ('الفجر', pt.fajr),
        ('الظهر', pt.dhuhr),
        ('العصر', pt.asr),
        ('المغرب', pt.maghrib),
        ('العشاء', pt.isha),
      ];
      for (final fard in fardList) {
        final diff = now.difference(fard.$2);
        if (diff.inMinutes >= 0 && diff.inMinutes <= 30) {
          return (
            title: 'أذكار بعد الصلاة',
            subtitle: 'دُبُر صلاة ${fard.$1} — استغفر الله ثلاثاً وسبّح',
            badge: 'وقت الفرض الآن',
            icon: Icons.verified_rounded,
            tabIndex: 2,
            gradient: const [Color(0xFF0F4C45), Color(0xFF1E7E6C)],
          );
        }
      }
    }

    final hour = now.hour;
    if (hour >= 4 && hour < 7) {
      return (
        title: 'أذكار الاستيقاظ',
        subtitle: 'الحمد لله الذي أحيانا بعد ما أماتنا وإليه النشور',
        badge: 'بداية اليوم',
        icon: Icons.wb_twilight_rounded,
        tabIndex: 4,
        gradient: const [Color(0xFF2B5876), Color(0xFF4E4376)],
      );
    } else if (hour >= 7 && hour < 12) {
      return (
        title: 'أذكار الصباح',
        subtitle: 'أصبحنا وأصبح الملك لله — حصّن يومك بالذكر',
        badge: 'وِرد الصباح',
        icon: Icons.wb_sunny_rounded,
        tabIndex: 0,
        gradient: const [Color(0xFFD97706), Color(0xFFF59E0B)],
      );
    } else if (hour >= 15 && hour < 20) {
      return (
        title: 'أذكار المساء',
        subtitle: 'أمسينا وأمسى الملك لله — طمأنينة وحفظ',
        badge: 'وِرد المساء',
        icon: Icons.nights_stay_rounded,
        tabIndex: 1,
        gradient: const [Color(0xFF7C2D12), Color(0xFFC2410C)],
      );
    } else if (hour >= 20 || hour < 4) {
      return (
        title: 'أذكار النوم',
        subtitle: 'باسمك ربي وضعت جنبي وبك أرفعه — ختمة اليوم',
        badge: 'قبل المنام',
        icon: Icons.bedtime_rounded,
        tabIndex: 3,
        gradient: const [Color(0xFF1E1B4B), Color(0xFF312E81)],
      );
    } else {
      return (
        title: 'أذكار وتسابيح الظهيرة',
        subtitle: 'ألا بذكر الله تطمئن القلوب — افتح باقة الأذكار',
        badge: 'ذكر مستمر',
        icon: Icons.auto_awesome_rounded,
        tabIndex: 0,
        gradient: const [Color(0xFF0369A1), Color(0xFF0284C7)],
      );
    }
  }

  ({
    List<Color> gradient,
    IconData skyIcon,
    String periodBadge,
    Color accentText,
  }) _prayerTheme(Prayer p) {
    switch (p) {
      case Prayer.fajr:
      case Prayer.none:
        return (
          gradient: const [Color(0xFF1E3A5F), Color(0xFF3B6E9C), Color(0xFFD98236)],
          skyIcon: Icons.wb_twilight_rounded,
          periodBadge: 'نسائم الفجر',
          accentText: const Color(0xFFFFE4C4),
        );
      case Prayer.sunrise:
      case Prayer.dhuhr:
        return (
          gradient: const [Color(0xFF1976D2), Color(0xFF42A5F5), Color(0xFF64B5F6)],
          skyIcon: Icons.wb_sunny_rounded,
          periodBadge: 'ضياء الظهيرة',
          accentText: Colors.white,
        );
      case Prayer.asr:
        return (
          gradient: const [Color(0xFFD96B14), Color(0xFFF39237), Color(0xFFF7B267)],
          skyIcon: Icons.wb_sunny_outlined,
          periodBadge: 'أصيل العصر',
          accentText: Colors.white,
        );
      case Prayer.maghrib:
        return (
          gradient: const [Color(0xFF4A1D5C), Color(0xFFA8385D), Color(0xFFE86A17)],
          skyIcon: Icons.nights_stay_outlined,
          periodBadge: 'شفق المغرب',
          accentText: const Color(0xFFFFE8D6),
        );
      case Prayer.isha:
        return (
          gradient: const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
          skyIcon: Icons.bedtime_rounded,
          periodBadge: 'سكون العشاء',
          accentText: const Color(0xFFE2E8F0),
        );
    }
  }

  String _arabicPrayerName(Prayer p) {
    switch (p) {
      case Prayer.fajr:
        return 'الفجر';
      case Prayer.sunrise:
        return 'الشروق';
      case Prayer.dhuhr:
        return 'الظهر';
      case Prayer.asr:
        return 'العصر';
      case Prayer.maghrib:
        return 'المغرب';
      case Prayer.isha:
        return 'العشاء';
      case Prayer.none:
        return 'الفجر';
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'م' : 'ص';
    return '$h:$m $period';
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
    final int khatmahPctInt = ((_khatmahRead / 604) * 100).clamp(0, 100).round();
    final timely = _getTimelyDhikrVisual();
    final todayH = HijriCalendar.fromDate(DateTime.now().add(Duration(days: _hijriOffset)));
    final monthName = _hijriMonthsAr[(todayH.hMonth - 1).clamp(0, 11)];
    final hijriFullText = '${todayH.hDay} $monthName ${todayH.hYear} هـ';
    final ramadanDays = _daysUntilRamadan();

    final pt = _prayerTimes;
    final nextPrayer = pt?.nextPrayer() ?? Prayer.none;
    DateTime? nextTime = pt?.timeForPrayer(nextPrayer);
    if (nextPrayer == Prayer.none && pt != null) {
      nextTime = pt.fajr.add(const Duration(days: 1));
    }
    final remaining = nextTime != null ? nextTime.difference(DateTime.now()) : Duration.zero;
    final remHours = remaining.inHours.clamp(0, 23).toString().padLeft(2, '0');
    final remMins = (remaining.inMinutes % 60).clamp(0, 59).toString().padLeft(2, '0');
    final remSecs = (remaining.inSeconds % 60).clamp(0, 59).toString().padLeft(2, '0');
    final pVisual = _prayerTheme(nextPrayer);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 115),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'رفيق — الواحة الإيمانية',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            IconButton(
              tooltip: 'منظومة الإشعارات والتنبيهات',
              icon: const Icon(Icons.notifications_active_rounded, color: ThalabTheme.foxOrange),
              onPressed: () => _open(const HijriEventsScreen(initialTab: 2)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _open(const PrayerTimesScreen()),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: pVisual.gradient,
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: pVisual.gradient.first.withOpacity(0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on_rounded, color: pVisual.accentText, size: 14),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _locationName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: pVisual.accentText, fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        hijriFullText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(pVisual.skyIcon, color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'الصلاة القادمة: ${_arabicPrayerName(nextPrayer)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'موعد الأذان: ${_formatTime(nextTime)} • ${pVisual.periodBadge}',
                          style: TextStyle(color: pVisual.accentText, fontSize: 11.5),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$remHours:$remMins:$remSecs',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          'متبقي على الأذان',
                          style: TextStyle(color: pVisual.accentText, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _open(AdhkarScreen(initialTabIndex: timely.tabIndex)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: timely.gradient,
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: timely.gradient.first.withOpacity(0.24),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(timely.icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            timely.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              timely.badge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timely.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.38,
          children: [
            _RafiqServiceCard(
              title: 'المصحف الشريف',
              subtitle: _khatmahRead > 0
                  ? 'الختمة: $_khatmahRead/604 ($khatmahPctInt%)'
                  : 'تلاوة حرة وفهرس السور',
              icon: Icons.menu_book_rounded,
              badgeText: _khatmahRead > 0 ? '$khatmahPctInt%' : null,
              onTap: () => _open(const QuranScreen(), isKhatmah: false),
            ),
            _RafiqServiceCard(
              title: 'أذكاري',
              subtitle: 'الصباح، المساء، النوم، الصلاة',
              icon: Icons.wb_sunny_outlined,
              onTap: () => _open(const AdhkarScreen(initialTabIndex: 0)),
            ),
            _RafiqServiceCard(
              title: 'السبحة الذكية',
              subtitle: 'عداد تفاعلي وإجمالي دائم',
              icon: Icons.radio_button_checked_rounded,
              onTap: () => _open(const TasbihScreen()),
            ),
            _RafiqServiceCard(
              title: 'اتجاه القبلة',
              subtitle: 'بوصلة هندسية دقيقة',
              icon: Icons.explore_rounded,
              onTap: () => _open(const QiblaScreen()),
            ),
            _RafiqServiceCard(
              title: 'حصن المسلم',
              subtitle: 'الأدعية، الرقية، الأسماء الحسنى',
              icon: Icons.auto_stories_rounded,
              onTap: () => _open(const AdhkarScreen(initialTabIndex: 5)),
            ),
            _RafiqServiceCard(
              title: 'التقويم والمناسبات',
              subtitle: ramadanDays == 0 ? 'رمضان كريم اليوم!' : 'رمضان: $ramadanDays يوم • الهجري',
              icon: Icons.calendar_month_rounded,
              onTap: () => _open(const HijriEventsScreen(initialTab: 0)),
            ),
            _RafiqServiceCard(
              title: 'سجل الصلوات',
              subtitle: 'متابعة الفروض الخمس والسنن',
              icon: Icons.fact_check_rounded,
              onTap: () => _open(const PrayerTimesScreen()),
            ),
            _RafiqServiceCard(
              title: 'تنبيهات الأذان',
              subtitle: 'إعدادات قبل وبعد كل صلاة',
              icon: Icons.alarm_on_rounded,
              onTap: () => _open(const PrayerTimesScreen()),
            ),
          ],
        ),
      ],
    );
  }
}

class _RafiqServiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? badgeText;
  final VoidCallback onTap;

  const _RafiqServiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ThalabTheme.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ThalabTheme.softBorder, width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ThalabTheme.foxOrange.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: ThalabTheme.foxOrange, size: 22),
                ),
                if (badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ThalabTheme.foxOrange.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeText!,
                      style: const TextStyle(
                        color: ThalabTheme.foxOrange,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ThalabTheme.mutedSlate, fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// 3. تبويب المعرض المتكامل
// =========================================================================
class MediaTab extends StatelessWidget {
  const MediaTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const GalleryScreen(initialCategoryIndex: 0);
  }
}

// =========================================================================
// 4. تبويب الموسيقى والصوتيات المتكامل
// =========================================================================
class MusicTab extends StatelessWidget {
  const MusicTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const MusicStudioScreen(initialTabIndex: 0);
  }
}

// =========================================================================
// 5. تبويب المزيد
// =========================================================================
class MoreToolsTab extends StatelessWidget {
  const MoreToolsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const MoreHubScreen();
  }
}
