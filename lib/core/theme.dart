import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThalabTheme {
  // لوحة الألوان المستخلصة من الهوية البصرية
  static const Color creamBackground = Color(0xFFFFF8F0);
  static const Color cardSurface = Color(0xFFFFFCF8);
  static const Color foxOrange = Color(0xFFFF7A1A);
  static const Color foxOrangeLight = Color(0xFFFF9E44);
  static const Color darkSlate = Color(0xFF3A3D42);
  static const Color mutedSlate = Color(0xFF7D828A);
  static const Color softBorder = Color(0xFFF3E2D0);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: creamBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: foxOrange,
        surface: creamBackground,
        primary: foxOrange,
        onSurface: darkSlate,
      ),
      textTheme: GoogleFonts.cairoTextTheme().apply(
        bodyColor: darkSlate,
        displayColor: darkSlate,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.cairo(
          color: darkSlate,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
