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
      icon: Icons.auto_awesome_outlined,
      activeIcon: Icons.auto_awesome_rounded,
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
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      height: 74,
      decoration: BoxDecoration(
        color: ThalabTheme.cardSurface,
        borderRadius: BorderRadius.circular(38),
        border: Border.all(color: ThalabTheme.softBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: ThalabTheme.foxOrange.withOpacity(0.14),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double itemWidth = constraints.maxWidth / items.length;
          return Stack(
            alignment: Alignment.center,
            children: [
              // الخلفية البرتقالية المنزلقة للتبويب النشط
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                right: currentIndex * itemWidth + 4,
                top: 4,
                bottom: 4,
                width: itemWidth - 8,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [ThalabTheme.foxOrangeLight, ThalabTheme.foxOrange],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: [
                      BoxShadow(
                        color: ThalabTheme.foxOrange.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              // أيقونات وعناوين التبويبات
              Row(
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: isSelected ? 1.12 : 1.0,
                            duration: const Duration(milliseconds: 250),
                            child: Icon(
                              isSelected ? item.activeIcon : item.icon,
                              color: isSelected
                                  ? Colors.white
                                  : ThalabTheme.darkSlate,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : ThalabTheme.darkSlate,
                            ),
                          ),
                          if (isSelected)
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              width: 16,
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
