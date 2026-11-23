import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import 'productivity_pro_screens.dart';

class StudentHubScreen extends StatefulWidget {
  const StudentHubScreen({super.key});

  @override
  State<StudentHubScreen> createState() => _StudentHubScreenState();
}

class _StudentHubScreenState extends State<StudentHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ركن الطلاب المتكامل'),
        actions: [
          IconButton(
            tooltip: 'مؤقت المذاكرة (بومودورو)',
            icon: const Icon(Icons.timer_rounded, color: ThalabTheme.foxOrange),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PomodoroProScreen()),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: ThalabTheme.foxOrange,
          unselectedLabelColor: ThalabTheme.mutedSlate,
          indicatorColor: ThalabTheme.foxOrange,
          tabs: const [
            Tab(icon: Icon(Icons.track_changes_rounded), text: 'الأهداف والمواد'),
            Tab(icon: Icon(Icons.calendar_view_week_rounded), text: 'جدول المذاكرة'),
            Tab(icon: Icon(Icons.calculate_rounded), text: 'حاسبة GPA'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _StudyGoalsTab(),
          _StudyScheduleTab(),
          _GpaCalculatorTab(),
        ],
      ),
    );
  }
}

// =========================================================================
// 1. تبويب الأهداف والمواد الدراسية
// =========================================================================
class _StudyGoalsTab extends StatefulWidget {
  const _StudyGoalsTab();

  @override
  State<_StudyGoalsTab> createState() => _StudyGoalsTabState();
}

class _StudyGoalsTabState extends State<_StudyGoalsTab> {
  List> _subjects = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('student_subjects_json');
    if (raw != null && raw.isNotEmpty) {
      setState(() => _subjects = List>.from(jsonDecode(raw)));
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('student_subjects_json', jsonEncode(_subjects));
  }

