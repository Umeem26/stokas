import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_exception.dart';
import '../profile_model.dart';

abstract class ProfileRepository {
  /// Profil milik [userId], atau null jika tidak ada/tidak terbaca.
  Future<Profile?> getProfile(String userId);

  /// Semua profil (RLS: hanya owner yang melihat semuanya).
  Future<List<Profile>> getAllProfiles();
}

class SupabaseProfileRepository implements ProfileRepository {
  final SupabaseClient _client;

  SupabaseProfileRepository(this._client);

  @override
  Future<Profile?> getProfile(String userId) {
    return guard('Gagal memuat profil', () async {
      final row = await _client.from('profiles').select().eq('id', userId).maybeSingle();
      return row == null ? null : Profile.fromMap(row);
    });
  }

  @override
  Future<List<Profile>> getAllProfiles() {
    return guard('Gagal memuat daftar staf', () async {
      final rows = await _client.from('profiles').select().order('full_name');
      return rows.map(Profile.fromMap).toList();
    });
  }
}
