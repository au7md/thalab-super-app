import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';

class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> {
  int _tasbihCount = 0;
  int _tasbihTarget = 33;
  int _totalLifetimeTasbih = 0;
  int _selectedPhraseIndex = 0;

  static const List<Map<String, dynamic>> _tasbihPhrases = [
    {'text': 'سُبْحَانَ اللَّهِ', 'target': 33},
    {'text': 'الْحَمْدُ لِلَّهِ', 'target': 33},
    {'text': 'اللَّهُ أَكْبَرُ', 'target': 34},
    {'text': 'أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ وَأَتُوبُ إِلَيْهِ', 'target': 100},
    {'text': 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ', 'target': 100},
    {'text': 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ', 'target': 100},
    {'text': 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ', 'target': 100},
    {'text': 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ', 'target': 100},
  ];

  @override
  void initState() {
    super.initState();
    _loadTasbihData();
  }

  Future<void> _loadTasbihData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tasbihCount = prefs.getInt('tasbih_current') ?? 0;
      _totalLifetimeTasbih = prefs.getInt('tasbih_lifetime') ?? 0;
      _selectedPhraseIndex = (prefs.getInt('tasbih_phrase_idx') ?? 0)
          .clamp(0, _tasbihPhrases.length - 1);
      _tasbihTarget = _tasbihPhrases[_selectedPhraseIndex]['target'] as int;
    });
  }

  Future<void> _incrementTasbih() async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tasbihCount++;
      _totalLifetimeTasbih++;
      if (_tasbihCount == _tasbihTarget) {
        HapticFeedback.heavyImpact();
      }
    });
    await prefs.setInt('tasbih_current', _tasbihCount);
    await prefs.setInt('tasbih_lifetime', _totalLifetimeTasbih);
  }

  Future<void> _resetTasbih() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    setState(() => _tasbihCount = 0);
    await prefs.setInt('tasbih_current', 0);
  }

  @override
  Widget build(BuildContext context) {
    final currentPhrase = _tasbihPhrases[_selectedPhraseIndex]['text'] as String;
    final progress = (_tasbihCount / _tasbihTarget).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('السبحة الذكية'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _tasbihPhrases.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final selected = _selectedPhraseIndex == idx;
                  return ChoiceChip(
                    label: Text(
                      _tasbihPhrases[idx]['text'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: selected ? Colors.white : ThalabTheme.darkSlate,
                      ),
                    ),
                    selected: selected,
                    selectedColor: ThalabTheme.foxOrange,
                    backgroundColor: ThalabTheme.cardSurface,
                    onSelected: (_) async {
                      final prefs = await SharedPreferences.getInstance();
                      setState(() {
                        _selectedPhraseIndex = idx;
                        _tasbihTarget = _tasbihPhrases[idx]['target'] as int;
                        _tasbihCount = 0;
                      });
                      await prefs.setInt('tasbih_phrase_idx', idx);
                      await prefs.setInt('tasbih_current', 0);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                color: ThalabTheme.cardSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: ThalabTheme.softBorder),
              ),
              child: Column(
                children: [
                  Text(
                    currentPhrase,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.amiri(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.8,
                      color: ThalabTheme.darkSlate,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'الهدف: $_tasbihTarget • إجمالي تسبيحاتك: $_totalLifetimeTasbih',
                    style: const TextStyle(fontSize: 12.5, color: ThalabTheme.mutedSlate),
                  ),
                ],
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _incrementTasbih,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 10,
                      backgroundColor: ThalabTheme.softBorder,
                      valueColor: const AlwaysStoppedAnimation(ThalabTheme.foxOrange),
                    ),
                  ),
                  Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ThalabTheme.foxOrange.withOpacity(0.35),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_tasbihCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 50,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          'اضغط للتسبيح',
                          style: TextStyle(color: Colors.white70, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: ThalabTheme.foxOrange,
                side: const BorderSide(color: ThalabTheme.foxOrange),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _resetTasbih,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('تصفير العداد الحالي', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
