import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ParkPalColors {
  const ParkPalColors._();

  static const midnight = Color(0xFF08111F);
  static const navy = Color(0xFF101C2F);
  static const irisBlue = Color(0xFF3B82F6);
  static const irisCyan = Color(0xFF36D4FF);
  static const green900 = Color(0xFF0B3D24);
  static const green700 = Color(0xFF145A32);
  static const green500 = Color(0xFF1F7A4D);
  static const safeGreen = Color(0xFF1FA971);
  static const mint100 = Color(0xFFE7F4EB);
  static const mint50 = Color(0xFFF2F8F3);
  static const cream = Color(0xFFFAF8F3);
  static const ink = Color(0xFF14181A);
  static const muted = Color(0xFF62695F);
  static const mutedTwo = Color(0xFF8B9189);
  static const amber = Color(0xFF9A5B0E);
  static const amberBg = Color(0xFFFBF0DC);
  static const amberLine = Color(0xFFE7C988);
  static const red = Color(0xFFA23128);
  static const redBg = Color(0xFFFAEAE6);
  static const redLine = Color(0xFFE5B6AC);
  static const greenBg = Color(0xFFE6F2E9);
  static const greenLine = Color(0xFFB9D9C2);
  static const glassWhite = Color(0x1AFFFFFF);
  static const glassBorder = Color(0x33FFFFFF);
  static const line = Color(0x1A14181A);
  static const lineSoft = Color(0x0F14181A);
}

class ParkPalText {
  const ParkPalText._();

  static TextStyle display({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static TextStyle body({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static TextStyle mono({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }
}

Color parkPalStatusColor(String label) {
  final normalised = label.toLowerCase();
  if (normalised.contains('yes') ||
      normalised.contains('allowed') ||
      normalised.contains('safe')) {
    return ParkPalColors.safeGreen;
  }
  if (normalised.contains('no') ||
      normalised.contains('not allowed') ||
      normalised.contains('do not')) {
    return ParkPalColors.red;
  }
  return ParkPalColors.amber;
}

Color parkPalStatusBg(String label) {
  final color = parkPalStatusColor(label);
  if (color == ParkPalColors.safeGreen) return ParkPalColors.greenBg;
  if (color == ParkPalColors.red) return ParkPalColors.redBg;
  return ParkPalColors.amberBg;
}

Color parkPalStatusLine(String label) {
  final color = parkPalStatusColor(label);
  if (color == ParkPalColors.safeGreen) return ParkPalColors.greenLine;
  if (color == ParkPalColors.red) return ParkPalColors.redLine;
  return ParkPalColors.amberLine;
}

ThemeData buildParkPalTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: ParkPalColors.green700),
    useMaterial3: true,
  );

  return base.copyWith(
    scaffoldBackgroundColor: ParkPalColors.cream,
    textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: ParkPalText.display(
        fontSize: 56,
        fontWeight: FontWeight.w700,
        color: ParkPalColors.ink,
        height: 0.95,
      ),
      headlineMedium: ParkPalText.display(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: ParkPalColors.ink,
      ),
      titleLarge: ParkPalText.display(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: ParkPalColors.ink,
      ),
      bodyMedium: ParkPalText.body(color: ParkPalColors.ink),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: ParkPalColors.cream,
      foregroundColor: ParkPalColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: ParkPalText.display(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: ParkPalColors.ink,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ParkPalColors.green700,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ParkPalColors.green700,
        side: const BorderSide(color: ParkPalColors.green700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: ParkPalColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: ParkPalColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: ParkPalColors.green700, width: 1.4),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.92),
      indicatorColor: ParkPalColors.mint100,
      labelTextStyle: WidgetStatePropertyAll(
        ParkPalText.body(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

BoxDecoration parkPalGlassDecoration({
  Color color = Colors.white,
  double opacity = 0.72,
  double radius = 28,
}) {
  return BoxDecoration(
    color: color.withValues(alpha: opacity),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: ParkPalColors.lineSoft),
    boxShadow: [
      BoxShadow(
        color: ParkPalColors.green900.withValues(alpha: 0.08),
        blurRadius: 26,
        offset: const Offset(0, 16),
      ),
    ],
  );
}

LinearGradient parkPalIridescentBorderGradient() {
  return const LinearGradient(
    colors: [
      ParkPalColors.irisBlue,
      ParkPalColors.irisCyan,
      ParkPalColors.safeGreen,
    ],
  );
}
