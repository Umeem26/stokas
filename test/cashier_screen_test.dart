import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/core/app_exception.dart';
import 'package:minimarket_pos/core/permissions.dart';
import 'package:minimarket_pos/data/checkout_controller.dart';
import 'package:minimarket_pos/data/transaction_model.dart';
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

  Future<void> openPay(WidgetTester tester, List<String> productIds) async {
    for (final id in productIds) {
      await tapKey(tester, ValueKey('product-$id'));
    }
    await tapKey(tester, const Key('pay-button'));
    expect(find.byKey(const Key('pay-panel')), findsOneWidget);
  }

  FilledButton payButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.descendant(of: find.byKey(const Key('pay-confirm')), matching: find.byType(FilledButton)));

  testWidgets('panel bayar 480 px menggantikan keranjang; kiri jadi ringkasan baca-saja; Esc kembali', (tester) async {
    await pumpCashier(tester, _rows);
    await openPay(tester, ['A1', 'B2']);
    expect(tester.getSize(find.byKey(const Key('cashier-pay-panel'))).width, 480);
    expect(find.byKey(const Key('order-summary')), findsOneWidget);
    expect(find.byKey(const Key('cashier-search')), findsNothing, reason: 'kisi produk diganti ringkasan');
    expect(find.byKey(const ValueKey('inc-A1')), findsNothing, reason: 'ringkasan tanpa stepper');
    expect(tester.widget<MoneyText>(find.byKey(const Key('pay-total'))).amount, 15500);
    expect(find.text('Uang pas'), findsOneWidget);
    expect(find.text('Rp 20.000'), findsOneWidget);
    expect(find.text('Rp 50.000'), findsOneWidget);
    expect(find.text('Rp 100.000'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pay-panel')), findsNothing);
    expect(find.byKey(const Key('cashier-cart-panel')), findsOneWidget);
    expect(cartOf(tester).items, hasLength(2));
  });

  testWidgets('Bayar nonaktif dengan alasan saat uang < total; kembalian benar', (tester) async {
    await pumpCashier(tester, _rows);
    await openPay(tester, ['A1', 'B2']); // total 15.500

    expect(payButton(tester).onPressed, isNull);
    expect(find.text('Isi uang diterima dulu'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('paid-field')), '10000');
    await tester.pump();
    expect(payButton(tester).onPressed, isNull);
    expect(tester.widget<Text>(find.byKey(const Key('pay-reason'))).data, 'Uang kurang Rp 5.500');
    expect(tester.widget<MoneyText>(find.byKey(const Key('change-amount'))).amount, 0);

    await tapKey(tester, const ValueKey('quick-20000'));
    expect(payButton(tester).onPressed, isNotNull);
    expect(find.byKey(const Key('pay-reason')), findsNothing);
    expect(tester.widget<MoneyText>(find.byKey(const Key('change-amount'))).amount, 4500);
    expect(find.text('Bayar Rp 15.500'), findsOneWidget);

    await tapKey(tester, const Key('quick-exact'));
    expect(tester.widget<MoneyText>(find.byKey(const Key('change-amount'))).amount, 0);
    expect(payButton(tester).onPressed, isNotNull);
  });

  testWidgets('QRIS: checkout dengan method qris dan paid = total, tombol "Sudah dibayar"', (tester) async {
    final tx = await pumpCashier(tester, _rows);
    await openPay(tester, ['A1', 'C3']); // total 8.500
    await tapKey(tester, const ValueKey('method-qris'));

    expect(find.byKey(const Key('paid-field')), findsNothing, reason: 'QRIS dibayar pas');
    expect(tester.widget<MoneyText>(find.byKey(const Key('paid-exact'))).amount, 8500);
    expect(find.text('Sudah dibayar'), findsOneWidget);

    await tapKey(tester, const Key('pay-confirm'));
    final call = tx.calls.single;
    expect(call.method, PaymentMethod.qris);
    expect(call.paid, 8500);
    expect(find.byKey(const Key('checkout-done')), findsOneWidget);
    expect(find.text('QRIS'), findsOneWidget);
  });

  testWidgets('tombol 1/2/3 memilih cara bayar di luar kolom uang', (tester) async {
    final tx = await pumpCashier(tester, _rows);
    await openPay(tester, ['A1']);
    await tapKey(tester, const ValueKey('method-transfer'));
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pumpAndSettle();
    expect(find.text('Sudah dibayar'), findsOneWidget);
    await tapKey(tester, const Key('pay-confirm'));
    expect(tx.calls.single.method, PaymentMethod.qris);
  });

  testWidgets('gagal jaringan: panel & keranjang utuh, pesan jelas; bayar ulang memakai kunci yang sama', (tester) async {
    final tx = FakeTransactionRepository()..nextError = const NetworkException(checkoutOfflineMessage);
    await pumpCashier(tester, _rows, transactions: tx);
    await openPay(tester, ['A1', 'B2']);
    final before = cartOf(tester);

    await tester.enterText(find.byKey(const Key('paid-field')), '20000');
    await tester.pump();
    await tapKey(tester, const Key('pay-confirm'));

    expect(find.text('Tidak ada koneksi. Keranjang aman, coba lagi.'), findsOneWidget);
    expect(find.byKey(const Key('pay-panel')), findsOneWidget, reason: 'panel tetap');
    expect(tester.widget<TextField>(find.byKey(const Key('paid-field'))).controller!.text, '20.000', reason: 'isian tidak hilang');
    final after = cartOf(tester);
    expect(after.items.map((i) => '${i.productId}x${i.quantity}'), ['A1x1', 'B2x1']);
    expect(after.idempotencyKey, before.idempotencyKey);

    await tapKey(tester, const Key('pay-confirm'));
    expect(find.byKey(const Key('checkout-done')), findsOneWidget);
    expect(tx.calls.map((c) => c.key).toSet(), {before.idempotencyKey});
    expect(tx.transactionCount, 1);
  });

  testWidgets('gagal stok: pesan server apa adanya dan baris bermasalah ditandai', (tester) async {
    final tx = FakeTransactionRepository()
      ..nextError = const InsufficientStockException('Stok tidak cukup: A1 Snack Pedas (tersedia 3)', 'B2');
    await pumpCashier(tester, _rows, transactions: tx);
    await openPay(tester, ['A1', 'B2']);
    await tapKey(tester, const Key('quick-exact'));
    await tapKey(tester, const Key('pay-confirm'));

    expect(find.text('Stok tidak cukup: A1 Snack Pedas (tersedia 3)'), findsOneWidget);
    expect(find.byKey(const ValueKey('summary-problem-B2')), findsOneWidget);
    expect(find.byKey(const ValueKey('summary-problem-A1')), findsNothing);
    expect(cartOf(tester).items, hasLength(2));
  });

  testWidgets('layar selesai: kembalian besar & ringkasan; Transaksi baru -> keranjang kosong + kunci baru', (tester) async {
    await pumpCashier(tester, _rows);
    await openPay(tester, ['A1', 'B2']);
    final key = cartOf(tester).idempotencyKey;
    await tapKey(tester, const ValueKey('quick-50000'));
    await tapKey(tester, const Key('pay-confirm'));

    expect(find.byKey(const Key('checkout-done')), findsOneWidget);
    expect(tester.widget<MoneyText>(find.byKey(const Key('done-change'))).amount, 34500);
    expect(find.text('Tunai'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('done-receipt-no'))).data, '000001');
    expect(find.textContaining('WIB'), findsOneWidget);
    expect(find.text('Unduh struk (PDF)'), findsOneWidget);
    expect(cartOf(tester).items, hasLength(2), reason: 'keranjang dibersihkan lewat Transaksi baru');

    await tapKey(tester, const Key('new-transaction'));
    expect(find.byKey(const Key('checkout-done')), findsNothing);
    expect(cartOf(tester).items, isEmpty);
    expect(cartOf(tester).completed, isNull);
    expect(cartOf(tester).idempotencyKey, isNot(key));
    expect(find.byKey(const Key('cashier-search')), findsOneWidget);
  });

  testWidgets('390 px: Bayar di keranjang membuka panel bayar layar penuh', (tester) async {
    final tx = await pumpCashier(tester, _rows, size: const Size(390, 844));
    await tapKey(tester, const ValueKey('product-A1'));
    await tapKey(tester, const Key('cart-bar'));
    await tapKey(tester, const Key('pay-button'));

    expect(find.byKey(const Key('cart-page')), findsNothing);
    expect(tester.getSize(find.byKey(const Key('cashier-pay-panel'))).width, 390);
    expect(find.text('Lihat pesanan (1 barang)'), findsOneWidget);
    await tapKey(tester, const Key('quick-exact'));
    await tapKey(tester, const Key('pay-confirm'));
    expect(tx.calls.single.paid, 3500);
    expect(find.byKey(const Key('checkout-done')), findsOneWidget);
  });
}
