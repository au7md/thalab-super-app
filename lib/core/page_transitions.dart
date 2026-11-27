import 'package:flutter/material.dart';

/// انتقال موحّد بين كل الشاشات: تلاشي + انزلاق خفيف يحترم اتجاه RTL.
class ThalabPageTransitionsBuilder extends PageTransitionsBuilder {
  const ThalabPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        textDirection: Directionality.of(context),
        position: Tween<Offset>(
          begin: const Offset(0.06, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
