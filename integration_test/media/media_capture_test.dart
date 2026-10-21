// Pengambilan media README (screenshot + rekaman), bukan tes fungsional. Tidak ikut CI
// (CI hanya `flutter test` atas test/). Perintah lengkap: media/manifest.md.
//   Android: python integration_test/media/capture.py android
//   PC/web : python integration_test/media/capture.py web
// Android: tiap langkah media mencetak "MEDIA|id|perintah|arg|file-ack"; capture.py menjalankannya
// (screencap, mode gelap, jaringan, screenrecord, tarik berkas) lalu membuat file-ack lewat run-as.
// Web: screenshot lewat binding.takeScreenshot -> media_driver.dart.
// Data: hanya membaca, kecuali satu checkout pada rekaman kasir. Form gudang/staf TIDAK disimpan.
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:minimarket_pos/core/format.dart';
import 'package:minimarket_pos/data/checkout_controller.dart';
import 'package:minimarket_pos/data/receipt_pdf.dart';
import 'package:minimarket_pos/data/session.dart';
import 'package:minimarket_pos/presentation/app_shell.dart';
import 'package:minimarket_pos/main.dart' as app;
import 'package:minimarket_pos/presentation/cashier_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ownerEmail = String.fromEnvironment('OWNER_EMAIL');
const _ownerPassword = String.fromEnvironment('OWNER_PASSWORD');
const _cashierLogin = String.fromEnvironment('CASHIER_EMAIL');
const _cashierPassword = String.fromEnvironment('CASHIER_PASSWORD');
const _warehouseLogin = String.fromEnvironment('WAREHOUSE_EMAIL');
const _warehousePassword = String.fromEnvironment('WAREHOUSE_PASSWORD');

// Helper sama dengan app_test.dart; disalin karena build web hanya melayani folder target ini.

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

/// Mulai aplikasi di layar Login (sesi tersimpan dari tes sebelumnya dikeluarkan).
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

late IntegrationTestWidgetsFlutterBinding _binding;
var _seq = 0;

/// Minta capture.py menjalankan [cmd] di host, lalu tunggu file-ack (frame tetap dipompa).
Future<void> host(WidgetTester tester, String cmd, [String arg = '']) async {
  final id = ++_seq;
  final ack = File('${Directory.systemTemp.path}/media-ack-$id');
  if (ack.existsSync()) ack.deleteSync();
  print('MEDIA|$id|$cmd|$arg|${ack.path}');
  final end = DateTime.now().add(const Duration(seconds: 90));
  while (!ack.existsSync()) {
    if (DateTime.now().isAfter(end)) fail('capture.py tidak menjawab: $cmd $arg');
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Screenshot [name] (tanpa .png) setelah indikator ketuk & animasi mereda.
Future<void> shot(WidgetTester tester, String name) async {
  // Keyboard layar asli ikut muncul di integration test; sembunyikan agar isi tidak tertutup.
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await tester.pump(const Duration(milliseconds: 1200));
  if (kIsWeb) {
    await _binding.takeScreenshot(name);
  } else {
    await host(tester, 'shot', name);
  }
}

/// Screenshot dalam mode gelap sistem (Android), lalu kembali terang.
Future<void> darkShot(WidgetTester tester, String name) async {
  await host(tester, 'night', 'yes');
  await tester.pump(const Duration(milliseconds: 800));
  await shot(tester, name);
  await host(tester, 'night', 'no');
  await tester.pump(const Duration(milliseconds: 800));
}

Finder keyPrefix(String prefix) =>
    find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith(prefix));

/// Ketik seperti manusia (untuk rekaman): satu huruf per ~90 ms.
Future<void> typeSlowly(WidgetTester tester, Finder field, String text) async {
  for (var i = 1; i <= text.length; i++) {
    await tester.enterText(field, text.substring(0, i));
    await tester.pump(const Duration(milliseconds: 90));
  }
}

Future<void> pause(WidgetTester tester, [int ms = 700]) => tester.pump(Duration(milliseconds: ms));

/// Tambah [code] ke keranjang Kasir lewat kolom cari + Enter (sama seperti scan).
Future<void> scanCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byKey(const Key('cashier-search')), code);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Tombol uang cepat pertama selain "Uang pas".
Finder firstQuickCash() => find.byWidgetPredicate((w) {
      final k = w.key;
      return k is ValueKey<String> && k.value.startsWith('quick-') && k.value != 'quick-exact';
    }).first;

