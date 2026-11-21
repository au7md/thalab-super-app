import 'dart:async';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/storage_service.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  late PrayerTimes _prayerTimes;
  late Timer _timer;
  Duration _timeRemaining = Duration.zero;
  String _nextPrayerName = '';
  bool _notificationsEnabled = false;

  // إحداثيات القاهرة كقيمة افتراضية دقيقة (طريقة الهيئة المصرية العامة للمساحة)
  final Coordinates _coordinates = Coordinates(30.0444, 31.2357);

  @override
  void initState() {
    super.initState();
    _calculatePrayers();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _calculatePrayers() {
    final params = CalculationMethod.egyptian.getParameters();
    params.madhab = Madhab.shafi;
    final date = DateComponents.from(DateTime.now());
    _prayerTimes = PrayerTimes(_coordinates, date, params);
    _updateCountdown();
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final next = _prayerTimes.nextPrayer();
    DateTime? nextTime = _prayerTimes.timeForPrayer(next);

    if (next == Prayer.none || nextTime == null) {
      final tomorrow = DateComponents.from(now.add(const Duration(days: 1)));
      final params = CalculationMethod.egyptian.getParameters();
      final tomorrowPrayers = PrayerTimes(_coordinates, tomorrow, params);
      nextTime = tomorrowPrayers.fajr;
      _nextPrayerName = 'الفجر';
    } else {
      _nextPrayerName = _arabicPrayerName(next);
    }

    if (mounted) {
      setState(() {
        _timeRemaining = nextTime!.difference(now);
      });
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
      default:
        return 'الفجر';
    }
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '00:00:00';
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _activateDailyAlerts() async {
    await StorageService.scheduleDailyReminder(
      id: 101,
      title: 'أذكار الصباح — رفيق',
      body: 'ابدأ يومك بذكر الله وطمأنينة القلب.',
      hour: 6,
      minute: 30,
    );
    await StorageService.scheduleDailyReminder(
      id: 102,
      title: 'أذكار المساء — رفيق',
      body: 'حان وقت أذكار المساء وحفظ النفس.',
      hour: 17,
      minute: 30,
    );
    setState(() => _notificationsEnabled = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تفعيل إشعارات أذكار الصباح والمساء اليومية بنجاح ✓'),
          backgroundColor: ThalabTheme.foxOrange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('hh:mm a', 'ar');
    final currentPrayer = _prayerTimes.currentPrayer();

    final list = [
      ('الفجر', _prayerTimes.fajr, Prayer.fajr, Icons.wb_twilight_rounded),
      ('الشروق', _prayerTimes.sunrise, Prayer.sunrise, Icons.wb_sunny_outlined),
      ('الظهر', _prayerTimes.dhuhr, Prayer.dhuhr, Icons.wb_sunny_rounded),
      ('العصر', _prayerTimes.asr, Prayer.asr, Icons.sunny_snowing),
      ('المغرب', _prayerTimes.maghrib, Prayer.maghrib, Icons.nights_stay_outlined),
      ('العشاء', _prayerTimes.isha, Prayer.isha, Icons.bedtime_rounded),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('مواقيت الصلاة'),
        actions: [
          IconButton(
            tooltip: 'تفعيل تذكير الأذكار',
            icon: Icon(
              _notificationsEnabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              color: ThalabTheme.foxOrange,
            ),
            onPressed: _activateDailyAlerts,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: [
          // بطاقة العد التنازلي للصلاة القادمة
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: ThalabTheme.foxOrange.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'المتبقي على أذان $_nextPrayerName',
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDuration(_timeRemaining),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'توقيت القاهرة — الهيئة المصرية للمساحة',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // قائمة الصلوات
          ...list.map((item) {
            final isCurrent = item.$3 == currentPrayer;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: isCurrent
                    ? ThalabTheme.foxOrange.withOpacity(0.12)
                    : ThalabTheme.cardSurface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isCurrent ? ThalabTheme.foxOrange : ThalabTheme.softBorder,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(item.$4, color: ThalabTheme.foxOrange, size: 24),
                  const SizedBox(width: 14),
                  Text(
                    item.$1,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatter.format(item.$2),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isCurrent ? ThalabTheme.foxOrange : ThalabTheme.darkSlate,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
