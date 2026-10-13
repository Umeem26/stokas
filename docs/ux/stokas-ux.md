# Stokas — spesifikasi UX (ringkas, untuk implementasi)

Sumber lengkap ada di Claude Docs milik Umem. Dokumen ini hanya yang dibutuhkan kode. Bahasa UI: Indonesia sehari-hari, singkat, kata kerja di tombol ("Bayar Rp 37.500", "Tambah stok"). Semua angka contoh di mockup bukan data toko.

## Prinsip
1. Satu aksi utama per layar (tombol primer navy), selalu terlihat tanpa menggulir.
2. Kasir tidak kehilangan keranjang: saat jaringan putus atau server menolak, keranjang tetap, pesan menyebut penyebab (pesan RPC ditampilkan apa adanya, contoh "Stok tidak cukup: Marlong 250 ml (tersedia 3)").
3. PC bisa dipakai tanpa mouse (scanner USB = keyboard).
4. Status selalu ikon + kata (hijau/merah hanya beda rona). Uang selalu "Rp 12.500", digit tabular, rata kanan di tabel, minus pakai tanda.
5. Tema ikut sistem (terang/gelap), bisa diganti manual. Tap target >= 48 px.

## Peran dan navigasi
| Peran | Tab | Layar pertama |
|---|---|---|
| cashier | Kasir, Riwayat saya, Stok (baca saja) | Kasir |
| owner | Home, Riwayat, Stok, Staf | Home |
| warehouse | Terima, Opname, Pindah, Produk | Terima |

Lebar >= 768 px: rel samping (ikon + label, logo mark di atas, nama dan peran di bawah). Di bawah 768 px: tab bawah. Peran tidak pernah melihat tab peran lain (tombol Kasir tidak lagi menumpuk di layar Stok).

## Kasir (tablet/PC)
Dua panel. Kiri: kolom cari (selalu fokus; scan = ketik kode + Enter; cocokkan `products.id` persis dulu, baru nama), chip kategori, kisi produk 3 kolom (kartu: nama, harga, lencana stok; habis = nonaktif). Kanan 408 px: keranjang (baris: nama + subtotal; harga satuan + stepper -/+ 48 px), total besar, tombol "Bayar Rp ...", "Kosongkan keranjang".
Panel bayar menggantikan keranjang (480 px); panel kiri berubah jadi ringkasan pesanan (baca saja). Isi: cara bayar Tunai (bawaan, tombol 1) / QRIS (2) / Transfer (3); "Uang diterima" besar; tombol uang cepat (Uang pas + pecahan kertas 2.000/5.000/10.000/20.000/50.000/100.000 terkecil yang menutup total, lalu dua di atasnya, maks 3 tombol; total > 100.000 dibulatkan ke atas ke kelipatan 50.000); kotak Kembalian; tombol Bayar nonaktif bila uang < total dengan alasan tertulis. QRIS/Transfer dibayar pas (server menolak lebih), tombol "Sudah dibayar".
Layar selesai: kembalian sangat besar (display), ringkasan (total, diterima, nomor struk, waktu WIB), "Unduh struk (PDF)" (tidak ada cetak; toko tidak punya printer), "Transaksi baru" (Enter).
PC: tabel keranjang (Kode, Nama, Harga, Jumlah, Subtotal), baris terpilih diberi cincin fokus, status "Scanner siap", bar pintasan bawah. Keyboard: `/` fokus cari; Enter tambah produk cocok / di kolom kosong dengan keranjang terisi buka bayar; `+` `-` jumlah; Del hapus baris; Esc tutup; 1/2/3 cara bayar di panel bayar; Enter di layar selesai = transaksi baru.
Kasus: stok kurang saat bayar -> panel tetap, pesan server, baris bermasalah ditandai, keranjang utuh. Jaringan putus -> "Tidak ada koneksi", keranjang utuh, ulang bayar aman (idempotency key). Batch kedaluwarsa tidak dijual. Riwayat: hanya transaksi sendiri (RLS).

## Owner (HP)
Home: kartu "Omzet hari ini" (total, jumlah transaksi, perbandingan dengan kemarin hanya bila ada datanya; hari WIB), daftar "Perlu diurus" maks 5 baris (urut: kedaluwarsa, di bawah min_stock, harga belum diatur; tiap baris nama, rincian, lencana). Tanpa transaksi terakhir, tanpa slot kas (Fase 4). Harga dan modal diubah dari detail barang. Modal hanya owner.

## Gudang
Terima barang: kolom scan/cari, kartu per baris (nama, kode, stepper jumlah, pilihan Lantai 1/2, tanggal kedaluwarsa OPSIONAL), validasi UI "Tanggal ini sudah lewat", "Tambah baris", tombol "Simpan N barang" nonaktif bila ada baris salah dengan alasan. Opname (stock_count), Pindah (transfer_stock), Produk baru (create_product_with_stock; harga 0 untuk gudang). Tulis rugi batch kedaluwarsa = stock_count ke 0 dengan catatan "Tulis rugi", lewat dialog konfirmasi yang menyebut nama, jumlah, tanggal. Gudang tidak melihat modal dan tidak punya tombol Kasir/Bayar.

## Pola bersama
Pesan galat: apa gagal + penyebab + langkah ("Tidak bisa menyimpan. Koneksi terputus. Coba lagi."). Aksi merusak: konfirmasi menyebut objek, tombol bahaya kiri, batal kanan. Kosong: sebut langkah berikutnya ("Belum ada stok. Terima barang dulu."). Memuat: skeleton, bukan spinner layar penuh. Fokus keyboard: cincin 2 px `focus`.
