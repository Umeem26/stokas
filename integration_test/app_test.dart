// Tes integrasi ke Supabase sungguhan. Jalankan HANYA setelah kunci diputar:
//   flutter test integration_test/app_test.dart --dart-define-from-file=integration_test/env.test.json
// Grup berjalan berurutan dan berbagi data uji (kode produk & no. struk); semua data berawalan "UJI-".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:minimarket_pos/core/format.dart';
import 'package:minimarket_pos/core/permissions.dart';
import 'package:minimarket_pos/main.dart' as app;
import 'package:minimarket_pos/presentation/app_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ownerEmail = String.fromEnvironment('OWNER_EMAIL');
const _ownerPassword = String.fromEnvironment('OWNER_PASSWORD');
const _cashierLogin = String.fromEnvironment('CASHIER_EMAIL');
const _cashierPassword = String.fromEnvironment('CASHIER_PASSWORD');
const _warehouseLogin = String.fromEnvironment('WAREHOUSE_EMAIL');
const _warehousePassword = String.fromEnvironment('WAREHOUSE_PASSWORD');

// Data uji bersama antar-alur.
final _stamp = DateTime.now().millisecondsSinceEpoch;
final _code = 'UJI-$_stamp';
final _name = 'UJI-Produk $_stamp';
const _initialQty = 10;
const _receivedQty = 5;
const _price = 5000;
const _capital = 3500;
const _soldQty = 2;
String? _receiptNo;

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

Future<void> pumpUntilGone(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isEmpty) return;
  }
  fail('Masih tampil setelah ${timeout.inSeconds} dtk: $finder');
}

final _loginSubmit = find.byKey(const Key('login-submit'));
final _shell = find.byWidgetPredicate((w) => w.key == const Key('app-nav-bottom') || w.key == const Key('app-nav-rail'));

/// Mulai aplikasi di layar Login (sesi tersimpan dari alur sebelumnya dikeluarkan).
Future<void> startAtLogin(WidgetTester tester) async {
  app.main();
  await pumpUntil(tester, find.byWidgetPredicate((w) => w.key == const Key('login-submit') || w.key == const Key('app-nav-bottom') || w.key == const Key('app-nav-rail')));
  if (_loginSubmit.evaluate().isNotEmpty) return;
  await Supabase.instance.client.auth.signOut();
  await pumpUntil(tester, _loginSubmit);
}

Future<void> submitLogin(WidgetTester tester, String identifier, String password) async {
  await tester.enterText(find.byKey(const Key('login-identifier')), identifier);
  await tester.enterText(find.byKey(const Key('login-password')), password);
  await tester.tap(_loginSubmit);
}

Future<void> loginAs(WidgetTester tester, String identifier, String password) async {
  expect(identifier, isNotEmpty, reason: 'Akun uji kosong; pakai --dart-define-from-file');
  await startAtLogin(tester);
  await submitLogin(tester, identifier, password);
  await pumpUntil(tester, _shell);
}

