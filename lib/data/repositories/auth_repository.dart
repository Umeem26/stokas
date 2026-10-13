import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_exception.dart';
import '../../core/config.dart';

const inactiveAccountMessage = 'Akun tidak aktif atau tidak ditemukan. Hubungi owner.';
const wrongCredentialsMessage = 'Username atau password salah';
const networkErrorMessage = 'Tidak ada koneksi. Coba lagi.';
const genericSignInMessage = 'Gagal masuk. Coba lagi.';

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
AppException mapSignInError(Object error) {
  if (error is AuthRetryableFetchException || error is SocketException || error is TimeoutException) {
    return AppException(networkErrorMessage, error);
  }
  if (error is AuthException) {
    if (error.code == 'invalid_credentials' || error.message.toLowerCase().contains('invalid login credentials')) {
      return AppException(wrongCredentialsMessage, error);
    }
    if (error.code == 'user_banned') return AppException(inactiveAccountMessage, error);
  }
  final text = error.toString().toLowerCase();
  if (text.contains('socketexception') || text.contains('failed host lookup') || text.contains('clientexception')) {
    return AppException(networkErrorMessage, error);
  }
  return AppException(genericSignInMessage, error);
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
