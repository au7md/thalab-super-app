import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';

class DhikrItem {
  final String category;
  final String text;
  final String virtue;
  int remaining;
  final int initialCount;

  DhikrItem({
    required this.category,
    required this.text,
    required this.virtue,
    required this.initialCount,
  }) : remaining = initialCount;
}

class AdhkarScreen extends StatefulWidget {
  const AdhkarScreen({super.key});

  @override
  State<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends State<AdhkarScreen> {
  String _selectedCategory = 'الصباح';
  final List<String> _categories = ['الصباح', 'المساء', 'بعد الصلاة', 'النوم', 'أدعية'];

  late List<DhikrItem> _items;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _items = [
      DhikrItem(
        category: 'الصباح',
        text: 'أصبحنا وأصبح الملك لله، والحمد لله، لا إله إلا الله وحده لا شريك له.',
        virtue: 'من أذكار الاستفتاح الصباحية الثابتة.',
        initialCount: 1,
      ),
      DhikrItem(
        category: 'الصباح',
        text: 'رضيت بالله رباً، وبالإسلام ديناً، وبمحمد صلى الله عليه وسلم نبياً.',
        virtue: 'تقال ثلاث مرات صباحاً ومساءً.',
        initialCount: 3,
      ),
      DhikrItem(
        category: 'المساء',
        text: 'أمسينا وأمسى الملك لله، والحمد لله، لا إله إلا الله وحده لا شريك له.',
        virtue: 'من أذكار المساء الثابتة.',
        initialCount: 1,
      ),
      DhikrItem(
        category: 'بعد الصلاة',
        text: 'أستغفر الله (ثلاثاً) اللهم أنت السلام ومنك السلام تباركت يا ذا الجلال والإكرام.',
        virtue: 'الذكر المباشر عقب التسليم من الفريضة.',
        initialCount: 1,
      ),
      DhikrItem(
        category: 'النوم',
        text: 'باسمك اللهم أموت وأحيا.',
        virtue: 'يقال عند أخذ المضجع للنوم.',
        initialCount: 1,
      ),
      DhikrItem(
        category: 'أدعية',
        text: 'اللهم إنك عفو تحب العفو فاعف عنا.',
        virtue: 'من جوامع الدعاء.',
        initialCount: 3,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items.where((e) => e.category == _selectedCategory).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الأذكار والأدعية'),
        actions: [
          IconButton(
            tooltip: 'إعادة ضبط العدادات',
            icon: const Icon(Icons.refresh_rounded, color: ThalabTheme.foxOrange),
            onPressed: () => setState(() => _loadData()),
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
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final selected = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(
                    cat,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : ThalabTheme.darkSlate,
                    ),
                  ),
                  selected: selected,
                  selectedColor: ThalabTheme.foxOrange,
                  backgroundColor: ThalabTheme.cardSurface,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = filtered[index];
                final done = item.remaining == 0;
                return GestureDetector(
                  onTap: () {
                    if (item.remaining > 0) {
                      HapticFeedback.lightImpact();
                      setState(() => item.remaining--);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: done
                          ? ThalabTheme.foxOrange.withOpacity(0.08)
                          : ThalabTheme.cardSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: done ? ThalabTheme.foxOrange : ThalabTheme.softBorder,
                        width: 1.4,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.text,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            height: 1.7,
                            color: done ? ThalabTheme.mutedSlate : ThalabTheme.darkSlate,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.virtue,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: ThalabTheme.mutedSlate,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: done ? Colors.green : ThalabTheme.foxOrange,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                done ? 'تم ✓' : '${item.remaining} / ${item.initialCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
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
