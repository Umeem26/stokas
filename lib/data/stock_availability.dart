import '../core/jakarta_time.dart';

// Baris stok = satu batch per (produk, lantai, tanggal kedaluwarsa), beserta `products`.

bool _isDeleted(Map<String, dynamic> row) => (row['products'] as Map?)?['is_deleted'] == true;

/// Buang batch milik produk yang sudah dihapus (soft delete). Query sudah menyaring;
/// ini lapisan pengaman agar barang terhapus tidak pernah tampil/dijual.
List<Map<String, dynamic>> withoutDeleted(List<Map<String, dynamic>> rows) =>
    rows.where((r) => !_isDeleted(r)).toList();

/// Batch kedaluwarsa (tanggal acuan Asia/Jakarta).
bool isBatchExpired(Map<String, dynamic> row, DateTime now) => isExpiredOn(row['expiry_date'] as String?, now);

/// Barang yang bisa dijual di Kasir, dengan stok tersedia = jumlah batch yang belum kedaluwarsa.
class SellableProduct {
  final Map<String, dynamic> product;
  final num available;
  final List<String> floors;

  const SellableProduct({required this.product, required this.available, required this.floors});

  String get id => product['id'];
  String get name => product['brand_name'];
  int get price => (product['price'] as num?)?.round() ?? 0;
}

/// Kelompokkan batch per produk (urutan kemunculan pertama dipertahankan).
List<SellableProduct> sellableProducts(List<Map<String, dynamic>> rows, DateTime now) {
  final products = <String, Map<String, dynamic>>{};
  final available = <String, num>{};
  final floors = <String, Set<String>>{};
  for (final row in withoutDeleted(rows)) {
    final product = Map<String, dynamic>.from(row['products'] as Map);
    final id = product['id'] as String;
    products.putIfAbsent(id, () => product);
    available.putIfAbsent(id, () => 0);
    floors.putIfAbsent(id, () => <String>{});
    if (isBatchExpired(row, now)) continue;
    final qty = row['quantity'] as num? ?? 0;
    available[id] = available[id]! + qty;
    if (qty > 0) floors[id]!.add(row['floor_name'] as String);
  }
  return [
    for (final id in products.keys)
      SellableProduct(product: products[id]!, available: available[id]!, floors: floors[id]!.toList()..sort()),
  ];
}
