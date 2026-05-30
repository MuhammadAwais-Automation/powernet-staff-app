import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const primaryColor = Color(0xFF071A33); // Deep Navy
const accentColor = Color(0xFFF5A623); // Vibrant Orange Accent
const cyanColor = Color(0xFF1DD7FF); // Stable Cyan
const successColor = Color(0xFF22C55E);
const warningColor = Color(0xFFF59E0B);
const dangerColor = Color(0xFFEF4444);

// Backward compatibility constants for existing files
const primary = primaryColor;
const success = successColor;
const warning = warningColor;
const danger = dangerColor;
const info = cyanColor;

// Soft background colors
const softOrangeBg = Color(0xFFFFF3DF);
const softCyanBg = Color(0xFFEAFBFF);
const softGreenBg = Color(0xFFECFDF3);
const softRedBg = Color(0xFFFFF1F2);

const _lightBg = Color(0xFFF7FAFD);
const _lightSurface = Color(0xFFFFFFFF);
const _lightSurfaceMuted = Color(0xFFEFF6FC);
const _lightBorder = Color(0xFFE3EBF3);
const _lightText = Color(0xFF071A33);
const _lightTextMuted = Color(0xFF718397);
const _lightTextSoft = Color(0xFF4B6076);
const _lightInput = Color(0xFFF3F8FC);

const _darkBg = Color(0xFF0A121D);
const _darkSurface = Color(0xFF0F1B2C);
const _darkSurfaceMuted = Color(0xFF14243B);
const _darkBorder = Color(0xFF1E324C);
const _darkText = Color(0xFFF0F5FA);
const _darkTextMuted = Color(0xFF8BA0B6);
const _darkTextSoft = Color(0xFFACBDCF);
const _darkInput = Color(0xFF112035);

class PnColors extends ThemeExtension<PnColors> {
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color textSoft;
  final Color input;
  final Color primary;
  final Color accent;
  final Color cyan;
  final Color success;
  final Color warning;
  final Color danger;
  final Color softOrange;
  final Color softCyan;
  final Color softGreen;
  final Color softRed;

  const PnColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.textSoft,
    required this.input,
    required this.primary,
    required this.accent,
    required this.cyan,
    required this.success,
    required this.warning,
    required this.danger,
    required this.softOrange,
    required this.softCyan,
    required this.softGreen,
    required this.softRed,
  });

  static const light = PnColors(
    background: _lightBg,
    surface: _lightSurface,
    surfaceMuted: _lightSurfaceMuted,
    border: _lightBorder,
    text: _lightText,
    textMuted: _lightTextMuted,
    textSoft: _lightTextSoft,
    input: _lightInput,
    primary: primaryColor,
    accent: accentColor,
    cyan: cyanColor,
    success: successColor,
    warning: warningColor,
    danger: dangerColor,
    softOrange: softOrangeBg,
    softCyan: softCyanBg,
    softGreen: softGreenBg,
    softRed: softRedBg,
  );

  static const dark = PnColors(
    background: _darkBg,
    surface: _darkSurface,
    surfaceMuted: _darkSurfaceMuted,
    border: _darkBorder,
    text: _darkText,
    textMuted: _darkTextMuted,
    textSoft: _darkTextSoft,
    input: _darkInput,
    primary: primaryColor,
    accent: accentColor,
    cyan: cyanColor,
    success: successColor,
    warning: warningColor,
    danger: dangerColor,
    softOrange: Color(0xFF2C2213),
    softCyan: Color(0xFF10272D),
    softGreen: Color(0xFF10281D),
    softRed: Color(0xFF2E1719),
  );

  @override
  PnColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? textSoft,
    Color? input,
    Color? primary,
    Color? accent,
    Color? cyan,
    Color? success,
    Color? warning,
    Color? danger,
    Color? softOrange,
    Color? softCyan,
    Color? softGreen,
    Color? softRed,
  }) {
    return PnColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textSoft: textSoft ?? this.textSoft,
      input: input ?? this.input,
      primary: primary ?? this.primary,
      accent: accent ?? this.accent,
      cyan: cyan ?? this.cyan,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      softOrange: softOrange ?? this.softOrange,
      softCyan: softCyan ?? this.softCyan,
      softGreen: softGreen ?? this.softGreen,
      softRed: softRed ?? this.softRed,
    );
  }

  @override
  PnColors lerp(PnColors? other, double t) {
    if (other == null) return this;
    return PnColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textSoft: Color.lerp(textSoft, other.textSoft, t)!,
      input: Color.lerp(input, other.input, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      cyan: Color.lerp(cyan, other.cyan, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      softOrange: Color.lerp(softOrange, other.softOrange, t)!,
      softCyan: Color.lerp(softCyan, other.softCyan, t)!,
      softGreen: Color.lerp(softGreen, other.softGreen, t)!,
      softRed: Color.lerp(softRed, other.softRed, t)!,
    );
  }
}

ThemeData buildLightTheme() => _buildTheme(Brightness.light);
ThemeData buildDarkTheme() => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final pn = isDark ? PnColors.dark : PnColors.light;

  // Custom display/body fonts using Manrope from Google Fonts
  final baseTextTheme = ThemeData(brightness: brightness).textTheme;
  final textTheme = GoogleFonts.manropeTextTheme(baseTextTheme).copyWith(
    titleLarge: GoogleFonts.manrope(
      textStyle: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: pn.text,
      ),
    ),
    titleMedium: GoogleFonts.manrope(
      textStyle: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: pn.text,
      ),
    ),
    bodyLarge: GoogleFonts.manrope(
      textStyle: baseTextTheme.bodyLarge?.copyWith(color: pn.textSoft),
    ),
    bodyMedium: GoogleFonts.manrope(
      textStyle: baseTextTheme.bodyMedium?.copyWith(color: pn.textSoft),
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: accentColor,
      brightness: brightness,
      surface: pn.surface,
    ),
    scaffoldBackgroundColor: pn.background,
    textTheme: textTheme,
    extensions: [pn],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: pn.text,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: pn.text,
      ),
    ),
    cardTheme: CardThemeData(
      color: pn.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: pn.border, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: pn.input,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: pn.border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: pn.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: cyanColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(
        color: pn.textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: pn.textMuted.withValues(alpha: 0.7),
        fontSize: 14,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentColor, // Orange background
        foregroundColor: primaryColor, // Navy Blue text
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: pn.text,
        side: BorderSide(color: pn.border, width: 1),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
        backgroundColor: pn.surface,
      ),
    ),
    dividerTheme: DividerThemeData(color: pn.border, space: 1, thickness: 1),
  );
}
