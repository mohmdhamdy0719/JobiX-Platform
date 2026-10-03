import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared visual foundation extracted from the approved JobiX mobile screens.
abstract final class TokensV0 {
  static const version = 'tokens_v0';
  static const fontFamily = String.fromEnvironment(
    'APPROVED_FONT_FAMILY',
    defaultValue: 'Inter',
  );
  static const navy = Color(0xFF0F172A);
  static const deepBlue = Color(0xFF1E3A8A);
  static const primary = Color(0xFF2563EB);
  static const primaryHover = Color(0xFF3B82F6);
  static const background = Color(0xFFF8F9FF);
  static const canvas = Color(0xFFF8F9FF);
  static const surfaceCard = Color(0xFFFFFFFF);
  static const onPrimary = Color(0xFFFFFFFF);
  static const transparent = Color(0x00000000);
  static const secondarySurface = Color(0xFFF8FAFC);
  static const surfaceContainerLow = Color(0xFFEFF4FF);
  static const surfaceContainer = Color(0xFFE5EEFF);
  static const surfaceContainerHigh = Color(0xFFDCE9FF);
  static const surfaceVariant = Color(0xFFD3E4FE);
  static const onSurface = Color(0xFF0B1C30);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF64748B);
  static const disabled = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const divider = Color(0xFFCBD5E1);
  static const success = Color(0xFF22C55E);
  static const error = Color(0xFFEF4444);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF0EA5E9);
  static const inverseOnSurface = Color(0xFFEAF1FF);
  static const inversePrimary = Color(0xFFB4C5FF);
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space20 = 20.0;
  static const space24 = 24.0;
  static const space32 = 32.0;
  static const space40 = 40.0;
  static const space48 = 48.0;
  static const space56 = 56.0;
  static const space64 = 64.0;
  static const pageGutter = 16.0;
  static const tabletGutter = 24.0;
  static const contentMaxWidth = 560.0;

  // Radius scale follows the references' 8px controls, 12px cards and pills.
  static const chipRadius = 8.0;
  static const controlRadius = 12.0;
  static const cardRadius = 12.0;
  static const panelRadius = 16.0;
  static const pillRadius = 999.0;

  // Inter is supplied by the host app; Arabic remains on the platform fallback.
  static const displayMobileSize = 30.0;
  static const displaySize = 36.0;
  static const headlineLargeSize = 30.0;
  static const headlineMobileSize = 26.0;
  static const headlineMediumSize = 22.0;
  static const headlineSmallSize = 18.0;
  static const bodyLargeSize = 16.0;
  static const bodyMediumSize = 15.0;
  static const bodySmallSize = 13.0;
  static const labelLargeSize = 16.0;
  static const labelMediumSize = 14.0;
  static const labelSmallSize = 12.0;
}

ThemeData foundationTheme() {
  const scheme = ColorScheme.light(
    primary: TokensV0.primary,
    onPrimary: TokensV0.onPrimary,
    primaryContainer: TokensV0.primary,
    onPrimaryContainer: TokensV0.onPrimary,
    secondary: TokensV0.deepBlue,
    onSecondary: TokensV0.onPrimary,
    secondaryContainer: TokensV0.surfaceContainerLow,
    onSecondaryContainer: TokensV0.deepBlue,
    tertiary: TokensV0.info,
    onTertiary: TokensV0.onPrimary,
    tertiaryContainer: TokensV0.surfaceContainerLow,
    onTertiaryContainer: TokensV0.onSurface,
    surface: TokensV0.canvas,
    onSurface: TokensV0.onSurface,
    onSurfaceVariant: TokensV0.textSecondary,
    surfaceContainerLowest: TokensV0.surfaceCard,
    surfaceContainerLow: TokensV0.surfaceContainerLow,
    surfaceContainer: TokensV0.surfaceContainer,
    surfaceContainerHigh: TokensV0.surfaceContainerHigh,
    surfaceContainerHighest: TokensV0.surfaceVariant,
    error: TokensV0.error,
    onError: TokensV0.onPrimary,
    errorContainer: TokensV0.errorContainer,
    onErrorContainer: TokensV0.onErrorContainer,
    outline: TokensV0.border,
    outlineVariant: TokensV0.divider,
    inverseSurface: TokensV0.navy,
    onInverseSurface: TokensV0.inverseOnSurface,
    inversePrimary: TokensV0.inversePrimary,
    surfaceTint: TokensV0.primary,
    shadow: TokensV0.navy,
    scrim: TokensV0.navy,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: TokensV0.background,
    fontFamily: TokensV0.fontFamily.isEmpty ? null : TokensV0.fontFamily,
    dividerColor: TokensV0.divider,
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: TokensV0.displaySize,
        height: 44 / 36,
        fontWeight: FontWeight.w700,
        color: TokensV0.navy,
      ),
      displayMedium: TextStyle(
        fontSize: TokensV0.displayMobileSize,
        height: 38 / 30,
        fontWeight: FontWeight.w700,
        color: TokensV0.navy,
      ),
      headlineLarge: TextStyle(
        fontSize: TokensV0.headlineLargeSize,
        height: 38 / 30,
        fontWeight: FontWeight.w700,
        color: TokensV0.navy,
      ),
      headlineMedium: TextStyle(
        fontSize: TokensV0.headlineMediumSize,
        height: 30 / 22,
        fontWeight: FontWeight.w600,
        color: TokensV0.navy,
      ),
      headlineSmall: TextStyle(
        fontSize: TokensV0.headlineSmallSize,
        height: 26 / 18,
        fontWeight: FontWeight.w600,
        color: TokensV0.navy,
      ),
      bodyLarge: TextStyle(
        fontSize: TokensV0.bodyLargeSize,
        height: 24 / 16,
        color: TokensV0.textSecondary,
      ),
      bodyMedium: TextStyle(
        fontSize: TokensV0.bodyMediumSize,
        height: 22 / 15,
        color: TokensV0.textPrimary,
      ),
      bodySmall: TextStyle(
        fontSize: TokensV0.bodySmallSize,
        height: 18 / 13,
        color: TokensV0.textSecondary,
      ),
      labelLarge: TextStyle(
        fontSize: TokensV0.labelLargeSize,
        height: 22 / 16,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(
        fontSize: TokensV0.labelMediumSize,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: TextStyle(
        fontSize: TokensV0.labelSmallSize,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: TokensV0.canvas,
      foregroundColor: TokensV0.navy,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: TokensV0.surfaceCard,
      elevation: 1,
      shadowColor: TokensV0.navy.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TokensV0.cardRadius),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TokensV0.primary,
        foregroundColor: TokensV0.onPrimary,
        disabledBackgroundColor: TokensV0.surfaceContainer,
        disabledForegroundColor: TokensV0.disabled,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TokensV0.controlRadius),
        ),
        textStyle: const TextStyle(
          fontFamily: TokensV0.fontFamily,
          fontSize: TokensV0.labelLargeSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TokensV0.secondarySurface,
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: TokensV0.space16,
        vertical: TokensV0.space16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TokensV0.controlRadius),
        borderSide: const BorderSide(color: TokensV0.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TokensV0.controlRadius),
        borderSide: const BorderSide(color: TokensV0.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TokensV0.controlRadius),
        borderSide: const BorderSide(color: TokensV0.primary, width: 1.5),
      ),
    ),
  );
}

final themeProvider = Provider<ThemeData>((ref) => foundationTheme());
