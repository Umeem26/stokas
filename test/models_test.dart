import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/data/product_model.dart';
import 'package:minimarket_pos/data/transaction_model.dart';

void main() {
  group('ProductModel.fromMap', () {
    test('membaca semua kolom dari Supabase (tanpa capital_price)', () {
      final p = ProductModel.fromMap({
        'id': '8991234567890',
        'brand_name': 'Indomie Goreng',
        'category_id': 3,
        'unit_type': 'pcs',
        'min_stock': 5,
        'price': 3500,
      });

      expect(p.id, '8991234567890');
      expect(p.brandName, 'Indomie Goreng');
      expect(p.categoryId, 3);
      expect(p.unitType, 'pcs');
      expect(p.minStock, 5.0);
      expect(p.price, 3500);
      expect(p.price, isA<int>());
    });

    test('min_stock desimal tetap num, harga dibulatkan ke Rupiah', () {
      final p = ProductModel.fromMap({
        'id': 'A1',
        'brand_name': 'Gula',
        'category_id': 1,
        'unit_type': 'gram',
        'min_stock': 2.5,
        'price': 15000.0,
      });

      expect(p.minStock, 2.5);
      expect(p.price, 15000);
    });

    test('harga kosong (null) menjadi 0', () {
      final p = ProductModel.fromMap({
        'id': 'A2',
        'brand_name': 'Air Mineral',
        'category_id': 1,
        'unit_type': 'ml',
        'min_stock': 0,
        'price': null,
      });

      expect(p.price, 0);
    });
  });

  group('TransactionModel', () {
    test('fromCheckoutJson membaca hasil RPC checkout', () {
      final t = TransactionModel.fromCheckoutJson({
        'id': 42,
        'total': 10500,
        'paid': 20000,
        'change': 9500,
        'created_at': '2026-10-13T03:15:00+00:00',
        'items': [
          {'product_id': 'A1', 'name': 'Gula', 'qty': 3, 'price': 3500, 'subtotal': 10500},
        ],
      });

      expect(t.id, 42);
      expect(t.totalAmount, 10500);
      expect(t.paidAmount, 20000);
      expect(t.changeAmount, 9500);
      expect(t.createdAt.isUtc, isFalse);
      expect(t.createdAt.toUtc(), DateTime.utc(2026, 10, 13, 3, 15));
      expect(t.items.single.productName, 'Gula');
      expect(t.items.single.quantity, 3);
      expect(t.items.single.subtotal, 10500);
    });

    test('TransactionItem.fromRow memakai snapshot product_name & price_at_purchase', () {
      final i = TransactionItem.fromRow({
        'product_id': 'A1',
        'product_name': 'Gula Lama',
        'quantity': 1.5,
        'price_at_purchase': 12000,
        'subtotal': 18000,
      });
      expect(i.productName, 'Gula Lama');
      expect(i.quantity, 1.5);
      expect(i.price, 12000);
      expect(i.subtotal, 18000);
    });

    test('CartItem default quantity 1 dan subtotal = harga x qty', () {
      const item = CartItem(productId: 'A1', productName: 'Gula', price: 3500);
      expect(item.quantity, 1);
      expect(item.subtotal, 3500);
      expect(item.copyWith(quantity: 3).subtotal, 10500);
    });
  });
}
