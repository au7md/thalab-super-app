import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  bool _isKhatmahMode = false;
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

  // ألوان متجاوبة مع الثيم
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardBg => Theme.of(context).cardColor;
  Color get _innerBg => Theme.of(context).scaffoldBackgroundColor;
  Color get _borderColor => _isDark ? ThalabTheme.darkBorder : ThalabTheme.softBorder;
  Color get _textColor => _isDark ? ThalabTheme.darkTextPrimary : ThalabTheme.darkSlate;

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBookmarks = prefs.getStringList('quran_bookmarks') ?? [];
    final savedCompleted = prefs.getStringList('quran_completed_pages') ?? [];
    final khatmahEntry = prefs.getBool('quran_is_khatmah_entry') ?? false;

    setState(() {
      _lastPage = prefs.getInt('quran_last_page') ?? 1;
      _khatmahGoalDays = prefs.getInt('khatmah_goal_days') ?? 30;
      _isKhatmahMode = khatmahEntry;
      _bookmarkedPages = savedBookmarks.toSet();
      _completedPagesSet = savedCompleted.toSet();
      _completedPagesCount = _completedPagesSet.length;
    });
    await prefs.setInt('khatmah_pages_read', _completedPagesCount);
  }

  Future<void> _openPage(int pageNumber, {bool? khatmahOverride}) async {
    final safePage = pageNumber.clamp(1, 604);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quran_last_page', safePage);
    final bool effectiveKhatmah = khatmahOverride ?? _isKhatmahMode;
    await prefs.setBool('quran_is_khatmah_entry', effectiveKhatmah);
    setState(() {
      _lastPage = safePage;
      _isKhatmahMode = effectiveKhatmah;
    });

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuranPageReaderScreen(
          initialPage: safePage,
          isKhatmahMode: effectiveKhatmah,
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
      backgroundColor: _cardBg,
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
                    Text(
                      'إعدادات الورد والختمة المتكاملة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textColor,
                      ),
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
                    backgroundColor: _borderColor,
                    valueColor: const AlwaysStoppedAnimation(ThalabTheme.foxOrange),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _innerBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('بداية ورد اليوم',
                              style: TextStyle(fontSize: 11, color: ThalabTheme.mutedText(context))),
                          Text(
                            '${quran.getSurahNameArabic(startData['surah'])} : ${startData['start']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: _textColor,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('نهاية الورد (ص $wirdEndPage)',
                              style: TextStyle(fontSize: 11, color: ThalabTheme.mutedText(context))),
                          Text(
                            '${quran.getSurahNameArabic(endData['surah'])} : ${endData['end']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: _textColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'مدة الختمة المستهدفة: $_khatmahGoalDays يوماً ($pagesPerDay صفحة يومياً)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: _textColor),
                ),
                Text(
                  'المتبقي لإنهاء الختمة: $estimatedDaysLeft يوماً ($_completedPagesCount من 604 صفحة)',
                  style: TextStyle(fontSize: 12, color: ThalabTheme.mutedText(context)),
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
                          color: selected ? Colors.white : _textColor,
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
                          _openPage(wirdStartPage, khatmahOverride: true);
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
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('العلامات المرجعية المحفوظة',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textColor)),
            const SizedBox(height: 12),
            if (sorted.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('لا توجد علامات مرجعية محفوظة بعد',
                    style: TextStyle(color: ThalabTheme.mutedText(context))),
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
                      _openPage(p, khatmahOverride: false);
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
        title: Text(_isKhatmahMode ? 'المصحف والختمة' : 'المصحف الشريف'),
        actions: [
          IconButton(
            tooltip: 'البحث في آيات القرآن والسور',
            icon: const Icon(Icons.search_rounded, color: ThalabTheme.foxOrange),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _QuranSmartSearchDelegate(
                  onSelectPage: (page) => _openPage(page, khatmahOverride: false),
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
                      'جاري تنزيل المصحف المصور للعمل بدون إنترنت: $_downloadedOfflineCount من 604',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: GestureDetector(
              onTap: () => _openPage(_lastPage, khatmahOverride: _isKhatmahMode),
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
                          Text(
                            _isKhatmahMode
                                ? 'متابعة الختمة (ورد اليوم: ص $nextWirdPage)'
                                : 'متابعة القراءة من حيث توقفت',
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
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
                            'الورد اليومي ($pagesPerDay ص) • المنجز $_completedPagesCount من 604',
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
          onTap: () => _openPage(startPage, khatmahOverride: false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _borderColor),
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
                          color: _textColor,
                        ),
                      ),
                      Text(
                        '$place • $versesCount آية',
                        style: TextStyle(fontSize: 11.5, color: ThalabTheme.mutedText(context)),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: ThalabTheme.foxOrange.withOpacity(0.1),
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
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: ThalabTheme.mutedText(context),
                    ),
                  ],
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
          onTap: () => _openPage(page, khatmahOverride: false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _borderColor),
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
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _textColor),
                      ),
                      Text(
                        'يبدأ من سورة ${quran.getSurahNameArabic(firstSurah)} (آية $firstVerse)',
                        style: TextStyle(fontSize: 11.5, color: ThalabTheme.mutedText(context)),
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
// قارئ صفحات المصحف (مُصحح بالكامل للوضع الفاتح والليلي)
// =========================================================================
class QuranPageReaderScreen extends StatefulWidget {
  final int initialPage;
  final bool isKhatmahMode;
  final VoidCallback onDownloadAllRequested;

  const QuranPageReaderScreen({
    super.key,
    required this.initialPage,
    this.isKhatmahMode = false,
    required this.onDownloadAllRequested,
  });

  @override
  State<QuranPageReaderScreen> createState() => _QuranPageReaderScreenState();
}

class _QuranPageReaderScreenState extends State<QuranPageReaderScreen> {
  late PageController _pageController;
  late int _currentPage;
  late bool _isKhatmahMode;
  bool _isImageMushaf = true;
  double _fontSize = 23.0;
  bool _isNightPaper = false;
  bool _isChromeVisible = true;
  Set<String> _bookmarks = {};
  Set<String> _completedPages = {};
  String _docsPath = '';

  final GlobalKey _verseCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _isKhatmahMode = widget.isKhatmahMode;
    _pageController = PageController(initialPage: _currentPage - 1);
    _initReaderPrefs();
  }

  Future<void> _initReaderPrefs() async {
    final dir = await getApplicationDocumentsDirectory();
    final prefs = await SharedPreferences.getInstance();
    final askedOffline = prefs.getBool('mushaf_asked_offline_download') ?? false;
    final alreadyDownloaded = prefs.getBool('mushaf_offline_downloaded') ?? false;
    final khatmahStored = prefs.getBool('quran_is_khatmah_entry') ?? widget.isKhatmahMode;

    setState(() {
      _docsPath = dir.path;
      _isImageMushaf = prefs.getBool('quran_is_image_mode') ?? true;
      _fontSize = prefs.getDouble('quran_font_size') ?? 23.0;
      _isNightPaper = prefs.getBool('quran_night_paper') ?? false;
      _isKhatmahMode = widget.isKhatmahMode || khatmahStored;
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
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.download_for_offline_rounded, color: ThalabTheme.foxOrange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تنزيل المصحف المصور أوفلاين',
                style: TextStyle(
                  fontSize: 17,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? ThalabTheme.darkTextPrimary
                      : ThalabTheme.darkSlate,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'هل ترغب في تنزيل صفحات المصحف الشريف المصور (604 صفحة) على جهازك الآن لتتمكن من القراءة في أي وقت بدون إنترنت؟',
          style: TextStyle(
            height: 1.5,
            fontSize: 13.5,
            color: Theme.of(context).brightness == Brightness.dark
                ? ThalabTheme.darkTextPrimary
                : ThalabTheme.darkSlate,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('لاحقاً (قراءة بالإنترنت)',
                style: TextStyle(color: ThalabTheme.mutedText(context))),
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
                const SnackBar(content: Text('بدأ تنزيل صفحات المصحف في الخلفية بنجاح')),
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

  void _openJumpToPageDialog() {
    final pageCtrl = TextEditingController(text: '$_currentPage');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('الانتقال السريع لصفحة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? ThalabTheme.darkTextPrimary : ThalabTheme.darkSlate,
            )),
        content: TextField(
          controller: pageCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: 'أدخل رقم الصفحة (1 - 604)',
            filled: true,
            fillColor: Theme.of(context).scaffoldBackgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: TextStyle(color: ThalabTheme.mutedText(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThalabTheme.foxOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final target = int.tryParse(pageCtrl.text.trim());
              if (target != null && target >= 1 && target <= 604) {
                Navigator.pop(ctx);
                _pageController.jumpToPage(target - 1);
              }
            },
            child: const Text('انتقال'),
          ),
        ],
      ),
    );
  }

  void _showVerseActionsSheet(int surahNum, int verseNum, String verseText) {
    HapticFeedback.selectionClick();
    final surahName = quran.getSurahNameArabic(surahNum);
    final formattedVerse =
        '﴿$verseText﴾\n— سورة $surahName • آية ${_toArabicDigits(verseNum)} (صفحة $_currentPage)';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'سورة $surahName • آية ${_toArabicDigits(verseNum)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? ThalabTheme.darkTextPrimary : ThalabTheme.darkSlate,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? ThalabTheme.darkBorder : ThalabTheme.softBorder,
                ),
              ),
              child: Text(
                '﴿$verseText﴾',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: GoogleFonts.amiriQuran(
                  fontSize: 20,
                  height: 2.0,
                  color: isDark ? ThalabTheme.darkTextPrimary : ThalabTheme.darkSlate,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: formattedVerse));
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ الآية الكريمة بنجاح')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, color: ThalabTheme.foxOrange),
                    label: const Text('نسخ الآية'),
                  ),
                ),
                const SizedBox(width: 12),
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
                      _openVerseImageShareDialog(surahName, verseNum, verseText);
                    },
                    icon: const Icon(Icons.image_rounded),
                    label: const Text('مشاركة كصورة'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openVerseImageShareDialog(String surahName, int verseNum, String verseText) {
    int bgIndex = 0;
    double cardFontSize = 21.0;
    bool showSurahName = true;
    bool showAppName = true;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<({String name, List<Color> colors, Color text, Color accent})> themes = [
      (
        name: 'كريمي',
        colors: const [Color(0xFFFFFAF2), Color(0xFFFFEBD6)],
        text: const Color(0xFF1F1D1A),
        accent: ThalabTheme.foxOrange,
      ),
      (
        name: 'ليلي',
        colors: const [Color(0xFF1A1D24), Color(0xFF282E3A)],
        text: Colors.white,
        accent: const Color(0xFFF7B267),
      ),
      (
        name: 'زمردي',
        colors: const [Color(0xFF123524), Color(0xFF1E563B)],
        text: Colors.white,
        accent: const Color(0xFFA7F3D0),
      ),
      (
        name: 'سماوي',
        colors: const [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
        text: const Color(0xFF0F172A),
        accent: const Color(0xFF0369A1),
      ),
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final t = themes[bgIndex];
          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              'تخصيص بطاقة الآية',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? ThalabTheme.darkTextPrimary : ThalabTheme.darkSlate,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RepaintBoundary(
                    key: _verseCardKey,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: t.colors,
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: t.accent.withOpacity(0.45), width: 1.5),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_rounded, color: t.accent, size: 22),
                          const SizedBox(height: 10),
                          Text(
                            '﴿$verseText﴾',
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: GoogleFonts.amiriQuran(
                              fontSize: cardFontSize,
                              height: 2.0,
                              color: t.text,
                            ),
                          ),
                          if (showSurahName) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: t.accent.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'سورة $surahName • آية ${_toArabicDigits(verseNum)}',
                                style: TextStyle(
                                  color: t.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                          if (showAppName) ...[
                            const SizedBox(height: 8),
                            Text(
                              'تطبيق الثعلب • المصحف الشريف',
                              style: TextStyle(
                                color: t.text.withOpacity(0.6),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(themes.length, (i) {
                      final selected = bgIndex == i;
                      return GestureDetector(
                        onTap: () => setDialogState(() => bgIndex = i),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: themes[i].colors),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? ThalabTheme.foxOrange
                                  : (isDark ? ThalabTheme.darkBorder : ThalabTheme.softBorder),
                              width: selected ? 2.5 : 1,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('حجم الخط:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Slider(
                          value: cardFontSize,
                          min: 16,
                          max: 28,
                          activeColor: ThalabTheme.foxOrange,
                          onChanged: (v) => setDialogState(() => cardFontSize = v),
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('إظهار اسم السورة والآية', style: TextStyle(fontSize: 12.5)),
                    activeColor: ThalabTheme.foxOrange,
                    value: showSurahName,
                    onChanged: (v) => setDialogState(() => showSurahName = v),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('إظهار اسم التطبيق', style: TextStyle(fontSize: 12.5)),
                    activeColor: ThalabTheme.foxOrange,
                    value: showAppName,
                    onChanged: (v) => setDialogState(() => showAppName = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء', style: TextStyle(color: ThalabTheme.mutedText(context))),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThalabTheme.foxOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  try {
                    final boundary = _verseCardKey.currentContext?.findRenderObject()
                        as RenderRepaintBoundary?;
                    if (boundary != null) {
                      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
                      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                      if (byteData != null) {
                        final tempDir = await getTemporaryDirectory();
                        final file = File('${tempDir.path}/aya_${surahName.hashCode}_$verseNum.png');
                        await file.writeAsBytes(byteData.buffer.asUint8List());
                        if (ctx.mounted) Navigator.pop(ctx);
                        await Share.shareXFiles(
                          [XFile(file.path)],
                          text: 'سورة $surahName • آية ${_toArabicDigits(verseNum)} — تطبيق الثعلب',
                        );
                        return;
                      }
                    }
                  } catch (_) {}
                  if (ctx.mounted) Navigator.pop(ctx);
                  await Share.share(
                    '﴿$verseText﴾\n— سورة $surahName • آية ${_toArabicDigits(verseNum)}',
                  );
                },
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('مشاركة الصورة'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openDisplaySettings() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? ThalabTheme.darkTextPrimary : ThalabTheme.darkSlate;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
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
              Text('إعدادات عرض المصحف',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('المصحف المصور (الافتراضي)')),
                      selected: _isImageMushaf,
                      selectedColor: ThalabTheme.foxOrange,
                      labelStyle: TextStyle(
                        color: _isImageMushaf ? Colors.white : textColor,
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
                        color: !_isImageMushaf ? Colors.white : textColor,
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
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
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

    final Color paperBg = _isNightPaper
        ? const Color(0xFF141312)
        : const Color(0xFFFFFDF7);
    final Color appBarTextColor = _isNightPaper ? Colors.white : ThalabTheme.darkSlate;

    return Scaffold(
      backgroundColor: paperBg,
      appBar: _isChromeVisible
          ? AppBar(
              backgroundColor: paperBg,
              elevation: 0,
              title: Text(
                'سورة ${quran.getSurahNameArabic(firstSurah)} • الجزء $juzNumber',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: appBarTextColor,
                ),
              ),
              iconTheme: IconThemeData(color: appBarTextColor),
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
                    Share.share(
                      'أقرأ الآن سورة ${quran.getSurahNameArabic(firstSurah)} - صفحة $_currentPage من تطبيق الثعلب.',
                    );
                  },
                ),
                IconButton(
                  tooltip: 'إعدادات العرض (مصور / نصي)',
                  icon: const Icon(Icons.tune_rounded, color: ThalabTheme.foxOrange),
                  onPressed: _openDisplaySettings,
                ),
              ],
            )
          : null,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTap: () => setState(() => _isChromeVisible = !_isChromeVisible),
        child: PageView.builder(
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
      ),
      bottomNavigationBar: _isChromeVisible
          ? Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              color: paperBg,
              child: Row(
                mainAxisAlignment:
                    _isKhatmahMode ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _openJumpToPageDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _isNightPaper
                            ? const Color(0xFF282522)
                            : ThalabTheme.cardOf(context),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: _isNightPaper
                                ? ThalabTheme.darkBorder
                                : ThalabTheme.borderOf(context)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'صفحة $_currentPage من 604',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: appBarTextColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.unfold_more_rounded,
                              size: 16, color: ThalabTheme.foxOrange),
                        ],
                      ),
                    ),
                  ),
                  if (_isKhatmahMode) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isCompleted ? const Color(0xFF1B8A5A) : ThalabTheme.foxOrange,
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
                ],
              ),
            )
          : null,
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
                Text(
                  'تعذر تحميل صورة الصفحة لعدم توفر اتصال بالإنترنت.\nيمكنك التبديل الفوري إلى النص العثماني (أميري) أو تنزيل الصفحات عند توفر الشبكة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, height: 1.6, color: ThalabTheme.mutedText(context)),
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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _isNightPaper ? const Color(0xFF1C1A18) : const Color(0xFFFFFAF0),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: ThalabTheme.foxOrange.withOpacity(_isNightPaper ? 0.25 : 0.35),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isNightPaper ? 0.25 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Center(child: imageWidget),
        ),
      ),
    );
  }

  Widget _buildUthmaniTextPage(int pageNum) {
    final segments = quran.getPageData(pageNum);
    final textColor = _isNightPaper ? const Color(0xFFF4EDE4) : const Color(0xFF1F1D1A);
    final frameBg = _isNightPaper ? const Color(0xFF23201D) : const Color(0xFFFFFAF2);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: frameBg,
          borderRadius: BorderRadius.circular(22),
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
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int v = startVerse; v <= endVerse; v++)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ActionChip(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: ThalabTheme.foxOrange.withOpacity(0.08),
                            side: BorderSide(color: ThalabTheme.foxOrange.withOpacity(0.25)),
                            label: Text(
                              'آية ${_toArabicDigits(v)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: ThalabTheme.foxOrange,
                              ),
                            ),
                            onPressed: () {
                              final txt = quran.getVerse(surahNum, v, verseEndSymbol: false);
                              _showVerseActionsSheet(surahNum, v, txt);
                            },
                          ),
                        ),
                    ],
                  ),
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
// محرك البحث الذكي في القرآن الكريم
// =========================================================================
class _QuranSearchMatch {
  final String type;
  final String title;
  final String subtitle;
  final int page;

