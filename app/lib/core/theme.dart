import 'package:flutter/material.dart';

/// ألوان التطبيق مستوحاة من غلاف الكتاب: أخضر المسجد النبوي والذهبي والعنابي.
class AppColors {
  AppColors._();

  static const Color green = Color(0xFF0B3B32);
  static const Color greenLight = Color(0xFF14574A);
  static const Color greenSoft = Color(0xFF1E6B5B);
  static const Color gold = Color(0xFFC9A227);
  static const Color goldLight = Color(0xFFE3C566);
  static const Color maroon = Color(0xFF6B1F3A);
  static const Color cream = Color(0xFFF7F3E8);
  static const Color creamDeep = Color(0xFFEFE8D8);
  static const Color ink = Color(0xFF1C2421);
  static const Color darkBg = Color(0xFF0A1512);
  static const Color darkSurface = Color(0xFF122019);
}

class AppTheme {
  AppTheme._();

  static const String displayFont = 'Amiri';
  static const String bodyFont = 'Tajawal';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? AppColors.goldLight : AppColors.green,
      onPrimary: isDark ? AppColors.darkBg : Colors.white,
      secondary: AppColors.gold,
      onSecondary: AppColors.green,
      surface: isDark ? AppColors.darkSurface : AppColors.cream,
      onSurface: isDark ? const Color(0xFFE8E3D5) : AppColors.ink,
      surfaceContainerHighest:
          isDark ? const Color(0xFF1A2B22) : AppColors.creamDeep,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? AppColors.darkBg : AppColors.cream,
      fontFamily: bodyFont,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontFamily: displayFont,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.82),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isDark
                ? AppColors.gold.withValues(alpha: 0.18)
                : AppColors.green.withValues(alpha: 0.10),
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.gold,
        inactiveTrackColor: scheme.onSurface.withValues(alpha: 0.18),
        thumbColor: AppColors.gold,
        overlayColor: AppColors.gold.withValues(alpha: 0.18),
        trackHeight: 4,
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.25)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.85),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.primary.withValues(alpha: 0.18),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : Colors.white.withValues(alpha: 0.95),
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.gold.withValues(alpha: 0.22),
        elevation: 8,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: bodyFont,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: TextStyle(
          fontFamily: displayFont,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        headlineMedium: TextStyle(
          fontFamily: displayFont,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        titleLarge: TextStyle(
          fontFamily: displayFont,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        titleMedium: TextStyle(
          fontFamily: bodyFont,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
        bodyMedium: TextStyle(
          fontFamily: bodyFont,
          height: 1.7,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}
