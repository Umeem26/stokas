import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_exception.dart';
import '../../core/config.dart';

const inactiveAccountMessage = 'Akun dinonaktifkan atau tidak ditemukan. Hubungi owner.';
const wrongCredentialsMessage = 'Username/email atau password salah. Periksa lalu coba lagi.';
const networkErrorMessage = 'Tidak ada koneksi. Periksa internet, lalu coba lagi.';
const apiKeyRejectedMessage = 'Konfigurasi aplikasi salah: kunci Supabase tidak diterima.';
const rateLimitedMessage = 'Terlalu banyak percobaan masuk. Tunggu sebentar, lalu coba lagi.';

/// Galat tak dikenal tetap membawa kodenya agar tidak tertukar dengan galat lain.
String unknownSignInMessage(String code) => 'Gagal masuk (kode: $code). Coba lagi atau hubungi owner.';

/// Jenis kegagalan login; layar Login memilih ikon dari sini.
enum SignInFailure { wrongCredentials, network, inactive, apiKey, rateLimited, other }

/// Galat login bertipe dengan pesan ramah (tidak pernah memuat password).
class SignInException extends AppException {
  final SignInFailure failure;

  const SignInException(this.failure, super.message, [super.cause]);
}

/// Perubahan sesi yang relevan untuk gerbang login.
enum AuthChange { signedIn, signedOut }

abstract class AuthRepository {
  /// Id pengguna dari sesi yang tersimpan, atau null jika belum login.
  String? get currentUserId;

  Stream<AuthChange> get changes;

  /// [identifier] berupa username atau email. Gagal -> [AppException] berpesan ramah.
  Future<void> signIn(String identifier, String password);

  Future<void> signOut();
}

/// Terjemahkan error login menjadi pesan Indonesia. Tidak pernah memuat password.
/// Setiap jenis punya pesan sendiri; yang tak dikenal tetap menyebut kodenya.
SignInException mapSignInError(Object error) {
  if (error is AuthRetryableFetchException || error is SocketException || isNetworkError(error)) {
    return SignInException(SignInFailure.network, networkErrorMessage, error);
  }
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (error.code == 'invalid_credentials' || message.contains('invalid login credentials')) {
      return SignInException(SignInFailure.wrongCredentials, wrongCredentialsMessage, error);
    }
    // 401: kunci API ditolak (salah, kosong, atau kunci rahasia dipakai di browser).
    if (error.statusCode == '401' || message.contains('api key')) {
      return SignInException(SignInFailure.apiKey, apiKeyRejectedMessage, error);
    }
    if (error.code == 'user_banned') return SignInException(SignInFailure.inactive, inactiveAccountMessage, error);
    if (error.statusCode == '429' || error.code == 'over_request_rate_limit') {
      return SignInException(SignInFailure.rateLimited, rateLimitedMessage, error);
    }
    final code = error.code ?? (error.statusCode != null ? 'HTTP ${error.statusCode}' : 'auth');
    return SignInException(SignInFailure.other, unknownSignInMessage(code), error);
  }
  return SignInException(SignInFailure.other, unknownSignInMessage('${error.runtimeType}'), error);
}

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;

  SupabaseAuthRepository(this._client);

  @override
  String? get currentUserId => _client.auth.currentSession?.user.id;

  @override
  Stream<AuthChange> get changes => _client.auth.onAuthStateChange
      .map((s) => switch (s.event) {
            AuthChangeEvent.signedIn => AuthChange.signedIn,
            AuthChangeEvent.signedOut => AuthChange.signedOut,
            _ => null,
          })
      .where((c) => c != null)
      .cast<AuthChange>();

  @override
  Future<void> signIn(String identifier, String password) async {
    try {
      await _client.auth.signInWithPassword(email: usernameToEmail(identifier), password: password);
    } catch (e) {
      final mapped = mapSignInError(e);
      debugPrint('❌ Login gagal: ${mapped.message} (${e.runtimeType})');
      throw mapped;
    }
  }

  @override
  Future<void> signOut() => guard('Gagal keluar', () => _client.auth.signOut());
}
