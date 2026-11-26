import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/rafiq_notifications_service.dart';
import '../../core/theme.dart';

/// شاشة تشخيص الأذان والإشعارات: تعرض حالة كل شرط يلزم لوصول الأذان،
/// وتتيح اختبار كل مسار على حدة، وتفتح إعدادات النظام الضرورية.
class AdhanDiagnosticsScreen extends StatefulWidget {
  const AdhanDiagnosticsScreen({super.key});

  @override
  State<AdhanDiagnosticsScreen> createState() => _AdhanDiagnosticsScreenState();
}

class _AdhanDiagnosticsScreenState extends State<AdhanDiagnosticsScreen> {
  final RafiqNotificationsService _svc = RafiqNotificationsService.instance;
  Map<String, dynamic> _d = {};
  bool _loading = true;
  bool _follow = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final d = await _svc.diagnostics();
    if (!mounted) return;
    setState(() {
      _d = d;
      _follow = prefs.getBool('adhan_follow_ringer') ?? true;
      _loading = false;
    });
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  String _fmtTime(int ms) {
    if (ms <= 0) return 'لا يوجد';
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)}  ${two(t.hour)}:${two(t.minute)}';
  }

  String _ringerLabel(String r) {
    switch (r) {
      case 'normal':
        return 'عادي (سيُسمع الأذان)';
      case 'vibrate':
        return 'اهتزاز (بدون صوت)';
      default:
        return 'صامت (بدون صوت)';
    }
  }

  Widget _row(String label, bool? ok, String detail) {
    final scheme = Theme.of(context).colorScheme;
    final color = ok == null
        ? scheme.onSurfaceVariant
        : (ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626));
    final icon = ok == null
        ? Icons.info_outline_rounded
        : (ok ? Icons.check_circle_rounded : Icons.cancel_rounded);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                if (detail.isNotEmpty)
                  Text(detail, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(String title, List<Widget> children) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15, color: ThalabTheme.foxOrange)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _btn(IconData icon, String label, Future<void> Function() onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.tonalIcon(
          onPressed: () async {
            await onTap();
          },
          icon: Icon(icon, size: 19),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ),
    );
  }

  String _report() {
    try {
      return const JsonEncoder.withIndent('  ').convert(_d);
    } catch (_) {
      return _d.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = (_d['rawFound'] as Map?) ?? {};
    final missing = raw.entries.where((e) => e.value != true).map((e) => '${e.key}').toList();
    final nativeError = (_d['nativeError'] ?? '') as String;
    final lastError = (_d['lastError'] ?? '') as String;
    final ringer = (_d['ringer'] ?? 'normal') as String;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تشخيص الأذان والإشعارات'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: ThalabTheme.foxOrange))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _card('حالة النظام', [
                  _row(
                    'نظام الأذان الأصلي',
                    nativeError.isEmpty,
                    nativeError.isEmpty ? 'متصل' : nativeError,
                  ),
                  _row(
                    'إذن الإشعارات',
                    _d['notificationsEnabled'] == true,
                    _d['notificationsEnabled'] == true ? '' : 'اضغط «طلب إذن الإشعارات» بالأسفل',
                  ),
                  _row(
                    'المنبهات الدقيقة (المكتبة)',
                    _d['canExact'] == true,
                    'الأذان الأصلي لا يحتاجها، لكنها تفيد باقي التنبيهات',
                  ),
                  _row(
                    'استثناء البطارية',
                    _d['batteryIgnored'] == true,
                    _d['batteryIgnored'] == true
                        ? ''
                        : 'مهم جداً على أوبو: بدونه قد يُقتل التطبيق ولا يصل الأذان',
                  ),
                  _row('وضع الرنين الحالي', ringer == 'normal', _ringerLabel(ringer)),
                  _row(
                    'عدم الإزعاج (DND)',
                    _d['dnd'] != true,
                    _d['dnd'] == true ? 'مفعّل: سيمنع صوت الأذان' : 'غير مفعّل',
                  ),
                  _row(
                    'ملفات صوت الأذان داخل التطبيق',
                    missing.isEmpty,
                    missing.isEmpty ? 'كل الأصوات موجودة' : 'مفقودة: ${missing.join('، ')}',
                  ),
                  _row(
                    'أذانات مجدولة (نظام الأذان)',
                    (_d['scheduledCount'] ?? 0) > 0,
                    'العدد: ${_d['scheduledCount'] ?? 0} — التالي: ${_fmtTime((_d['nextAlarmMs'] ?? 0) as int)}',
                  ),
                  _row(
                    'إشعارات مجدولة (المكتبة)',
                    (_d['pluginPending'] ?? -1) > 0,
                    'العدد: ${_d['pluginPending']}',
                  ),
                  _row(_deviceName(_d['device']), null, 'أندرويد API ${_d['sdk'] ?? '?'}'),
                ]),
                _card('إعداد الصوت', [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: ThalabTheme.foxOrange,
                    title: const Text('الأذان يحترم وضع الصامت',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    subtitle: const Text('عند الصامت أو الاهتزاز: إشعار فقط بدون صوت أذان',
                        style: TextStyle(fontSize: 12)),
                    value: _follow,
                    onChanged: (v) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('adhan_follow_ringer', v);
                      setState(() => _follow = v);
                      await _svc.resyncFromSavedLocation();
                      await _load();
                    },
                  ),
                ]),
                _card('اختبارات', [
                  _btn(Icons.timer_rounded, 'أذان مجدول بعد 10 ثوانٍ (النظام الجديد)', () async {
                    await _svc.sendTestScheduledAdhan(delaySeconds: 10);
                    _toast('أغلق الشاشة أو اخرج من التطبيق وانتظر 10 ثوانٍ');
                  }),
                  _btn(Icons.play_arrow_rounded, 'تشغيل الأذان الآن', () async {
                    final ok = await _svc.nativeAction('playNow', {
                      'title': 'تجربة الأذان',
                      'body': 'اختبار تشغيل الصوت',
                      'muezzin': 'mishary_afasy',
                      'followRinger': _follow,
                    });
                    _toast(ok ? 'تم الإرسال' : 'فشل التشغيل — راجع آخر خطأ');
                    await _load();
                  }),
                  _btn(Icons.stop_rounded, 'إيقاف الأذان', () async {
                    await _svc.nativeAction('stop');
                  }),
                  _btn(Icons.notifications_active_rounded, 'إشعار مجدول بعد 10 ثوانٍ (المكتبة)', () async {
                    await _svc.clearLastError();
                    await _svc.sendTestPluginScheduled(delaySeconds: 10);
                    _toast('سيصل إشعار بعد 10 ثوانٍ — ثم حدّث الشاشة لرؤية الأخطاء');
                    await _load();
                  }),
                  _btn(Icons.sync_rounded, 'إعادة جدولة كل التنبيهات', () async {
                    await _svc.resyncFromSavedLocation();
                    _toast('أُعيدت الجدولة');
                    await _load();
                  }),
                ]),
                _card('الأذونات وإعدادات أوبو', [
                  _btn(Icons.notifications_rounded, 'طلب إذن الإشعارات', () async {
                    await _svc.requestPermissionsFromUi();
                    await _load();
                  }),
                  _btn(Icons.battery_charging_full_rounded, 'استثناء التطبيق من توفير البطارية', () async {
                    await _svc.nativeAction('openBatterySettings');
                  }),
                  _btn(Icons.rocket_launch_rounded, 'التشغيل التلقائي (Oppo / ColorOS)', () async {
                    final ok = await _svc.nativeAction('openAutoStart');
                    if (!ok) {
                      _toast('تعذّر الفتح مباشرة: الإعدادات ← التطبيقات ← الثعلب ← استخدام البطارية ← السماح بالنشاط في الخلفية');
                      await _svc.nativeAction('openAppSettings');
                    }
                  }),
                  _btn(Icons.settings_rounded, 'إعدادات التطبيق في النظام', () async {
                    await _svc.nativeAction('openAppSettings');
                  }),
                ]),
                _card('آخر خطأ مسجّل', [
                  SelectableText(
                    lastError.isEmpty ? 'لا توجد أخطاء مسجّلة ✓' : lastError,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 10),
                  _btn(Icons.copy_rounded, 'نسخ تقرير التشخيص كاملاً', () async {
                    await Clipboard.setData(ClipboardData(text: _report()));
                    _toast('تم النسخ — الصقه في المحادثة');
                  }),
                ]),
              ],
            ),
    );
  }

  String _deviceName(dynamic v) => (v ?? 'الجهاز').toString();
}
