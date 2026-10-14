import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/core/permissions.dart';
import 'package:minimarket_pos/data/profile_model.dart';
import 'package:minimarket_pos/data/providers.dart';
import 'package:minimarket_pos/data/repositories/auth_repository.dart';
import 'package:minimarket_pos/data/session.dart';
import 'package:minimarket_pos/presentation/design/stokas_logo.dart';
import 'package:minimarket_pos/presentation/design/stokas_theme.dart';
import 'package:minimarket_pos/presentation/login_screen.dart';
import 'package:minimarket_pos/presentation/staff_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import 'fakes.dart';

/// Auth yang bisa diatur: [result] = galat yang dilempar, atau [pending] untuk menahan proses.
class ScriptedAuth extends FakeAuthRepository {
  final calls = <(String, String)>[];
  Object? result;
  Completer<void>? pending;

  @override
  Future<void> signIn(String identifier, String password) async {
    calls.add((identifier, password));
    if (pending != null) await pending!.future;
    if (result != null) throw result!;
  }
}

Future<ScriptedAuth> pumpLogin(WidgetTester tester, {String? message}) async {
  final auth = ScriptedAuth();
  await tester.pumpWidget(ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(auth)],
    child: MaterialApp(theme: StokasTheme.light, home: LoginScreen(message: message)),
  ));
  await tester.pumpAndSettle();
  return auth;
}

Future<void> fillLogin(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('login-identifier')), 'budi.kasir');
  await tester.enterText(find.byKey(const Key('login-password')), 'rahasia123');
}

const owner = Profile(id: 'o1', fullName: 'Ani Owner', role: AppRole.owner, isActive: true);
const budi = Profile(id: 's1', fullName: 'Budi', role: AppRole.cashier, isActive: true);
const citra = Profile(id: 's2', fullName: 'Citra', role: AppRole.warehouse, isActive: false);

Future<FakeStaffRepository> pumpStaff(WidgetTester tester, List<Profile> profiles) async {
  final staff = FakeStaffRepository();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentProfileProvider.overrideWithValue(owner),
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository({for (final p in profiles) p.id: p})),
      staffRepositoryProvider.overrideWithValue(staff),
    ],
    child: MaterialApp(theme: StokasTheme.light, home: const StaffScreen()),
  ));
  return staff;
}

