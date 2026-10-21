# Media — manifest

Screenshot dan demo GIF untuk README, diambil dari data demo (produk `DEMO-01..29`, transaksi 7 hari).
File mentah ada di `media/raw/` (git-ignored); set pilihan yang dioptimalkan ada di `docs/screenshots/`.

## Cara mengulang

Prasyarat: Pixel_9 sudah cold boot (`adb devices` menampilkan `emulator-5554`), `integration_test/env.test.json`
berisi akun uji, `.env` berisi kunci publishable, `ffmpeg` di PATH, Python dengan `pymupdf` dan `pillow`
(`pip install pymupdf pillow`). Penggerak UI: `integration_test/media/media_capture_test.dart` (tidak ikut CI;
CI hanya `flutter test` atas `test/`). Tidak ada klik manual.

```sh
# 1. Android (Pixel_9, portrait, resolusi asli 1080x2424 lewat `adb exec-out screencap -p`).
#    Menyalakan demo mode status bar (jam 12:00, baterai 100 tidak mengisi, wifi penuh, tanpa notifikasi),
#    menjalankan tes, lalu mematikan demo mode, mode gelap, dan menyalakan lagi jaringan.
python integration_test/media/capture.py android
#    Sebagian tes saja (regex nama tes, diteruskan ke flutter test):
python integration_test/media/capture.py android --name "gudang|owner"
#    Perluasan saja (39-59, tanpa checkout; semua dialog ditutup dengan Batal):
python integration_test/media/capture.py android --name "ext"
#    Splash (screenrecord 4 dtk -> ffmpeg, frame terbersih dipilih otomatis), ikon di launcher & laci (33-38):
python integration_test/media/capture.py brand

# 2. PC mode (Chrome 1440x900, dpr 2): build release statis + Playwright (Chrome terpasang, headless).
#    Hanya membaca: login kasir -> scan 4 kode ke keranjang (tidak dibayar); login owner -> Home, Staf.
#    Butuh `pip install playwright` (memakai channel chrome, tanpa unduh browser).
flutter build web --release
python integration_test/media/web_static.py
#    Perluasan saja (60-64: Kasir & Home gelap lewat prefers-color-scheme, Riwayat, Stok, Terima gudang):
python integration_test/media/web_static.py ext
#    Alternatif lama (tidak dipakai, lihat catatan): flutter drive --release lewat chromedriver, batas 8 menit.
#    CHROMEDRIVER=/path/to/chromedriver python integration_test/media/capture.py web

# 3. Olah: struk PDF -> PNG (203 dpi), checkout.mp4 -> checkout.gif (<= 250 KB), contact-sheet-terang.png dan
#    contact-sheet-gelap.png, lalu set pilihan ke docs/screenshots/ (256 warna, <= 250 KB per gambar).
python integration_test/media/capture.py post
```

Cara kerja Android: tes mencetak `MEDIA|id|perintah|arg|file-ack`; `capture.py` menjalankan perintah di host
(`shot`, `night`, `net`, `rec-start`/`rec-stop`, `pull`, `note`) lalu membuat file-ack lewat `adb shell run-as`.
Mode gelap = `cmd uimode night yes`; offline = `svc wifi disable; svc data disable`.

Peringatan: menjalankan ulang tes `kasir — rekaman checkout, struk` membuat **satu transaksi baru** (stok berkurang).

## Inventaris layar

Dari `lib/presentation/app_shell.dart` (`_tabsByRole`) dan rute/dialog di `lib/presentation/`. Tab per peran:
owner = Home, Riwayat, Stok, Staf; kasir = Kasir, Riwayat saya, Stok (lihat saja); gudang = Terima, Opname, Pindah,
Produk. Mode PC = lebar >= 768 px: rel samping untuk semua peran; Kasir punya tata letak PC sendiri (`pc_widgets.dart`).
Kolom "Difoto" merujuk ke file di `media/raw/`; `—` = dilewati (alasan di bawah tabel).

