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
- `supabase/` — migrasi SQL + Edge Function (dokumentasi; jangan dijalankan/deploy dari sini).

## Peran (lib/core/permissions.dart, `can(role, Permission)`)
- owner: semua + Staf. kasir: Kasir, Riwayat, lihat Stok (beranda Kasir).
- gudang: Stok tambah/edit/mutasi, tanpa ubah harga & tanpa harga modal (beranda Stok).
- Login via `AuthGate` + `SessionController` (lib/data/session.dart); akun staf via Edge Function `staff-admin`.

## Aturan tetap
- Commit langsung ke `main` dengan pesan jelas (conventional commits).
- Jangan pernah commit secret: `.env`, keystore/jks, key.properties.
- Jalankan `flutter analyze` dan `flutter test` sebelum commit; keduanya harus bersih/hijau.
- Jika `flutter build` mengubah `android/gradle.properties` (migrator), kembalikan dengan `git checkout`.
- Bahasa UI (Indonesia) tidak diubah tanpa diminta.
- Baca hanya file yang perlu.
- Laporan akhir maksimal 10 baris.
