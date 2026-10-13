-- Fase 1: kunci bucket product-images. Dijalankan manual lewat SQL Editor pada 13 Okt 2026.
drop policy if exists "product 16wiy3a_0" on storage.objects;
drop policy if exists "product 16wiy3a_1" on storage.objects;
drop policy if exists "product 16wiy3a_2" on storage.objects;
drop policy if exists "product 16wiy3a_3" on storage.objects;

create policy product_images_select on storage.objects for select to authenticated
  using (bucket_id = 'product-images' and private.is_role('owner','cashier','warehouse'));
create policy product_images_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'product-images' and private.is_role('owner','warehouse'));
create policy product_images_update on storage.objects for update to authenticated
  using (bucket_id = 'product-images' and private.is_role('owner','warehouse'))
  with check (bucket_id = 'product-images' and private.is_role('owner','warehouse'));
create policy product_images_delete on storage.objects for delete to authenticated
  using (bucket_id = 'product-images' and private.is_role('owner'));
