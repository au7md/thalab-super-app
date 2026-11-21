import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class StorageService {
  static late SharedPreferences _prefs;
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(initSettings);
  }

  // --- بيانات السبحة ---
  static int getTotalTasbih() => _prefs.getInt('total_tasbih') ?? 0;
  static Future<void> setTotalTasbih(int val) => _prefs.setInt('total_tasbih', val);

  static int getCurrentTasbih() => _prefs.getInt('current_tasbih') ?? 0;
  static Future<void> setCurrentTasbih(int val) => _prefs.setInt('current_tasbih', val);

  static String getSelectedDhikr() =>
      _prefs.getString('selected_dhikr') ?? 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ';
  static Future<void> setSelectedDhikr(String val) =>
      _prefs.setString('selected_dhikr', val);

  // --- بيانات المصحف ---
  static int getLastSurah() => _prefs.getInt('last_surah') ?? 1;
  static Future<void> setLastSurah(int surahNumber) =>
      _prefs.setInt('last_surah', surahNumber);

  // --- تفعيل إشعار تذكير بالأذكار ---
  static Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'thalab_rafiq_channel',
          'تنبيهات رفيق الدينية',
          channelDescription: 'تذكير بأذكار الصباح والمساء والورد اليومي',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
