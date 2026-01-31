import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Deep Charcoal color palette for Dark Mode
class DarkPalette {
  static const Color background = Color(0xFF1A1C1E); // Deep Charcoal
  static const Color surface = Color(0xFF25282A); // Lighter Soft Gray
  static const Color surfaceVariant = Color(0xFF2C2C2E);
  static const Color textPrimary = Color(0xFFE1E3E5); // Off-white
  static const Color textSecondary = Color(0xFF9CA3AF); // Medium Gray
}

/// SoftColors ThemeExtension for brand-specific colors in both modes
@immutable
class SoftColorsExtension extends ThemeExtension<SoftColorsExtension> {
  final Color brandPrimary;
  final Color background;
  final Color surface;
  final Color bgLight;
  final Color textMain;
  final Color textSecondary;
  final Color border;
  final Color success;
  final Color warning;
  final Color error;

  const SoftColorsExtension({
    required this.brandPrimary,
    required this.background,
    required this.surface,
    required this.bgLight,
    required this.textMain,
    required this.textSecondary,
    required this.border,
    required this.success,
    required this.warning,
    required this.error,
  });

  /// Light mode colors
  static const SoftColorsExtension light = SoftColorsExtension(
    brandPrimary: Color(0xFF3C67AC),
    background: Color(0xFFF7F8FA),
    surface: Colors.white,
    bgLight: Color(0xFFF0F2F5),
    textMain: Color(0xFF1A1C1E),
    textSecondary: Color(0xFF6B7280),
    border: Color(0xFFE5E7EB),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
  );

  /// Dark mode colors with Deep Charcoal palette
  static const SoftColorsExtension dark = SoftColorsExtension(
    brandPrimary: Color(0xFF8EB5F5), // Desaturated 20% from Neon
    background: DarkPalette.background,
    surface: DarkPalette.surface,
    bgLight: DarkPalette.surfaceVariant,
    textMain: DarkPalette.textPrimary,
    textSecondary: DarkPalette.textSecondary,
    border: Color(0xFF3A3C3E),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFF87171),
  );

  @override
  SoftColorsExtension copyWith({
    Color? brandPrimary,
    Color? background,
    Color? surface,
    Color? bgLight,
    Color? textMain,
    Color? textSecondary,
    Color? border,
    Color? success,
    Color? warning,
    Color? error,
  }) {
    return SoftColorsExtension(
      brandPrimary: brandPrimary ?? this.brandPrimary,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      bgLight: bgLight ?? this.bgLight,
      textMain: textMain ?? this.textMain,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
    );
  }

  @override
  SoftColorsExtension lerp(SoftColorsExtension? other, double t) {
    if (other is! SoftColorsExtension) return this;
    return SoftColorsExtension(
      brandPrimary: Color.lerp(brandPrimary, other.brandPrimary, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      bgLight: Color.lerp(bgLight, other.bgLight, t)!,
      textMain: Color.lerp(textMain, other.textMain, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

class AppTheme {
  const AppTheme._();

  static const Color primary = Color(0xFF3C67AC);

  static final ThemeData lightTheme = FlexThemeData.light(
    colors: const FlexSchemeColor(
      primary: primary,
      primaryContainer: Color(0xFFD2E4FF),
      secondary: Color(0xFF535F70),
      secondaryContainer: Color(0xFFD7E3F7),
      tertiary: Color(0xFF6B5778),
      tertiaryContainer: Color(0xFFF2DAFF),
      appBarColor: primary,
      error: Color(0xFFBA1A1A),
    ),
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 7,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 10,
      blendOnColors: false,
      useM2StyleDividerInM3: true,
      alignedDropdown: true,
      useInputDecoratorThemeInDialogs: true,
      defaultRadius: 16.0,
      inputDecoratorRadius: 12.0,
      filledButtonRadius: 12.0,
      elevatedButtonRadius: 12.0,
      outlinedButtonRadius: 12.0,
      textButtonRadius: 12.0,
      cardRadius: 16.0,
      dialogRadius: 24.0,
      navigationBarBackgroundSchemeColor: SchemeColor.surface,
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    fontFamily: GoogleFonts.outfit().fontFamily,
  ).copyWith(extensions: [SoftColorsExtension.light]);

  static final ThemeData darkTheme =
      FlexThemeData.dark(
        colors: const FlexSchemeColor(
          primary: Color(0xFF7BA3E0), // Softer blue for dark mode
          primaryContainer: Color(0xFF3C67AC),
          secondary: Color(0xFFBBC7DB),
          secondaryContainer: Color(0xFF3B4858),
          tertiary: Color(0xFFD6BEE4),
          tertiaryContainer: Color(0xFF523F5F),
          error: Color(0xFFFFB4AB),
        ),
        scaffoldBackground: DarkPalette.background,
        surface: DarkPalette.surface,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 13,
        subThemesData: const FlexSubThemesData(
          filledButtonRadius: 12.0,
          elevatedButtonRadius: 12.0,
          outlinedButtonRadius: 12.0,
          textButtonRadius: 12.0,
          cardRadius: 16.0,
          dialogRadius: 24.0,
          navigationBarBackgroundSchemeColor: SchemeColor.surface,
          inputDecoratorRadius: 12.0,
        ),
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        useMaterial3: true,
        fontFamily: GoogleFonts.outfit().fontFamily,
      ).copyWith(
        scaffoldBackgroundColor: DarkPalette.background,
        cardColor: DarkPalette.surface,
        canvasColor: DarkPalette.surface,
        extensions: [SoftColorsExtension.dark],
      );
}

/// Extension method to access SoftColors from context
extension SoftColorsContext on BuildContext {
  SoftColorsExtension get softColors =>
      Theme.of(this).extension<SoftColorsExtension>() ??
      SoftColorsExtension.light;
}
