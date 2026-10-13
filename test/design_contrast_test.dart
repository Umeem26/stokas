import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/presentation/design/stokas_tokens.dart';

/// Rasio kontras WCAG 2.x antara dua warna buram.
double contrastRatio(Color a, Color b) {
  double channel(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) => 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final la = luminance(a), lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

String hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

void main() {
  const themes = {'light': StokasColors.light, 'dark': StokasColors.dark};

  // Pasangan wajib (latar depan, latar belakang).
  const text = [
    ('ink', 'canvas'), ('ink', 'surface'), ('ink', 'surface-sunken'),
    ('ink-muted', 'canvas'), ('ink-muted', 'surface'), ('ink-muted', 'surface-sunken'),
    ('on-primary', 'primary'), ('on-primary', 'primary-hover'),
    ('on-stock', 'stock'),
    ('on-cash', 'cash'),
    ('positive', 'positive-soft'), ('positive', 'canvas'), ('positive', 'surface'),
    ('negative', 'negative-soft'), ('negative', 'canvas'), ('negative', 'surface'),
    ('warning', 'warning-soft'), ('warning', 'canvas'), ('warning', 'surface'),
  ];
  const graphic = [
    ('line-strong', 'canvas'), ('line-strong', 'surface'),
    ('cash-deep', 'canvas'), ('cash-deep', 'surface'),
    ('focus', 'canvas'), ('focus', 'surface'),
  ];

  for (final theme in themes.entries) {
    final c = theme.value.byName;
    group('kontras WCAG tema ${theme.key}', () {
      for (final (fg, bg) in text) {
        test('teks $fg di atas $bg >= 4.5', () {
          final r = contrastRatio(c[fg]!, c[bg]!);
          expect(r, greaterThanOrEqualTo(4.5), reason: '$fg ${hex(c[fg]!)} / $bg ${hex(c[bg]!)} = ${r.toStringAsFixed(2)}');
        });
      }
      for (final (fg, bg) in graphic) {
        test('grafis $fg di atas $bg >= 3', () {
          final r = contrastRatio(c[fg]!, c[bg]!);
          expect(r, greaterThanOrEqualTo(3), reason: '$fg ${hex(c[fg]!)} / $bg ${hex(c[bg]!)} = ${r.toStringAsFixed(2)}');
        });
      }
    });
  }

  test('rumus kontras: hitam/putih = 21', () {
    expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01));
  });

  test('StokasColors memuat semua token warna tokens.json dengan nama & nilai yang sama', () {
    final json = jsonDecode(File('docs/brand/tokens.json').readAsStringSync()) as Map<String, dynamic>;
    final tokens = (json['color'] as Map)['tokens'] as List;
    expect(StokasColors.light.byName.keys.toSet(), {for (final t in tokens) t['name']});
    for (final t in tokens) {
      final value = t['value'] as Map;
      for (final theme in themes.entries) {
        expect(hex(theme.value.byName[t['name']]!), (value[theme.key] as String).toLowerCase(), reason: '${t['name']} (${theme.key})');
      }
    }
  });
}
