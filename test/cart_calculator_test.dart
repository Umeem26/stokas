import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/data/cart_calculator.dart';
import 'package:minimarket_pos/data/transaction_model.dart';

void main() {
  group('calculateTotal', () {
    test('keranjang kosong bernilai 0', () {
      expect(calculateTotal([]), 0);
    });

    test('menjumlahkan subtotal semua item (int Rupiah)', () {
      final cart = [
        const CartItem(productId: 'A1', productName: 'Indomie', price: 3500, quantity: 4),
        const CartItem(productId: 'A2', productName: 'Teh Botol', price: 5000, quantity: 2),
      ];
      expect(calculateTotal(cart), 24000);
      expect(calculateTotal(cart), isA<int>());
    });

    test('qty desimal dibulatkan per baris seperti server', () {
      const item = CartItem(productId: 'G', productName: 'Gula curah', price: 14999, quantity: 0.5);
      expect(item.subtotal, 7500); // round(7499.5)
    });
  });

  group('calculateChange', () {
    test('kembalian = bayar - total', () {
      expect(calculateChange(total: 24000, paid: 50000), 26000);
    });

    test('uang pas menghasilkan kembalian 0', () {
      expect(calculateChange(total: 24000, paid: 24000), 0);
    });
  });

  group('cartAddError (batas qty keranjang)', () {
    test('boleh tambah selama belum melebihi stok', () {
      expect(cartAddError(inCart: 0, available: 3), isNull);
      expect(cartAddError(inCart: 2, available: 3), isNull);
    });

    test('menolak melebihi stok dengan pesan "Stok tersisa N"', () {
      expect(cartAddError(inCart: 3, available: 3), 'Stok tersisa 3');
    });

    test('stok habis atau minus -> "Stok tersisa 0"', () {
      expect(cartAddError(inCart: 0, available: 0), 'Stok tersisa 0');
      expect(cartAddError(inCart: 0, available: -2), 'Stok tersisa 0');
    });

    test('stok desimal tampil tanpa .0 berlebih', () {
      expect(cartAddError(inCart: 2, available: 2.0), 'Stok tersisa 2');
      expect(cartAddError(inCart: 1, available: 1.5), 'Stok tersisa 1.5');
    });
  });
}
