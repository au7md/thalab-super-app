import 'dart:async';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/storage_service.dart';

class CityPreset {
  final String name;
  final double lat;
  final double lng;
  final CalculationMethod method;

  const CityPreset(this.name, this.lat, this.lng, this.method);
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
  bool _notificationsEnabled = false;

  double _lat = 30.0444;
  double _lng = 31.2357;
  String _cityName = 'القاهرة، مصر';
  String _methodKey = 'egyptian';
  bool _isHanafi = false;

  static const List<CityPreset> _cities = [
    CityPreset('القاهرة، مصر', 30.0444, 31.2357, CalculationMethod.egyptian),
    CityPreset('الإسكندرية، مصر', 31.2001, 29.9187, CalculationMethod.egyptian),
    CityPreset('المنصورة، مصر', 31.0409, 31.3785, CalculationMethod.egyptian),
    CityPreset('أسوان، مصر', 24.0889, 32.8998, CalculationMethod.egyptian),
    CityPreset('مكة المكرمة', 21.4225, 39.8262, CalculationMethod.umm_al_qura),
    CityPreset('المدينة المنورة', 24.4672, 39.6112, CalculationMethod.umm_al_qura),
    CityPreset('الرياض، السعودية', 24.7136, 46.6753, CalculationMethod.umm_al_qura),
    CityPreset('دبي، الإمارات', 25.2048, 55.2708, CalculationMethod.dubai),
    CityPreset('القدس، فلسطين', 31.7683, 35.2137, CalculationMethod.muslim_world_league),
    CityPreset('عمّان، الأردن', 31.9454, 35.9284, CalculationMethod.muslim_world_league),
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
      _cityName = prefs.getString('prayer_city') ?? 'القاهرة، مصر';
      _methodKey = prefs.getString('prayer_method') ?? 'egyptian';
      _isHanafi = prefs.getBool('prayer_hanafi') ?? false;
    });
    _calculatePrayers();
  }

  Future<void> _saveLocationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('prayer_lat', _lat);
    await prefs.setDouble('prayer_lng', _lng);
    await prefs.setString('prayer_city', _cityName);
    await prefs.setString('prayer_method', _methodKey);
    await prefs.setBool('prayer_hanafi', _isHanafi);
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

  Future<void> _detectGpsLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition();
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
          _cityName = 'موقعي الحالي GPS (${_lat.toStringAsFixed(2)}, ${_lng.toStringAsFixed(2)})';
        });
        await _saveLocationSettings();
        _calculatePrayers();
      }
    } catch (_) {}
  }

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThalabTheme.cardSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'إعدادات الموقع والحساب الفلكي',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThalabTheme.foxOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _detectGpsLocation();
                  },
                  icon: const Icon(Icons.my_location_rounded),
                  label: const Text('تحديد موقعي تلقائياً عبر GPS'),
                ),
              ),
              const SizedBox(height: 16),
              const Text('أو اختر المدينة يدوياً:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _cities.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final city = _cities[index];
                    return ActionChip(
                      label: Text(city.name),
                      backgroundColor: ThalabTheme.creamBackground,
                      onPressed: () async {
                        setState(() {
                          _lat = city.lat;
                          _lng = city.lng;
                          _cityName = city.name;
                        });
                        await _saveLocationSettings();
                        _calculatePrayers();
                        if (mounted) Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text('طريقة الحساب:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('الهيئة المصرية'),
                    selected: _methodKey == 'egyptian',
                    selectedColor: ThalabTheme.foxOrange,
                    onSelected: (_) async {
                      setSheetState(() => _methodKey = 'egyptian');
                      setState(() => _methodKey = 'egyptian');
                      await _saveLocationSettings();
                      _calculatePrayers();
                    },
                  ),
                  ChoiceChip(
                    label: const Text('أم القرى'),
                    selected: _methodKey == 'umm_al_qura',
                    selectedColor: ThalabTheme.foxOrange,
                    onSelected: (_) async {
                      setSheetState(() => _methodKey = 'umm_al_qura');
                      setState(() => _methodKey = 'umm_al_qura');
                      await _saveLocationSettings();
                      _calculatePrayers();
                    },
                  ),
                  ChoiceChip(
                    label: const Text('رابطة العالم الإسلامي'),
                    selected: _methodKey == 'mwl',
                    selectedColor: ThalabTheme.foxOrange,
                    onSelected: (_) async {
                      setSheetState(() => _methodKey = 'mwl');
                      setState(() => _methodKey = 'mwl');
                      await _saveLocationSettings();
                      _calculatePrayers();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('المذهب الحنفي (في وقت العصر)'),
                activeColor: ThalabTheme.foxOrange,
                value: _isHanafi,
                onChanged: (val) async {
                  setSheetState(() => _isHanafi = val);
                  setState(() => _isHanafi = val);
                  await _saveLocationSettings();
                  _calculatePrayers();
                },
              ),
            ],
          ),
        ),
      ),
    );
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
      default:
        return 'الفجر';
    }
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '00:00:00';
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _activateDailyAlerts() async {
    await StorageService.scheduleDailyReminder(
      id: 101,
      title: 'أذكار الصباح — رفيق',
      body: 'ابدأ يومك بذكر الله وطمأنينة القلب.',
      hour: 6,
      minute: 30,
    );
    await StorageService.scheduleDailyReminder(
      id: 102,
      title: 'أذكار المساء — رفيق',
      body: 'حان وقت أذكار المساء وحفظ النفس.',
      hour: 17,
      minute: 30,
    );
    setState(() => _notificationsEnabled = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تفعيل تنبيهات الأذكار اليومية ✓'),
          backgroundColor: ThalabTheme.foxOrange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('hh:mm a', 'ar');
    final currentPrayer = _prayerTimes.currentPrayer();

    final list = [
      ('الفجر', _prayerTimes.fajr, Prayer.fajr, Icons.wb_twilight_rounded),
      ('الشروق', _prayerTimes.sunrise, Prayer.sunrise, Icons.wb_sunny_outlined),
      ('الظهر', _prayerTimes.dhuhr, Prayer.dhuhr, Icons.wb_sunny_rounded),
      ('العصر', _prayerTimes.asr, Prayer.asr, Icons.sunny_snowing),
      ('المغرب', _prayerTimes.maghrib, Prayer.maghrib, Icons.nights_stay_outlined),
      ('العشاء', _prayerTimes.isha, Prayer.isha, Icons.bedtime_rounded),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('مواقيت الصلاة'),
        actions: [
          IconButton(
            tooltip: 'تخصيص الموقع وطريقة الحساب',
            icon: const Icon(Icons.tune_rounded, color: ThalabTheme.foxOrange),
            onPressed: _openSettingsSheet,
          ),
          IconButton(
            tooltip: 'تنبيهات الأذكار',
            icon: Icon(
              _notificationsEnabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              color: ThalabTheme.foxOrange,
            ),
            onPressed: _activateDailyAlerts,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: ThalabTheme.foxOrange.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'المتبقي على أذان $_nextPrayerName',
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDuration(_timeRemaining),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _openSettingsSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded, color: Colors.white, size: 15),
                        const SizedBox(width: 4),
                        Text(_cityName, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...list.map((item) {
            final isCurrent = item.$3 == currentPrayer;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: isCurrent
                    ? ThalabTheme.foxOrange.withOpacity(0.12)
                    : ThalabTheme.cardSurface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isCurrent ? ThalabTheme.foxOrange : ThalabTheme.softBorder,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(item.$4, color: ThalabTheme.foxOrange, size: 24),
                  const SizedBox(width: 14),
                  Text(
                    item.$1,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatter.format(item.$2),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isCurrent ? ThalabTheme.foxOrange : ThalabTheme.darkSlate,
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
