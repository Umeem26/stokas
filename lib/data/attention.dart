import '../core/format.dart';
import '../core/jakarta_time.dart';
import 'stock_availability.dart';

/// Batch dianggap hampir kedaluwarsa bila tanggalnya <= sekian hari dari hari ini (WIB).
const nearExpiryDays = 14;

/// Jumlah baris maksimum di daftar "Perlu diurus".
const attentionLimit = 5;

/// Jenis masalah, berurutan dari yang paling mendesak.
enum AttentionKind { expired, nearExpiry, belowMin, noPrice }

class AttentionItem {
  final AttentionKind kind;
  final Map<String, dynamic> product;
  final String detail;

  const AttentionItem({required this.kind, required this.product, required this.detail});

  String get productId => product['id'] as String;
  String get name => '${product['brand_name']}';
}

bool _active(Map<String, dynamic> p) => p['is_deleted'] != true;

/// Selisih hari kalender dari hari ini (WIB) ke [expiryDate] (yyyy-MM-dd); negatif = sudah lewat.
int daysUntilExpiry(String expiryDate, DateTime now) {
  final d = DateTime.parse(expiryDate.substring(0, 10));
  return DateTime.utc(d.year, d.month, d.day).difference(jakartaToday(now)).inDays;
}

String _batchDetail(Map<String, dynamic> batch, Map<String, dynamic> product) {
  final d = DateTime.parse((batch['expiry_date'] as String).substring(0, 10));
  return '${batch['floor_name']} · ${formatDayId(d)} · ${formatQty(batch['quantity'] as num)} ${product['unit_type'] ?? ''}'.trim();
}

/// Daftar "Perlu diurus" (maks [limit]): batch kedaluwarsa (qty > 0) -> batch hampir kedaluwarsa
/// (<= [nearExpiryDays] hari) -> produk dengan stok layak jual < min_stock -> harga belum diatur (0).
/// [products] = produk aktif; [stockRows] = batch beserta `products`. Produk terhapus diabaikan.
List<AttentionItem> attentionItems({
  required List<Map<String, dynamic>> products,
  required List<Map<String, dynamic>> stockRows,
  required DateTime now,
  int limit = attentionLimit,
}) {
  final byId = {for (final p in products.where(_active)) p['id'] as String: p};
  final batches = [
    for (final r in withoutDeleted(stockRows))
      if (byId.containsKey(r['product_id']) && (r['quantity'] as num? ?? 0) > 0) r,
  ];

  final expired = <(int, AttentionItem)>[];
  final nearExpiry = <(int, AttentionItem)>[];
  final available = {for (final id in byId.keys) id: 0 as num};
  for (final b in batches) {
    final product = byId[b['product_id']]!;
    final expiry = b['expiry_date'] as String?;
    final days = expiry == null || expiry.isEmpty ? null : daysUntilExpiry(expiry, now);
    if (days != null && days < 0) {
      expired.add((days, AttentionItem(kind: AttentionKind.expired, product: product, detail: _batchDetail(b, product))));
      continue; // batch kedaluwarsa tidak dihitung sebagai stok layak jual
    }
    available[product['id']] = available[product['id']]! + (b['quantity'] as num);
    if (days != null && days <= nearExpiryDays) {
      nearExpiry.add((days, AttentionItem(kind: AttentionKind.nearExpiry, product: product, detail: _batchDetail(b, product))));
    }
  }

  int byName(Map<String, dynamic> a, Map<String, dynamic> b) => '${a['brand_name']}'.compareTo('${b['brand_name']}');
  int byDays((int, AttentionItem) a, (int, AttentionItem) b) {
    final c = a.$1.compareTo(b.$1);
    return c != 0 ? c : byName(a.$2.product, b.$2.product);
  }

  final sorted = byId.values.toList()..sort(byName);
  final belowMin = [
    for (final p in sorted)
      if (available[p['id']]! < ((p['min_stock'] as num?) ?? 0))
        AttentionItem(
          kind: AttentionKind.belowMin,
          product: p,
          detail: 'sisa ${formatQty(available[p['id']]!)}, batas minimum ${formatQty(p['min_stock'] as num)}',
        ),
  ];
  final noPrice = [
    for (final p in sorted)
      if (((p['price'] as num?) ?? 0) == 0) AttentionItem(kind: AttentionKind.noPrice, product: p, detail: 'Kode ${p['id']}'),
  ];

  return [
    ...(expired..sort(byDays)).map((e) => e.$2),
    ...(nearExpiry..sort(byDays)).map((e) => e.$2),
    ...belowMin,
    ...noPrice,
  ].take(limit).toList();
}
