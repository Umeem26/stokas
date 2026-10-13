/// Toko beroperasi di Asia/Jakarta (WIB, UTC+7, tanpa DST). Server memakai zona yang
/// sama untuk "hari ini" (stok kedaluwarsa di RPC checkout).
const jakartaOffset = Duration(hours: 7);

/// Tanggal kalender Jakarta untuk instan [now] (zona apa pun), sebagai DateTime UTC jam 00:00.
DateTime jakartaToday(DateTime now) {
  final wib = now.toUtc().add(jakartaOffset);
  return DateTime.utc(wib.year, wib.month, wib.day);
}

/// Tengah malam Jakarta hari ini, sebagai instan UTC.
DateTime jakartaDayStartUtc(DateTime now) => jakartaToday(now).subtract(jakartaOffset);

/// Batas [mulai, akhir) "hari ini" dalam ISO-8601 UTC untuk filter `created_at`.
({String start, String end}) jakartaTodayRangeIso(DateTime now) {
  final start = jakartaDayStartUtc(now);
  return (start: start.toIso8601String(), end: start.add(const Duration(days: 1)).toIso8601String());
}

/// Batch kedaluwarsa bila tanggalnya sebelum hari ini (Jakarta); tanggal hari ini masih boleh dijual.
bool isExpiredOn(String? expiryDate, DateTime now) {
  if (expiryDate == null || expiryDate.isEmpty) return false;
  final d = DateTime.parse(expiryDate.substring(0, 10));
  return DateTime.utc(d.year, d.month, d.day).isBefore(jakartaToday(now));
}
