import 'dart:math' as math;
import 'package:flutter/material.dart';
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
  Coordinates _coords = Coordinates(30.0444, 31.2357); // القاهرة كافتراضي
  String _locationLabel = 'القاهرة، مصر';
  bool _isUpdating = false;

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

  Future<void> _refreshLocation() async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يرجى تفعيل الموقع (GPS) لتحديد اتجاه القبلة بدقة')),
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

  @override
  Widget build(BuildContext context) {
    final qiblaDirection = Qibla(_coords).direction;

    return Scaffold(
      appBar: AppBar(
        title: const Text('اتجاه القبلة'),
        actions: [
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
          final heading = snapshot.data?.heading ?? 0.0;
          final angleDiff = (qiblaDirection - heading) * (math.pi / 180);
          final normalizedDiff = ((qiblaDirection - heading + 540) % 360) - 180;
          final isAligned = normalizedDiff.abs() < 6.0;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on_rounded, size: 16, color: ThalabTheme.foxOrange),
                      const SizedBox(width: 4),
                      Text(
                        _locationLabel,
                        style: const TextStyle(fontSize: 13, color: ThalabTheme.mutedSlate),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: isAligned
                          ? const Color(0xFF1B8A5A).withOpacity(0.14)
                          : ThalabTheme.foxOrange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      isAligned
                          ? 'أنت الآن باتجاه القبلة تماماً ✓'
                          : 'زاوية القبلة: ${qiblaDirection.toStringAsFixed(1)}° من الشمال',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: isAligned ? const Color(0xFF1B8A5A) : ThalabTheme.foxOrange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 270,
                        height: 270,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ThalabTheme.cardSurface,
                          border: Border.all(
                            color: isAligned ? const Color(0xFF1B8A5A) : ThalabTheme.foxOrange,
                            width: 4.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                      ),
                      Transform.rotate(
                        angle: angleDiff,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color: isAligned ? const Color(0xFF1B8A5A) : ThalabTheme.foxOrange,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.mosque_rounded, color: Colors.white, size: 30),
                            ),
                            Container(
                              width: 6,
                              height: 90,
                              decoration: BoxDecoration(
                                color: isAligned ? const Color(0xFF1B8A5A) : ThalabTheme.foxOrange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 75),
                          ],
                        ),
                      ),
                      Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: ThalabTheme.darkSlate,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'ضع الهاتف أفقياً وأدره حتى يشير رمز الكعبة للأعلى ويتحول الإطار للأخضر',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: ThalabTheme.mutedSlate, height: 1.5),
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
