import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
      // useTextTheme: true, // Deprecated
      useM2StyleDividerInM3: true,
      alignedDropdown: true,
      useInputDecoratorThemeInDialogs: true,
      defaultRadius: 16.0, // Matching 16px radius from spec
      inputDecoratorRadius: 12.0, // Matching 12px for inputs
      filledButtonRadius: 12.0,
      elevatedButtonRadius: 12.0,
      outlinedButtonRadius: 12.0,
      textButtonRadius: 12.0,
      cardRadius: 16.0,
      dialogRadius: 24.0,
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    fontFamily: GoogleFonts.outfit().fontFamily,
  );

  static final ThemeData darkTheme = FlexThemeData.dark(
    colors: const FlexSchemeColor(
      primary: Color(0xFF9EC1FF), // Lighter version for dark mode
      primaryContainer: Color(0xFF3C67AC), // Brand color as container
      secondary: Color(0xFFBBC7DB),
      secondaryContainer: Color(0xFF3B4858),
      tertiary: Color(0xFFD6BEE4),
      tertiaryContainer: Color(0xFF523F5F),
      error: Color(0xFFFFB4AB),
    ),
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 13,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 20,
      // useTextTheme: true, // Deprecated
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
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    fontFamily: GoogleFonts.outfit().fontFamily,
  );
}
