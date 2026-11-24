import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thalab_app/core/daily_progress.dart';

void main() {
  final today = DateTime(2026, 11, 25, 12, 0);
  const todayKey = '2026-11-25';

  test('dateKey pads month and day', () {
    expect(DailyProgress.dateKey(DateTime(2026, 1, 2)), '2026-01-02');
  });

  test('dailyInt returns value only when stored date is today', () async {
    SharedPreferences.setMockInitialValues({
      'adhkar_completed_today': 7,
      'adhkar_progress_date': todayKey,
      'tasbih_daily_count': 33,
      'tasbih_daily_date': '2026-11-24', // أمس
    });
    final prefs = await SharedPreferences.getInstance();
    expect(DailyProgress.dailyInt(prefs, 'adhkar_completed_today',
        'adhkar_progress_date', today), 7);
    expect(
        DailyProgress.dailyInt(
            prefs, 'tasbih_daily_count', 'tasbih_daily_date', today),
        0);
    expect(
        DailyProgress.dailyInt(
            prefs, 'missing', 'missing_date', today),
        0);
  });

  test('parseHabits counts only habits stamped with today', () {
    final raw = jsonEncode([
      {'title': 'أذكار', 'done': true, 'done_date': todayKey},
      {'title': 'قرآن', 'done': true, 'done_date': '2026-11-24'},
      {'title': 'بومودورو', 'done': false},
      {'title': 'قديم بلا تاريخ', 'done': true},
    ]);
    final r = DailyProgress.parseHabits(raw, today);
    expect(r.done, 1);
    expect(r.total, 4);
  });

  test('parseHabits handles null, empty and corrupt json', () {
    expect(DailyProgress.parseHabits(null, today).total, 0);
    expect(DailyProgress.parseHabits('', today).total, 0);
    expect(DailyProgress.parseHabits('{broken', today).total, 0);
  });

  test('load aggregates all sections and counts active ones', () async {
    SharedPreferences.setMockInitialValues({
      'adhkar_completed_today': 5,
      'adhkar_progress_date': todayKey,
      'tasbih_daily_count': 100,
      'tasbih_daily_date': todayKey,
      'khatmah_pages_read': 42,
      'pomodoro_count': 3,
      'pomodoro_count_date': '2026-11-24',
      'thalab_habits_v2_json': jsonEncode([
        {'title': 'أذكار', 'done': true, 'done_date': todayKey},
        {'title': 'قرآن', 'done': false},
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final p = await DailyProgress.load(prefs, now: today);
    expect(p.adhkarCompleted, 5);
    expect(p.tasbihToday, 100);
    expect(p.khatmahPages, 42);
    expect(p.habitsDone, 1);
    expect(p.habitsTotal, 2);
    expect(p.pomodorosToday, 0);
    expect(p.activeSections, 4); // أذكار + تسبيح + ختمة + عادات
  });
}
