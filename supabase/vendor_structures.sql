-- Vendeurs : role vendor + table structures (liaison Merise profiles 1 — N structures)
-- À exécuter dans Supabase > SQL Editor après sql_editor_djassa.sql

-- Étendre le rôle vendeur sur profiles
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role in ('client', 'courier', 'vendor', 'admin'));

create table if not exists public.structures (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  slug text not null unique,
  description text not null default '',
  phone text not null default '',
  email text,
  logo_url text,
  cover_url text,
  address text not null default '',
  latitude double precision,
  longitude double precision,
  is_verified boolean not null default false,
  is_active boolean not null default true,
  opening_hour text default '08:00',
  closing_hour text default '18:00',
  delivery_fee integer not null default 0 check (delivery_fee >= 0),
  minimum_order integer not null default 0 check (minimum_order >= 0),
  rating numeric not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists structures_owner_id_idx on public.structures (owner_id);

alter table public.products
  add column if not exists structure_id uuid references public.structures(id);

create index if not exists products_structure_id_idx on public.products (structure_id);

create or replace function public.is_vendor()
returns boolean
language sql
security definer
set search_path = public
return coalesce(
  (
    select p.role = 'vendor'
    from public.profiles p
    where p.id = auth.uid()
    limit 1
  ),
  false
);

alter table public.structures enable row level security;

drop policy if exists "structures_select_public" on public.structures;
create policy "structures_select_public"
on public.structures for select
using (is_active = true and deleted_at is null);

drop policy if exists "structures_manage_own" on public.structures;
create policy "structures_manage_own"
on public.structures for all
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

drop policy if exists "products_vendor_select_own" on public.products;
create policy "products_vendor_select_own"
on public.products for select
using (
  exists (
    select 1
    from public.structures s
    where s.id = products.structure_id
      and s.owner_id = auth.uid()
  )
);

drop policy if exists "products_vendor_insert_own" on public.products;
create policy "products_vendor_insert_own"
on public.products for insert
with check (
  public.is_vendor()
  and exists (
    select 1
    from public.structures s
    where s.id = products.structure_id
      and s.owner_id = auth.uid()
  )
);

drop policy if exists "products_vendor_update_own" on public.products;
create policy "products_vendor_update_own"
on public.products for update
using (
  public.is_vendor()
  and exists (
    select 1
    from public.structures s
    where s.id = products.structure_id
      and s.owner_id = auth.uid()
  )
)
with check (
  public.is_vendor()
  and exists (
    select 1
    from public.structures s
    where s.id = products.structure_id
      and s.owner_id = auth.uid()
  )
);

drop policy if exists "products_vendor_delete_own" on public.products;
create policy "products_vendor_delete_own"
on public.products for delete
using (
  public.is_vendor()
  and exists (
    select 1
    from public.structures s
    where s.id = products.structure_id
      and s.owner_id = auth.uid()
  )
);

-- Commandes vendeur sans accès au profil client.
-- La fonction ne retourne que les infos nécessaires à la boutique:
-- numéro, statut, date et articles vendus.
drop function if exists public.get_vendor_orders();
create or replace function public.get_vendor_orders()
returns table (
  order_id uuid,
  order_number text,
  status text,
  created_at timestamptz,
  item_name text,
  quantity integer,
  unit_price integer,
  item_total integer
)
language sql
security definer
set search_path = public
as '
  select
    o.id as order_id,
    o.order_number,
    o.status,
    o.created_at,
    oi.product_name as item_name,
    oi.quantity,
    oi.unit_price,
    oi.total as item_total
  from public.order_items oi
  join public.orders o on o.id = oi.order_id
  join public.products p on p.id = oi.product_id
  join public.structures s on s.id = p.structure_id
  where s.owner_id = auth.uid()
    and exists (
      select 1
      from public.profiles profile
      where profile.id = auth.uid()
        and profile.role = ''vendor''
    )
  order by o.created_at desc, oi.created_at asc
';

grant execute on function public.get_vendor_orders() to authenticated;

select 'vendor_structures_sql_ok' as status;
