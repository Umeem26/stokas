import '../core/format.dart';
import '../core/jakarta_time.dart';

const pastDateMessage = 'Tanggal ini sudah lewat';

/// Satu baris di layar Terima: satu panggilan RPC restock (produk, lantai, kedaluwarsa, jumlah).
class ReceiveLine {
  final int key; // kunci widget yang stabil
  final String productId;
  final String name;
  final String unit;
  num qty;
  String floor;
  DateTime? expiry; // tanggal kalender; null = tanpa kedaluwarsa
  String? error; // pesan server terakhir untuk baris ini

  ReceiveLine({
    required this.key,
    required this.productId,
    required this.name,
    required this.unit,
    required this.floor,
    this.qty = 1,
    this.expiry,
  });
}

/// Tanggal [expiry] sebelum hari ini (WIB). Hari ini masih boleh.
bool isPastDate(DateTime? expiry, DateTime now) => expiry != null && isExpiredOn(formatDateParam(expiry), now);

/// Masalah baris yang membuat Simpan nonaktif; null bila baris benar.
String? lineProblem(ReceiveLine line, DateTime now) {
  if (line.qty <= 0) return 'Jumlah harus lebih dari 0';
  if (isPastDate(line.expiry, now)) return pastDateMessage;
  return null;
}

/// Alasan tombol Simpan nonaktif (ditulis di bawah tombol); null bila boleh disimpan.
String? saveBlockReason(List<ReceiveLine> lines, DateTime now) {
  if (lines.isEmpty) return 'Belum ada barang. Scan kode atau cari nama barang.';
  final past = lines.where((l) => l.qty > 0 && isPastDate(l.expiry, now)).length;
  final zero = lines.where((l) => l.qty <= 0).length;
  if (past == 0 && zero == 0) return null;
  final parts = [
    if (past > 0) '$past baris bertanggal kedaluwarsa yang sudah lewat',
    if (zero > 0) '$zero baris berjumlah 0',
  ];
  return 'Belum bisa disimpan: ${parts.join(', ')}.';
}
