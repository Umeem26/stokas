-- Baseline: dokumentasi skema Supabase sesuai kondisi per 13 Okt 2026.
-- RLS sengaja belum aktif di sini; diperbaiki di migrasi berikutnya.
-- Jangan dijalankan ke proyek yang sudah berisi tabel-tabel ini.

create table public.categories (id serial primary key, name text not null);
create table public.products (id text primary key, brand_name text not null, category_id int references public.categories(id), unit_type text not null, min_stock numeric default 5, price numeric default 0, capital_price numeric default 0, is_deleted boolean default false, image_url text);
create table public.stocks (id serial primary key, product_id text references public.products(id), floor_name text not null, quantity numeric not null, expiry_date date, created_at timestamptz default now());
create table public.transactions (id serial primary key, total_amount numeric not null, paid_amount numeric not null, change_amount numeric not null, created_at timestamptz default now());
create table public.transaction_items (id serial primary key, transaction_id int references public.transactions(id), product_id text references public.products(id), quantity numeric not null, price_at_purchase numeric not null, subtotal numeric not null);
