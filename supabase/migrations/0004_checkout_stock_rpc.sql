-- Fase 2: uang integer, checkout atomik (FEFO), audit trail stok, harga modal khusus owner.

-- 1) Uang jadi bigint (Rupiah bulat)
alter table public.products
  alter column price type bigint using round(price)::bigint;
alter table public.transactions
  alter column total_amount type bigint using round(total_amount)::bigint,
  alter column paid_amount type bigint using round(paid_amount)::bigint,
  alter column change_amount type bigint using round(change_amount)::bigint;
alter table public.transaction_items
  alter column price_at_purchase type bigint using round(price_at_purchase)::bigint,
  alter column subtotal type bigint using round(subtotal)::bigint;

-- 2) Harga modal dipindah ke tabel khusus owner
create table public.product_costs (
  product_id text primary key references public.products(id) on delete cascade,
  capital_price bigint not null default 0 check (capital_price >= 0)
);
insert into public.product_costs (product_id, capital_price)
  select id, round(coalesce(capital_price, 0))::bigint from public.products;
alter table public.product_costs enable row level security;
create policy product_costs_owner on public.product_costs for all to authenticated
  using (private.is_role('owner')) with check (private.is_role('owner'));

create or replace function private.guard_product_prices() returns trigger
  language plpgsql set search_path = '' as $$
begin
  if (new.price is distinct from old.price or new.is_deleted is distinct from old.is_deleted)
     and not private.is_role('owner') then
    raise exception 'Hanya owner yang boleh mengubah harga atau menghapus barang';
  end if;
  return new;
end $$;
alter table public.products drop column capital_price;

-- 3) Batasan stok, kolom baru, audit trail
alter table public.stocks add constraint stocks_qty_nonneg check (quantity >= 0);
create unique index stocks_batch_uq on public.stocks
  (product_id, floor_name, (coalesce(expiry_date, 'infinity'::date)));
create index stocks_product_idx on public.stocks (product_id);

alter table public.transactions
  add column idempotency_key uuid unique,
  add column payment_method text not null default 'cash';
alter table public.transaction_items
  add column product_name text not null default '';
create index tx_created_idx on public.transactions (created_at);
create index txi_tx_idx on public.transaction_items (transaction_id);

create table public.stock_movements (
  id bigint generated always as identity primary key,
  product_id text not null references public.products(id),
  floor_name text not null,
  expiry_date date,
  delta numeric not null,
  kind text not null check (kind in ('sale','restock','opname','transfer_in','transfer_out')),
  ref_transaction_id integer references public.transactions(id),
  note text,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);
create index sm_product_idx on public.stock_movements (product_id, created_at desc);
alter table public.stock_movements enable row level security;
create policy sm_select on public.stock_movements for select to authenticated
  using (private.is_role('owner','warehouse'));

-- 4) Semua perubahan stok/transaksi hanya lewat RPC
drop policy if exists stocks_insert on public.stocks;
drop policy if exists stocks_update on public.stocks;
drop policy if exists stocks_delete on public.stocks;
drop policy if exists tx_insert on public.transactions;
drop policy if exists txi_insert on public.transaction_items;
drop policy if exists products_delete on public.products;
revoke insert, update, delete on public.stocks, public.transactions, public.transaction_items from authenticated;
revoke insert, update, delete on public.stock_movements from authenticated;
revoke delete on public.products from authenticated;

-- 5) Pembentuk JSON nota
create function private.tx_json(p_id integer) returns jsonb
  language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', t.id, 'total', t.total_amount, 'paid', t.paid_amount,
    'change', t.change_amount, 'created_at', t.created_at,
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'product_id', i.product_id, 'name', i.product_name, 'qty', i.quantity,
        'price', i.price_at_purchase, 'subtotal', i.subtotal) order by i.id)
      from public.transaction_items i where i.transaction_id = t.id), '[]'::jsonb))
  from public.transactions t where t.id = p_id $$;
revoke execute on function private.tx_json(integer) from public, anon, authenticated;

-- 6) Checkout atomik: idempotent, FEFO, tolak stok kurang, lewati stok kedaluwarsa
create function public.checkout(p_key uuid, p_items jsonb, p_paid bigint) returns jsonb
  language plpgsql security definer set search_path = '' as $$
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

  begin
    insert into public.transactions (total_amount, paid_amount, change_amount, cashier_id, idempotency_key)
    values (v_total, p_paid, p_paid - v_total, v_uid, p_key) returning * into v_tx;
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

