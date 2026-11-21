import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:quran/quran.dart' as quran;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme.dart';
import '../../core/storage_service.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _savedPage = 1;
  int _khatmahDays = 30;
  int _khatmahPagesRead = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProgress();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPage = StorageService.getLastSurah();
      _khatmahDays = prefs.getInt('khatmah_days') ?? 30;
      _khatmahPagesRead = prefs.getInt('khatmah_pages_read') ?? 0;
    });
  }

  Future<void> _configureKhatmah() async {
    int tempDays = _khatmahDays;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: ThalabTheme.cardSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('إعداد خطة الختمة', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('حدد مدة الختمة بالأيام (604 صفحة):'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: ThalabTheme.foxOrange),
                    onPressed: () {
                      if (tempDays > 3) setDialogState(() => tempDays--);
                    },
                  ),
                  Text('$tempDays يوم', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: ThalabTheme.foxOrange),
                    onPressed: () {
                      if (tempDays < 365) setDialogState(() => tempDays++);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'الورد اليومي: ${(604 / tempDays).ceil()} صفحة يومياً',
                style: const TextStyle(color: ThalabTheme.foxOrange, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('khatmah_pages_read', 0);
                setState(() => _khatmahPagesRead = 0);
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text('تصفير الختمة', style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ThalabTheme.foxOrange,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('khatmah_days', tempDays);
                setState(() => _khatmahDays = tempDays);
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _openReader(int page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MushafReaderScreen(initialPage: page)),
    );
    _loadProgress();
  }

  void _openGlobalSearch() {
    showSearch(
      context: context,
      delegate: QuranGlobalSearchDelegate(onSelectPage: _openReader),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int dailyGoal = (604 / _khatmahDays).ceil();
    final int startWirdPage = (_khatmahPagesRead + 1).clamp(1, 604);
    final int endWirdPage = (_khatmahPagesRead + dailyGoal).clamp(1, 604);
    final double khatmahPct = (_khatmahPagesRead / 604).clamp(0.0, 1.0);
    final int daysLeft = ((604 - _khatmahPagesRead) / dailyGoal).ceil();

    final startData = quran.getPageData(startWirdPage);
    final endData = quran.getPageData(endWirdPage);
    final String startSurah = startData.isNotEmpty
        ? '${quran.getSurahNameArabic(startData.first['surah'])} : ${startData.first['start']}'
        : 'الفاتحة : 1';
    final String endSurah = endData.isNotEmpty
        ? '${quran.getSurahNameArabic(endData.last['surah'])} : ${endData.last['end']}'
        : 'الناس : 6';

    return Scaffold(
      appBar: AppBar(
        title: const Text('القرآن الكريم'),
        actions: [
          IconButton(
            tooltip: 'بحث في السور والآيات',
            icon: const Icon(Icons.search_rounded, color: ThalabTheme.foxOrange, size: 26),
            onPressed: _openGlobalSearch,
          ),
          IconButton(
            tooltip: 'العلامة المحفوظة',
            icon: const Icon(Icons.bookmark_rounded, color: ThalabTheme.foxOrange, size: 26),
            onPressed: () => _openReader(_savedPage),
          ),
        ],
      ),
      body: Column(
        children: [
          // بطاقة الختمة اليومية المتكاملة (بداية الورد - المتابعة - نهاية الورد)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThalabTheme.cardSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: ThalabTheme.softBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: ThalabTheme.foxOrange.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: ThalabTheme.foxOrange.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'ختمة $_khatmahDays يوم',
                          style: const TextStyle(
                            color: ThalabTheme.foxOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'متبقي $daysLeft يوم',
                        style: const TextStyle(fontSize: 12, color: ThalabTheme.mutedSlate),
                      ),
                      const Spacer(),
                      Text(
                        '${(khatmahPct * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ThalabTheme.foxOrange,
                          fontSize: 15,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.tune_rounded, size: 20, color: ThalabTheme.darkSlate),
                        onPressed: _configureKhatmah,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: khatmahPct,
                      minHeight: 6,
                      backgroundColor: ThalabTheme.softBorder,
                      valueColor: const AlwaysStoppedAnimation<Color>(ThalabTheme.foxOrange),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _WirdPoint(label: 'بداية الورد', value: startSurah),
                      _WirdPoint(label: 'نهاية الورد (ص $endWirdPage)', value: endSurah, alignEnd: true),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThalabTheme.foxOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _openReader(_savedPage),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text('متابعة الورد (صفحة $_savedPage)', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // شريط التبويب (السور / الأجزاء)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: ThalabTheme.cardSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ThalabTheme.softBorder),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: ThalabTheme.foxOrange,
                borderRadius: BorderRadius.circular(14),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: ThalabTheme.darkSlate,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'السور (114)'),
                Tab(text: 'الأجزاء (30)'),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // قائمة السور والأجزاء
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // تبويب السور
                ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                  itemCount: 114,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final surahNum = index + 1;
                    final name = quran.getSurahNameArabic(surahNum);
                    final verses = quran.getVerseCount(surahNum);
                    final place = quran.getPlaceOfRevelation(surahNum) == 'Makkah' ? 'مكية' : 'مدنية';
                    final startPage = quran.getPageNumber(surahNum, 1);

                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _openReader(startPage),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: ThalabTheme.cardSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: ThalabTheme.softBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: ThalabTheme.foxOrange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$surahNum',
                                style: const TextStyle(color: ThalabTheme.foxOrange, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('سورة $name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('$place • $verses آية', style: const TextStyle(fontSize: 12, color: ThalabTheme.mutedSlate)),
                                ],
                              ),
                            ),
                            Text('ص $startPage', style: const TextStyle(color: ThalabTheme.foxOrange, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // تبويب الأجزاء الـ 30
                ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                  itemCount: 30,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final juzNum = index + 1;
                    final juzSurahs = quran.getSurahAndVersesFromJuz(juzNum);
                    final firstSurah = juzSurahs.keys.first;
                    final firstVerse = juzSurahs[firstSurah]!.first;
                    final startPage = quran.getPageNumber(firstSurah, firstVerse);

                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _openReader(startPage),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: ThalabTheme.cardSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: ThalabTheme.softBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: ThalabTheme.foxOrange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$juzNum',
                                style: const TextStyle(color: ThalabTheme.foxOrange, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('الجزء $juzNum', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(
                                    'يبدأ من سورة ${quran.getSurahNameArabic(firstSurah)} آية $firstVerse',
                                    style: const TextStyle(fontSize: 12, color: ThalabTheme.mutedSlate),
                                  ),
                                ],
                              ),
                            ),
                            Text('ص $startPage', style: const TextStyle(color: ThalabTheme.foxOrange, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WirdPoint extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _WirdPoint({required this.label, required this.value, this.alignEnd = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: ThalabTheme.mutedSlate)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class MushafReaderScreen extends StatefulWidget {
  final int initialPage;
  const MushafReaderScreen({super.key, required this.initialPage});

  @override
  State<MushafReaderScreen> createState() => _MushafReaderScreenState();
}

class _MushafReaderScreenState extends State<MushafReaderScreen> {
  late PageController _controller;
  late int _currentPage;
  bool _nightMode = false;
  bool _isImageMode = true; // الأولوية للمصحف المصور
  double _fontSize = 22.0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(1, 604);
    _controller = PageController(initialPage: _currentPage - 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onPageChanged(int page) async {
    setState(() => _currentPage = page);
    await StorageService.setLastSurah(page);
  }

  Future<void> _markPageComplete() async {
    final prefs = await SharedPreferences.getInstance();
    final currentRead = prefs.getInt('khatmah_pages_read') ?? 0;
    if (_currentPage > currentRead) {
      await prefs.setInt('khatmah_pages_read', _currentPage);
    }
    HapticFeedback.mediumImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تسجيل إنجاز صفحة $_currentPage في الختمة ✓'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _openSettingsBar() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _nightMode ? const Color(0xFF1E1C1A) : ThalabTheme.cardSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إعدادات العرض والقراءة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _nightMode ? Colors.white : ThalabTheme.darkSlate,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('المصحف المصور')),
                      selected: _isImageMode,
                      selectedColor: ThalabTheme.foxOrange,
                      onSelected: (_) {
                        setSheetState(() => _isImageMode = true);
                        setState(() => _isImageMode = true);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('الوضع النصي التفاعلي')),
                      selected: !_isImageMode,
                      selectedColor: ThalabTheme.foxOrange,
                      onSelected: (_) {
                        setSheetState(() => _isImageMode = false);
                        setState(() => _isImageMode = false);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'الوضع الليلي المريح',
                  style: TextStyle(color: _nightMode ? Colors.white : ThalabTheme.darkSlate),
                ),
                activeColor: ThalabTheme.foxOrange,
                value: _nightMode,
                onChanged: (val) {
                  setSheetState(() => _nightMode = val);
                  setState(() => _nightMode = val);
                },
              ),
              if (!_isImageMode) ...[
                Text(
                  'حجم الخط النصي: ${_fontSize.toInt()}',
                  style: TextStyle(color: _nightMode ? Colors.white70 : ThalabTheme.mutedSlate),
                ),
                Slider(
                  value: _fontSize,
                  min: 18,
                  max: 32,
                  activeColor: ThalabTheme.foxOrange,
                  onChanged: (val) {
                    setSheetState(() => _fontSize = val);
                    setState(() => _fontSize = val);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showPageVersesSheet() {
    final entries = quran.getPageData(_currentPage);
    showModalBottomSheet(
      context: context,
      backgroundColor: ThalabTheme.cardSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            const Text('اختر آية للنسخ أو المشاركة كبطاقة صورة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...entries.expand((entry) {
              final int s = entry['surah'];
              final int start = entry['start'];
              final int end = entry['end'];
              return List.generate(end - start + 1, (i) {
                final v = start + i;
                final verseText = quran.getVerse(s, v);
                final surahName = quran.getSurahNameArabic(s);
                return Card(
                  color: ThalabTheme.creamBackground,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('$verseText ﴿$v﴾', style: const TextStyle(fontSize: 17, height: 1.7)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              label: const Text('نسخ'),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: '$verseText ﴿$surahName: $v﴾'));
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم نسخ الآية الكريمة')),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ThalabTheme.foxOrange,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.image_rounded, size: 18),
                              label: const Text('مشاركة كصورة'),
                              onPressed: () {
                                Navigator.pop(ctx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => VerseShareCardScreen(
                                      verseText: verseText,
                                      surahName: surahName,
                                      verseNumber: v,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              });
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageData = quran.getPageData(_currentPage);
    final firstSurah = pageData.isNotEmpty ? pageData.first['surah'] as int : 1;
    final surahTitle = quran.getSurahNameArabic(firstSurah);
    final juzNum = pageData.isNotEmpty ? quran.getJuzNumber(firstSurah, pageData.first['start']) : 1;

    return Scaffold(
      backgroundColor: _nightMode ? const Color(0xFF121110) : const Color(0xFFFFFCF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: _nightMode ? Colors.white : ThalabTheme.darkSlate,
        title: Text(
          'سورة $surahTitle • الجزء $juzNum',
          style: TextStyle(fontSize: 15, color: _nightMode ? Colors.white : ThalabTheme.darkSlate),
        ),
        actions: [
          IconButton(
            tooltip: 'مشاركة آية من الصفحة',
            icon: const Icon(Icons.share_rounded),
            onPressed: _showPageVersesSheet,
          ),
          IconButton(
            tooltip: 'إعدادات العرض',
            icon: const Icon(Icons.tune_rounded),
            onPressed: _openSettingsBar,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: 604,
        onPageChanged: (idx) => _onPageChanged(idx + 1),
        itemBuilder: (context, index) {
          final pageNum = index + 1;
          if (_isImageMode) {
            final padded = pageNum.toString().padLeft(3, '0');
            return InteractiveViewer(
              minScale: 1.0,
              maxScale: 3.5,
              child: SizedBox.expand(
                child: ColorFiltered(
                  colorFilter: _nightMode
                      ? const ColorFilter.matrix([
                          -1, 0, 0, 0, 240,
                          0, -1, 0, 0, 240,
                          0, 0, -1, 0, 240,
                          0, 0, 0, 1, 0,
                        ])
                      : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                  child: Image.network(
                    'https://android.quran.com/data/width_1260/page$padded.png',
                    fit: BoxFit.fill,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: ThalabTheme.foxOrange));
                    },
                    errorBuilder: (_, __, ___) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.wifi_off_rounded, size: 48, color: ThalabTheme.foxOrange),
                          const SizedBox(height: 10),
                          Text(
                            'تعذر تحميل صورة الصفحة، يمكنك التحويل للوضع النصي من زر الإعدادات بالأعلى',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _nightMode ? Colors.white70 : ThalabTheme.darkSlate),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          // الوضع النصي المصلح في الوضع الليلي والنهاري
          final entries = quran.getPageData(pageNum);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _nightMode ? const Color(0xFF1C1A17) : ThalabTheme.cardSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: ThalabTheme.foxOrange.withOpacity(0.45), width: 1.8),
              ),
              child: Column(
                children: entries.map((entry) {
                  final int s = entry['surah'];
                  final int start = entry['start'];
                  final int end = entry['end'];
                  final List<String> versesText = [];
                  for (int v = start; v <= end; v++) {
                    versesText.add('${quran.getVerse(s, v)} ﴿$v﴾');
                  }
                  return Column(
                    children: [
                      if (start == 1) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: ThalabTheme.foxOrange.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'سورة ${quran.getSurahNameArabic(s)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: ThalabTheme.foxOrange,
                            ),
                          ),
                        ),
                        if (s != 1 && s != 9)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              quran.basmala,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: _fontSize - 2,
                                fontWeight: FontWeight.bold,
                                color: _nightMode ? const Color(0xFFF5EFE6) : ThalabTheme.darkSlate,
                              ),
                            ),
                          ),
                      ],
                      GestureDetector(
                        onLongPress: _showPageVersesSheet,
                        child: Text(
                          versesText.join(' '),
                          textAlign: TextAlign.justify,
                          style: TextStyle(
                            fontSize: _fontSize,
                            height: 2.0,
                            color: _nightMode ? const Color(0xFFF5EFE6) : ThalabTheme.darkSlate,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
      // شريط التحكم السفلي في قارئ المصحف (رقم الصفحة + تسجيل إتمام الصفحة)
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        color: _nightMode ? const Color(0xFF181614) : ThalabTheme.creamBackground,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ThalabTheme.foxOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: _markPageComplete,
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text('إتمام الصفحة في الختمة'),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _nightMode ? const Color(0xFF262320) : ThalabTheme.cardSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ThalabTheme.softBorder),
              ),
              child: Text(
                'صفحة $_currentPage / 604',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _nightMode ? Colors.white : ThalabTheme.darkSlate,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// شاشة تصميم ومشاركة الآية كبطاقة صورة احترافية
class VerseShareCardScreen extends StatefulWidget {
  final String verseText;
  final String surahName;
  final int verseNumber;

  const VerseShareCardScreen({
    super.key,
    required this.verseText,
    required this.surahName,
    required this.verseNumber,
  });

  @override
  State<VerseShareCardScreen> createState() => _VerseShareCardScreenState();
}

class _VerseShareCardScreenState extends State<VerseShareCardScreen> {
  final GlobalKey _cardKey = GlobalKey();
  bool _darkCard = false;

  Future<void> _captureAndShare() async {
    try {
      final boundary = _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/thalab_ayah_${widget.verseNumber}.png').create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '﴿${widget.verseText}﴾ — سورة ${widget.surahName} (${widget.verseNumber})',
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مشاركة الآية كبطاقة'),
        actions: [
          IconButton(
            tooltip: 'تبديل لون البطاقة',
            icon: Icon(_darkCard ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: () => setState(() => _darkCard = !_darkCard),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RepaintBoundary(
              key: _cardKey,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: _darkCard
                      ? const LinearGradient(colors: [Color(0xFF1F1C18), Color(0xFF2D2721)])
                      : const LinearGradient(colors: [Color(0xFFFFF8F0), Color(0xFFFFEBD6)]),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: ThalabTheme.foxOrange, width: 2),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.auto_stories_rounded, color: ThalabTheme.foxOrange, size: 32),
                    const SizedBox(height: 18),
                    Text(
                      '﴿ ${widget.verseText} ﴾',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        height: 1.9,
                        color: _darkCard ? Colors.white : ThalabTheme.darkSlate,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: ThalabTheme.foxOrange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'سورة ${widget.surahName} • آية ${widget.verseNumber}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'تطبيق الثعلب — رفيق',
                      style: TextStyle(
                        fontSize: 11,
                        color: _darkCard ? Colors.white54 : ThalabTheme.mutedSlate,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThalabTheme.foxOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: _captureAndShare,
                icon: const Icon(Icons.share_rounded),
                label: const Text('مشاركة الصورة الآن', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuranGlobalSearchDelegate extends SearchDelegate {
  final ValueChanged<int> onSelectPage;
  QuranGlobalSearchDelegate({required this.onSelectPage});

  @override
  String get searchFieldLabel => 'ابحث بكلمة من آية أو اسم سورة...';

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildSearchList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchList(context);

  Widget _buildSearchList(BuildContext context) {
    final q = query.trim();
    if (q.isEmpty) {
      return const Center(child: Text('اكتب أي كلمة للبحث في آيات القرآن الكريم'));
    }

    final List<Widget> results = [];
    for (int i = 1; i <= 114; i++) {
      final sName = quran.getSurahNameArabic(i);
      if (sName.contains(q)) {
        final page = quran.getPageNumber(i, 1);
        results.add(
          ListTile(
            leading: const Icon(Icons.menu_book_rounded, color: ThalabTheme.foxOrange),
            title: Text('سورة $sName', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('الانتقال إلى صفحة $page'),
            onTap: () {
              close(context, null);
              onSelectPage(page);
            },
          ),
        );
      }
    }

    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isNotEmpty) {
      final verseMatches = quran.searchWords(words);
      final List<dynamic> list = verseMatches['result'] ?? [];
      for (final item in list.take(40)) {
        final int s = item['surah'];
        final int v = item['verse'];
        final int page = quran.getPageNumber(s, v);
        results.add(
          ListTile(
            leading: const Icon(Icons.format_quote_rounded, color: ThalabTheme.foxOrange),
            title: Text(
              quran.getVerse(s, v),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('سورة ${quran.getSurahNameArabic(s)} • آية $v (صفحة $page)'),
            onTap: () {
              close(context, null);
              onSelectPage(page);
            },
          ),
        );
      }
    }

    if (results.isEmpty) {
      return const Center(child: Text('لا توجد نتائج مطابقة'));
    }
    return ListView(children: results);
  }
}
