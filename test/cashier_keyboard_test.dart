import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/data/providers.dart';
import 'package:minimarket_pos/data/scanner_buffer.dart';
import 'package:minimarket_pos/data/session.dart';
import 'package:minimarket_pos/data/transaction_model.dart';
import 'package:minimarket_pos/presentation/cashier_screen.dart';

import 'cashier_screen_test.dart' show cartOf, item, tapKey;
import 'fakes.dart';

final _rows = [
  item(1, 'A1', 'Kopi Sachet', 10),
  item(2, 'B2', 'A1 Snack Pedas', 10, price: 12000, category: 'Snack'),
  item(3, 'C3', 'Teh Botol', 1, price: 5000, category: 'Minuman'),
  item(5, '8991001', 'Ciki', 20, price: 2000, category: 'Snack'),
];

const pcSize = Size(1366, 900);

Future<FakeTransactionRepository> pumpKasir(WidgetTester tester, {Size size = pcSize}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final tx = FakeTransactionRepository();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentProfileProvider.overrideWithValue(null),
      clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 13, 3)),
      scannerClockProvider.overrideWithValue(() => tester.binding.clock.now()),
      stockRepositoryProvider.overrideWithValue(FakeStockRepository(_rows)),
      transactionRepositoryProvider.overrideWithValue(tx),
    ],
    child: const MaterialApp(home: CashierScreen()),
  ));
  await tester.pumpAndSettle();
  return tx;
}

TextField searchField(WidgetTester tester) => tester.widget<TextField>(find.byKey(const Key('cashier-search')));

bool searchFocused(WidgetTester tester) => searchField(tester).focusNode!.hasFocus;

/// Lepas fokus dari kolom mana pun (mis. kasir mengeklik area kosong).
Future<void> unfocusAll(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.pump();
}

/// Ketik [text] per karakter dengan jeda [gap] (meniru scanner atau manusia), lalu Enter.
Future<void> typeKeys(WidgetTester tester, String text, Duration gap, {bool enter = true}) async {
  for (final ch in text.split('')) {
    await tester.sendKeyEvent(LogicalKeyboardKey(ch.toLowerCase().codeUnitAt(0)), character: ch);
    await tester.pump(gap);
  }
  if (enter) await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
}

Future<void> key(WidgetTester tester, LogicalKeyboardKey k, {String? character}) async {
  await tester.sendKeyEvent(k, character: character);
  await tester.pumpAndSettle();
}

/// "+" di keyboard PC = Shift + "=" (karakter '+').
Future<void> plus(WidgetTester tester) => key(tester, LogicalKeyboardKey.equal, character: '+');
Future<void> minus(WidgetTester tester) => key(tester, LogicalKeyboardKey.minus, character: '-');

/// Isi kolom cari lalu Enter (keyboard fisik).
Future<void> searchEnter(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('cashier-search')), text);
  await tester.pump();
  await key(tester, LogicalKeyboardKey.enter);
}

String? scanStatus(WidgetTester tester) {
  final f = find.descendant(of: find.byKey(const Key('scan-status')), matching: find.byType(Text));
  return f.evaluate().isEmpty ? null : tester.widget<Text>(f).data;
}

bool rowSelected(WidgetTester tester, String id) {
  final box = find.descendant(of: find.byKey(ValueKey('cart-row-$id')), matching: find.byType(Container)).first;
  return tester.widget<Container>(box).foregroundDecoration != null;
}

