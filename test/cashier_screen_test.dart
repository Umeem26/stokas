import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/core/app_exception.dart';
import 'package:minimarket_pos/core/permissions.dart';
import 'package:minimarket_pos/data/checkout_controller.dart';
import 'package:minimarket_pos/presentation/cashier_screen.dart';
import 'package:minimarket_pos/presentation/design/money_text.dart';

import 'fakes.dart';
import 'stock_rpc_test.dart' show pumpApp;

Map<String, dynamic> item(int id, String productId, String name, num qty, {int price = 3500, String category = 'Makanan'}) => {
      'id': id,
      'product_id': productId,
      'floor_name': 'Lantai 1',
      'expiry_date': null,
      'quantity': qty,
      'products': {
        'id': productId,
        'brand_name': name,
        'category_id': 1,
        'price': price,
        'min_stock': 1,
        'unit_type': 'pcs',
        'is_deleted': false,
        'categories': {'id': 1, 'name': category},
      },
    };

Future<FakeTransactionRepository> pumpCashier(
  WidgetTester tester,
  List<Map<String, dynamic>> rows, {
  Size size = const Size(1194, 834),
  FakeTransactionRepository? transactions,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final tx = transactions ?? FakeTransactionRepository();
  await pumpApp(tester, const CashierScreen(), role: AppRole.cashier, stock: FakeStockRepository(rows), transactions: tx);
  await tester.pumpAndSettle();
  return tx;
}

CheckoutState cartOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CashierScreen, skipOffstage: false))).read(checkoutControllerProvider);

