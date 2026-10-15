// Tes integrasi ke Supabase sungguhan. Jalankan HANYA setelah kunci diputar:
//   flutter test integration_test/app_test.dart --dart-define-from-file=integration_test/env.test.json
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:minimarket_pos/core/permissions.dart';
import 'package:minimarket_pos/main.dart' as app;

const _ownerEmail = String.fromEnvironment('OWNER_EMAIL');
const _ownerPassword = String.fromEnvironment('OWNER_PASSWORD');

/// Pump sampai [finder] muncul; pumpAndSettle tidak dipakai karena indikator
/// muat beranimasi terus selama menunggu jaringan.
Future<void> pumpUntil(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Tidak muncul dalam ${timeout.inSeconds} dtk: $finder');
}

Future<void> loginAsOwner(WidgetTester tester) async {
  app.main();
  final submit = find.byKey(const Key('login-submit'));
  final staffTab = find.text('Staf');
  await pumpUntil(tester, find.byWidgetPredicate((w) => w.key == const Key('login-submit') || (w is Text && w.data == 'Staf')));
  if (submit.evaluate().isEmpty) return; // Sesi owner tersimpan.
  await tester.enterText(find.widgetWithText(TextFormField, 'Username atau email'), _ownerEmail);
  await tester.enterText(find.byKey(const Key('login-password')), _ownerPassword);
  await tester.tap(submit);
  await pumpUntil(tester, staffTab);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Bagian 3 — Staf (owner)', () {
    testWidgets('owner membuat staf UJI-gudang berperan gudang -> tampil "Gudang"', (tester) async {
      expect(_ownerEmail, isNotEmpty, reason: 'OWNER_EMAIL kosong; pakai --dart-define-from-file');
      await loginAsOwner(tester);

      await tester.tap(find.text('Staf').last);
      final addButton = find.text('Tambah staf');
      await pumpUntil(tester, addButton);
      await tester.tap(addButton.last);
      await pumpUntil(tester, find.text('Simpan staf'));

      // Username unik agar tes bisa diulang (username dipakai -> 409).
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final fullName = 'UJI-gudang $stamp';
      await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'uji-gudang-$stamp');
      await tester.enterText(find.widgetWithText(TextFormField, 'Nama Lengkap'), fullName);
      await tester.tap(find.byType(DropdownButtonFormField<AppRole>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppRole.warehouse.label).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Password Awal'), 'UjiGudang-$stamp');
      await tester.tap(find.text('Simpan staf'));

      // Kembali ke Kelola Staf; baris staf baru harus berlencana "Gudang", bukan "Kasir".
      final nameText = find.text(fullName);
      await pumpUntil(tester, nameText);
      final row = find.ancestor(
        of: nameText,
        matching: find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('staff-')),
      );
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('Gudang')), findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('Kasir')), findsNothing);
    });
  });
}
