import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_exception.dart';
import '../../core/permissions.dart';

abstract class StaffRepository {
  Future<void> createStaff({required String username, required String fullName, required AppRole role, required String password});

  Future<void> setPassword({required String userId, required String password});

  Future<void> setActive({required String userId, required bool isActive});
}

/// Semua aksi lewat Edge Function `staff-admin` (hanya owner).
class SupabaseStaffRepository implements StaffRepository {
  final SupabaseClient _client;

  SupabaseStaffRepository(this._client);

  Future<void> _invoke(String fallbackMessage, Map<String, dynamic> body) async {
    try {
      await _client.functions.invoke('staff-admin', body: body);
    } on FunctionException catch (e) {
      // Server membalas {error: "pesan"}; tampilkan pesan itu apa adanya.
      final details = e.details;
      final serverMessage = details is Map ? details['error'] : null;
      debugPrint('❌ staff-admin ${body['action']}: ${e.status} $serverMessage');
      throw AppException(serverMessage is String && serverMessage.isNotEmpty ? serverMessage : fallbackMessage, e);
    } catch (e) {
      debugPrint('❌ staff-admin ${body['action']}: ${e.runtimeType}');
      throw AppException(fallbackMessage, e);
    }
  }

  @override
  Future<void> createStaff({required String username, required String fullName, required AppRole role, required String password}) {
    return _invoke('Gagal menambah staf', {
      'action': 'create',
      'username': username.trim().toLowerCase(),
      'full_name': fullName.trim(),
      'role': role.name,
      'password': password,
    });
  }

  @override
  Future<void> setPassword({required String userId, required String password}) {
    return _invoke('Gagal mengganti password', {'action': 'set_password', 'user_id': userId, 'password': password});
  }

  @override
  Future<void> setActive({required String userId, required bool isActive}) {
    return _invoke('Gagal mengubah status staf', {'action': 'set_active', 'user_id': userId, 'is_active': isActive});
  }
}
