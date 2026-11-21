import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import '../../core/theme.dart';
import '../../core/rafiq_notifications_service.dart';

class IslamicOccasion {
  final String title;
  final int hMonth;
  final int hDay;
  final String subtitle;
  final String virtue;
  final IconData icon;
  final Color accentColor;

  const IslamicOccasion({
    required this.title,
    required this.hMonth,
    required this.hDay,
    required this.subtitle,
    required this.virtue,
    required this.icon,
    required this.accentColor,
  });
}

class HijriEventsScreen extends StatefulWidget {
  final int initialTab;
  const HijriEventsScreen({super.key, this.initialTab = 0});

  @override
  State<HijriEventsScreen> createState() => _HijriEventsScreenState();
}

class _HijriEventsScreenState extends State<HijriEventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _hijriOffset = 0;

  // إعدادات منظومة الإشعارات
  bool _notifAdhkar = true;
  bool _notifKhatmah = true;
  bool _notifAyah = true;
  bool _notifNawafil = true;
  bool _notifFasting = true;
  bool _notifPostPrayer = true;

  static const List<String> _hijriMonthsAr = [
    'مُحَرَّم',
    'صَفَر',
    'رَبِيع الأَوَّل',
    'رَبِيع الآخِر',
    'جُمَادَى الأُولَى',
    'جُمَادَى الآخِرَة',
    'رَجَب',
    'شَعْبَان',
    'رَمَضَان',
    'شَوَّال',
    'ذُو القَعْدَة',
    'ذُو الحِجَّة',
  ];

  static const List<IslamicOccasion> _occasions = [
    IslamicOccasion(
      title: 'بداية شهر رمضان المبارك',
      hMonth: 9,
      hDay: 1,
      subtitle: '١ رمضان • شهر الصيام والقرآن',
      virtue: '«مَن صامَ رَمَضانَ إيمانًا واحْتِسابًا غُفِرَ له ما تَقَدَّمَ مِن ذَنْبِهِ» — استعد بتنظيم ورد الختمة والقيام.',
      icon: Icons.nights_stay_rounded,
      accentColor: Color(0xFFE86A17),
    ),
    IslamicOccasion(
      title: 'العشر الأواخر وليلة القدر',
      hMonth: 9,
      hDay: 21,
      subtitle: '٢١ رمضان • خير من ألف شهر',
      virtue: 'تحرّوا ليلة القدر في الوتر من العشر الأواخر، وأكثروا من: «اللهم إنك عفو تحب العفو فاعف عني».',
      icon: Icons.auto_awesome_rounded,
      accentColor: Color(0xFF7B4B94),
    ),
    IslamicOccasion(
      title: 'عيد الفطر المبارك',
      hMonth: 10,
      hDay: 1,
      subtitle: '١ شوال • يوم الجائزة والفرح',
      virtue: 'يُسن إخراج زكاة الفطر قبل صلاة العيد، والتكبير وإظهار الفرح وصلة الأرحام.',
      icon: Icons.celebration_rounded,
      accentColor: Color(0xFF1B8A5A),
    ),
    IslamicOccasion(
      title: 'يوم عرفة',
      hMonth: 12,
      hDay: 9,
      subtitle: '٩ ذو الحجة • خير أيام الدنيا',
      virtue: 'صيام يوم عرفة يكفّر السنة الماضية والباقية، وخير الدعاء دعاء يوم عرفة.',
      icon: Icons.landscape_rounded,
      accentColor: Color(0xFFD97706),
    ),
    IslamicOccasion(
      title: 'عيد الأضحى المبارك',
      hMonth: 12,
      hDay: 10,
      subtitle: '١٠ ذو الحجة • يوم النحر الأكبر',
      virtue: 'أعظم الأيام عند الله يوم النحر ثم يوم القرّ، ويستمر التكبير المقيد حتى عصر ثالث أيام التشريق.',
      icon: Icons.mosque_rounded,
      accentColor: Color(0xFF0D9488),
    ),
    IslamicOccasion(
      title: 'رأس السنة الهجرية',
      hMonth: 1,
      hDay: 1,
      subtitle: '١ محرم • ذكرى الهجرة النبوية',
      virtue: 'شهر الله المحرم هو أفضل الصيام بعد رمضان، وبداية عام هجري جديد بالطاعة.',
      icon: Icons.explore_rounded,
      accentColor: Color(0xFF2563EB),
    ),
    IslamicOccasion(
      title: 'يوم عاشوراء',
      hMonth: 1,
      hDay: 10,
      subtitle: '١٠ محرم • يوم نجاة موسى عليه السلام',
      virtue: 'صيام يوم عاشوراء يكفّر السنة الماضية، ويُستحب صيام التاسع معه مخالفةً لأهل الكتاب.',
      icon: Icons.water_drop_rounded,
      accentColor: Color(0xFF0284C7),
    ),
    IslamicOccasion(
      title: 'ذكرى المولد النبوي الشريف',
      hMonth: 3,
      hDay: 12,
      subtitle: '١٢ ربيع الأول • مولد خير الأنام ﷺ',
      virtue: 'أكثروا من الصلاة والسلام على النبي ﷺ واتباع سنته في الأخلاق والرحمة.',
      icon: Icons.favorite_rounded,
      accentColor: Color(0xFFBE185D),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hijriOffset = prefs.getInt('hijri_day_offset') ?? 0;
      _notifAdhkar = prefs.getBool('notif_adhkar') ?? true;
      _notifKhatmah = prefs.getBool('notif_khatmah') ?? true;
      _notifAyah = prefs.getBool('notif_ayah') ?? true;
      _notifNawafil = prefs.getBool('notif_nawafil') ?? true;
      _notifFasting = prefs.getBool('notif_fasting') ?? true;
      _notifPostPrayer = prefs.getBool('notif_post_prayer') ?? true;
    });
  }

  Future<void> _updateHijriOffset(int newOffset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('hijri_day_offset', newOffset);
    setState(() => _hijriOffset = newOffset);
  }

  Future<void> _toggleNotification(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    await _loadSettings();

    final lat = prefs.getDouble('prayer_lat') ?? 30.0444;
    final lng = prefs.getDouble('prayer_lng') ?? 31.2357;
    await RafiqNotificationsService.syncAllScheduledNotifications(
      lat: lat,
      lng: lng,
      params: CalculationMethod.egyptian.getParameters(),
    );
  }

  HijriCalendar _adjustedToday() {
    final adjustedDate = DateTime.now().add(Duration(days: _hijriOffset));
    return HijriCalendar.fromDate(adjustedDate);
  }

  int _daysUntilOccasion(IslamicOccasion occ) {
    final now = DateTime.now().add(Duration(days: _hijriOffset));
    final todayH = HijriCalendar.fromDate(now);

    int targetYear = todayH.hYear;
    if (occ.hMonth < todayH.hMonth ||
        (occ.hMonth == todayH.hMonth && occ.hDay < todayH.hDay)) {
      targetYear++;
    }

    final targetG = HijriCalendar().hijriToGregorian(targetYear, occ.hMonth, occ.hDay);
    final todayClean = DateTime(now.year, now.month, now.day);
    final targetClean = DateTime(targetG.year, targetG.month, targetG.day);
    return targetClean.difference(todayClean).inDays;
  }

  void _showOccasionDetails(IslamicOccasion occ, int daysLeft) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThalabTheme.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: occ.accentColor.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(occ.icon, color: occ.accentColor, size: 38),
            ),
            const SizedBox(height: 14),
            Text(
              occ.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: occ.accentColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                daysLeft == 0 ? 'اليوم هو موعد المناسبة المباركة' : 'متبقي $daysLeft يوم',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              occ.virtue,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.7, color: ThalabTheme.darkSlate),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayH = _adjustedToday();
    final monthName = _hijriMonthsAr[(todayH.hMonth - 1).clamp(0, 11)];
    final gregorianStr = DateFormat('EEEE، d MMMM y', 'ar').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقويم الهجري والمناسبات'),
      ),
      body: Column(
        children: [
          // شريط التبويب الثلاثي
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: ThalabTheme.cardSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ThalabTheme.softBorder),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: ThalabTheme.foxOrange,
                borderRadius: BorderRadius.circular(14),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: ThalabTheme.darkSlate,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'المناسبات'),
                Tab(text: 'التقويم'),
                Tab(text: 'الإشعارات'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. تبويب المناسبات والعد التنازلي لرمضان
                ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 34),
                  itemCount: _occasions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final occ = _occasions[index];
                    final daysLeft = _daysUntilOccasion(occ);
                    final isRamadan = occ.hMonth == 9 && occ.hDay == 1;

                    return GestureDetector(
                      onTap: () => _showOccasionDetails(occ, daysLeft),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: isRamadan
                              ? const LinearGradient(
                                  colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
                                )
                              : null,
                          color: isRamadan ? null : ThalabTheme.cardSurface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isRamadan ? Colors.transparent : ThalabTheme.softBorder,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isRamadan
                                    ? Colors.white.withOpacity(0.22)
                                    : occ.accentColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                occ.icon,
                                color: isRamadan ? Colors.white : occ.accentColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    occ.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isRamadan ? Colors.white : ThalabTheme.darkSlate,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    occ.subtitle,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isRamadan ? Colors.white70 : ThalabTheme.mutedSlate,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isRamadan
                                    ? Colors.white
                                    : occ.accentColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    daysLeft == 0 ? 'اليوم' : '$daysLeft',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isRamadan ? ThalabTheme.foxOrange : occ.accentColor,
                                    ),
                                  ),
                                  if (daysLeft > 0)
                                    Text(
                                      'يوم',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isRamadan ? ThalabTheme.foxOrange : occ.accentColor,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // 2. تبويب التقويم الهجري وضبط الهلال
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 34),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
                        ),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${todayH.hDay} $monthName ${todayH.hYear} هـ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            gregorianStr,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // شبكة أيام الشهر الهجري مع تمييز الأيام البيض
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ThalabTheme.cardSurface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: ThalabTheme.softBorder),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'أيام شهر $monthName',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1B8A5A),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text('الأيام البيض (١٣-١٥)', style: TextStyle(fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: todayH.lengthOfMonth,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                            itemBuilder: (context, idx) {
                              final day = idx + 1;
                              final isToday = day == todayH.hDay;
                              final isWhiteDay = day == 13 || day == 14 || day == 15;

                              return Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? ThalabTheme.foxOrange
                                      : isWhiteDay
                                          ? const Color(0xFF1B8A5A).withOpacity(0.15)
                                          : ThalabTheme.creamBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  border: isWhiteDay && !isToday
                                      ? Border.all(color: const Color(0xFF1B8A5A), width: 1.2)
                                      : null,
                                ),
                                child: Text(
                                  '$day',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isToday
                                        ? Colors.white
                                        : isWhiteDay
                                            ? const Color(0xFF1B8A5A)
                                            : ThalabTheme.darkSlate,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ضبط تصحيح الهلال
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ThalabTheme.cardSurface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: ThalabTheme.softBorder),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('تصحيح رؤية الهلال', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  'تقديم أو تأخير التاريخ الهجري حسب الرؤية',
                                  style: TextStyle(fontSize: 11, color: ThalabTheme.mutedSlate),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: ThalabTheme.foxOrange),
                            onPressed: () {
                              if (_hijriOffset > -2) _updateHijriOffset(_hijriOffset - 1);
                            },
                          ),
                          Text(
                            '${_hijriOffset >= 0 ? '+$_hijriOffset' : _hijriOffset} يوم',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: ThalabTheme.foxOrange),
                            onPressed: () {
                              if (_hijriOffset < 2) _updateHijriOffset(_hijriOffset + 1);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // 3. تبويب منظومة الإشعارات الشاملة
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 34),
                  children: [
                    _NotifSwitchCard(
                      title: 'إشعارات الأذكار وحصن المسلم',
                      subtitle: 'أذكار الصباح، المساء، وأذكار متنوعة يومياً',
                      icon: Icons.auto_stories_rounded,
                      value: _notifAdhkar,
                      onChanged: (v) => _toggleNotification('notif_adhkar', v),
                    ),
                    _NotifSwitchCard(
                      title: 'تذكير وِرد الختمة اليومي',
                      subtitle: 'متابعة التقدم في ختم القرآن الكريم',
                      icon: Icons.menu_book_rounded,
                      value: _notifKhatmah,
                      onChanged: (v) => _toggleNotification('notif_khatmah', v),
                    ),
                    _NotifSwitchCard(
                      title: 'إشعار آية متجددة يومياً',
                      subtitle: 'آية قرآنية مختارة للتدبر كل يوم',
                      icon: Icons.format_quote_rounded,
                      value: _notifAyah,
                      onChanged: (v) => _toggleNotification('notif_ayah', v),
                    ),
                    _NotifSwitchCard(
                      title: 'تذكير الصيام بجميع أنواعه',
                      subtitle: 'الاثنين والخميس والأيام البيض والمواسم',
                      icon: Icons.nights_stay_rounded,
                      value: _notifFasting,
                      onChanged: (v) => _toggleNotification('notif_fasting', v),
                    ),
                    _NotifSwitchCard(
                      title: 'إشعارات السنن والنوافل',
                      subtitle: 'صلاة الضحى وركعة الوتر وقيام الليل',
                      icon: Icons.wb_sunny_rounded,
                      value: _notifNawafil,
                      onChanged: (v) => _toggleNotification('notif_nawafil', v),
                    ),
                    _NotifSwitchCard(
                      title: 'متابعة إتمام الصلاة دبر كل فرض',
                      subtitle: 'تذكير لطيف بعد كل صلاة للتحقق من إتمامها',
                      icon: Icons.check_circle_outline_rounded,
                      value: _notifPostPrayer,
                      onChanged: (v) => _toggleNotification('notif_post_prayer', v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifSwitchCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotifSwitchCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: ThalabTheme.cardSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ThalabTheme.softBorder, width: 1.4),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeColor: ThalabTheme.foxOrange,
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ThalabTheme.foxOrange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: ThalabTheme.foxOrange),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11.5, color: ThalabTheme.mutedSlate)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
