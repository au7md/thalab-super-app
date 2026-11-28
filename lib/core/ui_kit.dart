import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'fox_mascot.dart';
import 'haptics.dart';
import 'theme.dart';

/// لون النص الفرعي المتوافق مع الوضعين.
Color thalabMuted(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? ThalabTheme.darkTextMuted
        : ThalabTheme.mutedSlate;

/// انتقال تلاشي + تكبير خفيف (للانتقال من الافتتاحية).
Route<T> fadeScaleRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 550),
    pageBuilder: (context, _, __) => builder(context),
    transitionsBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// يضيف ضغطة "ارتداد" لأي عنصر قابل للنقر.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final bool haptic;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.95,
    this.haptic = true,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) Haptics.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// ظهور تدريجي مع انزلاق لأعلى بعد تأخير (لتتابع ظهور العناصر).
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset from;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
    this.from = const Offset(0, 0.10),
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _show ? 1 : 0,
      duration: widget.duration,
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _show ? Offset.zero : widget.from,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// حالة فارغة موحّدة: الثعلب + عنوان + وصف (+ زر اختياري).
class FoxEmptyState extends StatelessWidget {
  final FoxMood mood;
  final String title;
  final String subtitle;
  final Widget? action;

  const FoxEmptyState({
    super.key,
    required this.mood,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeSlideIn(child: FoxMascot(size: 112, mood: mood)),
            const SizedBox(height: 18),
            FadeSlideIn(
              delay: const Duration(milliseconds: 150),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 6),
            FadeSlideIn(
              delay: const Duration(milliseconds: 300),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.6, color: thalabMuted(context)),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              FadeSlideIn(delay: const Duration(milliseconds: 450), child: action!),
            ],
          ],
        ),
      ),
    );
  }
}
