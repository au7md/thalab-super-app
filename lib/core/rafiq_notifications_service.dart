import 'dart:math';
import 'package:adhan/adhan.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:quran/quran.dart' as quran;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'storage_service.dart';

class RafiqNotificationsService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationDetails _channelDetails =
      AndroidNotificationDetails(
    'rafiq_smart_reminders',
    'تذكيرات رفيق الإيمانية',
    channelDescription: 'إشعارات الأذكار، الختمة، الصيام، النوافل، ومتابعة الصلوات',
    importance: Importance.high,
    priority: Priority.high,
  );

  static Future<void> syncAllScheduledNotifications({
    required double lat,
    required double lng,
    required CalculationParameters params,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _plugin.cancelAll();

    // 1. إشعارات الأذكار (الصباح، المساء، وحصن المسلم)
    if (prefs.getBool('notif_adhkar') ?? true) {
      await StorageService.scheduleDailyReminder(
        id: 201,
        title: 'أذكار الصباح ☀️',
        body: '«أصبحنا وأصبح الملك لله» — حصّن يومك بذكر الله.',
        hour: 6,
        minute: 15,
      );
      await StorageService.scheduleDailyReminder(
        id: 202,
        title: 'أذكار المساء 🌙',
        body: 'حان موعد أذكار المساء وطمأنينة القلب.',
        hour: 17,
        minute: 15,
      );
      await StorageService.scheduleDailyReminder(
        id: 203,
        title: 'ذكر من حصن المسلم 📿',
        body: 'اللهم إني أسألك علماً نافعاً، ورزقاً طيباً، وعملاً متقبلاً.',
        hour: 13,
        minute: 30,
      );
    }

    // 2. إشعار تذكير الختمة اليومي
    if (prefs.getBool('notif_khatmah') ?? true) {
      final readPages = prefs.getInt('khatmah_pages_read') ?? 0;
      await StorageService.scheduleDailyReminder(
        id: 204,
        title: 'وِردك القرآني اليومي 📖',
        body: 'أنجزت حتى الآن $readPages من 604 صفحة، تابع وردك الآن.',
        hour: 20,
        minute: 30,
      );
    }

    // 3. إشعار آية متجددة يومياً
    if (prefs.getBool('notif_ayah') ?? true) {
      final rnd = Random();
      final surah = rnd.nextInt(114) + 1;
      final verse = rnd.nextInt(quran.getVerseCount(surah)) + 1;
      final ayahText = quran.getVerse(surah, verse);
      final surahName = quran.getSurahNameArabic(surah);
      await StorageService.scheduleDailyReminder(
        id: 205,
        title: 'آية وتدبر • سورة $surahName',
        body: '﴿$ayahText﴾',
        hour: 11,
        minute: 0,
      );
    }

    // 4. إشعارات النوافل والسنن (الضحى + الوتر وقيام الليل)
    if (prefs.getBool('notif_nawafil') ?? true) {
      await StorageService.scheduleDailyReminder(
        id: 206,
        title: 'صلاة الضحى (صلاة الأوابين) ✨',
        body: 'ركعتان تجزئان عن ثلاثمائة وستين صدقة على مفاصلك.',
        hour: 9,
        minute: 30,
      );
      await StorageService.scheduleDailyReminder(
        id: 207,
        title: 'ركعة الوتر وقيام الليل 🌌',
        body: 'اختم يومك بركعة وتر تناجي فيها ربك.',
        hour: 22,
        minute: 30,
      );
    }

    // 5. إشعارات الصيام (الاثنين والخميس + تذكير الأيام البيض)
    if (prefs.getBool('notif_fasting') ?? true) {
      await _scheduleWeeklyFasting(
        id: 208,
        weekday: DateTime.sunday,
        title: 'تذكير صيام غداً الاثنين 🌙',
        body: 'تُعرض الأعمال يوم الاثنين والخميس، انوِ الصيام إن استطعت.',
      );
      await _scheduleWeeklyFasting(
        id: 209,
        weekday: DateTime.wednesday,
        title: 'تذكير صيام غداً الخميس 🌙',
        body: 'صيام يوم في سبيل الله يباعد وجهك عن النار سبعين خريفاً.',
      );
    }

    // 6. إشعار المتابعة دبر كل صلاة (بعد 25 دقيقة من كل أذان)
    if (prefs.getBool('notif_post_prayer') ?? true) {
      final prayers = PrayerTimes(
        Coordinates(lat, lng),
        DateComponents.from(DateTime.now()),
        params,
      );
      final list = [
        (211, 'الفجر', prayers.fajr),
        (212, 'الظهر', prayers.dhuhr),
        (213, 'العصر', prayers.asr),
        (214, 'المغرب', prayers.maghrib),
        (215, 'العشاء', prayers.isha),
      ];

      for (final item in list) {
        final followUpTime = item.$3.add(const Duration(minutes: 25));
        if (followUpTime.isAfter(DateTime.now())) {
          await _plugin.zonedSchedule(
            item.$1,
            'متابعة صلاة ${item.$2} 🕌',
            'هل أتممت صلاة ${item.$2} وسنتها وأذكار ما بعد الصلاة؟',
            tz.TZDateTime.from(followUpTime, tz.local),
            const NotificationDetails(android: _channelDetails),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        }
      }
    }
  }

  static Future<void> _scheduleWeeklyFasting({
    required int id,
    required int weekday,
    required String title,
    required String body,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 0);
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      const NotificationDetails(android: _channelDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }
}
