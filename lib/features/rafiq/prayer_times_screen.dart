import 'package:clock/clock.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/rafiq_notifications_service.dart';

class OfflineCityPreset {
  final String name;
  final String country;
  final double lat;
  final double lng;

  const OfflineCityPreset(this.name, this.country, this.lat, this.lng);
}

class PrayerTimesScreen extends StatefulWidget {
  final int initialTab;
  const PrayerTimesScreen({super.key, this.initialTab = 0});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  PrayerTimes? _prayerTimes;
  DateTime? _tomorrowFajr;
  String? _prayerTimesDateKey;
  int debugCalcCount = 0;
  String? get debugPrayerTimesDateKey => _prayerTimesDateKey;
  DateTime? get debugFajrTime => _prayerTimes?.fajr;
  DateTime? get debugTomorrowFajr => _tomorrowFajr;
  Coordinates _coords = Coordinates(30.0444, 31.2357);
  String _locationLabel = 'القاهرة، مصر';
  String _locationMode = 'أوفلاين';
  bool _isLoadingLocation = false;
  int _hijriOffset = 0;
  Timer? _countdownTimer;

  Map<String, int> _todayPrayerStatus = {
    'fajr': 0,
    'dhuhr': 0,
    'asr': 0,
    'maghrib': 0,
    'isha': 0,
  };
  Map<String, bool> _todaySunnahDone = {
    'fajr': false,
    'dhuhr': false,
    'asr': false,
    'maghrib': false,
    'isha': false,
  };
  int _totalPrayerPoints = 0;

  Map<String, bool> _adhanNotifEnabled = {
    'fajr': true,
    'dhuhr': true,
    'asr': true,
    'maghrib': true,
    'isha': true,
  };
  Map<String, int> _beforeNotifMins = {
    'fajr': 15,
    'dhuhr': 10,
    'asr': 10,
    'maghrib': 10,
    'isha': 10,
  };
  Map<String, int> _afterNotifMins = {
    'fajr': 20,
    'dhuhr': 15,
    'asr': 15,
    'maghrib': 10,
    'isha': 15,
  };

  Map<String, String> _perPrayerMuezzin = {};

