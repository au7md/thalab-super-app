import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:adhan/adhan.dart';
import 'core/theme.dart';
import 'core/prayer_calc.dart';
import 'core/rafiq_notifications_service.dart';
import 'widgets/floating_nav_bar.dart';
import 'features/onboarding/splash_screen.dart';
import 'core/fox_mascot.dart';
import 'core/ui_kit.dart';
import 'features/onboarding/onboarding_screen.dart';
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
  await ThemeController.instance.load();
  runApp(const ThalabApp());
}

class ThalabApp extends StatelessWidget {
  const ThalabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.mode,
      builder: (_, currentMode, __) {
        return MaterialApp(
          title: 'الثعلب',
          debugShowCheckedModeBanner: false,
          theme: ThalabTheme.lightTheme,
          darkTheme: ThalabTheme.darkTheme,
          themeMode: currentMode,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SplashScreen(
            homeBuilder: (_) => const MainShellScreen(),
            onboardingBuilder: (_) => OnboardingScreen(
              homeBuilder: (_) => const MainShellScreen(),
            ),
          ),
        );
      },
    );
  }
}

// =========================================================================
// شل التطبيق الرئيسي (شريط تنقل رباعي هادئ وبدون الرئيسية)
// =========================================================================
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
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
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.025),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(_selectedIndex),
            child: _pages[_selectedIndex],
          ),
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
// 1. تبويب رفيق (الواحة الإيمانية المتكاملة)
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
  String _userName = '';

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
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _userName = (p.getString('user_name') ?? '').trim());
    });
    // الأذونات تُطلب الآن في شاشة الترحيب؛ هذا احتياط لمن تخطّاها فقط.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('perm_flow_done_v2') ?? false)) {
        _askNotificationPermissions();
      }
    });
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  Future<void> _askNotificationPermissions() async {
    final svc = RafiqNotificationsService.instance;
    final granted = await svc.requestPermissionsFromUi();
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('فعّل الإشعارات من إعدادات الهاتف حتى يصلك الأذان في وقته'),
      ));
      return;
    }
    // يُطلب إذن المنبهات الدقيقة مرة واحدة فقط (يفتح شاشة إعداد النظام)
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('exact_alarm_asked_v1') ?? false)) {
      await prefs.setBool('exact_alarm_asked_v1', true);
      if (!await svc.canScheduleExactAlarms()) {
        await svc.requestExactAlarmPermission();
      }
    }
  }

  Future<void> _refreshWidgets() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('saved_lat') ?? prefs.getDouble('prayer_lat') ?? 30.0444;
    final lng = prefs.getDouble('saved_lng') ?? prefs.getDouble('prayer_lng') ?? 31.2357;
    final locLabel = prefs.getString('saved_loc_name') ?? 'القاهرة، مصر';

    final params = prayerParamsFor(lat, lng);
    params.madhab = Madhab.shafi;
    final pt = PrayerTimes(Coordinates(lat, lng), DateComponents.from(DateTime.now()), params);

    RafiqNotificationsService.instance.syncAllScheduledNotifications(
      lat: lat,
      lng: lng,
      params: params,
    );

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

  String _greetingLine() =>
      _userName.isEmpty ? 'السلام عليكم ورحمة الله' : 'السلام عليكم يا $_userName';

  String _phaseLine() {
    final h = DateTime.now().hour;
    if (h >= 4 && h < 7) return 'بارك الله في فجرك 🌅';
    if (h >= 7 && h < 12) return 'صباحك نور وبركة ☀️';
    if (h >= 12 && h < 15) return 'ظهيرة هادئة وذكر دائم 🌤️';
    if (h >= 15 && h < 18) return 'عصرك طيّب ومبارك 🍂';
    if (h >= 18 && h < 21) return 'مساؤك طمأنينة 🌇';
    return 'ليلتك سكينة 🌙';
  }

  FoxMood _foxMood() {
    final h = DateTime.now().hour;
    return (h >= 22 || h < 4) ? FoxMood.sleepy : FoxMood.idle;
  }

  Widget _sectionTitle(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1.4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ThalabTheme.foxOrange.withOpacity(0.35),
                    ThalabTheme.foxOrange.withOpacity(0.0),
                  ],
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
        FadeSlideIn(
          child: Row(
            children: [
              FoxMascot(size: 60, mood: _foxMood()),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greetingLine(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _phaseLine(),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: ThalabTheme.foxOrange,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$hijriFullText • $_locationName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: thalabMuted(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PressableScale(
                onTap: () => _open(const HijriEventsScreen(initialTab: 2)),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: ThalabTheme.foxOrange.withOpacity(0.13),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_rounded,
                      color: ThalabTheme.foxOrange, size: 23),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _open(const PrayerTimesScreen(initialTab: 0)),
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
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _MiniPrayerSlot(name: 'الفجر', time: _formatTime(pt?.fajr), isNext: nextPrayer == Prayer.fajr || nextPrayer == Prayer.none),
                      _MiniPrayerSlot(name: 'الظهر', time: _formatTime(pt?.dhuhr), isNext: nextPrayer == Prayer.dhuhr),
                      _MiniPrayerSlot(name: 'العصر', time: _formatTime(pt?.asr), isNext: nextPrayer == Prayer.asr),
                      _MiniPrayerSlot(name: 'المغرب', time: _formatTime(pt?.maghrib), isNext: nextPrayer == Prayer.maghrib),
                      _MiniPrayerSlot(name: 'العشاء', time: _formatTime(pt?.isha), isNext: nextPrayer == Prayer.isha),
                    ],
                  ),
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
        const SizedBox(height: 16),
        _sectionTitle('🕌', 'خدماتك الإيمانية'),
        GridView.count(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.38,
          children: [
            _RafiqServiceCard(
              title: 'المصحف الشريف',
              accent: const Color(0xFF1E7E6C),
              emoji: '📖',
              index: 0,
              subtitle: _khatmahRead > 0
                  ? 'الختمة: $_khatmahRead/604 ($khatmahPctInt%)'
                  : 'تلاوة حرة وفهرس السور',
              icon: Icons.menu_book_rounded,
              badgeText: _khatmahRead > 0 ? '$khatmahPctInt%' : null,
              onTap: () => _open(const QuranScreen(), isKhatmah: false),
            ),
            _RafiqServiceCard(
              title: 'أذكاري',
              accent: const Color(0xFFF59E0B),
              emoji: '☀️',
              index: 1,
              subtitle: 'الصباح، المساء، النوم، الصلاة',
              icon: Icons.wb_sunny_outlined,
              onTap: () => _open(const AdhkarScreen(initialTabIndex: 0)),
            ),
            _RafiqServiceCard(
              title: 'السبحة الذكية',
              accent: const Color(0xFFE86A17),
              emoji: '📿',
              index: 2,
              subtitle: 'عداد تفاعلي وإجمالي دائم',
              icon: Icons.radio_button_checked_rounded,
              onTap: () => _open(const TasbihScreen()),
            ),
            _RafiqServiceCard(
              title: 'اتجاه القبلة',
              accent: const Color(0xFF2563EB),
              emoji: '🧭',
              index: 3,
              subtitle: 'بوصلة هندسية دقيقة',
              icon: Icons.explore_rounded,
              onTap: () => _open(const QiblaScreen()),
            ),
            _RafiqServiceCard(
              title: 'حصن المسلم',
              accent: const Color(0xFF7C3AED),
              emoji: '🛡️',
              index: 4,
              subtitle: 'الأدعية، الرقية، الأسماء الحسنى',
              icon: Icons.auto_stories_rounded,
              onTap: () => _open(const AdhkarScreen(initialTabIndex: 5)),
            ),
            _RafiqServiceCard(
              title: 'التقويم والمناسبات',
              accent: const Color(0xFF0F766E),
              emoji: '🗓️',
              index: 5,
              subtitle: ramadanDays == 0 ? 'رمضان كريم اليوم!' : 'رمضان: $ramadanDays يوم • الهجري',
              icon: Icons.calendar_month_rounded,
              onTap: () => _open(const HijriEventsScreen(initialTab: 0)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _open(const PrayerTimesScreen(initialTab: 1)),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? ThalabTheme.darkBorder
                    : ThalabTheme.softBorder,
                width: 1.4,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ThalabTheme.foxOrange.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.fact_check_rounded, color: ThalabTheme.foxOrange, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('صلاتي — السجل والتنبيهات',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('متابعة الفروض، السنن، واختيار المؤذن لكل صلاة',
                          style: TextStyle(color: ThalabTheme.mutedSlate, fontSize: 11.5)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: ThalabTheme.mutedSlate),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RafiqServiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String emoji;
  final int index;
  final String? badgeText;
  final VoidCallback onTap;

  const _RafiqServiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.emoji,
    required this.index,
    this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return FadeSlideIn(
      delay: Duration(milliseconds: 120 + index * 90),
      child: PressableScale(
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent.withOpacity(isDark ? 0.22 : 0.13), theme.cardColor],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withOpacity(isDark ? 0.35 : 0.28), width: 1.3),
          ),
          child: Stack(
            children: [
              PositionedDirectional(
                start: -4,
                bottom: -12,
                child: Opacity(
                  opacity: isDark ? 0.14 : 0.16,
                  child: Text(emoji, style: const TextStyle(fontSize: 62)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: accent, size: 22),
                        ),
                        if (badgeText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              badgeText!,
                              style: TextStyle(
                                color: accent,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: thalabMuted(context), fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniPrayerSlot extends StatelessWidget {
  final String name;
  final String time;
  final bool isNext;

  const _MiniPrayerSlot({
    required this.name,
    required this.time,
    required this.isNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isNext ? Colors.white.withOpacity(0.22) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            name,
            style: TextStyle(
              color: isNext ? Colors.white : Colors.white70,
              fontSize: 10.5,
              fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            time.replaceAll(' ص', '').replaceAll(' م', ''),
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: isNext ? FontWeight.w900 : FontWeight.bold,
            ),
          ),
        ],
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
