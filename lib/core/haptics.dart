import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// اهتزاز موحّد يحترم مفتاح «الاهتزاز التفاعلي» في الإعدادات.
class Haptics {
  Haptics._();
  static bool? _enabled;

  static Future<bool> _on() async {
    if (_enabled != null) return _enabled!;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('settings_haptic') ?? true;
    return _enabled!;
  }

  static void setEnabled(bool v) => _enabled = v;

  static Future<void> lightImpact() async {
    if (await _on()) await HapticFeedback.lightImpact();
  }

  static Future<void> mediumImpact() async {
    if (await _on()) await HapticFeedback.mediumImpact();
  }

  static Future<void> heavyImpact() async {
    if (await _on()) await HapticFeedback.heavyImpact();
  }

  static Future<void> selectionClick() async {
    if (await _on()) await HapticFeedback.selectionClick();
  }
}
