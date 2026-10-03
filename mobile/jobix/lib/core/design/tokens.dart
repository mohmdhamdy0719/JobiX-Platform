import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Jobix visual foundation. Keep the V0 names stable for existing consumers.
abstract final class TokensV0 {
  static const version = 'tokens_v0';
  static const fontFamily = String.fromEnvironment(
    'APPROVED_FONT_FAMILY',
    defaultValue: 'Inter',
  );
  static const arabicFontFamily = 'Noto Sans Arabic';
  static const navy = Color(0xFF14243A);
  static const deepBlue = Color(0xFF203F75);
  static const primary = Color(0xFF2563EB);
  static const primaryHover = Color(0xFF3B82F6);
  static const background = Color(0xFFFAFBFD);
  static const canvas = Color(0xFFFAFBFD);
  static const surfaceCard = Color(0xFFFFFFFF);
  static const onPrimary = Color(0xFFFFFFFF);
  static const transparent = Color(0x00000000);
  static const secondarySurface = Color(0xFFF5F7FA);
  static const surfaceContainerLow = Color(0xFFEEF3FB);
  static const surfaceContainer = Color(0xFFE5EBF3);
  static const surfaceContainerHigh = Color(0xFFD8E1ED);
  static const surfaceVariant = Color(0xFFCCD7E4);
  static const onSurface = Color(0xFF14243A);
  static const textPrimary = Color(0xFF1C2B40);
  static const textSecondary = Color(0xFF5F6F83);
  static const disabled = Color(0xFF78879A);
  static const border = Color(0xFFDCE3EB);
  static const divider = Color(0xFFC9D3DF);
  static const success = Color(0xFF247A55);
  static const error = Color(0xFFB42332);
  static const errorContainer = Color(0xFFFCE8E9);
  static const onErrorContainer = Color(0xFF7A1722);
  static const warning = Color(0xFF98621B);
  static const info = Color(0xFF2B6F9F);
  static const inverseOnSurface = Color(0xFFF3F6FA);
  static const inversePrimary = Color(0xFFB7CCFF);
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
  static const pageGutter = 20.0;
  static const tabletGutter = 28.0;
  static const contentMaxWidth = 560.0;
  static const chipRadius = 8.0;
  static const controlRadius = 10.0;
  static const cardRadius = 12.0;
  static const panelRadius = 14.0;
  static const pillRadius = 999.0;
  static const touchTarget = 48.0;
  static const actionHeight = 52.0;
  static const iconSize = 20.0;
  static const controlBorderWidth = 1.0;
  static const selectedBorderWidth = 1.5;
  static const motionFeedback = 170;
  static const motionContent = 200;
  static const motionNavigation = 220;
  static const progressHeight = 3.0;
  static const loadingWidth = 180.0;
  static const splashMarkSize = 96.0;
  static const displayMobileSize = 30.0;
  static const displaySize = 36.0;
  static const headlineLargeSize = 28.0;
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

ThemeData foundationTheme({String? languageCode}) {
  final isArabic = languageCode == 'ar';
  final family = isArabic ? TokensV0.arabicFontFamily : TokensV0.fontFamily;
  final bodyHeight = isArabic ? 1.7 : 1.5;
  final headingHeight = isArabic ? 1.48 : 1.28;
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
  final baseText =
      TextTheme(
        displayLarge: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: TokensV0.navy,
        ).copyWith(height: headingHeight, letterSpacing: isArabic ? 0 : -0.8),
        displayMedium: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: TokensV0.navy,
        ).copyWith(height: headingHeight, letterSpacing: isArabic ? 0 : -0.6),
        headlineLarge: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: TokensV0.navy,
        ).copyWith(height: headingHeight, letterSpacing: isArabic ? 0 : -0.55),
        headlineMedium: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: TokensV0.navy,
        ).copyWith(height: headingHeight),
        headlineSmall: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: TokensV0.navy,
        ).copyWith(height: headingHeight),
        bodyLarge: const TextStyle(
          fontSize: 16,
          color: TokensV0.textSecondary,
        ).copyWith(height: bodyHeight),
        bodyMedium: const TextStyle(
          fontSize: 15,
          color: TokensV0.textPrimary,
        ).copyWith(height: bodyHeight),
        bodySmall: const TextStyle(
          fontSize: 13,
          color: TokensV0.textSecondary,
        ).copyWith(height: bodyHeight),
        labelLarge: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: TokensV0.textPrimary,
        ).copyWith(height: bodyHeight),
        labelMedium: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: TokensV0.textPrimary,
        ).copyWith(height: bodyHeight),
        labelSmall: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: TokensV0.textSecondary,
        ).copyWith(height: bodyHeight),
      ).apply(
        fontFamily: family,
        fontFamilyFallback: const [
          TokensV0.fontFamily,
          TokensV0.arabicFontFamily,
        ],
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: TokensV0.background,
    fontFamily: family.isEmpty ? null : family,
    fontFamilyFallback: const [TokensV0.fontFamily, TokensV0.arabicFontFamily],
    dividerColor: TokensV0.divider,
    textTheme: baseText,
    appBarTheme: const AppBarTheme(
      backgroundColor: TokensV0.canvas,
      foregroundColor: TokensV0.navy,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: TokensV0.surfaceCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: TokensV0.border),
        borderRadius: BorderRadius.circular(TokensV0.cardRadius),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TokensV0.primary,
        foregroundColor: TokensV0.onPrimary,
        disabledBackgroundColor: TokensV0.surfaceContainer,
        disabledForegroundColor: TokensV0.textSecondary,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TokensV0.controlRadius),
        ),
        textStyle: TextStyle(
          fontFamily: family,
          fontFamilyFallback: const [
            TokensV0.fontFamily,
            TokensV0.arabicFontFamily,
          ],
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TokensV0.deepBlue,
        minimumSize: const Size.fromHeight(50),
        side: const BorderSide(color: TokensV0.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TokensV0.controlRadius),
        ),
        textStyle: TextStyle(
          fontFamily: family,
          fontFamilyFallback: const [
            TokensV0.fontFamily,
            TokensV0.arabicFontFamily,
          ],
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TokensV0.deepBlue,
        minimumSize: const Size(48, 48),
        textStyle: TextStyle(
          fontFamily: family,
          fontFamilyFallback: const [
            TokensV0.fontFamily,
            TokensV0.arabicFontFamily,
          ],
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TokensV0.surfaceCard,
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      hintStyle: const TextStyle(color: TokensV0.disabled),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TokensV0.controlRadius),
        borderSide: const BorderSide(color: TokensV0.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TokensV0.controlRadius),
        borderSide: const BorderSide(color: TokensV0.error, width: 1.5),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: JobixPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

class JobixPageTransitionsBuilder extends PageTransitionsBuilder {
  const JobixPageTransitionsBuilder();
  @override
  Duration get transitionDuration =>
      const Duration(milliseconds: TokensV0.motionNavigation);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return FadeTransition(
      opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
      child: child,
    );
  }
}

final themeProvider = Provider<ThemeData>((ref) => foundationTheme());

Duration motionDuration(BuildContext context, int milliseconds) =>
    MediaQuery.of(context).disableAnimations
    ? Duration.zero
    : Duration(milliseconds: milliseconds);
