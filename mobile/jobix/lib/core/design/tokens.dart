import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// DESIGN.md only. Ranged radii and typography intentionally remain unresolved.
abstract final class TokensV0 {
  static const version = 'tokens_v0';
  static const fontFamily = String.fromEnvironment('APPROVED_FONT_FAMILY');
  static const navy = Color(0xFF0F172A);
  static const deepBlue = Color(0xFF1E3A8A);
  static const primary = Color(0xFF2563EB);
  static const primaryHover = Color(0xFF3B82F6);
  static const background = Color(0xFFFFFFFF);
  static const secondarySurface = Color(0xFFF8FAFC);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF64748B);
  static const disabled = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const divider = Color(0xFFCBD5E1);
  static const success = Color(0xFF22C55E);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF0EA5E9);
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space20 = 20.0;
  static const space24 = 24.0;
  static const space32 = 32.0;
  static const space40 = 40.0;
  static const space48 = 48.0;
  static const chipRadius = 8.0;
}

ThemeData foundationTheme() {
  const scheme = ColorScheme.light(
    primary: TokensV0.primary,
    onPrimary: TokensV0.background,
    primaryContainer: TokensV0.secondarySurface,
    onPrimaryContainer: TokensV0.deepBlue,
    secondary: TokensV0.deepBlue,
    onSecondary: TokensV0.background,
    secondaryContainer: TokensV0.secondarySurface,
    onSecondaryContainer: TokensV0.textPrimary,
    tertiary: TokensV0.info,
    onTertiary: TokensV0.textPrimary,
    tertiaryContainer: TokensV0.secondarySurface,
    onTertiaryContainer: TokensV0.textPrimary,
    surface: TokensV0.background,
    onSurface: TokensV0.textPrimary,
    onSurfaceVariant: TokensV0.textSecondary,
    surfaceContainerLowest: TokensV0.background,
    surfaceContainerLow: TokensV0.secondarySurface,
    surfaceContainer: TokensV0.secondarySurface,
    surfaceContainerHigh: TokensV0.secondarySurface,
    surfaceContainerHighest: TokensV0.secondarySurface,
    error: TokensV0.error,
    onError: TokensV0.background,
    errorContainer: TokensV0.secondarySurface,
    onErrorContainer: TokensV0.error,
    outline: TokensV0.border,
    outlineVariant: TokensV0.divider,
    inverseSurface: TokensV0.navy,
    onInverseSurface: TokensV0.background,
    inversePrimary: TokensV0.primaryHover,
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
  );
}

final themeProvider = Provider<ThemeData>((ref) => foundationTheme());
