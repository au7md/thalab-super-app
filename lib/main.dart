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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await StorageService.init();
  } catch (_) {}

  runApp(const ThalabApp());

  Future.microtask(() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('saved_lat') ?? prefs.getDouble('prayer_lat') ?? 30.0444;
      final lng = prefs.getDouble('saved_lng') ?? prefs.getDouble('prayer_lng') ?? 31.2357;
      await RafiqNotificationsService.syncAllScheduledNotifications(
        lat: lat,
        lng: lng,
        params: CalculationMethod.egyptian.getParameters(),
      );
    } catch (_) {}
  });
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
// 2. تبويب رفيق (الواحة الإيمانية المتكاملة — التصميم الجديد المعتمد)
// =========================================================================
class RafiqTab extends StatefulWidget {
  const RafiqTab({super.key});

  @override
  State<RafiqTab> createState() => _RafiqTabState();
}

class _RafiqTabState extends State<RafiqTab> {
  int _khatmahRead = 0;
  int _hijriOffset = 0;
  Coordinates _coords = Coordinates(30.0444, 31.2357);
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
      _coords = Coordinates(lat, lng);
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

  /// تحديد الذكر التلقائي اللحظي (بعد الصلاة لمدة 30 دقيقة، أو الاستيقاظ/الصباح/المساء/النوم)
  (String title, String subtitle, IconData icon, int tabIndex) _getTimelyDhikrInfo() {
    final now = DateTime.now();
    final pt = _prayerTimes;

    // 1. التحقق أولاً: هل نحن في وقت أذكار ما بعد الصلاة (خلال 30 دقيقة من أذان أي فرض)؟
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
          return ('أذكار بعد الصلاة', 'دُبُر صلاة ${fard.$1} الآن', Icons.check_circle_outline_rounded, 2);
        }
      }
    }

    // 2. حسب فترة اليوم
    final hour = now.hour;
    if (hour >= 4 && hour < 7) {
      return ('أذكار الاستيقاظ', 'بداية يومك بذكر الله', Icons.wb_twilight_rounded, 4);
    } else if (hour >= 7 && hour < 12) {
      return ('أذكار الصباح', 'وقت الصباح المبارك الآن', Icons.wb_sunny_rounded, 0);
    } else if (hour >= 15 && hour < 20) {
      return ('أذكار المساء', 'وقت المساء وحفظ النفس', Icons.nights_stay_rounded, 1);
    } else if (hour >= 20 || hour < 4) {
      return ('أذكار النوم', 'حصّن نفسك قبل المنام', Icons.bedtime_rounded, 3);
    } else {
      return ('أذكار الصباح', 'أذكار اليوم والليلة', Icons.wb_sunny_outlined, 0);
    }
  }

  /// خصائص الهوية البصرية الديناميكية للويدجت حسب الصلاة القادمة/الحالية
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
    final double khatmahPct = (_khatmahRead / 604).clamp(0.0, 1.0);
    final timely = _getTimelyDhikrInfo();
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
        // 1. العنوان العلوي + زر الإشعارات المستقل
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'رفيق — الواحة الإيمانية',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            IconButton(
              tooltip: 'منظومة الإشعارات الذكية',
              icon: const Icon(Icons.notifications_active_rounded, color: ThalabTheme.foxOrange),
              onPressed: () => _open(const HijriEventsScreen(initialTab: 2)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 2. الكارت المزدوج العلوي: الختمة والقرآن (وضع الختمة) + الذكر التلقائي حسب الوقت
        Container(
          decoration: BoxDecoration(
            color: ThalabTheme.cardSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: ThalabTheme.softBorder, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // النصف الأيمن: المصحف والختمة (يفتح وضع الختمة)
                Expanded(
                  child: InkWell(
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(22)),
                    onTap: () => _open(const QuranScreen(), isKhatmah: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
                              Text(
                                '${(khatmahPct * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'المصحف والختمة',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
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

                // النصف الأيسر: الذكر التلقائي حسب الوقت ودبر الصلوات
                Expanded(
                  child: InkWell(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(22)),
                    onTap: () => _open(AdhkarScreen(initialTabIndex: timely.$4)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(timely.$3, color: ThalabTheme.foxOrange, size: 20),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ThalabTheme.foxOrange.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'تلقائي',
                                  style: TextStyle(
                                    color: ThalabTheme.foxOrange,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            timely.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ThalabTheme.darkSlate,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
          ),
        ),
        const SizedBox(height: 12),

        // 3. ويدجت الصلاة الحي الديناميكي (يتغير لونه وأيقونته حسب الفرض القادم + الهجري + الموقع)
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
                // الصف العلوي: الموقع المختار + التاريخ الهجري
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

                // الصف الأوسط: الفرض القادم + العد التنازلي + أيقونة الجو
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

        // 4. الشبكة الأساسية (6 بطاقات مرتبة في 3 صفوف):
        // الصف الأول: المصحف الشريف (وضع القراءة الحرة) + أذكاري (أذكار اليوم والليلة)
        // الصف الثاني: السبحة الذكية + اتجاه القبلة
        // الصف الثالث: حصن المسلم (الحصن + الرقية + الأسماء) + التقويم الهجري والمناسبات
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
              subtitle: 'تلاوة حرة وفهرس السور',
              icon: Icons.menu_book_rounded,
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
  final VoidCallback onTap;

  const _RafiqServiceCard({
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThalabTheme.foxOrange.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: ThalabTheme.foxOrange, size: 22),
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
// 3. تبويب المعرض
// =========================================================================
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

// =========================================================================
// 4. تبويب الموسيقى
// =========================================================================
class MusicTab extends StatelessWidget {
  const MusicTab({super.key});
  @override
  Widget build(BuildContext context) => _SectionGridTemplate(
        title: 'الموسيقى والصوتيات',
        items: [
          _GridToolItem('كل الصوتيات', Icons.library_music_rounded, null),
          _GridToolItem('قوائم التشغيل', Icons.queue_music_rounded, null),
          _GridToolItem('مسجل الصوت', Icons.mic_rounded, null),
          _GridToolItem('وضع الاسترخاء', Icons.spa_rounded, null),
        ],
      );
}

// =========================================================================
// 5. تبويب المزيد
// =========================================================================
class MoreToolsTab extends StatelessWidget {
  const MoreToolsTab({super.key});
  @override
  Widget build(BuildContext context) => _SectionGridTemplate(
        title: 'المزيد من الأدوات',
        items: [
          _GridToolItem('مدير الملفات', Icons.folder_rounded, null),
          _GridToolItem('التنظيف الذكي', Icons.cleaning_services_rounded, null),
          _GridToolItem('صور إلى PDF', Icons.picture_as_pdf_rounded, null),
          _GridToolItem('الخزنة السرية', Icons.lock_rounded, null),
          _GridToolItem('الآلة الحاسبة', Icons.calculate_rounded, null),
          _GridToolItem('سلة المحذوفات', Icons.delete_outline_rounded, null),
          _GridToolItem('الإعدادات', Icons.settings_rounded, null),
          _GridToolItem('حول التطبيق', Icons.info_outline_rounded, null),
        ],
      );
}

class _GridToolItem {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  _GridToolItem(this.label, this.icon, this.onTap);
}

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
        const SizedBox(height: 18),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.90,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: item.onTap ??
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('قسم "${item.label}" جاهز للدمج في الدفعة القادمة'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: ThalabTheme.darkSlate,
                      ),
                    );
                  },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: ThalabTheme.cardSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: ThalabTheme.softBorder, width: 1.4),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ThalabTheme.foxOrange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item.icon, color: ThalabTheme.foxOrange, size: 28),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