Future<void> tapKey(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> scan(WidgetTester tester, String code) async {
  await tester.enterText(find.byKey(const Key('cashier-search')), code);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

final _rows = [
  item(1, 'A1', 'Kopi Sachet', 10),
  item(2, 'B2', 'A1 Snack Pedas', 10, price: 12000, category: 'Snack'),
  item(3, 'C3', 'Teh Botol', 1, price: 5000, category: 'Minuman'),
  item(4, 'D4', 'Gula 1 kg', 0, price: 16000),
];

void main() {
  testWidgets('scan: products.id persis menang atas nama; nama unik ditambah; tak ada -> pesan', (tester) async {
    await pumpCashier(tester, _rows);
    final search = tester.widget<TextField>(find.byKey(const Key('cashier-search')));
    expect(search.focusNode!.hasFocus, isTrue, reason: 'kolom cari autofokus');

    await scan(tester, 'A1');
    expect(cartOf(tester).items.map((i) => i.productId), ['A1'], reason: 'id A1 menang atas nama "A1 Snack Pedas"');
    expect(search.controller!.text, isEmpty);
    expect(search.focusNode!.hasFocus, isTrue, reason: 'siap scan berikutnya');

    await scan(tester, 'teh botol');
    expect(cartOf(tester).quantityOf('C3'), 1);

    await scan(tester, 'ZZZ-404');
    expect(find.text('Barang tidak ditemukan'), findsOneWidget);
    expect(cartOf(tester).items, hasLength(2));
  });

  testWidgets('tambah dua kali = qty 2; stepper tidak melebihi stok', (tester) async {
    await pumpCashier(tester, _rows);
    await tapKey(tester, const ValueKey('product-A1'));
    await tapKey(tester, const ValueKey('product-A1'));
    expect(cartOf(tester).items.single.quantity, 2);
    expect(tester.widget<Text>(find.byKey(const ValueKey('qty-A1'))).data, '2');

    await tapKey(tester, const ValueKey('product-C3'));
    await tapKey(tester, const ValueKey('inc-C3'));
    expect(cartOf(tester).quantityOf('C3'), 1);
    expect(find.text('Teh Botol: Stok tersisa 1'), findsOneWidget);

    await tapKey(tester, const ValueKey('dec-A1'));
    expect(cartOf(tester).quantityOf('A1'), 1);
    await tapKey(tester, const ValueKey('remove-A1'));
    expect(cartOf(tester).quantityOf('A1'), 0);
  });

  testWidgets('produk Habis: nonaktif, berlabel Habis, tidak bisa ditambah (tap maupun scan)', (tester) async {
    await pumpCashier(tester, _rows);
    final card = find.byKey(const ValueKey('product-D4'));
    expect(find.descendant(of: card, matching: find.text('Habis')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.byIcon(Icons.cancel_outlined)), findsOneWidget);
    expect(tester.widget<InkWell>(card).onTap, isNull);

    await tapKey(tester, const ValueKey('product-D4'));
    await scan(tester, 'D4');
    expect(cartOf(tester).items, isEmpty);
    expect(find.text('Gula 1 kg habis'), findsOneWidget);
  });

  testWidgets('total benar dan tombol "Bayar Rp ..."', (tester) async {
    await pumpCashier(tester, _rows);
    await tapKey(tester, const ValueKey('product-A1'));
    await tapKey(tester, const ValueKey('product-A1'));
    await tapKey(tester, const ValueKey('product-B2'));
    await tapKey(tester, const ValueKey('product-C3'));

    expect(tester.widget<MoneyText>(find.byKey(const Key('cart-total'))).amount, 3500 * 2 + 12000 + 5000);
    expect(find.text('Bayar Rp 24.000'), findsOneWidget);
  });

  testWidgets('kosongkan keranjang butuh konfirmasi', (tester) async {
    await pumpCashier(tester, _rows);
    await tapKey(tester, const ValueKey('product-A1'));

    await tapKey(tester, const Key('clear-cart'));
    expect(find.text('Kosongkan keranjang?'), findsOneWidget);
    expect(cartOf(tester).items, hasLength(1));
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(cartOf(tester).items, hasLength(1));

    await tapKey(tester, const Key('clear-cart'));
    await tapKey(tester, const Key('confirm-clear'));
    expect(cartOf(tester).items, isEmpty);
  });

  testWidgets('1194 px: dua panel, keranjang 408 px, kisi 3 kolom, tap target >= 48', (tester) async {
    await pumpCashier(tester, _rows);
    expect(find.byKey(const Key('cashier-two-panel')), findsOneWidget);
    expect(find.byKey(const Key('cart-bar')), findsNothing);
    expect(tester.getSize(find.byKey(const Key('cashier-cart-panel'))).width, 408);

    final first = tester.getTopLeft(find.byKey(const ValueKey('product-A1')));
    final third = tester.getTopLeft(find.byKey(const ValueKey('product-C3')));
    expect(third.dy, first.dy, reason: '3 kartu sebaris');

    await tapKey(tester, const ValueKey('product-A1'));
    for (final key in [const ValueKey('dec-A1'), const ValueKey('inc-A1'), const ValueKey('remove-A1'), const Key('pay-button'), const Key('clear-cart')]) {
      final size = tester.getSize(find.byKey(key));
      expect(size.height, greaterThanOrEqualTo(48), reason: '$key');
      expect(size.width, greaterThanOrEqualTo(48), reason: '$key');
    }
  });

  testWidgets('390 px: satu kolom; bilah keranjang membuka keranjang layar penuh', (tester) async {
    await pumpCashier(tester, _rows, size: const Size(390, 844));
    expect(find.byKey(const Key('cashier-one-column')), findsOneWidget);
    expect(find.byKey(const Key('cashier-cart-panel')), findsNothing);

    await tapKey(tester, const ValueKey('product-A1'));
    expect(find.text('Keranjang (1) · Rp 3.500'), findsOneWidget);

    await tapKey(tester, const Key('cart-bar'));
    expect(find.byKey(const Key('cart-page')), findsOneWidget);
    expect(find.text('Bayar Rp 3.500'), findsOneWidget);
    await tapKey(tester, const ValueKey('inc-A1'));
    expect(cartOf(tester).quantityOf('A1'), 2);
  });

  testWidgets('keranjang utuh setelah error jaringan; bayar ulang memakai kunci yang sama', (tester) async {
    final tx = FakeTransactionRepository()..nextError = const AppException('Tidak ada koneksi');
    await pumpCashier(tester, _rows, transactions: tx);
    await tapKey(tester, const ValueKey('product-A1'));
    await tapKey(tester, const ValueKey('product-B2'));
    final before = cartOf(tester);

    Future<void> pay() async {
      await tapKey(tester, const Key('pay-button'));
      await tester.enterText(find.byKey(const Key('paid-field')), '20000');
      await tester.pump();
      await tapKey(tester, const Key('pay-confirm'));
    }

    await pay();
    expect(find.text('Tidak ada koneksi'), findsOneWidget);
    final after = cartOf(tester);
    expect(after.items.map((i) => '${i.productId}x${i.quantity}'), ['A1x1', 'B2x1']);
    expect(after.idempotencyKey, before.idempotencyKey);
    expect(tester.widget<MoneyText>(find.byKey(const Key('cart-total'))).amount, 15500);

    await pay();
    expect(find.text('Transaksi berhasil'), findsOneWidget);
    expect(tx.calls.map((c) => c.key).toSet(), {before.idempotencyKey});
    expect(tx.transactionCount, 1);
    await tester.tap(find.text('Transaksi baru'));
    await tester.pumpAndSettle();
    expect(cartOf(tester).items, isEmpty);
  });
}
