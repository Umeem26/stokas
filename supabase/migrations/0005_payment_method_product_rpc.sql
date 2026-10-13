-- 0005 bagian 1: batasi nilai cara bayar + cabut hak berlebih bawaan Supabase
-- Aman dijalankan ulang? Tidak: constraint hanya boleh ditambah sekali.

alter table public.transactions
  add constraint transactions_payment_method_chk
  check (payment_method in ('cash', 'qris', 'transfer'));

-- Hak TRUNCATE/REFERENCES/TRIGGER tidak diperlukan aplikasi (PostgREST tidak memakainya)
-- dan TRUNCATE melewati RLS. Dicabut sebagai pertahanan berlapis.
revoke truncate, references, trigger on all tables in schema public from authenticated, anon;
alter default privileges in schema public revoke truncate, references, trigger on tables from authenticated, anon;
-- 0005 bagian 2: struk memuat cara bayar; checkout menerima cara bayar
-- Panggilan lama dengan 3 argumen tetap jalan (p_method bawaan 'cash').

create or replace function private.tx_json(p_id integer)
returns jsonb language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
    'id', t.id, 'total', t.total_amount, 'paid', t.paid_amount,
    'change', t.change_amount, 'created_at', t.created_at,
    'payment_method', t.payment_method,
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'product_id', i.product_id, 'name', i.product_name, 'qty', i.quantity,
        'price', i.price_at_purchase, 'subtotal', i.subtotal) order by i.id)
      from public.transaction_items i where i.transaction_id = t.id), '[]'::jsonb))
  from public.transactions t where t.id = p_id
$$;

drop function if exists public.checkout(uuid, jsonb, bigint);

create function public.checkout(p_key uuid, p_items jsonb, p_paid bigint, p_method text default 'cash')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_today date := (now() at time zone 'Asia/Jakarta')::date;
  v_tx public.transactions%rowtype;
  v_total bigint := 0;
  r record; s record; st record;
  v_need numeric; v_take numeric;
begin
  if not private.is_role('owner','cashier') then
    raise exception 'Anda tidak punya akses untuk transaksi' using errcode = '42501';
  end if;
  if p_key is null then raise exception 'Kunci transaksi wajib diisi'; end if;
  if p_method is null or p_method not in ('cash', 'qris', 'transfer') then
    raise exception 'Cara bayar tidak valid';
  end if;

  select * into v_tx from public.transactions where idempotency_key = p_key and cashier_id = v_uid;
  if found then return private.tx_json(v_tx.id); end if;

  if jsonb_typeof(p_items) is distinct from 'array'
     or jsonb_array_length(p_items) not between 1 and 200 then
    raise exception 'Keranjang kosong atau tidak valid';
  end if;
  if exists (select 1 from jsonb_array_elements(p_items) e
             where nullif(e->>'product_id', '') is null
                or coalesce((e->>'qty')::numeric, 0) <= 0
                or (e->>'qty')::numeric > 99999) then
    raise exception 'Data keranjang tidak valid';
  end if;

  for r in select e->>'product_id' as pid, sum((e->>'qty')::numeric) as qty
           from jsonb_array_elements(p_items) e group by 1 order by 1 loop
    select id, brand_name, price, is_deleted into s from public.products where id = r.pid;
    if not found or s.is_deleted then raise exception 'Barang tidak ditemukan: %', r.pid; end if;
    v_total := v_total + round(s.price * r.qty)::bigint;
  end loop;
  if p_paid is null or p_paid < v_total then
    raise exception 'Uang bayar kurang dari total';
  end if;
  if p_method <> 'cash' and p_paid <> v_total then
    raise exception 'QRIS dan transfer harus dibayar pas';
  end if;

  begin
    insert into public.transactions (total_amount, paid_amount, change_amount, cashier_id, idempotency_key, payment_method)
    values (v_total, p_paid, p_paid - v_total, v_uid, p_key, p_method) returning * into v_tx;
  exception when unique_violation then
    select * into v_tx from public.transactions where idempotency_key = p_key;
    if v_tx.id is null or v_tx.cashier_id is distinct from v_uid then
      raise exception 'Kunci transaksi bentrok';
    end if;
    return private.tx_json(v_tx.id);
  end;

  for r in select e->>'product_id' as pid, sum((e->>'qty')::numeric) as qty
           from jsonb_array_elements(p_items) e group by 1 order by 1 loop
    select brand_name, price into s from public.products where id = r.pid;
    v_need := r.qty;
    for st in select id, floor_name, expiry_date, quantity from public.stocks
              where product_id = r.pid and quantity > 0
                and (expiry_date is null or expiry_date >= v_today)
              order by expiry_date nulls last, id for update loop
      exit when v_need <= 0;
      v_take := least(v_need, st.quantity);
      update public.stocks set quantity = quantity - v_take where id = st.id;
      insert into public.stock_movements (product_id, floor_name, expiry_date, delta, kind, ref_transaction_id, created_by)
      values (r.pid, st.floor_name, st.expiry_date, -v_take, 'sale', v_tx.id, v_uid);
      v_need := v_need - v_take;
    end loop;
    if v_need > 0 then
      raise exception 'Stok tidak cukup: % (tersedia %)', s.brand_name, r.qty - v_need
        using errcode = 'P0001', hint = r.pid;
    end if;
    insert into public.transaction_items (transaction_id, product_id, product_name, quantity, price_at_purchase, subtotal)
    values (v_tx.id, r.pid, s.brand_name, r.qty, s.price, round(s.price * r.qty)::bigint);
  end loop;

  return private.tx_json(v_tx.id);
