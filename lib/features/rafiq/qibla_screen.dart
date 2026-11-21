import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adhan/adhan.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  double _qiblaAngle = 136.0; // زاوية القبلة الافتراضية للقاهرة
  String _locationLabel = 'القاهرة، مصر (افتراضي)';
  bool _vibratedOnAlign = false;

  @override
  void initState() {
    super.initState();
    _detectLocation();
  }

  Future<void> _detectLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition();
        final qibla = Qibla(Coordinates(pos.latitude, pos.longitude));
        if (mounted) {
          setState(() {
            _qiblaAngle = qibla.direction;
            _locationLabel =
                'موقعك الحالي (${pos.latitude.toStringAsFixed(2)}, ${pos.longitude.toStringAsFixed(2)})';
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اتجاه القبلة'),
        actions: [
          IconButton(
            tooltip: 'تحديث الموقع GPS',
            icon: const Icon(Icons.my_location_rounded, color: ThalabTheme.foxOrange),
            onPressed: _detectLocation,
          ),
        ],
      ),
      body: StreamBuilder<CompassEvent>(
        stream: FlutterCompass.events,
        builder: (context, snapshot) {
          final double heading = snapshot.data?.heading ?? 0.0;
          final double diff = (_qiblaAngle - heading) % 360;
          final bool isAligned = diff.abs() < 4 || (360 - diff.abs()) < 4;

          if (isAligned && !_vibratedOnAlign) {
            _vibratedOnAlign = true;
            HapticFeedback.mediumImpact();
          } else if (!isAligned) {
            _vibratedOnAlign = false;
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
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
                        const Icon(Icons.location_on_rounded, color: ThalabTheme.foxOrange, size: 18),
                        const SizedBox(width: 6),
                        Text(_locationLabel, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isAligned ? 'أنت الآن في اتجاه القبلة الصحيح ✓' : 'أدر الهاتف لمحاذاة سهم الكعبة',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isAligned ? Colors.green : ThalabTheme.darkSlate,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // قرص البوصلة الدوار
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ThalabTheme.cardSurface,
                      border: Border.all(
                        color: isAligned ? Colors.green : ThalabTheme.foxOrange,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isAligned ? Colors.green : ThalabTheme.foxOrange).withOpacity(0.22),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Positioned(
                          top: 14,
                          child: Text('N', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                        ),
                        Transform.rotate(
                          angle: ((_qiblaAngle - heading) * (math.pi / 180)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isAligned ? Colors.green : ThalabTheme.foxOrange,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.mosque_rounded, color: Colors.white, size: 30),
                              ),
                              Container(
                                width: 6,
                                height: 85,
                                decoration: BoxDecoration(
                                  color: isAligned ? Colors.green : ThalabTheme.foxOrange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 55),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'زاوية القبلة: ${_qiblaAngle.toStringAsFixed(1)}°',
                    style: const TextStyle(color: ThalabTheme.mutedSlate, fontSize: 14),
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
