import 'package:flutter/foundation.dart';

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
Future<T> guard<T>(String message, Future<T> Function() action) async {
  try {
    return await action();
  } on AppException {
    rethrow;
  } catch (e) {
    debugPrint('❌ $message: $e');
    throw AppException(message, e);
  }
}
