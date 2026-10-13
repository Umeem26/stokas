import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/permissions.dart';
import 'profile_model.dart';
import 'providers.dart';
import 'repositories/auth_repository.dart';
import 'repositories/profile_repository.dart';

sealed class SessionState {
  const SessionState();
}

/// Belum login. [message] berisi alasan jika sesi ditolak (mis. akun nonaktif).
class SignedOut extends SessionState {
  final String? message;
  const SignedOut([this.message]);
}

class SignedIn extends SessionState {
  final Profile profile;
  const SignedIn(this.profile);
}

/// Tentukan status sesi: tanpa sesi -> SignedOut; profil tidak ada, nonaktif, atau
/// perannya tidak dikenal -> signOut + pesan; selain itu SignedIn.
Future<SessionState> resolveSession(AuthRepository auth, ProfileRepository profiles) async {
  final userId = auth.currentUserId;
  if (userId == null) return const SignedOut();

  final profile = await profiles.getProfile(userId);
  if (profile == null || !profile.isActive || profile.role == null) {
    await auth.signOut();
    return const SignedOut(inactiveAccountMessage);
  }
  return SignedIn(profile);
}

class SessionController extends AsyncNotifier<SessionState> {
  bool _resolving = false;

  @override
  Future<SessionState> build() async {
    final auth = ref.watch(authRepositoryProvider);
    final sub = auth.changes.listen(_onAuthChange);
    ref.onDispose(sub.cancel);
    return _resolve();
  }

  Future<SessionState> _resolve() async {
    _resolving = true;
    try {
      return await resolveSession(ref.read(authRepositoryProvider), ref.read(profileRepositoryProvider));
    } finally {
      _resolving = false;
    }
  }

  Future<void> _onAuthChange(AuthChange change) async {
    // Event yang muncul saat resolve sendiri (mis. signOut karena akun nonaktif) diabaikan.
    if (_resolving) return;
    final current = state.value;

    if (change == AuthChange.signedOut) {
      if (current is! SignedOut) state = const AsyncData(SignedOut());
      return;
    }

    // signedIn: abaikan jika pengguna yang sama sudah masuk (mis. pemulihan sesi),
    // agar layar beranda (dan keranjang kasir) tidak ter-reset.
    final userId = ref.read(authRepositoryProvider).currentUserId;
    if (current is SignedIn && current.profile.id == userId) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(_resolve);
  }

  Future<void> signOut() => ref.read(authRepositoryProvider).signOut();
}

final sessionControllerProvider = AsyncNotifierProvider<SessionController, SessionState>(SessionController.new);

/// Profil pengguna yang sedang login, atau null.
final currentProfileProvider = Provider<Profile?>((ref) {
  final session = ref.watch(sessionControllerProvider).value;
  return session is SignedIn ? session.profile : null;
});

final currentRoleProvider = Provider<AppRole?>((ref) => ref.watch(currentProfileProvider)?.role);
