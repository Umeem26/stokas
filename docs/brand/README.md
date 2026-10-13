Stokas adalah aplikasi kasir dan inventori untuk toko kecil, dipakai tiga peran: kasir (tablet atau PC), owner (HP), dan staf gudang. Nama berasal dari Stok + Kas. Garis merek: "Uang dan barang, satu catatan." (Inggris: "Money and stock, one ledger.")

## Nama dan penulisan

- Tulis `Stokas`, hanya huruf S yang kapital. Jangan `STOKAS` atau `StoKas`.
- Di dalam aplikasi cukup "Stokas". Di publikasi luar boleh "Stokas POS" supaya mudah dicari (usulan, bukan aturan merek).
- Jangan menjanjikan fitur yang belum dibangun di teks mana pun: antrean offline, tutup kas, rekomendasi restock, dan peringatan kedaluwarsa otomatis masih rencana.

## Nada dan bahasa

- Bahasa Indonesia, sapaan "Anda" (pesan dari server sudah memakainya). Kalimat pendek: sebut apa yang terjadi, lalu langkah berikutnya.
- Tanpa tanda seru, tanpa emoji, tanpa "Oops", tanpa humor di pesan yang menyangkut uang atau stok.
- Tombol memakai kata kerja dan, bila ada, jumlahnya: "Bayar Rp 742.000", "Simpan", "Tambah stok", "Batal", "Hapus barang". Teks hapus tidak menyebut "permanen" karena barang hanya disembunyikan.
- Angka: `Rp 742.000` (spasi setelah Rp, titik sebagai pemisah ribuan, tanpa desimal). Tanggal `13 Okt 2026`, jam `14.30 WIB` (24 jam, titik pemisah). Semua angka memakai angka rata (tabular).
- Pesan galat nyata dari sistem saat ini: "Stok tidak cukup: marlong (tersedia 3)", "Uang bayar kurang dari total", "Anda tidak punya akses untuk transaksi", "Hanya owner yang boleh mengubah harga atau menghapus barang". Di layar, ubah ke bentuk yang menyuruh bertindak: "Stok marlong tinggal 3. Kurangi jumlah atau pilih barang lain."

## Dasar visual

- Latar halaman `canvas`, kartu dan sheet `surface`, area cekung `surface-sunken`. Teks utama `ink`, teks sekunder `ink-muted`. Pemisah dekoratif `line`; batas kolom input dan kontrol memakai `line-strong`.
- Aksi utama (Bayar, Simpan) memakai `primary` dengan teks `on-primary`; keadaan tekan `primary-hover`. Satu aksi utama per layar.
- Dua warna dari logo punya arti tetap: `stock` (teal) untuk segala hal tentang barang dan stok, `cash` (emas) untuk segala hal tentang kas dan uang. `cash` hanya sebagai isian di atas `on-cash`; untuk garis atau grafis di latar terang pakai `cash-deep`.
- Status memakai `positive`, `warning`, `negative` dengan latar `-soft` masing-masing. Hijau dan merah nyaris sama terangnya (kontras antar keduanya sekitar 1:1), jadi warna tidak boleh jadi satu-satunya penanda: selalu sertakan tanda `+` atau `−`, ikon, atau kata ("Masuk", "Keluar", "Menipis", "Kedaluwarsa").
- Judul dan angka besar memakai `display-xl`, `display`, `headline`, `title-lg` (Manrope); teks isi memakai `title`, `body-lg`, `body`, `label`, `caption` (Inter). Layar tablet kasir memakai `body-lg`, HP dan tabel padat memakai `body`. Aktifkan angka rata: `font-variant-numeric: tabular-nums` di web, `FontFeature.tabularFigures()` di Flutter (kedua font memuat fitur `tnum`).
- Jarak berkelipatan 4 (`space-1` sampai `space-8`). Area sentuh minimal `tap-min` (48px). Sudut: `radius-sm` lencana, `radius-md` tombol dan input, `radius-lg` kartu dan sheet.
- Kartu dipisah dengan garis `line`, bukan bayangan. `shadow-float` hanya untuk yang melayang (dialog, sheet, menu).
- Fokus keyboard: cincin 2px solid `focus`, offset 2px.
- Dua tema tersedia, terang dan gelap, dengan token yang sama. Tema mana yang jadi bawaan di perangkat kasir adalah keputusan UX yang belum diambil.

## Logo dan ikon aplikasi

- Tanda berupa huruf S: ujung atas membawa koin (kas), ujung bawah membawa kotak (stok). Pakai file di grup `Logos` apa adanya; jangan menggambar ulang atau mengubah warna koin dan kotak.
- Latar terang: `stokas-logo.svg` atau `stokas-mark.svg`. Latar gelap: versi `-reverse`. Satu warna (struk thermal, cap, fotokopi): versi `-mono`.
- Ruang bebas minimal sebesar diameter koin (seperempat tinggi tanda) di semua sisi. Ukuran terkecil yang sudah diperiksa terbaca: tanda 16 px, lockup tinggi 32 px; di bawah itu belum diuji.
- Ikon peluncur ada di grup `AppIcons`: `icon-1024-full.png` (persegi penuh, tanpa transparansi), `icon-foreground-1024.png` (foreground adaptif Android; latar `primary` tema terang `#17305C`), `icon-1024-rounded.png` (web, README, halaman toko aplikasi).

## Ikonografi

Belum ada set ikon resmi. Usulan yang belum final: Material Symbols gaya outlined, 24px, untuk selaras dengan Flutter. Lencana status memakai ikon centang, segitiga seru, dan lingkaran silang yang digambar di komponen `StatusBadge`.
