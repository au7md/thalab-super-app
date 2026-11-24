import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/daily_progress.dart';

class _TasbihPhraseItem {
  final String text;
  final int target;

  const _TasbihPhraseItem({required this.text, required this.target});
}

class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen>
    with SingleTickerProviderStateMixin {
  int _tasbihCount = 0;
  int _tasbihTarget = 33;
  int _completedRounds = 0;
  int _totalLifetimeTasbih = 0;
  int _selectedPhraseIndex = 0;
  int _selectedStyleIndex = 0;
  bool _vibrationEnabled = true;

  late AnimationController _beadAnimController;
  final List<_TasbihPhraseItem> _customPhrases = [];

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardBg => Theme.of(context).cardColor;
  Color get _innerBg => Theme.of(context).scaffoldBackgroundColor;
  Color get _borderColor => _isDark ? ThalabTheme.darkBorder : ThalabTheme.softBorder;
  Color get _textColor => _isDark ? ThalabTheme.darkTextPrimary : ThalabTheme.darkSlate;

  static const List<_TasbihPhraseItem> _defaultPhrases = [
    _TasbihPhraseItem(text: 'سُبْحَانَ اللَّهِ', target: 33),
    _TasbihPhraseItem(text: 'الْحَمْدُ لِلَّهِ', target: 33),
    _TasbihPhraseItem(text: 'اللَّهُ أَكْبَرُ', target: 34),
    _TasbihPhraseItem(text: 'أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ وَأَتُوبُ إِلَيْهِ', target: 100),
    _TasbihPhraseItem(text: 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ', target: 100),
    _TasbihPhraseItem(text: 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ', target: 100),
    _TasbihPhraseItem(text: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ', target: 100),
    _TasbihPhraseItem(text: 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ', target: 100),
  ];

  static const List<int> _presetTargets = [33, 34, 99, 100, 500, 1000];

  List<_TasbihPhraseItem> get _allPhrases => [
        ..._defaultPhrases,
        ..._customPhrases,
      ];

  @override
  void initState() {
    super.initState();
    _beadAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _loadTasbihData();
  }

  @override
  void dispose() {
    _beadAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadTasbihData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCustom = prefs.getStringList('tasbih_custom_phrases') ?? [];
    final List<_TasbihPhraseItem> parsedCustom = [];
    for (final item in savedCustom) {
      final sep = item.lastIndexOf('::');
      if (sep > 0) {
        final txt = item.substring(0, sep);
        final tgt = int.tryParse(item.substring(sep + 2)) ?? 33;
        parsedCustom.add(_TasbihPhraseItem(text: txt, target: tgt));
      }
    }

    setState(() {
      _customPhrases
        ..clear()
        ..addAll(parsedCustom);
      _selectedStyleIndex = prefs.getInt('tasbih_style_idx') ?? 0;
      _vibrationEnabled = prefs.getBool('tasbih_vibration') ?? true;
      _selectedPhraseIndex = (prefs.getInt('tasbih_phrase_idx') ?? 0)
          .clamp(0, _allPhrases.length - 1);
      final target = prefs.getInt('tasbih_custom_target') ??
          _allPhrases[_selectedPhraseIndex].target;
      _tasbihTarget = target > 0 ? target : 33;

      final savedCurrent = prefs.getInt('tasbih_current') ?? 0;
      _tasbihCount = savedCurrent >= _tasbihTarget ? 0 : savedCurrent;
      _completedRounds = prefs.getInt('tasbih_rounds') ?? 0;
      _totalLifetimeTasbih = prefs.getInt('tasbih_lifetime') ?? 0;
    });
  }

  Future<void> _incrementTasbih() async {
    _beadAnimController.forward(from: 0.0);
    if (_vibrationEnabled) {
      HapticFeedback.lightImpact();
    }

    final prefs = await SharedPreferences.getInstance();
    bool roundJustCompleted = false;

    setState(() {
      _totalLifetimeTasbih++;
      if (_tasbihCount + 1 >= _tasbihTarget) {
        _tasbihCount = 0;
        _completedRounds++;
        roundJustCompleted = true;
      } else {
        _tasbihCount++;
      }
    });

    if (roundJustCompleted && _vibrationEnabled) {
      HapticFeedback.heavyImpact();
    }

    // عدّاد تسبيح اليوم (يُصفَّر تلقائياً بتغيّر التاريخ)
    final todayKey = DailyProgress.dateKey(DateTime.now());
    final savedDay = prefs.getString('tasbih_daily_date');
    final todaySoFar = savedDay == todayKey
        ? (prefs.getInt('tasbih_daily_count') ?? 0)
        : 0;
    await prefs.setString('tasbih_daily_date', todayKey);
    await prefs.setInt('tasbih_daily_count', todaySoFar + 1);

    await prefs.setInt('tasbih_current', _tasbihCount);
    await prefs.setInt('tasbih_rounds', _completedRounds);
    await prefs.setInt('tasbih_lifetime', _totalLifetimeTasbih);
  }

  Future<void> _resetTasbih() async {
    if (_vibrationEnabled) {
      HapticFeedback.mediumImpact();
    }
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tasbihCount = 0;
      _completedRounds = 0;
    });
    await prefs.setInt('tasbih_current', 0);
    await prefs.setInt('tasbih_rounds', 0);
  }

  Future<void> _applyNewTarget(int newTarget) async {
    if (newTarget <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tasbihTarget = newTarget;
      _tasbihCount = 0;
    });
    await prefs.setInt('tasbih_custom_target', newTarget);
    await prefs.setInt('tasbih_current', 0);
  }

  void _openAddCustomPhraseDialog() {
    final textController = TextEditingController();
    int selectedTarget = 33;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'إضافة ذِكر أو ورد خاص للسبحة',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'اكتب الذكر هنا (مثال: رَبِّ اغْفِرْ لِي وَتُبْ عَلَيَّ)...',
                  filled: true,
                  fillColor: _innerBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'الهدف المطلوب للحلقة:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _presetTargets.map((t) {
                  final active = selectedTarget == t;
                  return ChoiceChip(
                    label: Text('$t'),
                    selected: active,
                    selectedColor: ThalabTheme.foxOrange,
                    backgroundColor: _innerBg,
                    labelStyle: TextStyle(
                      color: active ? Colors.white : _textColor,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (_) => setSheetState(() => selectedTarget = t),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThalabTheme.foxOrange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () async {
                  final txt = textController.text.trim();
                  if (txt.isEmpty) return;
                  final prefs = await SharedPreferences.getInstance();
                  setState(() {
                    _customPhrases.add(_TasbihPhraseItem(text: txt, target: selectedTarget));
                    _selectedPhraseIndex = _allPhrases.length - 1;
                    _tasbihTarget = selectedTarget;
                    _tasbihCount = 0;
                    _completedRounds = 0;
                  });
                  final encoded = _customPhrases
                      .map((e) => '${e.text}::${e.target}')
                      .toList();
                  await prefs.setStringList('tasbih_custom_phrases', encoded);
                  await prefs.setInt('tasbih_phrase_idx', _selectedPhraseIndex);
                  await prefs.setInt('tasbih_custom_target', _tasbihTarget);
                  await prefs.setInt('tasbih_current', 0);
                  await prefs.setInt('tasbih_rounds', 0);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('حفظ وبدء التسبيح', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openTargetSelectorSheet() {
    final customTargetController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 26,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'تحديد عدد حبات الحلقة (الهدف)',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ThalabTheme.foxOrange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'الحالي: $_tasbihTarget',
                    style: const TextStyle(
                      color: ThalabTheme.foxOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _presetTargets.map((target) {
                final isSelected = _tasbihTarget == target;
                return ChoiceChip(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Text(
                      '$target تسبيحة',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : _textColor,
                      ),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: ThalabTheme.foxOrange,
                  backgroundColor: _innerBg,
                  onSelected: (_) async {
                    await _applyNewTarget(target);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: customTargetController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: 'أو اكتب هدفاً مخصصاً (مثل 70)...',
                      filled: true,
                      fillColor: _innerBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThalabTheme.foxOrange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(84, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final parsed = int.tryParse(customTargetController.text.trim());
                    if (parsed != null && parsed > 0) {
                      await _applyNewTarget(parsed);
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                  child: const Text('تطبيق', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phrases = _allPhrases;
    final currentPhrase = phrases[_selectedPhraseIndex].text;
    final progress = (_tasbihCount / _tasbihTarget).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('السبحة الإلكترونية'),
        actions: [
          IconButton(
            tooltip: _vibrationEnabled ? 'إيقاف الاهتزاز' : 'تفعيل الاهتزاز',
            icon: Icon(
              _vibrationEnabled ? Icons.vibration_rounded : Icons.smartphone_rounded,
              color: _vibrationEnabled ? ThalabTheme.foxOrange : ThalabTheme.mutedText(context),
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              setState(() => _vibrationEnabled = !_vibrationEnabled);
              await prefs.setBool('tasbih_vibration', _vibrationEnabled);
            },
          ),
          IconButton(
            tooltip: 'إضافة ذكر مخصص',
            icon: const Icon(Icons.add_circle_outline_rounded, color: ThalabTheme.foxOrange),
            onPressed: _openAddCustomPhraseDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: phrases.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final selected = _selectedPhraseIndex == idx;
                  return ChoiceChip(
                    label: Text(
                      phrases[idx].text,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: selected ? Colors.white : _textColor,
                      ),
                    ),
                    selected: selected,
                    selectedColor: ThalabTheme.foxOrange,
                    backgroundColor: _cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: selected ? ThalabTheme.foxOrange : _borderColor,
                      ),
                    ),
                    onSelected: (_) async {
                      final prefs = await SharedPreferences.getInstance();
                      final newTarget = phrases[idx].target;
                      setState(() {
                        _selectedPhraseIndex = idx;
                        _tasbihTarget = newTarget;
                        _tasbihCount = 0;
                        _completedRounds = 0;
                      });
                      await prefs.setInt('tasbih_phrase_idx', idx);
                      await prefs.setInt('tasbih_custom_target', newTarget);
                      await prefs.setInt('tasbih_current', 0);
                      await prefs.setInt('tasbih_rounds', 0);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _borderColor, width: 1.3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(_isDark ? 0.16 : 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    currentPhrase,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.amiri(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      height: 1.75,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatBadge(
                        label: 'الدورات',
                        value: '$_completedRounds',
                      ),
                      InkWell(
                        onTap: _openTargetSelectorSheet,
                        borderRadius: BorderRadius.circular(12),
                        child: _StatBadge(
                          label: 'الهدف (اضغط)',
                          value: '$_tasbihCount من $_tasbihTarget',
                          highlight: true,
                        ),
                      ),
                      _StatBadge(
                        label: 'الإجمالي العام',
                        value: '$_totalLifetimeTasbih',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StyleToggleBtn(
                      title: 'سبحة الخرز التفاعلية',
                      icon: Icons.blur_circular_rounded,
                      selected: _selectedStyleIndex == 0,
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        setState(() => _selectedStyleIndex = 0);
                        await prefs.setInt('tasbih_style_idx', 0);
                      },
                    ),
                  ),
                  Expanded(
                    child: _StyleToggleBtn(
                      title: 'خاتم التسبيح الرقمي',
                      icon: Icons.watch_rounded,
                      selected: _selectedStyleIndex == 1,
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        setState(() => _selectedStyleIndex = 1);
                        await prefs.setInt('tasbih_style_idx', 1);
                      },
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            if (_selectedStyleIndex == 0)
              _buildBeadedRosaryWidget(progress)
            else
              _buildDigitalRingCounterWidget(progress),

            const Spacer(),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ThalabTheme.foxOrange,
                    side: const BorderSide(color: ThalabTheme.foxOrange),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _resetTasbih,
                  icon: const Icon(Icons.refresh_rounded, size: 19),
                  label: const Text('تصفير العداد', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textColor,
                    side: BorderSide(color: _borderColor),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _openTargetSelectorSheet,
                  icon: const Icon(Icons.flag_rounded, size: 19, color: ThalabTheme.foxOrange),
                  label: Text('الهدف: $_tasbihTarget',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeadedRosaryWidget(double progress) {
    return GestureDetector(
      onTap: _incrementTasbih,
      child: AnimatedBuilder(
        animation: _beadAnimController,
        builder: (context, child) {
          final bounce = 1.0 - (math.sin(_beadAnimController.value * math.pi) * 0.045);
          return Transform.scale(
            scale: bounce,
            child: SizedBox(
              width: 268,
              height: 268,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(268, 268),
                    painter: _TasbihBeadsPainter(
                      totalBeads: 33,
                      activeCount: _tasbihCount,
                      animPhase: _beadAnimController.value,
                      primaryColor: ThalabTheme.foxOrange,
                      secondaryColor: const Color(0xFFD97724),
                    ),
                  ),
                  Container(
                    width: 178,
                    height: 178,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2B231D), Color(0xFF4A3728)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: const Color(0xFFD4AF37),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ThalabTheme.foxOrange.withOpacity(0.28),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_tasbihCount',
                          style: const TextStyle(
                            color: Color(0xFFFFE6B8),
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$_tasbihCount من $_tasbihTarget',
                            style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'المس للتسبيح',
                          style: TextStyle(color: Colors.white70, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDigitalRingCounterWidget(double progress) {
    return GestureDetector(
      onTap: _incrementTasbih,
      child: AnimatedBuilder(
        animation: _beadAnimController,
        builder: (context, _) {
          final pressScale = 1.0 - (math.sin(_beadAnimController.value * math.pi) * 0.04);
          return Transform.scale(
            scale: pressScale,
            child: Container(
              width: 235,
              height: 265,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1F242D), Color(0xFF323946)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(48),
                border: Border.all(color: ThalabTheme.foxOrange, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9EB398),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF5A6956), width: 2.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ROUND $_completedRounds',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E291C),
                              ),
                            ),
                            Text(
                              'TARGET $_tasbihTarget',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E291C),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _tasbihCount.toString().padLeft(4, '0'),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: Color(0xFF141E12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(ThalabTheme.foxOrange),
                    ),
                  ),

                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.white24, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: ThalabTheme.foxOrange.withOpacity(0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.fingerprint_rounded,
                      color: Colors.white,
                      size: 46,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _StatBadge({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? ThalabTheme.foxOrange.withOpacity(0.12)
            : Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10.5, color: ThalabTheme.mutedText(context)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: highlight
                  ? ThalabTheme.foxOrange
                  : (isDark ? ThalabTheme.darkTextPrimary : ThalabTheme.darkSlate),
            ),
          ),
        ],
      ),
    );
  }
}

class _StyleToggleBtn extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _StyleToggleBtn({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? ThalabTheme.foxOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : ThalabTheme.mutedText(context),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: selected
                      ? Colors.white
                      : (isDark ? ThalabTheme.darkTextPrimary : ThalabTheme.darkSlate),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TasbihBeadsPainter extends CustomPainter {
  final int totalBeads;
  final int activeCount;
  final double animPhase;
  final Color primaryColor;
  final Color secondaryColor;

  _TasbihBeadsPainter({
    required this.totalBeads,
    required this.activeCount,
    required this.animPhase,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringRadius = (size.width / 2) - 18;

    final stringPaint = Paint()
      ..color = const Color(0xFFD4AF37).withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(center, ringRadius, stringPaint);

    final activeBeadIndex = activeCount % totalBeads;
    final stepAngle = (2 * math.pi) / totalBeads;
    final rotationOffset = (activeCount * stepAngle) + (animPhase * stepAngle * 0.35);

    for (int i = 0; i < totalBeads; i++) {
      final angle = -math.pi / 2 + (i * stepAngle) + rotationOffset;
      final bx = center.dx + math.cos(angle) * ringRadius;
      final by = center.dy + math.sin(angle) * ringRadius;
      final beadCenter = Offset(bx, by);

      final isDivider = i % 11 == 0;
      final isHighlighted = i == (activeBeadIndex % totalBeads);
      final beadRadius = isDivider ? 8.5 : (isHighlighted ? 8.0 : 6.4);

      final beadPaint = Paint()
        ..shader = RadialGradient(
          colors: isDivider
              ? [const Color(0xFFFFE082), const Color(0xFFB8860B)]
              : isHighlighted
                  ? [Colors.white, primaryColor]
                  : [primaryColor, secondaryColor],
          center: const Alignment(-0.35, -0.35),
        ).createShader(Rect.fromCircle(center: beadCenter, radius: beadRadius));

      canvas.drawCircle(beadCenter, beadRadius, beadPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TasbihBeadsPainter oldDelegate) =>
      oldDelegate.activeCount != activeCount || oldDelegate.animPhase != animPhase;
}
