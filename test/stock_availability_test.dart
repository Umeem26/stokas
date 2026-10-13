import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/data/stock_availability.dart';

Map<String, dynamic> batch(String productId, num qty,
        {String floor = 'Lantai 1', String? expiry, bool deleted = false, num minStock = 5}) =>
    {
      'product_id': productId,
      'floor_name': floor,
      'expiry_date': expiry,
      'quantity': qty,
      'products': {
        'id': productId,
        'brand_name': 'Barang $productId',
        'price': 3500,
        'min_stock': minStock,
        'unit_type': 'pcs',
        'is_deleted': deleted,
      },
    };

void main() {
  final now = DateTime.utc(2026, 10, 13, 3); // 13 Okt 10:00 WIB

  test('withoutDeleted membuang batch milik produk is_deleted=true', () {
    final rows = [batch('A', 3), batch('B', 4, deleted: true)];
    expect(withoutDeleted(rows).map((r) => r['product_id']), ['A']);
  });

  test('produk terhapus tidak muncul di daftar Kasir', () {
    final products = sellableProducts([batch('A', 3), batch('B', 4, deleted: true)], now);
    expect(products.map((p) => p.id), ['A']);
  });

  test('stok tersedia = jumlah semua batch belum kedaluwarsa lintas lantai', () {
    final products = sellableProducts([
      batch('A', 3, floor: 'Lantai 1', expiry: '2026-12-01'),
      batch('A', 2, floor: 'Lantai 2'),
      batch('A', 10, floor: 'Lantai 2', expiry: '2026-10-12'), // kedaluwarsa kemarin
      batch('A', 1, floor: 'Lantai 1', expiry: '2026-10-13'), // hari ini masih boleh
    ], now);
    expect(products.single.available, 6);
    expect(products.single.floors, ['Lantai 1', 'Lantai 2']);
    expect(products.single.price, 3500);
  });

  test('produk yang semua batch-nya kedaluwarsa tetap tampil dengan stok 0', () {
    final products = sellableProducts([batch('A', 7, expiry: '2026-01-01')], now);
    expect(products.single.available, 0);
    expect(products.single.floors, isEmpty);
    expect(isBatchExpired(batch('A', 7, expiry: '2026-01-01'), now), isTrue);
  });

  test('lowStockCount per produk, tanpa batch kedaluwarsa dan produk terhapus', () {
    final rows = [
      batch('A', 3, minStock: 5), // menipis
      batch('A', 1, floor: 'Lantai 2', minStock: 5),
      batch('B', 4, minStock: 5),
      batch('B', 20, expiry: '2026-10-01', minStock: 5), // kedaluwarsa: tidak menolong -> menipis
      batch('C', 50, minStock: 5), // aman
      batch('D', 0, deleted: true), // terhapus: diabaikan
    ];
    expect(lowStockCount(rows, now), 2);
  });
}
