import 'dart:async';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/rafiq_notifications_service.dart';

class EgyptGovernorate {
  final String name;
  final double lat;
  final double lng;

  const EgyptGovernorate(this.name, this.lat, this.lng);
}

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  late PrayerTimes _prayerTimes;
  late Timer _timer;
  Duration _timeRemaining = Duration.zero;
  String _nextPrayerName = '';
  bool _isLocating = false;

  double _lat = 30.0444;
  double _lng = 31.2357;
  String _locationTitle = 'القاهرة، مصر';
  String _methodKey = 'egyptian';
  bool _isHanafi = false;

  static const List<EgyptGovernorate> _egyptGovernorates = [
    EgyptGovernorate('القاهرة', 30.0444, 31.2357),
    EgyptGovernorate('الجيزة', 30.0131, 31.2089),
    EgyptGovernorate('الإسكندرية', 31.2001, 29.9187),
    EgyptGovernorate('الدقهلية (المنصورة)', 31.0409, 31.3785),
    EgyptGovernorate('الشرقية (الزقازيق)', 30.5877, 31.5020),
    EgyptGovernorate('المنوفية (شبين الكوم)', 30.5503, 31.0106),
    EgyptGovernorate('القليوبية (بنها)', 30.4591, 31.1786),
    EgyptGovernorate('البحيرة (دمنهور)', 31.0341, 30.4682),
    EgyptGovernorate('الغربية (طنطا)', 30.7865, 31.0004),
    EgyptGovernorate('كفر الشيخ', 31.1107, 30.9388),
    EgyptGovernorate('دمياط', 31.4175, 31.8144),
    EgyptGovernorate('بورسعيد', 31.2653, 32.3019),
    EgyptGovernorate('الإسماعيلية', 30.5965, 32.2715),
    EgyptGovernorate('السويس', 29.9668, 32.5498),
    EgyptGovernorate('الفيوم', 29.3084, 30.8428),
    EgyptGovernorate('بني سويف', 29.0661, 31.0994),
    EgyptGovernorate('المنيا', 28.1099, 30.7503),
    EgyptGovernorate('أسيوط', 27.1783, 31.1859),
    EgyptGovernorate('سوهاج', 26.5591, 31.6957),
    EgyptGovernorate('قنا', 26.1551, 32.7160),
    EgyptGovernorate('الأقصر', 25.6872, 32.6396),
    EgyptGovernorate('أسوان', 24.0889, 32.8998),
    EgyptGovernorate('البحر الأحمر (الغردقة)', 27.2579, 33.8116),
    EgyptGovernorate('الوادي الجديد (الخارجة)', 25.4390, 30.5586),
    EgyptGovernorate('مطروح (مرسى مطروح)', 31.3543, 27.2373),
    EgyptGovernorate('شمال سيناء (العريش)', 31.1321, 33.8033),
    EgyptGovernorate('جنوب سيناء (الطور)', 28.2417, 33.6222),
  ];

  @override
  void initState() {
    super.initState();
    _calculatePrayers();
    _loadSavedLocation();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lat = prefs.getDouble('prayer_lat') ?? 30.0444;
      _lng = prefs.getDouble('prayer_lng') ?? 31.2357;
      _locationTitle = prefs.getString('prayer_city') ?? 'القاهرة، مصر';
      _methodKey = prefs.getString('prayer_method') ?? 'egyptian';
      _isHanafi = prefs.getBool('prayer_hanafi') ?? false;
    });
    _calculatePrayers();
  }

  Future<void> _saveLocationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('prayer_lat', _lat);
    await prefs.setDouble('prayer_lng', _lng);
    await prefs.setString('prayer_city', _locationTitle);
    await prefs.setString('prayer_method', _methodKey);
    await prefs.setBool('prayer_hanafi', _isHanafi);

    await RafiqNotificationsService.syncAllScheduledNotifications(
      lat: _lat,
      lng: _lng,
      params: _getParams(),
    );
  }

  CalculationParameters _getParams() {
    CalculationParameters params;
    switch (_methodKey) {
      case 'umm_al_qura':
        params = CalculationMethod.umm_al_qura.getParameters();
        break;
      case 'mwl':
        params = CalculationMethod.muslim_world_league.getParameters();
        break;
      default:
        params = CalculationMethod.egyptian.getParameters();
    }
    params.madhab = _isHanafi ? Madhab.hanafi : Madhab.shafi;
    return params;
  }

  void _calculatePrayers() {
    final coords = Coordinates(_lat, _lng);
    final date = DateComponents.from(DateTime.now());
    _prayerTimes = PrayerTimes(coords, date, _getParams());
    _updateCountdown();
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final next = _prayerTimes.nextPrayer();
    DateTime? nextTime = _prayerTimes.timeForPrayer(next);

    if (next == Prayer.none || nextTime == null) {
      final tomorrow = DateComponents.from(now.add(const Duration(days: 1)));
      final tomorrowPrayers = PrayerTimes(Coordinates(_lat, _lng), tomorrow, _getParams());
      nextTime = tomorrowPrayers.fajr;
      _nextPrayerName = 'الفجر';
    } else {
      _nextPrayerName = _arabicPrayerName(next);
    }

    if (mounted) {
      setState(() => _timeRemaining = nextTime!.difference(now));
    }
  }

  String _nearestGovernorateName(double lat, double lng) {
    EgyptGovernorate nearest = _egyptGovernorates.first;
    double minDistance = double.infinity;
    for (final gov in _egyptGovernorates) {
      final d = Geolocator.distanceBetween(lat, lng, gov.lat, gov.lng);
      if (d < minDistance) {
        minDistance = d;
        nearest = gov;
      }
    }
    return '${nearest.name}، مصر';
  }

  Future<void> _detectFastAccurateLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى تفعيل خدمة الموقع (GPS) من إعدادات الهاتف')),
        );
        setState(() => _isLocating = false);
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        Position? pos = await Geolocator.getLastKnownPosition();
        if (pos != null) {
          _lat = pos.latitude;
          _lng = pos.longitude;
          _locationTitle = _nearestGovernorateName(_lat, _lng);
          _calculatePrayers();
        }

        final currentPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );

        _lat = currentPos.latitude;
        _lng = currentPos.longitude;
        if (mounted) {
          setState(() => _locationTitle = _nearestGovernorateName(_lat, _lng));
        }
        await _saveLocationSettings();
        _calculatePrayers();
      }
