-- DJASSA / LE BOLIDE - Schema Supabase principal
-- A coller dans Supabase > SQL Editor > New query > Run.
--
-- Important:
-- - Ce script cree les tables utilisees par l'app Flutter.
-- - Il NE corrige PAS un 422 sur /auth/v1/signup si Supabase Auth refuse
--   l'inscription (email provider desactive, confirmation email/SMTP,
--   captcha, mot de passe trop faible, rate limit, etc.).

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- PROFILS
-- ---------------------------------------------------------------------------

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  surname text not null default '',
  phone text not null default '',
  email text,
  avatar_url text,
  is_verified boolean not null default false,
  role text not null default 'client' check (role in ('client', 'courier')),
  is_admin boolean not null default false,
  license_number text not null default '',
  license_type text not null default 'A',
  license_photo_url text not null default '',
  vehicle_type text not null default 'Moto',
  vehicle_plate text not null default '',
  emergency_phone text not null default '',
  is_available boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.profiles
add column if not exists license_number text not null default '',
add column if not exists license_type text not null default 'A',
add column if not exists license_photo_url text not null default '',
add column if not exists vehicle_type text not null default 'Moto',
add column if not exists vehicle_plate text not null default '',
add column if not exists emergency_phone text not null default '',
add column if not exists is_available boolean not null default true;

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own_or_admin" on public.profiles;
create policy "profiles_select_own_or_admin"
on public.profiles
for select
using (
  id = auth.uid()
  or coalesce(
    (select p.is_admin from public.profiles p where p.id = auth.uid()),
    false
  )
);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles
for insert
with check (id = auth.uid());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles
for update
using (id = auth.uid())
with check (id = auth.uid());

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select coalesce(
    (select p.is_admin from public.profiles p where p.id = auth.uid() limit 1),
    false
  );
$$;

create or replace function public.is_courier()
returns boolean
language sql
security definer
set search_path = public
as $$
  select coalesce(
    (select p.role = 'courier' from public.profiles p where p.id = auth.uid() limit 1),
    false
  );
$$;

create or replace function public.is_courier_or_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select coalesce(public.is_courier(), false) or coalesce(public.is_admin(), false);
$$;

-- ---------------------------------------------------------------------------
-- CATALOGUE
-- ---------------------------------------------------------------------------

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  icon_name text not null default 'category',
  subtitle text not null default '',
  items_count integer not null default 0,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references public.categories(id) on delete set null,
  name text not null,
  slug text not null unique,
  description text not null default '',
  compatibility text not null default '',
  price integer not null default 0,
  old_price integer not null default 0,
  stock integer not null default 0,
  rating numeric not null default 4.5,
  badge text not null default 'Top',
  icon_name text not null default 'car',
  image_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.categories enable row level security;
alter table public.products enable row level security;

drop policy if exists "categories_public_select_active" on public.categories;
create policy "categories_public_select_active"
on public.categories
for select
using (is_active = true or public.is_admin());

drop policy if exists "products_public_select_active" on public.products;
create policy "products_public_select_active"
on public.products
for select
using (is_active = true or public.is_admin());

drop policy if exists "categories_admin_all" on public.categories;
create policy "categories_admin_all"
on public.categories
for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "products_admin_all" on public.products;
create policy "products_admin_all"
on public.products
for all
using (public.is_admin())
with check (public.is_admin());

insert into public.categories (name, slug, icon_name, subtitle, items_count, sort_order)
values
  ('Electronique', 'electronique', 'electric_bolt', 'Accessoires, gadgets, equipements', 120, 1),
  ('Maison', 'maison', 'home', 'Decoration, entretien, rangement', 86, 2),
  ('Mode', 'mode', 'checkroom', 'Vetements, sacs, chaussures', 148, 3),
  ('Beaute', 'beaute', 'spa', 'Soins, parfums, accessoires', 72, 4),
  ('Sport', 'sport', 'sports_soccer', 'Equipements et accessoires', 64, 5),
  ('Divers', 'divers', 'category', 'Autres articles du catalogue', 200, 6)
on conflict (slug) do nothing;

-- ---------------------------------------------------------------------------
-- COMMANDES
-- ---------------------------------------------------------------------------

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text unique default ('DJ-' || upper(substr(gen_random_uuid()::text, 1, 6))),
  user_id uuid not null references public.profiles(id) on delete cascade,
  customer_name text not null default '',
  customer_phone text not null default '',
  delivery_address text not null default '',
  subtotal integer not null default 0,
  delivery_fee integer not null default 0,
  total integer not null default 0,
  items_count integer not null default 1,
  status text not null default 'pending_payment',
  courier_id uuid references public.profiles(id) on delete set null,
  courier_accepted_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  quantity integer not null default 1,
  unit_price integer not null default 0,
  total integer not null default 0,
  created_at timestamptz not null default now()
);

alter table public.orders enable row level security;
alter table public.order_items enable row level security;

drop policy if exists "orders_select_own_courier_admin" on public.orders;
create policy "orders_select_own_courier_admin"
on public.orders
for select
using (
  user_id = auth.uid()
  or courier_id = auth.uid()
  or (public.is_courier_or_admin() and courier_id is null)
  or public.is_admin()
);

drop policy if exists "orders_insert_own" on public.orders;
create policy "orders_insert_own"
on public.orders
for insert
with check (user_id = auth.uid());

drop policy if exists "orders_update_own_or_admin" on public.orders;
create policy "orders_update_own_or_admin"
on public.orders
for update
using (user_id = auth.uid() or courier_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or courier_id = auth.uid() or public.is_admin());

drop policy if exists "order_items_select_own_order" on public.order_items;
create policy "order_items_select_own_order"
on public.order_items
for select
using (
  exists (
    select 1 from public.orders o
    where o.id = order_items.order_id
      and (o.user_id = auth.uid() or o.courier_id = auth.uid() or public.is_admin())
  )
);

drop policy if exists "order_items_insert_own_order" on public.order_items;
create policy "order_items_insert_own_order"
on public.order_items
for insert
with check (
  exists (
    select 1 from public.orders o
    where o.id = order_items.order_id
      and o.user_id = auth.uid()
  )
);

-- ---------------------------------------------------------------------------
-- NOTIFICATIONS
-- ---------------------------------------------------------------------------

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  icon_name text not null default 'notifications_active',
  user_id uuid references public.profiles(id) on delete cascade,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.notifications enable row level security;

drop policy if exists "notifications_select_target_or_admin" on public.notifications;
create policy "notifications_select_target_or_admin"
on public.notifications
for select
using (user_id is null or user_id = auth.uid() or public.is_admin());

drop policy if exists "notifications_admin_all" on public.notifications;
create policy "notifications_admin_all"
on public.notifications
for all
using (public.is_admin())
with check (public.is_admin());
