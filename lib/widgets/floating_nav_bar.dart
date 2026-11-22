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

  static const List<String> labels = [
    'الرئيسية',
    'رفيق',
    'المعرض',
    'الموسيقى',
    'المزيد',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      child: Container(
        height: 78,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFFFF6EB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(39),
          border: Border.all(
            color: ThalabTheme.foxOrange.withOpacity(0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: ThalabTheme.foxOrange.withOpacity(0.16),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(37),
          child: Row(
            children: List.generate(labels.length, (index) {
              final bool isSelected = currentIndex == index;
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
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [
                                Color(0xFFFF9649),
                                ThalabTheme.foxOrange,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: ThalabTheme.foxOrange.withOpacity(0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (!isSelected && index > 0 && currentIndex != index - 1)
                          Positioned(
                            right: 0,
                            top: 16,
                            bottom: 16,
                            child: Container(
                              width: 1,
                              color: ThalabTheme.softBorder,
                            ),
                          ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 34,
                              height: 32,
                              child: CustomPaint(
                                painter: _Thalab3DIconPainter(
                                  index: index,
                                  isSelected: isSelected,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              labels[index],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : ThalabTheme.darkSlate,
                              ),
                            ),
                            if (isSelected)
                              Container(
                                margin: const EdgeInsets.only(top: 3),
                                width: 18,
                                height: 2.8,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _Thalab3DIconPainter extends CustomPainter {
  final int index;
  final bool isSelected;

  _Thalab3DIconPainter({required this.index, required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final orangeMain = isSelected ? Colors.white : ThalabTheme.foxOrange;
    final orangeShadow = isSelected ? const Color(0xFFFFDEC2) : const Color(0xFFC2510C);
    final slateMain = isSelected ? const Color(0xFFFFEFE0) : const Color(0xFF3E434C);
    final wallCream = isSelected ? Colors.white.withOpacity(0.95) : const Color(0xFFFFF3E4);

    switch (index) {
      case 0: // 1. الرئيسية: بيت ثلاثي الأبعاد بظل وسقف برتقالي ونافذة
        // ظل البيت
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.24, h * 0.46, w * 0.56, h * 0.44),
            const Radius.circular(5),
          ),
          Paint()..color = orangeShadow.withOpacity(0.35),
        );
        // واجهة البيت
        final body = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.21, h * 0.43, w * 0.56, h * 0.44),
          const Radius.circular(5),
        );
        canvas.drawRRect(body, Paint()..color = wallCream);
        canvas.drawRRect(
          body,
          Paint()
            ..color = orangeMain.withOpacity(0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
        // السقف المجسم
        final roof = Path()
          ..moveTo(w * 0.12, h * 0.47)
          ..lineTo(w * 0.49, h * 0.13)
          ..lineTo(w * 0.86, h * 0.47);
        canvas.drawPath(
          roof,
          Paint()
            ..color = orangeMain
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.4
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
        // النافذة المربعة
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.40, h * 0.55, w * 0.18, w * 0.18),
            const Radius.circular(2.5),
          ),
          Paint()..color = orangeMain,
        );
        break;

      case 1: // 2. رفيق: ثعلب 3D بأذنين مبطنتين وخدود بيضاء
        final leftEar = Path()
          ..moveTo(w * 0.20, h * 0.46)
          ..lineTo(w * 0.22, h * 0.10)
          ..lineTo(w * 0.42, h * 0.27)
          ..close();
        final rightEar = Path()
          ..moveTo(w * 0.80, h * 0.46)
          ..lineTo(w * 0.78, h * 0.10)
          ..lineTo(w * 0.58, h * 0.27)
          ..close();
        canvas.drawPath(leftEar, Paint()..color = orangeShadow);
        canvas.drawPath(rightEar, Paint()..color = orangeShadow);

        // الرأس البيضاوي المجسم
        final head = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.17, h * 0.25, w * 0.66, h * 0.58),
          const Radius.circular(14),
        );
        canvas.drawRRect(head, Paint()..color = orangeMain);

        // الخدود البيضاء
        final cheeks = Path()
          ..moveTo(w * 0.17, h * 0.55)
          ..quadraticBezierTo(w * 0.50, h * 0.67, w * 0.83, h * 0.55)
          ..quadraticBezierTo(w * 0.80, h * 0.85, w * 0.50, h * 0.85)
          ..quadraticBezierTo(w * 0.20, h * 0.85, w * 0.17, h * 0.55);
        canvas.drawPath(
          cheeks,
          Paint()..color = isSelected ? const Color(0xFFFFE5CC) : Colors.white,
        );

        // العيون المبتسمة والأنف
        final faceInk = isSelected ? ThalabTheme.foxOrange : const Color(0xFF2D3138);
        final eyePaint = Paint()
          ..color = faceInk
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(Rect.fromLTWH(w * 0.29, h * 0.43, 6.5, 4.5), 3.14, 3.14, false, eyePaint);
        canvas.drawArc(Rect.fromLTWH(w * 0.54, h * 0.43, 6.5, 4.5), 3.14, 3.14, false, eyePaint);
        canvas.drawCircle(Offset(w * 0.50, h * 0.68), 2.3, Paint()..color = faceInk);
        break;

      case 2: // 3. المعرض: كلاكيت 3D وبطاقة صورة متداخلة
        final clapperBody = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.14, h * 0.33, w * 0.56, h * 0.45),
          const Radius.circular(6),
        );
        canvas.drawRRect(clapperBody, Paint()..color = slateMain);

        // ذراع الكلاكيت المخطط
        canvas.drawLine(
          Offset(w * 0.16, h * 0.26),
          Offset(w * 0.68, h * 0.15),
          Paint()
            ..color = orangeMain
            ..strokeWidth = 4.2
            ..strokeCap = StrokeCap.round,
        );

        // مثلث التشغيل
        final play = Path()
          ..moveTo(w * 0.37, h * 0.46)
          ..lineTo(w * 0.37, h * 0.65)
          ..lineTo(w * 0.52, h * 0.555)
          ..close();
        canvas.drawPath(play, Paint()..color = orangeMain);

        // بطاقة الصورة المصغرة
        final picRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.53, h * 0.52, w * 0.34, h * 0.34),
          const Radius.circular(5),
        );
        canvas.drawRRect(picRect, Paint()..color = wallCream);
        canvas.drawRRect(
          picRect,
          Paint()
            ..color = orangeMain
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        canvas.drawCircle(Offset(w * 0.77, h * 0.61), 2.1, Paint()..color = orangeMain);
        break;

      case 3: // 4. الموسيقى: نوتة موسيقية مزدوجة مجسمة
        canvas.drawCircle(Offset(w * 0.30, h * 0.74), 5.6, Paint()..color = orangeMain);
        canvas.drawCircle(Offset(w * 0.68, h * 0.68), 5.6, Paint()..color = orangeMain);

        final stem = Paint()
          ..color = orangeMain
          ..strokeWidth = 3.8
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(w * 0.35, h * 0.72), Offset(w * 0.35, h * 0.22), stem);
        canvas.drawLine(Offset(w * 0.73, h * 0.66), Offset(w * 0.73, h * 0.16), stem);

        final bar = Path()
          ..moveTo(w * 0.35, h * 0.22)
          ..lineTo(w * 0.73, h * 0.16)
          ..lineTo(w * 0.73, h * 0.27)
          ..lineTo(w * 0.35, h * 0.33)
          ..close();
        canvas.drawPath(bar, Paint()..color = orangeMain);
        break;

      case 4: // 5. المزيد: 4 مربعات مع غصن برتقالي
        final boxPaint = Paint()..color = slateMain;
        const double b = 8.8;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.18, h * 0.23, b, b), const Radius.circular(3)),
          boxPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.47, h * 0.23, b, b), const Radius.circular(3)),
          boxPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.18, h * 0.53, b, b), const Radius.circular(3)),
          boxPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.47, h * 0.53, b, b), const Radius.circular(3)),
          boxPaint,
        );

        final branch = Paint()
          ..color = orangeMain
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(w * 0.78, h * 0.80), Offset(w * 0.85, h * 0.44), branch);
        canvas.drawCircle(Offset(w * 0.86, h * 0.42), 2.8, Paint()..color = orangeMain);
        canvas.drawCircle(Offset(w * 0.75, h * 0.58), 2.3, Paint()..color = orangeMain);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _Thalab3DIconPainter oldDelegate) =>
      oldDelegate.index != index || oldDelegate.isSelected != isSelected;
}
