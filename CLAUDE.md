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

## Fase 2 (skema 0004)
- Uang = `int` Rupiah; format hanya lewat `core/format.dart` (`formatRupiah`). Qty tetap `num`.
- Tulis stok/transaksi HANYA via RPC: `checkout`, `restock`, `stock_count`, `transfer_stock`. Tabel stocks/transactions/transaction_items hanya SELECT.
- `data/checkout_controller.dart`: keranjang + kunci idempotensi (sama saat retry, baru saat keranjang berubah/sukses).
- Stok tersedia = batch belum kedaluwarsa (`data/stock_availability.dart`, tanggal Asia/Jakarta di `core/jakarta_time.dart`).
- Harga modal di `product_costs` (owner saja). Hapus barang = `is_deleted=true`.
- Tes memakai repository palsu di `test/fakes.dart`.

## Peran (lib/core/permissions.dart, `can(role, Permission)`)
- owner: semua + Staf. kasir: Kasir, Riwayat, lihat Stok.
- gudang: Stok tambah/edit/mutasi, tanpa ubah harga & tanpa harga modal.
- Navigasi: `presentation/app_shell.dart` (`tabsFor(role)`, tab pertama = layar pertama); rel samping >= 768 px, tab bawah di bawahnya. Home owner + Detail barang di `presentation/owner/`.
- Login via `AuthGate` + `SessionController` (lib/data/session.dart); akun staf via Edge Function `staff-admin`.

## Aturan tetap
- Commit langsung ke `main` dengan pesan jelas (conventional commits).
- Jangan pernah commit secret: `.env`, keystore/jks, key.properties.
- Jalankan `flutter analyze` dan `flutter test` sebelum commit; keduanya harus bersih/hijau.
- Jika `flutter build` mengubah `android/gradle.properties` (migrator), kembalikan dengan `git checkout`.
- Bahasa UI (Indonesia) tidak diubah tanpa diminta.
- UI pakai token `StokasColors` lewat `context.stokas` (`presentation/design/`); tanpa hex atau ukuran font hardcode di widget.
- Teks UI Indonesia singkat; label tombol berupa kata kerja ("Simpan", "Tambah stok", "Bayar Rp 37.500").
- Status selalu ikon + kata (`StatusBadge`), bukan warna saja; uang lewat `MoneyText`/`formatRupiah`.
- Baca hanya file yang perlu.
- Laporan akhir maksimal 10 baris.
