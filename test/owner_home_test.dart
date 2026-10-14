import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/core/app_exception.dart';
import 'package:minimarket_pos/core/permissions.dart';
import 'package:minimarket_pos/core/validators.dart';
import 'package:minimarket_pos/data/attention.dart';
import 'package:minimarket_pos/data/providers.dart';
import 'package:minimarket_pos/data/revenue.dart';
import 'package:minimarket_pos/data/session.dart';
import 'package:minimarket_pos/presentation/edit_product_screen.dart';
import 'package:minimarket_pos/presentation/owner/home_screen.dart';
import 'package:minimarket_pos/presentation/owner/product_detail_screen.dart';
import 'package:minimarket_pos/presentation/stock_list_screen.dart';

import 'fakes.dart';

/// 13 Okt 2026 10:00 WIB.
final now = DateTime.utc(2026, 10, 13, 3);

Map<String, dynamic> product(String id, {int price = 3500, num minStock = 0, bool deleted = false}) => {
      'id': id,
      'brand_name': 'Barang $id',
      'category_id': 1,
      'price': price,
      'min_stock': minStock,
      'unit_type': 'pcs',
      'is_deleted': deleted,
    };

Map<String, dynamic> batch(Map<String, dynamic> p, num qty, {String floor = 'Lantai 1', String? expiry}) => {
      'id': qty.hashCode ^ floor.hashCode ^ expiry.hashCode,
      'product_id': p['id'],
      'floor_name': floor,
      'expiry_date': expiry,
      'quantity': qty,
      'products': p,
    };

RevenueRow tx(int amount, DateTime createdAt) => (amount: amount, createdAt: createdAt);

List<(AttentionKind, String)> summary(List<AttentionItem> items) => [for (final i in items) (i.kind, i.productId)];

Future<void> pumpOwner(
  WidgetTester tester,
  Widget home, {
  AppRole role = AppRole.owner,
  FakeTransactionRepository? transactions,
  FakeProductRepository? products,
  FakeStockRepository? stock,
}) {
  return tester.pumpWidget(ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      currentRoleProvider.overrideWithValue(role),
      currentProfileProvider.overrideWithValue(null),
      clockProvider.overrideWithValue(() => now),
      transactionRepositoryProvider.overrideWithValue(transactions ?? FakeTransactionRepository()),
      productRepositoryProvider.overrideWithValue(products ?? FakeProductRepository()),
      stockRepositoryProvider.overrideWithValue(stock ?? FakeStockRepository([])),
    ],
    child: MaterialApp(home: home),
  ));
}

/// Layar awal dengan tombol yang membuka Detail barang; hasil pop dicatat di [results].
Widget detailLauncher(Map<String, dynamic> p, List<Object?> results) => Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async => results.add(
            await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p))),
          ),
          child: const Text('buka'),
        ),
      ),
    );

