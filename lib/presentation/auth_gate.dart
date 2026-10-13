import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/permissions.dart';
import '../data/session.dart';
import 'cashier_screen.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'stock_list_screen.dart';
import 'widgets/error_view.dart';

/// Beranda per peran: owner -> Dashboard, kasir -> Kasir, gudang -> Stok.
Widget homeFor(AppRole role) {
  switch (role) {
    case AppRole.owner:
      return const DashboardScreen();
    case AppRole.cashier:
      return const CashierScreen();
    case AppRole.warehouse:
      return const StockListScreen();
  }
}

/// Gerbang sesi: tanpa sesi -> LoginScreen, ada sesi -> beranda sesuai peran.
class AuthGate extends ConsumerWidget {
  final GlobalKey<NavigatorState>? navigatorKey;

  const AuthGate({super.key, this.navigatorKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Saat keluar, tutup semua layar yang terbuka di atas gerbang.
    ref.listen(sessionControllerProvider, (previous, next) {
      if (next.value is SignedOut) navigatorKey?.currentState?.popUntil((route) => route.isFirst);
    });

    return ref.watch(sessionControllerProvider).when(
      skipLoadingOnRefresh: false,
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: ErrorView(error: error, onRetry: () => ref.invalidate(sessionControllerProvider)),
      ),
      data: (session) => switch (session) {
        SignedOut(:final message) => LoginScreen(message: message),
        SignedIn(:final profile) => homeFor(profile.role!),
      },
    );
  }
}
