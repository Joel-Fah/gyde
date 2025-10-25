// lib/utils/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4A90E2),
        // A nice, friendly blue
        brightness: Brightness.light,
        primary: const Color(0xFF4A90E2),
        secondary: const Color(0xFF50E3C2),
        // A contrasting mint green
        // Define specific container colors for user vs. model messages
        primaryContainer: const Color(0xFFD8E6F8),
        // User message bubble
        secondaryContainer: const Color(0xFFE8F5E9), // Model message bubble
      ),
      textTheme: GoogleFonts.syneTextTheme(
        ThemeData.light().textTheme.copyWith(
          bodyMedium: GoogleFonts.syne(fontSize: 18.0),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.sourceSans3(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F9FC),
    );
  }
}
