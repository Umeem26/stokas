import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session.dart';
import 'app_shell.dart';
import 'login_screen.dart';
import 'widgets/error_view.dart';

/// Gerbang sesi: tanpa sesi -> LoginScreen, ada sesi -> AppShell sesuai peran.
/// [initialPath] = rute awal (deep link); tab tak sah diarahkan ke layar pertama peran.
class AuthGate extends ConsumerWidget {
  final GlobalKey<NavigatorState>? navigatorKey;
  final String? initialPath;

  const AuthGate({super.key, this.navigatorKey, this.initialPath});

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
        // Kunci per akun: logout / ganti akun membuang semua state tab.
        SignedIn(:final profile) => AppShell(key: ValueKey(profile.id), role: profile.role!, initialPath: initialPath),
      },
    );
  }
}
