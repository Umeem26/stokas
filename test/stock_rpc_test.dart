import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/core/app_exception.dart';
import 'package:minimarket_pos/core/permissions.dart';
import 'package:minimarket_pos/data/providers.dart';
import 'package:minimarket_pos/data/session.dart';
import 'package:minimarket_pos/presentation/cashier_screen.dart';
import 'package:minimarket_pos/presentation/edit_product_screen.dart';
import 'package:minimarket_pos/presentation/mutation_screen.dart';
import 'package:minimarket_pos/presentation/widgets/stock_adjust_dialog.dart';

import 'fakes.dart';

Map<String, dynamic> row(int id, String productId, num qty, {String floor = 'Lantai 1', String? expiry}) => {
      'id': id,
      'product_id': productId,
      'floor_name': floor,
      'expiry_date': expiry,
      'quantity': qty,
      'products': {
        'id': productId,
        'brand_name': 'Barang $productId',
        'category_id': 1,
        'price': 3500,
        'min_stock': 1,
        'unit_type': 'pcs',
        'is_deleted': false,
      },
    };

Future<void> pumpApp(
  WidgetTester tester,
  Widget home, {
  AppRole role = AppRole.warehouse,
  FakeStockRepository? stock,
  FakeTransactionRepository? transactions,
  FakeProductRepository? products,
}) {
  return tester.pumpWidget(ProviderScope(
    overrides: [
      currentRoleProvider.overrideWithValue(role),
      currentProfileProvider.overrideWithValue(null),
      clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 13, 3)),
      if (stock != null) stockRepositoryProvider.overrideWithValue(stock),
      if (transactions != null) transactionRepositoryProvider.overrideWithValue(transactions),
      if (products != null) productRepositoryProvider.overrideWithValue(products),
    ],
    child: MaterialApp(home: home),
  ));
}

Widget dialogLauncher(StockAdjustMode mode, Map<String, dynamic> stock) => Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showStockAdjustDialog(context, mode: mode, stock: stock),
          child: const Text('buka'),
        ),
      ),
    );

void main() {
  testWidgets('Stok masuk memanggil RPC restock dengan lantai, kedaluwarsa, jumlah, catatan', (tester) async {
    final stock = FakeStockRepository([row(1, 'A', 5, expiry: '2026-12-01')]);
    await pumpApp(tester, dialogLauncher(StockAdjustMode.restock, stock.rows.first), stock: stock);
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('stockAdjustQty')), '12');
    await tester.enterText(find.byKey(const Key('stockAdjustNote')), 'Kiriman supplier');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(stock.calls, ['restock A Lantai 1 2026-12-1 12 Kiriman supplier']);
    expect(stock.rows.first['quantity'], 17);
    expect(find.text('Stok Masuk'), findsNothing, reason: 'dialog tertutup');
  });

  testWidgets('Opname menerima hasil hitung 0 dan memanggil RPC stock_count', (tester) async {
    final stock = FakeStockRepository([row(1, 'A', 5, floor: 'Lantai 2')]);
    await pumpApp(tester, dialogLauncher(StockAdjustMode.opname, stock.rows.first), stock: stock);
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.text('Stok tercatat: 5 pcs'), findsOneWidget);

    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(stock.calls, isEmpty, reason: 'jumlah wajib diisi');

    await tester.enterText(find.byKey(const Key('stockAdjustQty')), '0');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(stock.calls, ['opname A Lantai 2 - 0']);
    expect(stock.rows.first['quantity'], 0);
  });

  testWidgets('Mutasi memanggil RPC transfer_stock (bukan tulis langsung ke stocks)', (tester) async {
    final stock = FakeStockRepository([row(1, 'A', 5, expiry: '2026-12-01')]);
    await pumpApp(tester, MutationScreen(sourceStock: stock.rows.first), stock: stock);

    await tester.enterText(find.byType(TextFormField), '3');
    await tester.tap(find.text('Pindahkan'));
    await tester.pumpAndSettle();

    expect(stock.calls, ['transfer A Lantai 1->Lantai 2 2026-12-1 3']);
    expect(stock.rows.map((r) => [r['floor_name'], r['quantity']]), [
      ['Lantai 1', 2],
      ['Lantai 2', 3],
    ]);
  });

  testWidgets('Kasir: stok kurang dari server -> stok dimuat ulang dan pengguna diberi tahu', (tester) async {
    final stock = FakeStockRepository([row(1, 'A', 5)]);
    final transactions = FakeTransactionRepository()
      ..nextError = const InsufficientStockException('Stok tidak cukup: Barang A (tersedia 1)', 'A');
    await pumpApp(tester, const CashierScreen(), role: AppRole.cashier, stock: stock, transactions: transactions);
    await tester.pumpAndSettle();
    expect(stock.loads, 1);

    await tester.tap(find.byKey(const ValueKey('product-A')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('pay-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('paid-field')), '10000');
    await tester.pump();
    await tester.tap(find.byKey(const Key('pay-confirm')));
    await tester.pumpAndSettle();

    expect(transactions.calls, hasLength(1));
    expect(stock.loads, 2);
    expect(find.text('Stok tidak cukup: Barang A (tersedia 1)'), findsOneWidget, reason: 'pesan server apa adanya');
    expect(find.byKey(const ValueKey('summary-problem-A')), findsOneWidget, reason: 'baris bermasalah ditandai');
    expect(find.text('Barang A'), findsWidgets, reason: 'keranjang tetap');
  });

  testWidgets('Kasir: batch kedaluwarsa tidak dihitung, tambah melebihi stok -> "Stok tersisa N"', (tester) async {
    final stock = FakeStockRepository([
      row(1, 'A', 1),
      row(2, 'A', 9, floor: 'Lantai 2', expiry: '2026-10-01'),
    ]);
    await pumpApp(tester, const CashierScreen(), role: AppRole.cashier, stock: stock);
    await tester.pumpAndSettle();
    expect(find.text('Stok 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('product-A')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('product-A')));
    await tester.pump();
    expect(find.text('Barang A: Stok tersisa 1'), findsOneWidget);
  });

  group('Edit produk gudang tanpa harga', () {
    final productRow = row(1, 'A', 5)['products'] as Map<String, dynamic>;

    testWidgets('gudang tidak membaca maupun melihat harga modal', (tester) async {
      final products = FakeProductRepository()..capitalPrices['A'] = 3000;
      await pumpApp(tester, EditProductScreen(productData: productRow), role: AppRole.warehouse, products: products);
      await tester.pumpAndSettle();

      expect(products.capitalReads, 0);
      expect(find.text('Modal'), findsNothing);
      expect(find.text('3.000'), findsNothing);
      expect(find.textContaining('3.500'), findsNothing);

      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(products.updates.single.$2, isFalse); // harga tidak dikirim
      expect(products.capitalSaves, isEmpty);
    });
  });
}