| Layar | Peran | Keadaan | Difoto |
|---|---|---|---|
| Splash native | semua | terang / gelap | 33 / 34 |
| Layar utama launcher (ikon) | — | terang / gelap | 35 / 36 |
| Laci aplikasi (ikon) | — | terang / gelap | 37 / 38 |
| Login | umum | kosong / gelap / error | 01 / 02 / 03 |
| Galat konfigurasi (kunci salah) | umum | error | — |
| Menu akun + dialog "Keluar?" | semua | dialog | 39 |
| Kasir (cari + kartu barang) | kasir | keranjang kosong / "Menipis" / tidak ada hasil | 04 / 11 / 40 |
| Keranjang | kasir | 3 item / gelap / dialog "Kosongkan keranjang?" | 05 / 06 / 41 |
| Pembayaran | kasir | tunai / QRIS / tunai gelap | 07 / 08 / 42 |
| Transaksi berhasil + struk | kasir | sukses / struk PDF 80 mm | 12 / 13 |
| Riwayat saya | kasir | daftar / lembar detail struk / detail gelap | 14 / 43 / 44 |
| Stok (lihat saja) | kasir | daftar "Kedaluwarsa" / "Habis" | 09 / 10 |
| Terima barang | gudang | kosong / kode tak dikenal / terisi / terisi gelap | 45 / 46 / 16 / 48 |
| Pilih barang (lembar bawah) | gudang | daftar | 47 |
| Produk baru | gudang | terisi | 17 |
| Produk (daftar stok gudang) | gudang | daftar / gelap | 15 / 49 |
| Edit barang (tanpa harga) | gudang | terisi | 50 |
| Dialog Stok Masuk | gudang, owner | kosong | 51 |
| Pindah Lantai (dari daftar) | gudang, owner | form | 52 |
| Opname | gudang | selisih / dialog "Tulis rugi?" | 18 / 19 |
| Pindah stok | gudang | terisi | 20 |
| Home | owner | isi / gelap / offline / pulih | 21 / 22 / 28 / 29 |
| Detail barang | owner | isi / gelap / dialog "Hapus barang?" | 23 / 53 / 54 |
| Riwayat Transaksi | owner | daftar / lembar detail | 24 / 25 |
| Stok (dengan harga) | owner | daftar | 55 |
| Tambah barang (harga & modal) | owner | kosong | 56 |
| Kelola Staf | owner | daftar / gelap | 26 / 57 |
| Tambah Staf | owner | terisi | 27 |
| Dialog reset password / nonaktifkan staf | owner | dialog | 58 / 59 |
| Kasir PC | kasir | keranjang 3 item / gelap | 30 / 60 |
| Home PC | owner | isi / gelap | 31 / 61 |
| Kelola Staf PC | owner | daftar | 32 |
| Riwayat PC / Stok PC | owner | daftar | 62 / 63 |
| Terima PC | gudang | kosong | 64 |
| Daftar kosong (Riwayat, Stok, Staf, Home "Perlu diurus") | semua | kosong | — |

Dilewati: galat konfigurasi hanya muncul bila `.env` memuat kunci non-publishable (perlu mengganti kunci);
daftar kosong butuh database tanpa data (data demo selalu terisi); "Transaksi berhasil" gelap butuh checkout
(dilarang) — padanannya lembar detail struk gelap (44).

## Berkas

Akun: `umum` = tanpa login; `kasir` = CASHIER_EMAIL (Kasir1); `gudang` = WAREHOUSE_EMAIL (Gudang1);
`owner` = OWNER_EMAIL (Umem). Login gagal memakai akun fiktif `kasir.contoh`; email/password asli tidak tampil.

