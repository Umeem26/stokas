import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/core/app_exception.dart';
import 'package:minimarket_pos/presentation/widgets/error_view.dart';

void main() {
  test('guard membungkus error mentah menjadi AppException ramah', () async {
    await expectLater(
      guard<void>('Gagal memuat data stok', () async => throw StateError('socket closed')),
      throwsA(isA<AppException>().having((e) => e.toString(), 'pesan', 'Gagal memuat data stok')),
    );
  });

  test('guard meneruskan AppException apa adanya', () async {
    await expectLater(
      guard<void>('Gagal memindahkan stok', () async => throw const AppException('Stok tidak cukup!')),
      throwsA(isA<AppException>().having((e) => e.message, 'pesan', 'Stok tidak cukup!')),
    );
  });

  testWidgets('ErrorView menampilkan pesan dan memanggil onRetry', (tester) async {
    var retried = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ErrorView(error: const AppException('Gagal memuat riwayat transaksi'), onRetry: () => retried++),
      ),
    ));

    expect(find.text('Gagal memuat riwayat transaksi'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    expect(retried, 1);
  });
}
