import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'core/storage_service.dart';
import 'widgets/floating_nav_bar.dart';
import 'features/rafiq/tasbih_screen.dart';
import 'features/rafiq/adhkar_screen.dart';
import 'features/rafiq/prayer_times_screen.dart';
import 'features/rafiq/quran_screen.dart';
import 'features/rafiq/qibla_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  runApp(const ThalabApp());
}

class ThalabApp extends StatelessWidget {
  const ThalabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'الثعلب',
      debugShowCheckedModeBanner: false,
      theme: ThalabTheme.lightTheme,
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const MainShellScreen(),
    );
  }
}

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomeDashboardTab(),
    RafiqTab(),
    MediaTab(),
    MusicTab(),
    MoreToolsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: _pages[_selectedIndex],
        ),
      ),
      bottomNavigationBar: ThalabFloatingNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}

// 1. تبويب الرئيسية
class HomeDashboardTab extends StatelessWidget {
  const HomeDashboardTab({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أهلاً بك في الثعلب',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  'مساحتك الذكية الهادئة والمتكاملة',
                  style: TextStyle(fontSize: 13, color: ThalabTheme.mutedSlate),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ThalabTheme.cardSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: ThalabTheme.softBorder),
              ),
              child: const Icon(Icons.pets_rounded, color: ThalabTheme.foxOrange, size: 28),
            ),
          ],
        ),
        const SizedBox(height: 22),
        GestureDetector(
          onTap: () => _open(context, const AdhkarScreen()),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: ThalabTheme.foxOrange.withOpacity(0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('رفيقك اليومي', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      SizedBox(height: 4),
                      Text(
                        'وِرد اليوم والأذكار',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'اضغط لفتح حصن المسلم بالعداد التفاعلي',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                Icon(Icons.mosque_rounded, color: Colors.white, size: 46),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Text('الوصول السريع', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            _QuickCard(
              title: 'المصحف الشريف',
              subtitle: 'متابعة الختمة والقراءة',
              icon: Icons.menu_book_rounded,
              onTap: () => _open(context, const QuranScreen()),
            ),
            _QuickCard(
              title: 'السبحة الذكية',
              subtitle: 'حبات تفاعلية متحركة',
              icon: Icons.adjust_rounded,
              onTap: () => _open(context, const TasbihScreen()),
            ),
            _QuickCard(
              title: 'مواقيت الصلاة',
              subtitle: 'تحديد الموقع والحساب',
              icon: Icons.access_time_filled_rounded,
              onTap: () => _open(context, const PrayerTimesScreen()),
            ),
            _QuickCard(
              title: 'اتجاه القبلة',
              subtitle: 'بوصلة حية للكعبة',
              icon: Icons.explore_rounded,
              onTap: () => _open(context, const QiblaScreen()),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ThalabTheme.cardSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: ThalabTheme.softBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: ThalabTheme.foxOrange, size: 26),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(subtitle, style: const TextStyle(color: ThalabTheme.mutedSlate, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// 2. تبويب رفيق (لوحة ويدجت إبداعية حيّة)
class RafiqTab extends StatefulWidget {
  const RafiqTab({super.key});

  @override
  State<RafiqTab> createState() => _RafiqTabState();
}

class _RafiqTabState extends State<RafiqTab> {
  int _khatmahRead = 0;
  int _totalTasbih = 0;

  @override
  void initState() {
    super.initState();
    _refreshWidgets();
  }

  Future<void> _refreshWidgets() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _khatmahRead = prefs.getInt('khatmah_pages_read') ?? 0;
      _totalTasbih = StorageService.getTotalTasbih();
    });
  }

  void _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _refreshWidgets();
  }

  @override
  Widget build(BuildContext context) {
    final double khatmahPct = (_khatmahRead / 604).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        const Text('رفيق — الواحة الإيمانية', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // صف الويدجت التفاعلية (تقدم الختمة + مجموع التسبيح)
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _open(const QuranScreen()),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.menu_book_rounded, color: Colors.white),
                          Text('الختمة', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${(khatmahPct * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$_khatmahRead / 604 صفحة',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => _open(const TasbihScreen()),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ThalabTheme.cardSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: ThalabTheme.softBorder, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.adjust_rounded, color: ThalabTheme.foxOrange),
                          Text('التسبيح', style: TextStyle(color: ThalabTheme.mutedSlate, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$_totalTasbih',
                        style: const TextStyle(
                          color: ThalabTheme.darkSlate,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'إجمالي التسبيحات',
                        style: TextStyle(color: ThalabTheme.mutedSlate, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // بطاقة ويدجت المواقيت
        GestureDetector(
          onTap: () => _open(const PrayerTimesScreen()),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: ThalabTheme.cardSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: ThalabTheme.softBorder, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ThalabTheme.foxOrange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.mosque_rounded, color: ThalabTheme.foxOrange, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('مواقيت الصلاة والأذان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                        'عرض المواقيت والعد التنازلي وتخصيص الموقع',
                        style: TextStyle(color: ThalabTheme.mutedSlate, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: ThalabTheme.foxOrange),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // شبكة الأقسام الأساسية (بدون قسم الأدعية المنفصل)
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.18,
          children: [
            _RafiqServiceCard(
              title: 'المصحف الشريف',
              subtitle: '114 سورة + بحث + ختمة',
              icon: Icons.menu_book_rounded,
              onTap: () => _open(const QuranScreen()),
            ),
            _RafiqServiceCard(
              title: 'الأذكار الكاملة',
              subtitle: 'حصن المسلم بالتشكيل',
              icon: Icons.auto_stories_rounded,
              onTap: () => _open(const AdhkarScreen()),
            ),
            _RafiqServiceCard(
              title: 'السبحة الذكية',
              subtitle: 'حبات سبحة ثلاثية الأبعاد',
              icon: Icons.radio_button_checked_rounded,
              onTap: () => _open(const TasbihScreen()),
            ),
            _RafiqServiceCard(
              title: 'اتجاه القبلة',
              subtitle: 'بوصلة الكعبة المشرفة',
              icon: Icons.explore_rounded,
              onTap: () => _open(const QiblaScreen()),
            ),
          ],
        ),
      ],
    );
  }
}

class _RafiqServiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _RafiqServiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThalabTheme.cardSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: ThalabTheme.softBorder, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ThalabTheme.foxOrange.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: ThalabTheme.foxOrange, size: 26),
            ),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(subtitle, style: const TextStyle(color: ThalabTheme.mutedSlate, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// 3. تبويب الميديا
class MediaTab extends StatelessWidget {
  const MediaTab({super.key});
  @override
  Widget build(BuildContext context) => _SectionGridTemplate(
        title: 'الميديا والمعرض',
        items: [
          _GridToolItem('الفيديوهات', Icons.video_library_rounded, null),
          _GridToolItem('الصور', Icons.photo_library_rounded, null),
          _GridToolItem('قص الفيديو', Icons.content_cut_rounded, null),
          _GridToolItem('استخراج الصوت', Icons.audiotrack_rounded, null),
        ],
      );
}

// 4. تبويب الموسيقى
class MusicTab extends StatelessWidget {
  const MusicTab({super.key});
  @override
  Widget build(BuildContext context) => _SectionGridTemplate(
        title: 'الموسيقى والصوتيات',
        items: [
          _GridToolItem('كل الصوتيات', Icons.library_music_rounded, null),
          _GridToolItem('قوائم التشغيل', Icons.queue_music_rounded, null),
          _GridToolItem('مسجل الصوت', Icons.mic_rounded, null),
          _GridToolItem('وضع الاسترخاء', Icons.spa_rounded, null),
        ],
      );
}

// 5. تبويب المزيد
class MoreToolsTab extends StatelessWidget {
  const MoreToolsTab({super.key});
  @override
  Widget build(BuildContext context) => _SectionGridTemplate(
        title: 'المزيد من الأدوات',
        items: [
          _GridToolItem('مدير الملفات', Icons.folder_rounded, null),
          _GridToolItem('التنظيف الذكي', Icons.cleaning_services_rounded, null),
          _GridToolItem('صور إلى PDF', Icons.picture_as_pdf_rounded, null),
          _GridToolItem('الخزنة السرية', Icons.lock_rounded, null),
          _GridToolItem('الآلة الحاسبة', Icons.calculate_rounded, null),
          _GridToolItem('سلة المحذوفات', Icons.delete_outline_rounded, null),
          _GridToolItem('الإعدادات', Icons.settings_rounded, null),
          _GridToolItem('حول التطبيق', Icons.info_outline_rounded, null),
        ],
      );
}

class _GridToolItem {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  _GridToolItem(this.label, this.icon, this.onTap);
}

class _SectionGridTemplate extends StatelessWidget {
  final String title;
  final List<_GridToolItem> items;

  const _SectionGridTemplate({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 18),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.90,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: item.onTap ??
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('قسم "${item.label}" جاهز للدمج في الدفعة القادمة'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: ThalabTheme.darkSlate,
                      ),
                    );
                  },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: ThalabTheme.cardSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: ThalabTheme.softBorder, width: 1.4),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ThalabTheme.foxOrange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item.icon, color: ThalabTheme.foxOrange, size: 28),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
