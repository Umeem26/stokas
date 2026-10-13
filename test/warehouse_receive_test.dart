import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/core/app_exception.dart';
import 'package:minimarket_pos/core/permissions.dart';
import 'package:minimarket_pos/data/receive_lines.dart';
import 'package:minimarket_pos/data/repositories/product_repository.dart';
import 'package:minimarket_pos/data/scan_match.dart';
import 'package:minimarket_pos/presentation/design/stokas_button.dart';
import 'package:minimarket_pos/presentation/stock_list_screen.dart';
import 'package:minimarket_pos/presentation/warehouse/new_product_screen.dart';
import 'package:minimarket_pos/presentation/warehouse/receive_screen.dart';

import 'fakes.dart';
import 'stock_rpc_test.dart' show pumpApp, row;

List<Map<String, dynamic>> _catalog() => [
      {'id': 'A1', 'brand_name': 'Kopi Sachet', 'unit_type': 'pcs'},
      {'id': 'B2', 'brand_name': 'A1 Snack Pedas', 'unit_type': 'pcs'},
      {'id': 'C3', 'brand_name': 'Teh Botol', 'unit_type': 'pcs'},
    ];

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<(FakeStockRepository, FakeProductRepository)> pumpReceive(WidgetTester tester) async {
  _tallView(tester);
  final stock = FakeStockRepository([]);
  final products = FakeProductRepository(_catalog());
  await pumpApp(tester, const ReceiveScreen(), stock: stock, products: products);
  await tester.pumpAndSettle();
  return (stock, products);
}

Future<void> scan(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('receive-search')), text);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

