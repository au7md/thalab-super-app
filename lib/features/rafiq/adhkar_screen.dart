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
  const AdhkarScreen({super.key});

  @override
  State<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends State<AdhkarScreen> {
  final List<String> _tabs = [
    'أذكار الصباح',
    'أذكار المساء',
    'أذكار بعد السلام من الصلاة المفروضة',
    'أذكار النوم',
    'أذكار الاستيقاظ',
  ];

  final List<String> _tabLabels = [
    'الصباح',
    'المساء',
    'بعد الصلاة',
    'النوم',
    'الاستيقاظ',
  ];

  int _selectedTabIndex = 0;
  List<DhikrEntry> _allAdhkar = [];
  bool _isLoading = true;
  String? _errorMessage;

  static const String _cacheKey = 'cached_full_adhkar_json_v1';
  static const String _remoteSource =
      'https://raw.githubusercontent.com/nawafalqari/azkar-api/56df51279ab6eb86dc2f6202c7de26c8948331c1/azkar.json';

  @override
  void initState() {
    super.initState();
    _initAdhkar();
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
          _errorMessage = 'يرجى الاتصال بالإنترنت مرة واحدة لتحميل موسوعة الأذكار الكاملة وحفظها على هاتفك.';
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _errorMessage = 'تعذر جلب البيانات، تأكد من الاتصال بالإنترنت واضغط إعادة المحاولة.';
        _isLoading = false;
      });
    }
  }

  List<DhikrEntry> get _currentList {
    final targetCat = _tabs[_selectedTabIndex];
    return _allAdhkar.where((e) => e.category.contains(targetCat) || targetCat.contains(e.category)).toList();
  }

  void _resetCategory() {
    HapticFeedback.mediumImpact();
    setState(() {
      for (final item in _currentList) {
        item.remainingCount = item.targetCount;
      }
    });
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
          // شريط التصنيفات
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
                  onSelected: (_) => setState(() => _selectedTabIndex = index),
                );
              },
            ),
          ),

          // شريط الإنجاز الكلي للقسم
          if (!_isLoading && items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          'إنجاز ${_tabLabels[_selectedTabIndex]}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          '$completedCount من ${items.length} ذِكر',
                          style: const TextStyle(
                            color: ThalabTheme.foxOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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

          const SizedBox(height: 8),

          // المحتوى
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
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 34),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final bool isDone = item.remainingCount == 0;
                          final double itemRatio =
                              1.0 - (item.remainingCount / item.targetCount);

                          return GestureDetector(
                            onTap: () {
                              if (!isDone) {
                                setState(() => item.remainingCount--);
                                if (item.remainingCount == 0) {
                                  HapticFeedback.heavyImpact();
                                } else {
                                  HapticFeedback.lightImpact();
                                }
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: isDone
                                    ? ThalabTheme.foxOrange.withOpacity(0.07)
                                    : ThalabTheme.cardSurface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isDone
                                      ? ThalabTheme.foxOrange.withOpacity(0.6)
                                      : ThalabTheme.softBorder,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // نص الذكر بالتشكيل الواضح
                                  Text(
                                    item.text,
                                    textAlign: TextAlign.justify,
                                    style: TextStyle(
                                      fontSize: 18.5,
                                      fontWeight: FontWeight.w700,
                                      height: 1.95,
                                      color: isDone
                                          ? ThalabTheme.mutedSlate
                                          : ThalabTheme.darkSlate,
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
                                      // زر نسخ الذكر
                                      IconButton(
                                        tooltip: 'نسخ الذكر',
                                        icon: const Icon(
                                          Icons.copy_rounded,
                                          size: 20,
                                          color: ThalabTheme.mutedSlate,
                                        ),
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
                                      // العداد الدائري التفاعلي
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
                                              color: isDone
                                                  ? Colors.green
                                                  : ThalabTheme.foxOrange,
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
