import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/core/supabase_key_guard.dart';
import 'package:minimarket_pos/presentation/config_error_screen.dart';

/// JWT palsu (tanda tangan tidak valid) dengan klaim [role]; cukup untuk dekode payload.
String _fakeJwt(String role) {
  String part(Map<String, Object> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'iss': 'supabase', 'role': role})}.c2lnbmF0dXJl';
}

void main() {
  group('checkClientKey', () {
    // Nilai palsu dirakit saat tes agar tidak menyerupai kunci asli di repo.
    final cases = <(String, String?, String?)>[
      ('sb_secret_ ditolak', 'sb_secret_${'x' * 24}', secretKeyMessage),
      ('JWT service_role ditolak', _fakeJwt('service_role'), secretKeyMessage),
      ('JWT anon diterima', _fakeJwt('anon'), null),
      ('sb_publishable_ diterima', 'sb_publishable_${'x' * 24}', null),
      ('kosong ditolak', '', emptyKeyMessage),
      ('spasi saja ditolak', '   ', emptyKeyMessage),
      ('tidak ada (null) ditolak', null, emptyKeyMessage),
    ];

    for (final (name, key, message) in cases) {
      test(name, () {
        if (message == null) {
          expect(() => checkClientKey(key), returnsNormally);
        } else {
          expect(() => checkClientKey(key),
              throwsA(isA<ConfigException>().having((e) => e.message, 'message', message)));
        }
      });
    }

    test('pesan kunci rahasia sesuai permintaan', () {
      expect(secretKeyMessage,
          'Kunci Supabase salah: kunci rahasia tidak boleh dipakai di aplikasi. Pakai kunci publishable.');
    });
  });

  test('checkSupabaseConfig menolak URL kosong', () {
    expect(() => checkSupabaseConfig(url: '', key: _fakeJwt('anon')),
        throwsA(isA<ConfigException>().having((e) => e.message, 'message', emptyUrlMessage)));
  });

  testWidgets('layar galat konfigurasi tampil, bukan Login', (tester) async {
    await tester.pumpWidget(const ConfigErrorApp(message: secretKeyMessage));
    expect(find.text('Konfigurasi aplikasi salah'), findsOneWidget);
    expect(find.text(secretKeyMessage), findsOneWidget);
    expect(find.byIcon(Icons.vpn_key_off_outlined), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Masuk'), findsNothing);
  });
}
