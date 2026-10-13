-- Fase 1: peran, profil, RLS. Sudah diterapkan ke proyek Supabase pada 13 Okt 2026.
create schema if not exists private;
create type public.app_role as enum ('owner','cashier','warehouse');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role public.app_role not null default 'cashier',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create function private.user_role() returns public.app_role
  language sql stable security definer set search_path = ''
  as $$ select role from public.profiles where id = auth.uid() and is_active $$;
create function private.is_role(variadic r public.app_role[]) returns boolean
  language sql stable security definer set search_path = ''
  as $$ select coalesce(private.user_role() = any(r), false) $$;
revoke all on schema private from public;
grant usage on schema private to authenticated;
revoke execute on all functions in schema private from public, anon;
grant execute on function private.user_role(), private.is_role(public.app_role[]) to authenticated;

create function private.handle_new_user() returns trigger
  language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, full_name, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''),
          coalesce((new.raw_app_meta_data->>'role')::public.app_role,'cashier'));
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.handle_new_user();

alter table public.transactions
  add column cashier_id uuid references auth.users(id) on delete set null default auth.uid();

create function private.guard_product_prices() returns trigger language plpgsql set search_path = '' as $$
begin
  if (new.price is distinct from old.price or new.capital_price is distinct from old.capital_price)
     and not private.is_role('owner') then
    raise exception 'Hanya owner yang boleh mengubah harga';
  end if;
  return new;
end $$;
create trigger products_guard_prices before update on public.products
  for each row execute function private.guard_product_prices();

create function private.guard_profile_update() returns trigger language plpgsql set search_path = '' as $$
begin
  if old.id = auth.uid() and (new.role <> old.role or new.is_active <> old.is_active) then
    raise exception 'Tidak bisa mengubah peran atau status akun sendiri';
  end if;
  return new;
end $$;
create trigger profiles_guard_update before update on public.profiles
  for each row execute function private.guard_profile_update();

alter table public.profiles          enable row level security;
alter table public.categories        enable row level security;
alter table public.products          enable row level security;
alter table public.stocks            enable row level security;
alter table public.transactions      enable row level security;
alter table public.transaction_items enable row level security;

create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()) or private.is_role('owner'));
create policy profiles_update on public.profiles for update to authenticated
  using (private.is_role('owner')) with check (private.is_role('owner'));

create policy categories_select on public.categories for select to authenticated
  using (private.is_role('owner','cashier','warehouse'));
create policy categories_write on public.categories for insert to authenticated
  with check (private.is_role('owner','warehouse'));
create policy categories_update on public.categories for update to authenticated
  using (private.is_role('owner','warehouse')) with check (private.is_role('owner','warehouse'));
create policy categories_delete on public.categories for delete to authenticated
  using (private.is_role('owner'));

create policy products_select on public.products for select to authenticated
  using (private.is_role('owner','cashier','warehouse'));
create policy products_insert on public.products for insert to authenticated
  with check (private.is_role('owner','warehouse'));
create policy products_update on public.products for update to authenticated
  using (private.is_role('owner','warehouse')) with check (private.is_role('owner','warehouse'));
create policy products_delete on public.products for delete to authenticated
  using (private.is_role('owner'));

create policy stocks_select on public.stocks for select to authenticated
  using (private.is_role('owner','cashier','warehouse'));
create policy stocks_insert on public.stocks for insert to authenticated
  with check (private.is_role('owner','warehouse'));
-- kasir boleh update stok SEMENTARA; dicabut di Fase 2 saat checkout pindah ke RPC
create policy stocks_update on public.stocks for update to authenticated
  using (private.is_role('owner','warehouse','cashier'))
  with check (private.is_role('owner','warehouse','cashier'));
create policy stocks_delete on public.stocks for delete to authenticated
  using (private.is_role('owner','warehouse'));

create policy tx_select on public.transactions for select to authenticated
  using (private.is_role('owner') or (private.is_role('cashier') and cashier_id = (select auth.uid())));
create policy tx_insert on public.transactions for insert to authenticated
  with check (private.is_role('owner','cashier') and cashier_id = (select auth.uid()));

create policy txi_select on public.transaction_items for select to authenticated
  using (private.is_role('owner') or exists (select 1 from public.transactions t
         where t.id = transaction_id and t.cashier_id = (select auth.uid())));
create policy txi_insert on public.transaction_items for insert to authenticated
  with check (private.is_role('owner','cashier') and exists (select 1 from public.transactions t
         where t.id = transaction_id and t.cashier_id = (select auth.uid())));

revoke all on all tables    in schema public from anon;
revoke all on all sequences in schema public from anon;
alter default privileges in schema public revoke all on tables from anon;
