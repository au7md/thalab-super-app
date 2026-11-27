import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/fox_mascot.dart';
import '../../core/rafiq_notifications_service.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';

/// الترحيب: 5 خطوات (مرحباً، الأقسام، عنك، الأذونات، جاهز).
class OnboardingScreen extends StatefulWidget {
  final WidgetBuilder homeBuilder;
  const OnboardingScreen({super.key, required this.homeBuilder});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with WidgetsBindingObserver {
  static const int _pages = 5;
  final PageController _pc = PageController();
  final TextEditingController _name = TextEditingController();
  int _page = 0;
  String _gender = 'ذكر';

  // حالة الأذونات
  bool _notifOk = false;
  bool _batteryOk = false;
  bool _locationOk = false;
  bool _autoStartDone = false;
  String _device = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPerms();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pc.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPerms();
  }

  Future<void> _refreshPerms() async {
    try {
      final d = await RafiqNotificationsService.instance.diagnostics();
      final lp = await Geolocator.checkPermission();
      if (!mounted) return;
      setState(() {
        _notifOk = d['notificationsEnabled'] == true;
        _batteryOk = d['batteryIgnored'] == true;
        _device = ((d['device'] ?? '') as String).toLowerCase();
        _locationOk =
            lp == LocationPermission.always || lp == LocationPermission.whileInUse;
      });
    } catch (_) {}
  }

  bool get _needsAutoStart {
    const brands = ['oppo', 'realme', 'oneplus', 'xiaomi', 'redmi', 'poco', 'vivo', 'huawei', 'honor', 'samsung'];
    return brands.any((b) => _device.contains(b));
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _go(int p) async {
    await _pc.animateToPage(
      p,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _next() async {
    if (_page == 2 && _name.text.trim().isEmpty) {
      _toast('اكتب اسمك لينادي عليك الثعلب به 🦊');
      return;
    }
    if (_page < _pages - 1) {
      FocusScope.of(context).unfocus();
      await _go(_page + 1);
    } else {
      await _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _name.text.trim());
    await prefs.setString('user_gender', _gender);
    await prefs.setBool('first_launch_v1.7', false);
    await prefs.setBool('perm_flow_done_v2', true);
    if (!mounted) return;
    Navigator.pushReplacement(context, fadeScaleRoute(widget.homeBuilder));
  }

  // ---------------- الأذونات ----------------
  Future<void> _askNotif() async {
    await RafiqNotificationsService.instance.requestPermissionsFromUi();
    await _refreshPerms();
  }

  Future<void> _askLocation() async {
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.deniedForever) {
      _toast('الموقع مرفوض نهائياً — يمكنك اختيار مدينتك يدوياً داخل التطبيق');
    }
    await _refreshPerms();
  }

  Future<void> _askBattery() async {
    await RafiqNotificationsService.instance.nativeAction('openBatterySettings');
  }

  Future<void> _askAutoStart() async {
    final svc = RafiqNotificationsService.instance;
    final ok = await svc.nativeAction('openAutoStart');
    if (!ok) {
      _toast('افتح: الإعدادات ← التطبيقات ← الثعلب ← استخدام البطارية ← السماح بالنشاط في الخلفية');
      await svc.nativeAction('openAppSettings');
    }
    if (mounted) setState(() => _autoStartDone = true);
  }

  Future<void> _enableAll() async {
    if (!_notifOk) await _askNotif();
    if (!_locationOk) await _askLocation();
    if (!_batteryOk) await _askBattery();
  }

  // ---------------- البناء ----------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = thalabMuted(context);
    final isLast = _page == _pages - 1;

    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _page > 0) _go(_page - 1);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pc,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _welcomePage(muted),
                    _featuresPage(muted),
                    _aboutPage(muted),
                    _permissionsPage(muted),
                    _readyPage(muted),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: Row(
                  children: [
                    SizedBox(
                      width: 84,
                      child: _page > 0
                          ? TextButton(
                              onPressed: () => _go(_page - 1),
                              child: Text('رجوع', style: TextStyle(color: muted)),
                            )
                          : null,
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages, (i) {
                          final active = i == _page;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 22 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: active
                                  ? ThalabTheme.foxOrange
                                  : theme.dividerColor.withOpacity(0.6),
                            ),
                          );
                        }),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: ThalabTheme.foxOrange,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        onPressed: _next,
                        child: Text(
                          isLast ? 'ابدأ الآن 🚀' : 'التالي',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                        ),
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
  }

