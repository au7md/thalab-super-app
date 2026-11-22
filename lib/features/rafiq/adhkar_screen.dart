import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/adhkar_data.dart';

class AdhkarScreen extends StatefulWidget {
  final int initialTabIndex;
  const AdhkarScreen({super.key, this.initialTabIndex = 0});

  @override
  State<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends State<AdhkarScreen> {
  late int _selectedTab;
  final Map<String, int> _progress = {};
  final PageController _pageController = PageController(viewportFraction: 0.93);
  int _currentCardIndex = 0;
  String _searchQuery = '';
  String _selectedSubChapter = 'الكل';

  static const List<String> _tabs = [
    'الصباح',
    'المساء',
    'بعد الصلاة',
    'النوم',
    'الاستيقاظ',
    'حصن المسلم',
    'الرقية',
    'الأسماء الحسنى',
  ];

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex.clamp(0, _tabs.length - 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<DhikrItem> _rawListForTab(int tab) {
    switch (tab) {
      case 0:
        return AdhkarRepository.morningAdhkar;
      case 1:
        return AdhkarRepository.eveningAdhkar;
      case 2:
        return AdhkarRepository.afterPrayerAdhkar;
      case 3:
        return AdhkarRepository.sleepAdhkar;
      case 4:
        return AdhkarRepository.wakingUpAdhkar;
      case 5:
        return AdhkarRepository.hisnAlMuslimAdhkar;
      case 6:
        return AdhkarRepository.ruqyahAdhkar;
      default:
        return const [];
    }
  }

  List<String> _hisnSubChapters() {
    final chapters = <String>{'الكل'};
    for (final item in AdhkarRepository.hisnAlMuslimAdhkar) {
      if (item.subChapter.isNotEmpty) {
        chapters.add(item.subChapter);
      }
    }
    return chapters.toList();
  }

  String _normalize(String input) {
    return input
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '')
        .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .trim();
  }

  List<DhikrItem> get _filteredAdhkar {
    final list = _rawListForTab(_selectedTab);
    final q = _normalize(_searchQuery);

    return list.where((item) {
      if (_selectedTab == 5 &&
          _selectedSubChapter != 'الكل' &&
          item.subChapter != _selectedSubChapter) {
        return false;
      }
      if (q.isEmpty) return true;
      return _normalize(item.text).contains(q) ||
          _normalize(item.reference).contains(q) ||
          _normalize(item.subChapter).contains(q);
    }).toList();
  }

  String _keyFor(int tab, int index, String text) => '$tab-$index-${text.hashCode}';

  void _onTapDhikr(DhikrItem item, int index, int totalCount) {
    final key = _keyFor(_selectedTab, index, item.text);
    final current = _progress[key] ?? 0;
    if (current >= item.count) return;

    final next = current + 1;
    setState(() => _progress[key] = next);

    if (next == item.count) {
      HapticFeedback.mediumImpact();
      if (index + 1 < totalCount) {
        Future.delayed(const Duration(milliseconds: 360), () {
          if (mounted && _pageController.hasClients) {
            _pageController.animateToPage(
              index + 1,
              duration: const Duration(milliseconds: 340),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _resetTabProgress() {
    setState(() {
      _progress.removeWhere((k, _) => k.startsWith('$_selectedTab-'));
      _currentCardIndex = 0;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isNamesTab = _selectedTab == 7;
    final items = _filteredAdhkar;

    int completedCount = 0;
    for (int i = 0; i < items.length; i++) {
      final key = _keyFor(_selectedTab, i, items[i].text);
      if ((_progress[key] ?? 0) >= items[i].count) {
        completedCount++;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isNamesTab ? 'أسماء الله الحسنى' : 'الأذكار وحصن المسلم'),
        actions: [
          if (!isNamesTab)
            IconButton(
              tooltip: 'تصفير عداد القسم',
              icon: const Icon(Icons.refresh_rounded, color: ThalabTheme.foxOrange),
              onPressed: _resetTabProgress,
            ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 46,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final selected = _selectedTab == idx;
                return ChoiceChip(
                  label: Text(
                    _tabs[idx],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : ThalabTheme.darkSlate,
                    ),
                  ),
                  selected: selected,
                  selectedColor: ThalabTheme.foxOrange,
                  backgroundColor: ThalabTheme.cardSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: selected ? ThalabTheme.foxOrange : ThalabTheme.softBorder,
                    ),
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedTab = idx;
                      _currentCardIndex = 0;
                      _searchQuery = '';
                      _selectedSubChapter = 'الكل';
                    });
                    if (_pageController.hasClients) {
                      _pageController.jumpToPage(0);
                    }
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: TextField(
              onChanged: (v) {
                setState(() {
                  _searchQuery = v;
                  _currentCardIndex = 0;
                });
                if (_pageController.hasClients) {
                  _pageController.jumpToPage(0);
                }
              },
              decoration: InputDecoration(
                hintText: isNamesTab
                    ? 'ابحث باسم من أسماء الله أو معناه...'
                    : 'ابحث (لبس الثوب، الخلاء، الكرب، المسجد...)',
                hintStyle: const TextStyle(fontSize: 12.5, color: ThalabTheme.mutedSlate),
                prefixIcon: const Icon(Icons.search_rounded, color: ThalabTheme.foxOrange),
                filled: true,
                fillColor: ThalabTheme.cardSurface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
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
          if (_selectedTab == 5)
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                scrollDirection: Axis.horizontal,
                itemCount: _hisnSubChapters().length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final chapter = _hisnSubChapters()[i];
                  final isSubSelected = _selectedSubChapter == chapter;
                  return FilterChip(
                    label: Text(
                      chapter,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isSubSelected ? Colors.white : ThalabTheme.darkSlate,
                      ),
                    ),
                    selected: isSubSelected,
                    selectedColor: ThalabTheme.foxOrangeLight,
                    backgroundColor: ThalabTheme.cardSurface,
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() {
                        _selectedSubChapter = chapter;
                        _currentCardIndex = 0;
                      });
                      if (_pageController.hasClients) {
                        _pageController.jumpToPage(0);
                      }
                    },
                  );
                },
              ),
            ),
          if (isNamesTab)
            Expanded(child: _buildNamesOfAllahGrid())
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
              child: Row(
                children: [
                  Text(
                    'المنجز: $completedCount من ${items.length}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: items.isEmpty ? 0 : completedCount / items.length,
                        minHeight: 7,
                        backgroundColor: ThalabTheme.softBorder,
                        valueColor: const AlwaysStoppedAnimation(ThalabTheme.foxOrange),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    items.isEmpty ? '0/0' : '${_currentCardIndex + 1}/${items.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ThalabTheme.foxOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد نتائج مطابقة لبحثك',
                        style: TextStyle(color: ThalabTheme.mutedSlate, fontSize: 15),
                      ),
                    )
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: items.length,
                      onPageChanged: (idx) => setState(() => _currentCardIndex = idx),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final key = _keyFor(_selectedTab, index, item.text);
                        final currentCount = _progress[key] ?? 0;
                        final remaining = (item.count - currentCount).clamp(0, item.count);
                        final isDone = remaining == 0;

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(6, 4, 6, 20),
                          child: GestureDetector(
                            onTap: () => _onTapDhikr(item, index, items.length),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: isDone
                                    ? const Color(0xFFF1F9F4)
                                    : ThalabTheme.cardSurface,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: isDone
                                      ? const Color(0xFF2E9E6B)
                                      : ThalabTheme.softBorder,
                                  width: 1.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
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
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: ThalabTheme.foxOrange.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Text(
                                          item.subChapter.isNotEmpty
                                              ? item.subChapter
                                              : item.category,
                                          style: const TextStyle(
                                            color: ThalabTheme.foxOrange,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'نسخ الذكر',
                                        icon: const Icon(Icons.copy_rounded,
                                            size: 20, color: ThalabTheme.mutedSlate),
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: item.text));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('تم نسخ الذكر بنجاح'),
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      child: Column(
                                        children: [
                                          Text(
                                            item.text,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.amiri(
                                              fontSize: 22,
                                              height: 2.0,
                                              fontWeight: FontWeight.w700,
                                              color: ThalabTheme.darkSlate,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: ThalabTheme.creamBackground,
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: Text(
                                              item.reference,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                height: 1.5,
                                                color: ThalabTheme.mutedSlate,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Container(
                                    width: double.infinity,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isDone
                                            ? [
                                                const Color(0xFF2E9E6B),
                                                const Color(0xFF238558)
                                              ]
                                            : [
                                                ThalabTheme.foxOrange,
                                                ThalabTheme.foxOrangeLight
                                              ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isDone
                                              ? Icons.check_circle_rounded
                                              : Icons.touch_app_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          isDone
                                              ? 'اكتمل الذكر (${item.count}/${item.count})'
                                              : 'اضغط للتسبيح • المتبقي: $remaining',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNamesOfAllahGrid() {
    final q = _normalize(_searchQuery);
    final filtered = AdhkarRepository.namesOfAllah.where((n) {
      if (q.isEmpty) return true;
      return _normalize(n.name).contains(q) || _normalize(n.meaning).contains(q);
    }).toList();

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      itemCount: filtered.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.25,
      ),
      itemBuilder: (context, index) {
        final item = filtered[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ThalabTheme.cardSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: ThalabTheme.softBorder, width: 1.4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.name,
                style: GoogleFonts.amiri(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: ThalabTheme.foxOrange,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.meaning,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: ThalabTheme.mutedSlate,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
