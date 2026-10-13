import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/data/product_model.dart';
import 'package:minimarket_pos/data/transaction_model.dart';

void main() {
  group('ProductModel.fromMap', () {
    test('membaca semua kolom dari Supabase', () {
      final p = ProductModel.fromMap({
        'id': '8991234567890',
        'brand_name': 'Indomie Goreng',
        'category_id': 3,
        'unit_type': 'pcs',
        'min_stock': 5,
        'price': 3500,
        'capital_price': 3000,
      });

      expect(p.id, '8991234567890');
      expect(p.brandName, 'Indomie Goreng');
      expect(p.categoryId, 3);
      expect(p.unitType, 'pcs');
      expect(p.minStock, 5.0);
      expect(p.price, 3500.0);
      expect(p.capitalPrice, 3000.0);
    });

    test('numeric desimal dari Postgres tetap terbaca sebagai double', () {
      final p = ProductModel.fromMap({
        'id': 'A1',
        'brand_name': 'Gula',
        'category_id': 1,
        'unit_type': 'gram',
        'min_stock': 2.5,
        'price': 15000.0,
        'capital_price': 12500.5,
      });

      expect(p.minStock, 2.5);
      expect(p.capitalPrice, 12500.5);
    });

    test('harga kosong (null) menjadi 0', () {
      final p = ProductModel.fromMap({
        'id': 'A2',
        'brand_name': 'Air Mineral',
        'category_id': 1,
        'unit_type': 'ml',
        'min_stock': 0,
        'price': null,
        'capital_price': null,
      });

      expect(p.price, 0.0);
      expect(p.capitalPrice, 0.0);
    });
  });

  group('TransactionModel', () {
    test('toMap hanya berisi kolom header transaksi', () {
      final t = TransactionModel(
        totalAmount: 10500,
        paidAmount: 20000,
        changeAmount: 9500,
        items: [CartItem(productId: 'A1', productName: 'Gula', price: 10500)],
      );

      expect(t.toMap(), {
        'total_amount': 10500.0,
        'paid_amount': 20000.0,
        'change_amount': 9500.0,
      });
    });

    test('CartItem default quantity 1 dan subtotal = harga x qty', () {
      final item = CartItem(productId: 'A1', productName: 'Gula', price: 3500);
      expect(item.quantity, 1);
      expect(item.subtotal, 3500.0);

      item.quantity = 3;
      expect(item.subtotal, 10500.0);
    });
  });
}
