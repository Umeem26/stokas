import 'package:intl/intl.dart';

final _thousands = NumberFormat('#,##0', 'id_ID');

/// Angka dengan titik ribuan, mis. "1.250.000" (untuk isian uang).
String formatThousands(int amount) => _thousands.format(amount);

/// Satu-satunya format uang di aplikasi: Rupiah bulat, mis. "Rp 1.250.000".
String formatRupiah(int amount) {
  final sign = amount < 0 ? '-' : '';
  return '${sign}Rp ${formatThousands(amount.abs())}';
}

/// Baca input uang ("1.250.000" atau "Rp 1.250.000") menjadi Rupiah bulat; kosong = 0.
int parseRupiah(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? 0 : int.parse(digits);
}

/// Jumlah barang tanpa ".0" bila bulat (numeric Postgres bisa datang sebagai 2.0).
String formatQty(num qty) => qty == qty.roundToDouble() ? qty.round().toString() : qty.toString();

/// Tanggal untuk parameter `date` Postgres (yyyy-MM-dd), memakai tanggal kalender [date].
String formatDateParam(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
