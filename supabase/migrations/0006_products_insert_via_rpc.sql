-- 0006: produk baru hanya lewat RPC create_product_with_stock.
-- Alasan: INSERT langsung membiarkan gudang menetapkan harga bebas (penjaga harga hanya di UPDATE).
-- RPC bersifat SECURITY DEFINER sehingga tidak butuh hak INSERT pemanggil.
-- UPDATE sengaja DIPERTAHANKAN: nama/satuan/kategori/min stok/gambar sah diubah owner+gudang,
-- sedangkan price/is_deleted dijaga trigger products_guard_prices (hanya owner).

begin;

drop policy if exists products_insert on public.products;
revoke insert on public.products from authenticated, anon;

commit;
