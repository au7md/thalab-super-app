import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/storage_service.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  int _savedPage = 1;
  int _khatmahDays = 30;
  int _khatmahPagesRead = 0;

  @override
  void initState() {
    super.initState();
    _loadProgress();
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
          title: const Text('تخطيط الختمة', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('اختر عدد الأيام المستهدفة لإتمام ختمة القرآن الكريم (604 صفحة):'),
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
                  Text(
                    '$tempDays يوم',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
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
                'الورد اليومي المطلوب: ${(604 / tempDays).ceil()} صفحة يومياً',
                style: const TextStyle(
                  color: ThalabTheme.foxOrange,
                  fontWeight: FontWeight.bold,
                ),
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
              child: const Text('حفظ الخطة'),
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
    final int dailyTarget = (604 / _khatmahDays).ceil();
    final double khatmahProgress = (_khatmahPagesRead / 604).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المصحف الشريف'),
        actions: [
          IconButton(
            tooltip: 'بحث في السور والآيات',
            icon: const Icon(Icons.search_rounded, color: ThalabTheme.foxOrange, size: 26),
            onPressed: _openGlobalSearch,
          ),
          IconButton(
            tooltip: 'الانتقال للعلامة المحفوظة',
            icon: const Icon(Icons.bookmark_rounded, color: ThalabTheme.foxOrange, size: 26),
            onPressed: () => _openReader(_savedPage),
          ),
        ],
      ),
      body: Column(
        children: [
          // بطاقة متابعة الختمة والقراءة
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ختمة $_khatmahDays يوم • الورد: $dailyTarget ص/يوم',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'تم إنجاز $_khatmahPagesRead من 604 صفحة (${(khatmahProgress * 100).toStringAsFixed(1)}%)',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'تعديل خطة الختمة',
                        icon: const Icon(Icons.tune_rounded, color: Colors.white),
                        onPressed: _configureKhatmah,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: khatmahProgress,
                      minHeight: 7,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: ThalabTheme.foxOrange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _openReader(_savedPage),
                      child: Text(
                        'متابعة القراءة (صفحة $_savedPage)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // قائمة الـ 114 سورة كاملة بدون نت
          Expanded(
            child: ListView.separated(
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
                            style: const TextStyle(
                              color: ThalabTheme.foxOrange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'سورة $name',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                '$place • $verses آية',
                                style: const TextStyle(fontSize: 12, color: ThalabTheme.mutedSlate),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'ص $startPage',
                          style: const TextStyle(
                            color: ThalabTheme.foxOrange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
  bool _useImageMode = false;

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

  Future<void> _onPageUpdated(int page) async {
    setState(() => _currentPage = page);
    await StorageService.setLastSurah(page);
    final prefs = await SharedPreferences.getInstance();
    final read = prefs.getInt('khatmah_pages_read') ?? 0;
    if (page > read) {
      await prefs.setInt('khatmah_pages_read', page);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageData = quran.getPageData(_currentPage);
    final firstSurah = pageData.isNotEmpty ? pageData.first['surah'] as int : 1;
    final surahTitle = quran.getSurahNameArabic(firstSurah);

    return Scaffold(
      backgroundColor: _nightMode ? const Color(0xFF141210) : const Color(0xFFFFFBF2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: _nightMode ? Colors.white : ThalabTheme.darkSlate,
        title: Text(
          'سورة $surahTitle • ص $_currentPage',
          style: TextStyle(
            fontSize: 16,
            color: _nightMode ? Colors.white : ThalabTheme.darkSlate,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _useImageMode ? 'وضع المصحف المدمج (بدون نت)' : 'وضع الصفحات المصورة (يتطلب إنترنت)',
            icon: Icon(_useImageMode ? Icons.text_fields_rounded : Icons.image_outlined),
            onPressed: () => setState(() => _useImageMode = !_useImageMode),
          ),
          IconButton(
            tooltip: 'الوضع الليلي',
            icon: Icon(_nightMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: () => setState(() => _nightMode = !_nightMode),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: 604,
        onPageChanged: (idx) => _onPageUpdated(idx + 1),
        itemBuilder: (context, index) {
          final pageNum = index + 1;
          if (_useImageMode) {
            final padded = pageNum.toString().padLeft(3, '0');
            return InteractiveViewer(
              child: Center(
                child: Image.network(
                  'https://android.quran.com/data/width_1024/page$padded.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text('تعذر تحميل الصورة، يمكنك التبديل للوضع المدمج من الأعلى'),
                  ),
                ),
              ),
            );
          }

          // العرض النصي العثماني المدمج (يعمل 100% بدون إنترنت)
          final entries = quran.getPageData(pageNum);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _nightMode ? const Color(0xFF1E1B18) : ThalabTheme.cardSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: ThalabTheme.foxOrange.withOpacity(0.45),
                  width: 2,
                ),
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
                            color: ThalabTheme.foxOrange.withOpacity(0.14),
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
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _nightMode ? Colors.white : ThalabTheme.darkSlate,
                              ),
                            ),
                          ),
                      ],
                      Text(
                        versesText.join(' '),
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          fontSize: 21,
                          height: 2.0,
                          color: _nightMode ? Colors.white : ThalabTheme.darkSlate,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
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

    // البحث في أسماء السور
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

    // البحث في نصوص الآيات
    final verseMatches = quran.searchWords(q);
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

    if (results.isEmpty) {
      return const Center(child: Text('لا توجد نتائج مطابقة'));
    }
    return ListView(children: results);
  }
}
