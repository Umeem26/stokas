import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/data/receipt_pdf.dart';
import 'package:minimarket_pos/data/transaction_model.dart';

ByteData _font(String path) => ByteData.sublistView(File(path).readAsBytesSync());

/// Teks dari PDF tak terkompresi: string hex `<...>` (font Type0) diurai dengan setiap
/// tabel ToUnicode di berkas. Cukup untuk memeriksa kata yang tercetak.
Set<String> _words(Uint8List pdf) {
  final raw = latin1.decode(pdf);
  final maps = <Map<int, int>>[];
  for (final block in RegExp(r'beginbfchar\n([\s\S]*?)endbfchar').allMatches(raw)) {
    maps.add({
      for (final m in RegExp(r'<([0-9A-F]{4})> <([0-9A-F]{4})>').allMatches(block.group(1)!))
        int.parse(m.group(1)!, radix: 16): int.parse(m.group(2)!, radix: 16),
    });
  }
  final words = <String>{};
  for (final m in RegExp(r'<([0-9a-f]{4,})>').allMatches(raw)) {
    final hex = m.group(1)!;
    if (hex.length % 4 != 0) continue;
    final codes = [for (var i = 0; i < hex.length; i += 4) int.parse(hex.substring(i, i + 4), radix: 16)];
    for (final map in maps) {
      if (codes.every(map.containsKey)) words.add(String.fromCharCodes(codes.map((c) => map[c]!)));
    }
  }
  return words;
}

void main() {
  final transaction = TransactionModel(
    id: 42,
    totalAmount: 37500,
    paidAmount: 50000,
    changeAmount: 12500,
    createdAt: DateTime.utc(2026, 10, 13, 7, 30), // 14.30 WIB
    paymentMethod: PaymentMethod.cash,
    items: const [
      TransactionItem(productId: 'A1', productName: 'Marlong 250 ml', quantity: 3, price: 7500, subtotal: 22500),
      TransactionItem(productId: 'B2', productName: 'Kopi Sachet', quantity: 2, price: 7500, subtotal: 15000),
    ],
  );

  Future<Uint8List> build({bool compress = true}) => buildReceiptPdf(
        transaction,
        cashierName: 'Sari',
        regularFont: _font(receiptRegularFontAsset),
        boldFont: _font(receiptBoldFontAsset),
        compress: compress,
      );

  test('menghasilkan PDF (berawalan %PDF)', () async {
    final bytes = await build();
    expect(latin1.decode(bytes.sublist(0, 4)), '%PDF');
  });

  test('memuat nama barang, total, nomor struk, cara bayar, dan waktu WIB', () async {
    final words = _words(await build(compress: false));
    for (final w in ['Marlong', '250', 'ml', 'Kopi', 'Sachet', '37.500', '50.000', '12.500', '000042', 'Tunai', '14.30', 'WIB', 'Sari', 'Terima', 'kasih', 'Toko']) {
      expect(words, contains(w), reason: w);
    }
  });

  test('nama berkas memakai nomor struk', () {
    expect(receiptFileName(transaction), 'struk-000042');
  });
}
