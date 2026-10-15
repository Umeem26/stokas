import 'package:flutter/material.dart';

import 'design/stokas_theme.dart';
import 'design/stokas_tokens.dart';

/// Aplikasi pengganti saat konfigurasi Supabase ditolak penjaga startup: tanpa Login,
/// tanpa koneksi ke Supabase.
class ConfigErrorApp extends StatelessWidget {
  final String message;

  const ConfigErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stokas',
      debugShowCheckedModeBanner: false,
      theme: StokasTheme.light,
      darkTheme: StokasTheme.dark,
      themeMode: ThemeMode.system,
      home: ConfigErrorScreen(message: message),
    );
  }
}

class ConfigErrorScreen extends StatelessWidget {
  final String message;

  const ConfigErrorScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(StokasSpace.s5),
            child: Semantics(
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.vpn_key_off_outlined, size: StokasSpace.s8, color: c.negative),
                  const SizedBox(height: StokasSpace.s3),
                  Text('Konfigurasi aplikasi salah',
                      textAlign: TextAlign.center, style: StokasType.title.copyWith(color: c.ink)),
                  const SizedBox(height: StokasSpace.s2),
                  Text(message, textAlign: TextAlign.center, style: StokasType.body.copyWith(color: c.ink)),
                  const SizedBox(height: StokasSpace.s2),
                  Text('Perbaiki file .env, lalu buka ulang aplikasi.',
                      textAlign: TextAlign.center, style: StokasType.body.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
