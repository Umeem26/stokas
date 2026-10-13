import 'package:flutter/material.dart';

// Token Stokas, disalin dari docs/brand/tokens.json. Satu-satunya tempat nilai hex
// warna boleh ditulis; widget mengambil warna lewat `context.stokas`.

/// Semua token warna Stokas (nama sama dengan tokens.json, ditulis camelCase).
@immutable
class StokasColors extends ThemeExtension<StokasColors> {
  final Color canvas;
  final Color surface;
  final Color surfaceSunken;
  final Color line;
  final Color lineStrong;
  final Color ink;
  final Color inkMuted;
  final Color primary;
  final Color primaryHover;
  final Color onPrimary;
  final Color stock;
  final Color onStock;
  final Color cash;
  final Color onCash;
  final Color cashDeep;
  final Color positive;
  final Color positiveSoft;
  final Color negative;
  final Color negativeSoft;
  final Color warning;
  final Color warningSoft;
  final Color focus;

  const StokasColors({
    required this.canvas,
    required this.surface,
    required this.surfaceSunken,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.inkMuted,
    required this.primary,
    required this.primaryHover,
    required this.onPrimary,
    required this.stock,
    required this.onStock,
    required this.cash,
    required this.onCash,
    required this.cashDeep,
    required this.positive,
    required this.positiveSoft,
    required this.negative,
    required this.negativeSoft,
    required this.warning,
    required this.warningSoft,
    required this.focus,
  });

  static const light = StokasColors(
    canvas: Color(0xFFF6F8FB),
    surface: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEBF0F7),
    line: Color(0xFFD5DDEA),
    lineStrong: Color(0xFF66758C),
    ink: Color(0xFF0F1B2D),
    inkMuted: Color(0xFF4A5568),
    primary: Color(0xFF17305C),
    primaryHover: Color(0xFF214278),
    onPrimary: Color(0xFFFFFFFF),
    stock: Color(0xFF0E7C7B),
    onStock: Color(0xFFFFFFFF),
    cash: Color(0xFFF2B33D),
    onCash: Color(0xFF0F1B2D),
    cashDeep: Color(0xFFB7791F),
    positive: Color(0xFF146C36),
    positiveSoft: Color(0xFFE3F4E9),
    negative: Color(0xFFB91C1C),
    negativeSoft: Color(0xFFFCE9E9),
    warning: Color(0xFF8A3B0B),
    warningSoft: Color(0xFFFDF0CF),
    focus: Color(0xFF1D4ED8),
  );

  static const dark = StokasColors(
    canvas: Color(0xFF0B1524),
    surface: Color(0xFF13233A),
    surfaceSunken: Color(0xFF0F1C2F),
    line: Color(0xFF2B405F),
    lineStrong: Color(0xFF7C92B3),
    ink: Color(0xFFE8EEF7),
    inkMuted: Color(0xFFA9B7CB),
    primary: Color(0xFF9DB8F0),
    primaryHover: Color(0xFFB8CBF4),
    onPrimary: Color(0xFF0B1524),
    stock: Color(0xFF2BB5B1),
    onStock: Color(0xFF0B1524),
    cash: Color(0xFFF2B33D),
    onCash: Color(0xFF0B1524),
    cashDeep: Color(0xFFF2B33D),
    positive: Color(0xFF4ADE80),
    positiveSoft: Color(0xFF10301F),
    negative: Color(0xFFFCA5A5),
    negativeSoft: Color(0xFF3B1A22),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0xFF3A2A0E),
    focus: Color(0xFF8DB4FF),
  );

  /// Semua token sebagai peta nama tokens.json -> warna (untuk tes & dokumentasi).
  Map<String, Color> get byName => {
        'canvas': canvas,
        'surface': surface,
        'surface-sunken': surfaceSunken,
        'line': line,
        'line-strong': lineStrong,
        'ink': ink,
        'ink-muted': inkMuted,
        'primary': primary,
        'primary-hover': primaryHover,
        'on-primary': onPrimary,
        'stock': stock,
        'on-stock': onStock,
        'cash': cash,
        'on-cash': onCash,
        'cash-deep': cashDeep,
        'positive': positive,
        'positive-soft': positiveSoft,
        'negative': negative,
        'negative-soft': negativeSoft,
        'warning': warning,
        'warning-soft': warningSoft,
        'focus': focus,
      };

  @override
  StokasColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceSunken,
    Color? line,
    Color? lineStrong,
    Color? ink,
    Color? inkMuted,
    Color? primary,
    Color? primaryHover,
    Color? onPrimary,
    Color? stock,
    Color? onStock,
    Color? cash,
    Color? onCash,
    Color? cashDeep,
    Color? positive,
    Color? positiveSoft,
    Color? negative,
    Color? negativeSoft,
    Color? warning,
    Color? warningSoft,
    Color? focus,
  }) {
    return StokasColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      primary: primary ?? this.primary,
      primaryHover: primaryHover ?? this.primaryHover,
      onPrimary: onPrimary ?? this.onPrimary,
      stock: stock ?? this.stock,
      onStock: onStock ?? this.onStock,
      cash: cash ?? this.cash,
      onCash: onCash ?? this.onCash,
      cashDeep: cashDeep ?? this.cashDeep,
      positive: positive ?? this.positive,
      positiveSoft: positiveSoft ?? this.positiveSoft,
      negative: negative ?? this.negative,
      negativeSoft: negativeSoft ?? this.negativeSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      focus: focus ?? this.focus,
    );
  }

  @override
  StokasColors lerp(ThemeExtension<StokasColors>? other, double t) {
    if (other is! StokasColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return StokasColors(
      canvas: l(canvas, other.canvas),
      surface: l(surface, other.surface),
      surfaceSunken: l(surfaceSunken, other.surfaceSunken),
      line: l(line, other.line),
      lineStrong: l(lineStrong, other.lineStrong),
      ink: l(ink, other.ink),
      inkMuted: l(inkMuted, other.inkMuted),
      primary: l(primary, other.primary),
      primaryHover: l(primaryHover, other.primaryHover),
      onPrimary: l(onPrimary, other.onPrimary),
      stock: l(stock, other.stock),
      onStock: l(onStock, other.onStock),
      cash: l(cash, other.cash),
      onCash: l(onCash, other.onCash),
      cashDeep: l(cashDeep, other.cashDeep),
      positive: l(positive, other.positive),
      positiveSoft: l(positiveSoft, other.positiveSoft),
      negative: l(negative, other.negative),
      negativeSoft: l(negativeSoft, other.negativeSoft),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      focus: l(focus, other.focus),
    );
  }
}

