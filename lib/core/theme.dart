import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class ThalabTheme {
  static const Color creamBackground = Color(0xFFFFF8F0);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color foxOrange = Color(0xFFE86A17);
  static const Color foxOrangeLight = Color(0xFFFF8C3B);
  static const Color darkSlate = Color(0xFF22252A);
  static const Color mutedSlate = Color(0xFF6B7280);
  static const Color softBorder = Color(0xFFF2E6D8);

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.readexProTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: creamBackground,
      primaryColor: foxOrange,
      colorScheme: ColorScheme.fromSeed(
        seedColor: foxOrange,
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
}
