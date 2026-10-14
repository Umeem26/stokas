import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/core/permissions.dart';
import 'package:minimarket_pos/data/checkout_controller.dart';
import 'package:minimarket_pos/data/profile_model.dart';
import 'package:minimarket_pos/data/providers.dart';
import 'package:minimarket_pos/presentation/app_shell.dart';
import 'package:minimarket_pos/presentation/auth_gate.dart';
import 'package:minimarket_pos/presentation/cashier_screen.dart';
import 'package:minimarket_pos/presentation/history_screen.dart';
import 'package:minimarket_pos/presentation/login_screen.dart';
import 'package:minimarket_pos/presentation/owner/home_screen.dart';
import 'package:minimarket_pos/presentation/stock_list_screen.dart';
import 'package:minimarket_pos/presentation/warehouse/receive_screen.dart';

import 'fakes.dart';
import 'stock_rpc_test.dart' show pumpApp, row;

const _expected = {
  'kasir': ['Kasir', 'Riwayat saya', 'Stok'],
  'owner': ['Home', 'Riwayat', 'Stok', 'Staf'],
  'gudang': ['Terima', 'Opname', 'Pindah', 'Produk'],
};

final _profiles = FakeProfileRepository({
  'kasir': const Profile(id: 'kasir', fullName: 'Sari Kasir', role: AppRole.cashier, isActive: true),
  'owner': const Profile(id: 'owner', fullName: 'Umem', role: AppRole.owner, isActive: true),
  'gudang': const Profile(id: 'gudang', fullName: 'Budi Gudang', role: AppRole.warehouse, isActive: true),
});

void setWidth(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<FakeAuthRepository> pumpGate(WidgetTester tester, String? userId, {String? initialPath}) async {
  final auth = FakeAuthRepository(userId);
  await tester.pumpWidget(ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      profileRepositoryProvider.overrideWithValue(_profiles),
      stockRepositoryProvider.overrideWithValue(FakeStockRepository([row(1, 'A', 5)])),
      productRepositoryProvider.overrideWithValue(FakeProductRepository()),
      transactionRepositoryProvider.overrideWithValue(FakeTransactionRepository()),
      clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 13, 3)),
    ],
    child: MaterialApp(home: AuthGate(initialPath: initialPath)),
  ));
  await tester.pumpAndSettle();
  return auth;
}

/// Label item di navigasi bawah, berurutan.
List<String> bottomLabels(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(of: find.byKey(const Key('app-nav-bottom')), matching: find.byType(Text)))
    .map((t) => t.data!)
    .toList();

int cartSize(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CashierScreen))).read(checkoutControllerProvider).items.length;

void main() {
  group('tabsFor / resolveTab', () {
    test('label per peran persis tabel; tiap tab diizinkan untuk perannya', () {
      final roles = {'kasir': AppRole.cashier, 'owner': AppRole.owner, 'gudang': AppRole.warehouse};
      for (final e in roles.entries) {
        expect(tabsFor(e.value).map((t) => t.label), _expected[e.key], reason: e.key);
        expect(tabsFor(e.value).every((t) => can(e.value, t.permission)), isTrue);
      }
    });

    test('rute tak dikenal / milik peran lain -> layar pertama peran', () {
      expect(resolveTab(AppRole.cashier, '/staf'), AppTab.kasir);
      expect(resolveTab(AppRole.cashier, '/terima'), AppTab.kasir);
      expect(resolveTab(AppRole.cashier, null), AppTab.kasir);
      expect(resolveTab(AppRole.warehouse, '/kasir'), AppTab.terima);
      expect(resolveTab(AppRole.owner, '/ngawur'), AppTab.home);
      expect(resolveTab(AppRole.owner, '/staf'), AppTab.staf);
      expect(resolveTab(AppRole.cashier, '/riwayat'), AppTab.riwayatSaya);
    });
  });

  for (final userId in _expected.keys) {
    testWidgets('$userId: label tab persis tabel, tanpa tab peran lain, layar pertama benar', (tester) async {
      setWidth(tester, 700);
      await pumpGate(tester, userId);

      expect(bottomLabels(tester), _expected[userId]);
      final others = AppTab.values.where((t) => !_expected[userId]!.contains(t.label));
      for (final t in others) {
        expect(find.byKey(Key('nav-${t.name}')), findsNothing, reason: t.name);
      }

      switch (userId) {
        case 'kasir':
          expect(find.byType(CashierScreen), findsOneWidget);
        case 'owner':
          expect(find.byType(HomeScreen), findsOneWidget);
        case 'gudang':
          expect(find.byType(ReceiveScreen), findsOneWidget);
      }
    });
  }

  testWidgets('deep link ke tab peran lain -> layar pertama peran', (tester) async {
    setWidth(tester, 700);
    await pumpGate(tester, 'kasir', initialPath: '/staf');
    expect(find.byType(CashierScreen), findsOneWidget);
    expect(find.text('Staf'), findsNothing);
  });

  testWidgets('lebar 700 = tab bawah, 800 = rel samping dengan nama dan peran', (tester) async {
    setWidth(tester, 700);
    await pumpGate(tester, 'owner');
    expect(find.byKey(const Key('app-nav-bottom')), findsOneWidget);
    expect(find.byKey(const Key('app-nav-rail')), findsNothing);

    setWidth(tester, 800);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-nav-rail')), findsOneWidget);
    expect(find.byKey(const Key('app-nav-bottom')), findsNothing);
    final rail = find.byKey(const Key('app-nav-rail'));
    expect(find.descendant(of: rail, matching: find.text('Umem')), findsOneWidget);
    expect(find.descendant(of: rail, matching: find.text('Owner')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('nav-home'))).height, greaterThanOrEqualTo(48));
  });

  testWidgets('pindah tab lalu kembali: keranjang Kasir tetap; logout mereset', (tester) async {
    setWidth(tester, 800);
    final auth = await pumpGate(tester, 'kasir');

    await tester.tap(find.text('Barang A'));
    await tester.pump();
    expect(cartSize(tester), 1);

    await tester.tap(find.byKey(const Key('nav-stok')));
    await tester.pumpAndSettle();
    expect(find.byType(StockListScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-riwayatSaya')));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-kasir')));
    await tester.pumpAndSettle();
    expect(cartSize(tester), 1);

    // Ganti tata letak (rel -> tab bawah) juga tidak membuang keranjang.
    setWidth(tester, 700);
    await tester.pumpAndSettle();
    expect(cartSize(tester), 1);

    await auth.signOut();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(CashierScreen), findsNothing);

    await auth.signIn('kasir', 'rahasia123');
    await tester.pumpAndSettle();
    expect(cartSize(tester), 0);
  });

  testWidgets('Stok untuk kasir: tidak ada tombol Kasir yang menumpuk layar Kasir kedua', (tester) async {
    for (final role in AppRole.values) {
      await pumpApp(tester, const StockListScreen(), role: role, stock: FakeStockRepository([row(1, 'A', 5)]));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.point_of_sale), findsNothing, reason: role.name);
      expect(find.byTooltip('Menu Kasir'), findsNothing, reason: role.name);
    }
  });
}
