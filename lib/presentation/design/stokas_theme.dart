import 'package:flutter/material.dart';

import 'stokas_tokens.dart';

/// Tema Material 3 Stokas. Warna hanya dari [StokasColors], tipe dari [StokasType].
abstract final class StokasTheme {
  static final light = build(StokasColors.light, Brightness.light);
  static final dark = build(StokasColors.dark, Brightness.dark);

  static TextTheme textTheme(StokasColors c) => TextTheme(
        displayLarge: StokasType.displayXl,
        displayMedium: StokasType.displayL,
        displaySmall: StokasType.headline,
        headlineLarge: StokasType.displayL,
        headlineMedium: StokasType.headline,
        headlineSmall: StokasType.titleLg,
        titleLarge: StokasType.titleLg,
        titleMedium: StokasType.title,
        titleSmall: StokasType.title,
        bodyLarge: StokasType.bodyLg,
        bodyMedium: StokasType.body,
        bodySmall: StokasType.caption,
        labelLarge: StokasType.title,
        labelMedium: StokasType.label,
        labelSmall: StokasType.label,
      ).apply(bodyColor: c.ink, displayColor: c.ink);

  static ColorScheme colorScheme(StokasColors c, Brightness brightness) => ColorScheme(
        brightness: brightness,
        primary: c.primary,
        onPrimary: c.onPrimary,
        primaryContainer: c.primaryHover,
        onPrimaryContainer: c.onPrimary,
        secondary: c.stock,
        onSecondary: c.onStock,
        tertiary: c.cash,
        onTertiary: c.onCash,
        error: c.negative,
        // on-negative tidak ada di token: teks di atas negative memakai latar terkontras.
        onError: brightness == Brightness.light ? c.surface : c.canvas,
        errorContainer: c.negativeSoft,
        onErrorContainer: c.negative,
        surface: c.surface,
        onSurface: c.ink,
        onSurfaceVariant: c.inkMuted,
        surfaceContainerLowest: c.surface,
        surfaceContainerLow: c.surface,
        surfaceContainer: c.surface,
        surfaceContainerHigh: c.surfaceSunken,
        surfaceContainerHighest: c.surfaceSunken,
        outline: c.lineStrong,
        outlineVariant: c.line,
        inverseSurface: c.ink,
        onInverseSurface: c.canvas,
        inversePrimary: c.primaryHover,
        shadow: c.ink,
        scrim: c.ink,
        surfaceTint: Colors.transparent,
      );

  static ThemeData build(StokasColors c, Brightness brightness) {
    final scheme = colorScheme(c, brightness);
    final text = textTheme(c);
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(StokasRadius.md));
    const minTap = Size(StokasSpace.tapMin, StokasSpace.tapMin);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(StokasRadius.md),
      borderSide: BorderSide(color: c.lineStrong),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [c],
      fontFamily: StokasType.sans,
      textTheme: text,
      primaryColor: c.primary,
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      dividerColor: c.line,
      focusColor: c.focus.withValues(alpha: 0.12),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: StokasType.titleLg.copyWith(color: c.onPrimary),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: StokasSpace.s1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StokasRadius.lg),
          side: BorderSide(color: c.line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StokasRadius.lg)),
        titleTextStyle: StokasType.titleLg.copyWith(color: c.ink),
        contentTextStyle: StokasType.body.copyWith(color: c.ink),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(StokasRadius.lg))),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StokasRadius.md)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.inkMuted,
        textColor: c.ink,
        minVerticalPadding: StokasSpace.s2,
      ),
      iconTheme: IconThemeData(color: c.ink),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        labelStyle: StokasType.body.copyWith(color: c.inkMuted),
        hintStyle: StokasType.body.copyWith(color: c.inkMuted),
        helperStyle: StokasType.caption.copyWith(color: c.inkMuted),
        errorStyle: StokasType.caption.copyWith(color: c.negative),
        prefixIconColor: c.inkMuted,
        suffixIconColor: c.inkMuted,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.focus, width: 2)),
        errorBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.negative)),
        focusedErrorBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.negative, width: 2)),
        disabledBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.line)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.surfaceSunken,
          disabledForegroundColor: c.inkMuted,
          minimumSize: minTap,
          elevation: 0,
          shape: buttonShape,
          textStyle: StokasType.title,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.surfaceSunken,
          disabledForegroundColor: c.inkMuted,
          minimumSize: minTap,
          shape: buttonShape,
          textStyle: StokasType.title,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          backgroundColor: c.surface,
          side: BorderSide(color: c.lineStrong),
          minimumSize: minTap,
          shape: buttonShape,
          textStyle: StokasType.title,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: minTap,
          shape: buttonShape,
          textStyle: StokasType.title,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: minTap)),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: StokasType.body.copyWith(color: c.canvas),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
    );
  }
}
