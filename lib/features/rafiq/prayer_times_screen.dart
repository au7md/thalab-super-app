import 'dart:async';
import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../core/rafiq_notifications_service.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  PrayerTimes? _prayerTimes;
  String _locationLabel = 'القاهرة، مصر (افتراضي)';
  bool _loading = true;
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;
  String _nextPrayerName = '';

  @override
  void initState() {
    super.initState();
    _loadPrayerTimes();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPrayerTimes() async {
    double lat = 30.0444;
    double lng = 31.2357;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 5),
          ),
        );
        lat = pos.latitude;
        lng = pos.longitude;
        _locationLabel = 'موقعك الحالي (${lat.toStringAsFixed(2)}, ${lng.toStringAsFixed(2)})';
      }
    } catch (_) {
      // الاعتماد على إحداثيات القاهرة كخيار احتياطي
    }

    final coordinates = Coordinates(lat, lng);
    final params = CalculationMethod.egyptian.getParameters();
    params.madhab = Madhab.shafi;

    final date = DateComponents.from(DateTime.now());
    final times = PrayerTimes(coordinates, date, params);

    await _scheduleAllPrayers(times);

    if (!mounted) return;
    setState(() {
      _prayerTimes = times;
      _loading = false;
    });
    _updateCountdown();
  }

  Future<void> _scheduleAllPrayers(PrayerTimes times) async {
    final service = RafiqNotificationsService.instance;
    final map = <int, MapEntry<String, DateTime>>{
      101: MapEntry('الفجر', times.fajr),
      102: MapEntry('الظهر', times.dhuhr),
      103: MapEntry('العصر', times.asr),
      104: MapEntry('المغرب', times.maghrib),
      105: MapEntry('العشاء', times.isha),
    };
    for (final entry in map.entries) {
      await service.schedulePrayerNotification(
        id: entry.key,
        prayerName: entry.value.key,
        scheduledTime: entry.value.value,
      );
    }
  }

  void _updateCountdown() {
    final times = _prayerTimes;
    if (times == null) return;

    final now = DateTime.now();
    final next = times.nextPrayer();
    DateTime? targetTime = times.timeForPrayer(next);
    String name = _arabicPrayerName(next);

    if (targetTime == null || next == Prayer.none) {
      targetTime = times.fajr.add(const Duration(days: 1));
      name = 'الفجر';
    }

    if (!mounted) return;
    setState(() {
      _nextPrayerName = name;
      _remaining = targetTime!.difference(now);
      if (_remaining.isNegative) _remaining = Duration.zero;
    });
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

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _prayerTimes == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final times = _prayerTimes!;
    final fmt = DateFormat('hh:mm a', 'ar');
    final items = [
      ('الفجر', times.fajr, Icons.nights_stay_outlined, Prayer.fajr),
      ('الشروق', times.sunrise, Icons.wb_twilight_rounded, Prayer.sunrise),
      ('الظهر', times.dhuhr, Icons.wb_sunny_outlined, Prayer.dhuhr),
      ('العصر', times.asr, Icons.wb_sunny_rounded, Prayer.asr),
      ('المغرب', times.maghrib, Icons.nights_stay_rounded, Prayer.maghrib),
      ('العشاء', times.isha, Icons.bedtime_outlined, Prayer.isha),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('مواقيت الصلاة'),
        actions: [
          IconButton(
            tooltip: 'تحديث الموقع',
            onPressed: () {
              setState(() => _loading = true);
              _loadPrayerTimes();
            },
            icon: const Icon(Icons.my_location_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF0F3D3E), Color(0xFF1E6F5C)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _locationLabel,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'المتبقي على صلاة $_nextPrayerName',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDuration(_remaining),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...items.map((item) {
            final isNext = times.nextPrayer() == item.$4;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isNext
                    ? const Color(0xFF1E6F5C).withValues(alpha: 0.14)
                    : Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isNext ? const Color(0xFF1E6F5C) : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Icon(item.$3, color: const Color(0xFF1E6F5C)),
                  const SizedBox(width: 12),
                  Text(
                    item.$1,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isNext ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    fmt.format(item.$2),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
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
