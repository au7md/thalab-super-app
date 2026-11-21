import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme.dart';
import 'widgets/floating_nav_bar.dart';

void main() {
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
        // بطاقة الصلاة القادمة
        Container(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('رفيقك اليومي', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  SizedBox(height: 4),
                  Text('وِرد اليوم والأذكار', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text('«أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ»', style: TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
              Icon(Icons.mosque_rounded, color: Colors.white, size: 46),
            ],
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
          children: const [
            _QuickCard(title: 'المصحف المصور', subtitle: 'متابعة القراءة', icon: Icons.menu_book_rounded),
            _QuickCard(title: 'السبحة الذكية', subtitle: 'عداد تفاعلي', icon: Icons.adjust_rounded),
            _QuickCard(title: 'مسجل الصوت', subtitle: 'تسجيل فوري', icon: Icons.mic_rounded),
            _QuickCard(title: 'التنظيف الذكي', subtitle: 'تحسين المساحة', icon: Icons.cleaning_services_rounded),
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

  const _QuickCard({required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

// 2. تبويب رفيق (سيتم تفصيله في الدفعة الثانية)
class RafiqTab extends StatelessWidget {
  const RafiqTab({super.key});
  @override
  Widget build(BuildContext context) => const _SectionGridTemplate(
        title: 'رفيق — القسم الديني',
        items: [
          ('القرآن الكريم', Icons.menu_book_rounded),
          ('الأذكار', Icons.auto_stories_rounded),
          ('السبحة الإلكترونية', Icons.radio_button_checked_rounded),
          ('الأدعية', Icons.volunteer_activism_rounded),
          ('مواقيت الصلاة', Icons.mosque_rounded),
          ('اتجاه القبلة', Icons.explore_rounded),
        ],
      );
}

// 3. تبويب الميديا
class MediaTab extends StatelessWidget {
  const MediaTab({super.key});
  @override
  Widget build(BuildContext context) => const _SectionGridTemplate(
        title: 'الميديا والمعرض',
        items: [
          ('الفيديوهات', Icons.video_library_rounded),
          ('الصور', Icons.photo_library_rounded),
          ('قص الفيديو', Icons.content_cut_rounded),
          ('استخراج الصوت', Icons.audiotrack_rounded),
        ],
      );
}

// 4. تبويب الموسيقى
class MusicTab extends StatelessWidget {
  const MusicTab({super.key});
  @override
  Widget build(BuildContext context) => const _SectionGridTemplate(
        title: 'الموسيقى والصوتيات',
        items: [
          ('كل الصوتيات', Icons.library_music_rounded),
          ('قوائم التشغيل', Icons.queue_music_rounded),
          ('مسجل الصوت', Icons.mic_rounded),
          ('وضع الاسترخاء', Icons.spa_rounded),
        ],
      );
}

// 5. تبويب المزيد
class MoreToolsTab extends StatelessWidget {
  const MoreToolsTab({super.key});
  @override
  Widget build(BuildContext context) => const _SectionGridTemplate(
        title: 'المزيد من الأدوات',
        items: [
          ('مدير الملفات', Icons.folder_rounded),
          ('التنظيف الذكي', Icons.cleaning_services_rounded),
          ('صور إلى PDF', Icons.picture_as_pdf_rounded),
          ('الخزنة السرية', Icons.lock_rounded),
          ('الآلة الحاسبة', Icons.calculate_rounded),
          ('سلة المحذوفات', Icons.delete_outline_rounded),
          ('الإعدادات', Icons.settings_rounded),
          ('حول التطبيق', Icons.info_outline_rounded),
        ],
      );
}

class _SectionGridTemplate extends StatelessWidget {
  final String title;
  final List<(String, IconData)> items;

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
            childAspectRatio: 0.92,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              decoration: BoxDecoration(
                color: ThalabTheme.cardSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: ThalabTheme.softBorder, width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: ThalabTheme.foxOrange.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                    child: Icon(item.$2, color: ThalabTheme.foxOrange, size: 28),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.$1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
