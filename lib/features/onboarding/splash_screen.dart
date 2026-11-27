import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/fox_mascot.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';

/// شاشة الفتح: ثعلب حي + موجات نابضة + ظهور متتابع للأقسام.
class SplashScreen extends StatefulWidget {
  final WidgetBuilder homeBuilder;
  final WidgetBuilder onboardingBuilder;

  const SplashScreen({
    super.key,
    required this.homeBuilder,
    required this.onboardingBuilder,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _rings;

  @override
  void initState() {
    super.initState();
    _rings = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat();
    _go();
  }

  Future<void> _go() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirst = prefs.getBool('first_launch_v1.7') ?? true;
    await Future.delayed(const Duration(milliseconds: 2600));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      fadeScaleRoute((ctx) => isFirst ? widget.onboardingBuilder(ctx) : widget.homeBuilder(ctx)),
    );
  }

  @override
  void dispose() {
    _rings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = thalabMuted(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF121316), Color(0xFF1B1410)]
                : const [Color(0xFFFFF8F0), Color(0xFFFFE9D3)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _rings,
                      builder: (_, __) => CustomPaint(
                        size: const Size(260, 260),
                        painter: _RingsPainter(_rings.value, ThalabTheme.foxOrange),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 950),
                      curve: Curves.easeOutBack,
                      builder: (_, v, child) => Opacity(
                        opacity: v.clamp(0.0, 1.0),
                        child: Transform.scale(scale: 0.6 + 0.4 * v, child: child),
                      ),
                      child: const FoxMascot(size: 140, mood: FoxMood.happy),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const FadeSlideIn(
                delay: Duration(milliseconds: 500),
                child: Text(
                  'الثعلب',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 6),
              FadeSlideIn(
                delay: const Duration(milliseconds: 800),
                child: Text(
                  'رفيقك اليومي المتكامل',
                  style: TextStyle(fontSize: 15, color: muted, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 22),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeSlideIn(delay: Duration(milliseconds: 1000), child: _EmojiChip('🕌')),
                  FadeSlideIn(delay: Duration(milliseconds: 1150), child: _EmojiChip('📸')),
                  FadeSlideIn(delay: Duration(milliseconds: 1300), child: _EmojiChip('🎧')),
                  FadeSlideIn(delay: Duration(milliseconds: 1450), child: _EmojiChip('🧰')),
                ],
              ),
              const Spacer(flex: 3),
              FadeSlideIn(
                delay: const Duration(milliseconds: 1000),
                child: SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: const LinearProgressIndicator(
                      minHeight: 4,
                      color: ThalabTheme.foxOrange,
                      backgroundColor: Color(0x22E86A17),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmojiChip extends StatelessWidget {
  final String emoji;
  const _EmojiChip(this.emoji);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 22)),
    );
  }
}

class _RingsPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingsPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 3; i++) {
      final phase = (progress + i / 3) % 1.0;
      final radius = 74 + phase * 56;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = color.withOpacity((1 - phase) * 0.28);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) => old.progress != progress;
}