-- 7) Stok masuk
create function public.restock(p_product text, p_floor text, p_expiry date, p_qty numeric, p_note text default null)
  returns void language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_role('owner','warehouse') then
    raise exception 'Anda tidak punya akses untuk mengubah stok' using errcode = '42501';
  end if;
  if p_qty is null or p_qty <= 0 then raise exception 'Jumlah harus lebih dari 0'; end if;
  if nullif(trim(p_floor), '') is null then raise exception 'Lantai wajib diisi'; end if;
  if not exists (select 1 from public.products where id = p_product and not is_deleted) then
    raise exception 'Barang tidak ditemukan';
  end if;
  insert into public.stocks (product_id, floor_name, expiry_date, quantity)
  values (p_product, trim(p_floor), p_expiry, p_qty)
  on conflict (product_id, floor_name, (coalesce(expiry_date, 'infinity'::date)))
  do update set quantity = public.stocks.quantity + excluded.quantity;
  insert into public.stock_movements (product_id, floor_name, expiry_date, delta, kind, note)
  values (p_product, trim(p_floor), p_expiry, p_qty, 'restock', p_note);
end $$;

-- 8) Opname: set jumlah hasil hitung fisik
create function public.stock_count(p_product text, p_floor text, p_expiry date, p_counted numeric, p_note text default null)
  returns void language plpgsql security definer set search_path = '' as $$
declare v_old numeric;
begin
  if not private.is_role('owner','warehouse') then
    raise exception 'Anda tidak punya akses untuk mengubah stok' using errcode = '42501';
  end if;
  if p_counted is null or p_counted < 0 then raise exception 'Jumlah tidak valid'; end if;
  if not exists (select 1 from public.products where id = p_product and not is_deleted) then
    raise exception 'Barang tidak ditemukan';
  end if;
  select quantity into v_old from public.stocks
   where product_id = p_product and floor_name = p_floor
     and coalesce(expiry_date, 'infinity'::date) = coalesce(p_expiry, 'infinity'::date) for update;
  if not found then
    if p_counted > 0 then
      insert into public.stocks (product_id, floor_name, expiry_date, quantity) values (p_product, p_floor, p_expiry, p_counted);
      insert into public.stock_movements (product_id, floor_name, expiry_date, delta, kind, note)
      values (p_product, p_floor, p_expiry, p_counted, 'opname', p_note);
    end if;
    return;
  end if;
  if v_old = p_counted then return; end if;
  update public.stocks set quantity = p_counted
   where product_id = p_product and floor_name = p_floor
     and coalesce(expiry_date, 'infinity'::date) = coalesce(p_expiry, 'infinity'::date);
  insert into public.stock_movements (product_id, floor_name, expiry_date, delta, kind, note)
  values (p_product, p_floor, p_expiry, p_counted - v_old, 'opname', p_note);
end $$;

-- 9) Mutasi antar-lantai atomik
create function public.transfer_stock(p_product text, p_from text, p_to text, p_expiry date, p_qty numeric)
  returns void language plpgsql security definer set search_path = '' as $$
declare v_src numeric;
begin
  if not private.is_role('owner','warehouse') then
    raise exception 'Anda tidak punya akses untuk mengubah stok' using errcode = '42501';
  end if;
  if p_qty is null or p_qty <= 0 then raise exception 'Jumlah harus lebih dari 0'; end if;
  if p_from = p_to or nullif(trim(p_to), '') is null then raise exception 'Lantai tujuan tidak valid'; end if;
  select quantity into v_src from public.stocks
   where product_id = p_product and floor_name = p_from
     and coalesce(expiry_date, 'infinity'::date) = coalesce(p_expiry, 'infinity'::date) for update;
  if not found or v_src < p_qty then raise exception 'Stok di lantai asal tidak cukup'; end if;
  update public.stocks set quantity = quantity - p_qty
   where product_id = p_product and floor_name = p_from
     and coalesce(expiry_date, 'infinity'::date) = coalesce(p_expiry, 'infinity'::date);
  insert into public.stocks (product_id, floor_name, expiry_date, quantity)
  values (p_product, trim(p_to), p_expiry, p_qty)
  on conflict (product_id, floor_name, (coalesce(expiry_date, 'infinity'::date)))
  do update set quantity = public.stocks.quantity + excluded.quantity;
  insert into public.stock_movements (product_id, floor_name, expiry_date, delta, kind)
  values (p_product, p_from, p_expiry, -p_qty, 'transfer_out'),
         (p_product, trim(p_to), p_expiry, p_qty, 'transfer_in');
end $$;

revoke execute on function public.checkout(uuid, jsonb, bigint) from public, anon;
revoke execute on function public.restock(text, text, date, numeric, text) from public, anon;
revoke execute on function public.stock_count(text, text, date, numeric, text) from public, anon;
revoke execute on function public.transfer_stock(text, text, text, date, numeric) from public, anon;
grant execute on function public.checkout(uuid, jsonb, bigint) to authenticated;
grant execute on function public.restock(text, text, date, numeric, text) to authenticated;
grant execute on function public.stock_count(text, text, date, numeric, text) to authenticated;
grant execute on function public.transfer_stock(text, text, text, date, numeric) to authenticated;
