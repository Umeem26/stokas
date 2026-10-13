import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/uuid.dart';
import 'cart_calculator.dart';
import 'providers.dart';
import 'stock_availability.dart';
import 'transaction_model.dart';

/// Pembuat kunci idempotensi (UUID v4); bisa di-override di tes.
final idempotencyKeyFactoryProvider = Provider<String Function()>((ref) => uuidV4);

class CheckoutState {
  final List<CartItem> items;

  /// Kunci untuk isi keranjang ini. Dipakai ulang saat bayar diulang (mis. setelah gagal
  /// jaringan) agar server tidak mencatat transaksi ganda; diganti saat isi keranjang berubah.
  final String idempotencyKey;
  final bool isPaying;

  const CheckoutState({required this.items, required this.idempotencyKey, this.isPaying = false});

  int get total => calculateTotal(items);

  num quantityOf(String productId) {
    for (final i in items) {
      if (i.productId == productId) return i.quantity;
    }
    return 0;
  }
}

class CheckoutController extends Notifier<CheckoutState> {
  @override
  CheckoutState build() => CheckoutState(items: const [], idempotencyKey: _newKey());

  String _newKey() => ref.read(idempotencyKeyFactoryProvider)();

  void _setItems(List<CartItem> items) {
    state = CheckoutState(items: List.unmodifiable(items), idempotencyKey: _newKey());
  }

  /// Tambah 1 [product] ke keranjang. Mengembalikan pesan (mis. "Stok tersisa 3") bila
  /// melebihi stok tersedia atau sedang memproses bayar; null jika berhasil.
  String? add(SellableProduct product) {
    if (state.isPaying) return 'Pembayaran sedang diproses';
    final inCart = state.quantityOf(product.id);
    final error = cartAddError(inCart: inCart, available: product.available);
    if (error != null) return error;

    final items = [...state.items];
    final index = items.indexWhere((i) => i.productId == product.id);
    if (index >= 0) {
      items[index] = items[index].copyWith(quantity: inCart + 1);
    } else {
      items.add(CartItem(productId: product.id, productName: product.name, price: product.price));
    }
    _setItems(items);
    return null;
  }

  /// Kurangi 1; item dibuang bila jumlahnya habis.
  void decrement(String productId) {
    if (state.isPaying) return;
    final items = [...state.items];
    final index = items.indexWhere((i) => i.productId == productId);
    if (index < 0) return;
    final qty = items[index].quantity;
    if (qty > 1) {
      items[index] = items[index].copyWith(quantity: qty - 1);
    } else {
      items.removeAt(index);
    }
    _setItems(items);
  }

  /// Bayar dengan uang [paid] (Rupiah). Sukses: keranjang dikosongkan & kunci baru.
  /// Gagal: keranjang dan kunci tetap, sehingga percobaan ulang aman. Panggilan saat
  /// pembayaran masih berjalan (tap ganda) mengembalikan null tanpa memanggil server.
  Future<TransactionModel?> pay(int paid) async {
    if (state.isPaying || state.items.isEmpty) return null;
    final attempt = state;
    state = CheckoutState(items: attempt.items, idempotencyKey: attempt.idempotencyKey, isPaying: true);
    try {
      final tx = await ref.read(transactionRepositoryProvider).checkout(
            idempotencyKey: attempt.idempotencyKey,
            items: attempt.items,
            paid: paid,
          );
      if (ref.mounted) _setItems(const []);
      return tx;
    } catch (_) {
      if (ref.mounted) state = attempt;
      rethrow;
    }
  }
}

final checkoutControllerProvider =
    NotifierProvider.autoDispose<CheckoutController, CheckoutState>(CheckoutController.new);
