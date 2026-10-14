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

/// Batch kedaluwarsa bila tanggalnya sebelum hari ini (Jakarta); tanggal hari ini masih boleh dijual.
bool isExpiredOn(String? expiryDate, DateTime now) {
  if (expiryDate == null || expiryDate.isEmpty) return false;
  final d = DateTime.parse(expiryDate.substring(0, 10));
  return DateTime.utc(d.year, d.month, d.day).isBefore(jakartaToday(now));
}

const _monthsId = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

/// Tanggal kalender [date] (tanpa konversi zona), mis. "13 Okt 2026".
String formatDayId(DateTime date) => '${date.day} ${_monthsId[date.month - 1]} ${date.year}';

/// Hari ini (Jakarta) sebagai DateTime lokal jam 00:00, untuk date picker.
DateTime jakartaTodayLocal(DateTime now) {
  final d = jakartaToday(now);
  return DateTime(d.year, d.month, d.day);
}

/// Waktu struk dalam WIB, mis. "13 Okt 2026 14.30 WIB" (24 jam, titik pemisah), zona perangkat diabaikan.
String formatWibDateTime(DateTime instant) {
  final t = instant.toUtc().add(jakartaOffset);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${formatDayId(t)} ${two(t.hour)}.${two(t.minute)} WIB';
}
