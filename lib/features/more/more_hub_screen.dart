import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/fox_mascot.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import 'pro_tools_screens.dart';
import 'student_hub_screen.dart';
import 'productivity_pro_screens.dart';

class MoreHubScreen extends StatefulWidget {
  const MoreHubScreen({super.key});

  @override
  State<MoreHubScreen> createState() => _MoreHubScreenState();
}

class _MoreHubScreenState extends State<MoreHubScreen> {
  static const MethodChannel _channel =
      MethodChannel('com.au7md.thalab_app/audio_studio');

  int _sadaqahDuaCount = 0;
  String _userName = 'أحمد';
  String _userGender = 'ذكر'; // 'ذكر' أو 'أنثى'

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _sadaqahDuaCount = prefs.getInt('sadaqah_dua_count') ?? 0;
        _userName = prefs.getString('user_name') ?? 'مستخدم الثعلب';
        _userGender = prefs.getString('user_gender') ?? 'ذكر';
      });
    }
  }

  Future<void> _incrementDua() async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    setState(() => _sadaqahDuaCount++);
    await prefs.setInt('sadaqah_dua_count', _sadaqahDuaCount);
  }

  Future<void> _openUrl(String url) async {
    try {
      await _channel.invokeMethod('openExternalUrl', {'url': url});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الرابط على هذا الجهاز')),
        );
      }
    }
  }

  void _openDeveloperSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThalabTheme.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ThalabTheme.softBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ThalabTheme.foxOrange.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.code_rounded, color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'أحمد محمد أحمد',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                const Text(
                  'أحمد تعلب  •  @au7md',
                  style: TextStyle(
                    color: ThalabTheme.foxOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ThalabTheme.cardSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ThalabTheme.softBorder),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.volunteer_activism_rounded,
                              color: ThalabTheme.foxOrange, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'صدقة جارية ودعوة بظهر الغيب',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'اللهم اغفر لي ولوالديّ وللمسلمين أجمعين، واجعل هذا العمل خالصاً لوجهك الكريم ونافعاً لكل من يستخدمه.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: ThalabTheme.mutedSlate, fontSize: 12.5, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThalabTheme.foxOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          await _incrementDua();
                          setSheetState(() {});
                        },
                        icon: const Icon(Icons.favorite_rounded, size: 18),
                        label: Text('آمين • دعوة صادقة ($_sadaqahDuaCount)'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'التواصل المباشر مع المطور:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SocialActionChip(
                      label: 'واتساب',
                      icon: Icons.chat_rounded,
                      color: const Color(0xFF25D366),
                      onTap: () => _openUrl('https://wa.me/201124539443'),
                    ),
                    _SocialActionChip(
                      label: 'فيسبوك',
                      icon: Icons.facebook_rounded,
                      color: const Color(0xFF1877F2),
                      onTap: () => _openUrl('https://www.facebook.com/au7md'),
                    ),
                    _SocialActionChip(
                      label: 'انستقرام',
                      icon: Icons.camera_alt_rounded,
                      color: const Color(0xFFE4405F),
                      onTap: () => _openUrl('https://www.instagram.com/au7md'),
                    ),
                    _SocialActionChip(
                      label: 'تليجرام',
                      icon: Icons.send_rounded,
                      color: const Color(0xFF0088CC),
                      onTap: () => _openUrl('https://t.me/au7md'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز الأدوات والمزيد'),
        actions: [
          IconButton(
            tooltip: 'عن المطور والصدقة الجارية',
            icon: const Icon(Icons.volunteer_activism_rounded,
                color: ThalabTheme.foxOrange),
            onPressed: _openDeveloperSheet,
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.instance.mode,
            builder: (_, mode, __) {
              final isDark = mode == ThemeMode.dark;
              return IconButton(
                tooltip: isDark ? 'التحويل للوضع الفاتح' : 'التحويل للوضع الليلي',
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    isDark ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
                    key: ValueKey(isDark),
                    color: ThalabTheme.foxOrange,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ThemeController.instance.toggle();
                },
              );
            },
          ),
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings_rounded, color: ThalabTheme.darkSlate),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
              );
              _loadUserData();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          // 1. بطاقة الملف الشخصي للمستخدم
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserProfileScreen()),
              );
              _loadUserData();
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: ThalabTheme.foxOrange.withOpacity(0.26),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const FoxMascot(size: 56, mood: FoxMood.studying),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مرحباً، $_userName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16.5),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'ملفك الشخصي وإحصائياتك • اضغط للتخصيص',
                          style: TextStyle(color: Colors.white70, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. قسم الإنتاجية والتركيز + ركن الطلاب
          const _SectionHeader(
              title: 'الإنتاجية والتركيز (Pro)', icon: Icons.bolt_rounded),
          const SizedBox(height: 10),
          GridView.count(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.48,
            children: [
              _ToolGridCard(
                title: 'مؤقت بومودورو',
                subtitle: 'جلسات متعددة وتركيز هادئ',
                icon: Icons.timer_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PomodoroProScreen()),
                ),
              ),
              _ToolGridCard(
                title: 'خزنة الملاحظات',
                subtitle: 'محمية برقم سري وبصمة',
                icon: Icons.lock_person_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SecureNotesVaultScreen()),
                ),
              ),
              _ToolGridCard(
                title: 'متتبع العادات',
                subtitle: 'مربوط بمهام التطبيق',
                icon: Icons.checklist_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IntegratedHabitScreen()),
                ),
              ),
              _ToolGridCard(
                title: 'ركن الطلاب',
                subtitle: 'أهداف، GPA، وجدول المذاكرة',
                icon: Icons.school_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudentHubScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. الأدوات الذكية والحاسبات
          const _SectionHeader(
              title: 'الأدوات الذكية والحاسبات', icon: Icons.calculate_rounded),
          const SizedBox(height: 10),
          GridView.count(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.48,
            children: [
              _ToolGridCard(
                title: 'محول الوحدات',
                subtitle: 'طول، وزن، مساحة، حرارة',
                icon: Icons.swap_horiz_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UnitConverterScreen()),
                ),
              ),
              _ToolGridCard(
                title: 'حاسبة العمر',
                subtitle: 'بالسنة والشهر واليوم',
                icon: Icons.cake_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AgeCalculatorScreen()),
                ),
              ),
              _ToolGridCard(
                title: 'مولد كلمات المرور',
                subtitle: 'تشفير وأمان عالي',
                icon: Icons.password_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PasswordGeneratorScreen()),
                ),
              ),
              _ToolGridCard(
                title: 'محلل النصوص',
                subtitle: 'كلمات، أحرف، وقت قراءة',
                icon: Icons.text_fields_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TextAnalyzerScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4. الإعدادات والمشاركة
          const _SectionHeader(title: 'النظام والحساب', icon: Icons.tune_rounded),
          const SizedBox(height: 10),
          GridView.count(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.48,
            children: [
              _ToolGridCard(
                title: 'الإعدادات',
                subtitle: 'المظهر، اللغة، الإشعارات',
                icon: Icons.settings_rounded,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
                  );
                  _loadUserData();
                },
              ),
              _ToolGridCard(
                title: 'مشاركة التطبيق',
                subtitle: 'انشر الخير مع غيرك',
                icon: Icons.share_rounded,
                onTap: () => Share.share(
                  'تطبيق الثعلب المتكامل — أوقات الصلاة، القرآن، الاستوديو، والأدوات الذكية.\nتطوير: أحمد تعلب (@au7md)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 5. كارت الصدقة الجارية والمطور في نهاية الصفحة
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _openDeveloperSheet,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ThalabTheme.softBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ThalabTheme.foxOrange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.volunteer_activism_rounded,
                        color: ThalabTheme.foxOrange, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('عن المطور والصدقة الجارية',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        Text('تطوير: أحمد تعلب (au7md) • اضغط للتواصل',
                            style: TextStyle(color: ThalabTheme.mutedSlate, fontSize: 11)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: ThalabTheme.mutedSlate),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// شاشة الملف الشخصي للمستخدم
// =========================================================================
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  String _gender = 'ذكر';
  int _pomodoroCount = 0;
  int _khatmahPages = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameCtrl.text = prefs.getString('user_name') ?? 'مستخدم الثعلب';
      _gender = prefs.getString('user_gender') ?? 'ذكر';
      _pomodoroCount = prefs.getInt('pomodoro_count') ?? 0;
      _khatmahPages = prefs.getInt('khatmah_pages_read') ?? 0;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameCtrl.text.trim().isEmpty ? 'مستخدم الثعلب' : _nameCtrl.text.trim());
    await prefs.setString('user_gender', _gender);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ بيانات الملف الشخصي ✓')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: ThalabTheme.foxOrange.withOpacity(0.15),
              child: Icon(
                _gender == 'أنثى' ? Icons.face_3_rounded : Icons.face_rounded,
                size: 48,
                color: ThalabTheme.foxOrange,
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'الاسم الشخصي',
              filled: true,
              fillColor: ThalabTheme.cardSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('الجنس', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('ذكر')),
                  selected: _gender == 'ذكر',
                  selectedColor: ThalabTheme.foxOrange,
                  labelStyle: TextStyle(color: _gender == 'ذكر' ? Colors.white : ThalabTheme.darkSlate),
                  onSelected: (_) => setState(() => _gender = 'ذكر'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('أنثى')),
                  selected: _gender == 'أنثى',
                  selectedColor: ThalabTheme.foxOrange,
                  labelStyle: TextStyle(color: _gender == 'أنثى' ? Colors.white : ThalabTheme.darkSlate),
                  onSelected: (_) => setState(() => _gender = 'أنثى'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThalabTheme.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ThalabTheme.softBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ملخص إنجازك في الثعلب', style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('جلسات التركيز المكتملة:'),
                    Text('$_pomodoroCount جلسة', style: const TextStyle(fontWeight: FontWeight.bold, color: ThalabTheme.foxOrange)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('صفحات الختمة المقروءة:'),
                    Text('$_khatmahPages / 604', style: const TextStyle(fontWeight: FontWeight.bold, color: ThalabTheme.foxOrange)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThalabTheme.foxOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _save,
            child: const Text('حفظ التغييرات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// شاشة الإعدادات
// =========================================================================
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _hapticEnabled = true;
  String _appLang = 'العربية';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('settings_notifications') ?? true;
      _hapticEnabled = prefs.getBool('settings_haptic') ?? true;
      _appLang = prefs.getString('settings_lang') ?? 'العربية';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            activeColor: ThalabTheme.foxOrange,
            title: const Text('تنبيهات الأذان والأذكار', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('تفعيل أو إيقاف الإشعارات اليومية'),
            value: _notificationsEnabled,
            onChanged: (v) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('settings_notifications', v);
              setState(() => _notificationsEnabled = v);
            },
          ),
          const Divider(),
          SwitchListTile(
            activeColor: ThalabTheme.foxOrange,
            title: const Text('الاهتزاز التفاعلي (Haptic)', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('اهتزاز خفيف عند التسبيح والضغط'),
            value: _hapticEnabled,
            onChanged: (v) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('settings_haptic', v);
              setState(() => _hapticEnabled = v);
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('لغة التطبيق', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(_appLang),
            trailing: const Icon(Icons.language_rounded, color: ThalabTheme.foxOrange),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('اللغة العربية هي اللغة الأساسية للتطبيق حالياً')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: ThalabTheme.foxOrange, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1.4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ThalabTheme.foxOrange.withOpacity(0.35),
                  ThalabTheme.foxOrange.withOpacity(0.0),
                ],
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolGridCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ToolGridCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  static const List<Color> _palette = [
    Color(0xFFE86A17),
    Color(0xFF2563EB),
    Color(0xFF16A34A),
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
    Color(0xFF0F766E),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final h = title.codeUnits.fold<int>(0, (a, b) => a + b);
    final accent = _palette[h % _palette.length];
    return FadeSlideIn(
      delay: Duration(milliseconds: 80 + (h % 5) * 70),
      child: PressableScale(
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent.withOpacity(isDark ? 0.20 : 0.11), theme.cardColor],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withOpacity(isDark ? 0.32 : 0.25)),
          ),
          child: Stack(
            children: [
              PositionedDirectional(
                start: -10,
                bottom: -14,
                child: Icon(icon, size: 70, color: accent.withOpacity(0.10)),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(icon, color: accent, size: 22),
                    ),
                    const Spacer(),
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: thalabMuted(context), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SocialActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
