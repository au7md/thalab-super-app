import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adhan/adhan.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  double _qiblaAngle = 136.0;
  String _locationName = 'القاهرة، مصر';
  bool _vibratedOnAlign = false;
  double? _smoothedHeading;

  @override
  void initState() {
    super.initState();
    _loadSavedOrDetect();
  }

  Future<void> _loadSavedOrDetect() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLat = prefs.getDouble('prayer_lat');
    final savedLng = prefs.getDouble('prayer_lng');
    final savedCity = prefs.getString('prayer_city');

    if (savedLat != null && savedLng != null) {
      setState(() {
        _qiblaAngle = Qibla(Coordinates(savedLat, savedLng)).direction;
        if (savedCity != null) _locationName = savedCity;
      });
    }
    _detectFastLocation();
  }

  Future<void> _detectFastLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        Position? pos = await Geolocator.getLastKnownPosition();
        pos ??= await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 6),
          ),
        );

        final qibla = Qibla(Coordinates(pos.latitude, pos.longitude));
        String resolvedName = _locationName;
        try {
          await setLocaleIdentifier('ar');
          final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final city = p.subAdministrativeArea ?? p.locality ?? '';
            final gov = p.administrativeArea ?? '';
            if (city.isNotEmpty || gov.isNotEmpty) {
              resolvedName = [city, gov].where((e) => e.isNotEmpty).join('، ');
            }
          }
        } catch (_) {}

        if (mounted) {
          setState(() {
            _qiblaAngle = qibla.direction;
            _locationName = resolvedName;
          });
        }
      }
    } catch (_) {}
  }

  // فلتر تنعيم دائري لمنع اهتزاز الإبرة
  double _smoothAngle(double rawHeading) {
    if (_smoothedHeading == null) {
      _smoothedHeading = rawHeading;
      return rawHeading;
    }
    double diff = rawHeading - _smoothedHeading!;
    while (diff < -180) {
      diff += 360;
    }
    while (diff > 180) {
      diff -= 360;
    }
    _smoothedHeading = (_smoothedHeading! + diff * 0.18) % 360;
    return _smoothedHeading!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اتجاه القبلة'),
        actions: [
          IconButton(
            tooltip: 'تحديث الموقع',
            icon: const Icon(Icons.my_location_rounded, color: ThalabTheme.foxOrange),
            onPressed: _detectFastLocation,
          ),
        ],
      ),
      body: StreamBuilder<CompassEvent>(
        stream: FlutterCompass.events,
        builder: (context, snapshot) {
          final double rawHeading = snapshot.data?.heading ?? 0.0;
          final double heading = _smoothAngle(rawHeading);

          double diff = (_qiblaAngle - heading) % 360;
          if (diff > 180) diff -= 360;
          final bool isAligned = diff.abs() <= 3.5;

          if (isAligned && !_vibratedOnAlign) {
            _vibratedOnAlign = true;
            HapticFeedback.mediumImpact();
          } else if (!isAligned) {
            _vibratedOnAlign = false;
          }

          final Color activeColor = isAligned ? const Color(0xFF1B8A5A) : ThalabTheme.foxOrange;

          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // شارة الموقع الحالي بالعربي
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: ThalabTheme.cardSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ThalabTheme.softBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on_rounded, color: activeColor, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _locationName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // حالة المحاذاة
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: activeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      isAligned
                          ? 'أنت الآن باتجاه الكعبة المشرفة ✓'
                          : 'أدر الهاتف نحو مؤشر الكعبة (${diff.abs().toStringAsFixed(0)}°)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: activeColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // إطار البوصلة الهندسي الإسلامي
                  SizedBox(
                    width: 300,
                    height: 300,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // الزخرفة الإسلامية الثابتة
                        CustomPaint(
                          size: const Size(300, 300),
                          painter: _IslamicCompassPainter(accentColor: activeColor),
                        ),

                        // قرص الاتجاهات الدوار (الشمال + الكعبة)
                        Transform.rotate(
                          angle: (-heading * (math.pi / 180)),
                          child: SizedBox(
                            width: 260,
                            height: 260,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Positioned(
                                  top: 8,
                                  child: Text(
                                    'N',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ),
                                // إبرة اتجاه الكعبة المشرفة
                                Transform.rotate(
                                  angle: (_qiblaAngle * (math.pi / 180)),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: activeColor,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: activeColor.withOpacity(0.4),
                                              blurRadius: 12,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.mosque_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      Container(
                                        width: 5,
                                        height: 75,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [activeColor, activeColor.withOpacity(0.2)],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      const SizedBox(height: 85),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // نقطة الارتكاز المركزية
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: activeColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'زاوية القبلة الفلكية: ${_qiblaAngle.toStringAsFixed(1)}° من الشمال',
                    style: const TextStyle(color: ThalabTheme.mutedSlate, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _IslamicCompassPainter extends CustomPainter {
  final Color accentColor;
  _IslamicCompassPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 6;

    // الخلفية الدائرية
    canvas.drawCircle(
      center,
      outerRadius,
      Paint()..color = ThalabTheme.cardSurface,
    );

    // الإطار الخارجي
    canvas.drawCircle(
      center,
      outerRadius,
      Paint()
        ..color = accentColor.withOpacity(0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // رسم النجمة الإسلامية الثمانية (مربعين متقاطعين بزاوية 45 درجة)
    final starRadius = outerRadius - 28;
    final starPaint = Paint()
      ..color = accentColor.withOpacity(0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int rot = 0; rot < 2; rot++) {
      final path = Path();
      for (int i = 0; i < 4; i++) {
        final angle = (rot * math.pi / 4) + (i * math.pi / 2);
        final pt = Offset(
          center.dx + starRadius * math.cos(angle),
          center.dy + starRadius * math.sin(angle),
        );
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      canvas.drawPath(path, starPaint);
    }

    // شرطات الدرجات المحيطية
    final tickPaint = Paint()
      ..color = ThalabTheme.mutedSlate.withOpacity(0.35)
      ..strokeWidth = 1.5;

    for (int deg = 0; deg < 360; deg += 15) {
      final rad = deg * math.pi / 180;
      final isMajor = deg % 90 == 0;
      final inner = outerRadius - (isMajor ? 14 : 8);
      canvas.drawLine(
        Offset(center.dx + inner * math.cos(rad), center.dy + inner * math.sin(rad)),
        Offset(center.dx + (outerRadius - 2) * math.cos(rad), center.dy + (outerRadius - 2) * math.sin(rad)),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _IslamicCompassPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}