| File | Layar | Keadaan | Akun |
|---|---|---|---|
| 01-umum-login-kosong.png | Login | kosong | — |
| 02-umum-login-kosong-gelap.png | Login | kosong, tema gelap | — |
| 03-umum-login-error.png | Login | error: username fiktif + password salah | — |
| 04-kasir-kasir-keranjang-kosong.png | Kasir | keranjang kosong | kasir |
| 05-kasir-keranjang-3-item.png | Keranjang | 3 item (Rp 18.900) | kasir |
| 06-kasir-keranjang-3-item-gelap.png | Keranjang | 3 item, tema gelap | kasir |
| 07-kasir-bayar-tunai-uang-cepat.png | Pembayaran | tunai, tombol uang cepat Rp 20.000 | kasir |
| 08-kasir-bayar-qris-konfirmasi.png | Pembayaran | QRIS, langkah "Sudah dibayar" (tidak dibayar) | kasir |
| 09-kasir-stok-daftar.png | Stok (read-only) | daftar, lencana "Kedaluwarsa" | kasir |
| 10-kasir-stok-habis.png | Stok (read-only) | lencana "Habis" | kasir |
| 11-kasir-kasir-stok-menipis.png | Kasir | cari "mi": label "Menipis" (stok rendah) | kasir |
| 12-kasir-sukses-struk.png | Transaksi berhasil | kembalian + ringkasan struk | kasir |
| 13-kasir-struk-pdf-80mm.png | Struk PDF | dirender dari PDF 80 mm (203 dpi) | kasir |
| 14-kasir-riwayat.png | Riwayat saya | daftar struk | kasir |
| 15-gudang-stok-daftar.png | Produk (daftar stok gudang) | tanpa harga | gudang |
| 16-gudang-terima-terisi.png | Terima barang | 2 baris terisi, TIDAK disimpan | gudang |
| 17-gudang-produk-baru-terisi.png | Produk baru | terisi, TIDAK disimpan | gudang |
| 18-gudang-opname-selisih.png | Opname | hitung nyata 22 dari 24 (selisih), TIDAK disimpan | gudang |
| 19-gudang-tulis-rugi-konfirmasi.png | Opname | dialog "Tulis rugi?", ditutup dengan Batal | gudang |
| 20-gudang-pindah-lantai-terisi.png | Pindah stok | Lantai 2 -> Lantai 1, 6 pcs, TIDAK disimpan | gudang |
| 21-owner-home.png | Home | omzet hari ini Rp 435.500 (9 transaksi) + "Perlu diurus" | owner |
| 22-owner-home-gelap.png | Home | tema gelap | owner |
| 23-owner-detail-barang.png | Detail barang | dari "Perlu diurus" (harga & modal) | owner |
| 24-owner-riwayat.png | Riwayat Transaksi | daftar | owner |
| 25-owner-riwayat-detail.png | Riwayat Transaksi | lembar detail struk | owner |
| 26-owner-staf.png | Kelola Staf | apa adanya, termasuk 2 akun nonaktif | owner |
| 27-owner-staf-tambah-terisi.png | Tambah Staf | terisi, TIDAK disimpan | owner |
| 28-owner-home-offline.png | Home | jaringan mati: "Koneksi terputus" + "Coba lagi" | owner |
| 29-owner-home-pulih.png | Home | jaringan menyala lagi, "Coba lagi" -> data pulih | owner |
| 30-pc-kasir-keranjang.png | Kasir PC | tabel keranjang 3 item (Rp 18.900) + panel bayar + "Siap scan" + bilah pintasan, tidak dibayar | kasir |
| 31-pc-owner-home.png | Home PC | rel samping; omzet hari ini Rp 435.500 (9 transaksi) + "Perlu diurus" | owner |
| 32-pc-owner-staf.png | Kelola Staf PC | rel samping, apa adanya | owner |
| checkout.mp4 / checkout.gif | Kasir | rekaman cari -> tambah -> scan kode -> uang cepat -> struk (22,7 dtk, mulai setelah login) | kasir |
| 33-umum-splash.png / 34-umum-splash-gelap.png | Splash native | frame splash dari screenrecord (latar #F6F8FB / #0B1524) | — |
| 35-umum-launcher-ikon[-gelap].png | Layar utama launcher | ikon Stokas di dock, terang / gelap | — |
| 37-umum-laci-aplikasi-ikon[-gelap].png | Laci aplikasi | ikon "Stokas" di daftar aplikasi | — |
| 39-kasir-akun-keluar-dialog.png | Menu akun | dialog "Keluar?", ditutup Batal | kasir |
| 40-kasir-kasir-cari-kosong.png | Kasir | cari "zzz": "Tidak ada barang yang cocok" | kasir |
| 41-kasir-keranjang-kosongkan-dialog.png | Keranjang | dialog "Kosongkan keranjang?", Batal | kasir |
| 42-kasir-bayar-tunai-gelap.png | Pembayaran | tunai, tema gelap, tidak dibayar | kasir |
| 43-kasir-riwayat-detail.png / 44-...-gelap.png | Riwayat saya | lembar detail struk, terang / gelap | kasir |
| 45-gudang-terima-kosong.png | Terima barang | kosong | gudang |
| 46-gudang-terima-kode-baru.png | Terima barang | kode tak dikenal: "Buat produk baru dengan kode ini" | gudang |
| 47-gudang-terima-pilih-barang.png | Pilih barang | lembar bawah daftar produk | gudang |
| 48-gudang-terima-terisi-gelap.png | Terima barang | 2 baris terisi, tema gelap, TIDAK disimpan | gudang |
| 49-gudang-stok-daftar-gelap.png | Produk | tema gelap | gudang |
| 50-gudang-edit-barang.png | Edit barang | tanpa harga, TIDAK disimpan | gudang |
| 51-gudang-stok-masuk-dialog.png | Dialog Stok Masuk | kosong, ditutup Batal | gudang |
| 52-gudang-pindah-lantai-form.png | Pindah Lokasi Stok | form; memperlihatkan bug overflow (lihat catatan) | gudang |
| 53-owner-detail-barang-gelap.png | Detail barang | tema gelap | owner |
| 54-owner-detail-hapus-dialog.png | Detail barang | dialog "Hapus ...?", Batal | owner |
| 55-owner-stok-daftar.png | Stok | dengan harga | owner |
| 56-owner-tambah-barang-kosong.png | Input Barang Baru | kosong | owner |
| 57-owner-staf-gelap.png | Kelola Staf | tema gelap | owner |
| 58-owner-staf-reset-dialog.png | Kelola Staf | dialog reset password, Batal | owner |
| 59-owner-staf-nonaktifkan-dialog.png | Kelola Staf | dialog "Nonaktifkan ...?", Batal | owner |
| 60-pc-kasir-keranjang-gelap.png | Kasir PC | keranjang 3 item, tema gelap, tidak dibayar | kasir |
| 61-pc-owner-home-gelap.png | Home PC | omzet hari ini Rp 435.500, tema gelap | owner |
| 62-pc-owner-riwayat.png / 63-pc-owner-stok.png | Riwayat PC / Stok PC | daftar | owner |
| 64-pc-gudang-terima.png | Terima PC | kosong | gudang |
| contact-sheet-terang.png / contact-sheet-gelap.png | — | montase berlabel nama file, terang / gelap | — |

## Catatan dan yang dilewati

- Stok read-only: daftar Stok hanya punya lencana "Kedaluwarsa" dan "Habis"; label "Hampir kedaluwarsa" dan
  "Menipis" tidak ada di layar itu. Diganti: "Menipis" di kartu produk Kasir (11), "Hampir kedaluwarsa" di Home owner (21).
- QRIS tidak punya dialog konfirmasi terpisah; langkah konfirmasi = panel dengan tombol "Sudah dibayar" (08).
- "Dialog buat staf" di aplikasi berupa layar penuh "Tambah Staf" (27).
- Terima barang: tanggal kedaluwarsa tidak diisi (opsional; date picker dilewati).
- Offline: koneksi keep-alive lama tidak langsung putus di emulator, jadi tes menunggu 20 dtk sebelum tarik-untuk-muat-ulang.
- Mode gelap (perluasan 21 Okt 2026): Login, Home owner, Detail barang, Staf, Keranjang, Bayar, struk (lembar detail
  Riwayat, 44, karena layar "Transaksi berhasil" butuh checkout), Terima, Produk; PC: Kasir, Home.
- 22 (Home gelap) dan 29 diambil pada hari lain: omzet Rp 95.950, tidak sama dengan 21. Galeri memakai 61 untuk Home gelap.
- BUG ditemukan (tidak diperbaiki; logika aplikasi tidak diubah): di "Pindah Lokasi Stok" nama barang panjang
  meluap 28 px ke kanan (garis kuning-hitam debug di 52). 52 tidak dipakai di galeri.
- Data hari ini untuk 33-64: transaksi demo id 90-98 (Rp 435.500, aslinya 19 Okt) digeser sementara ke tanggal
  tangkap lewat SQL (`created_at`), lalu dikembalikan ke 19 Okt. Tanpa checkout; stok tidak berubah.
- PC memakai build statis + Playwright karena paling stabil: `flutter drive -d chrome` (debug) macet di
  "Waiting for connection from debug service on Chrome" (DWDS tidak pernah tersambung); `--release` lolos tahap itu
  tetapi mengompilasi ulang dart2js tiap jalan (~290 dtk) dan tidak selesai dalam batas 8 menit. Build statis
  cukup sekali, lalu capture 3 layar < 1 menit. Field/tombol dipilih lewat semantics Flutter (label), bukan koordinat.
- PC hanya 3 layar (Kasir, Home owner, Staf); panel bayar terbuka (31 lama) dihapus karena kolom bayar sudah tampil di 30.
- 21 dan 31 diambil ulang 19 Okt 2026 setelah data hari ini ditambahkan (sebelumnya omzet Rp 0); hanya kedua file itu
  yang diganti (tes owner dan `web_static.py` juga memotret 22-27, 30, 32, tetapi file lama itu dipulihkan). Tanpa checkout.

## DATA DEMO DIUBAH

```
struk 000089; total Rp 15.700; tunai Rp 20.000; kembalian Rp 4.300
DEMO-01 Keripik Singkong Original 60 g x1
DEMO-05 Teh Botol Kemasan 350 ml x1
DEMO-18 Mie Goreng Instan 85 g x1
```

Hanya dari rekaman checkout. Form gudang dan staf tidak disimpan; tidak ada yang dihapus.
