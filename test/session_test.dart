import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/core/app_exception.dart';
import 'package:minimarket_pos/core/permissions.dart';
import 'package:minimarket_pos/data/profile_model.dart';
import 'package:minimarket_pos/data/providers.dart';
import 'package:minimarket_pos/data/repositories/auth_repository.dart';
import 'package:minimarket_pos/data/repositories/profile_repository.dart';
import 'package:minimarket_pos/data/session.dart';
import 'package:minimarket_pos/presentation/auth_gate.dart';
import 'package:minimarket_pos/presentation/cashier_screen.dart';
import 'package:minimarket_pos/presentation/dashboard_screen.dart';
import 'package:minimarket_pos/presentation/stock_list_screen.dart';

class FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AuthChange>.broadcast();
  String? userId;
  int signOutCalls = 0;

  FakeAuthRepository([this.userId]);

  @override
  String? get currentUserId => userId;

  @override
  Stream<AuthChange> get changes => _controller.stream;

  @override
  Future<void> signIn(String identifier, String password) async {
    userId = identifier;
    _controller.add(AuthChange.signedIn);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    userId = null;
    _controller.add(AuthChange.signedOut);
  }
}

class FakeProfileRepository implements ProfileRepository {
  final Map<String, Profile> profiles;
  FakeProfileRepository(this.profiles);

  @override
  Future<Profile?> getProfile(String userId) async => profiles[userId];

  @override
  Future<List<Profile>> getAllProfiles() async => profiles.values.toList();
}

Profile _profile(String id, AppRole? role, {bool active = true}) =>
    Profile(id: id, fullName: 'User $id', role: role, isActive: active);

void main() {
  final profiles = FakeProfileRepository({
    'owner': _profile('owner', AppRole.owner),
    'kasir': _profile('kasir', AppRole.cashier),
    'gudang': _profile('gudang', AppRole.warehouse),
    'nonaktif': _profile('nonaktif', AppRole.cashier, active: false),
    'aneh': _profile('aneh', null),
  });

  group('resolveSession', () {
    test('tanpa sesi -> SignedOut tanpa pesan', () async {
      final auth = FakeAuthRepository();
      final s = await resolveSession(auth, profiles);
      expect(s, isA<SignedOut>().having((s) => s.message, 'pesan', isNull));
      expect(auth.signOutCalls, 0);
    });

    for (final id in ['nonaktif', 'tidak-ada', 'aneh']) {
      test('profil $id -> signOut + pesan akun tidak aktif', () async {
        final auth = FakeAuthRepository(id);
        final s = await resolveSession(auth, profiles);
        expect(s, isA<SignedOut>().having((s) => s.message, 'pesan', inactiveAccountMessage));
        expect(auth.signOutCalls, 1);
      });
    }

    test('profil aktif tiap peran -> SignedIn dengan beranda sesuai peran', () async {
      final homes = {'owner': DashboardScreen, 'kasir': CashierScreen, 'gudang': StockListScreen};
      for (final entry in homes.entries) {
        final s = await resolveSession(FakeAuthRepository(entry.key), profiles);
        expect(s, isA<SignedIn>(), reason: entry.key);
        expect(homeFor((s as SignedIn).profile.role!).runtimeType, entry.value, reason: entry.key);
      }
    });

    test('gagal memuat profil (jaringan) -> error diteruskan, sesi tidak dihapus', () async {
      final auth = FakeAuthRepository('owner');
      final failing = _FailingProfileRepository();
      await expectLater(resolveSession(auth, failing), throwsA(isA<AppException>()));
      expect(auth.signOutCalls, 0);
    });
  });

  group('SessionController', () {
    ProviderContainer makeContainer(FakeAuthRepository auth) {
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
      ], retry: (retryCount, error) => null);
      addTearDown(container.dispose);
      return container;
    }

    test('login lalu logout mengikuti onAuthStateChange', () async {
      final auth = FakeAuthRepository();
      final container = makeContainer(auth);
      final sub = container.listen(sessionControllerProvider, (prev, next) {});
      addTearDown(sub.close);

      expect(await container.read(sessionControllerProvider.future), isA<SignedOut>());

      await auth.signIn('kasir', 'rahasia123');
      await pumpEventQueue();
      expect(container.read(currentRoleProvider), AppRole.cashier);

      await container.read(sessionControllerProvider.notifier).signOut();
      await pumpEventQueue();
      expect(container.read(sessionControllerProvider).value, isA<SignedOut>());
      expect(container.read(currentProfileProvider), isNull);
    });

    test('login dengan akun nonaktif -> kembali ke login dengan pesan', () async {
      final auth = FakeAuthRepository();
      final container = makeContainer(auth);
      final sub = container.listen(sessionControllerProvider, (prev, next) {});
      addTearDown(sub.close);
      await container.read(sessionControllerProvider.future);

      await auth.signIn('nonaktif', 'rahasia123');
      await pumpEventQueue();

      final s = container.read(sessionControllerProvider).value;
      expect(s, isA<SignedOut>().having((s) => s.message, 'pesan', inactiveAccountMessage));
      expect(auth.userId, isNull);
    });
  });
}

class _FailingProfileRepository implements ProfileRepository {
  @override
  Future<Profile?> getProfile(String userId) async => throw const AppException('Gagal memuat profil');

  @override
  Future<List<Profile>> getAllProfiles() async => throw const AppException('Gagal memuat daftar staf');
}
