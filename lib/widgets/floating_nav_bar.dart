import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';

class NavItemData {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const NavItemData({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class ThalabFloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ThalabFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const List<NavItemData> items = [
    NavItemData(
      label: 'الرئيسية',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    NavItemData(
      label: 'رفيق',
      icon: Icons.people_alt_outlined,
      activeIcon: Icons.people_alt_rounded,
    ),
    NavItemData(
      label: 'الميديا',
      icon: Icons.play_circle_outline_rounded,
      activeIcon: Icons.play_circle_filled_rounded,
    ),
    NavItemData(
      label: 'الموسيقى',
      icon: Icons.music_note_outlined,
      activeIcon: Icons.music_note_rounded,
    ),
    NavItemData(
      label: 'المزيد',
      icon: Icons.more_horiz_rounded,
      activeIcon: Icons.grid_view_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(items.length, (index) {
          final bool isSelected = currentIndex == index;
          final item = items[index];

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (!isSelected) {
                  HapticFeedback.lightImpact();
                  onTap(index);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: isSelected ? 78 : 68,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [ThalabTheme.foxOrangeLight, ThalabTheme.foxOrange],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : null,
                  color: isSelected ? null : ThalabTheme.cardSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected
                        ? ThalabTheme.foxOrange
                        : ThalabTheme.softBorder,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? ThalabTheme.foxOrange.withOpacity(0.32)
                          : ThalabTheme.foxOrange.withOpacity(0.08),
                      blurRadius: isSelected ? 16 : 8,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected ? item.activeIcon : item.icon,
                      color: isSelected ? Colors.white : ThalabTheme.darkSlate,
                      size: isSelected ? 26 : 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        color:
                            isSelected ? Colors.white : ThalabTheme.darkSlate,
                      ),
                    ),
                    if (isSelected)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 18,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
