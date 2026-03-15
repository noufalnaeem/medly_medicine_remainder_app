import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central design system for Medly.
/// All screens pull constants from here for visual consistency.
class AppTheme {
  AppTheme._();

  // ─── Brand palettes ─────────────────────────────────────────────────────────

  // Patient — deep indigo
  static const Color patientPrimary   = Color(0xFF3949AB);
  static const Color patientPrimaryDk = Color(0xFF1A237E);
  static const Color patientAccent    = Color(0xFF5C6BC0);
  static const Color patientLight     = Color(0xFFE8EAF6);

  // Caregiver — teal / emerald
  static const Color caregiverPrimary   = Color(0xFF00695C);
  static const Color caregiverPrimaryDk = Color(0xFF004D40);
  static const Color caregiverAccent    = Color(0xFF00897B);
  static const Color caregiverLight     = Color(0xFFE0F2F1);

  // Semantic colours
  static const Color successGreen = Color(0xFF2E7D32);
  static const Color warningOrange = Color(0xFFE65100);
  static const Color dangerRed    = Color(0xFFC62828);

  // Background / surface
  static const Color background  = Color(0xFFF0F4FF);
  static const Color surface     = Colors.white;
  static const Color surfaceAlt  = Color(0xFFF5F7FF);

  // ─── Text colours ────────────────────────────────────────────────────────────

  static const Color textPrimary   = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint      = Color(0xFFB0BEC5);

  // ─── Gradients ───────────────────────────────────────────────────────────────

  static const LinearGradient patientGradient = LinearGradient(
    colors: [Color(0xFF1A237E), Color(0xFF3949AB), Color(0xFF5C6BC0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient patientGradientV = LinearGradient(
    colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient caregiverGradient = LinearGradient(
    colors: [Color(0xFF004D40), Color(0xFF00695C), Color(0xFF00897B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient caregiverGradientV = LinearGradient(
    colors: [Color(0xFF004D40), Color(0xFF00695C)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFB71C1C), Color(0xFFC62828), Color(0xFFE53935)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Typography ──────────────────────────────────────────────────────────────

  static TextStyle headline1(Color color) => GoogleFonts.nunito(
    fontSize: 32, fontWeight: FontWeight.w800, color: color, height: 1.2);

  static TextStyle headline2(Color color) => GoogleFonts.nunito(
    fontSize: 24, fontWeight: FontWeight.w700, color: color);

  static TextStyle headline3(Color color) => GoogleFonts.nunito(
    fontSize: 20, fontWeight: FontWeight.w700, color: color);

  static TextStyle title(Color color) => GoogleFonts.nunito(
    fontSize: 17, fontWeight: FontWeight.w700, color: color);

  static TextStyle body(Color color) => GoogleFonts.nunito(
    fontSize: 14, fontWeight: FontWeight.w500, color: color);

  static TextStyle caption(Color color) => GoogleFonts.nunito(
    fontSize: 12, fontWeight: FontWeight.w500, color: color);

  static TextStyle label(Color color) => GoogleFonts.nunito(
    fontSize: 13, fontWeight: FontWeight.w600, color: color);

  // ─── Shadows ─────────────────────────────────────────────────────────────────

  static List<BoxShadow> softShadow(Color color, {double opacity = 0.15}) => [
    BoxShadow(
      color: color.withOpacity(opacity),
      blurRadius: 16,
      offset: const Offset(0, 6),
    )
  ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0x183949AB),
      blurRadius: 12,
      offset: const Offset(0, 4),
    )
  ];

  // ─── Decorations ─────────────────────────────────────────────────────────────

  static BoxDecoration cardDecoration({
    double radius = 16,
    Color? color,
    List<BoxShadow>? shadow,
  }) =>
      BoxDecoration(
        color: color ?? surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow ?? cardShadow,
      );

  static BoxDecoration gradientDecoration(
    Gradient gradient, {
    double radius = 20,
  }) =>
      BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: (gradient as LinearGradient).colors.first.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      );

  // ─── Input decoration ────────────────────────────────────────────────────────

  static InputDecoration inputDecoration({
    required String label,
    required IconData icon,
    Color primaryColor = patientPrimary,
    Widget? suffixIcon,
    String? helperText,
  }) =>
      InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunito(
          color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
        hintStyle: GoogleFonts.nunito(color: textHint, fontSize: 14),
        prefixIcon: Icon(icon, color: primaryColor, size: 22),
        suffixIcon: suffixIcon,
        helperText: helperText,
        helperStyle: GoogleFonts.nunito(color: textHint, fontSize: 11),
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryColor.withOpacity(0.15), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      );

  // ─── Button styles ───────────────────────────────────────────────────────────

  static ButtonStyle filledButton({
    Color? color,
    double radius = 14,
    EdgeInsets padding = const EdgeInsets.symmetric(vertical: 16),
  }) =>
      ElevatedButton.styleFrom(
        backgroundColor: color ?? patientPrimary,
        foregroundColor: Colors.white,
        padding: padding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        elevation: 0,
      );

  // ─── Global ThemeData ────────────────────────────────────────────────────────

  static ThemeData buildTheme() {
    const primary = patientPrimary;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.nunitoTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: surface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          textStyle: GoogleFonts.nunito(
            fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: GoogleFonts.nunito(fontSize: 14),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: patientPrimary,
        foregroundColor: Colors.white,
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  /// Pill-shaped status badge
  static Widget statusBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(
      label,
      style: GoogleFonts.nunito(
        fontSize: 11, fontWeight: FontWeight.w700, color: color),
    ),
  );

  /// Gradient button that wraps any child
  static Widget gradientButton({
    required VoidCallback? onPressed,
    required Widget child,
    Gradient gradient = patientGradient,
    double height = 54,
    double radius = 14,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: onPressed != null ? gradient : null,
        color: onPressed == null ? Colors.grey[300] : null,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: onPressed != null
            ? [BoxShadow(
                color: (gradient as LinearGradient).colors.first.withOpacity(0.4),
                blurRadius: 12, offset: const Offset(0, 4))]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(radius),
          child: Center(child: child),
        ),
      ),
    );
  }
}
