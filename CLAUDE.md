# Minimarket POS

Aplikasi kasir & inventori minimarket. Flutter (Dart) + Supabase (Postgres + Storage `product-images`).
State management: flutter_riverpod. Kredensial dibaca dari `.env` (SUPABASE_URL, SUPABASE_ANON_KEY).

## Struktur lib/
- `main.dart` — init dotenv, Supabase, locale id_ID, `ProviderScope`, tema.
- `core/app_exception.dart` — `AppException` (pesan ramah) + `guard()` pembungkus error.
- `data/*_model.dart` — ProductModel, TransactionModel, CartItem.
- `data/cart_calculator.dart` — hitung total & kembalian.
- `data/repositories/` — antarmuka abstrak + implementasi Supabase (Product, Stock, Transaction).
  Semua panggilan Supabase hanya boleh di sini.
- `data/providers.dart` — provider repository & data layar (FutureProvider).
- `presentation/` — layar; `presentation/widgets/error_view.dart` untuk state gagal + "Coba lagi".
- `supabase/migrations/` — dokumentasi skema SQL (tidak dijalankan otomatis).

## Aturan tetap
- Commit langsung ke `main` dengan pesan jelas (conventional commits).
- Jangan pernah commit secret: `.env`, keystore/jks, key.properties.
- Jalankan `flutter analyze` dan `flutter test` sebelum commit; keduanya harus bersih/hijau.
- Jika `flutter build` mengubah `android/gradle.properties` (migrator), kembalikan dengan `git checkout`.
- Bahasa UI (Indonesia) tidak diubah tanpa diminta.
- Baca hanya file yang perlu.
- Laporan akhir maksimal 10 baris.
