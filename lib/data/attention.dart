import '../core/format.dart';
import '../core/jakarta_time.dart';
import 'stock_availability.dart';

/// Batch dianggap hampir kedaluwarsa bila tanggalnya <= sekian hari dari hari ini (WIB).
const nearExpiryDays = 14;

/// Jumlah baris maksimum di daftar "Perlu diurus".
const attentionLimit = 5;

/// Jenis masalah, berurutan dari yang paling mendesak.
enum AttentionKind { expired, nearExpiry, belowMin, noPrice }

/// Satu baris "Perlu diurus" = satu barang. [kind] dan [detail] dari kondisi terparahnya;
/// [otherIssues] = jumlah masalah lain barang itu (ditulis "+N masalah lain" di rincian).
class AttentionItem {
  final AttentionKind kind;
  final Map<String, dynamic> product;
  final String detail;
  final int otherIssues;

  const AttentionItem({required this.kind, required this.product, required this.detail, this.otherIssues = 0});

  String get productId => product['id'] as String;
  String get name => '${product['brand_name']}';
}

/// Satu kondisi bermasalah; [days] = selisih hari ke kedaluwarsa (0 untuk jenis tanpa tanggal).
typedef _Issue = ({AttentionKind kind, int days, String detail});

int _bySeverity(_Issue a, _Issue b) {
  final c = a.kind.index.compareTo(b.kind.index);
  return c != 0 ? c : a.days.compareTo(b.days);
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

/// Daftar "Perlu diurus" (maks [limit]), satu baris per barang. Kondisi dari yang terparah:
/// batch kedaluwarsa (qty > 0) -> batch hampir kedaluwarsa (<= [nearExpiryDays] hari) -> stok layak
/// jual < min_stock -> harga belum diatur (0); dalam satu jenis, tanggal paling awal dulu.
/// Baris diurutkan menurut kondisi terparah masing-masing, lalu nama.
/// [products] = produk aktif; [stockRows] = batch beserta `products`. Produk terhapus diabaikan.
List<AttentionItem> attentionItems({
  required List<Map<String, dynamic>> products,
  required List<Map<String, dynamic>> stockRows,
  required DateTime now,
  int limit = attentionLimit,
}) {
  final byId = {for (final p in products.where(_active)) p['id'] as String: p};
  final issues = {for (final id in byId.keys) id: <_Issue>[]};
  final available = {for (final id in byId.keys) id: 0 as num};

  for (final b in withoutDeleted(stockRows)) {
    final product = byId[b['product_id']];
    if (product == null || (b['quantity'] as num? ?? 0) <= 0) continue;
    final id = product['id'] as String;
    final expiry = b['expiry_date'] as String?;
    final days = expiry == null || expiry.isEmpty ? null : daysUntilExpiry(expiry, now);
    if (days != null && days < 0) {
      issues[id]!.add((kind: AttentionKind.expired, days: days, detail: _batchDetail(b, product)));
      continue; // batch kedaluwarsa tidak dihitung sebagai stok layak jual
    }
    available[id] = available[id]! + (b['quantity'] as num);
    if (days != null && days <= nearExpiryDays) {
      issues[id]!.add((kind: AttentionKind.nearExpiry, days: days, detail: _batchDetail(b, product)));
    }
  }

  for (final p in byId.values) {
    final id = p['id'] as String;
    final minStock = (p['min_stock'] as num?) ?? 0;
    if (available[id]! < minStock) {
      issues[id]!.add((
        kind: AttentionKind.belowMin,
        days: 0,
        detail: 'sisa ${formatQty(available[id]!)}, batas minimum ${formatQty(minStock)}',
      ));
    }
    if (((p['price'] as num?) ?? 0) == 0) issues[id]!.add((kind: AttentionKind.noPrice, days: 0, detail: 'Kode $id'));
  }

  final rows = <(_Issue, AttentionItem)>[];
  for (final MapEntry(key: id, value: list) in issues.entries) {
    if (list.isEmpty) continue;
    list.sort(_bySeverity);
    final worst = list.first;
    final others = list.length - 1;
    final detail = others > 0 ? '${worst.detail} · +$others masalah lain' : worst.detail;
    rows.add((worst, AttentionItem(kind: worst.kind, product: byId[id]!, detail: detail, otherIssues: others)));
  }

  rows.sort((a, b) {
    final c = _bySeverity(a.$1, b.$1);
    return c != 0 ? c : a.$2.name.compareTo(b.$2.name);
  });
  return rows.take(limit).map((r) => r.$2).toList();
}
