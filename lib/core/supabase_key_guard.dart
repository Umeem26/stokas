import 'dart:convert';

import 'app_exception.dart';

const secretKeyMessage = 'Kunci Supabase salah: kunci rahasia tidak boleh dipakai di aplikasi. Pakai kunci publishable.';
const emptyKeyMessage = 'Kunci Supabase kosong. Isi SUPABASE_ANON_KEY di .env dengan kunci publishable.';
const emptyUrlMessage = 'Alamat Supabase kosong. Isi SUPABASE_URL di .env.';

/// Konfigurasi aplikasi tidak bisa dipakai; aplikasi menampilkan layar galat konfigurasi.
class ConfigException extends AppException {
  const ConfigException(super.message);
}

/// Tolak kunci klien yang kosong, kunci rahasia (`sb_secret_...`), atau JWT ber-role
/// `service_role`. Kunci rahasia menembus RLS dan tidak boleh ada di aplikasi.
void checkClientKey(String? key) {
  final value = (key ?? '').trim();
  if (value.isEmpty) throw const ConfigException(emptyKeyMessage);
  if (value.startsWith('sb_secret_')) throw const ConfigException(secretKeyMessage);
  if (_jwtRole(value) == 'service_role') throw const ConfigException(secretKeyMessage);
}

/// Cek [url] dan [key] dari .env sebelum Supabase diinisialisasi.
void checkSupabaseConfig({required String? url, required String? key}) {
  if ((url ?? '').trim().isEmpty) throw const ConfigException(emptyUrlMessage);
  checkClientKey(key);
}

/// Klaim `role` dari payload JWT, atau null bila [token] bukan JWT yang bisa didekode.
String? _jwtRole(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    return payload is Map ? payload['role']?.toString() : null;
  } catch (_) {
    return null;
  }
}
