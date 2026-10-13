import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/receipt_pdf.dart';
import '../data/transaction_model.dart';
import 'design/stokas_tokens.dart';

/// Simpan berkas PDF; mengembalikan lokasi, atau null bila pengguna membatalkan.
typedef ReceiptSaver = Future<String?> Function(String name, Uint8List bytes);

/// Dialog "Simpan sebagai" (Android, desktop) atau unduhan browser (web). Bisa di-override di tes.
final receiptSaverProvider = Provider<ReceiptSaver>(
  (ref) => (name, bytes) => FileSaver.instance.saveAs(name: name, bytes: bytes, fileExtension: 'pdf', mimeType: MimeType.pdf),
);

/// Buat struk PDF dari transaksi tersimpan (lengkap dengan item) lalu simpan.
/// Pesan hasil ditampilkan di SnackBar; batal simpan tidak dianggap gagal.
Future<void> downloadReceipt(BuildContext context, WidgetRef ref, TransactionModel transaction, {required String cashierName}) async {
  final messenger = ScaffoldMessenger.of(context);
  final c = context.stokas;
  void show(String text, IconData icon) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [Icon(icon, color: c.canvas), const SizedBox(width: StokasSpace.s2), Expanded(child: Text(text))]),
    ));

  try {
    final bytes = await buildReceiptPdf(
      transaction,
      cashierName: cashierName,
      regularFont: await rootBundle.load(receiptRegularFontAsset),
      boldFont: await rootBundle.load(receiptBoldFontAsset),
    );
    final path = await ref.read(receiptSaverProvider)(receiptFileName(transaction), bytes);
    if (path != null) show('Struk ${transaction.receiptNumber} disimpan', Icons.check_circle_outline);
  } catch (e) {
    debugPrint('❌ Gagal menyimpan struk: $e');
    show('Struk gagal disimpan. Coba lagi.', Icons.error_outline);
  }
}
