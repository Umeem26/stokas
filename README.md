<div align="center">
  <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white" />
  <img src="https://img.shields.io/badge/Status-Active%20Development-orange?style=for-the-badge" />
  
  <br />
  <h1>🛒 Minimarket POS & Inventory System</h1>
  <p><i>"Enterprise-grade Point of Sale solution with real-time inventory precision."</i></p>
</div>

---

### 📋 Overview
Aplikasi ini adalah sistem **Point of Sale (POS)** dan **Manajemen Inventaris** tingkat profesional yang dibangun menggunakan Flutter dan Supabase. Dirancang khusus untuk menangani kompleksitas operasional minimarket modern, mulai dari pelacakan stok di berbagai lantai hingga pemantauan ketat terhadap masa kedaluwarsa produk.

### ✨ Fitur Unggulan
- **Real-time Stock Tracking:** Pemantauan stok barang secara instan yang tersinkronisasi di seluruh lantai operasional.
- **Expiry Monitoring:** Sistem peringatan dini untuk produk dengan masa simpan terbatas, khususnya kategori *frozen food*.
- **Integrated POS:** Proses transaksi penjualan yang cepat dan terhubung langsung dengan pembaruan stok otomatis.
- **Supabase Backend:** Memanfaatkan database real-time dan sistem autentikasi yang aman dari Supabase.
- **Image Integration:** Dilengkapi fitur pengambil gambar untuk pendataan produk yang lebih visual.

### 🛠️ Tech Stack
- **Frontend:** [Flutter](https://flutter.dev/) (Android & iOS)
- **Backend/Database:** [Supabase](https://supabase.com/)
- **Language:** [Dart](https://dart.dev/)
- **Features:** Image Picker & Android Manifest optimized for release.

### 🗄️ Folder `supabase/`
- `migrations/0001_baseline.sql` — skema awal (`categories`, `products`, `stocks`, `transactions`, `transaction_items`) sesuai kondisi 13 Oktober 2026, tanpa RLS.
- `migrations/0002_auth_roles_rls.sql` — tabel `profiles`, peran (`owner`/`cashier`/`warehouse`), kolom `transactions.cashier_id`, dan RLS di semua tabel.
- `migrations/0003_storage_policies.sql` — kebijakan akses bucket `product-images`.
- `functions/staff-admin` — Edge Function untuk owner: tambah staf, reset password, aktif/nonaktifkan akun.

File-file ini adalah dokumentasi dari yang sudah diterapkan ke proyek Supabase; tidak dijalankan otomatis oleh aplikasi maupun CI.

### 🔐 Peran & Login
Semua pengguna wajib login. Staf login dengan **username** (dipetakan ke email `username@staff.pos.invalid`); owner boleh login dengan email biasa. Sesi tersimpan di perangkat sehingga tidak perlu login ulang setiap membuka aplikasi. Akun yang dinonaktifkan otomatis dikeluarkan.

| Peran | Beranda | Akses |
|---|---|---|
| Owner | Dashboard | Semua layar, ubah harga, lihat harga modal, kelola staf |
| Kasir | Kasir | Kasir, riwayat transaksi sendiri, lihat stok |
| Gudang | Stok | Tambah/edit/mutasi stok; tidak bisa mengubah harga dan tidak melihat harga modal |

Akun staf dibuat owner dari menu **Staf** di Dashboard. Hak akses di aplikasi hanya menyembunyikan menu; penjagaan sebenarnya ada di RLS database.

### ⚙️ Instalasi & Persiapan
1. Clone repositori:
   ```bash
   git clone [https://github.com/Umeem26/Minimarket-Pos-System.git](https://github.com/Umeem26/Minimarket-Pos-System.git)
2. Konfigurasi proyek Supabase Anda dan masukkan API Key ke dalam proyek.
3. Jalankan perintah:
   ```bash
   flutter pub get
   flutter run
