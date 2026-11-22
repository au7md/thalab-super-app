import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart' as quran;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _lastPage = 1;
  int _khatmahGoalDays = 30;
  int _completedPagesCount = 0;
  Set<String> _bookmarkedPages = {};
  Set<String> _completedPagesSet = {};

  bool _isDownloadingOffline = false;
  int _downloadedOfflineCount = 0;

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
    final savedBookmarks = prefs.getStringList('quran_bookmarks') ?? [];
    final savedCompleted = prefs.getStringList('quran_completed_pages') ?? [];

    setState(() {
      _lastPage = prefs.getInt('quran_last_page') ?? 1;
      _khatmahGoalDays = prefs.getInt('khatmah_goal_days') ?? 30;
      _bookmarkedPages = savedBookmarks.toSet();
      _completedPagesSet = savedCompleted.toSet();
      _completedPagesCount = _completedPagesSet.length;
    });
    await prefs.setInt('khatmah_pages_read', _completedPagesCount);
  }

  Future<void> _openPage(int pageNumber, {bool isFirstTimePrompt = true}) async {
    final safePage = pageNumber.clamp(1, 604);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quran_last_page', safePage);
    setState(() => _lastPage = safePage);

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuranPageReaderScreen(
          initialPage: safePage,
          onDownloadAllRequested: _startOfflineDownloadAll,
        ),
      ),
    );
    _loadProgress();
  }

  Future<void> _startOfflineDownloadAll() async {
    if (_isDownloadingOffline) return;
    setState(() {
      _isDownloadingOffline = true;
      _downloadedOfflineCount = 0;
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final quranDir = Directory('${dir.path}/mushaf_pages');
      if (!await quranDir.exists()) {
        await quranDir.create(recursive: true);
      }

      final client = HttpClient();
      for (int p = 1; p <= 604; p++) {
        if (!mounted) break;
        final file = File('${quranDir.path}/page_$p.png');
        if (await file.exists() && await file.length() > 1024) {
          setState(() => _downloadedOfflineCount = p);
          continue;
        }
        final padded = p.toString().padLeft(3, '0');
        final url = Uri.parse('https://android.quran.com/data/width_1024/page$padded.png');
        try {
          final req = await client.getUrl(url).timeout(const Duration(seconds: 10));
          final res = await req.close();
          if (res.statusCode == 200) {
            final bytes = await res.fold<List<int>>([], (prev, element) => prev..addAll(element));
            await file.writeAsBytes(bytes);
          }
        } catch (_) {}
        if (mounted) {
          setState(() => _downloadedOfflineCount = p);
        }
      }
      client.close();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('mushaf_offline_downloaded', true);
    } finally {
      if (mounted) {
        setState(() => _isDownloadingOffline = false);
      }
    }
  }

  void _openWirdSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThalabTheme.cardSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final int pagesPerDay = (604 / _khatmahGoalDays).ceil();
          final int remainingPages = (604 - _completedPagesCount).clamp(0, 604);
          final int estimatedDaysLeft = (remainingPages / pagesPerDay).ceil();
          final double progressPct = (_completedPagesCount / 604).clamp(0.0, 1.0);

          final int wirdStartPage = (_completedPagesCount + 1).clamp(1, 604);
          final int wirdEndPage = (wirdStartPage + pagesPerDay - 1).clamp(1, 604);
          final startData = quran.getPageData(wirdStartPage).first;
          final endData = quran.getPageData(wirdEndPage).last;

          return Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 34),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'إعدادات الورد والختمة المتكاملة',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ThalabTheme.foxOrange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(progressPct * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: ThalabTheme.foxOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progressPct,
                    minHeight: 8,
                    backgroundColor: ThalabTheme.softBorder,
                    valueColor: const AlwaysStoppedAnimation(ThalabTheme.foxOrange),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ThalabTheme.creamBackground,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: ThalabTheme.softBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('بداية ورد اليوم',
                              style: TextStyle(fontSize: 11, color: ThalabTheme.mutedSlate)),
                          Text(
                            '${quran.getSurahNameArabic(startData['surah'])} : ${startData['start']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('نهاية الورد (ص $wirdEndPage)',
                              style: const TextStyle(fontSize: 11, color: ThalabTheme.mutedSlate)),
                          Text(
                            '${quran.getSurahNameArabic(endData['surah'])} : ${endData['end']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'مدة الختمة المستهدفة: $_khatmahGoalDays يوماً ($pagesPerDay صفحة يومياً)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                Text(
                  'المتبقي لإنهاء الختمة: $estimatedDaysLeft يوماً ($_completedPagesCount / 604 صفحة)',
                  style: const TextStyle(fontSize: 12, color: ThalabTheme.mutedSlate),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [7, 15, 30, 60].map((days) {
                    final selected = _khatmahGoalDays == days;
                    return ChoiceChip(
                      label: Text(
                        '$days يوم',
                        style: TextStyle(
                          color: selected ? Colors.white : ThalabTheme.darkSlate,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      selected: selected,
                      selectedColor: ThalabTheme.foxOrange,
                      onSelected: (_) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setInt('khatmah_goal_days', days);
                        setState(() => _khatmahGoalDays = days);
                        setSheetState(() {});
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThalabTheme.foxOrange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openPage(wirdStartPage);
                        },
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text('ابدأ ورد اليوم (ص $wirdStartPage)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setStringList('quran_completed_pages', []);
                        await prefs.setInt('khatmah_pages_read', 0);
                        setState(() {
                          _completedPagesSet.clear();
                          _completedPagesCount = 0;
                        });
                        setSheetState(() {});
                      },
                      child: const Text('تصفير الختمة'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openBookmarksSheet() {
    final sorted = _bookmarkedPages.map(int.parse).toList()..sort();
    showModalBottomSheet(
      context: context,
      backgroundColor: ThalabTheme.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('العلامات المرجعية المحفوظة',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (sorted.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('لا توجد علامات مرجعية محفوظة بعد',
                    style: TextStyle(color: ThalabTheme.mutedSlate)),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sorted.map((p) {
                  final surahNum = quran.getPageData(p).first['surah'] as int;
                  return ActionChip(
                    avatar: const Icon(Icons.bookmark_rounded, size: 16, color: ThalabTheme.foxOrange),
                    label: Text('ص $p (${quran.getSurahNameArabic(surahNum)})'),
                    onPressed: () {
                      Navigator.pop(context);
                      _openPage(p);
                    },
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastPageSurah = quran.getPageData(_lastPage).first['surah'] as int;
    final lastSurahName = quran.getSurahNameArabic(lastPageSurah);
    final int pagesPerDay = (604 / _khatmahGoalDays).ceil();
    final int nextWirdPage = (_completedPagesCount + 1).clamp(1, 604);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المصحف الشريف'),
        actions: [
          IconButton(
            tooltip: 'البحث في آيات القرآن والسور',
            icon: const Icon(Icons.search_rounded, color: ThalabTheme.foxOrange),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _QuranSmartSearchDelegate(
                  onSelectPage: (page) => _openPage(page),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'إعدادات الورد والختمة',
            icon: const Icon(Icons.tune_rounded, color: ThalabTheme.foxOrange),
            onPressed: _openWirdSettingsSheet,
          ),
          IconButton(
            tooltip: 'العلامات المرجعية',
            icon: const Icon(Icons.bookmark_rounded, color: ThalabTheme.foxOrange),
            onPressed: _openBookmarksSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط تقدم التنزيل أوفلاين إذا كان نشطاً
          if (_isDownloadingOffline)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: ThalabTheme.foxOrange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: ThalabTheme.foxOrange),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'جاري تنزيل المصحف المصور للعمل بدون إنترنت: $_downloadedOfflineCount / 604',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          // شريط المتابعة من حيث توقفت (مدمج وأنيق)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: GestureDetector(
              onTap: () => _openPage(_lastPage),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: ThalabTheme.foxOrange.withOpacity(0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'متابعة القراءة من حيث توقفت',
                            style: TextStyle(color: Colors.white70, fontSize: 11.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'سورة $lastSurahName • صفحة $_lastPage',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'الورد اليومي ($pagesPerDay ص) • ص $nextWirdPage',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'متابعة',
                        style: TextStyle(
                          color: ThalabTheme.foxOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // تبويب السور والأجزاء
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
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
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: ThalabTheme.darkSlate,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.all(4),
              tabs: const [
                Tab(text: 'السور (114)'),
                Tab(text: 'الأجزاء (30)'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSurahsList(),
                _buildJuzList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurahsList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      itemCount: 114,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final surahNum = index + 1;
        final nameAr = quran.getSurahNameArabic(surahNum);
        final versesCount = quran.getVerseCount(surahNum);
        final place = quran.getPlaceOfRevelation(surahNum) == 'Makkah' ? 'مكية' : 'مدنية';
        final startPage = quran.getSurahPages(surahNum).first;

        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openPage(startPage),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: ThalabTheme.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ThalabTheme.softBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
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
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'سورة $nameAr',
                        style: GoogleFonts.amiri(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: ThalabTheme.darkSlate,
                        ),
                      ),
                      Text(
                        '$place • $versesCount آية',
                        style: const TextStyle(fontSize: 11.5, color: ThalabTheme.mutedSlate),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ThalabTheme.creamBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'ص $startPage',
                    style: const TextStyle(
                      color: ThalabTheme.foxOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildJuzList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      itemCount: 30,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final juzNum = index + 1;
        final juzSurahs = quran.getSurahAndVersesFromJuz(juzNum);
        final firstSurah = juzSurahs.keys.first;
        final firstVerse = juzSurahs[firstSurah]!.first;
        final page = quran.getPageNumber(firstSurah, firstVerse);

        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openPage(page),
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
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ThalabTheme.foxOrange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$juzNum',
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
                        'الجزء $juzNum',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'يبدأ من سورة ${quran.getSurahNameArabic(firstSurah)} (آية $firstVerse)',
                        style: const TextStyle(fontSize: 11.5, color: ThalabTheme.mutedSlate),
                      ),
                    ],
                  ),
                ),
                Text(
                  'ص $page',
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
    );
  }
}

// =========================================================================
// قارئ صفحات المصحف (المصور أوفلاين + الخط الأميري العثماني المريح)
// =========================================================================
class QuranPageReaderScreen extends StatefulWidget {
  final int initialPage;
  final VoidCallback onDownloadAllRequested;

  const QuranPageReaderScreen({
    super.key,
    required this.initialPage,
    required this.onDownloadAllRequested,
  });

  @override
  State<QuranPageReaderScreen> createState() => _QuranPageReaderScreenState();
}

class _QuranPageReaderScreenState extends State<QuranPageReaderScreen> {
  late PageController _pageController;
  late int _currentPage;
  bool _isImageMushaf = true; // الأولوية للمصحف المصور
  double _fontSize = 23.0;
  bool _isNightPaper = false;
  Set<String> _bookmarks = {};
  Set<String> _completedPages = {};
  String _docsPath = '';

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: _currentPage - 1);
    _initReaderPrefs();
  }

  Future<void> _initReaderPrefs() async {
    final dir = await getApplicationDocumentsDirectory();
    final prefs = await SharedPreferences.getInstance();
    final askedOffline = prefs.getBool('mushaf_asked_offline_download') ?? false;
    final alreadyDownloaded = prefs.getBool('mushaf_offline_downloaded') ?? false;

    setState(() {
      _docsPath = dir.path;
      _isImageMushaf = prefs.getBool('quran_is_image_mode') ?? true;
      _fontSize = prefs.getDouble('quran_font_size') ?? 23.0;
      _isNightPaper = prefs.getBool('quran_night_paper') ?? false;
      _bookmarks = (prefs.getStringList('quran_bookmarks') ?? []).toSet();
      _completedPages = (prefs.getStringList('quran_completed_pages') ?? []).toSet();
    });

    if (!askedOffline && !alreadyDownloaded && mounted) {
      await prefs.setBool('mushaf_asked_offline_download', true);
      _showOfflineDownloadDialog();
    }
  }

  void _showOfflineDownloadDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThalabTheme.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.download_for_offline_rounded, color: ThalabTheme.foxOrange),
            SizedBox(width: 8),
            Expanded(
              child: Text('تنزيل المصحف المصور أوفلاين', style: TextStyle(fontSize: 17)),
            ),
          ],
        ),
        content: const Text(
          'هل ترغب في تنزيل صفحات المصحف الشريف المصور (604 صفحة) على جهازك الآن لتتمكن من القراءة في أي وقت بدون إنترنت؟',
          style: TextStyle(height: 1.5, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لاحقاً (قراءة بالإنترنت)',
                style: TextStyle(color: ThalabTheme.mutedSlate)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThalabTheme.foxOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDownloadAllRequested();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('بدأ تنزيل صفحات المصحف في الخلفية بنجاح'),
                ),
              );
            },
            child: const Text('تنزيل الآن'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePageVisit(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quran_last_page', page);
  }

  Future<void> _toggleBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _currentPage.toString();
    setState(() {
      if (_bookmarks.contains(key)) {
        _bookmarks.remove(key);
      } else {
        _bookmarks.add(key);
      }
    });
    await prefs.setStringList('quran_bookmarks', _bookmarks.toList());
  }

  Future<void> _togglePageCompleted() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    final key = _currentPage.toString();
    setState(() {
      if (_completedPages.contains(key)) {
        _completedPages.remove(key);
      } else {
        _completedPages.add(key);
      }
    });
    await prefs.setStringList('quran_completed_pages', _completedPages.toList());
    await prefs.setInt('khatmah_pages_read', _completedPages.length);
  }

  void _openDisplaySettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThalabTheme.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إعدادات عرض المصحف',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('المصحف المصور (الافتراضي)')),
                      selected: _isImageMushaf,
                      selectedColor: ThalabTheme.foxOrange,
                      labelStyle: TextStyle(
                        color: _isImageMushaf ? Colors.white : ThalabTheme.darkSlate,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (_) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('quran_is_image_mode', true);
                        setState(() => _isImageMushaf = true);
                        setModalState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('النص العثماني (أميري)')),
                      selected: !_isImageMushaf,
                      selectedColor: ThalabTheme.foxOrange,
                      labelStyle: TextStyle(
                        color: !_isImageMushaf ? Colors.white : ThalabTheme.darkSlate,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (_) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('quran_is_image_mode', false);
                        setState(() => _isImageMushaf = false);
                        setModalState(() {});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (!_isImageMushaf) ...[
                Text('حجم الخط العثماني: ${_fontSize.toInt()}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Slider(
                  value: _fontSize,
                  min: 18,
                  max: 34,
                  activeColor: ThalabTheme.foxOrange,
                  onChanged: (val) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setDouble('quran_font_size', val);
                    setState(() => _fontSize = val);
                    setModalState(() {});
                  },
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('وضع القراءة الليلية الهادئة'),
                activeColor: ThalabTheme.foxOrange,
                value: _isNightPaper,
                onChanged: (val) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('quran_night_paper', val);
                  setState(() => _isNightPaper = val);
                  setModalState(() {});
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDownloadAllRequested();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('بدأ تنزيل صفحات المصحف المصور للعمل أوفلاين')),
                    );
                  },
                  icon: const Icon(Icons.download_for_offline_rounded, color: ThalabTheme.foxOrange),
                  label: const Text('تنزيل كل الصفحات (604) للقراءة بدون إنترنت'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageData = quran.getPageData(_currentPage);
    final firstSurah = pageData.first['surah'] as int;
    final firstVerse = pageData.first['start'] as int;
    final juzNumber = quran.getJuzNumber(firstSurah, firstVerse);
    final isBookmarked = _bookmarks.contains(_currentPage.toString());
    final isCompleted = _completedPages.contains(_currentPage.toString());

    final paperBg = _isNightPaper ? const Color(0xFF1A1816) : const Color(0xFFFFFCF7);

    return Scaffold(
      backgroundColor: paperBg,
      appBar: AppBar(
        backgroundColor: paperBg,
        title: Text(
          'سورة ${quran.getSurahNameArabic(firstSurah)} • الجزء $juzNumber',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.bold,
            color: _isNightPaper ? Colors.white : ThalabTheme.darkSlate,
          ),
        ),
        iconTheme: IconThemeData(color: _isNightPaper ? Colors.white : ThalabTheme.darkSlate),
        actions: [
          IconButton(
            tooltip: 'حفظ علامة مرجعية',
            icon: Icon(
              isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: ThalabTheme.foxOrange,
            ),
            onPressed: _toggleBookmark,
          ),
          IconButton(
            tooltip: 'مشاركة الصفحة',
            icon: const Icon(Icons.share_rounded, color: ThalabTheme.foxOrange),
            onPressed: () {
              Share.share('أقرأ الآن سورة ${quran.getSurahNameArabic(firstSurah)} - صفحة $_currentPage من تطبيق الثعلب.');
            },
          ),
          IconButton(
            tooltip: 'إعدادات العرض (مصور / نصي)',
            icon: const Icon(Icons.tune_rounded, color: ThalabTheme.foxOrange),
            onPressed: _openDisplaySettings,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: 604,
        onPageChanged: (index) {
          final newPage = index + 1;
          setState(() => _currentPage = newPage);
          _savePageVisit(newPage);
        },
        itemBuilder: (context, index) {
          final pageNum = index + 1;
          return _isImageMushaf
              ? _buildImageMushafPage(pageNum)
              : _buildUthmaniTextPage(pageNum);
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        color: paperBg,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _isNightPaper ? const Color(0xFF2A2622) : ThalabTheme.cardSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: ThalabTheme.softBorder),
              ),
              child: Text(
                'صفحة $_currentPage / 604',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: _isNightPaper ? Colors.white : ThalabTheme.darkSlate,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCompleted ? const Color(0xFF1B8A5A) : ThalabTheme.foxOrange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: _togglePageCompleted,
                icon: Icon(
                  isCompleted ? Icons.check_circle_rounded : Icons.task_alt_rounded,
                  size: 20,
                ),
                label: Text(
                  isCompleted ? 'تمت قراءة الصفحة ✓' : 'إتمام الصفحة في الختمة',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageMushafPage(int pageNum) {
    final padded = pageNum.toString().padLeft(3, '0');
    final imageUrl = 'https://android.quran.com/data/width_1024/page$padded.png';
    final localFile = _docsPath.isNotEmpty ? File('$_docsPath/mushaf_pages/page_$pageNum.png') : null;
    final hasLocalFile = localFile != null && localFile.existsSync();

    Widget imageWidget;
    if (hasLocalFile) {
      imageWidget = Image.file(localFile, fit: BoxFit.contain);
    } else {
      imageWidget = Image.network(
        imageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: ThalabTheme.foxOrange),
          );
        },
        errorBuilder: (_, __, ___) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 46, color: ThalabTheme.foxOrange),
                const SizedBox(height: 12),
                const Text(
                  'تعذر تحميل صورة الصفحة لعدم توفر اتصال بالإنترنت.\nيمكنك التبديل الفوري إلى النص العثماني (أميري) أو تنزيل الصفحات عند توفر الشبكة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, height: 1.6, color: ThalabTheme.mutedSlate),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThalabTheme.foxOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => setState(() => _isImageMushaf = false),
                  icon: const Icon(Icons.text_fields_rounded),
                  label: const Text('التحويل للنص العثماني الآن'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isNightPaper) {
      imageWidget = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1, 0, 0, 0, 255,
          0, -1, 0, 0, 255,
          0, 0, -1, 0, 255,
          0, 0, 0, 1, 0,
        ]),
        child: imageWidget,
      );
    }

    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 3.0,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: imageWidget,
        ),
      ),
    );
  }

  Widget _buildUthmaniTextPage(int pageNum) {
    final segments = quran.getPageData(pageNum);
    final textColor = _isNightPaper ? const Color(0xFFF4EDE4) : const Color(0xFF1F1D1A);
    final frameBg = _isNightPaper ? const Color(0xFF23201D) : const Color(0xFFFFFAF2);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: frameBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: ThalabTheme.foxOrange.withOpacity(0.45),
            width: 1.6,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: segments.map((seg) {
            final int surahNum = seg['surah'] as int;
            final int startVerse = seg['start'] as int;
            final int endVerse = seg['end'] as int;

            final List<InlineSpan> verseSpans = [];
            for (int v = startVerse; v <= endVerse; v++) {
              final verseText = quran.getVerse(surahNum, v, verseEndSymbol: false);
              verseSpans.add(
                TextSpan(
                  text: '$verseText ',
                  style: GoogleFonts.amiriQuran(
                    fontSize: _fontSize,
                    height: 2.25,
                    color: textColor,
                  ),
                ),
              );
              verseSpans.add(
                TextSpan(
                  text: ' ﴿${_toArabicDigits(v)}﴾ ',
                  style: GoogleFonts.amiri(
                    fontSize: _fontSize * 0.85,
                    fontWeight: FontWeight.bold,
                    color: ThalabTheme.foxOrange,
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (startVerse == 1) ...[
                  // إطار زخرفي مستقل لاسم السورة
                  Container(
                    margin: const EdgeInsets.only(bottom: 10, top: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ThalabTheme.foxOrange.withOpacity(0.16),
                          ThalabTheme.foxOrangeLight.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ThalabTheme.foxOrange.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          quran.getPlaceOfRevelation(surahNum) == 'Makkah' ? 'مكية' : 'مدنية',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: ThalabTheme.foxOrange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'سورة ${quran.getSurahNameArabic(surahNum)}',
                          style: GoogleFonts.amiri(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: ThalabTheme.foxOrange,
                          ),
                        ),
                        Text(
                          'آياتها ${quran.getVerseCount(surahNum)}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: ThalabTheme.foxOrange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // سطر البسملة المستقل تماماً عن الآيات (ما عدا الفاتحة والتوبة)
                  if (surahNum != 1 && surahNum != 9)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        quran.basmala,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.amiriQuran(
                          fontSize: _fontSize * 0.95,
                          height: 1.9,
                          color: textColor,
                        ),
                      ),
                    ),
                ],
                RichText(
                  textAlign: TextAlign.justify,
                  textDirection: TextDirection.rtl,
                  text: TextSpan(children: verseSpans),
                ),
                const SizedBox(height: 10),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _toArabicDigits(int number) {
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String str = number.toString();
    for (int i = 0; i < 10; i++) {
      str = str.replaceAll(en[i], ar[i]);
    }
    return str;
  }
}

// =========================================================================
// محرك البحث الذكي في القرآن الكريم (بدون تشكيل + يفتح المصحف المصور مباشرة)
// =========================================================================
class _QuranSmartSearchDelegate extends SearchDelegate<void> {
  final ValueChanged<int> onSelectPage;

  _QuranSmartSearchDelegate({required this.onSelectPage});

  @override
  String get searchFieldLabel => 'ابحث بكلمة أو آية أو اسم سورة...';

  String _normalize(String s) {
    return s
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'), '')
        .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .trim();
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildMatches(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildMatches(context);

  Widget _buildMatches(BuildContext context) {
    final q = _normalize(query);
    if (q.length < 2) {
      return const Center(
        child: Text(
          'اكتب كلمتين أو أكثر للبحث في جميع آيات القرآن الكريم والسور',
          style: TextStyle(color: ThalabTheme.mutedSlate),
        ),
      );
    }

    final List<Map<String, dynamic>> results = [];

    // 1. البحث في أسماء السور
    for (int s = 1; s <= 114; s++) {
      final sName = quran.getSurahNameArabic(s);
      if (_normalize(sName).contains(q)) {
        results.add({
          'type': 'surah',
          'surah': s,
          'verse': 1,
          'title': 'سورة $sName',
          'snippet': 'الانتقال إلى بداية سورة $sName',
          'page': quran.getSurahPages(s).first,
        });
      }
    }

    // 2. البحث في الآيات بدون تشكيل
    for (int s = 1; s <= 114; s++) {
      if (results.length >= 60) break;
      final count = quran.getVerseCount(s);
      for (int v = 1; v <= count; v++) {
        final rawVerse = quran.getVerse(s, v);
        if (_normalize(rawVerse).contains(q)) {
          results.add({
            'type': 'verse',
            'surah': s,
            'verse': v,
            'title': 'سورة ${quran.getSurahNameArabic(s)} • آية $v',
            'snippet': rawVerse,
            'page': quran.getPageNumber(s, v),
          });
          if (results.length >= 60) break;
        }
      }
    }

    if (results.isEmpty) {
      return const Center(
        child: Text(
          'لم يتم العثور على نتائج مطابقة',
          style: TextStyle(color: ThalabTheme.mutedSlate, fontSize: 15),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = results[index];
        final int page = item['page'] as int;
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            // تفعيل المصحف المصور كأولوية عند فتح نتيجة البحث
            await prefs.setBool('quran_is_image_mode', true);
            if (context.mounted) {
              close(context, null);
              onSelectPage(page);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ThalabTheme.cardSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ThalabTheme.softBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item['title'] as String,
                      style: const TextStyle(
                        color: ThalabTheme.foxOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ThalabTheme.creamBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'المصحف المصور • ص $page',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item['snippet'] as String,
                  style: GoogleFonts.amiri(
                    fontSize: 19,
                    height: 1.8,
                    color: ThalabTheme.darkSlate,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
