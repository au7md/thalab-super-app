import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../core/storage_service.dart';

class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen>
    with TickerProviderStateMixin {
  int _count = 0;
  int _totalCount = 0;
  int _completedRounds = 0;
  int _target = 33; // 33, 100, أو 0 (مفتوح)
  String _selectedDhikr = 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ';

  late AnimationController _pressController;
  late AnimationController _beadRotationController;

  final List<String> _presets = [
    'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
    'أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ وَأَتُوبُ إِلَيْهِ',
    'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ',
    'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ',
    'سُبْحَانَ اللَّهِ، وَالْحَمْدُ لِلَّهِ، وَلَا إِلَهَ إِلَّا اللَّهُ، وَاللَّهُ أَكْبَرُ',
  ];

  @override
  void initState() {
    super.initState();
    _count = StorageService.getCurrentTasbih();
    _totalCount = StorageService.getTotalTasbih();
    _selectedDhikr = StorageService.getSelectedDhikr();

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: 0.93,
      upperBound: 1.0,
      value: 1.0,
    );

    _beadRotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    _beadRotationController.dispose();
    super.dispose();
  }

  void _increment() {
    _pressController.reverse().then((_) => _pressController.forward());
    _beadRotationController.forward(from: 0.0);

    setState(() {
      _count++;
      _totalCount++;
    });

    StorageService.setTotalTasbih(_totalCount);

    // التحقق من الوصول للهدف (33 أو 100) والتصفير التلقائي
    if (_target > 0 && _count >= _target) {
      HapticFeedback.heavyImpact();
      setState(() {
        _completedRounds++;
      });
      Future.delayed(const Duration(milliseconds: 260), () {
        if (mounted) {
          setState(() => _count = 0);
          StorageService.setCurrentTasbih(0);
        }
      });
    } else {
      HapticFeedback.selectionClick();
      StorageService.setCurrentTasbih(_count);
    }
  }

  void _resetCurrent() {
    HapticFeedback.mediumImpact();
    setState(() {
      _count = 0;
      _completedRounds = 0;
    });
    StorageService.setCurrentTasbih(0);
  }

  void _setTarget(int newTarget) {
    HapticFeedback.lightImpact();
    setState(() {
      _target = newTarget;
      if (_target > 0 && _count >= _target) {
        _count = 0;
        StorageService.setCurrentTasbih(0);
      }
    });
  }

  void _showCustomDhikrDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThalabTheme.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('إضافة ذكر مخصص', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'اكتب الذكر هنا...',
            filled: true,
            fillColor: ThalabTheme.creamBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: ThalabTheme.mutedSlate)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThalabTheme.foxOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _selectedDhikr = controller.text.trim();
                  _count = 0;
                  _completedRounds = 0;
                });
                StorageService.setSelectedDhikr(_selectedDhikr);
                StorageService.setCurrentTasbih(0);
              }
              Navigator.pop(ctx);
            },
            child: const Text('اعتماد'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _target == 0 ? 1.0 : (_count / _target).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('السبحة الذكية'),
        actions: [
          IconButton(
            tooltip: 'ذكر مخصص',
            icon: const Icon(Icons.edit_note_rounded, color: ThalabTheme.foxOrange, size: 28),
            onPressed: _showCustomDhikrDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        child: Column(
          children: [
            // شريط اختيار الهدف بدقة (33 / 100 / مفتوح)
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: ThalabTheme.cardSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ThalabTheme.softBorder),
              ),
              child: Row(
                children: [
                  _TargetButton(label: '33', selected: _target == 33, onTap: () => _setTarget(33)),
                  _TargetButton(label: '100', selected: _target == 100, onTap: () => _setTarget(100)),
                  _TargetButton(label: 'مفتوح ∞', selected: _target == 0, onTap: () => _setTarget(0)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // اختيار الذكر
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _presets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final text = _presets[index];
                  final isSelected = text == _selectedDhikr;
                  return ChoiceChip(
                    label: Text(
                      text,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : ThalabTheme.darkSlate,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: ThalabTheme.foxOrange,
                    backgroundColor: ThalabTheme.cardSurface,
                    onSelected: (_) {
                      setState(() {
                        _selectedDhikr = text;
                        _count = 0;
                        _completedRounds = 0;
                      });
                      StorageService.setSelectedDhikr(text);
                      StorageService.setCurrentTasbih(0);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // بطاقة الذكر النشط
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: ThalabTheme.cardSurface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: ThalabTheme.softBorder, width: 1.5),
              ),
              child: Text(
                _selectedDhikr,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18.5, fontWeight: FontWeight.bold, height: 1.55),
              ),
            ),

            const Spacer(),

            // دائرة السبحة التفاعلية المتطورة
            ScaleTransition(
              scale: _pressController,
              child: GestureDetector(
                onTap: _increment,
                child: AnimatedBuilder(
                  animation: _beadRotationController,
                  builder: (context, _) {
                    return SizedBox(
                      width: 280,
                      height: 280,
                      child: CustomPaint(
                        painter: _ModernRosaryPainter(
                          progress: progress,
                          count: _count,
                          isInfinite: _target == 0,
                          animFraction: _beadRotationController.value,
                        ),
                        child: Center(
                          child: Container(
                            width: 172,
                            height: 172,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFFCF8), Color(0xFFFFF2E2)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(color: ThalabTheme.foxOrange.withOpacity(0.35), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: ThalabTheme.foxOrange.withOpacity(0.22),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$_count',
                                  style: const TextStyle(
                                    fontSize: 52,
                                    fontWeight: FontWeight.bold,
                                    color: ThalabTheme.foxOrange,
                                    height: 1.1,
                                  ),
                                ),
                                if (_target > 0)
                                  Text(
                                    'من $_target',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: ThalabTheme.mutedSlate,
                                    ),
                                  )
                                else
                                  const Text(
                                    'عد مفتوح',
                                    style: TextStyle(fontSize: 12, color: ThalabTheme.mutedSlate),
                                  ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: ThalabTheme.foxOrange.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'الدورات: $_completedRounds • الكلي: $_totalCount',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: ThalabTheme.foxOrange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const Spacer(),

            TextButton.icon(
              onPressed: _resetCurrent,
              icon: const Icon(Icons.refresh_rounded, color: ThalabTheme.mutedSlate),
              label: const Text(
                'تصفير العداد والدورات',
                style: TextStyle(color: ThalabTheme.mutedSlate, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TargetButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? ThalabTheme.foxOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: selected ? Colors.white : ThalabTheme.darkSlate,
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernRosaryPainter extends CustomPainter {
  final double progress;
  final int count;
  final bool isInfinite;
  final double animFraction;

  _ModernRosaryPainter({
    required this.progress,
    required this.count,
    required this.isInfinite,
    required this.animFraction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final trackRadius = size.width / 2 - 22;

    // 1. مسار الحلقة الخلفية الناعم
    final bgTrackPaint = Paint()
      ..color = ThalabTheme.softBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, trackRadius, bgTrackPaint);

    // 2. قوس التقدم المتوهج
    final progressPaint = Paint()
      ..shader = const SweepGradient(
        colors: [ThalabTheme.foxOrangeLight, ThalabTheme.foxOrange],
      ).createShader(Rect.fromCircle(center: center, radius: trackRadius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: trackRadius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );

    // 3. حبات السبحة المحيطية المضيئة
    const int beadCount = 33;
    final double rotationOffset = isInfinite
        ? ((count - 1 + animFraction) / beadCount) * 2 * math.pi
        : 0.0;

    for (int i = 0; i < beadCount; i++) {
      final double angle = -math.pi / 2 + (i / beadCount) * 2 * math.pi + rotationOffset;
      final beadCenter = Offset(
        center.dx + trackRadius * math.cos(angle),
        center.dy + trackRadius * math.sin(angle),
      );

      final bool isLit = isInfinite || (i / beadCount) <= progress && count > 0;
      final beadPaint = Paint()
        ..color = isLit ? Colors.white : ThalabTheme.creamBackground;

      canvas.drawCircle(beadCenter, isLit ? 4.2 : 2.8, beadPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ModernRosaryPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.count != count ||
      oldDelegate.animFraction != animFraction;
}
