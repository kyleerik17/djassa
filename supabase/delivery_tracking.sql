-- Table temps reel pour la position client/livreur d'une commande.
-- A executer dans Supabase SQL Editor.

create table if not exists public.delivery_locations (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  role text not null check (role in ('client', 'courier')),
  latitude double precision not null,
  longitude double precision not null,
  updated_at timestamptz not null default now(),
  unique (order_id, role)
);

alter table public.delivery_locations enable row level security;

-- Support du compte livreur/backoffice existant.
alter table public.profiles
add column if not exists is_admin boolean not null default false;

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select coalesce(
    (
      select p.is_admin
      from public.profiles p
      where p.id = auth.uid()
      limit 1
    ),
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
    (
      select p.role = 'courier'
      from public.profiles p
      where p.id = auth.uid()
      limit 1
    ),
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

-- Active les evenements realtime pour que l'app Flutter recoive les positions
-- sans attendre un refresh/polling.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'delivery_locations'
  ) then
    alter publication supabase_realtime add table public.delivery_locations;
  end if;
end $$;

drop policy if exists "delivery_locations_select_own_order" on public.delivery_locations;
create policy "delivery_locations_select_own_order"
on public.delivery_locations
for select
using (
  exists (
    select 1
    from public.orders o
    where o.id = delivery_locations.order_id
      and (o.user_id = auth.uid() or o.courier_id = auth.uid())
  )
);

drop policy if exists "delivery_locations_select_admin" on public.delivery_locations;
create policy "delivery_locations_select_admin"
on public.delivery_locations
for select
using (public.is_admin());

drop policy if exists "delivery_locations_insert_own_client" on public.delivery_locations;
create policy "delivery_locations_insert_own_client"
on public.delivery_locations
for insert
with check (
  role = 'client'
  and exists (
    select 1
    from public.orders o
    where o.id = delivery_locations.order_id
      and o.user_id = auth.uid()
  )
);

drop policy if exists "delivery_locations_update_own_client" on public.delivery_locations;
create policy "delivery_locations_update_own_client"
on public.delivery_locations
for update
using (
  role = 'client'
  and exists (
    select 1
    from public.orders o
    where o.id = delivery_locations.order_id
      and o.user_id = auth.uid()
  )
)
with check (
  role = 'client'
  and exists (
    select 1
    from public.orders o
    where o.id = delivery_locations.order_id
      and o.user_id = auth.uid()
  )
);

drop policy if exists "delivery_locations_insert_courier_admin" on public.delivery_locations;
create policy "delivery_locations_insert_courier_admin"
on public.delivery_locations
for insert
with check (
  role = 'courier'
  and (
    public.is_admin()
    or exists (
      select 1
      from public.orders o
      where o.id = delivery_locations.order_id
        and o.courier_id = auth.uid()
    )
  )
);

drop policy if exists "delivery_locations_update_courier_admin" on public.delivery_locations;
create policy "delivery_locations_update_courier_admin"
on public.delivery_locations
for update
using (
  role = 'courier'
  and (
    public.is_admin()
    or exists (
      select 1
      from public.orders o
      where o.id = delivery_locations.order_id
        and o.courier_id = auth.uid()
    )
  )
)
with check (
  role = 'courier'
  and (
    public.is_admin()
    or exists (
      select 1
      from public.orders o
      where o.id = delivery_locations.order_id
        and o.courier_id = auth.uid()
    )
  )
);
