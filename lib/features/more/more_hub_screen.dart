// lib/features/more/more_hub_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme.dart';
import 'pro_tools_screens.dart';

class MoreHubScreen extends StatefulWidget {
  const MoreHubScreen({super.key});

  @override
  State<MoreHubScreen> createState() => _MoreHubScreenState();
}

class _MoreHubScreenState extends State<MoreHubScreen> {
  static const MethodChannel _channel =
      MethodChannel('com.au7md.thalab_app/audio_studio');

  int _sadaqahDuaCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDuaCount();
  }

  Future<void> _loadDuaCount() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _sadaqahDuaCount = prefs.getInt('sadaqah_dua_count') ?? 0);
    }
  }

  Future<void> _incrementDua() async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    setState(() => _sadaqahDuaCount++);
    await prefs.setInt('sadaqah_dua_count', _sadaqahDuaCount);
  }

  Future<void> _openUrl(String url) async {
    try {
      await _channel.invokeMethod('openExternalUrl', {'url': url});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الرابط على هذا الجهاز')),
        );
      }
    }
  }

  void _openDeveloperSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThalabTheme.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ThalabTheme.softBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ThalabTheme.foxOrange.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.code_rounded, color: Colors.white, size: 38),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'أحمد محمد أحمد',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                const Text(
                  'أحمد تعلب  •  @au7md',
                  style: TextStyle(
                    color: ThalabTheme.foxOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 16),

                // بطاقة الصدقة الجارية
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ThalabTheme.cardSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ThalabTheme.softBorder),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.volunteer_activism_rounded,
                              color: ThalabTheme.foxOrange, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'صدقة جارية ودعوة بظهر الغيب',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'اللهم اغفر لي ولوالديّ وللمسلمين أجمعين، واجعل هذا العمل خالصاً لوجهك الكريم ونافعاً لكل من يستخدمه.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: ThalabTheme.mutedSlate, fontSize: 12.5, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThalabTheme.foxOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          await _incrementDua();
                          setSheetState(() {});
                        },
                        icon: const Icon(Icons.favorite_rounded, size: 18),
                        label: Text('آمين • دعوة صادقة ($_sadaqahDuaCount)'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'التواصل المباشر مع المطور:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SocialActionChip(
                      label: 'واتساب',
                      icon: Icons.chat_rounded,
                      color: const Color(0xFF25D366),
                      onTap: () => _openUrl('https://wa.me/201124539443'),
                    ),
                    _SocialActionChip(
                      label: 'فيسبوك',
                      icon: Icons.facebook_rounded,
                      color: const Color(0xFF1877F2),
                      onTap: () => _openUrl('https://www.facebook.com/au7md'),
                    ),
                    _SocialActionChip(
                      label: 'انستقرام',
                      icon: Icons.camera_alt_rounded,
                      color: const Color(0xFFE4405F),
                      onTap: () => _openUrl('https://www.instagram.com/au7md'),
                    ),
                    _SocialActionChip(
                      label: 'تليجرام',
                      icon: Icons.send_rounded,
                      color: const Color(0xFF0088CC),
                      onTap: () => _openUrl('https://t.me/au7md'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز الأدوات والمزيد'),
        actions: [
          IconButton(
            tooltip: 'عن المطور',
            icon: const Icon(Icons.person_pin_rounded, color: ThalabTheme.foxOrange),
            onPressed: _openDeveloperSheet,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          // بطاقة المطور المختصرة في الأعلى
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: _openDeveloperSheet,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: ThalabTheme.foxOrange.withOpacity(0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.volunteer_activism_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تطوير: أحمد تعلب (au7md)',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'صدقة جارية • اضغط للتواصل والدعاء بظهر الغيب',
                          style: TextStyle(color: Colors.white70, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          const _SectionHeader(title: 'الإنتاجية والتركيز (Pro)', icon: Icons.bolt_rounded),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              _ToolGridCard(
                title: 'مؤقت بومودورو',
                subtitle: 'تركيز 25د • راحة 5د',
                icon: Icons.timer_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _PomodoroProScreen()),
                ),
              ),
              _ToolGridCard(
                title: 'خزنة الملاحظات',
                subtitle: 'تدوين سريع ومشاركة',
                icon: Icons.note_alt_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _QuickNotesVaultScreen()),
                ),
              ),
              _ToolGridCard(
                title: 'متتبع العادات',
                subtitle: 'إنجازك اليومي',
                icon: Icons.checklist_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _HabitTrackerScreen()),
                ),
              ),
              _ToolGridCard(
                title: 'مشاركة التطبيق',
                subtitle: 'انشر الخير مع غيرك',
                icon: Icons.share_rounded,
                onTap: () => Share.share(
                  'تطبيق الثعلب المتكامل — أوقات الصلاة، القرآن، الاستوديو، والأدوات الذكية.\nتطوير: أحمد تعلب (@au7md)',
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),
          const _SectionHeader(
              title: 'الأدوات الذكية والحاسبات', icon: Icons.calculate_rounded),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              _ToolGridCard(
                title: 'حاسبة الزكاة',
                subtitle: 'حساب النصاب والزكاة',
                icon: Icons.mosque_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ZakatCalculatorScreen()),
                ),
              ),
              _ToolGridCard(
                title: 'محول الوحدات',
                subtitle: 'طول، وزن، مساحة، حرارة',
                icon: Icons.swap_horiz_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UnitConverterScreen()),
                ),
              ),
              _ToolGridCard(
                title: 'حاسبة العمر',
                subtitle: 'بالسنة والشهر واليوم',
                icon: Icons.cake_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AgeCalculatorScreen()),
                ),
              ),
              _ToolGridCard(
                title: 'مولد كلمات المرور',
                subtitle: 'تشفير وأمان عالي',
                icon: Icons.password_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PasswordGeneratorScreen()),
                ),
              ),
              _ToolGridCard(
                title: 'محلل النصوص',
                subtitle: 'كلمات، أحرف، وقت قراءة',
                icon: Icons.text_fields_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TextAnalyzerScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// 1. مؤقت بومودورو الاحترافي
// =========================================================================
class _PomodoroProScreen extends StatefulWidget {
  const _PomodoroProScreen();

  @override
  State<_PomodoroProScreen> createState() => _PomodoroProScreenState();
}

class _PomodoroProScreenState extends State<_PomodoroProScreen> {
  static const int _workSec = 25 * 60;
  static const int _breakSec = 5 * 60;

  bool _isWorkMode = true;
  int _secondsLeft = _workSec;
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

  void _toggleTimer() {
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
          setState(() => _isRunning = false);
          if (_isWorkMode) {
            final prefs = await SharedPreferences.getInstance();
            setState(() => _completedToday++);
            await prefs.setInt('pomodoro_count', _completedToday);
          }
          _switchMode(!_isWorkMode);
        }
      });
    }
  }

  void _switchMode(bool work) {
    _timer?.cancel();
    setState(() {
      _isWorkMode = work;
      _isRunning = false;
      _secondsLeft = work ? _workSec : _breakSec;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _isWorkMode ? _workSec : _breakSec;
    final progress = 1.0 - (_secondsLeft / total);
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(title: const Text('مؤقت بومودورو للتركيز')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('جلسة عمل (25 د)'),
                  selected: _isWorkMode,
                  selectedColor: ThalabTheme.foxOrange,
                  labelStyle: TextStyle(
                      color: _isWorkMode ? Colors.white : ThalabTheme.darkSlate,
                      fontWeight: FontWeight.bold),
                  onSelected: (_) => _switchMode(true),
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('استراحة (5 د)'),
                  selected: !_isWorkMode,
                  selectedColor: Colors.teal,
                  labelStyle: TextStyle(
                      color: !_isWorkMode ? Colors.white : ThalabTheme.darkSlate,
                      fontWeight: FontWeight.bold),
                  onSelected: (_) => _switchMode(false),
                ),
              ],
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 230,
              height: 230,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 12,
                      backgroundColor: ThalabTheme.softBorder,
                      color: _isWorkMode ? ThalabTheme.foxOrange : Colors.teal,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$m:$s',
                          style: const TextStyle(
                              fontSize: 48, fontWeight: FontWeight.w900)),
                      Text(
                        _isWorkMode ? 'وقت التركيز' : 'وقت الراحة',
                        style: const TextStyle(
                            color: ThalabTheme.mutedSlate, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 34),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 32,
                  icon: const Icon(Icons.refresh_rounded, color: ThalabTheme.mutedSlate),
                  onPressed: () => _switchMode(_isWorkMode),
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isWorkMode ? ThalabTheme.foxOrange : Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: _toggleTimer,
                  icon: Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  label: Text(_isRunning ? 'إيقاف مؤقت' : 'ابدأ الآن',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: ThalabTheme.cardSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: ThalabTheme.softBorder),
              ),
              child: Text(
                'الجلسات المكتملة: $_completedToday جلسة',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// 2. خزنة الملاحظات السريعة
// =========================================================================
class _QuickNotesVaultScreen extends StatefulWidget {
  const _QuickNotesVaultScreen();

  @override
  State<_QuickNotesVaultScreen> createState() => _QuickNotesVaultScreenState();
}

class _QuickNotesVaultScreenState extends State<_QuickNotesVaultScreen> {
  List<String> _notes = [];
  final TextEditingController _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _notes = prefs.getStringList('thalab_quick_notes') ?? []);
    }
  }

  Future<void> _addNote() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notes.insert(0, text);
      _ctrl.clear();
    });
    await prefs.setStringList('thalab_quick_notes', _notes);
  }

  Future<void> _deleteNote(int idx) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _notes.removeAt(idx));
    await prefs.setStringList('thalab_quick_notes', _notes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('خزنة الملاحظات السريعة')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: InputDecoration(
                      hintText: 'اكتب ملاحظة أو فكرة سريعة...',
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
                  onPressed: _addNote,
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: _notes.isEmpty
                ? const Center(
                    child: Text('لا توجد ملاحظات محفوظة بعد',
                        style: TextStyle(color: ThalabTheme.mutedSlate)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _notes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ThalabTheme.cardSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ThalabTheme.softBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(_notes[i])),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded,
                                size: 19, color: ThalabTheme.foxOrange),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _notes[i]));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم النسخ ✓')),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 19, color: Colors.redAccent),
                            onPressed: () => _deleteNote(i),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// 3. متتبع العادات اليومية
