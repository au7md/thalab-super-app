import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'rafiq_notifications_service.dart';

/// Unique name of the periodic background task that keeps prayer and azkar
/// notifications topped up even when the app is not opened for days.
const String kNotificationTopUpTask = 'thalab_notification_topup';

/// Background entry point invoked by WorkManager. Re-computes prayer times
/// from the last saved location and re-schedules the rolling notification
/// window. Runs in a separate isolate, so it must stay self-contained.
@pragma('vm:entry-point')
void notificationTopUpDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('saved_lat') ??
          prefs.getDouble('prayer_lat') ??
          30.0444;
      final lng = prefs.getDouble('saved_lng') ??
          prefs.getDouble('prayer_lng') ??
          31.2357;
      final params = CalculationMethod.egyptian.getParameters();
      params.madhab = Madhab.shafi;
      await RafiqNotificationsService.instance.syncAllScheduledNotifications(
        lat: lat,
        lng: lng,
        params: params,
      );
      return true;
    } catch (_) {
      return false;
    }
  });
}
