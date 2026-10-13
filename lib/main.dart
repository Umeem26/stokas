import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart'; 

import 'presentation/auth_gate.dart';
import 'presentation/design/stokas_theme.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // --- BARIS AJAIB PENYEMBUH ERROR ---
  // Kita "daftarkan" dulu format tanggal Indonesia agar aplikasi tidak kaget
  await initializeDateFormatting('id_ID', null);

  runApp(
    ProviderScope(
      // Tanpa retry otomatis: error langsung tampil dengan tombol "Coba lagi"
      retry: (retryCount, error) => null,
      child: const MyApp(),
    ),
  );
}

final _navigatorKey = GlobalKey<NavigatorState>();

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

      // Pintu Masuk -> Login / beranda sesuai peran
      home: AuthGate(navigatorKey: _navigatorKey),
    );
  }
}