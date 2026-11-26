import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:adhan/adhan.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'prayer_calc.dart';

class MuezzinOption {
  final String id;
  final String name;
  final String description;

  const MuezzinOption(this.id, this.name, this.description);
}

class RafiqNotificationsService {
  RafiqNotificationsService._();
  static final RafiqNotificationsService instance = RafiqNotificationsService._();

  /// القناة مع نظام الأذان الأصلي (AdhanSystem.kt).
  static const MethodChannel _adhanChannel =
      MethodChannel('com.au7md.thalab_app/adhan');
  static const int _nativeIdBase = 20000;

  /// يسجّل آخر خطأ في الجدولة (كان يُبتلع بصمت في نسخة release).
  Future<void> _logError(String where, Object e) async {
    debugPrint('Notifications [$where]: $e');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'notif_last_error', '[${DateTime.now().toIso8601String()}] $where: $e');
    } catch (_) {}
  }

  Future<String> lastError() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('notif_last_error') ?? '';
  }

  Future<void> clearLastError() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notif_last_error');
  }

  /// عدد الأيام التي تُجدوَل مسبقاً لمواقيت الصلاة.
  static const int _daysAhead = 14;

  /// اللاحقة تُغيَّر عند تعديل إعدادات القنوات، لأن أندرويد يثبّت صوت القناة
  /// وأهميتها عند أول إنشاء ولا يحدّثها لاحقاً.
  static const String _cv = 'v3';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// طابور لمنع تداخل عمليات المزامنة (cancelAll + schedule) المتزامنة.
  Future<void> _queue = Future<void>.value();

  static const List<MuezzinOption> fajrMuezzins = [
    MuezzinOption('fajr_egypt', 'أذان الفجر — مصر', 'نبرة الفجر المصرية الأصيلة'),
    MuezzinOption('fajr_kuwait', 'أذان الفجر — الكويت', 'أذان الفجر الكويتي الهادئ'),
    MuezzinOption('default', 'تنبيه النظام الافتراضي', 'نغمة إشعار قياسية'),
  ];

  static const List<MuezzinOption> generalMuezzins = [
    MuezzinOption('mishary_afasy', 'الشيخ مشاري العفاسي', 'أذان هادئ وعذب'),
    MuezzinOption('nasser_qatami', 'الشيخ ناصر القطامي', 'نبرة خاشعة ومميزة'),
    MuezzinOption('haram', 'أذان الحرم المكي', 'روحانية المسجد الحرام'),
    MuezzinOption('abdul_basit', 'الشيخ عبد الباسط عبد الصمد', 'الأذان الكلاسيكي الأصيل'),
    MuezzinOption('mustafa_ismail', 'الشيخ مصطفى إسماعيل', 'مقامات مصرية عريقة'),
    MuezzinOption('hamad_daghreeri', 'الشيخ حمد الدغريري', 'أداء ندي ومؤثر'),
    MuezzinOption('hamza_majali', 'الشيخ حمزة المجالي', 'صوت جهوري خاشع'),
    MuezzinOption('nour_maghribi', 'الشيخ نور الدين المغربي', 'أداء مغربي متميز'),
    MuezzinOption('default', 'تنبيه النظام الافتراضي', 'نغمة إشعار قياسية'),
  ];

  // ---------------------------------------------------------------------------
  // التهيئة والأذونات
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();
      await _configureLocalTimeZone();

      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      );
      await _plugin.initialize(initSettings);

      // إذن الإشعارات فقط (أندرويد 13+). إذن الأذان الدقيق يُطلب من الواجهة
      // عند الحاجة، وليس عند كل تشغيل للتطبيق.
      _initialized = true;
    } catch (e) {
      debugPrint('RafiqNotificationsService init error: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// هل يسمح النظام بالتنبيهات الدقيقة؟ إذا لا، ستُجدوَل الأذانات بتوقيت تقريبي
  /// وقد تتأخر دقائق — يجب إبلاغ المستخدم بذلك.
  Future<bool> canScheduleExactAlarms() async {
    try {
      return (await _android?.canScheduleExactNotifications()) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// يفتح شاشة إعداد "المنبهات والتذكيرات" في النظام.
  Future<void> requestExactAlarmPermission() async {
    await _android?.requestExactAlarmsPermission();
  }

  /// يُستدعى من الواجهة بعد أول إطار (وليس من main) لأن طلب الإذن يحتاج Activity.
  /// يعيد true إذا كان الإشعار مسموحاً، ويعيد جدولة كل شيء عند المنح.
  Future<bool> requestPermissionsFromUi() async {
    await init();
    final granted = (await _android?.requestNotificationsPermission()) ?? false;
    if (granted) await resyncFromSavedLocation();
    return granted;
  }

  /// هل الإشعارات مسموحة فعلاً على مستوى النظام؟
  Future<bool> notificationsEnabled() async {
    try {
      return (await _android?.areNotificationsEnabled()) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// إعادة الجدولة باستخدام الموقع المحفوظ (يُستعمل بعد منح الإذن).
  Future<void> resyncFromSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('saved_lat') ?? 30.0444;
    final lng = prefs.getDouble('saved_lng') ?? 31.2357;
    await syncAllScheduledNotifications(
      lat: lat,
      lng: lng,
      params: prayerParamsFor(lat, lng),
    );
  }

  Future<void> _configureLocalTimeZone() async {
    try {
      // اسم المنطقة الحقيقي (IANA) — يحترم التوقيت الصيفي تلقائياً.
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      debugPrint('Timezone detection failed, falling back by offset: $e');
      _fallbackTimeZoneByOffset();
    }
  }

  void _fallbackTimeZoneByOffset() {
    final offset = DateTime.now().timeZoneOffset;
    if (offset.inHours == 2) {
      tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
    } else if (offset.inHours == 3) {
      tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
    } else {
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<String> _getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name')?.trim() ?? '';
    return name.isEmpty ? 'صديقي' : name;
  }

  // ---------------------------------------------------------------------------
  // القنوات (Channels) — الصوت وخصائص الصوت تُحدَّد هنا وليس في كل إشعار
  // ---------------------------------------------------------------------------

  Future<void> _ensureChannel({
    required String id,
    required String name,
    String? description,
    String? rawSound,
    bool alarmUsage = false,
    Importance importance = Importance.max,
  }) async {
    final channel = AndroidNotificationChannel(
      id,
      name,
      description: description,
      importance: importance,
      playSound: true,
      sound: rawSound == null ? null : RawResourceAndroidNotificationSound(rawSound),
      audioAttributesUsage:
          alarmUsage ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
      enableVibration: true,
    );
    await _android?.createNotificationChannel(channel);
  }

  // ---------------------------------------------------------------------------
  // الجدولة الأساسية
  // ---------------------------------------------------------------------------

  /// يجدول إشعاراً واحداً (لمرة واحدة) أو متكرراً يومياً إذا مُرِّر [repeat].
  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required String channelId,
    required String channelName,
    String? channelDescription,
    String? rawSound,
    bool isAdhan = false,
    DateTimeComponents? repeat,
  }) async {
    if (!_initialized) return;
    if (repeat == null && !when.isAfter(tz.TZDateTime.now(tz.local))) return;

    try {
      await _ensureChannel(
        id: channelId,
        name: channelName,
        description: channelDescription,
        rawSound: rawSound,
        alarmUsage: isAdhan,
      );

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          sound: rawSound == null ? null : RawResourceAndroidNotificationSound(rawSound),
          audioAttributesUsage:
              isAdhan ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      );

      final mode = (await canScheduleExactAlarms())
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: repeat,
      );
    } catch (e) {
      await _logError('schedule id=$id', e);
    }
  }

  tz.TZDateTime _toTz(DateTime d) => tz.TZDateTime.from(d, tz.local);

  // ---------------------------------------------------------------------------
  // الاختبارات
  // ---------------------------------------------------------------------------

  Future<void> sendTestNotification() async {
    await init();
    final userName = await _getUserName();
    await _ensureChannel(
      id: 'rafiq_prayers_$_cv',
      name: 'تنبيهات رفيق الإيمانية',
      description: 'تنبيهات الأذان والأذكار والمناسبات',
    );
    await _plugin.show(
      999,
      'رفيق — الواحة الإيمانية',
      'أهلاً يا $userName، منظومة الإشعارات الدقيقة تعمل الآن بنجاح.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'rafiq_prayers_$_cv',
          'تنبيهات رفيق الإيمانية',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> sendTestScheduledAdhan({int delaySeconds = 5, String? muezzinId}) async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final userName = await _getUserName();
    final muezzin = muezzinId ?? prefs.getString('prayer_muezzin_dhuhr') ?? 'mishary_afasy';
    final follow = prefs.getBool('adhan_follow_ringer') ?? true;
    try {
      await _adhanChannel.invokeMethod('scheduleTest', {
        'delaySeconds': delaySeconds,
        'title': 'تجربة الأذان المجدول',
        'body': 'أهلاً يا $userName، الأذان يعمل بنظام الثعلب الجديد.',
        'muezzin': muezzin == 'default' ? '' : muezzin,
        'followRinger': follow,
      });
    } catch (e) {
      await _logError('scheduleTest', e);
    }
  }

  /// اختبار جدولة المكتبة (flutter_local_notifications) بشكل منفصل لعزل المشكلة.
  Future<void> sendTestPluginScheduled({int delaySeconds = 10}) async {
    await init();
    final userName = await _getUserName();
    await _schedule(
      id: 997,
      title: 'اختبار الإشعار المجدول',
      body: 'أهلاً يا $userName، جدولة المكتبة تعمل.',
      when: _toTz(DateTime.now().add(Duration(seconds: delaySeconds))),
      channelId: 'rafiq_prayers_$_cv',
      channelName: 'تنبيهات رفيق الإيمانية',
    );
  }

  // ---------------------------------------------------------------------------
  // نظام الأذان الأصلي + التشخيص
  // ---------------------------------------------------------------------------

  Future<void> _nativeCancelAll() async {
    try {
      await _adhanChannel.invokeMethod('cancelAll');
    } catch (e) {
      await _logError('native cancelAll', e);
    }
  }

  Future<void> _nativeSchedule(List<Map<String, Object>> entries) async {
    try {
      await _adhanChannel.invokeMethod('schedule', {'entries': entries});
    } catch (e) {
      await _logError('native schedule', e);
    }
  }

  /// يستدعي أمراً أصلياً ويعيد نجاحه (فتح إعدادات، تشغيل، إيقاف...).
  Future<bool> nativeAction(String method, [Map<String, Object?>? args]) async {
    try {
      final r = await _adhanChannel.invokeMethod<bool>(method, args);
      return r ?? false;
    } catch (e) {
      await _logError('native $method', e);
      return false;
    }
  }

  Future<Map<String, dynamic>> diagnostics() async {
    final ids = <String>{
      ...fajrMuezzins.map((m) => m.id),
      ...generalMuezzins.map((m) => m.id),
    }..remove('default');

    Map<String, dynamic> native = {};
    String nativeError = '';
    try {
      final r = await _adhanChannel.invokeMapMethod<String, dynamic>(
        'diagnostics',
        {'muezzinIds': ids.toList()},
      );
      native = r ?? {};
    } catch (e) {
      nativeError = '$e';
    }

    int pending = -1;
    try {
      pending = await pendingCount();
    } catch (e) {
      await _logError('pendingCount', e);
    }

    return {
      ...native,
      'nativeError': nativeError,
      'pluginNotificationsEnabled': await notificationsEnabled(),
      'pluginExactAllowed': await canScheduleExactAlarms(),
      'pluginPending': pending,
      'lastError': await lastError(),
    };
  }

  // ---------------------------------------------------------------------------
  // المزامنة الكاملة — تُستدعى من الواجهة، وتُنفَّذ بالتسلسل عبر الطابور
  // ---------------------------------------------------------------------------

  Future<void> syncAllScheduledNotifications({
    required double lat,
    required double lng,
    required CalculationParameters params,
  }) {
    _queue = _queue
        .then((_) => _doSync(lat, lng, params))
        .catchError((Object e) => debugPrint('Sync error: $e'));
    return _queue;
  }

  Future<void> _doSync(double lat, double lng, CalculationParameters params) async {
    await init();
    if (!_initialized) return;

    // نلغي ما سبق ثم نُعيد الجدولة كاملة بالإعدادات الحالية.
    await _plugin.cancelAll();
    await _nativeCancelAll();

    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notif_master_enabled') ?? true)) return;

    final userName = await _getUserName();
    final coords = Coordinates(lat, lng);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ---- مواقيت الصلاة لعدة أيام ----
    int idCounter = 100;
    final nativeEntries = <Map<String, Object>>[];
    int nativeId = _nativeIdBase;
    final followRinger = prefs.getBool('adhan_follow_ringer') ?? true;
    for (int dayOffset = 0; dayOffset < _daysAhead; dayOffset++) {
      final date = today.add(Duration(days: dayOffset));
      final pt = PrayerTimes(coords, DateComponents.from(date), params);

      final prayers = <(String, String, DateTime)>[
        ('fajr', 'الفجر', pt.fajr),
        ('dhuhr', 'الظهر', pt.dhuhr),
        ('asr', 'العصر', pt.asr),
        ('maghrib', 'المغرب', pt.maghrib),
        ('isha', 'العشاء', pt.isha),
      ];

      for (final p in prayers) {
        final key = p.$1;
        final name = p.$2;
        final adhanAt = _toTz(p.$3);

        final adhanEnabled = prefs.getBool('prayer_notif_${key}_adhan') ?? true;
        final beforeMins = prefs.getInt('prayer_notif_${key}_before') ?? 0;
        final afterMins = prefs.getInt('prayer_notif_${key}_after') ?? 0;

        final defaultMuezzin = key == 'fajr' ? 'fajr_egypt' : 'mishary_afasy';
        final muezzinId = prefs.getString('prayer_muezzin_$key') ?? defaultMuezzin;
        final muezzinList = key == 'fajr' ? fajrMuezzins : generalMuezzins;
        final muezzinName = muezzinList
            .firstWhere((m) => m.id == muezzinId, orElse: () => muezzinList.first)
            .name;

        if (beforeMins > 0) {
          await _schedule(
            id: idCounter++,
            title: 'اقتربت صلاة $name يا $userName',
            body: 'متبقي $beforeMins دقيقة على أذان $name — استعد للوضوء والصلاة.',
            when: _toTz(adhanAt.subtract(Duration(minutes: beforeMins))),
            channelId: 'rafiq_prayers_$_cv',
            channelName: 'مواقيت الصلاة - رفيق',
          );
        }

        if (adhanEnabled) {
          final fajrNote = key == 'fajr' ? ' • الصلاة خير من النوم' : '';
          if (adhanAt.isAfter(tz.TZDateTime.now(tz.local))) {
            nativeEntries.add({
              'id': nativeId++,
              'whenMs': adhanAt.millisecondsSinceEpoch,
              'title': 'حان الآن موعد أذان $name$fajrNote',
              'body': 'أقم صلاتك يا $userName ($muezzinName)',
              'muezzin': muezzinId == 'default' ? '' : muezzinId,
              'followRinger': followRinger,
            });
          }
        }

        if (afterMins > 0) {
          await _schedule(
            id: idCounter++,
            title: 'أذكار ما بعد صلاة $name',
            body: 'تقبل الله طاعتك يا $userName — لا تنسَ أذكار دُبُر الصلاة.',
            when: _toTz(adhanAt.add(Duration(minutes: afterMins))),
            channelId: 'rafiq_prayers_$_cv',
            channelName: 'مواقيت الصلاة - رفيق',
          );
        }
      }
    }

    // الأذان يُجدوَل عبر النظام الأصلي (يحترم وضع الصامت)
    await _nativeSchedule(nativeEntries);

    // ---- التذكيرات اليومية (تتكرر كل يوم عبر matchDateTimeComponents) ----
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

    // ---- المناسبات الهجرية ----
    if (prefs.getBool('notif_hijri_events') ?? true) {
      final hijriOffset = prefs.getInt('hijri_day_offset') ?? 0;
      final todayH = HijriCalendar.fromDate(now.add(Duration(days: hijriOffset)));

      // (شهر، يوم، الاسم، عدد أيام التذكير المسبق)
      // مثال: تاسوعاء في 9 محرم، يُذكَّر قبلها بيوم لأن نصّ الإشعار يقول "غداً".
      final events = <(int, int, String, int)>[
        (1, 1, 'رأس السنة الهجرية', 0),
        (1, 9, 'تاسوعاء وعاشوراء', 1),
        (1, 10, 'يوم عاشوراء المبارك', 0),
        (8, 15, 'ليلة النصف من شعبان', 0),
        (9, 1, 'بداية شهر رمضان المبارك', 0),
        (9, 21, 'بداية العشر الأواخر من رمضان', 0),
        (10, 1, 'عيد الفطر المبارك', 0),
        (12, 8, 'يوم التروية', 0),
        (12, 9, 'يوم عرفة المبارك (صيامه يكفّر سنتين)', 0),
        (12, 10, 'عيد الأضحى المبارك', 0),
      ];

      int eventId = 700;
      for (final ev in events) {
        final month = ev.$1;
        final day = ev.$2;
        final label = ev.$3;
        final daysBefore = ev.$4;

        int targetYear = todayH.hYear;
        if (month < todayH.hMonth || (month == todayH.hMonth && day < todayH.hDay)) {
          targetYear++;
        }
        final gDate = HijriCalendar().hijriToGregorian(targetYear, month, day);
        final notifyAt = DateTime(gDate.year, gDate.month, gDate.day, 8)
            .subtract(Duration(days: hijriOffset + daysBefore));

        if (notifyAt.isAfter(now) && notifyAt.difference(now).inDays <= 60) {
          final timing = daysBefore > 0 ? 'تبدأ المناسبة غداً' : 'اغتنم فضل اليوم';
          await _schedule(
            id: eventId++,
            title: 'مناسبة إسلامية: $label',
            body: 'تذكير من تقويم الثعلب الهجري يا $userName — $timing.',
            when: _toTz(notifyAt),
            channelId: 'rafiq_events_$_cv',
            channelName: 'المناسبات الهجرية - رفيق',
          );
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // تذكير يومي متكرر — الإصلاح الأهم: matchDateTimeComponents يجعله يتكرر
  // ---------------------------------------------------------------------------

  Future<void> scheduleDailyAzkar({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (!_initialized) return;
    final now = tz.TZDateTime.now(tz.local);
    var first = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (first.isBefore(now)) {
      first = first.add(const Duration(days: 1));
    }

    await _schedule(
      id: id,
      title: title,
      body: body,
      when: first,
      channelId: 'rafiq_azkar_$_cv',
      channelName: 'الأذكار اليومية - رفيق',
      channelDescription: 'تذكير بأذكار الصباح والمساء والورد',
      repeat: DateTimeComponents.time,
    );
  }

  // ---------------------------------------------------------------------------
  // أدوات مساعدة
  // ---------------------------------------------------------------------------

  Future<int> pendingCount() async {
    final list = await _plugin.pendingNotificationRequests();
    return list.length;
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
