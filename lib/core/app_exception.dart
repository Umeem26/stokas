import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const noAccessMessage = 'Anda tidak punya akses untuk aksi ini';

/// Error aplikasi dengan pesan ramah yang aman ditampilkan ke pengguna.
class AppException implements Exception {
  final String message;
  final Object? cause;

  const AppException(this.message, [this.cause]);

  @override
  String toString() => message;
}

/// Checkout ditolak karena stok kurang; [productId] dari hint error server.
class InsufficientStockException extends AppException {
  final String productId;

  const InsufficientStockException(super.message, this.productId, [super.cause]);
}

/// Permintaan tidak sampai ke server (jaringan putus/DNS/timeout).
class NetworkException extends AppException {
  const NetworkException(super.message, [super.cause]);
}

const checkoutOfflineMessage = 'Tidak ada koneksi. Keranjang aman, coba lagi.';

/// RPC tulis tanpa kunci idempotensi (restock, create_product_with_stock): bila jaringan
/// putus, hasilnya tidak diketahui, jadi tidak boleh diulang otomatis.
const uncertainSaveMessage = 'Belum pasti tersimpan. Cek tab Produk sebelum mengulang.';

/// Error dari lapisan HTTP/soket (bukan jawaban server). Dicek lewat nama tipe dan teks
/// karena SocketException (dart:io) dan ClientException (http) tidak tersedia di semua platform.
bool isNetworkError(Object error) {
  if (error is TimeoutException) return true;
  final text = '${error.runtimeType} $error';
  const markers = ['SocketException', 'ClientException', 'HandshakeException', 'Failed host lookup', 'Failed to fetch', 'XMLHttpRequest error'];
  return markers.any(text.contains);
}

/// Terjemahkan [error] menjadi [AppException] berpesan [message].
/// Penolakan akses (Postgres 42501) menjadi [noAccessMessage]; pesan dari
/// `raise exception` (P0001, sudah berbahasa Indonesia) diteruskan apa adanya.
AppException mapError(String message, Object error) {
  if (error is AppException) return error;
  if (error is PostgrestException) {
    if (error.code == '42501') return AppException(noAccessMessage, error);
    if (error.code == 'P0001') return AppException(error.message, error);
  }
  return AppException(message, error);
}

/// Seperti [mapError], tetapi galat jaringan menjadi [NetworkException] berpesan [uncertainSaveMessage].
AppException mapUncertainWriteError(String message, Object error) =>
    isNetworkError(error) ? NetworkException(uncertainSaveMessage, error) : mapError(message, error);

/// Seperti [mapError], ditambah "Stok tidak cukup" (P0001 + hint product_id) dari RPC checkout
/// dan [NetworkException] bila server tidak terjangkau.
AppException mapCheckoutError(Object error) {
  if (isNetworkError(error)) return NetworkException(checkoutOfflineMessage, error);
  if (error is PostgrestException &&
      error.code == 'P0001' &&
      error.message.startsWith('Stok tidak cukup') &&
      (error.hint ?? '').isNotEmpty) {
    return InsufficientStockException(error.message, error.hint!, error);
  }
  return mapError('Gagal memproses pembayaran. Coba lagi.', error);
}

/// Jalankan [action]; error dipetakan lewat [map] (bawaan: [mapError] dengan [message]),
/// dan detail aslinya dicatat lewat debugPrint.
Future<T> guard<T>(String message, Future<T> Function() action, {AppException Function(Object error)? map}) async {
  try {
    return await action();
  } on AppException {
    rethrow;
  } catch (e) {
    debugPrint('❌ $message: $e');
    throw (map ?? (e) => mapError(message, e))(e);
  }
}