void main() {
  group('omzet (hari kalender WIB)', () {
    test('rentang ambil = kemarin 00:00 WIB s/d besok 00:00 WIB', () {
      final r = revenueRangeUtc(now);
      expect(r.start, DateTime.utc(2026, 10, 11, 17));
      expect(r.end, DateTime.utc(2026, 10, 13, 17));
    });

    test('00:30 WIB masuk hari itu, 23:59 WIB kemarin tidak', () {
      final s = summarizeRevenue([
        tx(10000, DateTime.utc(2026, 10, 12, 17, 30)), // 13 Okt 00:30 WIB
        tx(5000, DateTime.utc(2026, 10, 12, 16, 59)), // 12 Okt 23:59 WIB
        tx(999, DateTime.utc(2026, 10, 11, 16, 59)), // 11 Okt: di luar rentang
        tx(999, DateTime.utc(2026, 10, 13, 17)), // 14 Okt 00:00 WIB: di luar rentang
      ], now);
      expect((s.todayTotal, s.todayCount), (10000, 1));
      expect((s.yesterdayTotal, s.yesterdayCount), (5000, 1));
      expect(s.changePercent, 100);
    });

    test('kemarin kosong -> tanpa perbandingan', () {
      final s = summarizeRevenue([tx(10000, DateTime.utc(2026, 10, 13, 1))], now);
      expect(s.changePercent, isNull);
      expect(summarizeRevenue([], now).changePercent, isNull);
    });

    test('persen dibulatkan', () {
      final yesterday = DateTime.utc(2026, 10, 12, 5);
      final today = DateTime.utc(2026, 10, 13, 1);
      expect(summarizeRevenue([tx(3000, yesterday), tx(10000, today)], now).changePercent, 233); // 233,3
      expect(summarizeRevenue([tx(3000, yesterday), tx(2000, today)], now).changePercent, -33); // -33,3
      expect(summarizeRevenue([tx(3000, yesterday), tx(1000, today)], now).changePercent, -67); // -66,7
      expect(summarizeRevenue([tx(3000, yesterday)], now).changePercent, -100);
    });
  });

  group('prioritas "Perlu diurus"', () {
    final cases = <String, (List<Map<String, dynamic>>, List<Map<String, dynamic>> Function(List<Map<String, dynamic>>), List<(AttentionKind, String)>)>{
      'tepat 14 hari = hampir kedaluwarsa, 15 hari tidak': (
        [product('A'), product('B')],
        (p) => [batch(p[0], 5, expiry: '2026-10-27'), batch(p[1], 5, expiry: '2026-10-28')],
        [(AttentionKind.nearExpiry, 'A')],
      ),
      'tanggal hari ini masih layak (hampir), kemarin kedaluwarsa': (
        [product('A'), product('B')],
        (p) => [batch(p[0], 5, expiry: '2026-10-13'), batch(p[1], 5, expiry: '2026-10-12')],
        [(AttentionKind.expired, 'B'), (AttentionKind.nearExpiry, 'A')],
      ),
      'batch qty 0 tidak dihitung kedaluwarsa/hampir': (
        [product('A'), product('B')],
        (p) => [batch(p[0], 0, expiry: '2026-10-01'), batch(p[1], 0, expiry: '2026-10-20')],
        [],
      ),
      'batch campur: kedaluwarsa tidak menolong stok layak jual': (
        [product('A', minStock: 10)],
        (p) => [batch(p[0], 50, expiry: '2026-10-01'), batch(p[0], 3, floor: 'Lantai 2')],
        [(AttentionKind.expired, 'A'), (AttentionKind.belowMin, 'A')],
      ),
      'stok = minimum tidak muncul; tanpa batch = sisa 0': (
        [product('A', minStock: 5), product('B', minStock: 5)],
        (p) => [batch(p[0], 5)],
        [(AttentionKind.belowMin, 'B')],
      ),
      'produk dihapus tidak muncul': (
        [product('A'), product('X', price: 0, minStock: 99, deleted: true)],
        (p) => [batch(p[1], 5, expiry: '2026-10-01'), batch(product('Y', deleted: true), 5, expiry: '2026-10-01')],
        [],
      ),
      'urutan: kedaluwarsa -> hampir -> di bawah minimum -> harga 0': (
        [product('P', price: 0), product('M', minStock: 10), product('N'), product('E')],
        (p) => [batch(p[0], 5), batch(p[1], 3), batch(p[2], 5, expiry: '2026-10-20'), batch(p[3], 5, expiry: '2026-10-01')],
        [(AttentionKind.expired, 'E'), (AttentionKind.nearExpiry, 'N'), (AttentionKind.belowMin, 'M'), (AttentionKind.noPrice, 'P')],
      ),
      'dalam satu jenis: tanggal paling awal dulu': (
        [product('A'), product('B')],
        (p) => [batch(p[0], 5, expiry: '2026-10-25'), batch(p[1], 5, expiry: '2026-10-15')],
        [(AttentionKind.nearExpiry, 'B'), (AttentionKind.nearExpiry, 'A')],
      ),
      'dipotong 5 baris': (
        [for (final id in ['A', 'B', 'C', 'D', 'E', 'F', 'G']) product(id, price: 0)],
        (p) => [for (final x in p) batch(x, 5)],
        [for (final id in ['A', 'B', 'C', 'D', 'E']) (AttentionKind.noPrice, id)],
      ),
    };

    for (final e in cases.entries) {
      test(e.key, () {
        final (products, rows, expected) = e.value;
        expect(summary(attentionItems(products: products, stockRows: rows(products), now: now)), expected);
      });
    }

    test('rincian satu baris', () {
      final a = product('A', minStock: 10);
      final items = attentionItems(products: [a], stockRows: [batch(a, 5, expiry: '2026-10-01'), batch(a, 3)], now: now);
      expect(items.map((i) => i.detail), ['Lantai 1 · 1 Okt 2026 · 5 pcs', 'sisa 3, batas minimum 10']);
      expect(nearExpiryDays, 14);
    });
  });

  test('validasi uang: bilangan bulat >= 0', () {
    expect(validateRupiahInput('0'), isNull);
    expect(validateRupiahInput('12.500'), isNull);
    expect(validateRupiahInput(''), isNotNull);
    expect(validateRupiahInput('-5'), isNotNull);
    expect(validateRupiahInput('12,5'), isNotNull);
    expect(validateMinStock('2.5'), isNull);
    expect(validateMinStock('-1'), isNotNull);
  });

  group('Home owner', () {
    testWidgets('kartu omzet: total, jumlah transaksi, perbandingan dengan kemarin', (tester) async {
      final transactions = FakeTransactionRepository()
        ..revenueRows.addAll([
          tx(10000, DateTime.utc(2026, 10, 12, 17, 30)),
          tx(5000, DateTime.utc(2026, 10, 13, 2)),
          tx(10000, DateTime.utc(2026, 10, 12, 16, 59)),
        ]);
      await pumpOwner(tester, const HomeScreen(), transactions: transactions);
      expect(find.byKey(const Key('home-revenue-skeleton')), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('Omzet hari ini'), findsOneWidget);
      expect(find.text('Rp 15.000'), findsOneWidget);
      expect(find.text('2 transaksi'), findsOneWidget);
      expect(find.text('Naik 50% dari kemarin'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('kemarin tanpa transaksi: tanpa perbandingan', (tester) async {
      final transactions = FakeTransactionRepository()..revenueRows.add(tx(10000, DateTime.utc(2026, 10, 13, 1)));
      await pumpOwner(tester, const HomeScreen(), transactions: transactions);
      await tester.pumpAndSettle();
      expect(find.text('1 transaksi'), findsOneWidget);
      expect(find.byKey(const Key('home-revenue-change')), findsNothing);
    });

    testWidgets('daftar Perlu diurus: nama, rincian, lencana; ketuk membuka Detail barang', (tester) async {
      final a = product('A', price: 0);
      final b = product('B', minStock: 10);
      final products = FakeProductRepository([a, b]);
      final stock = FakeStockRepository([batch(a, 5), batch(b, 3)]);
      await pumpOwner(tester, const HomeScreen(), products: products, stock: stock);
      await tester.pumpAndSettle();

      expect(find.text('Perlu diurus'), findsOneWidget);
      final first = find.byKey(const Key('attention-0'));
      expect(find.descendant(of: first, matching: find.text('Barang B')), findsOneWidget);
      expect(find.descendant(of: first, matching: find.text('sisa 3, batas minimum 10')), findsOneWidget);
      expect(find.descendant(of: first, matching: find.text('Menipis')), findsOneWidget);
      final second = find.byKey(const Key('attention-1'));
      expect(find.descendant(of: second, matching: find.text('Harga belum diatur')), findsOneWidget);

      await tester.tap(second);
      await tester.pumpAndSettle();
      expect(find.byType(ProductDetailScreen), findsOneWidget);
      expect(find.text('Detail barang'), findsOneWidget);
    });

    testWidgets('kosong: "Semua beres"', (tester) async {
      final a = product('A');
      await pumpOwner(tester, const HomeScreen(), products: FakeProductRepository([a]), stock: FakeStockRepository([batch(a, 5)]));
      await tester.pumpAndSettle();
      expect(find.text('Semua beres. Tidak ada yang perlu diurus.'), findsOneWidget);
    });

    testWidgets('galat bertipe + Coba lagi memuat ulang', (tester) async {
      final transactions = FakeTransactionRepository()
        ..revenueRows.add(tx(7000, DateTime.utc(2026, 10, 13, 1)))
        ..revenueError = const AppException('Gagal memuat omzet', 'SocketException: Failed host lookup');
      await pumpOwner(tester, const HomeScreen(), transactions: transactions);
      await tester.pumpAndSettle();

      expect(find.text('Gagal memuat omzet'), findsOneWidget);
      expect(find.text('Koneksi terputus. Periksa internet lalu coba lagi.'), findsOneWidget);
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Rp 7.000'), findsOneWidget);
      expect(transactions.revenueLoads, 2);
    });

    testWidgets('galat daftar tampil terpisah dari kartu omzet', (tester) async {
      final products = FakeProductRepository()..loadError = const AppException('Gagal memuat daftar barang');
      await pumpOwner(tester, const HomeScreen(), products: products);
      await tester.pumpAndSettle();
      expect(find.text('Gagal memuat daftar barang'), findsOneWidget);
      expect(find.text('Rp 0'), findsOneWidget);
    });
  });

  group('Detail barang', () {
    Future<FakeProductRepository> open(WidgetTester tester, Map<String, dynamic> p,
        {int? capital, List<Map<String, dynamic>> stock = const [], List<Object?>? results}) async {
      final products = FakeProductRepository([p]);
      if (capital != null) products.capitalPrices[p['id']] = capital;
      await pumpOwner(tester, detailLauncher(p, results ?? []), products: products, stock: FakeStockRepository(stock));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      return products;
    }

    testWidgets('memuat modal, simpan harga & modal lewat repository', (tester) async {
      final results = <Object?>[];
      final products = await open(tester, product('A'), capital: 3000, results: results);
      expect(products.capitalReads, 1);
      expect(find.text('3.000'), findsOneWidget);
      expect(find.text('3.500'), findsOneWidget);
      expect(find.text('A'), findsOneWidget); // kode, baca saja

      await tester.enterText(find.byKey(const Key('detail-price')), '4000');
      await tester.enterText(find.byKey(const Key('detail-capital')), '2500');
      await tester.tap(find.byKey(const Key('detail-save')));
      await tester.pumpAndSettle();

      final (saved, includePrices) = products.updates.single;
      expect((saved.id, saved.price, includePrices), ('A', 4000, true));
      expect(products.capitalSaves, [('A', 2500)]);
      expect(results, [true]);
    });

    testWidgets('modal tidak berubah = tidak ditulis', (tester) async {
      final products = await open(tester, product('A'), capital: 3000);
      await tester.tap(find.byKey(const Key('detail-save')));
      await tester.pumpAndSettle();
      expect(products.updates, hasLength(1));
      expect(products.capitalSaves, isEmpty);
    });

    testWidgets('harga 0 diberi peringatan tapi tetap bisa disimpan', (tester) async {
      final products = await open(tester, product('A', price: 0));
      expect(find.text('Harga belum diatur'), findsOneWidget);
      await tester.tap(find.byKey(const Key('detail-save')));
      await tester.pumpAndSettle();
      expect(products.updates.single.$1.price, 0);
    });

    testWidgets('modal > harga = peringatan, bukan blokir', (tester) async {
      final products = await open(tester, product('A'), capital: 3000);
      await tester.enterText(find.byKey(const Key('detail-price')), '2000');
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      expect(find.text('Modal lebih besar dari harga jual'), findsOneWidget);
      await tester.tap(find.byKey(const Key('detail-save')));
      await tester.pumpAndSettle();
      expect(products.updates.single.$1.price, 2000);
    });

    testWidgets('galat server ditampilkan apa adanya, layar tetap', (tester) async {
      final products = FakeProductRepository([product('A')])..updateError = const AppException('Nama barang sudah dipakai');
      await pumpOwner(tester, detailLauncher(product('A'), []), products: products);
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('detail-save')));
      await tester.pumpAndSettle();
      expect(find.text('Nama barang sudah dipakai'), findsOneWidget);
      expect(find.byType(ProductDetailScreen), findsOneWidget);
    });

    testWidgets('hapus butuh konfirmasi yang menyebut nama; bahaya kiri, Batal kanan', (tester) async {
      final results = <Object?>[];
      final products = await open(tester, product('A'), results: results);

      await tester.tap(find.byKey(const Key('detail-delete')));
      await tester.pumpAndSettle();
      expect(find.text('Hapus Barang A?'), findsOneWidget);
      expect(tester.getCenter(find.byKey(const Key('confirm-delete'))).dx, lessThan(tester.getCenter(find.text('Batal')).dx));
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(products.deleted, isEmpty);

      await tester.tap(find.byKey(const Key('detail-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-delete')));
      await tester.pumpAndSettle();
      expect(products.deleted, ['A']);
      expect(results, [true]);
    });

    testWidgets('stok per lantai/batch, batch kedaluwarsa berlabel', (tester) async {
      final a = product('A');
      await open(tester, a, stock: [batch(a, 5, expiry: '2026-10-01'), batch(a, 7, floor: 'Lantai 2')]);
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('Lantai 1 · Exp 1 Okt 2026'), findsOneWidget);
      expect(find.text('Kedaluwarsa'), findsOneWidget);
      expect(find.text('7 pcs'), findsOneWidget);
    });

    for (final role in [AppRole.warehouse, AppRole.cashier]) {
      testWidgets('${role.label} tidak punya akses ke layar ini', (tester) async {
        final products = FakeProductRepository()..capitalPrices['A'] = 3000;
        await pumpOwner(tester, ProductDetailScreen(product: product('A')), role: role, products: products);
        await tester.pumpAndSettle();
        expect(find.text('Halaman ini khusus owner.'), findsOneWidget);
        expect(find.text('Simpan'), findsNothing);
        expect(products.capitalReads, 0);
      });
    }

    testWidgets('daftar stok: owner membuka Detail barang, gudang form edit tanpa harga', (tester) async {
      final a = product('A');
      for (final (role, screen) in [(AppRole.owner, ProductDetailScreen), (AppRole.warehouse, EditProductScreen)]) {
        await tester.pumpWidget(const SizedBox()); // ProviderScope baru per peran
        await pumpOwner(tester, const StockListScreen(), role: role, stock: FakeStockRepository([batch(a, 5)]));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Edit Barang'));
        await tester.pumpAndSettle();
        expect(find.byType(screen), findsOneWidget, reason: role.name);
      }
    });
  });
}
