import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ParkPalAdminColors {
  const ParkPalAdminColors._();

  static const background = Color(0xFF07090F);
  static const panel = Color(0xFF0D111C);
  static const panelTwo = Color(0xFF111827);
  static const glass = Color(0x1AFFFFFF);
  static const glassBorder = Color(0x33FFFFFF);
  static const text = Color(0xFFF7FAFF);
  static const muted = Color(0xFF9AA4B2);
  static const blue = Color(0xFF3B82F6);
  static const cyan = Color(0xFF36D4FF);
  static const emerald = Color(0xFF22C55E);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);
}

ThemeData buildParkPalAdminTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: ParkPalAdminColors.background,
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: ParkPalAdminColors.text,
      displayColor: ParkPalAdminColors.text,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: ParkPalAdminColors.background,
      foregroundColor: ParkPalAdminColors.text,
      elevation: 0,
      titleTextStyle: GoogleFonts.dmSerifDisplay(
        color: ParkPalAdminColors.text,
        fontSize: 28,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ParkPalAdminColors.glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ParkPalAdminColors.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ParkPalAdminColors.cyan),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ParkPalAdminColors.blue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
  );
}

TextStyle adminHeading({double size = 32}) {
  return GoogleFonts.dmSerifDisplay(
    color: ParkPalAdminColors.text,
    fontSize: size,
    height: 1,
  );
}

TextStyle adminBody({
  Color color = ParkPalAdminColors.text,
  FontWeight weight = FontWeight.w500,
  double size = 14,
}) {
  return GoogleFonts.inter(color: color, fontWeight: weight, fontSize: size);
}

BoxDecoration adminGlassDecoration({double radius = 24}) {
  return BoxDecoration(
    color: ParkPalAdminColors.glass,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: ParkPalAdminColors.glassBorder),
    boxShadow: [
      BoxShadow(
        color: ParkPalAdminColors.blue.withValues(alpha: 0.08),
        blurRadius: 30,
        offset: const Offset(0, 18),
      ),
    ],
  );
}

LinearGradient adminIridescentGradient() {
  return const LinearGradient(
    colors: [
      ParkPalAdminColors.blue,
      ParkPalAdminColors.cyan,
      ParkPalAdminColors.emerald,
    ],
  );
}
