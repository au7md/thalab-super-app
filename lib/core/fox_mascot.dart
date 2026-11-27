import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

/// حالات الثعلب: كل حالة لها حركة وشارة تعبيرية مختلفة.
enum FoxMood { idle, happy, sleepy, praying, listening, studying, camera }

String foxBadgeFor(FoxMood mood) {
  switch (mood) {
    case FoxMood.happy:
      return '🎉';
    case FoxMood.sleepy:
      return '😴';
    case FoxMood.praying:
      return '🌙';
    case FoxMood.listening:
      return '🎧';
    case FoxMood.studying:
      return '📚';
    case FoxMood.camera:
      return '📸';
    case FoxMood.idle:
      return '✨';
  }
}

/// الثعلب الحي: شعار التطبيق بحركة تنفّس وتمايل وشارة حسب الحالة.
class FoxMascot extends StatefulWidget {
  final double size;
  final FoxMood mood;
  final bool showBadge;

  const FoxMascot({
    super.key,
    this.size = 120,
    this.mood = FoxMood.idle,
    this.showBadge = true,
  });

  @override
  State<FoxMascot> createState() => _FoxMascotState();
}

class _FoxMascotState extends State<FoxMascot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  Duration _durationFor(FoxMood m) {
    switch (m) {
      case FoxMood.sleepy:
        return const Duration(milliseconds: 3600);
      case FoxMood.happy:
        return const Duration(milliseconds: 650);
      default:
        return const Duration(milliseconds: 2200);
    }
  }

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _durationFor(widget.mood))
      ..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant FoxMascot old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) {
      _c.duration = _durationFor(widget.mood);
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        final sleepy = widget.mood == FoxMood.sleepy;
        final bob = (sleepy ? 2.0 : 6.0) * (t - 0.5);
        final tilt = widget.mood == FoxMood.happy ? (t - 0.5) * 0.16 : 0.0;
        final scale = 1.0 + (sleepy ? 0.02 : 0.035) * t;
        return Transform.translate(
          offset: Offset(0, bob),
          child: Transform.rotate(
            angle: tilt,
            child: Transform.scale(
              scale: scale,
              child: SizedBox(
                width: s,
                height: s,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: s,
                      height: s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: ThalabTheme.foxOrange.withOpacity(0.18 + 0.14 * t),
                            blurRadius: s * 0.28,
                            spreadRadius: s * 0.02,
                            offset: Offset(0, s * 0.06),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Opacity(
                          opacity: sleepy ? 0.86 : 1.0,
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Theme.of(context).cardColor,
                              child: Icon(Icons.pets_rounded,
                                  size: s * 0.5, color: ThalabTheme.foxOrange),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.showBadge)
                      PositionedDirectional(
                        end: -s * 0.02,
                        bottom: -s * 0.02,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: Container(
                            key: ValueKey(widget.mood),
                            width: s * 0.30,
                            height: s * 0.30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              foxBadgeFor(widget.mood),
                              style: TextStyle(fontSize: s * 0.17),
                            ),
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
    );
  }
}

/// فقاعة كلام الثعلب.
class FoxSays extends StatelessWidget {
  final String text;
  const FoxSays(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: ThalabTheme.foxOrange.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.6),
      ),
    );
  }
}

/// قصاصات احتفال (رموز تعبيرية تتساقط) تُوضع فوق الشاشة.
class FoxConfetti extends StatefulWidget {
  const FoxConfetti({super.key});

  @override
  State<FoxConfetti> createState() => _FoxConfettiState();
}

class _Particle {
  final double x;
  final double delay;
  final double size;
  final double drift;
  final String emoji;
  _Particle(this.x, this.delay, this.size, this.drift, this.emoji);
}

class _FoxConfettiState extends State<FoxConfetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Particle> _ps;

  @override
  void initState() {
    super.initState();
    final r = math.Random(7);
    const emojis = ['🎉', '✨', '🌙', '⭐', '🦊', '🧡', '🕌'];
    _ps = List.generate(
      22,
      (i) => _Particle(
        r.nextDouble(),
        r.nextDouble() * 0.45,
        16 + r.nextDouble() * 14,
        (r.nextDouble() - 0.5) * 0.12,
        emojis[r.nextInt(emojis.length)],
      ),
    );
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              return Stack(
                children: _ps.map((p) {
                  final local = ((_c.value - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
                  final y = -30 + local * (box.maxHeight + 60);
                  final x = p.x * box.maxWidth + p.drift * box.maxWidth * local;
                  return Positioned(
                    left: x,
                    top: y,
                    child: Opacity(
                      opacity: (1 - local).clamp(0.0, 1.0),
                      child: Text(p.emoji, style: TextStyle(fontSize: p.size)),
                    ),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }
}
