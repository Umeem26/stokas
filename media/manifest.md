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

# 2. PC mode (Chrome 1440x900, dpr 2) lewat flutter drive + onScreenshot (integration_test/media/media_driver.dart).
#    Butuh chromedriver yang cocok dengan versi Chrome, mis.:
#    npx @puppeteer/browsers install chromedriver@<versi-chrome>  (di luar repo)
CHROMEDRIVER=/path/to/chromedriver python integration_test/media/capture.py web

# 3. Olah: struk PDF -> PNG (203 dpi), checkout.mp4 -> checkout.gif (palettegen, lebar 360, 12 fps, <= 4 MB),
#    contact-sheet.png, dan set pilihan ke docs/screenshots/ (256 warna, <= ~250 KB per gambar).
python integration_test/media/capture.py post
```

Cara kerja Android: tes mencetak `MEDIA|id|perintah|arg|file-ack`; `capture.py` menjalankan perintah di host
(`shot`, `night`, `net`, `rec-start`/`rec-stop`, `pull`, `note`) lalu membuat file-ack lewat `adb shell run-as`.
Mode gelap = `cmd uimode night yes`; offline = `svc wifi disable; svc data disable`.

Peringatan: menjalankan ulang tes `kasir — rekaman checkout, struk` membuat **satu transaksi baru** (stok berkurang).

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
| 21-owner-home.png | Home | omzet hari ini + "Perlu diurus" | owner |
| 22-owner-home-gelap.png | Home | tema gelap | owner |
| 23-owner-detail-barang.png | Detail barang | dari "Perlu diurus" (harga & modal) | owner |
| 24-owner-riwayat.png | Riwayat Transaksi | daftar | owner |
| 25-owner-riwayat-detail.png | Riwayat Transaksi | lembar detail struk | owner |
| 26-owner-staf.png | Kelola Staf | apa adanya, termasuk 2 akun nonaktif | owner |
| 27-owner-staf-tambah-terisi.png | Tambah Staf | terisi, TIDAK disimpan | owner |
| 28-owner-home-offline.png | Home | jaringan mati: "Koneksi terputus" + "Coba lagi" | owner |
| 29-owner-home-pulih.png | Home | jaringan menyala lagi, "Coba lagi" -> data pulih | owner |
| 30–33 (PC) | Kasir PC, Home PC, Kelola Staf PC | menyusul (capture PC belum selesai) | — |
| checkout.mp4 / checkout.gif | Kasir | rekaman cari -> tambah -> scan kode -> uang cepat -> struk (22,7 dtk, mulai setelah login) | kasir |
| contact-sheet.png | — | montase semua PNG berlabel nama file | — |

## Catatan dan yang dilewati

- Stok read-only: daftar Stok hanya punya lencana "Kedaluwarsa" dan "Habis"; label "Hampir kedaluwarsa" dan
  "Menipis" tidak ada di layar itu. Diganti: "Menipis" di kartu produk Kasir (11), "Hampir kedaluwarsa" di Home owner (21).
- QRIS tidak punya dialog konfirmasi terpisah; langkah konfirmasi = panel dengan tombol "Sudah dibayar" (08).
- "Dialog buat staf" di aplikasi berupa layar penuh "Tambah Staf" (27).
- Terima barang: tanggal kedaluwarsa tidak diisi (opsional; date picker dilewati).
- Offline: koneksi keep-alive lama tidak langsung putus di emulator, jadi tes menunggu 20 dtk sebelum tarik-untuk-muat-ulang.
- Mode gelap hanya untuk Login, Keranjang, Home owner (02, 06, 22).

## DATA DEMO DIUBAH

```
struk 000089; total Rp 15.700; tunai Rp 20.000; kembalian Rp 4.300
DEMO-01 Keripik Singkong Original 60 g x1
DEMO-05 Teh Botol Kemasan 350 ml x1
DEMO-18 Mie Goreng Instan 85 g x1
```

Hanya dari rekaman checkout. Form gudang dan staf tidak disimpan; tidak ada yang dihapus.