/// Gulir daftar utama dari atas sampai [finder] terlihat.
Future<void> scrollFromTop(WidgetTester tester, Finder finder) async {
  final list = find.byType(Scrollable).hitTestable().first;
  tester.state<ScrollableState>(list).position.jumpTo(0);
  await tester.pump();
  await tester.scrollUntilVisible(finder, 300, scrollable: list, maxScrolls: 100);
  await Scrollable.ensureVisible(tester.element(finder.first), alignment: 0.4); // tengah layar
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> pickWarehouseProduct(WidgetTester tester, String prefix, String code) async {
  await tester.enterText(find.byKey(Key('$prefix-search')), code);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    _webTests();
  } else {
    _androidTests();
  }
}

void _androidTests() {
  testWidgets('umum — Login', (tester) async {
    await startAtLogin(tester);
    await settleRoute(tester);
    await shot(tester, '01-umum-login-kosong');
    await darkShot(tester, '02-umum-login-kosong-gelap');
    // Akun fiktif: email/password asli tidak pernah tampil di layar yang diambil.
    await submitLogin(tester, 'kasir.contoh', 'sandi-salah');
    await pumpUntil(tester, find.byKey(const Key('login-error')));
    await shot(tester, '03-umum-login-error');
  });

  testWidgets('kasir — keranjang, bayar, stok', (tester) async {
    await loginAs(tester, _cashierLogin, _cashierPassword);
    await pumpUntil(tester, find.byKey(const ValueKey('product-DEMO-01')));
    await shot(tester, '04-kasir-kasir-keranjang-kosong');

    for (final code in ['DEMO-05', 'DEMO-01', 'DEMO-18', 'DEMO-18']) {
      await scanCode(tester, code);
    }
    await pumpUntil(tester, find.textContaining('Keranjang (3)'));
    await tester.tap(find.byKey(const Key('cart-bar')));
    await pumpUntil(tester, find.byKey(const Key('cart-page')));
    await settleRoute(tester);
    await shot(tester, '05-kasir-keranjang-3-item');
    await darkShot(tester, '06-kasir-keranjang-3-item-gelap');

    await tester.tap(find.byKey(const Key('pay-button')));
    await pumpUntil(tester, find.byKey(const Key('quick-exact')));
    await settleRoute(tester);
    await tester.tap(firstQuickCash());
    await pause(tester);
    await shot(tester, '07-kasir-bayar-tunai-uang-cepat');
    await tester.tap(find.byKey(const ValueKey('method-qris')));
    await pumpUntil(tester, find.text('Sudah dibayar'));
    await shot(tester, '08-kasir-bayar-qris-konfirmasi');
    await tester.tap(find.byKey(const Key('pay-back'))); // tidak dibayar
    await pause(tester);

    await openTab(tester, AppTab.stok);
    await pumpUntil(tester, find.byType(ListView));
    await shot(tester, '09-kasir-stok-daftar');
    // Daftar Stok hanya punya lencana "Kedaluwarsa" (terlihat di 09) dan "Habis" (lihat manifest).
    await scrollFromTop(tester, find.text('Habis'));
    await shot(tester, '10-kasir-stok-habis');

    // Stok rendah tampil di kartu produk Kasir ("Menipis").
    await openTab(tester, AppTab.kasir);
    await tester.enterText(find.byKey(const Key('cashier-search')), 'mi');
    await pause(tester);
    await shot(tester, '11-kasir-kasir-stok-menipis');
  });

  testWidgets('kasir — rekaman checkout, struk', (tester) async {
    await loginAs(tester, _cashierLogin, _cashierPassword);
    final search = find.byKey(const Key('cashier-search'));
    await pumpUntil(tester, find.byKey(const ValueKey('product-DEMO-01')));
    await pause(tester, 1500);

    await host(tester, 'rec-start'); // rekaman dimulai SETELAH login
    await pause(tester, 800);
    await typeSlowly(tester, search, 'teh botol');
    await pumpUntil(tester, find.byKey(const ValueKey('product-DEMO-05')));
    await pause(tester, 500);
    await tester.tap(find.byKey(const ValueKey('product-DEMO-05')));
    await pause(tester);
    await typeSlowly(tester, search, 'keripik');
    await pumpUntil(tester, find.byKey(const ValueKey('product-DEMO-01')));
    await pause(tester, 500);
    await tester.tap(find.byKey(const ValueKey('product-DEMO-01')));
    await pause(tester);
    await typeSlowly(tester, search, 'DEMO-18'); // scan kode
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await pumpUntil(tester, find.textContaining('Keranjang (3)'));
    await pause(tester, 900);
    await tester.tap(find.byKey(const Key('cart-bar')));
    await pumpUntil(tester, find.byKey(const Key('cart-page')));
    await pause(tester, 1500);
    await tester.tap(find.byKey(const Key('pay-button')));
    await pumpUntil(tester, find.byKey(const Key('quick-exact')));
    await pause(tester, 1200);
    await tester.tap(firstQuickCash());
    await pause(tester, 1200);
    await tester.tap(find.byKey(const Key('pay-confirm')));
    await pumpUntil(tester, find.byKey(const Key('checkout-done')), timeout: const Duration(seconds: 30));
    await pause(tester, 2500);
    await host(tester, 'rec-stop');

    await shot(tester, '12-kasir-sukses-struk');

    // Struk PDF dari transaksi tersimpan (sama dengan tombol "Unduh struk"), dirender ke PNG di host.
    final container = ProviderScope.containerOf(tester.element(find.byType(CashierScreen)));
    final tx = container.read(checkoutControllerProvider).completed!;
    final bytes = await buildReceiptPdf(
      tx,
      cashierName: container.read(currentProfileProvider)?.fullName ?? '',
      regularFont: await rootBundle.load(receiptRegularFontAsset),
      boldFont: await rootBundle.load(receiptBoldFontAsset),
    );
    final pdf = File('${Directory.systemTemp.path}/media-struk.pdf')..writeAsBytesSync(bytes);
    await host(tester, 'pull', '${pdf.path}>13-kasir-struk-pdf-80mm.pdf');
    final items = tx.items.map((i) => '${i.productId} ${i.productName} x${formatQty(i.quantity)}').join('; ');
    await host(tester, 'note', 'struk ${tx.receiptNumber}; total ${formatRupiah(tx.totalAmount)}; tunai ${formatRupiah(tx.paidAmount)}; $items');
  });

  testWidgets('kasir — riwayat', (tester) async {
    await loginAs(tester, _cashierLogin, _cashierPassword);
    await openTab(tester, AppTab.riwayatSaya);
    await pumpUntil(tester, keyPrefix('history-'));
    await shot(tester, '14-kasir-riwayat');
  });

  testWidgets('gudang — stok, terima, produk baru, opname, pindah, tulis rugi', (tester) async {
    await loginAs(tester, _warehouseLogin, _warehousePassword);

    await openTab(tester, AppTab.produk);
    await pumpUntil(tester, find.byType(ListView));
    await shot(tester, '15-gudang-stok-daftar');

    // Terima: dua baris terisi, TIDAK disimpan.
    await openTab(tester, AppTab.terima);
    await pickWarehouseProduct(tester, 'receive', 'DEMO-08');
    await pumpUntil(tester, find.byKey(const Key('receive-qty-1')));
    await tester.enterText(find.byKey(const Key('receive-qty-1')), '24');
    await tester.tap(find.descendant(of: find.byKey(const Key('receive-floor-1')), matching: find.text('Lantai 2')));
    await pickWarehouseProduct(tester, 'receive', 'DEMO-18');
    await pumpUntil(tester, find.byKey(const Key('receive-qty-2')));
    await tester.enterText(find.byKey(const Key('receive-qty-2')), '48');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(tester, '16-gudang-terima-terisi');

    // Produk baru: terisi, TIDAK disimpan.
    await openTab(tester, AppTab.produk);
    await tester.tap(find.byKey(const Key('stock-new-product')));
    await pumpUntil(tester, find.byKey(const Key('np-code')));
    await settleRoute(tester);
    await tester.enterText(find.byKey(const Key('np-code')), '8991234500017');
    await tester.enterText(find.byKey(const Key('np-name')), 'Roti Tawar Gandum 400 g');
    await pause(tester, 2000); // kategori dimuat
    await tester.tap(find.byKey(const Key('np-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Snack').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('np-min')), '5');
    await tester.enterText(find.byKey(const Key('np-qty')), '12');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(tester, '17-gudang-produk-baru-terisi');
    await tester.pageBack();
    await pumpUntilGone(tester, find.byKey(const Key('np-code')));

    // Opname: hitung nyata berbeda (selisih), TIDAK disimpan.
    await openTab(tester, AppTab.opname);
    await pickWarehouseProduct(tester, 'opname', 'DEMO-03');
    await pumpUntil(tester, keyPrefix('opname-writeoff-'));
    await tester.enterText(keyPrefix('opname-count-').at(1), '22');
    FocusManager.instance.primaryFocus?.unfocus();
    await pause(tester);
    await shot(tester, '18-gudang-opname-selisih');

    // Tulis rugi: dialog konfirmasi, lalu Batal.
    await tester.tap(keyPrefix('opname-writeoff-').first);
    await pumpUntil(tester, find.byKey(const Key('writeoff-cancel')));
    await shot(tester, '19-gudang-tulis-rugi-konfirmasi');
    await tester.tap(find.byKey(const Key('writeoff-cancel')));
    await pumpUntilGone(tester, find.byKey(const Key('writeoff-cancel')));

    // Pindah lantai: batch + jumlah, TIDAK disimpan.
    await openTab(tester, AppTab.pindah);
    await pickWarehouseProduct(tester, 'transfer', 'DEMO-21');
    await pumpUntil(tester, keyPrefix('transfer-batch-'));
    await tester.tap(keyPrefix('transfer-batch-').last);
    await pumpUntil(tester, find.byKey(const Key('transfer-qty')));
    await tester.enterText(find.byKey(const Key('transfer-qty')), '6');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(tester, '20-gudang-pindah-lantai-terisi');
  });

  testWidgets('owner — home, detail, riwayat, staf', (tester) async {
    await loginAs(tester, _ownerEmail, _ownerPassword);
    await pumpUntil(tester, find.byKey(const Key('home-revenue')));
    await pumpUntil(tester, find.byKey(const Key('attention-0')));
    await shot(tester, '21-owner-home');
    await darkShot(tester, '22-owner-home-gelap');

    await tester.tap(find.byKey(const Key('attention-0')));
    await pumpUntil(tester, find.text('Detail barang'));
    await settleRoute(tester);
    await pumpUntil(tester, find.byWidgetPredicate((w) => w is TextField && w.enabled == true && w.decoration?.labelText == 'Modal'));
    await shot(tester, '23-owner-detail-barang');
    await tester.pageBack();
    await pumpUntilGone(tester, find.text('Detail barang'));

    await openTab(tester, AppTab.riwayat);
    await pumpUntil(tester, keyPrefix('history-'));
    await shot(tester, '24-owner-riwayat');
    await tester.tap(keyPrefix('history-').first);
    await pumpUntil(tester, find.textContaining(' × '));
    await shot(tester, '25-owner-riwayat-detail');
    Navigator.of(tester.element(find.textContaining(' × ').first)).pop();
    await pause(tester);

    await openTab(tester, AppTab.staf);
    await pumpUntil(tester, keyPrefix('staff-'));
    await shot(tester, '26-owner-staf');
    await tester.tap(find.text('Tambah staf').last);
    await pumpUntil(tester, find.text('Simpan staf'));
    await settleRoute(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'kasir2');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nama Lengkap'), 'Siti Rahma');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password Awal'), 'contoh-sandi-2026');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(tester, '27-owner-staf-tambah-terisi'); // TIDAK disimpan
    await tester.pageBack();
    await pumpUntilGone(tester, find.text('Simpan staf'));
  });

  testWidgets('owner — offline lalu pulih', (tester) async {
    await loginAs(tester, _ownerEmail, _ownerPassword);
    await pumpUntil(tester, find.byKey(const Key('home-revenue')));
    await pumpUntil(tester, find.byKey(const Key('attention-0')));

    await host(tester, 'net', 'off');
    // Koneksi keep-alive lama tidak langsung putus di emulator; tunggu idle timeout pool HTTP (15 dtk)
    // agar muat ulang membuka koneksi baru dan langsung gagal.
    await pause(tester, 20000);
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1500); // tarik untuk muat ulang
    try {
      await pumpUntil(tester, find.text('Coba lagi'), timeout: const Duration(seconds: 40));
    } on TestFailure {
      await shot(tester, 'debug-offline');
      rethrow;
    }
    await pumpUntilGone(tester, find.byType(RefreshProgressIndicator));
    await shot(tester, '28-owner-home-offline');

    await host(tester, 'net', 'on');
    final retry = find.text('Coba lagi');
    final end = DateTime.now().add(const Duration(seconds: 60));
    while (retry.evaluate().isNotEmpty) {
      if (DateTime.now().isAfter(end)) fail('Belum pulih setelah jaringan menyala');
      await tester.tap(retry.first);
      await pause(tester, 3000);
    }
    await pumpUntil(tester, find.byKey(const Key('home-revenue')));
    await pumpUntil(tester, find.byKey(const Key('attention-0')));
    await shot(tester, '29-owner-home-pulih');
  });

  // Perluasan (33-59): keadaan & dialog yang belum ada. Semua dialog ditutup dengan Batal; tanpa checkout.
  testWidgets('ext kasir — cari kosong, keluar, kosongkan, bayar gelap, riwayat detail', (tester) async {
    await loginAs(tester, _cashierLogin, _cashierPassword);
    await pumpUntil(tester, find.byKey(const ValueKey('product-DEMO-01')));
    await tester.enterText(find.byKey(const Key('cashier-search')), 'zzz');
    await pumpUntil(tester, find.text('Tidak ada barang yang cocok'));
    await shot(tester, '40-kasir-kasir-cari-kosong');
    await tester.enterText(find.byKey(const Key('cashier-search')), '');
    await pause(tester);

    await tester.tap(find.byTooltip('Akun').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar').last);
    await pumpUntil(tester, find.text('Keluar?'));
    await shot(tester, '39-kasir-akun-keluar-dialog');
    await tester.tap(find.text('Batal'));
    await pumpUntilGone(tester, find.text('Keluar?'));

    for (final code in ['DEMO-05', 'DEMO-01', 'DEMO-18', 'DEMO-18']) {
      await scanCode(tester, code);
    }
    await pumpUntil(tester, find.textContaining('Keranjang (3)'));
    await tester.tap(find.byKey(const Key('cart-bar')));
    await pumpUntil(tester, find.byKey(const Key('cart-page')));
    await settleRoute(tester);
    await tester.tap(find.byKey(const Key('clear-cart')));
    await pumpUntil(tester, find.byKey(const Key('confirm-clear')));
    await shot(tester, '41-kasir-keranjang-kosongkan-dialog');
    await tester.tap(find.text('Batal'));
    await pumpUntilGone(tester, find.byKey(const Key('confirm-clear')));

    await tester.tap(find.byKey(const Key('pay-button')));
    await pumpUntil(tester, find.byKey(const Key('quick-exact')));
    await settleRoute(tester);
    await tester.tap(firstQuickCash());
    await pause(tester);
    await darkShot(tester, '42-kasir-bayar-tunai-gelap');
    await tester.tap(find.byKey(const Key('pay-back'))); // tidak dibayar
    await pause(tester);
    final cartPage = find.byKey(const Key('cart-page'));
    if (cartPage.evaluate().isNotEmpty) Navigator.of(tester.element(cartPage)).pop();
    await pumpUntilGone(tester, cartPage);

    await openTab(tester, AppTab.riwayatSaya);
    await pumpUntil(tester, keyPrefix('history-'));
    await tester.tap(keyPrefix('history-').first);
    await pumpUntil(tester, find.textContaining(' × '));
    await shot(tester, '43-kasir-riwayat-detail');
    await darkShot(tester, '44-kasir-riwayat-detail-gelap');
    Navigator.of(tester.element(find.textContaining(' × ').first)).pop();
    await pause(tester);
  });

  testWidgets('ext gudang — terima kosong/kode baru/pilih/gelap, produk gelap, edit, stok masuk, pindah lantai', (tester) async {
    await loginAs(tester, _warehouseLogin, _warehousePassword);
    await pumpUntil(tester, find.textContaining('Belum ada barang'));
    await pause(tester, 1500); // daftar produk dimuat
    await shot(tester, '45-gudang-terima-kosong');

    await pickWarehouseProduct(tester, 'receive', '8990000000999');
    await pumpUntil(tester, find.byKey(const Key('receive-create-product')));
    await shot(tester, '46-gudang-terima-kode-baru');
    await tester.enterText(find.byKey(const Key('receive-search')), '');
    await pause(tester);

    await tester.tap(find.byKey(const Key('receive-add-line')));
    await pumpUntil(tester, keyPrefix('picker-'));
    await settleRoute(tester);
    await shot(tester, '47-gudang-terima-pilih-barang');
    Navigator.of(tester.element(keyPrefix('picker-').first)).pop();
    await pause(tester);

    await pickWarehouseProduct(tester, 'receive', 'DEMO-08');
    await pumpUntil(tester, find.byKey(const Key('receive-qty-1')));
    await tester.enterText(find.byKey(const Key('receive-qty-1')), '24');
    await tester.tap(find.descendant(of: find.byKey(const Key('receive-floor-1')), matching: find.text('Lantai 2')));
    await pickWarehouseProduct(tester, 'receive', 'DEMO-18');
    await pumpUntil(tester, find.byKey(const Key('receive-qty-2')));
    await tester.enterText(find.byKey(const Key('receive-qty-2')), '48');
    FocusManager.instance.primaryFocus?.unfocus();
    await darkShot(tester, '48-gudang-terima-terisi-gelap'); // TIDAK disimpan

    await openTab(tester, AppTab.produk);
    await pumpUntil(tester, find.byType(ListView));
    await darkShot(tester, '49-gudang-stok-daftar-gelap');

    await tester.tap(find.byTooltip('Edit Barang').first);
    await pumpUntil(tester, find.text('Simpan').hitTestable());
    await settleRoute(tester);
    await pause(tester, 1500); // kategori dimuat
    await shot(tester, '50-gudang-edit-barang'); // TIDAK disimpan
    await tester.pageBack();
    await settleRoute(tester);

    await tester.tap(find.byTooltip('Stok Masuk / Opname').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stok Masuk').last);
    await pumpUntil(tester, find.byKey(const Key('stockAdjustQty')));
    await shot(tester, '51-gudang-stok-masuk-dialog');
    await tester.tap(find.text('Batal'));
    await pumpUntilGone(tester, find.byKey(const Key('stockAdjustQty')));
  });

  testWidgets('ext gudang — pindah lantai terang & gelap', (tester) async {
    await loginAs(tester, _warehouseLogin, _warehousePassword);
    await openTab(tester, AppTab.produk);
    await pumpUntil(tester, find.byType(ListView));
    await pause(tester, 1500); // daftar produk dimuat

    await tester.tap(find.byTooltip('Pindah Lantai').first);
    await pumpUntil(tester, find.text('Pindahkan'));
    await settleRoute(tester);
    await shot(tester, '52-gudang-pindah-lantai-form'); // TIDAK disimpan
    await darkShot(tester, '52-gudang-pindah-lantai-form-gelap');
    await tester.pageBack();
    await settleRoute(tester);
  });

  testWidgets('ext owner — detail gelap, hapus, stok, tambah barang, staf gelap & dialog', (tester) async {
    await loginAs(tester, _ownerEmail, _ownerPassword);
    await pumpUntil(tester, find.byKey(const Key('home-revenue')));
    await pumpUntil(tester, find.byKey(const Key('attention-0')));

    await tester.tap(find.byKey(const Key('attention-0')));
    await pumpUntil(tester, find.text('Detail barang'));
    await settleRoute(tester);
    await pumpUntil(tester, find.byWidgetPredicate((w) => w is TextField && w.enabled == true && w.decoration?.labelText == 'Modal'));
    await darkShot(tester, '53-owner-detail-barang-gelap');
    await tester.ensureVisible(find.byKey(const Key('detail-delete')));
    await pause(tester);
    await tester.tap(find.byKey(const Key('detail-delete')));
    await pumpUntil(tester, find.byKey(const Key('confirm-delete')));
    await shot(tester, '54-owner-detail-hapus-dialog');
    await tester.tap(find.text('Batal'));
    await pumpUntilGone(tester, find.byKey(const Key('confirm-delete')));
    await tester.pageBack();
    await pumpUntilGone(tester, find.text('Detail barang'));

    await openTab(tester, AppTab.stok);
    await pumpUntil(tester, find.byType(ListView));
    await pause(tester, 1000);
    await shot(tester, '55-owner-stok-daftar');
    await tester.tap(find.byKey(const Key('stock-new-product')));
    await pumpUntil(tester, find.text('Simpan').hitTestable());
    await settleRoute(tester);
    await pause(tester, 1500);
    await shot(tester, '56-owner-tambah-barang-kosong');
    await tester.pageBack();
    await settleRoute(tester);

    await openTab(tester, AppTab.staf);
    await pumpUntil(tester, keyPrefix('staff-actions-'));
    await darkShot(tester, '57-owner-staf-gelap');
    final actions = keyPrefix('staff-actions-');
    await tester.tap(actions.at(1)); // bukan akun sendiri
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset password').last);
    await pumpUntil(tester, find.textContaining('Reset password '));
    await shot(tester, '58-owner-staf-reset-dialog');
    await tester.tap(find.text('Batal'));
    await pumpUntilGone(tester, find.textContaining('Reset password '));
    await tester.tap(actions.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(RegExp(r'^(Nonaktifkan|Aktifkan)$')).last);
    await pumpUntil(tester, find.byKey(const Key('confirm-toggle-active')));
    await shot(tester, '59-owner-staf-nonaktifkan-dialog');
    await tester.tap(find.text('Batal'));
    await pumpUntilGone(tester, find.byKey(const Key('confirm-toggle-active')));
  });
}

void _webTests() {
  testWidgets('pc — Kasir', (tester) async {
    await loginAs(tester, _cashierLogin, _cashierPassword);
    await pumpUntil(tester, find.byKey(const Key('cashier-pc')));
    await pumpUntil(tester, find.text('Siap scan'));
    await pause(tester, 1500); // daftar barang dimuat
    for (final code in ['DEMO-05', 'DEMO-01', 'DEMO-18', 'DEMO-18']) {
      await scanCode(tester, code);
      await pumpUntil(tester, find.byKey(const Key('scan-status')));
    }
    await pumpUntil(tester, keyPrefix('cart-row-DEMO-18'));
    await shot(tester, '30-pc-kasir-keranjang'); // tanpa bayar: data tidak berubah
  });

  testWidgets('pc — Home owner, Staf', (tester) async {
    await loginAs(tester, _ownerEmail, _ownerPassword);
    await pumpUntil(tester, find.byKey(const Key('home-revenue')));
    await pumpUntil(tester, find.byKey(const Key('attention-0')));
    await shot(tester, '31-pc-owner-home');
    await openTab(tester, AppTab.staf);
    await pumpUntil(tester, keyPrefix('staff-'));
    await shot(tester, '32-pc-owner-staf');
  });
}