end $$;

revoke all on function public.checkout(uuid, jsonb, bigint, text) from public, anon;
grant execute on function public.checkout(uuid, jsonb, bigint, text) to authenticated;
-- 0005 bagian 3: produk baru + stok awal dalam satu langkah atomik
-- Harga hanya boleh ditetapkan owner; gudang membuat produk berharga 0.

create function public.create_product_with_stock(
  p_id text, p_name text, p_unit text,
  p_category integer default null, p_min_stock numeric default 5,
  p_price bigint default 0, p_image_url text default null,
  p_floor text default null, p_qty numeric default null, p_expiry date default null,
  p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_role('owner','warehouse') then
    raise exception 'Anda tidak punya akses untuk menambah barang' using errcode = '42501';
  end if;
  if nullif(trim(p_id), '') is null or length(trim(p_id)) > 64 then
    raise exception 'Kode barang wajib diisi (maksimal 64 karakter)';
  end if;
  if nullif(trim(p_name), '') is null then raise exception 'Nama barang wajib diisi'; end if;
  if nullif(trim(p_unit), '') is null then raise exception 'Satuan wajib diisi'; end if;
  if coalesce(p_min_stock, 0) < 0 then raise exception 'Stok minimum tidak boleh negatif'; end if;
  if coalesce(p_price, 0) < 0 then raise exception 'Harga tidak boleh negatif'; end if;
  if coalesce(p_price, 0) > 0 and not private.is_role('owner') then
    raise exception 'Hanya owner yang boleh menetapkan harga';
  end if;
  if p_qty is not null and p_qty > 0 and nullif(trim(p_floor), '') is null then
    raise exception 'Lantai wajib diisi untuk stok awal';
  end if;

  begin
    insert into public.products (id, brand_name, category_id, unit_type, min_stock, price, image_url)
    values (trim(p_id), trim(p_name), p_category, trim(p_unit), coalesce(p_min_stock, 5), coalesce(p_price, 0), p_image_url);
  exception
    when unique_violation then raise exception 'Kode barang sudah dipakai';
    when foreign_key_violation then raise exception 'Kategori tidak ditemukan';
  end;

  if p_qty is not null and p_qty > 0 then
    perform public.restock(trim(p_id), trim(p_floor), p_expiry, p_qty, coalesce(p_note, 'Stok awal'));
  end if;
end $$;

revoke all on function public.create_product_with_stock(text, text, text, integer, numeric, bigint, text, text, numeric, date, text) from public, anon;
grant execute on function public.create_product_with_stock(text, text, text, integer, numeric, bigint, text, text, numeric, date, text) to authenticated;
