
# Logo

Tanda Stokas: huruf S dengan koin di ujung atas (kas) dan kotak di ujung bawah (stok). Tersedia sebagai tanda saja (`mark`) dan sebagai lockup tanda + nama (`logo`), masing-masing dalam versi terang, `-reverse` untuk latar gelap, dan `-mono` satu warna.

## Pakai
- Pakai file di grup Logos apa adanya. Jangan menggambar ulang, memutar, meregangkan, atau mengganti warna koin dan kotak.
- Latar terang: versi biasa. Latar gelap (navy, ink, foto gelap): `-reverse`. Satu tinta (struk thermal, cap, fotokopi): `-mono`.
- Ruang bebas minimal sebesar diameter koin di semua sisi.
- Ukuran terkecil yang sudah diperiksa: tanda 16 px, lockup tinggi 32 px.
- Nama selalu ditulis "Stokas" (S kapital, sisanya kecil), bukan STOKAS atau StoKas.

# Button

Tombol aksi dengan tiga varian: primer (navy, satu aksi utama per layar), sekunder (permukaan dengan garis, aksi pendukung seperti Batal), dan bahaya (garis dan teks merah, aksi yang menghapus seperti Hapus barang). Keadaan yang ditampilkan: normal, ditekan, fokus, dan nonaktif.

## Pakai
- Satu aksi primer per layar. Di layar kasir, itu tombol "Bayar" dengan nominal di labelnya (contoh: "Bayar Rp 742.000").
- Tinggi minimal `tap-min` (48 px). Di tablet kasir, tombol uang cepat memakai 56 px atau lebih.
- Label berupa kata kerja pendek: "Bayar", "Tambah stok", "Simpan". Hindari "OK" dan "Submit".
- Tombol bahaya selalu diikuti konfirmasi untuk aksi yang tidak bisa dibatalkan, dan tidak pernah menjadi satu-satunya tombol di layar.
- Keadaan nonaktif tetap terbaca dan disertai alasan di dekatnya bila tombolnya aksi penting.
- Cincin fokus `focus` 2 px tidak boleh dihilangkan; kasir PC bekerja dengan keyboard dan scanner.
- Warna emas (`cash`) dan teal (`stock`) saat ini dipakai untuk elemen informasi dan penanda, belum untuk varian tombol; apakah tombol "Bayar" memakai emas diputuskan di spesifikasi UX.

# StatusBadge

Lencana status kecil untuk stok. Tiga status yang ditampilkan: "Stok aman", "Menipis", dan "Kedaluwarsa".

## Pakai
- Selalu memuat ikon dan kata, tidak hanya warna. Hijau (`positive`) dan merah (`negative`) hanya dibedakan oleh rona dan sulit dibedakan bagi orang dengan buta warna merah-hijau; ikon dan kata yang membedakan.
- Satu lencana per baris. Bila ada beberapa kondisi, tampilkan yang paling parah.
- Kata berasal dari data: "Kedaluwarsa" hanya bila tanggal sudah lewat; detail seperti "Lantai 1 · 23 pcs" ditulis di baris item, bukan di dalam lencana.

# MoneyFigure

Penampil nominal rupiah. Selalu tampil sebagai "Rp" + angka dengan pemisah ribuan titik (contoh: Rp 12.500), tanpa desimal karena uang disimpan sebagai bilangan bulat.

## Pakai
- Angka memakai digit tabular supaya kolom sejajar; pakai rata kanan di tabel dan struk.
- Nominal negatif (selisih kas, retur) ditulis dengan tanda minus, jangan hanya warna merah.
- Total di layar kasir memakai ukuran display; ringkasan di HP owner memakai headline.
- Angka contoh diberi label "contoh" di dekatnya, seperti "KAS HARI INI (CONTOH)" pada pratinjau.

# Logos

Tanda dan lockup Stokas dalam tiga versi: terang, `-reverse` (latar gelap), dan `-mono`. File `-mono` memakai satu tinta (`currentColor` di file aslinya; pada pratinjau ini tampil hitam). Pakai di aplikasi dengan mewarnai sesuai konteks, misalnya ink `#0F1B2D` di terang dan `#E8EEF7` di gelap. Detail aturan pakai ada di README komponen Logo.

# AppIcons

Ikon peluncur aplikasi. `icon-1024-full.png`: persegi penuh tanpa transparansi (iOS, sumber untuk ikon Android lama). `icon-foreground-1024.png`: foreground adaptif Android dengan latar navy `#17305C`. `icon-1024-rounded.png`: sudut membulat untuk web, README, dan halaman toko aplikasi. `stokas-icon.svg` adalah sumber vektornya (tile navy, sudut 22 dari grid 96).
