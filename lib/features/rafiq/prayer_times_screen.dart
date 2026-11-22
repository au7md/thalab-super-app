import 'dart:async';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/notification_service.dart';
import '../../core/rafiq_notifications_service.dart';

class OfflineCityPreset {
  final String name;
  final String country;
  final double lat;
  final double lng;

  const OfflineCityPreset(this.name, this.country, this.lat, this.lng);
}

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  PrayerTimes? _prayerTimes;
  Coordinates _coords = Coordinates(30.0444, 31.2357);
  String _locationLabel = 'القاهرة، مصر';
  String _locationMode = 'أوفلاين';
  bool _isLoadingLocation = false;
  int _hijriOffset = 0;
  Timer? _countdownTimer;

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

  // قاعدة بيانات أوفلاين متكاملة (27 محافظة مصرية + أبرز العواصم العربية والإسلامية)
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
    final savedMode = prefs.getString('saved_loc_mode') ?? 'أوفلاين';
    final offset = prefs.getInt('hijri_day_offset') ?? 0;

    if (lat != null && lng != null) {
      _coords = Coordinates(lat, lng);
      _locationLabel = savedLocName ?? _nearestOfflineCityName(lat, lng);
      _locationMode = savedMode;
    }
    _hijriOffset = offset;

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
    final params = CalculationMethod.egyptian.getParameters();
    params.madhab = Madhab.shafi;
    final date = DateComponents.from(DateTime.now());
    setState(() {
      _prayerTimes = PrayerTimes(_coords, date, params);
    });
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

    if (_prayerTimes != null) {
      await NotificationService.scheduleDailyPrayerNotifications(
        fajr: _prayerTimes!.fajr,
        dhuhr: _prayerTimes!.dhuhr,
        asr: _prayerTimes!.asr,
        maghrib: _prayerTimes!.maghrib,
        isha: _prayerTimes!.isha,
      );
      await RafiqNotificationsService.syncAllScheduledNotifications(
        lat: lat,
        lng: lng,
        params: CalculationMethod.egyptian.getParameters(),
      );
    }
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
        desiredAccuracy: LocationAccuracy.medium,
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

  /// نافذة اختيار الموقع المتكاملة (أوفلاين من 34 محافظة/مدينة أو GPS أونلاين)
  void _openLocationSelectorSheet() {
    String query = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: ThalabTheme.cardSurface,
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
                      const Text(
                        'تحديد الموقع (أونلاين / أوفلاين)',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
                      fillColor: ThalabTheme.creamBackground,
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
                              : ThalabTheme.creamBackground,
                          leading: Icon(
                            Icons.location_city_rounded,
                            color: isSelected ? ThalabTheme.foxOrange : ThalabTheme.mutedSlate,
                          ),
                          title: Text(
                            fullLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? ThalabTheme.foxOrange : ThalabTheme.darkSlate,
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

  /// خصائص الهوية البصرية الديناميكية للويدجت حسب الصلاة القادمة
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
    final pVisual = _prayerTheme(nextPrayer);

    final todayH = HijriCalendar.fromDate(DateTime.now().add(Duration(days: _hijriOffset)));
    final monthName = _hijriMonthsAr[(todayH.hMonth - 1).clamp(0, 11)];
    final hijriFullText = '${todayH.hDay} $monthName ${todayH.hYear} هـ';

    // حساب أوقات النوافل (الضحى والثلث الأخير من الليل)
    final duhaStart = pt?.sunrise.add(const Duration(minutes: 20));
    final duhaEnd = pt?.dhuhr.subtract(const Duration(minutes: 15));
    DateTime? lastThirdNight;
    if (pt != null) {
      final nextFajr = pt.fajr.add(const Duration(days: 1));
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('مواقيت الصلاة والسنن'),
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // 1. ويدجت الصلاة الديناميكي المتناغم مع وقت الفرض + التاريخ الهجري + الموقع
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: pVisual.gradient,
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(26),
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(pVisual.skyIcon, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'الصلاة القادمة: ${_arabicPrayerName(nextPrayer)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
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
                Text(
                  'الوقت المتبقي للأذان • ${pVisual.periodBadge}',
                  style: TextStyle(color: pVisual.accentText, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. جدول الفروض والسنن الرواتب الموضحة لكل صلاة
          const Padding(
            padding: EdgeInsets.only(bottom: 8, right: 4),
            child: Text(
              'الصلوات المفروضة والسنن الرواتب',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
            ),
          ),
          ...prayersList.map((p) {
            final isNext = p['id'] == nextPrayer;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: isNext ? ThalabTheme.foxOrange.withOpacity(0.09) : ThalabTheme.cardSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isNext ? ThalabTheme.foxOrange : ThalabTheme.softBorder,
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
                        color: isNext ? ThalabTheme.foxOrange : ThalabTheme.mutedSlate,
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
                                color: isNext ? ThalabTheme.foxOrange : ThalabTheme.darkSlate,
                              ),
                            ),
                            Text(
                              '${p['fard']} • ${p['sunnahCount']}',
                              style: const TextStyle(fontSize: 11.5, color: ThalabTheme.mutedSlate),
                            ),
                          ],
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
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: ThalabTheme.creamBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      p['sunnah'] as String,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: ThalabTheme.darkSlate,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 10),

          // 3. بطاقة النوافل والأوقات المباركة (الضحى + قيام الليل + الوتر)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThalabTheme.cardSurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: ThalabTheme.foxOrange.withOpacity(0.35), width: 1.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.volunteer_activism_rounded, color: ThalabTheme.foxOrange, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'النوافل والأوقات المباركة اليوم',
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
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
      ),
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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11.5, color: ThalabTheme.mutedSlate)),
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
