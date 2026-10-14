import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/core/format.dart';
import 'package:minimarket_pos/core/jakarta_time.dart';
import 'package:minimarket_pos/core/uuid.dart';

void main() {
  group('format Rupiah', () {
    test('formatRupiah memakai titik ribuan tanpa desimal', () {
      expect(formatRupiah(0), 'Rp 0');
      expect(formatRupiah(3500), 'Rp 3.500');
      expect(formatRupiah(1250000), 'Rp 1.250.000');
      expect(formatRupiah(-500), '-Rp 500');
    });

    test('parseRupiah membaca isian berformat; kosong = 0', () {
      expect(parseRupiah('1.250.000'), 1250000);
      expect(parseRupiah('Rp 3.500'), 3500);
      expect(parseRupiah(''), 0);
    });

    test('formatQty membuang .0 tetapi mempertahankan pecahan', () {
      expect(formatQty(2), '2');
      expect(formatQty(2.0), '2');
      expect(formatQty(1.5), '1.5');
    });

    test('formatDateParam = yyyy-MM-dd untuk parameter date Postgres', () {
      expect(formatDateParam(DateTime(2026, 3, 7)), '2026-03-07');
    });
  });

  group('"hari ini" Asia/Jakarta', () {
    test('instan yang sama dari zona lain menghasilkan batas yang sama', () {
      final instant = DateTime.utc(2026, 10, 13, 2);
      expect(jakartaDayStartUtc(instant.toLocal()), jakartaDayStartUtc(instant));
      expect(jakartaDayStartUtc(instant), DateTime.utc(2026, 10, 12, 17));
      expect(jakartaDayStartUtc(instant).isUtc, isTrue);
    });

    test('batch kedaluwarsa bila tanggalnya sebelum hari ini WIB', () {
      final now = DateTime.utc(2026, 10, 12, 18); // 13 Okt 01:00 WIB
      expect(isExpiredOn('2026-10-12', now), isTrue);
      expect(isExpiredOn('2026-10-13', now), isFalse); // hari ini masih boleh dijual
      expect(isExpiredOn(null, now), isFalse);
    });
  });

  test('uuidV4 berformat UUID versi 4 dan unik', () {
    final pattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    final a = uuidV4();
    expect(a, matches(pattern));
    expect(uuidV4(), isNot(a));
  });
}
