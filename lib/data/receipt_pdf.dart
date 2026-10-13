import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/config.dart';
import '../core/format.dart';
import '../core/jakarta_time.dart';
import 'transaction_model.dart';

/// Lokasi font Inter yang dibundel (sama dengan pubspec `fonts:`); dipakai di struk PDF.
const receiptRegularFontAsset = 'assets/fonts/Inter-Regular.ttf';
const receiptBoldFontAsset = 'assets/fonts/Inter-SemiBold.ttf';

/// Nama file struk tanpa ekstensi, mis. "struk-000123".
String receiptFileName(TransactionModel t) => 'struk-${t.receiptNumber}';

/// Struk PDF selebar kertas 80 mm (tinggi mengikuti isi) dari transaksi tersimpan:
/// nama & harga barang adalah snapshot server, bukan isi keranjang.
/// [compress] hanya dimatikan di tes agar isi teks bisa diperiksa.
Future<Uint8List> buildReceiptPdf(
  TransactionModel t, {
  required String cashierName,
  required ByteData regularFont,
  required ByteData boldFont,
  String store = storeName,
  bool compress = true,
}) {
  final regular = pw.Font.ttf(regularFont);
  final bold = pw.Font.ttf(boldFont);
  final doc = pw.Document(
    compress: compress,
    title: 'Struk ${t.receiptNumber}',
    creator: 'Stokas',
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );

  const small = pw.TextStyle(fontSize: 8);
  const body = pw.TextStyle(fontSize: 9);
  final strong = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
  final divider = pw.Divider(height: 10, thickness: 0.5, borderStyle: pw.BorderStyle.dashed);

  pw.Widget row(String label, String value, {pw.TextStyle? style}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(
          children: [
            pw.Expanded(child: pw.Text(label, style: style ?? body)),
            pw.Text(value, style: style ?? body, textAlign: pw.TextAlign.right),
          ],
        ),
      );

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.roll80,
    build: (context) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(store, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        row('No. struk', t.receiptNumber, style: small),
        row('Waktu', formatWibDateTime(t.createdAt), style: small),
        row('Kasir', cashierName.isEmpty ? '-' : cashierName, style: small),
        divider,
        for (final item in t.items)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(item.productName, style: body),
                row('${formatQty(item.quantity)} × ${formatRupiah(item.price)}', formatRupiah(item.subtotal)),
              ],
            ),
          ),
        divider,
        row('Total', formatRupiah(t.totalAmount), style: strong),
        row('Cara bayar', t.paymentMethod.label),
        row('Diterima', formatRupiah(t.paidAmount)),
        row('Kembalian', formatRupiah(t.changeAmount)),
        divider,
        pw.Text('Terima kasih', textAlign: pw.TextAlign.center, style: body),
      ],
    ),
  ));
  return doc.save();
}
