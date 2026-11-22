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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF5),
          borderRadius: BorderRadius.circular(38),
          border: Border.all(
            color: ThalabTheme.foxOrange.withOpacity(0.38),
            width: 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: ThalabTheme.foxOrange.withOpacity(0.18),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: Stack(
            children: [
              // موجة برتقالية سفلية خفيفة في الخلفية تطابق التصميم
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 10,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ThalabTheme.foxOrange.withOpacity(0.35),
                        ThalabTheme.foxOrange.withOpacity(0.08),
                        ThalabTheme.foxOrange.withOpacity(0.35),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
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
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                                  colors: [
                                    ThalabTheme.foxOrangeLight,
                                    ThalabTheme.foxOrange,
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                )
                              : null,
                          borderRadius: isSelected
                              ? BorderRadius.circular(32)
                              : BorderRadius.zero,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // خط فاصل رأسي هادئ بين التبويبات غير النشطة
                            if (!isSelected && index > 0 && currentIndex != index - 1)
                              Positioned(
                                right: 0,
                                top: 18,
                                bottom: 18,
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
                                const SizedBox(height: 3),
                                Text(
                                  labels[index],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : ThalabTheme.darkSlate,
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    margin: const EdgeInsets.only(top: 3),
                                    width: 22,
                                    height: 3,
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
            ],
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

    final primaryOrange = isSelected ? Colors.white : ThalabTheme.foxOrange;
    final secondaryDark = isSelected ? const Color(0xFFFFE5CC) : const Color(0xFF42464D);
    final creamFill = isSelected ? Colors.white.withOpacity(0.92) : const Color(0xFFFFF4E6);

    switch (index) {
      case 0: // 1. الرئيسية: بيت 3D بسقف برتقالي ونافذة مربعة
        final bodyRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.22, h * 0.44, w * 0.56, h * 0.46),
          const Radius.circular(4),
        );
        canvas.drawRRect(bodyRect, Paint()..color = creamFill);
        canvas.drawRRect(
          bodyRect,
          Paint()
            ..color = primaryOrange.withOpacity(0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );

        // السقف المثلثي
        final roofPath = Path()
          ..moveTo(w * 0.12, h * 0.48)
          ..lineTo(w * 0.50, h * 0.14)
          ..lineTo(w * 0.88, h * 0.48);
        canvas.drawPath(
          roofPath,
          Paint()
            ..color = primaryOrange
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );

        // نافذة البيت
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.41, h * 0.56, w * 0.18, w * 0.18),
            const Radius.circular(2),
          ),
          Paint()..color = primaryOrange,
        );
        break;

      case 1: // 2. رفيق: وجه ثعلب 3D لطيف بأذنين وعيون مبتسمة
        // الأذنان
        final leftEar = Path()
          ..moveTo(w * 0.22, h * 0.45)
          ..lineTo(w * 0.24, h * 0.12)
          ..lineTo(w * 0.42, h * 0.28)
          ..close();
        final rightEar = Path()
          ..moveTo(w * 0.78, h * 0.45)
          ..lineTo(w * 0.76, h * 0.12)
          ..lineTo(w * 0.58, h * 0.28)
          ..close();
        canvas.drawPath(leftEar, Paint()..color = primaryOrange);
        canvas.drawPath(rightEar, Paint()..color = primaryOrange);

        // الرأس
        final headRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.18, h * 0.26, w * 0.64, h * 0.56),
          const Radius.circular(12),
        );
        canvas.drawRRect(headRect, Paint()..color = primaryOrange);

        // الخدود البيضاء السفلية
        final cheekPath = Path()
          ..moveTo(w * 0.18, h * 0.56)
          ..quadraticBezierTo(w * 0.50, h * 0.66, w * 0.82, h * 0.56)
          ..quadraticBezierTo(w * 0.80, h * 0.84, w * 0.50, h * 0.84)
          ..quadraticBezierTo(w * 0.20, h * 0.84, w * 0.18, h * 0.56);
        canvas.drawPath(
          cheekPath,
          Paint()..color = isSelected ? const Color(0xFFFFE5CC) : Colors.white,
        );

        // العيون المبتسمة والأنف
        final eyePaint = Paint()
          ..color = isSelected ? ThalabTheme.foxOrange : const Color(0xFF3A3D42)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(Rect.fromLTWH(w * 0.30, h * 0.44, 6, 4), 3.14, 3.14, false, eyePaint);
        canvas.drawArc(Rect.fromLTWH(w * 0.54, h * 0.44, 6, 4), 3.14, 3.14, false, eyePaint);
        canvas.drawCircle(
          Offset(w * 0.50, h * 0.68),
          2.2,
          Paint()..color = isSelected ? ThalabTheme.foxOrange : const Color(0xFF3A3D42),
        );
        break;

      case 2: // 3. المعرض: كلاكيت فيديو مع بطاقة صورة متداخلة
        final slateRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.16, h * 0.32, w * 0.54, h * 0.46),
          const Radius.circular(5),
        );
        canvas.drawRRect(slateRect, Paint()..color = secondaryDark);

        // ذراع الكلاكيت العلوي
        canvas.drawLine(
          Offset(w * 0.18, h * 0.26),
          Offset(w * 0.66, h * 0.16),
          Paint()
            ..color = primaryOrange
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round,
        );

        // مثلث التشغيل داخل الكلاكيت
        final playTri = Path()
          ..moveTo(w * 0.38, h * 0.46)
          ..lineTo(w * 0.38, h * 0.64)
          ..lineTo(w * 0.52, h * 0.55)
          ..close();
        canvas.drawPath(playTri, Paint()..color = primaryOrange);

        // بطاقة الصورة الصغيرة أسفل اليمين
        final photoCard = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.54, h * 0.54, w * 0.32, h * 0.32),
          const Radius.circular(4),
        );
        canvas.drawRRect(photoCard, Paint()..color = creamFill);
        canvas.drawRRect(
          photoCard,
          Paint()
            ..color = primaryOrange
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
        canvas.drawCircle(Offset(w * 0.76, h * 0.63), 2.0, Paint()..color = primaryOrange);
        break;

      case 3: // 4. الموسيقى: نوتة موسيقية مزدوجة 3D
        final notePaint = Paint()..color = primaryOrange;
        canvas.drawCircle(Offset(w * 0.30, h * 0.74), 5.2, notePaint);
        canvas.drawCircle(Offset(w * 0.68, h * 0.68), 5.2, notePaint);

        final stemPaint = Paint()
          ..color = primaryOrange
          ..strokeWidth = 3.6
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(w * 0.35, h * 0.72), Offset(w * 0.35, h * 0.24), stemPaint);
        canvas.drawLine(Offset(w * 0.73, h * 0.66), Offset(w * 0.73, h * 0.18), stemPaint);

        final beamPath = Path()
          ..moveTo(w * 0.35, h * 0.24)
          ..lineTo(w * 0.73, h * 0.18)
          ..lineTo(w * 0.73, h * 0.28)
          ..lineTo(w * 0.35, h * 0.34)
          ..close();
        canvas.drawPath(beamPath, notePaint);
        break;

      case 4: // 5. المزيد: 4 مربعات مع ورقة شجر برتقالية جانبية
        final sqPaint = Paint()..color = secondaryDark;
        const double boxSize = 8.5;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.20, h * 0.24, boxSize, boxSize), const Radius.circular(2.5)),
          sqPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.48, h * 0.24, boxSize, boxSize), const Radius.circular(2.5)),
          sqPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.20, h * 0.54, boxSize, boxSize), const Radius.circular(2.5)),
          sqPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.48, h * 0.54, boxSize, boxSize), const Radius.circular(2.5)),
          sqPaint,
        );

        // غصن صغير برتقالي بجانب المربعات
        final leafPaint = Paint()
          ..color = primaryOrange
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(w * 0.78, h * 0.78), Offset(w * 0.84, h * 0.46), leafPaint);
        canvas.drawCircle(Offset(w * 0.86, h * 0.44), 2.5, Paint()..color = primaryOrange);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _Thalab3DIconPainter oldDelegate) =>
      oldDelegate.index != index || oldDelegate.isSelected != isSelected;
}
