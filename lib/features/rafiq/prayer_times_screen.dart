/// التبويب الثالث: إعدادات تنبيهات كل صلاة + اختيار المؤذن لكل صلاة
Widget _buildPrayerNotificationsTab() {
  final prayers = [
    ('fajr', 'صلاة الفجر', Icons.wb_twilight_rounded),
    ('dhuhr', 'صلاة الظهر', Icons.wb_sunny_rounded),
    ('asr', 'صلاة العصر', Icons.wb_sunny_outlined),
    ('maghrib', 'صلاة المغرب', Icons.nights_stay_outlined),
    ('isha', 'صلاة العشاء', Icons.bedtime_rounded),
  ];

  const beforeOptions = [0, 5, 10, 15, 30];
  const afterOptions = [0, 10, 15, 20, 25];

  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
    children: [
      Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ThalabTheme.foxOrange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_active_rounded, color: ThalabTheme.foxOrange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'خصّص تنبيه الاستعداد، صوت المؤذن، وتنبيه الإقامة والأذكار لكل صلاة بمرونة كاملة.',
                style: TextStyle(fontSize: 12, height: 1.45, color: _textColor),
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ThalabTheme.foxOrange,
                  side: const BorderSide(color: ThalabTheme.foxOrange),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  final fajrMuezzin = _perPrayerMuezzin['fajr'] ?? 'fajr_egypt';
                  await RafiqNotificationsService.instance.sendTestScheduledAdhan(
                    muezzinId: fajrMuezzin,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('سيصل إشعار الأذان التجريبي خلال 5 ثوانٍ — أغلق التطبيق للتجربة'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
                label: const Text(
                  'تجربة الأذان (5 ث)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F766E),
                  side: const BorderSide(color: Color(0xFF0F766E)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final userName = prefs.getString('user_name')?.trim() ?? 'صديقي';
                  await RafiqNotificationsService.instance.scheduleDailyAzkar(
                    id: 505,
                    title: 'محاسبة سجل الصلوات يا $userName',
                    body: 'هل سجّلت صلواتك وسننك اليوم في رفيق؟ راجع سجلّك الآن.',
                    hour: 21,
                    minute: 30,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تفعيل تذكير سجل الصلوات اليومي (9:30 مساءً) ✓'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.fact_check_rounded, size: 20),
                label: const Text(
                  'تذكير سجل الصلاة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ),
            ),
          ],
        ),
      ),
      ...prayers.map((p) {
        final key = p.$1;
        final title = p.$2;
        final icon = p.$3;
        final adhanOn = _adhanNotifEnabled[key] ?? true;
        final beforeVal = _beforeNotifMins[key] ?? 10;
        final afterVal = _afterNotifMins[key] ?? 15;

        final muezzinList = key == 'fajr'
            ? RafiqNotificationsService.fajrMuezzins
            : RafiqNotificationsService.generalMuezzins;
        final currentMuezzinId =
            _perPrayerMuezzin[key] ?? (key == 'fajr' ? 'fajr_egypt' : 'mishary_afasy');

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor, width: 1.3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: ThalabTheme.foxOrange, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: _textColor,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Text('الأذان', style: TextStyle(fontSize: 12, color: _textColor)),
                      Switch(
                        value: adhanOn,
                        activeColor: ThalabTheme.foxOrange,
                        onChanged: (val) async {
                          final prefs = await SharedPreferences.getInstance();
                          setState(() => _adhanNotifEnabled[key] = val);
                          await prefs.setBool('prayer_notif_${key}_adhan', val);
                          await _syncNotificationsNow();
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 14),

              // 1. تنبيه الاستعداد قبل الأذان (قائمة منسدلة)
              const Text(
                'تنبيه الاستعداد قبل الأذان:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ThalabTheme.mutedSlate),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                value: beforeOptions.contains(beforeVal) ? beforeVal : 0,
                dropdownColor: _cardBg,
                style: TextStyle(color: _textColor, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _innerBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: beforeOptions
                    .map((mins) => DropdownMenuItem(
                          value: mins,
                          child: Text(
                            mins == 0 ? 'إيقاف التنبيه المسبق' : 'قبل الأذان بـ $mins دقيقة',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ))
                    .toList(),
                onChanged: (val) async {
                  if (val == null) return;
                  final prefs = await SharedPreferences.getInstance();
                  setState(() => _beforeNotifMins[key] = val);
                  await prefs.setInt('prayer_notif_${key}_before', val);
                  await _syncNotificationsNow();
                },
              ),
              const SizedBox(height: 10),

              // 2. صوت المؤذن لهذه الصلاة
              const Text(
                'صوت المؤذن لهذه الصلاة:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ThalabTheme.mutedSlate),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: muezzinList.any((m) => m.id == currentMuezzinId)
                    ? currentMuezzinId
                    : muezzinList.first.id,
                dropdownColor: _cardBg,
                style: TextStyle(color: _textColor, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _innerBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: muezzinList
                    .map((m) => DropdownMenuItem(
                          value: m.id,
                          child: Text(m.name, style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (val) async {
                  if (val == null) return;
                  final prefs = await SharedPreferences.getInstance();
                  setState(() => _perPrayerMuezzin[key] = val);
                  await prefs.setString('prayer_muezzin_$key', val);
                  await _syncNotificationsNow();
                },
              ),
              const SizedBox(height: 10),

              // 3. تنبيه الإقامة وأذكار بعد الصلاة (قائمة منسدلة)
              const Text(
                'تنبيه الإقامة وأذكار بعد الصلاة:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ThalabTheme.mutedSlate),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                value: afterOptions.contains(afterVal) ? afterVal : 0,
                dropdownColor: _cardBg,
                style: TextStyle(color: _textColor, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _innerBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: afterOptions
                    .map((mins) => DropdownMenuItem(
                          value: mins,
                          child: Text(
                            mins == 0 ? 'إيقاف تنبيه ما بعد الصلاة' : 'بعد الأذان بـ $mins دقيقة',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ))
                    .toList(),
                onChanged: (val) async {
                  if (val == null) return;
                  final prefs = await SharedPreferences.getInstance();
                  setState(() => _afterNotifMins[key] = val);
                  await prefs.setInt('prayer_notif_${key}_after', val);
                  await _syncNotificationsNow();
                },
              ),
            ],
          ),
        );
      }),
    ],
  );
}
