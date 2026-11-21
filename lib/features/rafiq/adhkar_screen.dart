import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';

class DhikrEntry {
  final String category;
  final String text;
  final String description;
  final int targetCount;
  int remainingCount;
  final GlobalKey cardKey = GlobalKey();

  DhikrEntry({
    required this.category,
    required this.text,
    required this.description,
    required this.targetCount,
  }) : remainingCount = targetCount;

  factory DhikrEntry.fromJson(Map<String, dynamic> json) {
    final int count = int.tryParse(json['count']?.toString() ?? '1') ?? 1;
    return DhikrEntry(
      category: (json['category'] ?? '').toString().trim(),
      text: (json['content'] ?? json['zekr'] ?? '').toString().trim(),
      description: (json['description'] ?? json['reference'] ?? '').toString().trim(),
      targetCount: count > 0 ? count : 1,
    );
  }
}

class AdhkarScreen extends StatefulWidget {
  final int? initialTabIndex;
  const AdhkarScreen({super.key, this.initialTabIndex});

  @override
  State<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends State<AdhkarScreen> {
  final List<String> _tabLabels = [
    'الصباح',
    'المساء',
    'بعد الصلاة',
    'النوم',
    'الاستيقاظ',
    'حصن المسلم',
  ];

  late int _selectedTabIndex;
  List<DhikrEntry> _allAdhkar = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();

  static const String _cacheKey = 'cached_full_adhkar_json_v2';
  static const String _remoteSource =
      'https://raw.githubusercontent.com/nawafalqari/azkar-api/56df51279ab6eb86dc2f6202c7de26c8948331c1/azkar.json';

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex ?? _detectSmartTabByTime();
    _initAdhkar();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _detectSmartTabByTime() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 12) return 0; // الصباح
    if (hour >= 15 && hour < 21) return 1; // المساء
    if (hour >= 21 || hour < 4) return 3; // النوم
    return 5; // حصن المسلم المتنوع
  }

  Future<void> _initAdhkar() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      String? rawJson = prefs.getString(_cacheKey);

      if (rawJson == null || rawJson.isEmpty) {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(_remoteSource));
        final response = await request.close();
        if (response.statusCode == 200) {
          rawJson = await response.transform(utf8.decoder).join();
          await prefs.setString(_cacheKey, rawJson);
        }
      }

      if (rawJson != null && rawJson.isNotEmpty) {
        final decoded = json.decode(rawJson);
        final List<DhikrEntry> parsed = [];

        if (decoded is Map<String, dynamic>) {
          decoded.forEach((key, value) {
            if (value is List) {
              for (final item in value) {
                if (item is Map<String, dynamic>) {
                  final entry = DhikrEntry.fromJson({...item, 'category': key});
                  if (entry.text.isNotEmpty) parsed.add(entry);
                }
              }
            }
          });
        } else if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final entry = DhikrEntry.fromJson(item);
              if (entry.text.isNotEmpty) parsed.add(entry);
            }
          }
        }

        setState(() {
          _allAdhkar = parsed;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'يرجى الاتصال بالإنترنت مرة واحدة لتحميل موسوعة الأذكار الكاملة وحفظها.';
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _errorMessage = 'تعذر الاتصال، تأكد من الإنترنت واضغط إعادة المحاولة.';
        _isLoading = false;
      });
    }
  }

  bool _isMainCategory(String cat) {
    return cat.contains('الصباح') ||
        cat.contains('المساء') ||
        cat.contains('الصلاة') ||
        cat.contains('النوم') ||
        cat.contains('الاستيقاظ');
  }

  List<DhikrEntry> get _currentList {
    List<DhikrEntry> list;
    switch (_selectedTabIndex) {
      case 0:
        list = _allAdhkar.where((e) => e.category.contains('الصباح')).toList();
        break;
      case 1:
        list = _allAdhkar.where((e) => e.category.contains('المساء')).toList();
        break;
      case 2:
        list = _allAdhkar.where((e) => e.category.contains('الصلاة')).toList();
        break;
      case 3:
        list = _allAdhkar.where((e) => e.category.contains('النوم')).toList();
        break;
      case 4:
        list = _allAdhkar.where((e) => e.category.contains('الاستيقاظ')).toList();
        break;
      default:
        // جميع أذكار حصن المسلم المتنوعة (لبس الثوب، الخلاء، المنزل، الركوب، إلخ)
        list = _allAdhkar.where((e) => !_isMainCategory(e.category)).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim();
      list = list.where((e) => e.text.contains(q) || e.category.contains(q)).toList();
    }
    return list;
  }

  void _onDhikrTap(List<DhikrEntry> items, int index) {
    final item = items[index];
    if (item.remainingCount <= 0) return;

    setState(() => item.remainingCount--);

    if (item.remainingCount == 0) {
      HapticFeedback.heavyImpact();
      // الانتقال التلقائي السلس للبطاقة التالية بعد إتمام الذكر
      if (index + 1 < items.length) {
        Future.delayed(const Duration(milliseconds: 280), () {
          final nextCtx = items[index + 1].cardKey.currentContext;
          if (nextCtx != null && mounted) {
            Scrollable.ensureVisible(
              nextCtx,
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              alignment: 0.12,
            );
          }
        });
      }
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _resetCategory() {
    HapticFeedback.mediumImpact();
    setState(() {
      for (final item in _currentList) {
        item.remainingCount = item.targetCount;
      }
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _currentList;
    final int completedCount = items.where((e) => e.remainingCount == 0).length;
    final double progress = items.isEmpty ? 0.0 : completedCount / items.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('حصن المسلم — الأذكار'),
        actions: [
          IconButton(
            tooltip: 'إعادة ضبط القسم',
            icon: const Icon(Icons.refresh_rounded, color: ThalabTheme.foxOrange),
            onPressed: _resetCategory,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 46,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _tabLabels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final selected = index == _selectedTabIndex;
                return ChoiceChip(
                  label: Text(
                    _tabLabels[index],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : ThalabTheme.darkSlate,
                    ),
                  ),
                  selected: selected,
                  selectedColor: ThalabTheme.foxOrange,
                  backgroundColor: ThalabTheme.cardSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: ThalabTheme.softBorder),
                  ),
                  onSelected: (_) => setState(() {
                    _selectedTabIndex = index;
                    _searchQuery = '';
                  }),
                );
              },
            ),
          ),

          // شريط بحث سريع داخل قسم حصن المسلم المتنوع
          if (_selectedTabIndex == 5)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'ابحث (لبس الثوب، الخلاء، الخروج، الكرب...)',
                  prefixIcon: const Icon(Icons.search_rounded, color: ThalabTheme.foxOrange),
                  filled: true,
                  fillColor: ThalabTheme.cardSurface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: ThalabTheme.softBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: ThalabTheme.softBorder),
                  ),
                ),
              ),
            ),

          if (!_isLoading && items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: ThalabTheme.cardSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: ThalabTheme.softBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'تقدم ${_tabLabels[_selectedTabIndex]}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          '$completedCount / ${items.length}',
                          style: const TextStyle(
                            color: ThalabTheme.foxOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: ThalabTheme.softBorder,
                        valueColor: const AlwaysStoppedAnimation<Color>(ThalabTheme.foxOrange),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 6),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: ThalabTheme.foxOrange))
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_download_rounded, size: 54, color: ThalabTheme.foxOrange),
                              const SizedBox(height: 12),
                              Text(_errorMessage!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ThalabTheme.foxOrange,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _initAdhkar,
                                child: const Text('تحميل وحفظ الآن'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 34),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final bool isDone = item.remainingCount == 0;
                          final double itemRatio = 1.0 - (item.remainingCount / item.targetCount);

                          return GestureDetector(
                            key: item.cardKey,
                            onTap: () => _onDhikrTap(items, index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: isDone
                                    ? Colors.green.withOpacity(0.06)
                                    : ThalabTheme.cardSurface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isDone
                                      ? Colors.green.withOpacity(0.5)
                                      : ThalabTheme.softBorder,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_selectedTabIndex == 5)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: ThalabTheme.foxOrange.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            item.category,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: ThalabTheme.foxOrange,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  Text(
                                    item.text,
                                    textAlign: TextAlign.justify,
                                    style: TextStyle(
                                      fontSize: 18.5,
                                      fontWeight: FontWeight.w700,
                                      height: 1.95,
                                      color: isDone ? ThalabTheme.mutedSlate : ThalabTheme.darkSlate,
                                    ),
                                  ),
                                  if (item.description.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: ThalabTheme.creamBackground,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        item.description,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: ThalabTheme.mutedSlate,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      IconButton(
                                        tooltip: 'نسخ الذكر',
                                        icon: const Icon(Icons.copy_rounded, size: 20, color: ThalabTheme.mutedSlate),
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: item.text));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('تم نسخ الذكر'),
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                        },
                                      ),
                                      const Spacer(),
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          SizedBox(
                                            width: 52,
                                            height: 52,
                                            child: CircularProgressIndicator(
                                              value: itemRatio,
                                              strokeWidth: 4.5,
                                              backgroundColor: ThalabTheme.softBorder,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                isDone ? Colors.green : ThalabTheme.foxOrange,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 42,
                                            height: 42,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isDone ? Colors.green : ThalabTheme.foxOrange,
                                            ),
                                            child: isDone
                                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                                                : Text(
                                                    '${item.remainingCount}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ],
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
