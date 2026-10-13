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

/// Jalankan [action]; error selain [AppException] dibungkus jadi [AppException]
/// dengan [message], dan detail aslinya dicatat lewat debugPrint.
/// Penolakan RLS (Postgres 42501) menjadi [noAccessMessage]; pesan dari
/// `raise exception` di trigger (P0001) diteruskan apa adanya.
Future<T> guard<T>(String message, Future<T> Function() action) async {
  try {
    return await action();
  } on AppException {
    rethrow;
  } on PostgrestException catch (e) {
    debugPrint('❌ $message: $e');
    if (e.code == '42501') throw AppException(noAccessMessage, e);
    if (e.code == 'P0001') throw AppException(e.message, e);
    throw AppException(message, e);
  } catch (e) {
    debugPrint('❌ $message: $e');
    throw AppException(message, e);
  }
}
