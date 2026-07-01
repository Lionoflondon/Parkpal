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
  static const porcelain = Color(0xFFFFFCF7);
  static const smoke = Color(0xFFF0EEE8);
  static const graphite = Color(0xFF202426);
  static const shadow = Color(0x2408111F);
}

class ParkPalText {
  const ParkPalText._();

  static TextStyle display({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
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
    colorScheme: base.colorScheme.copyWith(
      primary: ParkPalColors.green700,
      secondary: ParkPalColors.irisBlue,
      surface: ParkPalColors.porcelain,
      onSurface: ParkPalColors.ink,
      error: ParkPalColors.red,
    ),
    textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: ParkPalText.display(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        color: ParkPalColors.ink,
        height: 0.98,
        letterSpacing: -1.4,
      ),
      headlineMedium: ParkPalText.display(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: ParkPalColors.ink,
        letterSpacing: -0.7,
      ),
      titleLarge: ParkPalText.display(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: ParkPalColors.ink,
        letterSpacing: -0.3,
      ),
      bodyMedium: ParkPalText.body(color: ParkPalColors.ink, height: 1.45),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: ParkPalColors.cream,
      foregroundColor: ParkPalColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: ParkPalText.display(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: ParkPalColors.ink,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ParkPalColors.green700,
        foregroundColor: Colors.white,
        disabledBackgroundColor: ParkPalColors.line,
        disabledForegroundColor: ParkPalColors.mutedTwo,
        elevation: 0,
        textStyle: ParkPalText.body(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ParkPalColors.green700,
        disabledForegroundColor: ParkPalColors.mutedTwo,
        side: const BorderSide(color: ParkPalColors.greenLine),
        textStyle: ParkPalText.body(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ParkPalColors.porcelain,
      hintStyle: ParkPalText.body(color: ParkPalColors.mutedTwo),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: ParkPalColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: ParkPalColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: ParkPalColors.green700, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.92),
      indicatorColor: ParkPalColors.mint100,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? ParkPalColors.green700 : ParkPalColors.mutedTwo,
          size: 24,
        );
      }),
      labelTextStyle: WidgetStatePropertyAll(
        ParkPalText.body(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ParkPalColors.midnight,
      contentTextStyle: ParkPalText.body(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        color: ParkPalColors.shadow,
        blurRadius: 34,
        spreadRadius: -14,
        offset: const Offset(0, 22),
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.65),
        blurRadius: 18,
        spreadRadius: -18,
        offset: const Offset(0, -6),
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
