import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'page_transitions.dart';

class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_theme_mode') ?? 'light';
    mode.value = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setTheme(ThemeMode newMode) async {
    mode.value = newMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'app_theme_mode',
      newMode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  Future<void> toggle() async {
    await setTheme(
      mode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  bool get isDark => mode.value == ThemeMode.dark;
}

class ThalabTheme {
  static const Color creamBackground = Color(0xFFFFF8F0);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color foxOrange = Color(0xFFE86A17);
  static const Color foxOrangeLight = Color(0xFFFF8C3B);
  static const Color darkSlate = Color(0xFF22252A);
  static const Color mutedSlate = Color(0xFF6B7280);
  static const Color softBorder = Color(0xFFF2E6D8);

  // ألوان الوضع الليلي
  static const Color darkBackground = Color(0xFF121316);
  static const Color darkCardSurface = Color(0xFF1C1E22);
  static const Color darkBorder = Color(0xFF2C2F36);
  static const Color darkTextPrimary = Color(0xFFF3F4F6);
  static const Color darkTextMuted = Color(0xFF9CA3AF);

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.readexProTextTheme();

    return ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ThalabPageTransitionsBuilder(),
          TargetPlatform.iOS: ThalabPageTransitionsBuilder(),
        },
      ),
      brightness: Brightness.light,
      scaffoldBackgroundColor: creamBackground,
      cardColor: cardSurface,
      primaryColor: foxOrange,
      colorScheme: ColorScheme.fromSeed(
        seedColor: foxOrange,
        brightness: Brightness.light,
        surface: creamBackground,
        onSurface: darkSlate,
      ),
      textTheme: baseTextTheme.copyWith(
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: darkSlate, height: 1.6),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: darkSlate, height: 1.5),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: darkSlate,
          fontWeight: FontWeight.bold,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: creamBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: creamBackground,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.readexPro(
          color: darkSlate,
          fontSize: 19,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: darkSlate),
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.readexProTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ThalabPageTransitionsBuilder(),
          TargetPlatform.iOS: ThalabPageTransitionsBuilder(),
        },
      ),
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      cardColor: darkCardSurface,
      primaryColor: foxOrange,
      colorScheme: ColorScheme.fromSeed(
        seedColor: foxOrange,
        brightness: Brightness.dark,
        surface: darkBackground,
        onSurface: darkTextPrimary,
      ),
      textTheme: baseTextTheme.copyWith(
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: darkTextPrimary, height: 1.6),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: darkTextPrimary, height: 1.5),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: darkTextPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: darkBackground,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: GoogleFonts.readexPro(
          color: darkTextPrimary,
          fontSize: 19,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: darkTextPrimary),
      ),
    );
  }
}
