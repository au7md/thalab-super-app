import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      height: 70,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFF8F0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: ThalabTheme.foxOrange.withOpacity(0.14),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildItem(0, 'رفيق', isRafiq: true, icon: Icons.nights_stay_rounded),
          _buildItem(1, 'المعرض', icon: Icons.movie_creation_rounded),
          _buildItem(2, 'الموسيقى', icon: Icons.music_note_rounded),
          _buildItem(3, 'المزيد', icon: Icons.grid_view_rounded),
        ],
      ),
    );
  }

  Widget _buildItem(int idx, String label,
      {required IconData icon, bool isRafiq = false}) {
    final active = idx == currentIndex;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap(idx);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutBack,
        padding: EdgeInsets.symmetric(
          horizontal: active ? 18 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                )
              : null,
          borderRadius: BorderRadius.circular(24),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: ThalabTheme.foxOrange.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: active ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 220),
              child: isRafiq
                  ? Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.pets_rounded,
                          color: active ? Colors.white : ThalabTheme.darkSlate,
                          size: 22,
                        ),
                        Positioned(
                          top: -4,
                          right: -5,
                          child: Icon(
                            Icons.brightness_3_rounded,
                            size: 11,
                            color: active
                                ? const Color(0xFFFFE4B5)
                                : ThalabTheme.foxOrange,
                          ),
                        ),
                      ],
                    )
                  : Icon(
                      icon,
                      color: active ? Colors.white : ThalabTheme.darkSlate,
                      size: 23,
                    ),
            ),
            if (active) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
