import 'dart:async';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/rafiq_notifications_service.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  PrayerTimes? _prayerTimes;
  Coordinates _coords = Coordinates(30.0444, 31.2357); // القاهرة كافتراضي
  String _locationLabel = 'القاهرة، مصر (اضغط لتحديث موقعك)';
  bool _isLoadingLocation = false;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _initSavedLocation();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _initSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('saved_lat');
    final lng = prefs.getDouble('saved_lng');
    final savedLocName = prefs.getString('saved_loc_name');

    if (lat != null && lng != null) {
      _coords = Coordinates(lat, lng);
      _locationLabel = savedLocName ?? 'موقعك المحفوظ';
    }

    _calculatePrayerTimes();
    if (lat == null || lng == null) {
      _updateLocation();
    }
  }

  void _calculatePrayerTimes() {
    final params = CalculationMethod.egyptian.getParameters();
    params.madhab = Madhab.shafi;
    final date = DateComponents.from(DateTime.now());
    setState(() {
      _prayerTimes = PrayerTimes(_coords, date, params);
    });
  }

  Future<void> _updateLocation() async {
    if (_isLoadingLocation) return;
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يرجى تفعيل خدمة الموقع (GPS) لتحديث المواقيت')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('saved_lat', pos.latitude);
      await prefs.setDouble('saved_lng', pos.longitude);
      await prefs.setDouble('prayer_lat', pos.latitude);
      await prefs.setDouble('prayer_lng', pos.longitude);
      await prefs.setString(
        'saved_loc_name',
        'موقعك الحالي (${pos.latitude.toStringAsFixed(2)}, ${pos.longitude.toStringAsFixed(2)})',
      );

      setState(() {
        _coords = Coordinates(pos.latitude, pos.longitude);
        _locationLabel =
            'موقعك الحالي (${pos.latitude.toStringAsFixed(2)}, ${pos.longitude.toStringAsFixed(2)})';
      });
      _calculatePrayerTimes();

      await RafiqNotificationsService.syncAllScheduledNotifications(
        lat: pos.latitude,
        lng: pos.longitude,
        params: CalculationMethod.egyptian.getParameters(),
      );
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'م' : 'ص';
    return '$h:$m $period';
  }

  String _arabicPrayerName(Prayer p) {
    switch (p) {
      case Prayer.fajr:
        return 'الفجر';
      case Prayer.sunrise:
        return 'الشروق';
      case Prayer.dhuhr:
        return 'الظهر';
      case Prayer.asr:
        return 'العصر';
      case Prayer.maghrib:
        return 'المغرب';
      case Prayer.isha:
        return 'العشاء';
      case Prayer.none:
        return 'الفجر';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pt = _prayerTimes;
    final nextPrayer = pt?.nextPrayer() ?? Prayer.none;
    DateTime? nextTime = pt?.timeForPrayer(nextPrayer);
    if (nextPrayer == Prayer.none && pt != null) {
      nextTime = pt.fajr.add(const Duration(days: 1));
    }

    final remaining = nextTime != null ? nextTime.difference(DateTime.now()) : Duration.zero;
    final remHours = remaining.inHours.clamp(0, 23).toString().padLeft(2, '0');
    final remMins = (remaining.inMinutes % 60).clamp(0, 59).toString().padLeft(2, '0');
    final remSecs = (remaining.inSeconds % 60).clamp(0, 59).toString().padLeft(2, '0');

    final prayersList = [
      {'id': Prayer.fajr, 'name': 'الفجر', 'time': pt?.fajr, 'icon': Icons.wb_twilight_rounded},
      {'id': Prayer.sunrise, 'name': 'الشروق', 'time': pt?.sunrise, 'icon': Icons.wb_sunny_outlined},
      {'id': Prayer.dhuhr, 'name': 'الظهر', 'time': pt?.dhuhr, 'icon': Icons.wb_sunny_rounded},
      {'id': Prayer.asr, 'name': 'العصر', 'time': pt?.asr, 'icon': Icons.sunny_snowing},
      {'id': Prayer.maghrib, 'name': 'المغرب', 'time': pt?.maghrib, 'icon': Icons.nights_stay_outlined},
      {'id': Prayer.isha, 'name': 'العشاء', 'time': pt?.isha, 'icon': Icons.bedtime_rounded},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('مواقيت الصلاة'),
        actions: [
          IconButton(
            tooltip: 'تحديث الموقع (GPS)',
            icon: _isLoadingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: ThalabTheme.foxOrange),
                  )
                : const Icon(Icons.my_location_rounded, color: ThalabTheme.foxOrange),
            onPressed: _updateLocation,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: ThalabTheme.foxOrange.withOpacity(0.26),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on_rounded, color: Colors.white70, size: 15),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _locationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'الصلاة القادمة: ${_arabicPrayerName(nextPrayer)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$remHours:$remMins:$remSecs',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const Text(
                  'الوقت المتبقي للأذان',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...prayersList.map((p) {
            final isNext = p['id'] == nextPrayer;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isNext ? ThalabTheme.foxOrange.withOpacity(0.1) : ThalabTheme.cardSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isNext ? ThalabTheme.foxOrange : ThalabTheme.softBorder,
                  width: isNext ? 1.8 : 1.2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    p['icon'] as IconData,
                    color: isNext ? ThalabTheme.foxOrange : ThalabTheme.mutedSlate,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      p['name'] as String,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isNext ? ThalabTheme.foxOrange : ThalabTheme.darkSlate,
                      ),
                    ),
                  ),
                  Text(
                    _formatTime(p['time'] as DateTime?),
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: isNext ? ThalabTheme.foxOrange : ThalabTheme.darkSlate,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
