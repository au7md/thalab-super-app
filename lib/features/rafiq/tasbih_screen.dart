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
    with SingleTickerProviderStateMixin {
  int _count = 0;
  int _totalCount = 0;
  int _target = 33;
  String _selectedDhikr = 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ';
  late AnimationController _beadAnimController;

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
    _beadAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _beadAnimController.dispose();
    super.dispose();
  }

  void _increment() {
    _beadAnimController.forward(from: 0.0);
    setState(() {
      _count++;
      _totalCount++;
    });
    StorageService.setCurrentTasbih(_count);
    StorageService.setTotalTasbih(_totalCount);

    if (_target > 0 && _count % _target == 0) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _resetCurrent() {
    HapticFeedback.mediumImpact();
    setState(() => _count = 0);
    StorageService.setCurrentTasbih(0);
  }

  void _cycleTarget() {
    setState(() {
      if (_target == 33) {
        _target = 100;
      } else if (_target == 100) {
        _target = 0;
      } else {
        _target = 33;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('السبحة الإلكترونية'),
        actions: [
          IconButton(
            tooltip: 'ذكر مخصص',
            icon: const Icon(Icons.edit_note_rounded, color: ThalabTheme.foxOrange, size: 28),
            onPressed: _showCustomDhikrDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatPill(
                    label: 'إجمالي التسبيحات',
                    value: '$_totalCount',
                    icon: Icons.auto_awesome_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _cycleTarget,
                  child: _StatPill(
                    label: 'الهدف (اضغط للتغيير)',
                    value: _target == 0 ? 'مفتوح ∞' : '$_target',
                    icon: Icons.flag_rounded,
                    highlight: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 42,
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
                      });
                      StorageService.setSelectedDhikr(text);
                      StorageService.setCurrentTasbih(0);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
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
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, height: 1.6),
              ),
            ),
            const Spacer(),

            // حلقة السبحة ثلاثية الأبعاد بحبات متحركة
            GestureDetector(
              onTap: _increment,
              child: AnimatedBuilder(
                animation: _beadAnimController,
                builder: (context, _) {
                  return SizedBox(
                    width: 270,
                    height: 270,
                    child: CustomPaint(
                      painter: _RosaryBeadsPainter(
                        count: _count,
                        target: _target == 0 ? 33 : _target,
                        stepFraction: _beadAnimController.value,
                      ),
                      child: Center(
                        child: Container(
                          width: 155,
                          height: 155,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ThalabTheme.cardSurface,
                            border: Border.all(color: ThalabTheme.softBorder, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: ThalabTheme.foxOrange.withOpacity(0.18),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$_count',
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: ThalabTheme.foxOrange,
                                ),
                              ),
                              const Text(
                                'المس للتسبيح',
                                style: TextStyle(fontSize: 12, color: ThalabTheme.mutedSlate),
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

            const Spacer(),
            TextButton.icon(
              onPressed: _resetCurrent,
              icon: const Icon(Icons.refresh_rounded, color: ThalabTheme.mutedSlate),
              label: const Text(
                'تصفير العداد الحالي',
                style: TextStyle(color: ThalabTheme.mutedSlate, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RosaryBeadsPainter extends CustomPainter {
  final int count;
  final int target;
  final double stepFraction;

  _RosaryBeadsPainter({
    required this.count,
    required this.target,
    required this.stepFraction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 22;
    const int totalBeads = 33;

    // رسم خيط السبحة الدائري
    final stringPaint = Paint()
      ..color = ThalabTheme.softBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, radius, stringPaint);

    // حساب زاوية دوران الحبات مع كل تسبيحة
    final double baseAngle = ((count - 1 + stepFraction) / totalBeads) * 2 * math.pi;

    for (int i = 0; i < totalBeads; i++) {
      final double angle = -math.pi / 2 + (i / totalBeads) * 2 * math.pi + baseAngle;
      final offset = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      final bool isHeadBead = i == 0;
      final double beadRadius = isHeadBead ? 11.5 : 8.5;

      // ظل الحبة
      canvas.drawCircle(
        offset + const Offset(0, 2.5),
        beadRadius,
        Paint()..color = Colors.black.withOpacity(0.12),
      );

      // تدرج لوني يعطي مجسّم ثلاثي الأبعاد للحبة
      final rect = Rect.fromCircle(center: offset, radius: beadRadius);
      final beadPaint = Paint()
        ..shader = RadialGradient(
          colors: isHeadBead
              ? [const Color(0xFF545861), ThalabTheme.darkSlate]
              : [const Color(0xFFFFB870), ThalabTheme.foxOrange],
          center: const Alignment(-0.35, -0.35),
        ).createShader(rect);

      canvas.drawCircle(offset, beadRadius, beadPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RosaryBeadsPainter oldDelegate) =>
      oldDelegate.count != count || oldDelegate.stepFraction != stepFraction;
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlight ? ThalabTheme.foxOrange.withOpacity(0.1) : ThalabTheme.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight ? ThalabTheme.foxOrange.withOpacity(0.4) : ThalabTheme.softBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: ThalabTheme.foxOrange, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: ThalabTheme.mutedSlate)),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
