import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:adhan/adhan.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MuezzinOption {
  final String id;
  final String name;
  final String description;

  const MuezzinOption(this.id, this.name, this.description);
}

class RafiqNotificationsService {
  RafiqNotificationsService._();
  static final RafiqNotificationsService instance = RafiqNotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const List<MuezzinOption> muezzins = [
    MuezzinOption('afasy', 'الشيخ مشاري العفاسي', 'أذان هادئ وعذب'),
    MuezzinOption('qatami', 'الشيخ ناصر القطامي', 'نبرة خاشعة ومميزة'),
    MuezzinOption('dosari', 'الشيخ ياسر الدوسري', 'أذان الحرم المكي'),
    MuezzinOption('abdulbasit', 'الشيخ عبد الباسط عبد الصمد', 'الأذان الكلاسيكي الأصيل'),
    MuezzinOption('default', 'تنبيه النظام الافتراضي', 'نغمة إشعار قياسية'),
  ];

  Future<void> init() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();
      _configureLocalTimeZone();

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _plugin.initialize(initSettings);
      await _requestPermissions();
      _initialized = true;
    } catch (e) {
      debugPrint('RafiqNotificationsService init error: $e');
    }
  }

  void _configureLocalTimeZone() {
    final offset = DateTime.now().timeZoneOffset;
    if (offset.inHours == 2) {
      tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
      return;
    }
    if (offset.inHours == 3) {
      tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
      return;
    }
    final matching = tz.timeZoneDatabase.locations.values.where(
      (loc) => loc.currentTimeZone.offset == offset.inMilliseconds,
    );
    if (matching.isNotEmpty) {
      tz.setLocalLocation(matching.first);
    } else {
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('Permission request error: $e');
    }
  }

  Future<String> _getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name')?.trim() ?? '';
    return name.isEmpty ? 'صديقي' : name;
  }

  Future<void> sendTestNotification() async {
    await init();
    final userName = await _getUserName();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'rafiq_prayers_channel_v2',
      'تنبيهات رفيق الإيمانية',
      channelDescription: 'تنبيهات الأذان والأذكار والمناسبات',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    await _plugin.show(
      999,
      'رفيق — الواحة الإيمانية',
      'أهلاً يا $userName، منظومة الإشعارات الدقيقة تعمل الآن بنجاح.',
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> syncAllScheduledNotifications({
    required double lat,
    required double lng,
    required CalculationParameters params,
  }) async {
    await init();
    await cancelAll();

    final prefs = await SharedPreferences.getInstance();
    final masterEnabled = prefs.getBool('notif_master_enabled') ?? true;
    if (!masterEnabled) return;

    final userName = await _getUserName();
    final selectedMuezzin = prefs.getString('selected_muezzin_id') ?? 'afasy';
    final muezzinName = muezzins
        .firstWhere((m) => m.id == selectedMuezzin, orElse: () => muezzins.first)
        .name;

    final coords = Coordinates(lat, lng);
    final now = DateTime.now();

    int idCounter = 100;
    for (int dayOffset = 0; dayOffset <= 1; dayOffset++) {
      final targetDate = now.add(Duration(days: dayOffset));
      final pt = PrayerTimes(coords, DateComponents.from(targetDate), params);

      final prayers = [
        ('fajr', 'الفجر', pt.fajr),
        ('dhuhr', 'الظهر', pt.dhuhr),
        ('asr', 'العصر', pt.asr),
        ('maghrib', 'المغرب', pt.maghrib),
        ('isha', 'العشاء', pt.isha),
      ];

      for (final p in prayers) {
        final key = p.$1;
        final name = p.$2;
        final adhanTime = p.$3;

        final adhanEnabled = prefs.getBool('prayer_notif_${key}_adhan') ?? true;
        final beforeMins = prefs.getInt('prayer_notif_${key}_before') ?? 0;
        final afterMins = prefs.getInt('prayer_notif_${key}_after') ?? 0;

        if (beforeMins > 0) {
          final beforeTime = adhanTime.subtract(Duration(minutes: beforeMins));
          if (beforeTime.isAfter(now)) {
            await _scheduleExact(
              id: idCounter++,
              title: 'اقتربت صلاة $name يا $userName',
              body: 'متبقي $beforeMins دقيقة على أذان $name — استعد للوضوء والصلاة.',
              scheduledTime: beforeTime,
              channelId: 'rafiq_prayers_channel_v2',
              channelName: 'مواقيت الصلاة - رفيق',
            );
          }
        }

        if (adhanEnabled && adhanTime.isAfter(now)) {
          final fajrNote = key == 'fajr' ? ' • الصلاة خير من النوم' : '';
          await _scheduleExact(
            id: idCounter++,
            title: 'حان الآن موعد أذان $name$fajrNote',
            body: 'أقم صلاتك يا $userName ($muezzinName)',
            scheduledTime: adhanTime,
            channelId: 'rafiq_prayers_channel_v2',
            channelName: 'مواقيت الصلاة - رفيق',
          );
        }

        if (afterMins > 0) {
          final afterTime = adhanTime.add(Duration(minutes: afterMins));
          if (afterTime.isAfter(now)) {
            await _scheduleExact(
              id: idCounter++,
              title: 'أذكار ما بعد صلاة $name',
              body: 'تقبل الله طاعتك يا $userName — لا تنسَ أذكار دُبُر الصلاة.',
              scheduledTime: afterTime,
              channelId: 'rafiq_prayers_channel_v2',
              channelName: 'مواقيت الصلاة - رفيق',
            );
          }
        }
      }
    }

    if (prefs.getBool('notif_azkar_morning') ?? true) {
      await scheduleDailyAzkar(
        id: 501,
        title: 'أذكار الصباح يا $userName',
        body: 'حصّن يومك بذكر الله — افتح وِرد الصباح في رفيق',
        hour: prefs.getInt('notif_morning_hour') ?? 6,
        minute: prefs.getInt('notif_morning_min') ?? 30,
      );
    }

    if (prefs.getBool('notif_azkar_evening') ?? true) {
      await scheduleDailyAzkar(
        id: 502,
        title: 'أذكار المساء يا $userName',
        body: 'أمسينا وأمسى الملك لله — موعد أذكار المساء الآن',
        hour: prefs.getInt('notif_evening_hour') ?? 17,
        minute: prefs.getInt('notif_evening_min') ?? 30,
      );
    }

    if (prefs.getBool('notif_azkar_sleep') ?? true) {
      await scheduleDailyAzkar(
        id: 503,
        title: 'أذكار النوم يا $userName',
        body: 'اختم يومك بأذكار النوم وسورة الملك',
        hour: prefs.getInt('notif_sleep_hour') ?? 22,
        minute: prefs.getInt('notif_sleep_min') ?? 30,
      );
    }

    if (prefs.getBool('notif_quran_wird') ?? true) {
      await scheduleDailyAzkar(
        id: 504,
        title: 'وِردك القرآني اليومي يا $userName',
        body: 'لا تهجر القرآن اليوم — تابع تقدمك في الختمة',
        hour: prefs.getInt('notif_wird_hour') ?? 20,
        minute: prefs.getInt('notif_wird_min') ?? 0,
      );
    }

    if (prefs.getBool('notif_hijri_events') ?? true) {
      final hijriOffset = prefs.getInt('hijri_day_offset') ?? 0;
      final todayH = HijriCalendar.fromDate(now.add(Duration(days: hijriOffset)));
      final eventsList = [
        (1, 1, 'رأس السنة الهجرية'),
        (1, 9, 'تاسوعاء وعاشوراء غداً (يُستحب صيامه)'),
        (1, 10, 'يوم عاشوراء المبارك'),
        (8, 15, 'ليلة النصف من شعبان'),
        (9, 1, 'بداية شهر رمضان المبارك'),
        (9, 21, 'بداية العشر الأواخر من رمضان'),
        (10, 1, 'عيد الفطر المبارك'),
        (12, 8, 'يوم التروية وغداً يوم عرفة'),
        (12, 9, 'يوم عرفة المبارك (صيامه يكفّر سنتين)'),
        (12, 10, 'عيد الأضحى المبارك'),
      ];

      int eventId = 700;
      for (final ev in eventsList) {
        int targetYear = todayH.hYear;
        if (ev.$1 < todayH.hMonth || (ev.$1 == todayH.hMonth && ev.$2 < todayH.hDay)) {
          targetYear++;
        }
        final gDate = HijriCalendar().hijriToGregorian(targetYear, ev.$1, ev.$2);
        final notifyAt = DateTime(gDate.year, gDate.month, gDate.day, 8, 0)
            .subtract(Duration(days: hijriOffset));
        if (notifyAt.isAfter(now) && notifyAt.difference(now).inDays <= 60) {
          await _scheduleExact(
            id: eventId++,
            title: 'مناسبة إسلامية: ${ev.$3}',
            body: 'تذكير من تقويم الثعلب الهجري يا $userName — اغتنم فضل اليوم.',
            scheduledTime: notifyAt,
            channelId: 'rafiq_events_channel_v2',
            channelName: 'المناسبات الهجرية - رفيق',
          );
        }
      }
    }
  }

  Future<void> _scheduleExact({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String channelId,
    required String channelName,
  }) async {
    if (!_initialized || scheduledTime.isBefore(DateTime.now())) return;
    try {
      final tz.TZDateTime tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local);

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'تنبيهات واحة رفيق الإيمانية',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      );

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Schedule notification error: $e');
    }
  }

  Future<void> scheduleDailyAzkar({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (!_initialized) return;
    try {
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      tz.TZDateTime scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'rafiq_azkar_channel_v2',
        'الأذكار اليومية - رفيق',
        channelDescription: 'تذكير بأذكار الصباح والمساء والورد',
        importance: Importance.high,
        priority: Priority.high,
      );

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Schedule azkar error: $e');
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
