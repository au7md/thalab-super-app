import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:adhan/adhan.dart';
import '../../core/prayer_calc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/rafiq_notifications_service.dart';
import 'prayer_times_screen.dart';

class HijriEvent {
  final String title;
  final int month;
  final int day;
  final String description;
  final String virtue;
  final IconData icon;

  const HijriEvent({
    required this.title,
    required this.month,
    required this.day,
    required this.description,
    required this.virtue,
    required this.icon,
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

  late int _viewHijriYear;
  late int _viewHijriMonth;
  int? _selectedHijriDay;

  bool _masterNotifEnabled = true;
  bool _morningAzkarNotif = true;
  bool _eveningAzkarNotif = true;
  bool _sleepAzkarNotif = true;
  bool _quranWirdNotif = true;
  bool _hijriEventsNotif = true;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardBg => Theme.of(context).cardColor;
  Color get _innerBg => Theme.of(context).scaffoldBackgroundColor;
  Color get _borderColor => _isDark ? ThalabTheme.darkBorder : ThalabTheme.softBorder;
  Color get _textColor => _isDark ? ThalabTheme.darkTextPrimary : ThalabTheme.darkSlate;

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

  static const List<String> _gregorianMonthsAr = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  static const List<String> _weekDaysAr = [
    'السبت',
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
  ];

  static const List<HijriEvent> _events = [
    HijriEvent(
      title: 'رأس السنة الهجرية',
      month: 1,
      day: 1,
      description: 'بداية العام الهجري الجديد وذكرى الهجرة النبوية الشريفة.',
      virtue: 'محاسبة النفس وتجديد النية لعام مليء بالطاعات.',
      icon: Icons.auto_awesome_rounded,
    ),
    HijriEvent(
      title: 'يوم عاشوراء',
      month: 1,
      day: 10,
      description: 'اليوم العاشر من شهر الله المحرم، يُستحب صيامه وصيام يوم قبله.',
      virtue: 'صيامه يكفّر السنة الماضية كما صحّ عن النبي ﷺ.',
      icon: Icons.water_drop_rounded,
    ),
    HijriEvent(
      title: 'ليلة النصف من شعبان',
      month: 8,
      day: 15,
      description: 'ليلة مباركة يطّلع الله فيها على خلقه فيغفر للمستغفرين.',
      virtue: 'يُستحب فيها الدعاء والاستغفار وصيام الأيام البيض.',
      icon: Icons.nights_stay_rounded,
    ),
    HijriEvent(
      title: 'بداية شهر رمضان المبارك',
      month: 9,
      day: 1,
      description: 'أول أيام شهر الصيام والقيام وتلاوة القرآن الكريم.',
      virtue: 'تُفتح فيه أبواب الجنة وتُغلق أبواب النار وتُصفّد الشياطين.',
      icon: Icons.mosque_rounded,
    ),
    HijriEvent(
      title: 'العشر الأواخر وليلة القدر',
      month: 9,
      day: 21,
      description: 'تحرّي ليلة القدر في الليالي الوترية من العشر الأواخر.',
      virtue: 'ليلة القدر خير من ألف شهر، من قامها إيماناً واحتساباً غُفر له.',
      icon: Icons.star_rounded,
    ),
    HijriEvent(
      title: 'عيد الفطر المبارك',
      month: 10,
      day: 1,
      description: 'يوم الجائزة والفرح وصلة الأرحام بعد إتمام صيام شهر رمضان.',
      virtue: 'يُسنّ إخراج زكاة الفطر قبل صلاة العيد والتكبير.',
      icon: Icons.celebration_rounded,
    ),
    HijriEvent(
      title: 'يوم عرفة',
      month: 12,
      day: 9,
      description: 'أعظم أيام العام وموقف الحج الأكبر في التاسع من ذي الحجة.',
      virtue: 'صيامه يكفّر السنة الماضية والباقية لغير الحاج.',
      icon: Icons.wb_sunny_rounded,
    ),
    HijriEvent(
      title: 'عيد الأضحى المبارك',
      month: 12,
      day: 10,
      description: 'يوم النحر الأكبر وأيام التشريق المباركة (10 - 13 ذو الحجة).',
      virtue: 'أعظم الأيام عند الله يوم النحر ثم يوم القرّ.',
      icon: Icons.favorite_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    final initialH = HijriCalendar.now();
    _viewHijriYear = initialH.hYear;
    _viewHijriMonth = initialH.hMonth;
    _selectedHijriDay = initialH.hDay;
    _loadPrefs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final offset = prefs.getInt('hijri_day_offset') ?? 0;
    final adjustedH = HijriCalendar.fromDate(DateTime.now().add(Duration(days: offset)));

    setState(() {
      _hijriOffset = offset;
      _viewHijriYear = adjustedH.hYear;
      _viewHijriMonth = adjustedH.hMonth;
      _selectedHijriDay = adjustedH.hDay;
      _masterNotifEnabled = prefs.getBool('notif_master_enabled') ?? true;
      _morningAzkarNotif = prefs.getBool('notif_azkar_morning') ?? true;
      _eveningAzkarNotif = prefs.getBool('notif_azkar_evening') ?? true;
      _sleepAzkarNotif = prefs.getBool('notif_azkar_sleep') ?? true;
      _quranWirdNotif = prefs.getBool('notif_quran_wird') ?? true;
      _hijriEventsNotif = prefs.getBool('notif_hijri_events') ?? true;
    });
  }

  Future<void> _updateHijriOffset(int newOffset) async {
    HapticFeedback.selectionClick();
    final clamped = newOffset.clamp(-2, 2);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('hijri_day_offset', clamped);
    final adjustedH = HijriCalendar.fromDate(DateTime.now().add(Duration(days: clamped)));

    setState(() {
      _hijriOffset = clamped;
      _viewHijriYear = adjustedH.hYear;
      _viewHijriMonth = adjustedH.hMonth;
      _selectedHijriDay = adjustedH.hDay;
    });
    await _resyncAllNotifications();
  }

  Future<void> _resyncAllNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('saved_lat') ?? 30.0444;
    final lng = prefs.getDouble('saved_lng') ?? 31.2357;
    final params = prayerParamsFor(lat, lng);
    params.madhab = Madhab.shafi;
    await RafiqNotificationsService.instance.syncAllScheduledNotifications(
      lat: lat,
      lng: lng,
      params: params,
    );
  }

  int _daysUntil(HijriCalendar today, HijriEvent event) {
    int targetYear = today.hYear;
    if (event.month < today.hMonth ||
        (event.month == today.hMonth && event.day < today.hDay)) {
      targetYear += 1;
    }
    final targetGregorian = HijriCalendar().hijriToGregorian(targetYear, event.month, event.day);
    final nowDate = DateTime.now().add(Duration(days: _hijriOffset));
    final todayMidnight = DateTime(nowDate.year, nowDate.month, nowDate.day);
    return targetGregorian.difference(todayMidnight).inDays;
  }

  String _formatGregorianAr(DateTime dt) {
    final mName = _gregorianMonthsAr[(dt.month - 1).clamp(0, 11)];
    return '${dt.day} $mName ${dt.year} م';
  }

  @override
  Widget build(BuildContext context) {
    final adjustedNow = DateTime.now().add(Duration(days: _hijriOffset));
    final todayH = HijriCalendar.fromDate(adjustedNow);
    final todayMonthName = _hijriMonthsAr[(todayH.hMonth - 1).clamp(0, 11)];
    final sortedEvents = [..._events]
      ..sort((a, b) => _daysUntil(todayH, a).compareTo(_daysUntil(todayH, b)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقويم الهجري والمناسبات'),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderColor),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: ThalabTheme.foxOrange,
                borderRadius: BorderRadius.circular(14),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: _textColor,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              labelPadding: EdgeInsets.zero,
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.all(4),
              tabs: const [
                Tab(text: 'المناسبات'),
                Tab(text: 'التقويم الشهري'),
                Tab(text: 'الإشعارات'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEventsList(todayH, todayMonthName, sortedEvents),
                _buildInteractiveCalendarTab(todayH),
                _buildNotificationsCenterTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(
    HijriCalendar todayH,
    String todayMonthName,
    List<HijriEvent> sortedEvents,
  ) {
    final gToday = DateTime.now();
    final isWhiteDay = todayH.hDay == 13 || todayH.hDay == 14 || todayH.hDay == 15;
    final isMonOrThu = gToday.weekday == DateTime.monday || gToday.weekday == DateTime.thursday;

    int daysToWhiteDays;
    if (todayH.hDay < 13) {
      daysToWhiteDays = 13 - todayH.hDay;
    } else if (todayH.hDay <= 15) {
      daysToWhiteDays = 0;
    } else {
      daysToWhiteDays = (30 - todayH.hDay) + 13;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF163A38), Color(0xFF235C58)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF163A38).withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'التاريخ الهجري اليوم',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _formatGregorianAr(gToday),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${todayH.hDay} $todayMonthName ${todayH.hYear} هـ',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'تعديل فرق الهلال:',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Row(
                      children: [
                        _OffsetStepBtn(
                          icon: Icons.remove_rounded,
                          onTap: () => _updateHijriOffset(_hijriOffset - 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            _hijriOffset == 0
                                ? 'مضبوط (0)'
                                : (_hijriOffset > 0 ? '+$_hijriOffset يوم' : '$_hijriOffset يوم'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        _OffsetStepBtn(
                          icon: Icons.add_rounded,
                          onTap: () => _updateHijriOffset(_hijriOffset + 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ThalabTheme.foxOrange.withOpacity(0.35), width: 1.3),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ThalabTheme.foxOrange.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.brightness_3_rounded, color: ThalabTheme.foxOrange, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isWhiteDay
                          ? 'اليوم من الأيام البيض المباركة (${todayH.hDay} $todayMonthName)'
                          : 'الأيام البيض القادمة (13، 14، 15 $todayMonthName)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isMonOrThu
                          ? 'اليوم يُستحب صيامه (سنة الإثنين والخميس)'
                          : 'صيام ثلاثة أيام من كل شهر يعدل صيام الدهر كله',
                      style: const TextStyle(fontSize: 11.5, color: ThalabTheme.mutedSlate),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: ThalabTheme.foxOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  daysToWhiteDays == 0 ? 'الآن' : _afterDaysAr(daysToWhiteDays),
                  style: const TextStyle(
                    color: ThalabTheme.foxOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        const Padding(
          padding: EdgeInsets.only(bottom: 8, right: 4),
          child: Text(
            'المناسبات الإسلامية القادمة',
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
          ),
        ),

        ...sortedEvents.map((event) {
          final daysLeft = _daysUntil(todayH, event);
          final isToday = daysLeft == 0;
          final badgeText = isToday ? 'اليوم 🎉' : 'متبقي $daysLeft يوم';
          final eventMonthName = _hijriMonthsAr[(event.month - 1).clamp(0, 11)];

          int targetYear = todayH.hYear;
          if (event.month < todayH.hMonth ||
              (event.month == todayH.hMonth && event.day < todayH.hDay)) {
            targetYear += 1;
          }
          final gTarget = HijriCalendar().hijriToGregorian(targetYear, event.month, event.day);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isToday ? ThalabTheme.foxOrange.withOpacity(0.08) : _cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isToday ? ThalabTheme.foxOrange : _borderColor,
                width: isToday ? 1.8 : 1.3,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: ThalabTheme.foxOrange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(event.icon, color: ThalabTheme.foxOrange, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${event.day} $eventMonthName • يوافق ${_formatGregorianAr(gTarget)}',
                            style: const TextStyle(fontSize: 11, color: ThalabTheme.mutedSlate),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isToday
                            ? ThalabTheme.foxOrange
                            : (_isDark
                                ? const Color(0xFF235C58).withOpacity(0.35)
                                : const Color(0xFF163A38).withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: isToday
                              ? Colors.white
                              : (_isDark ? const Color(0xFF7FD1C8) : const Color(0xFF163A38)),
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  event.description,
                  style: const TextStyle(fontSize: 12.5, height: 1.45),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _innerBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    event.virtue,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: ThalabTheme.mutedSlate,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildInteractiveCalendarTab(HijriCalendar todayH) {
    final monthName = _hijriMonthsAr[(_viewHijriMonth - 1).clamp(0, 11)];
    final daysInMonth = HijriCalendar().getDaysInMonth(_viewHijriYear, _viewHijriMonth);
    final firstDayGregorian = HijriCalendar().hijriToGregorian(_viewHijriYear, _viewHijriMonth, 1);
    final int startOffset = (firstDayGregorian.weekday % 7 + 1) % 7;

    final selectedDaySafe = (_selectedHijriDay ?? 1).clamp(1, daysInMonth);
    final selectedGregorian = HijriCalendar()
        .hijriToGregorian(_viewHijriYear, _viewHijriMonth, selectedDaySafe)
        .subtract(Duration(days: _hijriOffset));

    final matchingEvents = _events
        .where((e) => e.month == _viewHijriMonth && e.day == selectedDaySafe)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor, width: 1.3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'الشهر السابق',
                icon: const Icon(Icons.chevron_right_rounded, color: ThalabTheme.foxOrange, textDirection: TextDirection.ltr),
                onPressed: () {
                  setState(() {
                    if (_viewHijriMonth == 1) {
                      _viewHijriMonth = 12;
                      _viewHijriYear--;
                    } else {
                      _viewHijriMonth--;
                    }
                    _selectedHijriDay = 1;
                  });
                },
              ),
              Column(
                children: [
                  Text(
                    '$monthName $_viewHijriYear هـ',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'يوافق ${_gregorianMonthsAr[firstDayGregorian.month - 1]} ${firstDayGregorian.year} م',
                    style: const TextStyle(fontSize: 11.5, color: ThalabTheme.mutedSlate),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'الشهر التالي',
                icon: const Icon(Icons.chevron_left_rounded, color: ThalabTheme.foxOrange, textDirection: TextDirection.ltr),
                onPressed: () {
                  setState(() {
                    if (_viewHijriMonth == 12) {
                      _viewHijriMonth = 1;
                      _viewHijriYear++;
                    } else {
                      _viewHijriMonth++;
                    }
                    _selectedHijriDay = 1;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _borderColor, width: 1.3),
          ),
          child: Column(
            children: [
              Row(
                children: _weekDaysAr
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: ThalabTheme.mutedSlate,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: startOffset + daysInMonth,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 0.88,
                ),
                itemBuilder: (context, index) {
                  if (index < startOffset) return const SizedBox.shrink();
                  final hDay = index - startOffset + 1;
                  final gDate = HijriCalendar()
                      .hijriToGregorian(_viewHijriYear, _viewHijriMonth, hDay)
                      .subtract(Duration(days: _hijriOffset));

                  final isToday = _viewHijriYear == todayH.hYear &&
                      _viewHijriMonth == todayH.hMonth &&
                      hDay == todayH.hDay;
                  final isSelected = hDay == selectedDaySafe;
                  final isWhite = hDay == 13 || hDay == 14 || hDay == 15;
                  final hasEvent = _events.any((e) => e.month == _viewHijriMonth && e.day == hDay);

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _selectedHijriDay = hDay),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? ThalabTheme.foxOrange
                            : isToday
                                ? const Color(0xFF163A38).withOpacity(_isDark ? 0.45 : 0.14)
                                : isWhite
                                    ? ThalabTheme.foxOrange.withOpacity(0.1)
                                    : _innerBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isToday
                              ? (_isDark ? const Color(0xFF4CA89F) : const Color(0xFF163A38))
                              : hasEvent
                                  ? ThalabTheme.foxOrange
                                  : Colors.transparent,
                          width: 1.4,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$hDay',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : _textColor,
                            ),
                          ),
                          Text(
                            '${gDate.day}',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: isSelected ? Colors.white70 : ThalabTheme.mutedSlate,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _LegendDot(
                    color: _isDark ? const Color(0xFF4CA89F) : const Color(0xFF163A38),
                    label: 'اليوم',
                  ),
                  _LegendDot(color: ThalabTheme.foxOrange.withOpacity(0.35), label: 'الأيام البيض'),
                  const _LegendDot(color: ThalabTheme.foxOrange, label: 'مناسبة دينية'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor, width: 1.3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$selectedDaySafe $monthName $_viewHijriYear هـ',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _formatGregorianAr(selectedGregorian),
                    style: const TextStyle(
                      color: ThalabTheme.foxOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (matchingEvents.isNotEmpty)
                ...matchingEvents.map(
                  (ev) => Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ThalabTheme.foxOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ev.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: ThalabTheme.foxOrange,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(ev.description, style: const TextStyle(fontSize: 12.5)),
                      ],
                    ),
                  ),
                )
              else if (selectedDaySafe == 13 || selectedDaySafe == 14 || selectedDaySafe == 15)
                const Text(
                  'يوم من الأيام البيض المباركة — يُستحب صيامه.',
                  style: TextStyle(fontSize: 13, color: ThalabTheme.foxOrange, fontWeight: FontWeight.bold),
                )
              else
                const Text(
                  'يوم عادي من الشهر الهجري — اغتنمه بالذكر وتلاوة الورد القرآني.',
                  style: TextStyle(fontSize: 12.5, color: ThalabTheme.mutedSlate),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsCenterTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'منظومة التنبيهات الذكية',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'تعمل في الخلفية بدقة حسب منطقتك الزمنية',
                          style: TextStyle(color: Colors.white70, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _masterNotifEnabled,
                    activeColor: ThalabTheme.foxOrange,
                    activeTrackColor: Colors.white,
                    inactiveThumbColor: Colors.white70,
                    inactiveTrackColor: Colors.black26,
                    onChanged: (val) async {
                      final prefs = await SharedPreferences.getInstance();
                      setState(() => _masterNotifEnabled = val);
                      await prefs.setBool('notif_master_enabled', val);
                      await _resyncAllNotifications();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: ThalabTheme.foxOrange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        await RafiqNotificationsService.instance.sendTestNotification();
                      },
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('تجربة إشعار الآن', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PrayerTimesScreen(initialTab: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('تنبيهات الصلوات', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        const Padding(
          padding: EdgeInsets.only(bottom: 8, right: 4),
          child: Text(
            'تنبيهات الأذكار والورد والمناسبات',
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
          ),
        ),

        _NotifToggleCard(
          title: 'تذكير أذكار الصباح',
          subtitle: 'يومياً الساعة 6:30 صباحاً',
          icon: Icons.wb_sunny_rounded,
          value: _morningAzkarNotif,
          onChanged: (val) async {
            final prefs = await SharedPreferences.getInstance();
            setState(() => _morningAzkarNotif = val);
            await prefs.setBool('notif_azkar_morning', val);
            await _resyncAllNotifications();
          },
        ),
        _NotifToggleCard(
          title: 'تذكير أذكار المساء',
          subtitle: 'يومياً الساعة 5:30 مساءً',
          icon: Icons.nights_stay_rounded,
          value: _eveningAzkarNotif,
          onChanged: (val) async {
            final prefs = await SharedPreferences.getInstance();
            setState(() => _eveningAzkarNotif = val);
            await prefs.setBool('notif_azkar_evening', val);
            await _resyncAllNotifications();
          },
        ),
        _NotifToggleCard(
          title: 'تذكير أذكار النوم',
          subtitle: 'يومياً الساعة 10:30 مساءً',
          icon: Icons.bedtime_rounded,
          value: _sleepAzkarNotif,
          onChanged: (val) async {
            final prefs = await SharedPreferences.getInstance();
            setState(() => _sleepAzkarNotif = val);
            await prefs.setBool('notif_azkar_sleep', val);
            await _resyncAllNotifications();
          },
        ),
        _NotifToggleCard(
          title: 'تذكير الورد القرآني اليومي',
          subtitle: 'يومياً الساعة 8:00 مساءً لمتابعة الختمة',
          icon: Icons.menu_book_rounded,
          value: _quranWirdNotif,
          onChanged: (val) async {
            final prefs = await SharedPreferences.getInstance();
            setState(() => _quranWirdNotif = val);
            await prefs.setBool('notif_quran_wird', val);
            await _resyncAllNotifications();
          },
        ),
        _NotifToggleCard(
          title: 'تنبيهات المناسبات الهجرية والأيام البيض',
          subtitle: 'تذكير تلقائي في عاشوراء، رمضان، عرفة، والعيدين',
          icon: Icons.event_available_rounded,
          value: _hijriEventsNotif,
          onChanged: (val) async {
            final prefs = await SharedPreferences.getInstance();
            setState(() => _hijriEventsNotif = val);
            await prefs.setBool('notif_hijri_events', val);
            await _resyncAllNotifications();
          },
        ),
      ],
    );
  }
}

class _OffsetStepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _OffsetStepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: ThalabTheme.mutedSlate)),
      ],
    );
  }
}

class _NotifToggleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotifToggleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? ThalabTheme.darkBorder : ThalabTheme.softBorder,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: ThalabTheme.foxOrange.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: ThalabTheme.foxOrange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle, style: const TextStyle(fontSize: 11.5, color: ThalabTheme.mutedSlate)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: ThalabTheme.foxOrange,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// صيغة عربية صحيحة لعدد الأيام: بعد يوم / يومين / 5 أيام / 26 يوماً.
String _afterDaysAr(int d) {
  if (d == 1) return 'بعد يوم';
  if (d == 2) return 'بعد يومين';
  if (d >= 3 && d <= 10) return 'بعد $d أيام';
  return 'بعد $d يوماً';
}
