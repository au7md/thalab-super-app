import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class RafiqNotificationsService {
  RafiqNotificationsService._();
  static final RafiqNotificationsService instance = RafiqNotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

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
    } catch (e) {
      debugPrint('Permission request error: $e');
    }
  }

  Future<void> schedulePrayerNotification({
    required int id,
    required String prayerName,
    required DateTime scheduledTime,
  }) async {
    if (!_initialized || scheduledTime.isBefore(DateTime.now())) return;
    try {
      final tz.TZDateTime tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local);

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'rafiq_prayers_channel',
        'مواقيت الصلاة - رفيق',
        channelDescription: 'تنبيهات الأذان ومواقيت الصلوات الخمس',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      );

      await _plugin.zonedSchedule(
        id,
        'حان الآن موعد صلاة $prayerName',
        'أقم صلاتك تنعم بحياتك — واحة رفيق الإيمانية',
        tzScheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Schedule prayer error: $e');
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
        'rafiq_azkar_channel',
        'الأذكار اليومية - رفيق',
        channelDescription: 'تذكير بأذكار الصباح والمساء',
        importance: Importance.high,
        priority: Priority.defaultPriority,
      );

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