Future<void> openToggle(WidgetTester tester, Profile p) async {
  await tester.tap(find.byKey(Key('staff-actions-${p.id}')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(p.isActive ? 'Nonaktifkan' : 'Aktifkan'));
  await tester.pumpAndSettle();
}

void main() {
  group('Login', () {
    testWidgets('logo Stokas + tagline tampil', (tester) async {
      await pumpLogin(tester);
      expect(find.byType(StokasLogo), findsOneWidget);
      expect(find.text('Uang dan barang, satu catatan.'), findsOneWidget);
      expect(find.text('Masuk'), findsWidgets);
    });

    final cases = {
      SignInFailure.wrongCredentials: (mapSignInError(const AuthException('Invalid login credentials', code: 'invalid_credentials')), Icons.key_off_outlined),
      SignInFailure.network: (mapSignInError(const SocketException('Failed host lookup')), Icons.wifi_off),
      SignInFailure.inactive: (mapSignInError(const AuthException('User is banned', code: 'user_banned')), Icons.block),
      SignInFailure.other: (mapSignInError(StateError('boom')), Icons.error_outline),
    };
    for (final MapEntry(key: failure, value: (error, icon)) in cases.entries) {
      testWidgets('galat ${failure.name}: ikon + teks jelas', (tester) async {
        expect(error.failure, failure);
        final auth = await pumpLogin(tester);
        auth.result = error;
        await fillLogin(tester);
        await tester.tap(find.byKey(const Key('login-submit')));
        await tester.pumpAndSettle();

        final banner = find.byKey(const Key('login-error'));
        expect(find.descendant(of: banner, matching: find.text(error.message)), findsOneWidget);
        expect(find.descendant(of: banner, matching: find.byIcon(icon)), findsOneWidget);
      });
    }

    testWidgets('pesan akun nonaktif dari gerbang sesi memakai ikon akun dinonaktifkan', (tester) async {
      await pumpLogin(tester, message: inactiveAccountMessage);
      final banner = find.byKey(const Key('login-error'));
      expect(find.descendant(of: banner, matching: find.text(inactiveAccountMessage)), findsOneWidget);
      expect(find.descendant(of: banner, matching: find.byIcon(Icons.block)), findsOneWidget);
    });

    testWidgets('Enter di kolom password mengirim', (tester) async {
      final auth = await pumpLogin(tester);
      await fillLogin(tester);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(auth.calls, [('budi.kasir', 'rahasia123')]);
    });

    testWidgets('Enter di kolom username: pindah ke password bila kosong, kirim bila terisi', (tester) async {
      final auth = await pumpLogin(tester);
      await tester.enterText(find.byKey(const Key('login-identifier')), 'budi.kasir');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(auth.calls, isEmpty);
      final password = tester.widget<EditableText>(find.descendant(of: find.byKey(const Key('login-password')), matching: find.byType(EditableText)));
      expect(password.focusNode.hasFocus, isTrue);

      await fillLogin(tester);
      await tester.showKeyboard(find.byKey(const Key('login-identifier')));
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(auth.calls, [('budi.kasir', 'rahasia123')]);
    });

    testWidgets('tombol nonaktif + indikator selama proses; tidak mengirim dua kali', (tester) async {
      final auth = await pumpLogin(tester)..pending = Completer<void>();
      await fillLogin(tester);
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pump();

      final button = tester.widget<FilledButton>(find.descendant(of: find.byKey(const Key('login-submit')), matching: find.byType(FilledButton)));
      expect(button.onPressed, isNull);
      expect(find.byKey(const ValueKey('stokasButtonLoading')), findsOneWidget);
      await tester.tap(find.byKey(const Key('login-submit')), warnIfMissed: false);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(auth.calls, hasLength(1));

      auth.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('stokasButtonLoading')), findsNothing);
    });

    testWidgets('tombol tampilkan password minimal 48 px', (tester) async {
      await pumpLogin(tester);
      final toggle = find.byTooltip('Tampilkan password');
      expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
      await tester.tap(toggle);
      await tester.pump();
      expect(find.byTooltip('Sembunyikan password'), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('login-submit'))).height, greaterThanOrEqualTo(48));
    });
  });

  group('Staf', () {
    testWidgets('memuat = skeleton; daftar: nama, peran dan status ikon + kata', (tester) async {
      await pumpStaff(tester, [owner, budi, citra]);
      expect(find.byKey(const Key('staff-skeleton')), findsOneWidget);
      await tester.pumpAndSettle();

      final b = find.byKey(const Key('staff-s1'));
      expect(find.descendant(of: b, matching: find.text('Budi')), findsOneWidget);
      expect(find.descendant(of: b, matching: find.text('Kasir')), findsOneWidget);
      expect(find.descendant(of: b, matching: find.byIcon(Icons.point_of_sale)), findsOneWidget);
      expect(find.descendant(of: b, matching: find.text('Aktif')), findsOneWidget);
      expect(find.descendant(of: b, matching: find.byIcon(Icons.check_circle_outline)), findsOneWidget);

      final c = find.byKey(const Key('staff-s2'));
      expect(find.descendant(of: c, matching: find.text('Gudang')), findsOneWidget);
      expect(find.descendant(of: c, matching: find.text('Nonaktif')), findsOneWidget);
      expect(find.descendant(of: c, matching: find.byIcon(Icons.cancel_outlined)), findsOneWidget);

      expect(find.text('Ani Owner (Anda)'), findsOneWidget);
    });

    testWidgets('nonaktifkan: konfirmasi menyebut nama, bahaya kiri; Batal tidak memanggil apa pun', (tester) async {
      final staff = await pumpStaff(tester, [owner, budi]);
      await tester.pumpAndSettle();

      await openToggle(tester, budi);
      expect(find.text('Nonaktifkan Budi?'), findsOneWidget);
      expect(staff.setActiveCalls, isEmpty);
      final danger = tester.getTopLeft(find.byKey(const Key('confirm-toggle-active')));
      final cancel = tester.getTopLeft(find.widgetWithText(OutlinedButton, 'Batal'));
      expect(danger.dx, lessThan(cancel.dx));

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Nonaktifkan Budi?'), findsNothing);
      expect(staff.setActiveCalls, isEmpty);
      expect(staff.setPasswordCalls, isEmpty);

      await openToggle(tester, budi);
      await tester.tap(find.byKey(const Key('confirm-toggle-active')));
      await tester.pumpAndSettle();
      expect(staff.setActiveCalls, [('s1', false)]);
      expect(find.text('Budi dinonaktifkan'), findsOneWidget);
    });

    testWidgets('aktifkan staf nonaktif lewat konfirmasi', (tester) async {
      final staff = await pumpStaff(tester, [owner, citra]);
      await tester.pumpAndSettle();
      await openToggle(tester, citra);
      expect(find.text('Aktifkan Citra?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-toggle-active')));
      await tester.pumpAndSettle();
      expect(staff.setActiveCalls, [('s2', true)]);
    });

    testWidgets('akun sendiri tidak bisa dinonaktifkan', (tester) async {
      await pumpStaff(tester, [owner]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('staff-actions-o1')));
      await tester.pumpAndSettle();
      expect(find.text('Reset password'), findsOneWidget);
      expect(find.text('Nonaktifkan'), findsNothing);
    });

    testWidgets('kosong: sebut langkah berikutnya', (tester) async {
      await pumpStaff(tester, []);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('staff-empty')), findsOneWidget);
      expect(find.text('Belum ada staf. Tambah staf dulu.'), findsOneWidget);
    });
  });

  test('tidak ada sisa google_fonts / Poppins di lib, test, pubspec', () {
    final files = [
      File('pubspec.yaml'),
      ...[Directory('lib'), Directory('test')]
          .expand((d) => d.listSync(recursive: true))
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('login_staff_test.dart')),
    ];
    final offenders = [
      for (final f in files)
        if (RegExp('google_fonts|GoogleFonts|poppins', caseSensitive: false).hasMatch(f.readAsStringSync())) f.path,
    ];
    expect(offenders, isEmpty);
  });
}
