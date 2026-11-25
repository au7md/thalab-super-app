import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme.dart';
import '../core/daily_progress.dart';

/// بطاقة "يومك في الثعلب": تجمع إنجاز اليوم من كل الأقسام في مكان واحد.
///
/// The card can share itself as a PNG: the body is wrapped in a
/// [RepaintBoundary] and captured at 3x, so the shared image is rendered by
/// Flutter itself (correct Arabic shaping) instead of a text-only summary.
class DailyProgressCard extends StatefulWidget {
  final DailyProgress progress;
  final VoidCallback onOpenAdhkar;
  final VoidCallback onOpenTasbih;
  final VoidCallback onOpenQuran;
  final VoidCallback onOpenHabits;

  const DailyProgressCard({
    super.key,
    required this.progress,
    required this.onOpenAdhkar,
    required this.onOpenTasbih,
    required this.onOpenQuran,
    required this.onOpenHabits,
  });

  @override
  State<DailyProgressCard> createState() => DailyProgressCardState();
}

class DailyProgressCardState extends State<DailyProgressCard> {
  final _boundaryKey = GlobalKey();
  bool _sharing = false;

  /// Renders the card to PNG bytes at 3x. Exposed for widget tests; the
  /// share flow below is a thin Share.shareXFiles wrapper around it.
  @visibleForTesting
  Future<Uint8List?> capturePng() async {
    final boundary = _boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    // A tap's ink splash dirties the boundary; wait for one painted frame
    // before capturing (toImage asserts on a dirty boundary in debug mode).
    // debugNeedsPaint is false by definition in release builds, where the
    // assert also does not exist, so gating on it is exact.
    if (boundary.debugNeedsPaint) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return null;
    }
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _share() async {
    if (_sharing) return;
    // NOTE: no setState before the capture. Rebuilding the boundary first
    // would mark it needs-paint and RenderRepaintBoundary.toImage asserts on
    // a dirty boundary.
    _sharing = true;
    try {
      final bytes = await capturePng();
      if (bytes == null) return;
      if (mounted) setState(() {}); // swap to the busy icon
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: 'thalab_day.png',
            mimeType: 'image/png',
          ),
        ],
        text: 'يومي في الثعلب 🦊',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        isDark ? ThalabTheme.darkCardSurface : ThalabTheme.cardSurface;
    final border = isDark ? ThalabTheme.darkBorder : ThalabTheme.softBorder;
    final progress = widget.progress;
    final active = progress.activeSections;

    return RepaintBoundary(
      key: _boundaryKey,
      child: Container(
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
                const Expanded(
                  child: Text(
                    'يومك في الثعلب',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'مشاركة إنجاز اليوم',
                  visualDensity: VisualDensity.compact,
                  iconSize: 17,
                  onPressed: _sharing ? null : _share,
                  icon: Icon(
                    _sharing
                        ? Icons.hourglass_top_rounded
                        : Icons.share_rounded,
                    color: ThalabTheme.foxOrange,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: ThalabTheme.foxOrange.withValues(alpha: 0.12),
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
                  onTap: widget.onOpenAdhkar,
                ),
                DailyStat(
                  icon: Icons.blur_circular_rounded,
                  value: '${progress.tasbihToday}',
                  label: 'تسبيح',
                  onTap: widget.onOpenTasbih,
                ),
                DailyStat(
                  icon: Icons.menu_book_rounded,
                  value: '${progress.khatmahPages}',
                  label: 'صفحات الختمة',
                  onTap: widget.onOpenQuran,
                ),
                DailyStat(
                  icon: Icons.check_circle_outline_rounded,
                  value: '${progress.habitsDone} من ${progress.habitsTotal}',
                  label: 'عادات',
                  onTap: widget.onOpenHabits,
                ),
                DailyStat(
                  icon: Icons.bolt_rounded,
                  value: '${progress.pomodorosToday}',
                  label: 'جلسات تركيز',
                  onTap: widget.onOpenHabits,
                ),
              ],
            ),
          ],
        ),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