  const _QuranSearchMatch({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.page,
  });
}

class _QuranSmartSearchDelegate extends SearchDelegate<void> {
  final ValueChanged<int> onSelectPage;

  _QuranSmartSearchDelegate({required this.onSelectPage});

  @override
  String get searchFieldLabel => 'ابحث باسم السورة أو كلمة من القرآن...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context);
  }

  String _normalizeArabic(String input) {
    return input
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .trim();
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded, color: ThalabTheme.foxOrange),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_forward_rounded),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchBody(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchBody(context);

  Widget _buildSearchBody(BuildContext context) {
    final normQuery = _normalizeArabic(query);
    if (normQuery.isEmpty) {
      return Center(
        child: Text(
          'اكتب اسم السورة أو جزءاً من آية للبحث الفوري',
          style: TextStyle(color: ThalabTheme.mutedText(context)),
        ),
      );
    }

    final List<_QuranSearchMatch> matches = [];

    for (int s = 1; s <= 114; s++) {
      final surahAr = quran.getSurahNameArabic(s);
      if (_normalizeArabic(surahAr).contains(normQuery)) {
        matches.add(
          _QuranSearchMatch(
            type: 'surah',
            title: 'سورة $surahAr',
            subtitle: 'صفحة ${quran.getSurahPages(s).first} • ${quran.getVerseCount(s)} آية',
            page: quran.getSurahPages(s).first,
          ),
        );
      }
    }

    for (int s = 1; s <= 114 && matches.length < 35; s++) {
      final count = quran.getVerseCount(s);
      for (int v = 1; v <= count && matches.length < 35; v++) {
        final verse = quran.getVerse(s, v, verseEndSymbol: false);
        if (_normalizeArabic(verse).contains(normQuery)) {
          matches.add(
            _QuranSearchMatch(
              type: 'verse',
              title: 'سورة ${quran.getSurahNameArabic(s)} • آية $v',
              subtitle: verse,
              page: quran.getPageNumber(s, v),
            ),
          );
        }
      }
    }

    if (matches.isEmpty) {
      return Center(
        child: Text('لا توجد نتائج مطابقة لبحثك', style: TextStyle(color: ThalabTheme.mutedText(context))),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: matches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = matches[index];
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            close(context, null);
            onSelectPage(item.page);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? ThalabTheme.darkBorder : ThalabTheme.softBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  item.type == 'surah' ? Icons.menu_book_rounded : Icons.format_quote_rounded,
                  color: ThalabTheme.foxOrange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: ThalabTheme.mutedText(context), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  'ص ${item.page}',
                  style: const TextStyle(color: ThalabTheme.foxOrange, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