Future<void> openTab(WidgetTester tester, AppTab tab) async {
  await tester.tap(find.byKey(Key('nav-${tab.name}')));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Tunggu transisi halaman selesai agar halaman di bawahnya tidak ikut ditemukan.
Future<void> settleRoute(WidgetTester tester) => tester.pump(const Duration(milliseconds: 800));

/// Gulir daftar utama halaman teratas sampai [finder] terlihat.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).hitTestable().first, maxScrolls: 200);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Kartu stok (daftar Stok/Produk) milik produk uji.
Finder stockTile() => find.ancestor(of: find.text(_name), matching: find.byType(Container)).first;

void expectNavTabs(List<AppTab> expected) {
  for (final tab in AppTab.values) {
    // riwayat & riwayatSaya berbagi tampilan; cek lewat kunci nav.
    expect(find.byKey(Key('nav-${tab.name}')), expected.contains(tab) ? findsOneWidget : findsNothing, reason: 'tab ${tab.name}');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('A — Login', () {
    testWidgets('password salah ditolak, tetap di Login', (tester) async {
      await startAtLogin(tester);
      await submitLogin(tester, _cashierLogin, '$_cashierPassword-salah');
      await pumpUntil(tester, find.byKey(const Key('login-error')));
      expect(_shell, findsNothing);
      expect(_loginSubmit, findsOneWidget);
    });

    testWidgets('owner masuk ke Home dengan tab owner', (tester) async {
      await loginAs(tester, _ownerEmail, _ownerPassword);
      expectNavTabs(tabsFor(AppRole.owner));
      await pumpUntil(tester, find.widgetWithText(AppBar, 'Home'));
    });

    testWidgets('kasir1 masuk ke Kasir tanpa Staf/Home', (tester) async {
      await loginAs(tester, _cashierLogin, _cashierPassword);
      expectNavTabs(tabsFor(AppRole.cashier));
      await pumpUntil(tester, find.widgetWithText(AppBar, 'Kasir'));
    });

    testWidgets('gudang2 masuk ke Terima barang tanpa Kasir', (tester) async {
      await loginAs(tester, _warehouseLogin, _warehousePassword);
      expectNavTabs(tabsFor(AppRole.warehouse));
      await pumpUntil(tester, find.text('Terima barang'));
    });
  });

  group('B — Gudang', () {
    testWidgets('produk baru UJI tanpa harga + stok awal, lalu Terima barang', (tester) async {
      await loginAs(tester, _warehouseLogin, _warehousePassword);

      // Produk baru dari tab Produk; form gudang tidak punya kolom harga.
      await openTab(tester, AppTab.produk);
      await pumpUntil(tester, find.byKey(const Key('stock-new-product')));
      await tester.tap(find.byKey(const Key('stock-new-product')));
      await pumpUntil(tester, find.byKey(const Key('np-code')));
      await settleRoute(tester);
      expect(find.widgetWithText(TextFormField, 'Harga jual'), findsNothing);
      await tester.enterText(find.byKey(const Key('np-code')), _code);
      await tester.enterText(find.byKey(const Key('np-name')), _name);
      await scrollTo(tester, find.byKey(const Key('np-qty'))); // ListView: kolom bawah belum dibangun
      await tester.enterText(find.byKey(const Key('np-qty')), '$_initialQty');
      await tester.tap(find.byKey(const Key('np-save')));
      await pumpUntil(tester, find.text('Produk $_name tersimpan'));
      await pumpUntilGone(tester, find.byKey(const Key('np-save')));
      await settleRoute(tester);
      // SnackBar menutupi tombol bawah selama ~4 dtk; tunggu hilang sebelum mengetuk.
      await pumpUntilGone(tester, find.byType(SnackBar));

      // Tampil di daftar Produk dengan stok awal, tanpa harga.
      await pumpUntil(tester, find.byType(ListView));
      await scrollTo(tester, find.text(_name));
      expect(find.descendant(of: stockTile(), matching: find.text('$_initialQty')), findsOneWidget);
      expect(find.descendant(of: stockTile(), matching: find.textContaining('Rp')), findsNothing);

      // Terima barang: cari kode -> baris -> jumlah -> simpan.
      await openTab(tester, AppTab.terima);
      await tester.enterText(find.byKey(const Key('receive-search')), _code);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await pumpUntil(tester, find.byKey(const Key('receive-qty-1')));
      await tester.enterText(find.byKey(const Key('receive-qty-1')), '$_receivedQty');
      await tester.pump();
      await tester.tap(find.byKey(const Key('receive-save')));
      await pumpUntil(tester, find.byKey(const Key('receive-summary')));
      expect(find.byKey(const Key('receive-qty-1')), findsNothing, reason: 'baris sukses hilang');
      expect(find.byKey(const Key('receive-error-1')), findsNothing);
    });
  });

  group('C — Owner', () {
    testWidgets('owner menetapkan harga jual & modal produk UJI', (tester) async {
      await loginAs(tester, _ownerEmail, _ownerPassword);
      await openTab(tester, AppTab.stok);
      await pumpUntil(tester, find.byType(ListView));
      await scrollTo(tester, find.text(_name));
      expect(find.descendant(of: stockTile(), matching: find.text('${_initialQty + _receivedQty}')), findsOneWidget);
      await tester.tap(find.descendant(of: stockTile(), matching: find.byTooltip('Edit Barang')));

      await pumpUntil(tester, find.text('Detail barang'));
      await settleRoute(tester);
      final capital = find.byKey(const Key('detail-capital'));
      await scrollTo(tester, find.byKey(const Key('detail-price')));
      await tester.enterText(find.byKey(const Key('detail-price')), '$_price');
      await scrollTo(tester, capital);
      await pumpUntil(tester, find.byWidgetPredicate((w) => w is TextField && w.enabled == true && w.decoration?.labelText == 'Modal'));
      await tester.enterText(capital, '$_capital');
      await tester.pump();
      await scrollTo(tester, find.byKey(const Key('detail-save')));
      await tester.tap(find.byKey(const Key('detail-save')));
      await pumpUntil(tester, find.text('Barang disimpan'));
      expect(find.byKey(const Key('detail-error')), findsNothing);

      // Kembali ke daftar Stok: harga baru tampil.
      await pumpUntilGone(tester, find.byKey(const Key('detail-save')));
      await settleRoute(tester);
      await pumpUntilGone(tester, find.byType(SnackBar));
      await scrollTo(tester, find.text(_name));
      await pumpUntil(tester, find.descendant(of: stockTile(), matching: find.text(formatRupiah(_price))));
    });
  });

  group('D — Kasir', () {
    testWidgets('kasir1 menjual 2 produk UJI tunai uang pas', (tester) async {
      await loginAs(tester, _cashierLogin, _cashierPassword);
      await pumpUntil(tester, find.byKey(const Key('cashier-search')));
      await tester.enterText(find.byKey(const Key('cashier-search')), _code);
      final tile = find.byKey(ValueKey('product-$_code'));
      await pumpUntil(tester, tile);
      expect(find.descendant(of: tile, matching: find.text(formatRupiah(_price))), findsOneWidget);
      await tester.tap(tile);
      await tester.pump();

      final cartBar = find.byKey(const Key('cart-bar'));
      await pumpUntil(tester, find.descendant(of: cartBar, matching: find.text('Keranjang (1) · ${formatRupiah(_price)}')));
      await tester.tap(cartBar);
      await pumpUntil(tester, find.byKey(ValueKey('inc-$_code')));
      await tester.tap(find.byKey(ValueKey('inc-$_code')));
      await tester.pump();
      final total = _price * _soldQty;
      await pumpUntil(tester, find.text('Bayar ${formatRupiah(total)}'));
      await tester.tap(find.byKey(const Key('pay-button')));

      await pumpUntil(tester, find.byKey(const Key('quick-exact')));
      expect(find.descendant(of: find.byKey(const Key('pay-total')), matching: find.text(formatRupiah(total))), findsOneWidget);
      await tester.tap(find.byKey(const Key('quick-exact')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('pay-confirm')));
      await pumpUntil(tester, find.byKey(const Key('checkout-done')), timeout: const Duration(seconds: 30));
      expect(find.byKey(const Key('pay-error')), findsNothing);
      _receiptNo = tester.widget<Text>(find.byKey(const Key('done-receipt-no'))).data;
      expect(_receiptNo, isNotEmpty);
      // ignore: avoid_print
      print('DATA UJI: produk $_code, struk $_receiptNo');

      // Riwayat saya memuat struk ini.
      await tester.tap(find.byKey(const Key('new-transaction')));
      await tester.pump();
      await openTab(tester, AppTab.riwayatSaya);
      await pumpUntil(tester, find.text('Struk $_receiptNo'));
    });
  });

  group('E — Verifikasi silang', () {
    testWidgets('owner melihat struk kasir dan stok berkurang', (tester) async {
      expect(_receiptNo, isNotNull, reason: 'Alur D gagal; tidak ada struk');
      await loginAs(tester, _ownerEmail, _ownerPassword);

      await openTab(tester, AppTab.riwayat);
      final receipt = find.text('Struk $_receiptNo');
      await pumpUntil(tester, receipt);
      final row = find.ancestor(of: receipt, matching: find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('history-')));
      expect(find.descendant(of: row, matching: find.text(formatRupiah(_price * _soldQty))), findsOneWidget);
      await tester.tap(receipt);
      await pumpUntil(tester, find.text(_name));
      expect(find.text('${formatQty(_soldQty)} × ${formatRupiah(_price)}'), findsOneWidget);
      Navigator.of(tester.element(find.text(_name))).pop(); // tutup lembar detail
      await tester.pump(const Duration(milliseconds: 500));

      await openTab(tester, AppTab.stok);
      await pumpUntil(tester, find.byType(ListView));
      await scrollTo(tester, find.text(_name));
      expect(find.descendant(of: stockTile(), matching: find.text('${_initialQty + _receivedQty - _soldQty}')), findsOneWidget);
    });

    testWidgets('gudang2 melihat stok sisa tanpa harga', (tester) async {
      await loginAs(tester, _warehouseLogin, _warehousePassword);
      await openTab(tester, AppTab.produk);
      await pumpUntil(tester, find.byType(ListView));
      await scrollTo(tester, find.text(_name));
      expect(find.descendant(of: stockTile(), matching: find.text('${_initialQty + _receivedQty - _soldQty}')), findsOneWidget);
      expect(find.descendant(of: stockTile(), matching: find.textContaining('Rp')), findsNothing);
    });
  });

  group('Bagian 3 — Staf (owner)', () {
    testWidgets('owner membuat staf UJI-gudang berperan gudang -> tampil "Gudang"', (tester) async {
      await loginAs(tester, _ownerEmail, _ownerPassword);

      await openTab(tester, AppTab.staf);
      final addButton = find.text('Tambah staf');
      await pumpUntil(tester, addButton);
      await tester.tap(addButton.last);
      await pumpUntil(tester, find.text('Simpan staf'));

      // Username unik agar tes bisa diulang (username dipakai -> 409).
      final fullName = 'UJI-gudang $_stamp';
      await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'uji-gudang-$_stamp');
      await tester.enterText(find.widgetWithText(TextFormField, 'Nama Lengkap'), fullName);
      await tester.tap(find.byType(DropdownButtonFormField<AppRole>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppRole.warehouse.label).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Password Awal'), 'UjiGudang-$_stamp');
      await tester.tap(find.text('Simpan staf'));
      // find.text juga cocok dengan isian form; tunggu form tertutup dulu.
      await pumpUntilGone(tester, find.text('Simpan staf'), timeout: const Duration(seconds: 30));

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
      // ignore: avoid_print
      print('DATA UJI: staf uji-gudang-$_stamp');
    });
  });
}
