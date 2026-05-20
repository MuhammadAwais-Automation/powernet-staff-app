import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const primary = Color(0xFFF05A2B);
const success = Color(0xFF16A34A);
const warning = Color(0xFFF59E0B);
const danger = Color(0xFFDC2626);
const info = Color(0xFF2563EB);

const _lightBg = Color(0xFFFFFFFF);
const _lightSurfaceMuted = Color(0xFFF6F7F9);
const _lightBorder = Color(0xFFE6E8EC);
const _lightText = Color(0xFF111827);
const _lightTextMuted = Color(0xFF6B7280);

const _darkBg = Color(0xFF0F1115);
const _darkSurfaceMuted = Color(0xFF171A20);
const _darkBorder = Color(0xFF262A33);
const _darkText = Color(0xFFF9FAFB);
const _darkTextMuted = Color(0xFF9CA3AF);

class PnColors extends ThemeExtension<PnColors> {
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  const PnColors({
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  static const light = PnColors(
    surface: _lightBg,
    surfaceMuted: _lightSurfaceMuted,
    border: _lightBorder,
    text: _lightText,
    textMuted: _lightTextMuted,
    success: Color(0xFF16A34A),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFDC2626),
    info: Color(0xFF2563EB),
  );

  static const dark = PnColors(
    surface: _darkBg,
    surfaceMuted: _darkSurfaceMuted,
    border: _darkBorder,
    text: _darkText,
    textMuted: _darkTextMuted,
    success: Color(0xFF16A34A),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFDC2626),
    info: Color(0xFF2563EB),
  );

  @override
  PnColors copyWith({
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
  }) {
    return PnColors(
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
    );
  }

  @override
  PnColors lerp(PnColors? other, double t) {
    if (other == null) return this;
    return PnColors(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

ThemeData buildLightTheme() => _buildTheme(Brightness.light);
ThemeData buildDarkTheme() => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final pn = isDark ? PnColors.dark : PnColors.light;
  final textTheme = GoogleFonts.interTextTheme(
    ThemeData(brightness: brightness).textTheme,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      brightness: brightness,
      surface: pn.surface,
    ),
    scaffoldBackgroundColor: pn.surface,
    textTheme: textTheme,
    extensions: [pn],
    appBarTheme: AppBarTheme(
      backgroundColor: pn.surface,
      foregroundColor: pn.text,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: pn.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: pn.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: pn.surfaceMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: pn.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: pn.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: pn.border,
      space: 1,
      thickness: 1,
    ),
  );
}
