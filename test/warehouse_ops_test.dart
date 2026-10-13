import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/core/app_exception.dart';
import 'package:minimarket_pos/data/stock_ops.dart';
import 'package:minimarket_pos/presentation/design/stokas_button.dart';
import 'package:minimarket_pos/presentation/stock_list_screen.dart';
import 'package:minimarket_pos/presentation/warehouse/opname_screen.dart';
import 'package:minimarket_pos/presentation/warehouse/receive_screen.dart';
import 'package:minimarket_pos/presentation/warehouse/transfer_screen.dart';

import 'fakes.dart';
import 'stock_rpc_test.dart' show pumpApp, row;

List<Map<String, dynamic>> _catalog() => [
      {'id': 'A', 'brand_name': 'Barang A', 'unit_type': 'pcs', 'min_stock': 1, 'category_id': 1, 'price': 3500},
      {'id': 'B', 'brand_name': 'Barang B', 'unit_type': 'pcs', 'min_stock': 1, 'category_id': null, 'price': 0},
    ];

Future<FakeStockRepository> pumpScreen(WidgetTester tester, Widget screen, List<Map<String, dynamic>> rows) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final stock = FakeStockRepository(rows);
  await pumpApp(tester, screen, stock: stock, products: FakeProductRepository(_catalog()));
  await tester.pumpAndSettle();
  return stock;
}

