import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/data/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import 'package:minimarket_pos/presentation/cashier_screen.dart';
import 'package:minimarket_pos/presentation/login_screen.dart';

import 'app_shell_test.dart' show pumpGate, setWidth;
import 'login_staff_test.dart' show pumpLogin;

final _password = find.byKey(const Key('login-password'));

EditableText _editable(WidgetTester tester) =>
    tester.widget<EditableText>(find.descendant(of: _password, matching: find.byType(EditableText)));

/// Fokus ke kolom password, lalu ketik lewat enterText dan tombol fisik.
/// Di web, tombol yang "handled" oleh Flutter dicegah browser -> huruf tidak masuk ke kolom.
Future<void> expectPasswordTypable(WidgetTester tester) async {
  expect(find.byType(LoginScreen), findsOneWidget);
  expect(find.byType(CashierScreen), findsNothing);

  await tester.tap(_password);
  await tester.pumpAndSettle();
  expect(_editable(tester).focusNode.hasFocus, isTrue, reason: 'kolom password harus fokus setelah diketuk');

  await tester.enterText(_password, 'rahasia');
  await tester.pumpAndSettle();
  expect(_editable(tester).controller.text, 'rahasia');

  final keys = {
    'x': LogicalKeyboardKey.keyX,
    '1': LogicalKeyboardKey.digit1,
    '/': LogicalKeyboardKey.slash,
    '+': LogicalKeyboardKey.equal,
    '-': LogicalKeyboardKey.minus,
  };
  for (final e in keys.entries) {
    final handled = await tester.sendKeyEvent(e.value, character: e.key);
    expect(handled, isFalse, reason: 'tombol "${e.key}" tidak boleh ditelan pendengar lain');
    await tester.pump();
  }
  await tester.pumpAndSettle();
  expect(_editable(tester).focusNode.hasFocus, isTrue, reason: 'fokus tidak boleh direbut');
}

void main() {
  testWidgets('gagal login (401): fokus tetap di password, ketikan berikutnya masuk', (tester) async {
    final auth = await pumpLogin(tester);
    auth.result = mapSignInError(const AuthException('Invalid login credentials', statusCode: '400', code: 'invalid_credentials'));
    await tester.enterText(find.byKey(const Key('login-identifier')), 'test@gmail.com');
    await tester.tap(_password);
    await tester.enterText(_password, 'salah');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(_editable(tester).focusNode.hasFocus, isTrue, reason: 'fokus tidak boleh lepas saat memproses');
    await tester.pumpAndSettle();

    expect(find.text(wrongCredentialsMessage), findsOneWidget);
    expect(_editable(tester).focusNode.hasFocus, isTrue, reason: 'setelah gagal, kasir langsung mengetik ulang password');
    expect(tester.testTextInput.hasAnyClients, isTrue);
    await expectPasswordTypable(tester);
  });

  testWidgets('event auth saat Login tampil tidak membuang isian dan fokus password', (tester) async {
    setWidth(tester, 1366);
    final auth = await pumpGate(tester, null);
    final state = tester.state(find.byType(LoginScreen));
    await tester.enterText(find.byKey(const Key('login-identifier')), 'test@gmail.com');
    await tester.tap(_password);
    await tester.enterText(_password, 'rahasia');
    await tester.pumpAndSettle();

    // Mis. tab lain keluar/masuk: tanpa sesi di tab ini, Login harus tetap sama.
    for (final change in [AuthChange.signedIn, AuthChange.signedOut, AuthChange.signedIn]) {
      auth.emit(change);
      await tester.pump();
      expect(find.byType(LoginScreen), findsOneWidget, reason: 'Login tidak boleh diganti spinner ($change)');
      await tester.pumpAndSettle();
    }
    expect(tester.state(find.byType(LoginScreen)), same(state), reason: 'state Login (controller) harus sama');
    expect(_editable(tester).controller.text, 'rahasia');
    expect(_editable(tester).focusNode.hasFocus, isTrue);
    await expectPasswordTypable(tester);
  });

  for (final width in [1366.0, 400.0]) {
    group('Login setelah Kasir aktif (lebar $width)', () {
      testWidgets('logout', (tester) async {
        setWidth(tester, width);
        final auth = await pumpGate(tester, 'kasir');
        expect(find.byType(CashierScreen), findsOneWidget);

        await auth.signOut();
        await tester.pumpAndSettle();
        await expectPasswordTypable(tester);
      });

      testWidgets('sesi kedaluwarsa saat panel bayar terbuka', (tester) async {
        setWidth(tester, width);
        final auth = await pumpGate(tester, 'kasir');
        // Tambah barang lalu buka panel bayar.
        await tester.enterText(find.byKey(const Key('cashier-search')), 'A');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        auth.userId = null;
        await auth.signOut();
        await tester.pumpAndSettle();
        await expectPasswordTypable(tester);
      });

      testWidgets('ganti akun: login lagi lalu logout lagi', (tester) async {
        setWidth(tester, width);
        final auth = await pumpGate(tester, 'kasir');
        await auth.signOut();
        await tester.pumpAndSettle();
        await auth.signIn('kasir', 'x');
        await tester.pumpAndSettle();
        expect(find.byType(CashierScreen), findsOneWidget);
        await auth.signOut();
        await tester.pumpAndSettle();
        await expectPasswordTypable(tester);
        // Gagal login lalu ketik lagi.
        await tester.tap(find.byKey(const Key('login-submit')));
        await tester.pumpAndSettle();
        await expectPasswordTypable(tester);
      });
    });
  }
}
