import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/core/app_exception.dart';
import 'package:minimarket_pos/core/config.dart';
import 'package:minimarket_pos/core/validators.dart';
import 'package:minimarket_pos/data/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Klien Supabase palsu: merekam email yang dikirim ke signInWithPassword (password tidak disimpan).
class _RecordingGoTrue extends Fake implements GoTrueClient {
  final emails = <String?>[];
  Object? error;

  @override
  Future<AuthResponse> signInWithPassword({String? email, String? phone, required String password, String? captchaToken}) async {
    emails.add(email);
    if (error != null) throw error!;
    return AuthResponse();
  }
}

class _FakeSupabase extends Fake implements SupabaseClient {
  @override
  final _RecordingGoTrue auth = _RecordingGoTrue();
}

void main() {
  group('SupabaseAuthRepository.signIn: email yang dikirim ke Supabase', () {
    for (final (input, email) in [
      ('test@gmail.com', 'test@gmail.com'),
      ('  test@gmail.com ', 'test@gmail.com'),
      ('Test@Gmail.com', 'Test@Gmail.com'),
      ('kasir1', 'kasir1@staff.pos.invalid'),
      (' Kasir1 ', 'kasir1@staff.pos.invalid'),
    ]) {
      test('"$input" -> $email', () async {
        final client = _FakeSupabase();
        await SupabaseAuthRepository(client).signIn(input, 'rahasia123');
        expect(client.auth.emails, [email]);
      });
    }

    test('password salah -> galat kredensial, email tetap utuh', () async {
      final client = _FakeSupabase();
      client.auth.error = const AuthException('Invalid login credentials', statusCode: '400', code: 'invalid_credentials');
      await expectLater(
        SupabaseAuthRepository(client).signIn('test@gmail.com', 'salah'),
        throwsA(isA<SignInException>().having((e) => e.failure, 'failure', SignInFailure.wrongCredentials)),
      );
      expect(client.auth.emails, ['test@gmail.com']);
    });
  });

  group('usernameToEmail', () {
    test('username biasa memakai domain staf', () {
      expect(usernameToEmail('budi'), 'budi@$staffEmailDomain');
      expect(staffEmailDomain, 'staff.pos.invalid');
    });

    test('username di-trim dan di-lowercase', () {
      expect(usernameToEmail('  Budi.Kasir '), 'budi.kasir@staff.pos.invalid');
    });

    test('input yang mengandung @ dipakai apa adanya', () {
      expect(usernameToEmail('owner@toko.com'), 'owner@toko.com');
      expect(usernameToEmail(' Owner@Toko.com '), 'Owner@Toko.com');
    });
  });

  group('mapSignInError', () {
    final cases = <(String, Object, SignInFailure, String)>[
      ('400 invalid_credentials',
          AuthApiException('Invalid login credentials', statusCode: '400', code: 'invalid_credentials'),
          SignInFailure.wrongCredentials, 'Username/email atau password salah. Periksa lalu coba lagi.'),
      ('401 Invalid API key', AuthApiException('Invalid API key', statusCode: '401'),
          SignInFailure.apiKey, 'Konfigurasi aplikasi salah: kunci Supabase tidak diterima.'),
      ('401 kunci rahasia di browser', AuthApiException('Forbidden use of secret API key in browser', statusCode: '401'),
          SignInFailure.apiKey, apiKeyRejectedMessage),
      ('akun nonaktif (user_banned)', AuthApiException('User is banned', statusCode: '400', code: 'user_banned'),
          SignInFailure.inactive, inactiveAccountMessage),
      ('429 terlalu banyak percobaan', AuthApiException('Request rate limit reached', statusCode: '429', code: 'over_request_rate_limit'),
          SignInFailure.rateLimited, rateLimitedMessage),
      ('koneksi: AuthRetryableFetchException', AuthRetryableFetchException(), SignInFailure.network, networkErrorMessage),
      ('koneksi: web Failed to fetch', Exception('ClientException: Failed to fetch'), SignInFailure.network, networkErrorMessage),
      ('auth tak dikenal tetap menyebut kode', AuthApiException('boom', statusCode: '500', code: 'unexpected_failure'),
          SignInFailure.other, unknownSignInMessage('unexpected_failure')),
      ('auth tanpa kode menyebut status HTTP', AuthApiException('boom', statusCode: '503'),
          SignInFailure.other, unknownSignInMessage('HTTP 503')),
      ('galat non-auth menyebut tipenya', StateError('boom'), SignInFailure.other, unknownSignInMessage('StateError')),
    ];

    for (final (name, error, failure, message) in cases) {
      test(name, () {
        final e = mapSignInError(error);
        expect(e.failure, failure);
        expect(e.message, message);
        expect(e.cause, same(error));
      });
    }

    test('setiap jenis galat punya pesan berbeda', () {
      final messages = {
        for (final (_, error, failure, _) in cases) failure: mapSignInError(error).message,
      };
      expect(messages.keys.toSet(), SignInFailure.values.toSet());
      expect(messages.values.toSet().length, SignInFailure.values.length);
    });
  });

  test('guard: penolakan RLS 42501 menjadi pesan tanpa akses', () async {
    await expectLater(
      guard<void>('Gagal menyimpan', () async => throw const PostgrestException(message: 'permission denied', code: '42501')),
      throwsA(isA<AppException>().having((e) => e.message, 'pesan', noAccessMessage)),
    );
  });

  group('validasi form login', () {
    test('username/email wajib diisi', () {
      expect(validateLoginIdentifier(''), isNotNull);
      expect(validateLoginIdentifier('   '), isNotNull);
      expect(validateLoginIdentifier('budi'), isNull);
    });

    test('password wajib diisi', () {
      expect(validateLoginPassword(''), isNotNull);
      expect(validateLoginPassword(null), isNotNull);
      expect(validateLoginPassword('x'), isNull);
    });
  });

  group('validasi form tambah staf', () {
    test('username 3-60 karakter dengan karakter yang diizinkan', () {
      expect(validateStaffUsername(''), isNotNull);
      expect(validateStaffUsername('ab'), isNotNull);
      expect(validateStaffUsername('budi kasir'), isNotNull);
      expect(validateStaffUsername('a' * 61), isNotNull);
      expect(validateStaffUsername('Budi.Kasir_01'), isNull);
    });

    test('nama wajib, maksimal 80 karakter', () {
      expect(validateStaffFullName(' '), isNotNull);
      expect(validateStaffFullName('a' * 81), isNotNull);
      expect(validateStaffFullName('Budi Santoso'), isNull);
    });

    test('password minimal 8 karakter', () {
      expect(validateStaffPassword('1234567'), isNotNull);
      expect(validateStaffPassword('12345678'), isNull);
    });
  });
}
