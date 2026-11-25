import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';

// =========================================================================
// 1. حاسبة الزكاة الشرعية (المال والذهب)
// =========================================================================
class ZakatCalculatorScreen extends StatefulWidget {
  const ZakatCalculatorScreen({super.key});

  @override
  State<ZakatCalculatorScreen> createState() => _ZakatCalculatorScreenState();
}

class _ZakatCalculatorScreenState extends State<ZakatCalculatorScreen> {
  final TextEditingController _cashCtrl = TextEditingController();
  final TextEditingController _goldPriceCtrl = TextEditingController(text: '3800');
  double _zakatDue = 0.0;
  bool _isAboveNisab = false;

  void _calculate() {
    final cash = double.tryParse(_cashCtrl.text.trim()) ?? 0.0;
    final goldPrice = double.tryParse(_goldPriceCtrl.text.trim()) ?? 0.0;
    final nisab = goldPrice * 85.0; // نصاب 85 جرام ذهب عيار 24

    setState(() {
      _isAboveNisab = cash >= nisab && nisab > 0;
      _zakatDue = _isAboveNisab ? cash * 0.025 : 0.0;
    });
  }

  @override
  void dispose() {
    _cashCtrl.dispose();
    _goldPriceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goldPrice = double.tryParse(_goldPriceCtrl.text.trim()) ?? 0.0;
    final nisab = goldPrice * 85.0;

    return Scaffold(
      appBar: AppBar(title: const Text('حاسبة الزكاة')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThalabTheme.cardOf(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ThalabTheme.borderOf(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('إجمالي المدخرات النقدية',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                const SizedBox(height: 8),
                TextField(
                  controller: _cashCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _calculate(),
                  decoration: InputDecoration(
                    hintText: 'أدخل المبلغ الذي حال عليه الحول...',
                    filled: true,
                    fillColor: ThalabTheme.creamBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('سعر جرام الذهب عيار 24 (لحساب النصاب)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                const SizedBox(height: 8),
                TextField(
                  controller: _goldPriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _calculate(),
                  decoration: InputDecoration(
                    hintText: 'سعر الجرام...',
                    filled: true,
                    fillColor: ThalabTheme.creamBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Text('الزكاة المستحقة (2.5%)',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  _zakatDue.toStringAsFixed(2),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  _isAboveNisab
                      ? 'بلغ المبلغ النصاب (${nisab.toStringAsFixed(0)}) وتجب فيه الزكاة'
                      : 'النصاب الحالي: ${nisab.toStringAsFixed(0)} — لم يبلغ النصاب بعد',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// 2. محول الوحدات الشامل (طول، وزن، حرارة، مساحة)
// =========================================================================
class UnitConverterScreen extends StatefulWidget {
  const UnitConverterScreen({super.key});

  @override
  State<UnitConverterScreen> createState() => _UnitConverterScreenState();
}

class _UnitConverterScreenState extends State<UnitConverterScreen> {
  final TextEditingController _inputCtrl = TextEditingController(text: '1');
  String _category = 'الطول';
  String _fromUnit = 'متر';
  String _toUnit = 'سنتيمتر';
  double _result = 100.0;

  static const Map<String, Map<String, double>> _factors = {
    'الطول': {
      'متر': 1.0,
      'كيلومتر': 1000.0,
      'سنتيمتر': 0.01,
      'ميل': 1609.344,
      'قدم': 0.3048,
    },
    'الوزن': {
      'كيلوجرام': 1.0,
      'جرام': 0.001,
      'طن': 1000.0,
      'باوند (رطل)': 0.453592,
    },
    'المساحة': {
      'متر مربع': 1.0,
      'كيلومتر مربع': 1000000.0,
      'فدان': 4200.83,
      'قيراط': 175.03,
    },
  };

  void _convert() {
    final val = double.tryParse(_inputCtrl.text.trim()) ?? 0.0;
    if (_category == 'الحرارة') {
      double celsius = val;
      if (_fromUnit == 'فهرنهايت') celsius = (val - 32) * 5 / 9;
      if (_fromUnit == 'كلفن') celsius = val - 273.15;

      double out = celsius;
      if (_toUnit == 'فهرنهايت') out = (celsius * 9 / 5) + 32;
      if (_toUnit == 'كلفن') out = celsius + 273.15;
      setState(() => _result = out);
      return;
    }

    final map = _factors[_category]!;
    final base = val * (map[_fromUnit] ?? 1.0);
    setState(() => _result = base / (map[_toUnit] ?? 1.0));
  }

  List<String> get _currentUnits => _category == 'الحرارة'
      ? ['سيلزيوس', 'فهرنهايت', 'كلفن']
      : _factors[_category]!.keys.toList();

  @override
  Widget build(BuildContext context) {
    final units = _currentUnits;
    return Scaffold(
      appBar: AppBar(title: const Text('محول الوحدات الشامل')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 8,
            children: ['الطول', 'الوزن', 'المساحة', 'الحرارة'].map((cat) {
              final active = _category == cat;
              return ChoiceChip(
                label: Text(cat,
                    style: TextStyle(
                        color: active ? Colors.white : ThalabTheme.darkSlate,
                        fontWeight: FontWeight.bold)),
                selected: active,
                selectedColor: ThalabTheme.foxOrange,
                onSelected: (_) {
                  setState(() {
                    _category = cat;
                    final u = _currentUnits;
                    _fromUnit = u.first;
                    _toUnit = u.length > 1 ? u[1] : u.first;
                  });
                  _convert();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThalabTheme.cardOf(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ThalabTheme.borderOf(context)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _inputCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _convert(),
                  decoration: InputDecoration(
                    labelText: 'القيمة',
                    filled: true,
                    fillColor: ThalabTheme.creamBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: units.contains(_fromUnit) ? _fromUnit : units.first,
                        decoration: const InputDecoration(labelText: 'من'),
                        items: units
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _fromUnit = v);
                            _convert();
                          }
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(Icons.swap_horiz_rounded, color: ThalabTheme.foxOrange),
                    ),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: units.contains(_toUnit) ? _toUnit : units.last,
                        decoration: const InputDecoration(labelText: 'إلى'),
                        items: units
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _toUnit = v);
                            _convert();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: ThalabTheme.darkSlate,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                const Text('النتيجة', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                Text(
                  _result.toStringAsFixed(4).replaceAll(RegExp(r'\.?0+$'), ''),
                  style: const TextStyle(
                      color: ThalabTheme.foxOrange,
                      fontSize: 32,
                      fontWeight: FontWeight.w900),
                ),
                Text(_toUnit, style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// 3. حاسبة العمر الدقيق
// =========================================================================
class AgeCalculatorScreen extends StatefulWidget {
  const AgeCalculatorScreen({super.key});

  @override
  State<AgeCalculatorScreen> createState() => _AgeCalculatorScreenState();
}

class _AgeCalculatorScreenState extends State<AgeCalculatorScreen> {
  DateTime _birthDate = DateTime(2005, 1, 2);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _birthDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    int years = now.year - _birthDate.year;
    int months = now.month - _birthDate.month;
    int days = now.day - _birthDate.day;

    if (days < 0) {
      months--;
      final prevMonth = DateTime(now.year, now.month, 0);
      days += prevMonth.day;
    }
    if (months < 0) {
      years--;
      months += 12;
    }

    final totalDays = now.difference(_birthDate).inDays;
    DateTime nextBirthday = DateTime(now.year, _birthDate.month, _birthDate.day);
    if (nextBirthday.isBefore(DateTime(now.year, now.month, now.day))) {
      nextBirthday = DateTime(now.year + 1, _birthDate.month, _birthDate.day);
    }
    final daysToNext = nextBirthday.difference(DateTime(now.year, now.month, now.day)).inDays;

    return Scaffold(
      appBar: AppBar(title: const Text('حاسبة العمر الدقيق')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: ThalabTheme.cardOf(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ThalabTheme.foxOrange),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('تاريخ الميلاد',
                            style: TextStyle(color: ThalabTheme.mutedText(context), fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          '${_birthDate.year}/${_birthDate.month}/${_birthDate.day}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Icon(Icons.calendar_month_rounded,
                        color: ThalabTheme.foxOrange, size: 28),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Text('عمرك الآن بالضبط',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 10),
                  Text(
                    '$years سنة  •  $months شهر  •  $days يوم',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: ThalabTheme.cardOf(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ThalabTheme.borderOf(context)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('إجمالي الأيام التي عشتها:',
                          style: TextStyle(color: ThalabTheme.mutedText(context))),
                      Text('$totalDays يوم',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('المتبقي على عيد ميلادك القادم:',
                          style: TextStyle(color: ThalabTheme.mutedText(context))),
                      Text('$daysToNext يوم',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: ThalabTheme.foxOrange)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// 4. مولد كلمات المرور القوية
// =========================================================================
class PasswordGeneratorScreen extends StatefulWidget {
  const PasswordGeneratorScreen({super.key});

  @override
  State<PasswordGeneratorScreen> createState() => _PasswordGeneratorScreenState();
}

class _PasswordGeneratorScreenState extends State<PasswordGeneratorScreen> {
  double _length = 14;
  bool _includeSymbols = true;
  bool _includeNumbers = true;
  String _password = '';

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    const letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    const symbols = '!@#\$%^&*()-_=+[]{}';

    String pool = letters;
    if (_includeNumbers) pool += numbers;
    if (_includeSymbols) pool += symbols;

    final rng = math.Random.secure();
    final generated = List.generate(
      _length.toInt(),
      (_) => pool[rng.nextInt(pool.length)],
    ).join();

    setState(() => _password = generated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مولد كلمات المرور القوية')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThalabTheme.darkSlate,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  SelectableText(
                    _password,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThalabTheme.foxOrange,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _password));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم نسخ كلمة المرور ✓')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('نسخ'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                        ),
                        onPressed: _generate,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('توليد جديد'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThalabTheme.cardOf(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ThalabTheme.borderOf(context)),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('طول كلمة المرور',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${_length.toInt()} حرف',
                          style: const TextStyle(
                              color: ThalabTheme.foxOrange, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: _length,
                    min: 8,
                    max: 32,
                    divisions: 24,
                    activeColor: ThalabTheme.foxOrange,
                    onChanged: (v) {
                      setState(() => _length = v);
                      _generate();
                    },
                  ),
                  SwitchListTile(
                    activeColor: ThalabTheme.foxOrange,
                    title: const Text('تضمين أرقام (0-9)'),
                    value: _includeNumbers,
                    onChanged: (v) {
                      setState(() => _includeNumbers = v);
                      _generate();
                    },
                  ),
                  SwitchListTile(
                    activeColor: ThalabTheme.foxOrange,
                    title: const Text('تضمين رموز خاصة (!@#\$)'),
                    value: _includeSymbols,
                    onChanged: (v) {
                      setState(() => _includeSymbols = v);
                      _generate();
                    },
                  ),
                ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// 5. محلل النصوص الاحترافي
// =========================================================================
class TextAnalyzerScreen extends StatefulWidget {
  const TextAnalyzerScreen({super.key});

  @override
  State<TextAnalyzerScreen> createState() => _TextAnalyzerScreenState();
}

class _TextAnalyzerScreenState extends State<TextAnalyzerScreen> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _ctrl.text.trim();
    final words = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    final chars = _ctrl.text.length;
    final charsNoSpace = _ctrl.text.replaceAll(RegExp(r'\s+'), '').length;
    final readSec = (words / 3.0).ceil();

    return Scaffold(
      appBar: AppBar(title: const Text('محلل النصوص الذكي')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              maxLines: 6,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'الصق أو اكتب النص هنا لتحليله فوراً...',
                filled: true,
                fillColor: ThalabTheme.cardOf(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: ThalabTheme.borderOf(context)),
                ),
              ),
            ),
            const SizedBox(height: 18),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.0,
              children: [
                _StatCard(label: 'عدد الكلمات', value: '$words'),
                _StatCard(label: 'إجمالي الأحرف', value: '$chars'),
                _StatCard(label: 'أحرف بدون مسافات', value: '$charsNoSpace'),
                _StatCard(label: 'وقت القراءة', value: '$readSec ثانية'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThalabTheme.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThalabTheme.borderOf(context)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: ThalabTheme.foxOrange)),
          Text(label,
              style: TextStyle(fontSize: 11.5, color: ThalabTheme.mutedText(context))),
        ],
      ),
    );
  }
}
