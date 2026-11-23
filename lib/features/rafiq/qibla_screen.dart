import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  Coordinates _coords = Coordinates(30.0444, 31.2357);
  String _locationLabel = 'القاهرة، مصر';
  bool _isUpdating = false;
  bool _wasAligned = false;

  static const double _kaabaLat = 21.422487;
  static const double _kaabaLng = 39.826206;

  static const List<({String name, double lat, double lng})> _quickCities = [
    (name: 'القاهرة، مصر', lat: 30.0444, lng: 31.2357),
    (name: 'الإسكندرية، مصر', lat: 31.2001, lng: 29.9187),
    (name: 'الجيزة، مصر', lat: 30.0131, lng: 31.2089),
    (name: 'المنصورة، مصر', lat: 31.0409, lng: 31.3785),
    (name: 'طنطا، مصر', lat: 30.7865, lng: 31.0004),
    (name: 'الزقازيق، مصر', lat: 30.5877, lng: 31.5020),
    (name: 'أسيوط، مصر', lat: 27.1783, lng: 31.1859),
    (name: 'أسوان، مصر', lat: 24.0889, lng: 32.8998),
    (name: 'مكة المكرمة، السعودية', lat: 21.4225, lng: 39.8262),
    (name: 'المدينة المنورة، السعودية', lat: 24.4672, lng: 39.6111),
    (name: 'الرياض، السعودية', lat: 24.7136, lng: 46.6753),
    (name: 'دبي، الإمارات', lat: 25.2048, lng: 55.2708),
  ];

  @override
  void initState() {
    super.initState();
    _loadCoordinates();
  }

  Future<void> _loadCoordinates() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('saved_lat');
    final lng = prefs.getDouble('saved_lng');
    final locName = prefs.getString('saved_loc_name');

    if (lat != null && lng != null && mounted) {
      setState(() {
        _coords = Coordinates(lat, lng);
        _locationLabel = locName ?? 'موقعك المحفوظ';
      });
    } else {
      _refreshLocation();
    }
  }

  double _distanceToKaabaKm(double lat1, double lng1) {
    const double r = 6371.0;
    final dLat = (_kaabaLat - lat1) * math.pi / 180.0;
    final dLng = (_kaabaLng - lng1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(_kaabaLat * math.pi / 180.0) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  Future<void> _refreshLocation() async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يرجى تفعيل الموقع (GPS) أو اختيار مدينتك من القائمة'),
            ),
          );
        }
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('saved_lat', pos.latitude);
      await prefs.setDouble('saved_lng', pos.longitude);
      await prefs.setString(
        'saved_loc_name',
        'موقعك الحالي (${pos.latitude.toStringAsFixed(2)}, ${pos.longitude.toStringAsFixed(2)})',
      );
      await prefs.setString('saved_loc_mode', 'GPS مباشر');

      if (mounted) {
        setState(() {
          _coords = Coordinates(pos.latitude, pos.longitude);
          _locationLabel =
              'موقعك الحالي (${pos.latitude.toStringAsFixed(2)}, ${pos.longitude.toStringAsFixed(2)})';
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _openCityPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThalabTheme.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'اختيار المدينة أوفلاين للقبلة',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 290,
              child: ListView.separated(
                itemCount: _quickCities.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, idx) {
                  final c = _quickCities[idx];
                  return ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    tileColor: ThalabTheme.creamBackground,
                    leading: const Icon(Icons.location_city_rounded, color: ThalabTheme.foxOrange),
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setDouble('saved_lat', c.lat);
                      await prefs.setDouble('saved_lng', c.lng);
                      await prefs.setString('saved_loc_name', c.name);
                      await prefs.setString('saved_loc_mode', 'أوفلاين');
                      if (mounted) {
                        setState(() {
                          _coords = Coordinates(c.lat, c.lng);
                          _locationLabel = c.name;
                        });
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qiblaDirection = Qibla(_coords).direction;
    final distanceKm = _distanceToKaabaKm(_coords.latitude, _coords.longitude);

    return Scaffold(
      appBar: AppBar(
        title: const Text('اتجاه القبلة'),
        actions: [
          IconButton(
            tooltip: 'اختيار المدينة أوفلاين',
            icon: const Icon(Icons.edit_location_alt_rounded, color: ThalabTheme.foxOrange),
            onPressed: _openCityPickerSheet,
          ),
          IconButton(
            tooltip: 'تحديث الموقع (GPS)',
            icon: _isUpdating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: ThalabTheme.foxOrange),
                  )
                : const Icon(Icons.my_location_rounded, color: ThalabTheme.foxOrange),
            onPressed: _refreshLocation,
          ),
        ],
      ),
      body: StreamBuilder<CompassEvent>(
        stream: FlutterCompass.events,
        builder: (context, snapshot) {
          final hasCompass = snapshot.hasData && snapshot.data?.heading != null;
          final heading = snapshot.data?.heading ?? 0.0;
          final accuracy = snapshot.data?.accuracy;
          final lowAccuracy = accuracy != null && accuracy > 25;

          final angleDiff = (qiblaDirection - heading) * (math.pi / 180);
          final normalizedDiff = ((qiblaDirection - heading + 540) % 360) - 180;
          final isAligned = hasCompass && normalizedDiff.abs() < 5.0;

          if (isAligned && !_wasAligned) {
            HapticFeedback.mediumImpact();
          }
          _wasAligned = isAligned;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _openCityPickerSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: ThalabTheme.cardSurface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: ThalabTheme.softBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 16, color: ThalabTheme.foxOrange),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: isAligned
                          ? const Color(0xFF1B8A5A).withOpacity(0.15)
                          : ThalabTheme.foxOrange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isAligned
                            ? const Color(0xFF1B8A5A)
                            : ThalabTheme.foxOrange.withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      !hasCompass
                          ? 'زاوية القبلة: ${qiblaDirection.toStringAsFixed(1)}° من الشمال'
                          : isAligned
                              ? 'أنت الآن باتجاه الكعبة المشرفة تماماً ✓'
                              : normalizedDiff > 0
                                  ? 'أدِر الهاتف لليمين بمقدار ${normalizedDiff.abs().toStringAsFixed(0)}°'
                                  : 'أدِر الهاتف لليسار بمقدار ${normalizedDiff.abs().toStringAsFixed(0)}°',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isAligned ? const Color(0xFF1B8A5A) : ThalabTheme.foxOrange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 0,
                        child: Container(
                          width: 4,
                          height: 18,
                          decoration: BoxDecoration(
                            color: isAligned ? const Color(0xFF1B8A5A) : ThalabTheme.darkSlate,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        width: 285,
                        height: 285,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ThalabTheme.cardSurface,
                          border: Border.all(
                            color: isAligned ? const Color(0xFF1B8A5A) : ThalabTheme.foxOrange,
                            width: isAligned ? 6 : 4.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isAligned ? const Color(0xFF1B8A5A) : ThalabTheme.foxOrange)
                                  .withOpacity(0.16),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: CustomPaint(
                          painter: _CompassDialPainter(
                            headingDeg: hasCompass ? heading : 0.0,
                            activeColor:
                                isAligned ? const Color(0xFF1B8A5A) : ThalabTheme.foxOrange,
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Transform.rotate(
                          angle: angleDiff,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  color: isAligned
                                      ? const Color(0xFF1B8A5A)
                                      : const Color(0xFF1E1E1E),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFD4AF37),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.mosque_rounded,
                                  color: Color(0xFFD4AF37),
                                  size: 28,
                                ),
                              ),
                              Container(
                                width: 6,
                                height: 86,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      isAligned ? const Color(0xFF1B8A5A) : ThalabTheme.foxOrange,
                                      (isAligned ? const Color(0xFF1B8A5A) : ThalabTheme.foxOrange)
                                          .withOpacity(0.25),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 82),
                            ],
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: ThalabTheme.darkSlate,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: _QiblaInfoTile(
                          icon: Icons.explore_rounded,
                          label: 'زاوية القبلة',
                          value: '${qiblaDirection.toStringAsFixed(1)}°',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QiblaInfoTile(
                          icon: Icons.straighten_rounded,
                          label: 'المسافة للكعبة',
                          value: '${distanceKm.toStringAsFixed(0)} كم',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (lowAccuracy)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.amber),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'دقة الحساس المغناطيسي منخفضة؛ حرّك الهاتف في الهواء على شكل رقم 8 لمعايرة البوصلة.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Text(
                    'ضع الهاتف أفقياً بعيداً عن المعادن وأدِره حتى ينطبق رمز الكعبة مع المؤشر العلوي ويهتز الهاتف',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: ThalabTheme.mutedSlate, height: 1.5),
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

class _QiblaInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _QiblaInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ThalabTheme.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ThalabTheme.softBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: ThalabTheme.foxOrange, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11.5, color: ThalabTheme.mutedSlate)),
              Text(
                value,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompassDialPainter extends CustomPainter {
  final double headingDeg;
  final Color activeColor;

  _CompassDialPainter({
    required this.headingDeg,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-headingDeg * math.pi / 180);

    final tickPaint = Paint()..strokeCap = StrokeCap.round;

    for (int deg = 0; deg < 360; deg += 15) {
      final isMajor = deg % 90 == 0;
      final isMid = deg % 45 == 0;
      tickPaint.color = deg == 0
          ? Colors.redAccent
          : isMajor
              ? activeColor
              : ThalabTheme.mutedSlate.withOpacity(0.35);
      tickPaint.strokeWidth = isMajor ? 2.6 : 1.3;

      final outerR = radius - 10;
      final innerR = outerR - (isMajor ? 12 : (isMid ? 8 : 5));
      final rad = (deg - 90) * math.pi / 180;

      canvas.drawLine(
        Offset(math.cos(rad) * innerR, math.sin(rad) * innerR),
        Offset(math.cos(rad) * outerR, math.sin(rad) * outerR),
        tickPaint,
      );
    }

    const labels = {0: 'ش', 90: 'ق', 180: 'ج', 270: 'غ'};
    labels.forEach((deg, text) {
      final rad = (deg - 90) * math.pi / 180;
      final rText = radius - 34;
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: deg == 0 ? Colors.redAccent : ThalabTheme.darkSlate,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout();

      canvas.save();
      canvas.translate(math.cos(rad) * rText, math.sin(rad) * rText);
      canvas.rotate(headingDeg * math.pi / 180);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    });

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CompassDialPainter oldDelegate) =>
      oldDelegate.headingDeg != headingDeg || oldDelegate.activeColor != activeColor;
}