  void _addSubjectDialog() {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مادة / هدف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'اسم المادة'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: targetCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الساعات المستهدفة'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThalabTheme.foxOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final target = int.tryParse(targetCtrl.text.trim()) ?? 10;
              if (name.isNotEmpty) {
                setState(() {
                  _subjects.add({
                    'name': name,
                    'target': target.clamp(1, 200),
                    'done': 0,
                  });
                });
                _save();
                Navigator.pop(ctx);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ThalabTheme.foxOrange,
        foregroundColor: Colors.white,
        onPressed: _addSubjectDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة مادة'),
      ),
      body: _subjects.isEmpty
          ? const Center(
              child: Text(
                'أضف موادك الدراسية وحدد ساعات المذاكرة المستهدفة',
                style: TextStyle(color: ThalabTheme.mutedSlate),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: _subjects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final sub = _subjects[i];
                final target = (sub['target'] as int).clamp(1, 200);
                final done = (sub['done'] as int).clamp(0, target);
                final pct = done / target;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ThalabTheme.cardSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ThalabTheme.softBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(sub['name'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.redAccent, size: 20),
                            onPressed: () {
                              setState(() => _subjects.removeAt(i));
                              _save();
                            },
                          ),
                        ],
                      ),
                      LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                        backgroundColor: ThalabTheme.softBorder,
                        color: ThalabTheme.foxOrange,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('تم إنجاز $done من $target ساعة',
                              style: const TextStyle(
                                  color: ThalabTheme.mutedSlate, fontSize: 12)),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline_rounded,
                                    color: ThalabTheme.mutedSlate),
                                onPressed: () {
                                  if (done > 0) {
                                    setState(() => _subjects[i]['done'] = done - 1);
                                    _save();
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_rounded,
                                    color: ThalabTheme.foxOrange),
                                onPressed: () {
                                  if (done < target) {
                                    setState(() => _subjects[i]['done'] = done + 1);
                                    _save();
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// =========================================================================
// 2. تبويب جدول المذاكرة الأسبوعي
// =========================================================================
class _StudyScheduleTab extends StatefulWidget {
  const _StudyScheduleTab();

  @override
  State<_StudyScheduleTab> createState() => _StudyScheduleTabState();
}

class _StudyScheduleTabState extends State<_StudyScheduleTab> {
  final List<String> _days = [
    'السبت',
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
  ];
  String _selectedDay = 'السبت';
  Map<String, List<String>> _schedule = {};
  final TextEditingController _taskCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('student_schedule_json');
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _schedule = decoded.map(
          (k, v) => MapEntry(k, List<String>.from(v as List)),
        );
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('student_schedule_json', jsonEncode(_schedule));
  }

  @override
  Widget build(BuildContext context) {
    final dayTasks = _schedule[_selectedDay] ?? [];

    return Column(
      children: [
        SizedBox(
          height: 54,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: _days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final d = _days[i];
              final active = d == _selectedDay;
              return ChoiceChip(
                label: Text(d),
                selected: active,
                selectedColor: ThalabTheme.foxOrange,
                labelStyle: TextStyle(
                  color: active ? Colors.white : ThalabTheme.darkSlate,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (_) => setState(() => _selectedDay = d),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _taskCtrl,
                  decoration: InputDecoration(
                    hintText: 'أضف حصة أو مهمة ليوم $_selectedDay...',
                    filled: true,
                    fillColor: ThalabTheme.cardSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: ThalabTheme.softBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: ThalabTheme.foxOrange),
                onPressed: () {
                  final t = _taskCtrl.text.trim();
                  if (t.isEmpty) return;
                  setState(() {
                    _schedule.putIfAbsent(_selectedDay, () => []);
                    _schedule[_selectedDay]!.add(t);
                    _taskCtrl.clear();
                  });
                  _save();
                },
                icon: const Icon(Icons.add_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
        Expanded(
          child: dayTasks.isEmpty
              ? Center(
                  child: Text('لا توجد مهام مجدولة ليوم $_selectedDay',
                      style: const TextStyle(color: ThalabTheme.mutedSlate)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: dayTasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: ThalabTheme.cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ThalabTheme.softBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.menu_book_rounded,
                            color: ThalabTheme.foxOrange, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(dayTasks[i],
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.redAccent, size: 20),
                          onPressed: () {
                            setState(() => _schedule[_selectedDay]!.removeAt(i));
                            _save();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// =========================================================================
// 3. تبويب حاسبة المعدل التراكمي (GPA)
// =========================================================================
class _GpaCalculatorTab extends StatefulWidget {
  const _GpaCalculatorTab();

  @override
  State<_GpaCalculatorTab> createState() => _GpaCalculatorTabState();
}

class _GpaCalculatorTabState extends State<_GpaCalculatorTab> {
  final List> _courses = [
    {'name': 'مادة 1', 'credits': 3, 'grade': 4.0},
    {'name': 'مادة 2', 'credits': 3, 'grade': 3.7},
  ];

  static const Map<String, double> _gradeScale = {
    'A+ (4.0)': 4.0,
    'A (3.7)': 3.7,
    'B+ (3.3)': 3.3,
    'B (3.0)': 3.0,
    'C+ (2.7)': 2.7,
    'C (2.3)': 2.3,
    'D (2.0)': 2.0,
    'F (0.0)': 0.0,
  };

  double get _gpa {
    double totalPoints = 0;
    int totalCredits = 0;
    for (final c in _courses) {
      final cr = c['credits'] as int;
      final gr = c['grade'] as double;
      totalPoints += cr * gr;
      totalCredits += cr;
    }
    return totalCredits == 0 ? 0.0 : totalPoints / totalCredits;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const Text('المعدل التراكمي المتوقع (GPA)',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 6),
              Text(
                _gpa.toStringAsFixed(2),
                style: const TextStyle(
                    color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(_courses.length, (i) {
          final c = _courses[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ThalabTheme.cardSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ThalabTheme.softBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('مادة ${i + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                DropdownButton<int>(
                  value: c['credits'] as int,
                  items: [1, 2, 3, 4]
                      .map((cr) =>
                          DropdownMenuItem(value: cr, child: Text('$cr س')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _courses[i]['credits'] = v);
                  },
                ),
                const SizedBox(width: 10),
                DropdownButton<double>(
                  value: c['grade'] as double,
                  items: _gradeScale.entries
                      .map((e) =>
                          DropdownMenuItem(value: e.value, child: Text(e.key)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _courses[i]['grade'] = v);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent, size: 20),
                  onPressed: () => setState(() => _courses.removeAt(i)),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: ThalabTheme.foxOrange,
            side: const BorderSide(color: ThalabTheme.foxOrange),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () => setState(
            () => _courses.add({
              'name': 'مادة ${_courses.length + 1}',
              'credits': 3,
              'grade': 4.0,
            }),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة مادة جديدة',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
