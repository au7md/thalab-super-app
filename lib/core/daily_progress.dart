import 'package:clock/clock.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// تجميع تقدّم المستخدم اليومي من كل أقسام التطبيق في مكان واحد.
/// كل الدوال هنا نقية وقابلة للاختبار: لا قنوات منصة ولا إشعارات.
class DailyProgress {
  const DailyProgress({
    required this.adhkarCompleted,
    required this.tasbihToday,
    required this.khatmahPages,
    required this.habitsDone,
    required this.habitsTotal,
    required this.pomodorosToday,
  });

  final int adhkarCompleted;
  final int tasbihToday;
  final int khatmahPages;
  final int habitsDone;
  final int habitsTotal;
  final int pomodorosToday;

  /// عدد الأقسام التي أنجز فيها المستخدم شيئاً اليوم (لشارة التحفيز).
  int get activeSections {
    var n = 0;
    if (adhkarCompleted > 0) n++;
    if (tasbihToday > 0) n++;
    if (khatmahPages > 0) n++;
    if (habitsDone > 0) n++;
    if (pomodorosToday > 0) n++;
    return n;
  }

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// يقرأ عدّاداً مرتبطاً بتاريخ؛ يعيد صفراً لو التاريخ ليس اليوم.
  static int dailyInt(
    SharedPreferences prefs,
    String valueKey,
    String dateKeyName,
    DateTime today,
  ) {
    final saved = prefs.getString(dateKeyName);
    if (saved != dateKey(today)) return 0;
    return prefs.getInt(valueKey) ?? 0;
  }

  /// يحلل عادات اليوم من مخزن العادات مع دعم الصيغتين:
  /// القديمة (بدون تاريخ، تُعامل كأنها لم تُنجز اليوم) والجديدة (مع تاريخ).
  static ({int done, int total}) parseHabits(String? rawJson, DateTime today) {
    if (rawJson == null || rawJson.isEmpty) return (done: 0, total: 0);
    try {
      final list = List<Map<String, dynamic>>.from(jsonDecode(rawJson));
      final todayKey = dateKey(today);
      var done = 0;
      for (final h in list) {
        final doneDate = h['done_date'] as String?;
        // الصيغة القديمة: done=true بلا تاريخ — لا تُحسب إنجاز اليوم.
        if (doneDate == todayKey) done++;
      }
      return (done: done, total: list.length);
    } catch (_) {
      return (done: 0, total: 0);
    }
  }

  static Future<DailyProgress> load(
    SharedPreferences prefs, {
    DateTime? now,
  }) async {
    final today = now ?? clock.now();
    final habits = parseHabits(prefs.getString('thalab_habits_v2_json'), today);
    return DailyProgress(
      adhkarCompleted:
          dailyInt(prefs, 'adhkar_completed_today', 'adhkar_progress_date', today),
      tasbihToday:
          dailyInt(prefs, 'tasbih_daily_count', 'tasbih_daily_date', today),
      khatmahPages: prefs.getInt('khatmah_pages_read') ?? 0,
      habitsDone: habits.done,
      habitsTotal: habits.total,
      pomodorosToday:
          dailyInt(prefs, 'pomodoro_count', 'pomodoro_count_date', today),
    );
  }
}