  static const List<String> _hijriMonthsAr = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  static const List<OfflineCityPreset> _offlineCities = [
    OfflineCityPreset('القاهرة', 'مصر', 30.0444, 31.2357),
    OfflineCityPreset('الجيزة', 'مصر', 30.0131, 31.2089),
    OfflineCityPreset('الإسكندرية', 'مصر', 31.2001, 29.9187),
    OfflineCityPreset('القليوبية (بنها)', 'مصر', 30.4591, 31.1786),
    OfflineCityPreset('الشرقية (الزقازيق)', 'مصر', 30.5877, 31.5020),
    OfflineCityPreset('الدقهلية (المنصورة)', 'مصر', 31.0409, 31.3785),
    OfflineCityPreset('الغربية (طنطا)', 'مصر', 30.7865, 31.0004),
    OfflineCityPreset('المنوفية (شبين الكوم)', 'مصر', 30.5586, 31.0118),
    OfflineCityPreset('البحيرة (دمنهور)', 'مصر', 31.0341, 30.4682),
    OfflineCityPreset('كفر الشيخ', 'مصر', 31.1107, 30.9388),
    OfflineCityPreset('دمياط', 'مصر', 31.4175, 31.8144),
    OfflineCityPreset('بورسعيد', 'مصر', 31.2653, 32.3019),
    OfflineCityPreset('الإسماعيلية', 'مصر', 30.5965, 32.2715),
    OfflineCityPreset('السويس', 'مصر', 29.9668, 32.5498),
    OfflineCityPreset('الفيوم', 'مصر', 29.3084, 30.8428),
    OfflineCityPreset('بني سويف', 'مصر', 29.0661, 31.0994),
    OfflineCityPreset('المنيا', 'مصر', 28.1099, 30.7503),
    OfflineCityPreset('أسيوط', 'مصر', 27.1783, 31.1859),
    OfflineCityPreset('سوهاج', 'مصر', 26.5591, 31.6957),
    OfflineCityPreset('قنا', 'مصر', 26.1551, 32.7160),
    OfflineCityPreset('الأقصر', 'مصر', 25.6872, 32.6396),
    OfflineCityPreset('أسوان', 'مصر', 24.0889, 32.8998),
    OfflineCityPreset('البحر الأحمر (الغردقة)', 'مصر', 27.2579, 33.8116),
    OfflineCityPreset('الوادي الجديد (الخارجة)', 'مصر', 25.4390, 30.5586),
    OfflineCityPreset('مطروح (مرسى مطروح)', 'مصر', 31.3543, 27.2373),
    OfflineCityPreset('شمال سيناء (العريش)', 'مصر', 31.1321, 33.8033),
    OfflineCityPreset('جنوب سيناء (الطور)', 'مصر', 28.2417, 33.6222),
    OfflineCityPreset('مكة المكرمة', 'السعودية', 21.4225, 39.8262),
    OfflineCityPreset('المدينة المنورة', 'السعودية', 24.4672, 39.6111),
    OfflineCityPreset('الرياض', 'السعودية', 24.7136, 46.6753),
    OfflineCityPreset('دبي', 'الإمارات', 25.2048, 55.2708),
    OfflineCityPreset('عمّان', 'الأردن', 31.9454, 35.9284),
    OfflineCityPreset('الكويت', 'الكويت', 29.3759, 47.9774),
    OfflineCityPreset('الدوحة', 'قطر', 25.2854, 51.5310),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    _initAllData();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // Midnight rollover: recompute prayer times for the new day.
      if (_prayerTimesDateKey != null && _prayerTimesDateKey != _todayDateKey) {
        _calculatePrayerTimes();
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardBg => Theme.of(context).cardColor;
  Color get _innerBg => Theme.of(context).scaffoldBackgroundColor;
  Color get _borderColor => _isDark ? ThalabTheme.darkBorder : ThalabTheme.softBorder;
  Color get _textColor => _isDark ? ThalabTheme.darkTextPrimary : ThalabTheme.darkSlate;

  String get _todayDateKey {
    final now = clock.now();
    return '${now.year}_${now.month}_${now.day}';
  }

  Future<void> _initAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('saved_lat');
    final lng = prefs.getDouble('saved_lng');
    final savedLocName = prefs.getString('saved_loc_name');
    final savedMode = prefs.getString('saved_loc_mode') ?? 'أوفلاين';
    final offset = prefs.getInt('hijri_day_offset') ?? 0;

    if (lat != null && lng != null) {
      _coords = Coordinates(lat, lng);
      _locationLabel = savedLocName ?? _nearestOfflineCityName(lat, lng);
      _locationMode = savedMode;
    }
    _hijriOffset = offset;

    final dateKey = _todayDateKey;
    final keys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    final loadedStatus = <String, int>{};
    final loadedSunnah = <String, bool>{};
    final loadedAdhan = <String, bool>{};
    final loadedBefore = <String, int>{};
    final loadedAfter = <String, int>{};
    final loadedMuezzin = <String, String>{};

    for (final k in keys) {
      loadedStatus[k] = prefs.getInt('prayer_log_${dateKey}_$k') ?? 0;
      loadedSunnah[k] = prefs.getBool('sunnah_log_${dateKey}_$k') ?? false;
      loadedAdhan[k] = prefs.getBool('prayer_notif_${k}_adhan') ?? true;
      loadedBefore[k] = prefs.getInt('prayer_notif_${k}_before') ?? (k == 'fajr' ? 15 : 10);
      loadedAfter[k] = prefs.getInt('prayer_notif_${k}_after') ?? (k == 'fajr' ? 20 : 15);
      loadedMuezzin[k] =
          prefs.getString('prayer_muezzin_$k') ?? (k == 'fajr' ? 'fajr_egypt' : 'mishary_afasy');
    }

    setState(() {
      _todayPrayerStatus = loadedStatus;
      _todaySunnahDone = loadedSunnah;
      _totalPrayerPoints = prefs.getInt('total_prayer_points') ?? 0;
      _adhanNotifEnabled = loadedAdhan;
      _beforeNotifMins = loadedBefore;
      _afterNotifMins = loadedAfter;
      _perPrayerMuezzin = loadedMuezzin;
    });

    _calculatePrayerTimes();
    if (lat == null || lng == null) {
      _updateLocationOnline();
    }
  }

  String _nearestOfflineCityName(double lat, double lng) {
    OfflineCityPreset best = _offlineCities.first;
    double bestDist = double.infinity;
    for (final c in _offlineCities) {
      final dLat = c.lat - lat;
      final dLng = c.lng - lng;
      final dist = dLat * dLat + dLng * dLng;
      if (dist < bestDist) {
        bestDist = dist;
        best = c;
      }
    }
    return '${best.name}، ${best.country}';
  }

  void _calculatePrayerTimes() {
    debugCalcCount++;
    final params = CalculationMethod.egyptian.getParameters();
    params.madhab = Madhab.shafi;
    final now = clock.now();
    final date = DateComponents.from(now);
    // Tomorrow's fajr must come from a real calculation for tomorrow's date:
    // prayer times drift daily, so today+24h can be off by minutes.
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final tomorrowFajr =
        PrayerTimes(_coords, DateComponents.from(tomorrow), params).fajr;
    setState(() {
      _prayerTimes = PrayerTimes(_coords, date, params);
      _tomorrowFajr = tomorrowFajr;
      _prayerTimesDateKey = _todayDateKey;
    });
  }

  Future<void> _syncNotificationsNow() async {
    final params = CalculationMethod.egyptian.getParameters();
    params.madhab = Madhab.shafi;
    await RafiqNotificationsService.instance.syncAllScheduledNotifications(
      lat: _coords.latitude,
      lng: _coords.longitude,
      params: params,
    );
  }

  Future<void> _applyLocation({
    required double lat,
    required double lng,
    required String label,
    required String mode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('saved_lat', lat);
    await prefs.setDouble('saved_lng', lng);
    await prefs.setString('saved_loc_name', label);
    await prefs.setString('saved_loc_mode', mode);

    setState(() {
      _coords = Coordinates(lat, lng);
      _locationLabel = label;
      _locationMode = mode;
    });
    _calculatePrayerTimes();
    await _syncNotificationsNow();
  }

  Future<void> _updateLocationOnline() async {
    if (_isLoadingLocation) return;
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('خدمة الموقع غير مفعّلة — يمكنك اختيار محافظتك أوفلاين من القائمة'),
            ),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم رفض إذن الموقع — اختر محافظتك يدوياً أوفلاين')),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final resolvedName = _nearestOfflineCityName(pos.latitude, pos.longitude);
      await _applyLocation(
        lat: pos.latitude,
        lng: pos.longitude,
        label: '$resolvedName (${pos.latitude.toStringAsFixed(2)}, ${pos.longitude.toStringAsFixed(2)})',
        mode: 'GPS مباشر',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر التحديد التلقائي حالياً — تم الإبقاء على وضع الأوفلاين')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _openLocationSelectorSheet() {
    String query = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final filtered = _offlineCities
              .where((c) => c.name.contains(query.trim()) || c.country.contains(query.trim()))
              .toList();

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            maxChildSize: 0.9,
            minChildSize: 0.45,
            builder: (_, scrollController) => Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'تحديد الموقع (أونلاين / أوفلاين)',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThalabTheme.foxOrange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _updateLocationOnline();
                    },
                    icon: const Icon(Icons.my_location_rounded),
                    label: const Text('تحديد موقعي تلقائياً عبر GPS'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'ابحث عن محافظتك أو مدينتك (بدون إنترنت)...',
                      prefixIcon: const Icon(Icons.search_rounded, color: ThalabTheme.foxOrange),
                      filled: true,
                      fillColor: _innerBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => setSheetState(() => query = val),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final city = filtered[index];
                        final fullLabel = '${city.name}، ${city.country}';
                        final isSelected = _locationLabel.startsWith(fullLabel);
                        return ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          tileColor: isSelected
                              ? ThalabTheme.foxOrange.withOpacity(0.12)
                              : _innerBg,
                          leading: Icon(
                            Icons.location_city_rounded,
                            color: isSelected ? ThalabTheme.foxOrange : ThalabTheme.mutedText(context),
                          ),
                          title: Text(
                            fullLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? ThalabTheme.foxOrange : _textColor,
                            ),
                          ),
                          subtitle: Text(
                            'إحداثيات محفوظة أوفلاين (${city.lat.toStringAsFixed(2)}, ${city.lng.toStringAsFixed(2)})',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded, color: ThalabTheme.foxOrange)
                              : null,
                          onTap: () async {
                            Navigator.pop(ctx);
                            await _applyLocation(
                              lat: city.lat,
                              lng: city.lng,
                              label: fullLabel,
                              mode: 'أوفلاين',
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  ({
    List<Color> gradient,
    IconData skyIcon,
    String periodBadge,
    Color accentText,
  }) _prayerTheme(Prayer p) {
    switch (p) {
      case Prayer.fajr:
      case Prayer.none:
        return (
          gradient: const [Color(0xFF1E3A5F), Color(0xFF3B6E9C), Color(0xFFD98236)],
          skyIcon: Icons.wb_twilight_rounded,
          periodBadge: 'نسائم الفجر',
          accentText: const Color(0xFFFFE4C4),
        );
      case Prayer.sunrise:
      case Prayer.dhuhr:
        return (
          gradient: const [Color(0xFF1976D2), Color(0xFF42A5F5), Color(0xFF64B5F6)],
          skyIcon: Icons.wb_sunny_rounded,
          periodBadge: 'ضياء الظهيرة',
          accentText: Colors.white,
        );
      case Prayer.asr:
        return (
          gradient: const [Color(0xFFD96B14), Color(0xFFF39237), Color(0xFFF7B267)],
          skyIcon: Icons.wb_sunny_outlined,
          periodBadge: 'أصيل العصر',
          accentText: Colors.white,
        );
      case Prayer.maghrib:
        return (
          gradient: const [Color(0xFF4A1D5C), Color(0xFFA8385D), Color(0xFFE86A17)],
          skyIcon: Icons.nights_stay_outlined,
          periodBadge: 'شفق المغرب',
          accentText: const Color(0xFFFFE8D6),
        );
      case Prayer.isha:
        return (
          gradient: const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
          skyIcon: Icons.bedtime_rounded,
          periodBadge: 'سكون العشاء',
          accentText: const Color(0xFFE2E8F0),
        );
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

  Future<void> _updatePrayerLogStatus(String prayerKey, int newStatus) async {
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _todayDateKey;
    final oldStatus = _todayPrayerStatus[prayerKey] ?? 0;

    int pointsDelta = 0;
    if (oldStatus == 0 && newStatus > 0) {
      pointsDelta = newStatus == 2 ? 27 : 10;
    } else if (oldStatus > 0 && newStatus == 0) {
      pointsDelta = oldStatus == 2 ? -27 : -10;
    } else if (oldStatus != newStatus) {
      pointsDelta = (newStatus == 2 ? 27 : 10) - (oldStatus == 2 ? 27 : 10);
    }

    final updatedPoints = (_totalPrayerPoints + pointsDelta).clamp(0, 9999999);
    setState(() {
      _todayPrayerStatus[prayerKey] = newStatus;
      _totalPrayerPoints = updatedPoints;
    });
    await prefs.setInt('prayer_log_${dateKey}_$prayerKey', newStatus);
    await prefs.setInt('total_prayer_points', updatedPoints);
  }

  Future<void> _toggleSunnahLog(String prayerKey) async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _todayDateKey;
    final nextVal = !(_todaySunnahDone[prayerKey] ?? false);
    final updatedPoints = (_totalPrayerPoints + (nextVal ? 5 : -5)).clamp(0, 9999999);

    setState(() {
      _todaySunnahDone[prayerKey] = nextVal;
      _totalPrayerPoints = updatedPoints;
    });
    await prefs.setBool('sunnah_log_${dateKey}_$prayerKey', nextVal);
    await prefs.setInt('total_prayer_points', updatedPoints);
  }

  @override
  Widget build(BuildContext context) {
    final pt = _prayerTimes;
    final nextPrayer = pt?.nextPrayerByDateTime(clock.now()) ?? Prayer.none;
    DateTime? nextTime = pt?.timeForPrayer(nextPrayer);
    if (nextPrayer == Prayer.none && pt != null) {
      nextTime = _tomorrowFajr ?? pt.fajr.add(const Duration(days: 1));
    }

    final remaining = nextTime != null ? nextTime.difference(clock.now()) : Duration.zero;
    final remHours = remaining.inHours.clamp(0, 23).toString().padLeft(2, '0');
    final remMins = (remaining.inMinutes % 60).clamp(0, 59).toString().padLeft(2, '0');
    final remSecs = (remaining.inSeconds % 60).clamp(0, 59).toString().padLeft(2, '0');
    final pVisual = _prayerTheme(nextPrayer);

    final todayH = HijriCalendar.fromDate(clock.now().add(Duration(days: _hijriOffset)));
    final monthName = _hijriMonthsAr[(todayH.hMonth - 1).clamp(0, 11)];
    final hijriFullText = '${todayH.hDay} $monthName ${todayH.hYear} هـ';

    return Scaffold(
      appBar: AppBar(
        title: const Text('مواقيت الصلاة والمحاسبة'),
        actions: [
          IconButton(
            tooltip: 'اختيار المدينة (أوفلاين / GPS)',
            icon: const Icon(Icons.edit_location_alt_rounded, color: ThalabTheme.foxOrange),
            onPressed: _openLocationSelectorSheet,
          ),
          IconButton(
            tooltip: 'تحديث الموقع (GPS)',
            icon: _isLoadingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: ThalabTheme.foxOrange),
                  )
                : const Icon(Icons.my_location_rounded, color: ThalabTheme.foxOrange),
            onPressed: _updateLocationOnline,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: pVisual.gradient,
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: pVisual.gradient.first.withOpacity(0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: InkWell(
                          onTap: _openLocationSelectorSheet,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on_rounded, color: pVisual.accentText, size: 15),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '$_locationLabel ($_locationMode)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: pVisual.accentText, fontSize: 11.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          hijriFullText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(pVisual.skyIcon, color: Colors.white, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                'الصلاة القادمة: ${_arabicPrayerName(nextPrayer)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'موعد الأذان: ${_formatTime(nextTime)} • ${pVisual.periodBadge}',
                            style: TextStyle(color: pVisual.accentText, fontSize: 11.5),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$remHours:$remMins:$remSecs',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            'متبقي على الأذان',
                            style: TextStyle(color: pVisual.accentText, fontSize: 10.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderColor),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: ThalabTheme.foxOrange,
                borderRadius: BorderRadius.circular(14),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: _textColor,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
              labelPadding: EdgeInsets.zero,
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.all(4),
              tabs: const [
                Tab(text: 'المواقيت والسنن'),
                Tab(text: 'سجل الصلوات'),
                Tab(text: 'تنبيهات الأذان'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTimesAndSunnahTab(pt, nextPrayer),
                _buildPrayerTrackerTab(pt),
                _buildPrayerNotificationsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimesAndSunnahTab(PrayerTimes? pt, Prayer nextPrayer) {
    final duhaStart = pt?.sunrise.add(const Duration(minutes: 20));
    final duhaEnd = pt?.dhuhr.subtract(const Duration(minutes: 15));
    DateTime? lastThirdNight;
    if (pt != null) {
      final nextFajr = _tomorrowFajr ?? pt.fajr.add(const Duration(days: 1));
      final nightDuration = nextFajr.difference(pt.maghrib);
      lastThirdNight = nextFajr.subtract(Duration(minutes: (nightDuration.inMinutes / 3).round()));
    }

    final prayersList = [
      {
        'id': Prayer.fajr,
        'name': 'الفجر',
        'fard': 'ركعتان فرض',
        'sunnah': 'سنة الفجر: ركعتان قبلية (خير من الدنيا وما فيها)',
        'sunnahCount': '2 قبلية',
        'time': pt?.fajr,
        'icon': Icons.wb_twilight_rounded,
      },
      {
        'id': Prayer.sunrise,
        'name': 'الشروق (بداية الضحى)',
        'fard': 'نهاية وقت الفجر',
        'sunnah': 'صلاة الضحى بعد الشروق بـ 20 دقيقة (أقلها ركعتان وأكثرها 8)',
        'sunnahCount': 'نافلة الضحى',
        'time': pt?.sunrise,
        'icon': Icons.wb_sunny_outlined,
      },
      {
        'id': Prayer.dhuhr,
        'name': 'الظهر',
        'fard': '4 ركعات فرض',
        'sunnah': 'السنن الرواتب: 4 ركعات قبلية + 2 ركعتان بعدية (مجموع 6 سنن)',
        'sunnahCount': '4 قبلية • 2 بعدية',
        'time': pt?.dhuhr,
        'icon': Icons.wb_sunny_rounded,
      },
      {
        'id': Prayer.asr,
        'name': 'العصر',
        'fard': '4 ركعات فرض',
        'sunnah': 'سنة غير مؤكدة: 4 ركعات قبلية (رحم الله امرأً صلى قبل العصر أربعاً)',
        'sunnahCount': '4 قبلية (غير مؤكدة)',
        'time': pt?.asr,
        'icon': Icons.wb_sunny_outlined,
      },
      {
        'id': Prayer.maghrib,
        'name': 'المغرب',
        'fard': '3 ركعات فرض',
        'sunnah': 'السنة الراتبة: ركعتان بعدية بعد الفرض',
        'sunnahCount': '2 بعدية',
        'time': pt?.maghrib,
        'icon': Icons.nights_stay_outlined,
      },
      {
        'id': Prayer.isha,
        'name': 'العشاء',
        'fard': '4 ركعات فرض',
        'sunnah': 'السنة الراتبة: ركعتان بعدية + صلاة الشفع والوتر',
        'sunnahCount': '2 بعدية + الوتر',
        'time': pt?.isha,
        'icon': Icons.bedtime_rounded,
      },
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        ...prayersList.map((p) {
          final isNext = p['id'] == nextPrayer;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: isNext ? ThalabTheme.foxOrange.withOpacity(0.09) : _cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isNext ? ThalabTheme.foxOrange : _borderColor,
                width: isNext ? 1.8 : 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      p['icon'] as IconData,
                      color: isNext ? ThalabTheme.foxOrange : ThalabTheme.mutedText(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['name'] as String,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: isNext ? ThalabTheme.foxOrange : _textColor,
                            ),
                          ),
                          Text(
                            '${p['fard']} • ${p['sunnahCount']}',
                            style: TextStyle(fontSize: 11.5, color: ThalabTheme.mutedText(context)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatTime(p['time'] as DateTime?),
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: isNext ? ThalabTheme.foxOrange : _textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _innerBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    p['sunnah'] as String,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: _textColor,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: ThalabTheme.foxOrange.withOpacity(0.35), width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.volunteer_activism_rounded,
                      color: ThalabTheme.foxOrange, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'النوافل والأوقات المباركة اليوم',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _NaflRow(
                title: 'صلاة الضحى (صلاة الأوابين)',
                subtitle: 'أقلها ركعتان وأفضلها 8 ركعات',
                timeWindow: '${_formatTime(duhaStart)} — ${_formatTime(duhaEnd)}',
              ),
              const Divider(height: 18),
              _NaflRow(
                title: 'الثلث الأخير من الليل وقيام الليل',
                subtitle: 'وقت النزول الإلهي واستجابة الدعاء',
                timeWindow: 'يبدأ ${_formatTime(lastThirdNight)}',
              ),
              const Divider(height: 18),
              _NaflRow(
                title: 'صلاة الوتر',
                subtitle: 'من بعد العشاء حتى طلوع الفجر (ركعة أو 3 أو أكثر)',
                timeWindow: '${_formatTime(pt?.isha)} — ${_formatTime(pt?.fajr)}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrayerTrackerTab(PrayerTimes? pt) {
    final completedFardCount = _todayPrayerStatus.values.where((v) => v > 0).length;
    final completedSunnahCount = _todaySunnahDone.values.where((v) => v).length;
    final double dailyProgress = (completedFardCount / 5.0).clamp(0.0, 1.0);

    final fardItems = [
      ('fajr', 'صلاة الفجر', '2 سنة قبلية', pt?.fajr),
      ('dhuhr', 'صلاة الظهر', '4 قبلية + 2 بعدية', pt?.dhuhr),
      ('asr', 'صلاة العصر', '4 قبلية (مستحبة)', pt?.asr),
      ('maghrib', 'صلاة المغرب', '2 سنة بعدية', pt?.maghrib),
      ('isha', 'صلاة العشاء', '2 بعدية + الوتر', pt?.isha),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _borderColor, width: 1.4),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'محاسبة الصلوات اليوم',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      Text(
                        'الفروض: $completedFardCount / 5  •  السنن: $completedSunnahCount / 5',
                        style: TextStyle(fontSize: 12, color: ThalabTheme.mutedText(context)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ThalabTheme.foxOrange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: ThalabTheme.foxOrange, size: 17),
                        const SizedBox(width: 4),
                        Text(
                          '$_totalPrayerPoints نقطة',
                          style: const TextStyle(
                            color: ThalabTheme.foxOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: dailyProgress,
                  minHeight: 8,
                  backgroundColor: _innerBg,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF1B8A5A)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...fardItems.map((item) {
          final key = item.$1;
          final title = item.$2;
          final sunnahLabel = item.$3;
          final time = item.$4;
          final status = _todayPrayerStatus[key] ?? 0;
          final sunnahDone = _todaySunnahDone[key] ?? false;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: status > 0
                    ? const Color(0xFF1B8A5A).withOpacity(0.5)
                    : _borderColor,
                width: 1.4,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          status > 0
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: status > 0 ? const Color(0xFF1B8A5A) : ThalabTheme.mutedText(context),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: _textColor,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _formatTime(time),
                      style: TextStyle(
                        color: ThalabTheme.mutedText(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _StatusChoiceChip(
                      label: 'جماعة (مسجد)',
                      selected: status == 2,
                      color: const Color(0xFF1B8A5A),
                      onTap: () => _updatePrayerLogStatus(key, status == 2 ? 0 : 2),
                    ),
                    _StatusChoiceChip(
                      label: 'في وقتها',
                      selected: status == 1,
                      color: ThalabTheme.foxOrange,
                      onTap: () => _updatePrayerLogStatus(key, status == 1 ? 0 : 1),
                    ),
                    _StatusChoiceChip(
                      label: 'قضاء',
                      selected: status == 3,
                      color: const Color(0xFF64748B),
                      onTap: () => _updatePrayerLogStatus(key, status == 3 ? 0 : 3),
                    ),
                    FilterChip(
                      label: Text(
                        'السنن ($sunnahLabel)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: sunnahDone ? Colors.white : _textColor,
                        ),
                      ),
                      selected: sunnahDone,
                      selectedColor: const Color(0xFF0F766E),
                      backgroundColor: _innerBg,
                      checkmarkColor: Colors.white,
                      onSelected: (_) => _toggleSunnahLog(key),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPrayerNotificationsTab() {
    final prayers = [
      ('fajr', 'صلاة الفجر', Icons.wb_twilight_rounded),
      ('dhuhr', 'صلاة الظهر', Icons.wb_sunny_rounded),
      ('asr', 'صلاة العصر', Icons.wb_sunny_outlined),
      ('maghrib', 'صلاة المغرب', Icons.nights_stay_outlined),
      ('isha', 'صلاة العشاء', Icons.bedtime_rounded),
    ];

    const beforeOptions = [0, 5, 10, 15, 30];
    const afterOptions = [0, 10, 15, 20, 25];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ThalabTheme.foxOrange,
                    side: const BorderSide(color: ThalabTheme.foxOrange),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    final fajrMuezzin = _perPrayerMuezzin['fajr'] ?? 'fajr_egypt';
                    await RafiqNotificationsService.instance.sendTestScheduledAdhan(
                      muezzinId: fajrMuezzin,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('سيصل إشعار الأذان التجريبي خلال 5 ثوانٍ — أغلق التطبيق للتجربة'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
                  label: const Text('تجربة الأذان (5 ث)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                    side: const BorderSide(color: Color(0xFF0F766E)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    final userName = prefs.getString('user_name')?.trim() ?? 'صديقي';
                    await RafiqNotificationsService.instance.scheduleDailyAzkar(
                      id: 505,
                      title: 'محاسبة سجل الصلوات يا $userName',
                      body: 'هل سجّلت صلواتك وسننك اليوم في رفيق؟ راجع سجلّك الآن.',
                      hour: 21,
                      minute: 30,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم تفعيل تذكير سجل الصلوات اليومي (9:30 مساءً) ✓'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.fact_check_rounded, size: 20),
                  label: const Text('تذكير سجل الصلاة',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                ),
              ),
            ],
          ),
        ),
        ...prayers.map((p) {
          final key = p.$1;
          final title = p.$2;
          final icon = p.$3;
          final adhanOn = _adhanNotifEnabled[key] ?? true;
          final beforeVal = _beforeNotifMins[key] ?? 10;
          final afterVal = _afterNotifMins[key] ?? 15;

          final muezzinList = key == 'fajr'
              ? RafiqNotificationsService.fajrMuezzins
              : RafiqNotificationsService.generalMuezzins;
          final currentMuezzinId =
              _perPrayerMuezzin[key] ?? (key == 'fajr' ? 'fajr_egypt' : 'mishary_afasy');
          final muezzinName = muezzinList
              .firstWhere((m) => m.id == currentMuezzinId, orElse: () => muezzinList.first)
              .name;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _borderColor, width: 1.3),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ThalabTheme.foxOrange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: ThalabTheme.foxOrange, size: 22),
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                subtitle: Text(
                  adhanOn ? 'مفعّل • $muezzinName' : 'الأذان متوقف',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: ThalabTheme.mutedText(context)),
                ),
                trailing: Switch(
                  value: adhanOn,
                  activeColor: ThalabTheme.foxOrange,
                  onChanged: (val) async {
                    final prefs = await SharedPreferences.getInstance();
                    setState(() => _adhanNotifEnabled[key] = val);
                    await prefs.setBool('prayer_notif_${key}_adhan', val);
                    await _syncNotificationsNow();
                  },
                ),
                children: [
                  const Divider(height: 12),
                  DropdownButtonFormField<int>(
                    value: beforeOptions.contains(beforeVal) ? beforeVal : 0,
                    dropdownColor: _cardBg,
                    style: TextStyle(color: _textColor, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'تنبيه الاستعداد قبل الأذان',
                      labelStyle: TextStyle(fontSize: 12, color: ThalabTheme.mutedText(context)),
                      filled: true,
                      fillColor: _innerBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: beforeOptions
                        .map((mins) => DropdownMenuItem(
                              value: mins,
                              child: Text(
                                mins == 0 ? 'إيقاف التنبيه المسبق' : 'قبل الأذان بـ $mins دقيقة',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ))
                        .toList(),
                    onChanged: (val) async {
                      if (val == null) return;
                      final prefs = await SharedPreferences.getInstance();
                      setState(() => _beforeNotifMins[key] = val);
                      await prefs.setInt('prayer_notif_${key}_before', val);
                      await _syncNotificationsNow();
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: muezzinList.any((m) => m.id == currentMuezzinId)
                        ? currentMuezzinId
                        : muezzinList.first.id,
                    dropdownColor: _cardBg,
                    style: TextStyle(color: _textColor, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'صوت المؤذن لهذه الصلاة',
                      labelStyle: TextStyle(fontSize: 12, color: ThalabTheme.mutedText(context)),
                      filled: true,
                      fillColor: _innerBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: muezzinList
                        .map((m) => DropdownMenuItem(
                              value: m.id,
                              child: Text(m.name, style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (val) async {
                      if (val == null) return;
                      final prefs = await SharedPreferences.getInstance();
                      setState(() => _perPrayerMuezzin[key] = val);
                      await prefs.setString('prayer_muezzin_$key', val);
                      await _syncNotificationsNow();
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: afterOptions.contains(afterVal) ? afterVal : 0,
                    dropdownColor: _cardBg,
                    style: TextStyle(color: _textColor, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'تنبيه الإقامة وأذكار بعد الصلاة',
                      labelStyle: TextStyle(fontSize: 12, color: ThalabTheme.mutedText(context)),
                      filled: true,
                      fillColor: _innerBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: afterOptions
                        .map((mins) => DropdownMenuItem(
                              value: mins,
                              child: Text(
                                mins == 0 ? 'إيقاف تنبيه ما بعد الصلاة' : 'بعد الأذان بـ $mins دقيقة',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ))
                        .toList(),
                    onChanged: (val) async {
                      if (val == null) return;
                      final prefs = await SharedPreferences.getInstance();
                      setState(() => _afterNotifMins[key] = val);
                      await prefs.setInt('prayer_notif_${key}_after', val);
                      await _syncNotificationsNow();
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _StatusChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _StatusChoiceChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? ThalabTheme.darkTextPrimary
        : ThalabTheme.darkSlate;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: selected ? Colors.white : textColor,
        ),
      ),
      selected: selected,
      selectedColor: color,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      onSelected: (_) => onTap(),
    );
  }
}

class _NaflRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String timeWindow;

  const _NaflRow({
    required this.title,
    required this.subtitle,
    required this.timeWindow,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? ThalabTheme.darkTextPrimary
        : ThalabTheme.darkSlate;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textColor)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 11.5, color: ThalabTheme.mutedText(context))),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: ThalabTheme.foxOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            timeWindow,
            style: const TextStyle(
              color: ThalabTheme.foxOrange,
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
            ),
          ),
        ),
      ],
    );
  }
}
