import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/storage_service.dart';

class SurahMeta {
  final int number;
  final String name;
  final int startPage;
  final int verses;
  final bool isMeccan;

  const SurahMeta(this.number, this.name, this.startPage, this.verses, this.isMeccan);
}

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  String _query = '';
  int _savedPage = 1;

  // قائمة السور الرئيسية مع رقم الصفحة الافتتاحية في مصحف المدينة (604 صفحة)
  static const List<SurahMeta> _surahs = [
    SurahMeta(1, 'الفاتحة', 1, 7, true),
    SurahMeta(2, 'البقرة', 2, 286, false),
    SurahMeta(3, 'آل عمران', 50, 200, false),
    SurahMeta(4, 'النساء', 77, 176, false),
    SurahMeta(5, 'المائدة', 106, 120, false),
    SurahMeta(6, 'الأنعام', 128, 165, true),
    SurahMeta(7, 'الأعراف', 151, 206, true),
    SurahMeta(8, 'الأنفال', 177, 75, false),
    SurahMeta(9, 'التوبة', 187, 129, false),
    SurahMeta(10, 'يونس', 208, 109, true),
    SurahMeta(18, 'الكهف', 293, 110, true),
    SurahMeta(19, 'مريم', 305, 98, true),
    SurahMeta(20, 'طه', 312, 135, true),
    SurahMeta(36, 'يس', 440, 83, true),
    SurahMeta(55, 'الرحمن', 531, 78, false),
    SurahMeta(56, 'الواقعة', 534, 96, true),
    SurahMeta(67, 'الملك', 562, 30, true),
    SurahMeta(78, 'النبأ', 582, 40, true),
    SurahMeta(112, 'الإخلاص', 604, 4, true),
    SurahMeta(113, 'الفلق', 604, 5, true),
    SurahMeta(114, 'الناس', 604, 6, true),
  ];

  @override
  void initState() {
    super.initState();
    _savedPage = StorageService.getLastSurah();
  }

  void _openMushafReader(int initialPage) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafPageReader(initialPage: initialPage),
      ),
    );
    setState(() {
      _savedPage = StorageService.getLastSurah();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _surahs
        .where((s) => s.name.contains(_query.trim()) || '${s.number}' == _query.trim())
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('المصحف الشريف'),
        actions: [
          IconButton(
            tooltip: 'الانتقال لرقم صفحة',
            icon: const Icon(Icons.bookmark_added_rounded, color: ThalabTheme.foxOrange),
            onPressed: () => _openMushafReader(_savedPage),
          ),
        ],
      ),
      body: Column(
        children: [
          // بطاقة متابعة القراءة من حيث توقفت
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: GestureDetector(
              onTap: () => _openMushafReader(_savedPage),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book_rounded, color: Colors.white, size: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'متابعة القراءة',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'آخر موضع محفوظ: صفحة $_savedPage من 604',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
          ),

          // شريط البحث عن سورة
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (val) => setState(() => _query = val),
              decoration: InputDecoration(
                hintText: 'ابحث باسم السورة أو رقمها...',
                prefixIcon: const Icon(Icons.search_rounded, color: ThalabTheme.foxOrange),
                filled: true,
                fillColor: ThalabTheme.cardSurface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: ThalabTheme.softBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: ThalabTheme.softBorder),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // قائمة السور
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final surah = filtered[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _openMushafReader(surah.startPage),
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
                            '${surah.number}',
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
                                'سورة ${surah.name}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${surah.isMeccan ? "مكية" : "مدنية"} • ${surah.verses} آية',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: ThalabTheme.mutedSlate,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'ص ${surah.startPage}',
                          style: const TextStyle(
                            color: ThalabTheme.foxOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
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

class MushafPageReader extends StatefulWidget {
  final int initialPage;
  const MushafPageReader({super.key, required this.initialPage});

  @override
  State<MushafPageReader> createState() => _MushafPageReaderState();
}

class _MushafPageReaderState extends State<MushafPageReader> {
  late PageController _pageController;
  late int _currentPage;
  bool _nightMode = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(1, 604);
    _pageController = PageController(initialPage: _currentPage - 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _pageImageUrl(int page) {
    final padded = page.toString().padLeft(3, '0');
    return 'https://android.quran.com/data/width_1024/page$padded.png';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _nightMode ? const Color(0xFF141210) : const Color(0xFFFFFBF2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: _nightMode ? Colors.white : ThalabTheme.darkSlate,
        title: Text(
          'صفحة $_currentPage / 604',
          style: TextStyle(
            fontSize: 17,
            color: _nightMode ? Colors.white : ThalabTheme.darkSlate,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'الوضع الليلي للقراءة',
            icon: Icon(_nightMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: () => setState(() => _nightMode = !_nightMode),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: 604,
        onPageChanged: (index) {
          final page = index + 1;
          setState(() => _currentPage = page);
          StorageService.setLastSurah(page);
        },
        itemBuilder: (context, index) {
          final pageNum = index + 1;
          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 3.0,
            child: Center(
              child: ColorFiltered(
                colorFilter: _nightMode
                    ? const ColorFilter.matrix([
                        -1, 0, 0, 0, 255,
                        0, -1, 0, 0, 255,
                        0, 0, -1, 0, 255,
                        0, 0, 0, 1, 0,
                      ])
                    : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                child: Image.network(
                  _pageImageUrl(pageNum),
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: ThalabTheme.foxOrange),
                    );
                  },
                  errorBuilder: (_, __, ___) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 48, color: ThalabTheme.foxOrange),
                      const SizedBox(height: 12),
                      Text(
                        'تأكد من الاتصال بالإنترنت لتحميل صفحة $pageNum لأول مرة',
                        style: TextStyle(
                          color: _nightMode ? Colors.white70 : ThalabTheme.darkSlate,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