/// Pilih tanggal [day] Oktober 2026 (bulan "hari ini" di clock tes) lewat date picker.
Future<void> pickDay(WidgetTester tester, Key button, int day) async {
  await tester.tap(find.byKey(button));
  await tester.pumpAndSettle();
  await tester.tap(find.text('$day'));
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

StokasButton saveButton(WidgetTester tester) => tester.widget<StokasButton>(find.byKey(const Key('receive-save')));

void main() {
  group('matchScan & validasi baris', () {
    final items = _catalog();
    ScanMatch<Map<String, dynamic>> m(String q) => matchScan(items, q, id: (p) => p['id'], name: (p) => p['brand_name']);

    test('kode persis menang atas nama; nama persis; mengandung tunggal; banyak -> kandidat', () {
      expect(m('A1').match!['id'], 'A1', reason: 'bukan "A1 Snack Pedas"');
      expect(m('teh botol').match!['id'], 'C3');
      expect(m('snack').match!['id'], 'B2');
      expect(m('o').match, isNull);
      expect(m('o').candidates.map((p) => p['id']), ['A1', 'C3']);
      expect(m('zz').candidates, isEmpty);
    });

    test('saveBlockReason: kosong, tanggal lewat, jumlah 0; tanggal kosong dan hari ini boleh', () {
      final now = DateTime.utc(2026, 10, 13, 3); // 13 Okt 2026 10.00 WIB
      ReceiveLine line({DateTime? expiry, num qty = 1}) =>
          ReceiveLine(key: 1, productId: 'A1', name: 'Kopi', unit: 'pcs', floor: 'Lantai 1', qty: qty, expiry: expiry);

      expect(saveBlockReason([], now), isNotNull);
      expect(saveBlockReason([line()], now), isNull);
      expect(saveBlockReason([line(expiry: DateTime(2026, 10, 13))], now), isNull);
      expect(lineProblem(line(expiry: DateTime(2026, 10, 12)), now), pastDateMessage);
      expect(saveBlockReason([line(expiry: DateTime(2026, 10, 12))], now), contains('sudah lewat'));
      expect(saveBlockReason([line(qty: 0)], now), contains('berjumlah 0'));
    });

    test('NewProduct.toRpcParams: p_price 0 bawaan, jumlah 0 = tanpa stok awal, tanggal yyyy-MM-dd', () {
      final p = const NewProduct(id: ' Z9 ', name: 'Kopi', unit: 'pcs', floor: 'Lantai 1', qty: 0, note: ' ').toRpcParams();
      expect(p['p_price'], 0);
      expect(p['p_id'], 'Z9');
      expect(p['p_qty'], isNull);
      expect(p['p_note'], isNull);
      final q = NewProduct(id: 'Z9', name: 'Kopi', unit: 'pcs', floor: 'Lantai 2', qty: 3, expiry: DateTime(2026, 11, 2)).toRpcParams();
      expect(q['p_qty'], 3);
      expect(q['p_expiry'], '2026-11-02');
    });
  });

  testWidgets('scan: kode persis menang atas nama; banyak cocok -> pilih dari daftar', (tester) async {
    await pumpReceive(tester);

    await scan(tester, 'A1');
    expect(find.text('Kopi Sachet'), findsOneWidget);
    expect(find.text('A1 Snack Pedas'), findsNothing);
    expect(find.text('Simpan 1 barang'), findsOneWidget);

    await scan(tester, 'o');
    expect(find.text('Ada beberapa barang yang cocok, pilih dari daftar'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('receive-candidate-C3')));
    await tester.pumpAndSettle();
    expect(find.text('Teh Botol'), findsOneWidget);
    expect(find.text('Simpan 2 barang'), findsOneWidget);
  });

  testWidgets('tanggal lewat -> pesan di kartu, Simpan nonaktif dengan alasan; tanggal kosong boleh', (tester) async {
    final (stock, _) = await pumpReceive(tester);
    await scan(tester, 'A1');
    expect(saveButton(tester).onPressed, isNotNull, reason: 'tanpa tanggal boleh disimpan');

    await pickDay(tester, const Key('receive-expiry-1'), 12);
    expect(find.text('Tanggal ini sudah lewat'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
    expect(tester.widget<Text>(find.byKey(const Key('receive-save-reason'))).data, contains('sudah lewat'));

    await tester.tap(find.byTooltip('Hapus tanggal'));
    await tester.pumpAndSettle();
    expect(find.text('Tanggal ini sudah lewat'), findsNothing);
    expect(saveButton(tester).onPressed, isNotNull);
    expect(find.byKey(const Key('receive-save-reason')), findsNothing);
    expect(stock.calls, isEmpty);
  });

  testWidgets('Simpan memanggil restock per baris dengan lantai, jumlah, tanggal yang benar', (tester) async {
    final (stock, _) = await pumpReceive(tester);
    await scan(tester, 'A1');
    await scan(tester, 'C3');

    await tester.enterText(find.byKey(const Key('receive-qty-1')), '12');
    await tester.tap(find.descendant(of: find.byKey(const Key('receive-floor-1')), matching: find.text('Lantai 2')));
    await tester.pumpAndSettle();
    await pickDay(tester, const Key('receive-expiry-1'), 20);
    await tester.tap(find.byKey(const Key('receive-save')));
    await tester.pumpAndSettle();

    expect(stock.calls, ['restock A1 Lantai 2 2026-10-20 12', 'restock C3 Lantai 1 - 1']);
    expect(find.text('Kopi Sachet'), findsNothing);
    expect(find.text('Teh Botol'), findsNothing);
    expect(find.textContaining('2 tersimpan'), findsOneWidget);
  });

  testWidgets('gagal sebagian: baris sukses hilang, baris gagal tetap dengan pesan server', (tester) async {
    final (stock, _) = await pumpReceive(tester);
    for (final code in ['A1', 'B2', 'C3']) {
      await scan(tester, code);
    }
    stock.restockErrors['B2'] = const AppException('Barang tidak ditemukan');

    await tester.tap(find.byKey(const Key('receive-save')));
    await tester.pumpAndSettle();

    expect(stock.calls.length, 3);
    expect(find.text('Kopi Sachet'), findsNothing);
    expect(find.text('Teh Botol'), findsNothing);
    expect(find.text('A1 Snack Pedas'), findsOneWidget);
    expect(find.text('Barang tidak ditemukan'), findsOneWidget);
    expect(find.textContaining('2 tersimpan'), findsOneWidget);
    expect(find.text('Simpan 1 barang'), findsOneWidget);
  });

  testWidgets('jaringan putus: berhenti, tidak diulang otomatis, baris tetap dengan "Belum pasti tersimpan"', (tester) async {
    final (stock, _) = await pumpReceive(tester);
    await scan(tester, 'A1');
    await scan(tester, 'C3');
    stock.restockErrors['A1'] = const NetworkException(uncertainSaveMessage);

    await tester.tap(find.byKey(const Key('receive-save')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();

    expect(stock.calls, ['restock A1 Lantai 1 - 1'], reason: 'satu upaya, tanpa retry, sisa baris tidak dikirim');
    expect(find.text('Belum pasti tersimpan. Cek tab Produk sebelum mengulang.'), findsOneWidget);
    expect(find.text('Kopi Sachet'), findsOneWidget);
    expect(find.text('Teh Botol'), findsOneWidget);
    expect(find.textContaining('koneksi terputus'), findsOneWidget);
  });

  testWidgets('kode tak dikenal -> "Buat produk baru dengan kode ini" membuka Produk baru dengan kode terisi', (tester) async {
    final (_, products) = await pumpReceive(tester);
    await scan(tester, 'ZZ9');
    expect(find.text('Kode "ZZ9" belum terdaftar.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('receive-create-product')));
    await tester.pumpAndSettle();
    expect(find.byType(NewProductScreen), findsOneWidget);
    expect(tester.widget<TextField>(find.descendant(of: find.byKey(const Key('np-code')), matching: find.byType(TextField))).controller!.text, 'ZZ9');

    await tester.enterText(find.byKey(const Key('np-name')), 'Roti Tawar');
    await tester.tap(find.byKey(const Key('np-save')));
    await tester.pumpAndSettle();
    expect(find.byType(NewProductScreen), findsNothing);
    expect(products.created.single.id, 'ZZ9');

    await scan(tester, 'ZZ9');
    expect(find.text('Roti Tawar'), findsOneWidget, reason: 'daftar barang dimuat ulang');
  });

  group('Produk baru (gudang)', () {
    Future<FakeProductRepository> pumpForm(WidgetTester tester) async {
      _tallView(tester);
      final products = FakeProductRepository(_catalog());
      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewProductScreen())),
              child: const Text('buka'),
            ),
          ),
        ),
        products: products,
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      return products;
    }

    testWidgets('mengirim p_price 0; "Kode barang sudah dipakai" di dekat kolom kode; sukses -> snackbar + kembali', (tester) async {
      final products = await pumpForm(tester);

      await tester.enterText(find.byKey(const Key('np-code')), 'A1');
      await tester.enterText(find.byKey(const Key('np-name')), 'Kopi Baru');
      await tester.tap(find.byKey(const Key('np-save')));
      await tester.pumpAndSettle();

      expect(products.created.single.price, 0);
      expect(products.created.single.toRpcParams()['p_price'], 0);
      expect(find.descendant(of: find.byKey(const Key('np-code')), matching: find.text('Kode barang sudah dipakai')), findsOneWidget);
      expect(find.byType(NewProductScreen), findsOneWidget);

      await tester.enterText(find.byKey(const Key('np-code')), 'Z9');
      await tester.enterText(find.byKey(const Key('np-qty')), '6');
      await tester.tap(find.byKey(const Key('np-save')));
      await tester.pumpAndSettle();

      expect(products.created.last.toRpcParams(), containsPair('p_qty', 6));
      expect(products.created.last.price, 0);
      expect(find.byType(NewProductScreen), findsNothing);
      expect(find.text('Produk Kopi Baru tersimpan'), findsOneWidget);
    });

    testWidgets('pesan server lain tampil apa adanya; jaringan putus -> belum pasti', (tester) async {
      final products = await pumpForm(tester);
      await tester.enterText(find.byKey(const Key('np-code')), 'Z9');
      await tester.enterText(find.byKey(const Key('np-name')), 'Kopi Baru');

      products.nextError = const AppException('Kategori tidak ditemukan');
      await tester.tap(find.byKey(const Key('np-save')));
      await tester.pumpAndSettle();
      expect(find.text('Kategori tidak ditemukan'), findsOneWidget);

      products.nextError = const NetworkException(uncertainSaveMessage);
      await tester.tap(find.byKey(const Key('np-save')));
      await tester.pumpAndSettle();
      expect(find.text(uncertainSaveMessage), findsOneWidget);
      expect(products.created.length, 2, reason: 'tidak diulang otomatis');
    });

    testWidgets('gudang tidak melihat kolom harga/modal', (tester) async {
      await pumpForm(tester);
      final labels = tester.widgetList<TextField>(find.byType(TextField)).map((t) => (t.decoration?.labelText ?? '').toLowerCase());
      expect(labels, isNotEmpty);
      for (final l in labels) {
        expect(l.contains('harga') || l.contains('modal'), isFalse, reason: l);
      }
      expect(find.textContaining('Rp'), findsNothing);
    });
  });

  testWidgets('tab Produk: gudang tanpa harga + tombol primer "Produk baru" ke form gudang', (tester) async {
    _tallView(tester);
    await pumpApp(tester, const StockListScreen(title: 'Produk'),
        stock: FakeStockRepository([row(1, 'A', 5)]), products: FakeProductRepository());
    await tester.pumpAndSettle();
    expect(find.text('Barang A'), findsOneWidget);
    expect(find.text('Rp 3.500'), findsNothing);

    await tester.tap(find.byKey(const Key('stock-new-product')));
    await tester.pumpAndSettle();
    expect(find.byType(NewProductScreen), findsOneWidget);
  });

  testWidgets('tab Stok: owner melihat harga jual', (tester) async {
    _tallView(tester);
    await pumpApp(tester, const StockListScreen(), role: AppRole.owner, stock: FakeStockRepository([row(1, 'A', 5)]), products: FakeProductRepository());
    await tester.pumpAndSettle();
    expect(find.text('Rp 3.500'), findsOneWidget);
  });
}