Future<void> scan(WidgetTester tester, String prefix, String text) async {
  await tester.enterText(find.byKey(Key('$prefix-search')), text);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

StokasButton button(WidgetTester tester, String key) => tester.widget<StokasButton>(find.byKey(Key(key)));

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// Batch A: 1 = Lantai 1 tanpa tanggal (10), 2 = Lantai 2 exp 1 Des 2026 (5), 3 = Lantai 1 kedaluwarsa 1 Okt 2026 (4).
List<Map<String, dynamic>> _opnameRows() => [
      row(1, 'A', 10),
      row(2, 'A', 5, floor: 'Lantai 2', expiry: '2026-12-01'),
      row(3, 'A', 4, expiry: '2026-10-01'),
    ];

void main() {
  group('logika opname & pindah', () {
    test('countDiffLabel: Lebih / Kurang / Sama dengan tanda', () {
      expect(countDiff(10, 12).kind, CountDiff.lebih);
      expect(countDiffLabel(10, 12, 'pcs'), 'Lebih +2 pcs');
      expect(countDiffLabel(5, 3, 'pcs'), 'Kurang −2 pcs');
      expect(countDiffLabel(4, 4, 'pcs'), 'Sama');
      expect(countDiffLabel(2, 2.5, 'kg'), 'Lebih +0.5 kg');
    });

    test('transferBlockReason: melebihi stok asal, lantai sama, belum pilih', () {
      String? r({num? available = 5, String? from = 'Lantai 1', String to = 'Lantai 2', num qty = 1}) =>
          transferBlockReason(hasProduct: true, available: available, from: from, to: to, qty: qty, unit: 'pcs');
      expect(r(), isNull);
      expect(r(qty: 5), isNull);
      expect(r(qty: 6), 'Jumlah melebihi stok asal (5 pcs).');
      expect(r(to: 'Lantai 1'), contains('berbeda'));
      expect(r(available: null, from: null), 'Pilih stok asal.');
      expect(r(qty: 0), contains('lebih dari 0'));
    });
  });

  group('Opname', () {
    testWidgets('selisih benar dan berlabel ikon + kata; hanya baris berubah yang dikirim', (tester) async {
      final stock = await pumpScreen(tester, const OpnameScreen(), _opnameRows());
      expect(button(tester, 'opname-save').onPressed, isNull);

      await scan(tester, 'opname', 'A');
      expect(find.text('Tercatat 10 pcs'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('opname-save-reason'))).data, 'Belum ada jumlah yang berubah.');

      await tester.enterText(find.byKey(const Key('opname-count-1')), '12');
      await tester.enterText(find.byKey(const Key('opname-count-2')), '3');
      await tester.enterText(find.byKey(const Key('opname-count-3')), '4');
      await tester.pump();

      Finder diff(int id, IconData icon, String text) => find.descendant(
            of: find.byKey(Key('opname-diff-$id')),
            matching: find.byWidgetPredicate((w) => (w is Icon && w.icon == icon) || (w is Text && w.data == text)),
          );
      expect(diff(1, Icons.add_circle_outline, 'Lebih +2 pcs'), findsNWidgets(2));
      expect(diff(2, Icons.remove_circle_outline, 'Kurang −2 pcs'), findsNWidgets(2));
      expect(diff(3, Icons.check_circle_outline, 'Sama'), findsNWidgets(2));
      expect(find.text('Simpan 2 perubahan'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('opname-note')), 'Hitung bulanan');
      await tapKey(tester, 'opname-save');

      expect(stock.calls, ['opname A Lantai 1 - 12 Hitung bulanan', 'opname A Lantai 2 2026-12-1 3 Hitung bulanan']);
      expect(find.byKey(const ValueKey('opname-row-1')), findsNothing);
      expect(find.byKey(const ValueKey('opname-row-2')), findsNothing);
      expect(find.byKey(const ValueKey('opname-row-3')), findsOneWidget, reason: 'tidak berubah, tidak dikirim');
      expect(find.textContaining('2 tersimpan'), findsOneWidget);
    });

    testWidgets('jumlah tidak valid -> Simpan nonaktif dengan alasan', (tester) async {
      final stock = await pumpScreen(tester, const OpnameScreen(), _opnameRows());
      await scan(tester, 'opname', 'A');
      await tester.enterText(find.byKey(const Key('opname-count-1')), '1.2.3');
      await tester.pump();
      expect(find.text('Jumlah hitung tidak valid'), findsOneWidget);
      expect(button(tester, 'opname-save').onPressed, isNull);
      expect(tester.widget<Text>(find.byKey(const Key('opname-save-reason'))).data, contains('tidak valid'));
      expect(stock.calls, isEmpty);
    });

    testWidgets('gagal sebagian: baris sukses hilang, gagal tetap dengan pesan server', (tester) async {
      final stock = await pumpScreen(tester, const OpnameScreen(), _opnameRows());
      await scan(tester, 'opname', 'A');
      await tester.enterText(find.byKey(const Key('opname-count-1')), '12');
      await tester.enterText(find.byKey(const Key('opname-count-2')), '3');
      stock.failures['opname A Lantai 1 -'] = const AppException('Barang tidak ditemukan');

      await tapKey(tester, 'opname-save');

      expect(stock.calls.length, 2);
      expect(find.byKey(const ValueKey('opname-row-1')), findsOneWidget);
      expect(find.text('Barang tidak ditemukan'), findsOneWidget);
      expect(find.byKey(const ValueKey('opname-row-2')), findsNothing);
      expect(find.textContaining('1 tersimpan'), findsOneWidget);
      expect(find.text('Simpan 1 perubahan'), findsOneWidget, reason: 'isian baris gagal tetap');
    });

    testWidgets('jaringan putus: berhenti tanpa retry otomatis, "Belum pasti tersimpan"', (tester) async {
      final stock = await pumpScreen(tester, const OpnameScreen(), _opnameRows());
      await scan(tester, 'opname', 'A');
      await tester.enterText(find.byKey(const Key('opname-count-1')), '12');
      await tester.enterText(find.byKey(const Key('opname-count-2')), '3');
      stock.failures['opname A Lantai 1 -'] = const NetworkException(uncertainSaveMessage);

      await tapKey(tester, 'opname-save');
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();

      expect(stock.calls, ['opname A Lantai 1 - 12'], reason: 'satu upaya; sisa baris tidak dikirim');
      expect(find.text(uncertainSaveMessage), findsOneWidget);
      expect(find.byKey(const ValueKey('opname-row-2')), findsOneWidget);
    });

    testWidgets('Tulis rugi: lencana Kedaluwarsa; Batal tidak memanggil apa pun; konfirmasi -> stock_count 0 "Tulis rugi"',
        (tester) async {
      final stock = await pumpScreen(tester, const OpnameScreen(), _opnameRows());
      await scan(tester, 'opname', 'A');

      final row3 = find.byKey(const ValueKey('opname-row-3'));
      expect(find.descendant(of: row3, matching: find.text('Kedaluwarsa')), findsOneWidget);
      expect(find.byKey(const Key('opname-writeoff-1')), findsNothing, reason: 'batch belum kedaluwarsa');

      await tapKey(tester, 'opname-writeoff-3');
      expect(find.textContaining('Barang A, 4 pcs, kedaluwarsa 1 Okt 2026 di Lantai 1'), findsOneWidget);
      final danger = tester.getTopLeft(find.byKey(const Key('writeoff-confirm')));
      final cancel = tester.getTopLeft(find.byKey(const Key('writeoff-cancel')));
      expect(danger.dx, lessThan(cancel.dx), reason: 'bahaya di kiri, Batal di kanan');

      await tapKey(tester, 'writeoff-cancel');
      expect(stock.calls, isEmpty);
      expect(row3, findsOneWidget);

      await tapKey(tester, 'opname-writeoff-3');
      await tapKey(tester, 'writeoff-confirm');
      expect(stock.calls, ['opname A Lantai 1 2026-10-1 0 Tulis rugi']);
      expect(stock.rows.firstWhere((r) => r['id'] == 3)['quantity'], 0);
      expect(row3, findsNothing);
    });
  });

  group('Pindah', () {
    List<Map<String, dynamic>> rows() => [row(1, 'A', 5), row(2, 'A', 3, expiry: '2026-12-01')];

    testWidgets('menolak jumlah melebihi stok asal di UI; lalu memanggil transfer_stock batch yang dipilih', (tester) async {
      final stock = await pumpScreen(tester, const TransferScreen(), rows());
      await scan(tester, 'transfer', 'A');
      expect(tester.widget<Text>(find.byKey(const Key('transfer-save-reason'))).data, 'Pilih stok asal.');

      await tapKey(tester, 'transfer-batch-1');
      await tester.enterText(find.byKey(const Key('transfer-qty')), '6');
      await tester.pump();
      expect(find.text('Melebihi stok asal (5 pcs)'), findsOneWidget);
      expect(button(tester, 'transfer-save').onPressed, isNull);
      expect(tester.widget<Text>(find.byKey(const Key('transfer-save-reason'))).data, 'Jumlah melebihi stok asal (5 pcs).');

      await tester.tap(find.descendant(of: find.byKey(const Key('transfer-to')), matching: find.text('Lantai 1')));
      await tester.enterText(find.byKey(const Key('transfer-qty')), '5');
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('transfer-save-reason'))).data, contains('berbeda'));

      await tester.tap(find.descendant(of: find.byKey(const Key('transfer-to')), matching: find.text('Lantai 2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('transfer-save-reason')), findsNothing);
      await tapKey(tester, 'transfer-save');

      expect(stock.calls, ['transfer A Lantai 1->Lantai 2 - 5']);
      expect(find.text('5 pcs Barang A dipindah ke Lantai 2.'), findsOneWidget);
    });

    testWidgets('batch kedaluwarsa dipindah dengan tanggalnya; pesan server tampil apa adanya', (tester) async {
      final stock = await pumpScreen(tester, const TransferScreen(), rows());
      await scan(tester, 'transfer', 'A');
      await tapKey(tester, 'transfer-batch-2');
      stock.failures['transfer'] = const AppException('Stok di lantai asal tidak cukup');

      await tapKey(tester, 'transfer-save');
      expect(stock.calls, ['transfer A Lantai 1->Lantai 2 2026-12-1 1']);
      expect(find.text('Stok di lantai asal tidak cukup'), findsOneWidget);
    });
  });

  testWidgets('Produk: produk tanpa stok tampil dengan lencana "Habis"', (tester) async {
    await pumpScreen(tester, const StockListScreen(title: 'Produk', showAllProducts: true), [row(1, 'A', 5)]);
    expect(find.text('Barang A'), findsOneWidget);
    final b = find.byKey(const ValueKey('no-stock-B'));
    expect(find.descendant(of: b, matching: find.text('Barang B')), findsOneWidget);
    expect(find.descendant(of: b, matching: find.text('Habis')), findsOneWidget);
  });

  testWidgets('Terima: produk tanpa stok bisa dipilih lewat scan dan "Tambah baris"', (tester) async {
    await pumpScreen(tester, const ReceiveScreen(), [row(1, 'A', 5)]);
    await scan(tester, 'receive', 'B');
    expect(find.text('Barang B'), findsOneWidget);

    await tapKey(tester, 'receive-remove-1');
    await tapKey(tester, 'receive-add-line');
    await tapKey(tester, 'picker-B');
    expect(find.text('Barang B'), findsOneWidget);
    expect(find.text('Simpan 1 barang'), findsOneWidget);
  });
}
