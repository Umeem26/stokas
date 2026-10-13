import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/presentation/design/money_text.dart';
import 'package:minimarket_pos/presentation/design/status_badge.dart';
import 'package:minimarket_pos/presentation/design/stokas_button.dart';
import 'package:minimarket_pos/presentation/design/stokas_logo.dart';
import 'package:minimarket_pos/presentation/design/stokas_theme.dart';
import 'package:minimarket_pos/presentation/design/stokas_tokens.dart';

Future<void> pumpThemed(WidgetTester tester, ThemeData theme, Widget child) {
  return tester.pumpWidget(MaterialApp(
    theme: theme,
    home: Scaffold(body: Center(child: child)),
  ));
}

void main() {
  final themes = {'terang': StokasTheme.light, 'gelap': StokasTheme.dark};

  test('ThemeData memetakan token: ekstensi, ColorScheme, dan font', () {
    for (final entry in {StokasTheme.light: StokasColors.light, StokasTheme.dark: StokasColors.dark}.entries) {
      final t = entry.key, c = entry.value;
      expect(t.useMaterial3, isTrue);
      expect(t.extension<StokasColors>(), same(c));
      expect(t.colorScheme.primary, c.primary);
      expect(t.colorScheme.onPrimary, c.onPrimary);
      expect(t.colorScheme.surface, c.surface);
      expect(t.colorScheme.onSurface, c.ink);
      expect(t.colorScheme.error, c.negative);
      expect(t.scaffoldBackgroundColor, c.canvas);
      expect(t.textTheme.displayLarge!.fontFamily, 'Manrope');
      expect(t.textTheme.displayLarge!.fontSize, 40);
      expect(t.textTheme.headlineMedium!.fontFamily, 'Manrope');
      expect(t.textTheme.bodyMedium!.fontFamily, 'Inter');
      expect(t.textTheme.bodyMedium!.fontSize, 14);
      expect(t.textTheme.bodyLarge!.color, c.ink);
    }
    expect(StokasTheme.dark.brightness, Brightness.dark);
  });

  for (final entry in themes.entries) {
    final name = entry.key, theme = entry.value;
    final c = theme.extension<StokasColors>()!;

    group('tema $name', () {
      for (final variant in StokasButtonVariant.values) {
        testWidgets('StokasButton ${variant.name}: tap target >= 48, bisa ditekan, cincin fokus', (tester) async {
          var taps = 0;
          final focus = FocusNode();
          addTearDown(focus.dispose);
          await pumpThemed(tester, theme, StokasButton(label: 'Simpan', variant: variant, focusNode: focus, onPressed: () => taps++));

          final size = tester.getSize(find.byType(StokasButton));
          expect(size.height, greaterThanOrEqualTo(StokasSpace.tapMin));
          expect(size.width, greaterThanOrEqualTo(StokasSpace.tapMin));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

          await tester.tap(find.text('Simpan'));
          expect(taps, 1);

          expect(find.byKey(const ValueKey('stokasFocusRing')), findsNothing);
          focus.requestFocus();
          await tester.pump();
          final ring = tester.widget<DecoratedBox>(find.byKey(const ValueKey('stokasFocusRing')));
          final border = (ring.decoration as BoxDecoration).border as Border;
          expect(border.top.width, 2);
          expect(border.top.color, c.focus);
        });
      }

      testWidgets('StokasButton nonaktif tetap terbaca (ink-muted) dan tidak memanggil aksi', (tester) async {
        await pumpThemed(tester, theme, const StokasButton(label: 'Bayar', onPressed: null));
        expect(tester.getSize(find.byType(StokasButton)).height, greaterThanOrEqualTo(48));
        final text = tester.widget<DefaultTextStyle>(
          find.ancestor(of: find.text('Bayar'), matching: find.byType(DefaultTextStyle)).first,
        );
        expect(text.style.color, c.inkMuted);
      });

      for (final status in StockStatus.values) {
        testWidgets('StatusBadge ${status.name} memuat ikon dan kata', (tester) async {
          await pumpThemed(tester, theme, StatusBadge(status));
          expect(find.byIcon(status.icon), findsOneWidget);
          expect(find.text(status.defaultLabel), findsOneWidget);
          final expected = switch (status) {
            StockStatus.aman => c.positive,
            StockStatus.menipis => c.warning,
            StockStatus.bahaya => c.negative,
          };
          expect(tester.widget<Icon>(find.byIcon(status.icon)).color, expected);
          expect(tester.widget<Text>(find.text(status.defaultLabel)).style!.color, expected);
        });
      }

      testWidgets('StatusBadge label kustom tetap disertai ikon', (tester) async {
        await pumpThemed(tester, theme, const StatusBadge(StockStatus.bahaya, label: 'Habis'));
        expect(find.text('Habis'), findsOneWidget);
        expect(find.byIcon(StockStatus.bahaya.icon), findsOneWidget);
      });

      testWidgets('MoneyText: Rp titik ribuan, minus bertanda, digit tabular', (tester) async {
        await pumpThemed(tester, theme, const Column(children: [MoneyText(37500), MoneyText(-5000), MoneyText(0)]));
        expect(find.text('Rp 37.500'), findsOneWidget);
        expect(find.text('−Rp 5.000'), findsOneWidget);
        expect(find.text('Rp 0'), findsOneWidget);
        final style = tester.widget<Text>(find.text('Rp 37.500')).style!;
        expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
      });

      testWidgets('StokasLogo memilih aset sesuai tema (reverse di gelap)', (tester) async {
        final dark = theme.brightness == Brightness.dark;
        await pumpThemed(tester, theme, const Column(children: [StokasLogo(), StokasLogo.lockup()]));
        final assets = tester
            .widgetList<SvgPicture>(find.byType(SvgPicture))
            .map((p) => (p.bytesLoader as SvgAssetLoader).assetName)
            .toList();
        expect(assets, [
          dark ? 'assets/brand/stokas-mark-reverse.svg' : 'assets/brand/stokas-mark.svg',
          dark ? 'assets/brand/stokas-logo-reverse.svg' : 'assets/brand/stokas-logo.svg',
        ]);
        expect(find.bySemanticsLabel('Stokas'), findsNWidgets(2));
      });
    });
  }
}
