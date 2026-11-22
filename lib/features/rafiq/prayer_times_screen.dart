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

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('hh:mm a', 'ar');
    final currentPrayer = _prayerTimes.currentPrayer();

    final duhaStart = _prayerTimes.sunrise.add(const Duration(minutes: 15));
    final duhaEnd = _prayerTimes.dhuhr.subtract(const Duration(minutes: 10));
    final sunnahTimes = SunnahTimes(_prayerTimes);

    final list = [
      ('الفجر', _prayerTimes.fajr, Prayer.fajr, Icons.wb_twilight_rounded, 'سنة قبلية: ٢ ركعة'),
      ('الشروق', _prayerTimes.sunrise, Prayer.sunrise, Icons.wb_sunny_outlined, 'بداية وقت الضحى بعد ١٥ د'),
      ('الظهر', _prayerTimes.dhuhr, Prayer.dhuhr, Icons.wb_sunny_rounded, 'قبلية: ٤ ركعات • بعدية: ٢'),
      ('العصر', _prayerTimes.asr, Prayer.asr, Icons.sunny_snowing, 'نافلة قبلية: ٤ ركعات'),
      ('المغرب', _prayerTimes.maghrib, Prayer.maghrib, Icons.nights_stay_outlined, 'سنة بعدية: ٢ ركعة'),
      ('العشاء', _prayerTimes.isha, Prayer.isha, Icons.bedtime_rounded, 'بعدية: ٢ • الوتر: ١ - ٣'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('مواقيت الصلاة والسنن'),
        actions: [
          IconButton(
            tooltip: 'تحديد المحافظة أو GPS',
            icon: const Icon(Icons.location_city_rounded, color: ThalabTheme.foxOrange),
            onPressed: _openSettingsSheet,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
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
          const SizedBox(height: 18),
          ...list.map((item) {
            final isCurrent = item.$3 == currentPrayer;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$1,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w700,
                          ),
                        ),
                        Text(
                          item.$5,
                          style: const TextStyle(
                            fontSize: 11,
                            color: ThalabTheme.mutedSlate,
                          ),
                        ),
                      ],
                    ),
                  ),
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
          const SizedBox(height: 14),
          const Text(
            'أوقات النوافل وقيام الليل',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThalabTheme.cardSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: ThalabTheme.softBorder, width: 1.5),
            ),
            child: Column(
              children: [
                _NafilahRow(
                  icon: Icons.wb_sunny_rounded,
                  title: 'صلاة الضحى (الأوابين)',
                  subtitle: '٢ إلى ٨ ركعات',
                  timeText: '${formatter.format(duhaStart)} - ${formatter.format(duhaEnd)}',
                ),
                const Divider(height: 20, color: ThalabTheme.softBorder),
                _NafilahRow(
                  icon: Icons.dark_mode_outlined,
                  title: 'منتصف الليل الشرعي',
                  subtitle: 'نهاية وقت العشاء المختار',
                  timeText: formatter.format(sunnahTimes.middleOfTheNight),
                ),
                const Divider(height: 20, color: ThalabTheme.softBorder),
                _NafilahRow(
                  icon: Icons.auto_awesome_rounded,
                  title: 'الثلث الأخير من الليل',
                  subtitle: 'وقت النزول الإلهي والسحر',
                  timeText: formatter.format(sunnahTimes.lastThirdOfTheNight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NafilahRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String timeText;

  const _NafilahRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.timeText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ThalabTheme.foxOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: ThalabTheme.foxOrange, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: ThalabTheme.mutedSlate)),
            ],
          ),
        ),
        Text(
          timeText,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
            color: ThalabTheme.foxOrange,
          ),
        ),
      ],
    );
  }
}
