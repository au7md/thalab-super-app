import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adhan/adhan.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
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

  static const List<(String, double, double)> _govs = [
    ('القاهرة', 30.0444, 31.2357),
    ('الجيزة', 30.0131, 31.2089),
    ('الإسكندرية', 31.2001, 29.9187),
    ('الدقهلية', 31.0409, 31.3785),
    ('الشرقية', 30.5877, 31.5020),
    ('المنوفية', 30.5503, 31.0106),
    ('القليوبية', 30.4591, 31.1786),
    ('البحيرة', 31.0341, 30.4682),
    ('الغربية', 30.7865, 31.0004),
    ('كفر الشيخ', 31.1107, 30.9388),
    ('دمياط', 31.4175, 31.8144),
    ('بورسعيد', 31.2653, 32.3019),
    ('الإسماعيلية', 30.5965, 32.2715),
    ('السويس', 29.9668, 32.5498),
    ('الفيوم', 29.3084, 30.8428),
    ('بني سويف', 29.0661, 31.0994),
    ('المنيا', 28.1099, 30.7503),
    ('أسيوط', 27.1783, 31.1859),
    ('سوهاج', 26.5591, 31.6957),
    ('قنا', 26.1551, 32.7160),
    ('الأقصر', 25.6872, 32.6396),
    ('أسوان', 24.0889, 32.8998),
    ('البحر الأحمر', 27.2579, 33.8116),
    ('الوادي الجديد', 25.4390, 30.5586),
    ('مطروح', 31.3543, 27.2373),
    ('شمال سيناء', 31.1321, 33.8033),
    ('جنوب سيناء', 28.2417, 33.6222),
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedOrDetect();
  }

  String _resolveGovName(double lat, double lng) {
    String nearest = 'القاهرة';
    double minDist = double.infinity;
    for (final g in _govs) {
      final d = Geolocator.distanceBetween(lat, lng, g.$2, g.$3);
      if (d < minDist) {
        minDist = d;
        nearest = g.$1;
      }
    }
    return '$nearest، مصر';
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
            timeLimit: Duration(seconds: 5),
          ),
        );

        final qibla = Qibla(Coordinates(pos.latitude, pos.longitude));
        if (mounted) {
          setState(() {
            _qiblaAngle = qibla.direction;
            _locationName = _resolveGovName(pos!.latitude, pos.longitude);
          });
        }
      }
    } catch (_) {}
  }

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
                  SizedBox(
                    width: 300,
                    height: 300,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(300, 300),
                          painter: _IslamicCompassPainter(accentColor: activeColor),
                        ),
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

    canvas.drawCircle(center, outerRadius, Paint()..color = ThalabTheme.cardSurface);
    canvas.drawCircle(
      center,
      outerRadius,
      Paint()
        ..color = accentColor.withOpacity(0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

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
