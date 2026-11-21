import 'dart:async';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/storage_service.dart';

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
  bool _notificationsEnabled = false;
  bool _isLocating = false;

  double _lat = 30.0444;
  double _lng = 31.2357;
  String _locationTitle = 'القاهرة، مصر';
  String _methodKey = 'egyptian';
  bool _isHanafi = false;

  // جميع محافظات مصر الـ 27 بإحداثياتها الدقيقة
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
        // 1. استخدام آخر موقع معروف للاستجابة الفورية
        Position? pos = await Geolocator.getLastKnownPosition();
        if (pos != null) {
          _lat = pos.latitude;
          _lng = pos.longitude;
          _locationTitle = _nearestGovernorateName(_lat, _lng);
          _calculatePrayers();
        }

        // 2. تحديث الموقع الحالي بدقة متوسطة وسريعة (بحد أقصى 5 ثوانٍ)
        final currentPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );

        _lat = currentPos.latitude;
        _lng = currentPos.longitude;
        String resolvedAddress = _nearestGovernorateName(_lat, _lng);

        // 3. تحويل الإحداثيات إلى اسم العنوان الحقيقي بالعربي
        try {
          await setLocaleIdentifier('ar');
          final placemarks = await placemarkFromCoordinates(_lat, _lng);
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final district = p.subAdministrativeArea ?? p.locality ?? '';
            final gov = p.administrativeArea ?? '';
            final formatted = [district, gov].where((e) => e.isNotEmpty).join('، ');
            if (formatted.isNotEmpty) {
              resolvedAddress = formatted;
            }
          }
        } catch (_) {}

        if (mounted) {
          setState(() => _locationTitle = resolvedAddress);
        }
        await _saveLocationSettings();
        _calculatePrayers();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحديد الموقع تلقائياً، يمكنك اختيار المحافظة يدوياً')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _openSettingsSheet() {
    String filter = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: ThalabTheme.cardSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final filteredGovs = _egyptGovernorates
              .where((g) => g.name.contains(filter.trim()))
              .toList();

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            maxChildSize: 0.9,
            builder: (_, scrollCtrl) => ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                const Text(
                  'تحديد الموقع وإعدادات المواقيت',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThalabTheme.foxOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _detectFastAccurateLocation();
                    },
                    icon: const Icon(Icons.my_location_rounded),
                    label: const Text('تحديد موقعي التلقائي الآن (GPS)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('اختيار المحافظة يدوياً (27 محافظة):', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (val) => setSheetState(() => filter = val),
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم المحافظة...',
                    prefixIcon: const Icon(Icons.search_rounded, color: ThalabTheme.foxOrange),
                    filled: true,
                    fillColor: ThalabTheme.creamBackground,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: filteredGovs.map((gov) {
                    final isSelected = _locationTitle.contains(gov.name);
                    return ChoiceChip(
                      label: Text(
                        gov.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : ThalabTheme.darkSlate,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: ThalabTheme.foxOrange,
                      backgroundColor: ThalabTheme.creamBackground,
                      onSelected: (_) async {
                        setState(() {
                          _lat = gov.lat;
                          _lng = gov.lng;
                          _locationTitle = '${gov.name}، مصر';
                        });
                        await _saveLocationSettings();
                        _calculatePrayers();
                        if (mounted) Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                const Text('طريقة الحساب الفلكي:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('الهيئة المصرية العامة'),
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
                const SizedBox(height: 8),
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
          );
        },
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
            tooltip: 'تحديد المحافظة أو GPS',
            icon: const Icon(Icons.location_city_rounded, color: ThalabTheme.foxOrange),
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
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _openSettingsSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isLocating)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        else
                          const Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _locationTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
