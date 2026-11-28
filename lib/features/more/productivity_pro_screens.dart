import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/haptics.dart';
import '../../core/ui_kit.dart';
import '../../core/fox_mascot.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../rafiq/adhkar_screen.dart';
import '../rafiq/quran_screen.dart';

// =========================================================================
// 1. مؤقت بومودورو المطور (جلسات متعددة + استراحة مخصصة + تصميم هادئ)
// =========================================================================
class PomodoroProScreen extends StatefulWidget {
  const PomodoroProScreen({super.key});

  @override
  State<PomodoroProScreen> createState() => _PomodoroProScreenState();
}

class _PomodoroProScreenState extends State<PomodoroProScreen> {
  final List<int> _workPresets = [25, 45, 60];
  final List<int> _breakPresets = [5, 10, 15];

  int _selectedWorkMin = 25;
  int _selectedBreakMin = 5;
  bool _isWorkMode = true;
  int _secondsLeft = 25 * 60;
  bool _isRunning = false;
  int _completedToday = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _completedToday = prefs.getInt('pomodoro_count') ?? 0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _selectWorkMinutes(int min) {
    _timer?.cancel();
    setState(() {
      _selectedWorkMin = min;
      _isWorkMode = true;
      _isRunning = false;
      _secondsLeft = min * 60;
    });
  }

  void _selectBreakMinutes(int min) {
    _timer?.cancel();
    setState(() {
      _selectedBreakMin = min;
      _isWorkMode = false;
      _isRunning = false;
      _secondsLeft = min * 60;
    });
  }