// =========================================================================
class _HabitTrackerScreen extends StatefulWidget {
  const _HabitTrackerScreen();

  @override
  State<_HabitTrackerScreen> createState() => _HabitTrackerScreenState();
}

class _HabitTrackerScreenState extends State<_HabitTrackerScreen> {
  List<Map<String, dynamic>> _habits = [];
  final TextEditingController _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('thalab_habits_json');
    if (raw != null && raw.isNotEmpty) {
      setState(() =>
          _habits = List<Map<String, dynamic>>.from(jsonDecode(raw)));
    } else {
      _habits = [
        {'title': 'أذكار الصباح والمساء', 'done': false},
        {'title': 'قراءة ورد القرآن', 'done': false},
        {'title': 'شرب 2 لتر ماء', 'done': false},
      ];
    }
  }

  Future<void> _saveHabits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('thalab_habits_json', jsonEncode(_habits));
  }

  @override
  Widget build(BuildContext context) {
    final doneCount = _habits.where((h) => h['done'] == true).length;
    return Scaffold(
      appBar: AppBar(title: Text('متتبع العادات ($doneCount/${_habits.length})')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: InputDecoration(
                      hintText: 'أضف عادة يومية جديدة...',
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
                    final t = _ctrl.text.trim();
                    if (t.isNotEmpty) {
                      setState(() {
                        _habits.add({'title': t, 'done': false});
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
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: _habits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final item = _habits[i];
                final done = item['done'] == true;
                return Container(
                  decoration: BoxDecoration(
                    color: ThalabTheme.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: done ? ThalabTheme.foxOrange : ThalabTheme.softBorder,
                    ),
                  ),
                  child: CheckboxListTile(
                    activeColor: ThalabTheme.foxOrange,
                    value: done,
                    title: Text(
                      item['title'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    secondary: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.redAccent, size: 20),
                      onPressed: () {
                        setState(() => _habits.removeAt(i));
                        _saveHabits();
                      },
                    ),
                    onChanged: (v) {
                      setState(() => _habits[i]['done'] = v ?? false);
                      _saveHabits();
                    },
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: ThalabTheme.foxOrange, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ToolGridCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ToolGridCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ThalabTheme.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ThalabTheme.softBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThalabTheme.foxOrange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: ThalabTheme.foxOrange, size: 22),
            ),
            const Spacer(),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ThalabTheme.mutedSlate, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _SocialActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SocialActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
