import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart'; 

import 'core/supabase_key_guard.dart';
import 'presentation/auth_gate.dart';
import 'presentation/config_error_screen.dart';
import 'presentation/design/stokas_theme.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env", isOptional: true);

  // --- BARIS AJAIB PENYEMBUH ERROR ---
  // Kita "daftarkan" dulu format tanggal Indonesia agar aplikasi tidak kaget
  await initializeDateFormatting('id_ID', null);

  // Penjaga startup (debug & release): kunci kosong / rahasia -> layar galat konfigurasi, bukan Login.
  final url = dotenv.env['SUPABASE_URL'];
  final key = dotenv.env['SUPABASE_ANON_KEY'];
  try {
    checkSupabaseConfig(url: url, key: key);
  } on ConfigException catch (e) {
    debugPrint('❌ $e');
    runApp(ConfigErrorApp(message: e.message));
    return;
  }

  await Supabase.initialize(url: url!, anonKey: key!);

  runApp(
    ProviderScope(
      // Tanpa retry otomatis: error langsung tampil dengan tombol "Coba lagi"
      retry: (retryCount, error) => null,
      child: const MyApp(),
    ),
  );
}

final _navigatorKey = GlobalKey<NavigatorState>();

Route<void> _gateRoute(String? path) =>
    MaterialPageRoute(builder: (_) => AuthGate(navigatorKey: _navigatorKey, initialPath: path));

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stokas',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,

      // Tema Stokas (docs/brand/tokens.json), terang/gelap mengikuti sistem
      theme: StokasTheme.light,
      darkTheme: StokasTheme.dark,
      themeMode: ThemeMode.system,

      // Pintu masuk -> Login / beranda sesuai peran. Tanpa `home` (tidak boleh bersama
      // onGenerateInitialRoutes): rute awal (mis. /staf di web) diteruskan ke AuthGate,
      // bukan ditumpuk sebagai layar.
      onGenerateInitialRoutes: (path) => [_gateRoute(path)],
      onGenerateRoute: (settings) => _gateRoute(settings.name),
    );
  }
}