extension StokasThemeContext on BuildContext {
  /// Token warna Stokas tema aktif (terang bila tema belum memasang ekstensi).
  StokasColors get stokas => Theme.of(this).extension<StokasColors>() ?? StokasColors.light;
}

/// Jarak berkelipatan 4 (space-1 … space-8) dan area sentuh minimum.
abstract final class StokasSpace {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 24;
  static const double s6 = 32;
  static const double s8 = 48;

  /// Tinggi & lebar minimum area sentuh (Material 48dp).
  static const double tapMin = 48;
}

abstract final class StokasRadius {
  static const double sm = 6; // lencana, chip
  static const double md = 10; // tombol, input
  static const double lg = 16; // kartu, sheet, dialog
  static const double pill = 999;
}

abstract final class StokasShadow {
  /// shadow-float: hanya untuk yang melayang (dialog, sheet, menu).
  static List<BoxShadow> float(Brightness brightness) => [
        BoxShadow(
          offset: const Offset(0, 4),
          blurRadius: 16,
          color: brightness == Brightness.dark ? const Color(0x8C000000) : const Color(0x240F1B2D),
        ),
      ];
}

/// Skala tipe dari tokens.json. Manrope untuk display/judul, Inter untuk teks.
/// Semua gaya memakai angka rata (tabular) agar kolom angka sejajar.
abstract final class StokasType {
  static const display = 'Manrope';
  static const sans = 'Inter';
  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle _style(String family, double size, double lineHeight, FontWeight weight, {double letterSpacing = 0}) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        height: lineHeight / size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        fontFeatures: _tabular,
      );

  static final displayXl = _style(display, 40, 48, FontWeight.w800);
  static final displayL = _style(display, 32, 40, FontWeight.w800); // token "display"
  static final headline = _style(display, 24, 32, FontWeight.w700);
  static final titleLg = _style(display, 20, 28, FontWeight.w700);
  static final title = _style(sans, 16, 24, FontWeight.w600);
  static final bodyLg = _style(sans, 16, 24, FontWeight.w400);
  static final body = _style(sans, 14, 20, FontWeight.w400);
  static final label = _style(sans, 12, 16, FontWeight.w600, letterSpacing: 12 * 0.02);
  static final caption = _style(sans, 12, 16, FontWeight.w400);
}
