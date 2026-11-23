import 'package:flutter/material.dart';
import '../core/theme.dart';

class ThalabFloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ThalabFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      height: 66,
      decoration: BoxDecoration(
        color: ThalabTheme.cardSurface.withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: ThalabTheme.softBorder, width: 1.4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildItem(0, Icons.mosque_rounded, 'رفيق'),
          _buildItem(1, Icons.image_rounded, 'المعرض'),
          _buildItem(2, Icons.music_note_rounded, 'الموسيقى'),
          _buildItem(3, Icons.more_horiz_rounded, 'المزيد'),
        ],
      ),
    );
  }

  Widget _buildItem(int idx, IconData icon, String label) {
    final active = idx == currentIndex;
    return InkWell(
      onTap: () => onTap(idx),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? ThalabTheme.foxOrange.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active ? ThalabTheme.foxOrange : ThalabTheme.mutedSlate,
              size: 23,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: active ? ThalabTheme.foxOrange : ThalabTheme.mutedSlate,
                fontSize: 10.5,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
