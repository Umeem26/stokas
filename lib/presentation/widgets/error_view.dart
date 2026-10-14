import 'package:flutter/material.dart';

import '../../core/app_exception.dart';
import '../design/stokas_button.dart';
import '../design/stokas_tokens.dart';

/// Langkah berikutnya menurut jenis galat: jaringan putus, ditolak server (pesan apa adanya), atau tak dikenal.
String errorHint(Object error) {
  final cause = error is AppException ? error.cause : error;
  if (error is NetworkException || (cause != null && isNetworkError(cause))) {
    return 'Koneksi terputus. Periksa internet lalu coba lagi.';
  }
  return 'Coba lagi sebentar lagi.';
}

/// Tampilan saat data gagal dimuat, dengan tombol "Coba lagi".
class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const ErrorView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    // Galat mentah (bukan AppException) tidak ditampilkan apa adanya.
    final message = error is AppException ? error.toString() : 'Gagal memuat data';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(StokasSpace.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: StokasSpace.s8, color: c.negative),
            const SizedBox(height: StokasSpace.s3),
            Text(message, textAlign: TextAlign.center, style: StokasType.title.copyWith(color: c.ink)),
            const SizedBox(height: StokasSpace.s1),
            Text(errorHint(error), textAlign: TextAlign.center, style: StokasType.body.copyWith(color: c.inkMuted)),
            const SizedBox(height: StokasSpace.s4),
            StokasButton.secondary(label: 'Coba lagi', icon: Icons.refresh, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
