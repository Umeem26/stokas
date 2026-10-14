import '../core/jakarta_time.dart';

/// Satu transaksi untuk ringkasan omzet: total dan waktu (instan, tersimpan UTC).
typedef RevenueRow = ({int amount, DateTime createdAt});

/// Rentang ambil data omzet: kemarin 00:00 WIB s/d besok 00:00 WIB, sebagai instan UTC.
({DateTime start, DateTime end}) revenueRangeUtc(DateTime now) {
  final today = jakartaDayStartUtc(now);
  return (start: today.subtract(const Duration(days: 1)), end: today.add(const Duration(days: 1)));
}

class RevenueSummary {
  final int todayTotal;
  final int todayCount;
  final int yesterdayTotal;
  final int yesterdayCount;

  const RevenueSummary({
    required this.todayTotal,
    required this.todayCount,
    required this.yesterdayTotal,
    required this.yesterdayCount,
  });

  /// Selisih terhadap kemarin dalam persen (dibulatkan); null bila kemarin tanpa transaksi
  /// atau omzet kemarin 0 (tidak ada dasar perbandingan).
  int? get changePercent {
    if (yesterdayCount == 0 || yesterdayTotal == 0) return null;
    return ((todayTotal - yesterdayTotal) * 100 / yesterdayTotal).round();
  }
}

/// Jumlahkan [rows] per hari kalender WIB untuk instan [now]; baris di luar kemarin/hari ini diabaikan.
RevenueSummary summarizeRevenue(Iterable<RevenueRow> rows, DateTime now) {
  final today = jakartaDayStartUtc(now);
  final yesterday = today.subtract(const Duration(days: 1));
  final tomorrow = today.add(const Duration(days: 1));
  var todayTotal = 0, todayCount = 0, yesterdayTotal = 0, yesterdayCount = 0;
  for (final r in rows) {
    final t = r.createdAt.toUtc();
    if (t.isBefore(yesterday) || !t.isBefore(tomorrow)) continue;
    if (t.isBefore(today)) {
      yesterdayTotal += r.amount;
      yesterdayCount++;
    } else {
      todayTotal += r.amount;
      todayCount++;
    }
  }
  return RevenueSummary(
    todayTotal: todayTotal,
    todayCount: todayCount,
    yesterdayTotal: yesterdayTotal,
    yesterdayCount: yesterdayCount,
  );
}