void main() {
  group('ScannerBuffer', () {
    final t0 = DateTime(2026, 10, 13, 10);
    DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

    test('ketikan cepat + Enter = kode; lambat = abaikan; < 3 karakter bukan scan', () {
      final b = ScannerBuffer();
      for (final (i, ch) in '8991001'.split('').indexed) {
        b.add(ch, at(i * 10));
      }
      expect(b.submit(at(70)), '8991001');

      for (final (i, ch) in 'abc'.split('').indexed) {
        b.add(ch, at(1000 + i * 200));
      }
      expect(b.submit(at(1450)), isNull, reason: 'jeda 200 ms: hanya karakter terakhir tertampung');

      b..add('a', at(2000))..add('b', at(2010));
      expect(b.submit(at(2020)), isNull);
      expect(scannerMaxGapMs, 80);
    });

    test('Enter terlambat setelah ketikan cepat = abaikan', () {
      final b = ScannerBuffer()..add('1', at(0))..add('2', at(10))..add('3', at(20));
      expect(b.submit(at(20 + scannerMaxGapMs + 1)), isNull);
    });
  });

  group('Kasir mode PC (>= 1280)', () {
    testWidgets('tata letak: tabel keranjang, kolom bayar 400 px, status scanner, bilah pintasan; tanpa kisi', (tester) async {
      await pumpKasir(tester);
      expect(find.byKey(const Key('cart-table')), findsOneWidget);
      for (final h in ['Kode', 'Nama', 'Harga', 'Jumlah', 'Subtotal']) {
        expect(find.descendant(of: find.byKey(const Key('cart-table')), matching: find.text(h)), findsOneWidget);
      }
      expect(tester.getSize(find.byKey(const Key('cashier-pc-checkout'))).width, 400);
      expect(find.byKey(const Key('shortcut-bar')), findsOneWidget);
      expect(find.text('Siap scan'), findsOneWidget);
      expect(find.text('Menunggu ketikan scanner'), findsOneWidget);
      expect(find.textContaining('terhubung'), findsNothing);
      expect(find.byKey(const ValueKey('product-A1')), findsNothing, reason: 'kisi hanya di bawah 1280');
      expect(find.text('Tunai'), findsOneWidget, reason: 'cara bayar bawaan');
      expect(searchFocused(tester), isTrue);
    });

    testWidgets('di bawah 1280: kisi 4a tetap, tanpa tabel dan bilah pintasan', (tester) async {
      await pumpKasir(tester, size: const Size(1194, 834));
      expect(find.byKey(const Key('cashier-two-panel')), findsOneWidget);
      expect(find.byKey(const ValueKey('product-A1')), findsOneWidget);
      expect(find.byKey(const Key('cart-table')), findsNothing);
      expect(find.byKey(const Key('shortcut-bar')), findsNothing);
    });

    testWidgets('scan di kolom cari: aturan lama + status role=status', (tester) async {
      await pumpKasir(tester);
      await searchEnter(tester, 'teh botol');
      expect(cartOf(tester).quantityOf('C3'), 1);
      expect(scanStatus(tester), 'Ditambahkan: Teh Botol, jumlah sekarang 1');
      expect(searchField(tester).controller!.text, isEmpty);

      await searchEnter(tester, 'A1');
      expect(cartOf(tester).quantityOf('A1'), 1, reason: 'id persis menang atas nama');

      await searchEnter(tester, 'ZZZ-404');
      expect(scanStatus(tester), 'Barang tidak ditemukan: ZZZ-404');
      final live = tester.widget<Semantics>(find.ancestor(of: find.byKey(const Key('scan-status')), matching: find.byType(Semantics)).first);
      expect(live.properties.liveRegion, isTrue);
    });

    testWidgets('"/" memfokuskan kolom cari bila fokus di luar kolom teks', (tester) async {
      await pumpKasir(tester);
      await unfocusAll(tester);
      expect(searchFocused(tester), isFalse);
      await key(tester, LogicalKeyboardKey.slash, character: '/');
      expect(searchFocused(tester), isTrue);
    });

    testWidgets('Enter pada cari kosong dengan keranjang terisi membuka panel bayar; Esc menutup tanpa kehilangan keranjang', (tester) async {
      await pumpKasir(tester);
      await key(tester, LogicalKeyboardKey.enter);
      expect(find.byKey(const Key('pay-panel')), findsNothing, reason: 'keranjang kosong');

      await searchEnter(tester, '8991001');
      await searchEnter(tester, 'A1');
      await key(tester, LogicalKeyboardKey.enter);
      expect(find.byKey(const Key('pay-panel')), findsOneWidget);
      expect(find.text('Scanner dijeda'), findsOneWidget);

      await key(tester, LogicalKeyboardKey.escape);
      expect(find.byKey(const Key('pay-panel')), findsNothing);
      expect(cartOf(tester).items.map((i) => i.productId), ['8991001', 'A1']);
      expect(searchFocused(tester), isTrue, reason: 'fokus kembali ke cari');
      await key(tester, LogicalKeyboardKey.escape);
      expect(cartOf(tester).items, hasLength(2), reason: 'Esc tidak pernah mengosongkan keranjang');
    });

    testWidgets('+/- mengubah jumlah baris terpilih hanya bila cari kosong', (tester) async {
      await pumpKasir(tester);
      await searchEnter(tester, '8991001');
      await plus(tester);
      await key(tester, LogicalKeyboardKey.numpadAdd);
      expect(cartOf(tester).quantityOf('8991001'), 3);
      await minus(tester);
      expect(cartOf(tester).quantityOf('8991001'), 2);

      await tester.enterText(find.byKey(const Key('cashier-search')), 'kop');
      await tester.pump();
      await plus(tester);
      await minus(tester);
      expect(cartOf(tester).quantityOf('8991001'), 2, reason: 'cari terisi: + - diketik biasa');
      expect(searchField(tester).controller!.text, 'kop');
    });

    testWidgets('panah memilih baris (cincin fokus); Del menghapus baris terpilih', (tester) async {
      await pumpKasir(tester);
      await searchEnter(tester, 'A1');
      await searchEnter(tester, '8991001');
      await searchEnter(tester, 'teh botol');
      expect(rowSelected(tester, 'C3'), isTrue, reason: 'barang terakhir ditambah terpilih');

      await key(tester, LogicalKeyboardKey.arrowUp);
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(rowSelected(tester, 'A1'), isTrue);
      expect(rowSelected(tester, 'C3'), isFalse);
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(rowSelected(tester, '8991001'), isTrue);

      await key(tester, LogicalKeyboardKey.delete);
      expect(cartOf(tester).items.map((i) => i.productId), ['A1', 'C3']);
      expect(rowSelected(tester, 'C3'), isTrue, reason: 'pilihan pindah ke baris berikutnya');
      await key(tester, LogicalKeyboardKey.backspace);
      expect(cartOf(tester).items.map((i) => i.productId), ['A1']);
    });

    testWidgets('daftar hasil pencarian: maks 8, panah + Enter menambah, Esc menutup', (tester) async {
      await pumpKasir(tester);
      await tester.enterText(find.byKey(const Key('cashier-search')), 'k');
      await tester.pump();
      expect(find.byKey(const Key('search-results')), findsOneWidget);
      expect(find.byKey(const ValueKey('result-A1')), findsOneWidget);

      await key(tester, LogicalKeyboardKey.arrowDown); // Kopi Sachet
      await key(tester, LogicalKeyboardKey.arrowDown); // A1 Snack Pedas
      await key(tester, LogicalKeyboardKey.enter);
      expect(cartOf(tester).items.map((i) => i.productId), ['B2']);
      expect(find.byKey(const Key('search-results')), findsNothing);
      expect(searchFocused(tester), isTrue);

      await tester.enterText(find.byKey(const Key('cashier-search')), 'k');
      await tester.pump();
      await key(tester, LogicalKeyboardKey.escape);
      expect(find.byKey(const Key('search-results')), findsNothing);
      expect(searchField(tester).controller!.text, 'k');
      expect(cartOf(tester).items, hasLength(1));

      final many = [for (var i = 0; i < 12; i++) 'x$i'];
      expect(searchResults(many, 'x', id: (s) => s, name: (s) => s), hasLength(searchResultLimit));
    });

    testWidgets('scan cepat (jeda 10 ms) tanpa fokus di kolom cari menambah barang', (tester) async {
      await pumpKasir(tester);
      await unfocusAll(tester);
      await typeKeys(tester, '8991001', const Duration(milliseconds: 10));
      expect(cartOf(tester).quantityOf('8991001'), 1);
      expect(scanStatus(tester), 'Ditambahkan: Ciki, jumlah sekarang 1');
      expect(searchFocused(tester), isTrue, reason: 'fokus kembali ke cari');

      await unfocusAll(tester);
      await typeKeys(tester, '8991001', const Duration(milliseconds: 10));
      expect(scanStatus(tester), 'Ditambahkan: Ciki, jumlah sekarang 2');

      await unfocusAll(tester);
      await typeKeys(tester, '4040404', const Duration(milliseconds: 10));
      expect(scanStatus(tester), 'Barang tidak ditemukan: 4040404');
    });

    testWidgets('ketikan lambat (jeda 200 ms) bukan scan', (tester) async {
      await pumpKasir(tester);
      await unfocusAll(tester);
      await typeKeys(tester, '8991001', const Duration(milliseconds: 200));
      expect(cartOf(tester).items, isEmpty);
      expect(scanStatus(tester), isNull);
    });

    testWidgets('scan diabaikan saat panel bayar terbuka', (tester) async {
      final tx = await pumpKasir(tester);
      await searchEnter(tester, 'A1');
      await key(tester, LogicalKeyboardKey.enter);
      expect(find.byKey(const Key('pay-panel')), findsOneWidget);

      // Fokus di penerima tombol layar (bukan kolom teks), lalu scanner mengetik cepat + Enter.
      final keys = tester.widget<Focus>(find.byWidgetPredicate((w) => w is Focus && w.focusNode?.debugLabel == 'cashier-keys'));
      keys.focusNode!.requestFocus();
      await tester.pump();
      await typeKeys(tester, '8991001', const Duration(milliseconds: 10));
      expect(cartOf(tester).quantityOf('8991001'), 0);
      expect(cartOf(tester).items, hasLength(1));
      expect(tx.calls, isEmpty);
      expect(find.byKey(const Key('pay-panel')), findsOneWidget);
    });

    testWidgets('angka di "Uang diterima" tidak mengganti cara bayar', (tester) async {
      await pumpKasir(tester);
      await searchEnter(tester, 'A1');
      await key(tester, LogicalKeyboardKey.enter);
      final field = tester.widget<TextField>(find.byKey(const Key('paid-field')));
      expect(field.focusNode!.hasFocus, isTrue);

      for (final (k, ch) in [(LogicalKeyboardKey.digit2, '2'), (LogicalKeyboardKey.digit3, '3'), (LogicalKeyboardKey.numpad1, '1')]) {
        await key(tester, k, character: ch);
      }
      await tester.enterText(find.byKey(const Key('paid-field')), '23000');
      await tester.pump();
      expect(find.byKey(const Key('paid-field')), findsOneWidget, reason: 'tetap Tunai');
      expect(find.text('Sudah dibayar'), findsNothing);
      expect(cartOf(tester).quantityOf('A1'), 1, reason: '+/-/Del tidak aktif di kolom lain');
    });

    group('pengaman QRIS/Transfer', () {
      FocusNode confirmFocus(WidgetTester tester) =>
          tester.widget<FilledButton>(find.descendant(of: find.byKey(const Key('pay-confirm')), matching: find.byType(FilledButton))).focusNode!;
      bool ringShown(WidgetTester tester) =>
          find.descendant(of: find.byKey(const Key('pay-confirm')), matching: find.byKey(const ValueKey('stokasFocusRing'))).evaluate().isNotEmpty;

      Future<FakeTransactionRepository> openPay(WidgetTester tester, String methodKey) async {
        final tx = await pumpKasir(tester);
        await searchEnter(tester, 'A1');
        await key(tester, LogicalKeyboardKey.enter);
        await tapKey(tester, ValueKey('method-$methodKey'));
        return tx;
      }

      for (final method in ['qris', 'transfer']) {
        testWidgets('$method: Enter sekali tidak mencatat, hanya memfokuskan "Sudah dibayar" (cincin terlihat)', (tester) async {
          final tx = await openPay(tester, method);
          expect(find.text('Sudah dibayar'), findsOneWidget);
          expect(confirmFocus(tester).hasFocus, isFalse);

          await key(tester, LogicalKeyboardKey.enter);
          expect(tx.calls, isEmpty);
          expect(confirmFocus(tester).hasFocus, isTrue);
          expect(ringShown(tester), isTrue);
          expect(find.byKey(const Key('pay-panel')), findsOneWidget);
        });

        testWidgets('$method: Enter dua kali mencatat tepat sekali', (tester) async {
          final tx = await openPay(tester, method);
          await key(tester, LogicalKeyboardKey.enter);
          await key(tester, LogicalKeyboardKey.numpadEnter);
          expect(tx.calls, hasLength(1));
          expect(tx.calls.single.method.code, method);
          expect(find.byKey(const Key('checkout-done')), findsOneWidget);
        });
      }

      testWidgets('ganti cara bayar mengembalikan fokus awal: Enter lagi tidak mencatat', (tester) async {
        final tx = await openPay(tester, 'qris');
        await key(tester, LogicalKeyboardKey.enter);
        expect(confirmFocus(tester).hasFocus, isTrue);

        await key(tester, LogicalKeyboardKey.digit3, character: '3'); // Transfer
        expect(confirmFocus(tester).hasFocus, isFalse);
        await key(tester, LogicalKeyboardKey.enter);
        expect(tx.calls, isEmpty);
        expect(confirmFocus(tester).hasFocus, isTrue);

        await tapKey(tester, const ValueKey('method-qris'));
        expect(confirmFocus(tester).hasFocus, isFalse);
        await key(tester, LogicalKeyboardKey.enter);
        expect(tx.calls, isEmpty);

        await key(tester, LogicalKeyboardKey.digit1, character: '1'); // Tunai: kolom uang terfokus
        expect(tester.widget<TextField>(find.byKey(const Key('paid-field'))).focusNode!.hasFocus, isTrue);
      });

      testWidgets('klik "Sudah dibayar" tetap langsung mencatat', (tester) async {
        final tx = await openPay(tester, 'qris');
        await tapKey(tester, const Key('pay-confirm'));
        expect(tx.calls, hasLength(1));
      });

      testWidgets('Tunai tidak berubah: Enter di kolom uang langsung bayar', (tester) async {
        final tx = await pumpKasir(tester);
        await searchEnter(tester, 'A1');
        await key(tester, LogicalKeyboardKey.enter);
        await tester.enterText(find.byKey(const Key('paid-field')), '5000');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(tx.calls.single.method, PaymentMethod.cash);
      });
    });

    testWidgets('Enter di layar selesai = Transaksi baru; cara bayar terakhir diingat', (tester) async {
      final tx = await pumpKasir(tester);
      await searchEnter(tester, 'A1');
      await key(tester, LogicalKeyboardKey.enter);
      await tapKey(tester, const ValueKey('method-qris'));
      await key(tester, LogicalKeyboardKey.enter); // fokus ke "Sudah dibayar"
      await key(tester, LogicalKeyboardKey.enter); // catat
      expect(tx.calls.single.method, PaymentMethod.qris);
      expect(find.byKey(const Key('checkout-done')), findsOneWidget);

      await key(tester, LogicalKeyboardKey.enter);
      expect(find.byKey(const Key('checkout-done')), findsNothing);
      expect(cartOf(tester).items, isEmpty);
      expect(searchFocused(tester), isTrue);
      expect(find.text('QRIS'), findsOneWidget, reason: 'cara bayar terakhir di sesi ini');

      await searchEnter(tester, 'A1');
      await key(tester, LogicalKeyboardKey.enter);
      expect(find.text('Sudah dibayar'), findsOneWidget, reason: 'panel bayar mulai dari QRIS');
    });
  });
}
