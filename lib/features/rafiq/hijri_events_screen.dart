import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';

class HijriEvent {
  final String title;
  final int month;
  final int day;
  final String description;

  const HijriEvent({
    required this.title,
    required this.month,
    required this.day,
    required this.description,
  });
}

class HijriEventsScreen extends StatefulWidget {
  final int initialTab;
  const HijriEventsScreen({super.key, this.initialTab = 0});

  @override
  State<HijriEventsScreen> createState() => _HijriEventsScreenState();
}

class _HijriEventsScreenState extends State<HijriEventsScreen> {
  late int _currentTab;

  static const List<HijriEvent> _events = [
    HijriEvent(title: 'رأس السنة الهجرية', month: 1, day: 1, description: 'بداية العام الهجري الجديد وذكرى الهجرة النبوية الشريفة.'),
    HijriEvent(title: 'يوم عاشوراء', month: 1, day: 10, description: 'يُستحب صيامه وصيام يوم قبله أو بعده، يكفّر السنة الماضية.'),
    HijriEvent(title: 'ليلة النصف من شعبان', month: 8, day: 15, description: 'ليلة مباركة تُرفع فيها الأعمال ويُستحب فيها الدعاء والاستغفار.'),
    HijriEvent(title: 'بداية شهر رمضان المبارك', month: 9, day: 1, description: 'شهر الصيام والقيام وتلاوة القرآن الكريم.'),
    HijriEvent(title: 'العشر الأواخر وليلة القدر', month: 9, day: 21, description: 'تحرّي ليلة القدر في الليالي الوترية من العشر الأواخر.'),
    HijriEvent(title: 'عيد الفطر المبارك', month: 10, day: 1, description: 'يوم الجائزة والفرح بعد إتمام صيام شهر رمضان.'),
    HijriEvent(title: 'يوم عرفة', month: 12, day: 9, description: 'خير يوم طلعت عليه الشمس، وصيامه يكفّر سنتين لغير الحاج.'),
    HijriEvent(title: 'عيد الأضحى المبارك', month: 12, day: 10, description: 'يوم النحر الأكبر وأيام التشريق المباركة.'),
  ];

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
  }

  int _daysUntil(HijriCalendar today, HijriEvent event) {
    int targetYear = today.hYear;
    if (event.month < today.hMonth ||
        (event.month == today.hMonth && event.day < today.hDay)) {
      targetYear += 1;
    }
    final targetGregorian = HijriCalendar().hijriToGregorian(targetYear, event.month, event.day);
    final nowDate = DateTime.now();
    final todayMidnight = DateTime(nowDate.year, nowDate.month, nowDate.day);
    return targetGregorian.difference(todayMidnight).inDays;
  }

  @override
  Widget build(BuildContext context) {
    HijriCalendar.setLocal('ar');
    final today = HijriCalendar.now();

    final sortedEvents = [..._events]
      ..sort((a, b) => _daysUntil(today, a).compareTo(_daysUntil(today, b)));

    return DefaultTabController(
      length: 3,
      initialIndex: _currentTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('التقويم والمناسبات'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'المناسبات'),
              Tab(text: 'التقويم'),
              Tab(text: 'الإشعارات'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildEventsList(today, sortedEvents),
            _buildCalendarView(today),
            _buildNotificationsView(),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsList(HijriCalendar today, List<HijriEvent> sortedEvents) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: const Color(0xFF0F3D3E),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('التاريخ الهجري اليوم', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Text(
                today.toFormat('dd MMMM yyyy هـ'),
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ...sortedEvents.map((event) {
          final daysLeft = _daysUntil(today, event);
          final badgeText = daysLeft == 0 ? 'اليوم' : 'متبقي $daysLeft يوم';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(event.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E6F5C).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(color: Color(0xFF1E6F5C), fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  event.description,
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCalendarView(HijriCalendar today) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_rounded, size: 64, color: Color(0xFF0F3D3E)),
            const SizedBox(height: 16),
            Text(today.toFormat('dd MMMM yyyy هـ'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('اليوم: ${today.hDay}', style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_active_rounded, size: 64, color: Color(0xFF0F3D3E)),
            SizedBox(height: 16),
            Text('إعدادات الإشعارات والتنبيهات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('يمكنك التحكم في تنبيهات المواقيت والمناسبات من هنا.', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