  Widget _title(String t) => Text(
        t,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1.4),
      );

  Widget _sub(String t, Color muted) => Text(
        t,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14.5, color: muted, height: 1.7, fontWeight: FontWeight.w500),
      );

  // 0) مرحباً
  Widget _welcomePage(Color muted) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const FoxMascot(size: 170, mood: FoxMood.happy),
          const SizedBox(height: 30),
          FadeSlideIn(delay: const Duration(milliseconds: 200), child: _title('أهلاً بك في الثعلب 🦊')),
          const SizedBox(height: 10),
          FadeSlideIn(
            delay: const Duration(milliseconds: 380),
            child: _sub('مساحتك اليومية الهادئة: صلاتك وأذكارك، صورك وصوتياتك، وأدواتك الذكية في مكان واحد.', muted),
          ),
          const SizedBox(height: 22),
          const FadeSlideIn(
            delay: Duration(milliseconds: 600),
            child: FoxSays('هيا نجهّز التطبيق في دقيقة واحدة ✨'),
          ),
        ],
      ),
    );
  }

  // 1) الأقسام
  Widget _featuresPage(Color muted) {
    const items = [
      ('🕌', 'رفيق', 'مواقيت وأذان، مصحف، أذكار، سبحة، قبلة، وتقويم هجري.'),
      ('📸', 'المعرض', 'صورك وفيديوهاتك مع قص وتحرير ومشاركة.'),
      ('🎧', 'الصوتيات', 'مشغل بالخلفية، مسجّل صوت، واستوديو قص.'),
      ('🧰', 'المزيد', 'خزنة سرية، بومودورو، عادات، وركن الطلاب.'),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      child: Column(
        children: [
          const FoxMascot(size: 84, mood: FoxMood.idle, showBadge: false),
          const SizedBox(height: 14),
          _title('أربعة أقسام، رفيق واحد'),
          const SizedBox(height: 18),
          for (var i = 0; i < items.length; i++)
            FadeSlideIn(
              delay: Duration(milliseconds: 150 + i * 140),
              child: _featureCard(items[i].$1, items[i].$2, items[i].$3, muted),
            ),
        ],
      ),
    );
  }

  Widget _featureCard(String emoji, String title, String desc, Color muted) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ThalabTheme.foxOrange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 3),
                Text(desc, style: TextStyle(color: muted, fontSize: 12.5, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2) عنك
  Widget _aboutPage(Color muted) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: FoxMascot(size: 92, mood: _name.text.trim().isEmpty ? FoxMood.idle : FoxMood.happy)),
          const SizedBox(height: 14),
          Center(child: _title('دعنا نتعرف عليك')),
          const SizedBox(height: 22),
          const Text('بماذا تحب أن نناديك؟', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'مثال: أحمد',
              filled: true,
              fillColor: theme.cardColor,
              prefixIcon: const Icon(Icons.person_rounded, color: ThalabTheme.foxOrange),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: ThalabTheme.foxOrange, width: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('لضبط صيغة الخطاب', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _choice('👨', 'ذكر', _gender == 'ذكر', () => setState(() => _gender = 'ذكر'))),
              const SizedBox(width: 10),
              Expanded(child: _choice('👩', 'أنثى', _gender == 'أنثى', () => setState(() => _gender = 'أنثى'))),
            ],
          ),
          const SizedBox(height: 20),
          const Text('مظهر التطبيق', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.instance.mode,
            builder: (_, mode, __) => Row(
              children: [
                Expanded(
                  child: _themeCard('☀️ فاتح', false, mode != ThemeMode.dark,
                      () => ThemeController.instance.setTheme(ThemeMode.light)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _themeCard('🌙 ليلي', true, mode == ThemeMode.dark,
                      () => ThemeController.instance.setTheme(ThemeMode.dark)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _choice(String emoji, String label, bool selected, VoidCallback onTap) {
    final theme = Theme.of(context);
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? ThalabTheme.foxOrange : theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? ThalabTheme.foxOrange : theme.dividerColor.withOpacity(0.6),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeCard(String label, bool dark, bool selected, VoidCallback onTap) {
    final bg = dark ? ThalabTheme.darkBackground : ThalabTheme.creamBackground;
    final card = dark ? ThalabTheme.darkCardSurface : ThalabTheme.cardSurface;
    final line = dark ? ThalabTheme.darkBorder : ThalabTheme.softBorder;
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? ThalabTheme.foxOrange : line,
            width: selected ? 2.2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: line),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: ThalabTheme.foxOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 6,
                    decoration: BoxDecoration(
                      color: line,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: dark ? ThalabTheme.darkTextPrimary : ThalabTheme.darkSlate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3) الأذونات
  Widget _permissionsPage(Color muted) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        children: [
          const FoxMascot(size: 84, mood: FoxMood.praying),
          const SizedBox(height: 12),
          _title('لنضمن وصول الأذان في وقته'),
          const SizedBox(height: 8),
          _sub('كل إذن له سبب واضح، ويمكنك تغييره لاحقاً من «تشخيص الأذان».', muted),
          const SizedBox(height: 18),
          _permRow(
            emoji: '🔔',
            title: 'الإشعارات',
            why: 'ليصلك الأذان والأذكار والتذكيرات.',
            granted: _notifOk,
            button: 'تفعيل',
            onTap: _askNotif,
          ),
          _permRow(
            emoji: '🔋',
            title: 'استثناء البطارية',
            why: 'حتى لا يوقف النظام التطبيق ويفوتك الأذان.',
            granted: _batteryOk,
            button: 'استثناء',
            onTap: _askBattery,
          ),
          if (_needsAutoStart)
            _permRow(
              emoji: '🚀',
              title: 'التشغيل التلقائي',
              why: 'مهم في أوبو وشاومي وسامسونج: فعّل النشاط في الخلفية ثم ارجع.',
              granted: _autoStartDone,
              button: 'فتح',
              onTap: _askAutoStart,
            ),
          _permRow(
            emoji: '📍',
            title: 'الموقع (اختياري)',
            why: 'لدقة المواقيت والقبلة، ويمكنك اختيار مدينتك يدوياً.',
            granted: _locationOk,
            button: 'تفعيل',
            onTap: _askLocation,
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: ThalabTheme.foxOrange,
                side: const BorderSide(color: ThalabTheme.foxOrange),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: _enableAll,
              icon: const Icon(Icons.auto_awesome_rounded, size: 19),
              label: const Text('تفعيل الأساسيات دفعة واحدة', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 8),
          Text('المايكروفون يُطلب فقط عند أول تسجيل صوت.', style: TextStyle(color: muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _permRow({
    required String emoji,
    required String title,
    required String why,
    required bool granted,
    required String button,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final muted = thalabMuted(context);
    const green = Color(0xFF16A34A);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: granted ? green.withOpacity(0.6) : theme.dividerColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(why, style: TextStyle(color: muted, fontSize: 12, height: 1.45)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: granted
                ? const Icon(Icons.check_circle_rounded, key: ValueKey('ok'), color: green, size: 28)
                : FilledButton.tonal(
                    key: const ValueKey('btn'),
                    onPressed: onTap,
                    child: Text(button, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
          ),
        ],
      ),
    );
  }

  // 4) جاهز
  Widget _readyPage(Color muted) {
    final name = _name.text.trim().isEmpty ? 'صديقي' : _name.text.trim();
    final done = [_notifOk, _batteryOk, _locationOk].where((e) => e).length;
    return Stack(
      children: [
        if (_page == _pages - 1) const Positioned.fill(child: FoxConfetti()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FoxMascot(size: 160, mood: FoxMood.happy),
              const SizedBox(height: 26),
              _title('جاهز يا $name! 🎉'),
              const SizedBox(height: 10),
              _sub(
                done >= 2
                    ? 'ضبطنا الأساسيات، وسيصلك الأذان في وقته بإذن الله.'
                    : 'يمكنك إكمال الأذونات لاحقاً من «تشخيص الأذان والإشعارات» في قسم رفيق.',
                muted,
              ),
              const SizedBox(height: 18),
              const FoxSays('تقبّل الله طاعتكم 🌙'),
            ],
          ),
        ),
      ],
    );
  }
}
