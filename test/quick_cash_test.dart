import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/data/quick_cash.dart';

void main() {
  // total -> nominal setelah tombol "Uang pas" (selalu ada, tidak termasuk di daftar).
  const table = <int, List<int>>{
    // Contoh spesifikasi
    37500: [50000, 100000],
    3000: [5000, 10000, 20000],
    120000: [150000, 200000, 250000],
    10000: [20000, 50000, 100000], // 10.000 = Uang pas, deret bergeser ke atas
    // Tepi
    1: [2000, 5000, 10000],
    2000: [5000, 10000, 20000],
    100000: [], // pecahan terbesar = Uang pas; tidak ada yang lebih besar
    100001: [150000, 200000, 250000],
    150000: [200000, 250000, 300000], // kelipatan 50.000 yang sama dengan total dibuang
    // Lain-lain
    99999: [100000],
    50000: [100000],
    0: [],
  };

  for (final MapEntry(key: total, value: expected) in table.entries) {
    test('total $total -> Uang pas + $expected', () {
      final amounts = quickCashAmounts(total);
      expect(amounts, expected);
      expect(amounts.length, lessThanOrEqualTo(3));
      expect(amounts, isNot(contains(total)), reason: 'tidak menduplikasi Uang pas');
      expect(amounts.every((v) => v > total), isTrue, reason: 'setiap tombol menutup total');
    });
  }
}
