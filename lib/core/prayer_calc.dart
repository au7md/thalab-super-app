import 'package:adhan/adhan.dart';

/// يختار طريقة حساب المواقيت حسب المنطقة الجغرافية.
/// الحدود (bounding boxes) تقريبية؛ المستخدم يستطيع تجاوزها لاحقاً من الإعدادات.
///
/// الترتيب مهم: الدول الصغيرة داخل حدود السعودية (الكويت/قطر/الإمارات) تُفحص أولاً،
/// ثم مصر قبل السعودية لتفادي تداخل سيناء.
CalculationParameters prayerParamsFor(double lat, double lng) {
  final key = _methodKeyFor(lat, lng);
  final method = CalculationMethod.values.firstWhere(
    (m) => m.name.toLowerCase().replaceAll('_', '') == key,
    orElse: () => CalculationMethod.egyptian,
  );
  final params = method.getParameters();
  params.madhab = Madhab.shafi;
  return params;
}

String _methodKeyFor(double lat, double lng) {
  bool inBox(double latMin, double latMax, double lngMin, double lngMax) =>
      lat >= latMin && lat <= latMax && lng >= lngMin && lng <= lngMax;

  if (inBox(28.5, 30.2, 46.5, 48.5)) return 'kuwait';
  if (inBox(24.4, 26.3, 50.7, 51.7)) return 'qatar';
  if (inBox(22.6, 26.1, 51.0, 56.4)) return 'dubai';
  if (inBox(22.0, 31.7, 24.7, 34.9)) return 'egyptian';
  if (inBox(16.0, 32.5, 34.9, 56.0)) return 'ummalqura';
  return 'muslimworldleague';
}
