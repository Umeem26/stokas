import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/core/app_exception.dart';
import 'package:minimarket_pos/data/checkout_controller.dart';
import 'package:minimarket_pos/data/providers.dart';
import 'package:minimarket_pos/data/stock_availability.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes.dart';

SellableProduct product(String id, {num available = 10, int price = 3500}) => SellableProduct(
      product: {'id': id, 'brand_name': 'Barang $id', 'price': price},
      available: available,
      floors: const ['Lantai 1'],
    );

void main() {
  late FakeTransactionRepository repo;
  late ProviderContainer container;
  late int keySeq;

  CheckoutController controller() => container.read(checkoutControllerProvider.notifier);
  CheckoutState state() => container.read(checkoutControllerProvider);

  setUp(() {
    repo = FakeTransactionRepository();
    keySeq = 0;
    container = ProviderContainer(overrides: [
      transactionRepositoryProvider.overrideWithValue(repo),
      idempotencyKeyFactoryProvider.overrideWithValue(() => 'key-${++keySeq}'),
    ]);
    // Jaga provider autoDispose tetap hidup selama tes.
    final sub = container.listen(checkoutControllerProvider, (_, _) {});
    addTearDown(() {
      sub.close();
      container.dispose();
    });
  });

  group('batas qty keranjang', () {
    test('tambah ditolak saat melebihi stok tersedia', () {
      final p = product('A', available: 2);
      expect(controller().add(p), isNull);
      expect(controller().add(p), isNull);
      expect(controller().add(p), 'Stok tersisa 2');
      expect(state().quantityOf('A'), 2);
      expect(state().total, 7000);
    });

    test('stok 0 (mis. semua batch kedaluwarsa) tidak bisa masuk keranjang', () {
      expect(controller().add(product('A', available: 0)), 'Stok tersisa 0');
      expect(state().items, isEmpty);
    });
  });

  group('kunci idempotensi', () {
    test('berganti setiap kali isi keranjang berubah (tambah/kurang)', () {
      final k0 = state().idempotencyKey;
      controller().add(product('A'));
      final k1 = state().idempotencyKey;
      controller().add(product('A'));
      final k2 = state().idempotencyKey;
      controller().decrement('A');
      final k3 = state().idempotencyKey;
      expect({k0, k1, k2, k3}.length, 4);
    });

    test('dipakai ulang saat bayar diulang untuk keranjang yang sama setelah gagal jaringan', () async {
      controller().add(product('A'));
      final key = state().idempotencyKey;

      repo.nextError = const AppException('Gagal memproses pembayaran. Coba lagi.');
      await expectLater(controller().pay(5000), throwsA(isA<AppException>()));
      expect(state().items, hasLength(1), reason: 'keranjang tidak hilang');
      expect(state().idempotencyKey, key);
      expect(state().isPaying, isFalse);

      final tx = await controller().pay(5000);
      expect(tx, isNotNull);
      expect(repo.calls.map((c) => c.key), [key, key]);
      expect(repo.transactionCount, 1);
    });

    test('kunci baru dan keranjang kosong setelah sukses', () async {
      controller().add(product('A'));
      final key = state().idempotencyKey;
      final tx = await controller().pay(10000);

      expect(tx!.totalAmount, 3500);
      expect(tx.changeAmount, 6500);
      expect(state().items, isEmpty);
      expect(state().idempotencyKey, isNot(key));

      controller().add(product('B'));
      await controller().pay(10000);
      expect(repo.calls.map((c) => c.key).toSet(), hasLength(2));
      expect(repo.transactionCount, 2);
    });

    test('keranjang diubah setelah gagal -> kunci baru dipakai', () async {
      controller().add(product('A'));
      final first = state().idempotencyKey;
      repo.nextError = const AppException('Gagal');
      await expectLater(controller().pay(10000), throwsA(isA<AppException>()));

      controller().add(product('A'));
      await controller().pay(10000);
      expect(repo.calls.last.key, isNot(first));
    });
  });

  test('tap ganda: bayar kedua selama proses diabaikan, keranjang terkunci', () async {
    controller().add(product('A'));
    repo.gate = Completer<void>();

    final first = controller().pay(5000);
    expect(state().isPaying, isTrue);
    expect(await controller().pay(5000), isNull);
    expect(controller().add(product('B')), 'Pembayaran sedang diproses');
    controller().decrement('A');
    expect(state().quantityOf('A'), 1);

    repo.gate!.complete();
    expect(await first, isNotNull);
    expect(repo.calls, hasLength(1));
    expect(state().isPaying, isFalse);
  });

  test('payload checkout berisi product_id, qty, dan uang bayar int', () async {
    controller().add(product('A', price: 1500));
    controller().add(product('A', price: 1500));
    controller().add(product('B', price: 2000));
    await controller().pay(10000);

    final call = repo.calls.single;
    expect(call.paid, 10000);
    expect({for (final i in call.items) i.productId: i.quantity}, {'A': 2, 'B': 1});
  });

  group('pemetaan error RPC checkout', () {
    test('stok kurang (P0001 + hint) -> InsufficientStockException dengan product_id', () {
      final e = mapCheckoutError(const PostgrestException(
        message: 'Stok tidak cukup: Indomie Goreng (tersedia 2)',
        code: 'P0001',
        hint: '8991234567890',
      ));
      expect(e, isA<InsufficientStockException>());
      expect(e.message, 'Stok tidak cukup: Indomie Goreng (tersedia 2)');
      expect((e as InsufficientStockException).productId, '8991234567890');
    });

    test('pesan server lain (P0001) ditampilkan apa adanya', () {
      for (final msg in ['Uang bayar kurang dari total', 'Barang tidak ditemukan: X1', 'Keranjang kosong atau tidak valid']) {
        final e = mapCheckoutError(PostgrestException(message: msg, code: 'P0001'));
        expect(e, isNot(isA<InsufficientStockException>()), reason: msg);
        expect(e.message, msg);
      }
    });

    test('42501 -> pesan tanpa akses', () {
      final e = mapCheckoutError(const PostgrestException(message: 'Anda tidak punya akses untuk transaksi', code: '42501'));
      expect(e.message, noAccessMessage);
    });

    test('error jaringan/tak dikenal -> pesan umum, bukan detail teknis', () {
      final e = mapCheckoutError(Exception('SocketException: Failed host lookup'));
      expect(e.message, 'Gagal memproses pembayaran. Coba lagi.');
    });
  });
}