  void _toggleTimer() {
    Haptics.lightImpact();
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      setState(() => _isRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
        if (_secondsLeft > 0) {
          setState(() => _secondsLeft--);
        } else {
          t.cancel();
          Haptics.heavyImpact();
          setState(() => _isRunning = false);
          if (_isWorkMode) {
            final prefs = await SharedPreferences.getInstance();
            setState(() => _completedToday++);
            await prefs.setInt('pomodoro_count', _completedToday);
            _selectBreakMinutes(_selectedBreakMin);
          } else {
            _selectWorkMinutes(_selectedWorkMin);
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = (_isWorkMode ? _selectedWorkMin : _selectedBreakMin) * 60;
    final progress = total > 0 ? (1.0 - (_secondsLeft / total)).clamp(0.0, 1.0) : 0.0;
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    final activeColor = _isWorkMode ? ThalabTheme.foxOrange : const Color(0xFF0D9488);

    return Scaffold(
      appBar: AppBar(title: const Text('واحة التركيز (بومودورو)')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        children: [
          // بطاقة اختيار جلسة العمل والاستراحة
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('جلسات العمل (دقيقة)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: _workPresets.map((min) {
                    final selected = _isWorkMode && _selectedWorkMin == min;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Center(child: Text('$min د')),
                          selected: selected,
                          selectedColor: ThalabTheme.foxOrange,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => _selectWorkMinutes(min),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text('مدة الاستراحة (دقيقة)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: _breakPresets.map((min) {
                    final selected = !_isWorkMode && _selectedBreakMin == min;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Center(child: Text('$min د')),
                          selected: selected,
                          selectedColor: const Color(0xFF0D9488),
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => _selectBreakMinutes(min),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // حلقة المؤقت الهادئة
          Center(
            child: Container(
              width: 246,
              height: 246,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withOpacity(0.14),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 222,
                    height: 222,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 11,
                      backgroundColor: Theme.of(context).dividerColor,
                      color: activeColor,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: activeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _isWorkMode ? 'تركيز عميق' : 'استراحة هادئة',
                          style: TextStyle(
                            color: activeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$m:$s',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // أزرار التحكم
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 30,
                tooltip: 'إعادة ضبط',
                icon: const Icon(Icons.refresh_rounded, color: ThalabTheme.mutedSlate),
                onPressed: () => _isWorkMode
                    ? _selectWorkMinutes(_selectedWorkMin)
                    : _selectBreakMinutes(_selectedBreakMin),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22)),
                ),
                onPressed: _toggleTimer,
                icon: Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
                label: Text(
                  _isRunning ? 'إيقاف مؤقت' : 'ابدأ الجلسة',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // إحصائية الجلسات
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded,
                        color: ThalabTheme.foxOrange),
                    SizedBox(width: 8),
                    Text('الجلسات المكتملة',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Text(
                  '$_completedToday جلسة',
                  style: const TextStyle(
                      color: ThalabTheme.foxOrange,
                      fontWeight: FontWeight.w900,
                      fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// 2. خزنة الملاحظات السرية (قفل PIN + خيار البصمة + قلم أسفل اليسار)
// =========================================================================
class SecureNotesVaultScreen extends StatefulWidget {
  const SecureNotesVaultScreen({super.key});

  @override
  State<SecureNotesVaultScreen> createState() => _SecureNotesVaultScreenState();
}

class _SecureNotesVaultScreenState extends State<SecureNotesVaultScreen> {
  bool _isUnlocked = false;
  String? _savedPin;
  bool _biometricEnabled = false;
  String _enteredPin = '';
  List<Map<String, dynamic>> _notes = [];

  @override
  void initState() {
    super.initState();
    _initVault();
  }

  Future<void> _initVault() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString('vault_pin_code');
    final bio = prefs.getBool('vault_biometric_enabled') ?? false;
    final rawNotes = prefs.getString('thalab_vault_notes_json');
    List<Map<String, dynamic>> loaded = [];
    if (rawNotes != null && rawNotes.isNotEmpty) {
      loaded = List<Map<String, dynamic>>.from(jsonDecode(rawNotes));
    }
    if (mounted) {
      setState(() {
        _savedPin = pin;
        _biometricEnabled = bio;
        _notes = loaded;
      });
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('thalab_vault_notes_json', jsonEncode(_notes));
  }

  void _onDigitTap(String digit) async {
    Haptics.selectionClick();
    if (_enteredPin.length >= 4) return;
    setState(() => _enteredPin += digit);

    if (_enteredPin.length == 4) {
      if (_savedPin == null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('vault_pin_code', _enteredPin);
        setState(() {
          _savedPin = _enteredPin;
          _isUnlocked = true;
          _enteredPin = '';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تعيين الرقم السري للخزنة بنجاح ✓')),
          );
        }
      } else if (_enteredPin == _savedPin) {
        setState(() {
          _isUnlocked = true;
          _enteredPin = '';
        });
      } else {
        Haptics.heavyImpact();
        setState(() => _enteredPin = '');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الرقم السري غير صحيح، حاول مجدداً')),
          );
        }
      }
    }
  }

  void _openWriteNoteSheet() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ملاحظة سرية جديدة',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                hintText: 'عنوان الملاحظة...',
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bodyCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'اكتب تفاصيل ملاحظتك هنا...',
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThalabTheme.foxOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  final t = titleCtrl.text.trim();
                  final b = bodyCtrl.text.trim();
                  if (t.isEmpty && b.isEmpty) return;
                  final now = DateTime.now();
                  setState(() {
                    _notes.insert(0, {
                      'title': t.isEmpty ? 'ملاحظة سريعة' : t,
                      'body': b,
                      'date': '${now.year}/${now.month}/${now.day}',
                    });
                  });
                  _saveNotes();
                  Navigator.pop(ctx);
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('حفظ في الخزنة',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUnlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('خزنة الملاحظات السرية')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded,
                  size: 54, color: ThalabTheme.foxOrange),
              const SizedBox(height: 14),
              Text(
                _savedPin == null
                    ? 'أنشئ رقماً سرياً (4 أرقام) لحماية ملاحظاتك'
                    : 'أدخل الرقم السري لفتح الخزنة',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _enteredPin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? ThalabTheme.foxOrange : Colors.transparent,
                      border: Border.all(color: ThalabTheme.foxOrange, width: 2),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 16,
                childAspectRatio: 1.45,
                children: [
                  ...List.generate(9, (i) => '${i + 1}').map((d) {
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).cardColor,
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: () => _onDigitTap(d),
                      child: Text(d,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                    );
                  }),
                  if (_biometricEnabled && _savedPin != null)
                    IconButton(
                      icon: const Icon(Icons.fingerprint_rounded,
                          size: 34, color: ThalabTheme.foxOrange),
                      onPressed: () {
                        Haptics.mediumImpact();
                        setState(() => _isUnlocked = true);
                      },
                    )
                  else
                    const SizedBox.shrink(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).cardColor,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () => _onDigitTap('0'),
                    child: const Text('0',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.backspace_outlined,
                        color: ThalabTheme.mutedSlate),
                    onPressed: () {
                      if (_enteredPin.isNotEmpty) {
                        setState(() => _enteredPin =
                            _enteredPin.substring(0, _enteredPin.length - 1));
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('خزنة الملاحظات'),
        actions: [
          IconButton(
            tooltip: _biometricEnabled ? 'تعطيل البصمة' : 'تفعيل البصمة',
            icon: Icon(
              Icons.fingerprint_rounded,
              color: _biometricEnabled
                  ? ThalabTheme.foxOrange
                  : ThalabTheme.mutedSlate,
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              setState(() => _biometricEnabled = !_biometricEnabled);
              await prefs.setBool('vault_biometric_enabled', _biometricEnabled);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_biometricEnabled
                        ? 'تم تفعيل الفتح بالبصمة ✓'
                        : 'تم إيقاف الفتح بالبصمة'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _notes.isEmpty
              ? const FoxEmptyState(
                  mood: FoxMood.sleepy,
                  title: 'الخزنة فارغة 🔒',
                  subtitle: 'اضغط على القلم بالأسفل لإضافة أول ملاحظة سرية.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: _notes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final n = _notes[i];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(n['title'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 15)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  setState(() => _notes.removeAt(i));
                                  _saveNotes();
                                },
                              ),
                            ],
                          ),
                          if ((n['body'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(n['body'],
                                style: const TextStyle(
                                    color: ThalabTheme.mutedSlate, height: 1.4)),
                          ],
                          const SizedBox(height: 8),
                          Text(n['date'] ?? '',
                              style: const TextStyle(
                                  fontSize: 11, color: ThalabTheme.foxOrange)),
                        ],
                      ),
                    );
                  },
                ),
          // أيقونة القلم أسفل اليسار
          Positioned(
            left: 20,
            bottom: 24,
            child: FloatingActionButton(
              backgroundColor: ThalabTheme.foxOrange,
              foregroundColor: Colors.white,
              onPressed: _openWriteNoteSheet,
              child: const Icon(Icons.edit_rounded, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// 3. متتبع العادات المتكامل (مربوط بمهام التطبيق مباشرة)
// =========================================================================
class IntegratedHabitScreen extends StatefulWidget {
  const IntegratedHabitScreen({super.key});

  @override
  State<IntegratedHabitScreen> createState() => _IntegratedHabitScreenState();
}

class _IntegratedHabitScreenState extends State<IntegratedHabitScreen> {
  List<Map<String, dynamic>> _habits = [];
  final TextEditingController _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('thalab_habits_v2_json');
    if (raw != null && raw.isNotEmpty) {
      setState(() =>
          _habits = List<Map<String, dynamic>>.from(jsonDecode(raw)));
    } else {
      setState(() {
        _habits = [
          {'title': 'أذكار الصباح والمساء', 'done': false, 'route': 'adhkar'},
          {'title': 'قراءة ورد القرآن اليومي', 'done': false, 'route': 'quran'},
          {'title': 'جلسة تركيز بومودورو', 'done': false, 'route': 'pomodoro'},
        ];
      });
    }
  }

  Future<void> _saveHabits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('thalab_habits_v2_json', jsonEncode(_habits));
  }

  void _openLinkedTask(String? route) {
    if (route == 'adhkar') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdhkarScreen()));
    } else if (route == 'quran') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranScreen()));
    } else if (route == 'pomodoro') {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const PomodoroProScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final doneCount = _habits.where((h) => h['done'] == true).length;
    final pct = _habits.isEmpty ? 0.0 : doneCount / _habits.length;

    return Scaffold(
      appBar: AppBar(title: const Text('متتبع العادات والمهام')),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('إنجاز اليوم',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('$doneCount من ${_habits.length}',
                        style: const TextStyle(
                            color: ThalabTheme.foxOrange, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                  backgroundColor: Theme.of(context).dividerColor,
                  color: ThalabTheme.foxOrange,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: InputDecoration(
                      hintText: 'أضف عادة جديدة...',
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: ThalabTheme.foxOrange),
                  onPressed: () {
                    final t = _ctrl.text.trim();
                    if (t.isNotEmpty) {
                      setState(() {
                        _habits.add({'title': t, 'done': false, 'route': null});
                        _ctrl.clear();
                      });
                      _saveHabits();
                    }
                  },
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: _habits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final item = _habits[i];
                final done = item['done'] == true;
                final route = item['route'] as String?;
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: done ? ThalabTheme.foxOrange : Theme.of(context).dividerColor,
                    ),
                  ),
                  child: ListTile(
                    leading: Checkbox(
                      activeColor: ThalabTheme.foxOrange,
                      value: done,
                      onChanged: (v) {
                        setState(() => _habits[i]['done'] = v ?? false);
                        _saveHabits();
                      },
                    ),
                    title: Text(
                      item['title'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (route != null)
                          TextButton(
                            onPressed: () => _openLinkedTask(route),
                            child: const Text('انتقل',
                                style: TextStyle(
                                    color: ThalabTheme.foxOrange,
                                    fontWeight: FontWeight.bold)),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.redAccent, size: 20),
                          onPressed: () {
                            setState(() => _habits.removeAt(i));
                            _saveHabits();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
