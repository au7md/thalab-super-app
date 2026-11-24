import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/daily_progress.dart';

/// بطاقة "يومك في الثعلب": تجمع إنجاز اليوم من كل الأقسام في مكان واحد.
class DailyProgressCard extends StatelessWidget {
  final DailyProgress progress;
  final VoidCallback onOpenAdhkar;
  final VoidCallback onOpenTasbih;
  final VoidCallback onOpenQuran;
  final VoidCallback onOpenHabits;

  const DailyProgressCard({
    required this.progress,
    required this.onOpenAdhkar,
    required this.onOpenTasbih,
    required this.onOpenQuran,
    required this.onOpenHabits,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        isDark ? ThalabTheme.darkCardSurface : ThalabTheme.cardSurface;
    final border = isDark ? ThalabTheme.darkBorder : ThalabTheme.softBorder;
    final active = progress.activeSections;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded,
                  color: ThalabTheme.foxOrange, size: 18),
              const SizedBox(width: 6),
              const Text(
                'يومك في الثعلب',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: ThalabTheme.foxOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  active > 0 ? '$active أقسام نشطة' : 'ابدأ يومك',
                  style: const TextStyle(
                    color: ThalabTheme.foxOrange,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              DailyStat(
                icon: Icons.auto_awesome_rounded,
                value: '${progress.adhkarCompleted}',
                label: 'أذكار',
                onTap: onOpenAdhkar,
              ),
              DailyStat(
                icon: Icons.blur_circular_rounded,
                value: '${progress.tasbihToday}',
                label: 'تسبيح',
                onTap: onOpenTasbih,
              ),
              DailyStat(
                icon: Icons.menu_book_rounded,
                value: '${progress.khatmahPages}',
                label: 'صفحات الختمة',
                onTap: onOpenQuran,
              ),
              DailyStat(
                icon: Icons.check_circle_outline_rounded,
                value: '${progress.habitsDone}/${progress.habitsTotal}',
                label: 'عادات',
                onTap: onOpenHabits,
              ),
              DailyStat(
                icon: Icons.bolt_rounded,
                value: '${progress.pomodorosToday}',
                label: 'جلسات تركيز',
                onTap: onOpenHabits,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DailyStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;

  const DailyStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Icon(icon, color: ThalabTheme.foxOrange, size: 20),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? ThalabTheme.darkTextMuted
                      : ThalabTheme.mutedSlate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
