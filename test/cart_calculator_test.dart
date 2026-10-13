import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/data/cart_calculator.dart';
import 'package:minimarket_pos/data/transaction_model.dart';

void main() {
  group('calculateTotal', () {
    test('keranjang kosong bernilai 0', () {
      expect(calculateTotal([]), 0.0);
    });

    test('menjumlahkan subtotal semua item', () {
      final cart = [
        CartItem(productId: 'A1', productName: 'Indomie', price: 3500, quantity: 4),
        CartItem(productId: 'A2', productName: 'Teh Botol', price: 5000, quantity: 2),
      ];
      expect(calculateTotal(cart), 24000.0);
    });
  });

  group('calculateChange', () {
    test('kembalian = bayar - total', () {
      expect(calculateChange(total: 24000, paid: 50000), 26000.0);
    });

    test('uang pas menghasilkan kembalian 0', () {
      expect(calculateChange(total: 24000, paid: 24000), 0.0);
    });
  });
}
