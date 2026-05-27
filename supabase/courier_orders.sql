-- DJASSA / LE BOLIDE - Profils livreurs + prise de commande au plus rapide
-- A ex?cuter dans Supabase > SQL Editor > Run.

-- 1) Les profils peuvent ?tre client ou livreur.
alter table public.profiles
add column if not exists role text not null default 'client';

alter table public.profiles
add column if not exists license_number text not null default '',
add column if not exists license_type text not null default 'A',
add column if not exists license_photo_url text not null default '',
add column if not exists vehicle_type text not null default 'Moto',
add column if not exists vehicle_plate text not null default '',
add column if not exists emergency_phone text not null default '',
add column if not exists is_available boolean not null default true;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_role_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
    add constraint profiles_role_check check (role in ('client', 'courier'));
  end if;
end $$;

-- Fonction admin utilis?e par les policies (compatible avec admin_backoffice.sql).
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

-- 2) Une commande peut ?tre revendiqu?e par un seul livreur.
alter table public.orders
add column if not exists courier_id uuid references public.profiles(id) on delete set null,
add column if not exists courier_accepted_at timestamptz;

create index if not exists orders_courier_id_idx on public.orders(courier_id);
create index if not exists orders_available_for_courier_idx
on public.orders(created_at desc)
where courier_id is null;

-- R?ponses par livreur: refus local + historique de l'acceptation.
create table if not exists public.courier_order_responses (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  courier_id uuid not null references public.profiles(id) on delete cascade,
  response text not null check (response in ('accepted', 'refused')),
  created_at timestamptz not null default now(),
  unique (order_id, courier_id)
);

alter table public.courier_order_responses enable row level security;

-- 3) RLS: les livreurs voient les commandes disponibles + les leurs.
drop policy if exists "orders_courier_select_available_or_own" on public.orders;
create policy "orders_courier_select_available_or_own"
on public.orders
for select
using (
  public.is_courier_or_admin()
  and (
    courier_id is null
    or courier_id = auth.uid()
  )
);

-- Les livreurs lisent/?crivent uniquement leurs r?ponses.
drop policy if exists "courier_responses_select_own" on public.courier_order_responses;
create policy "courier_responses_select_own"
on public.courier_order_responses
for select
using (courier_id = auth.uid() or public.is_admin());

drop policy if exists "courier_responses_insert_own" on public.courier_order_responses;
create policy "courier_responses_insert_own"
on public.courier_order_responses
for insert
with check (courier_id = auth.uid() and public.is_courier());

-- 4) RPC atomique: le premier livreur qui accepte gagne.
create or replace function public.accept_delivery_order(p_order_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_updated_count integer;
begin
  if auth.uid() is null or not public.is_courier() then
    raise exception 'Profil livreur requis';
  end if;

  update public.orders
  set courier_id = auth.uid(),
      courier_accepted_at = now(),
      status = case
        when status in ('delivered', 'cancelled') then status
        else 'courier_assigned'
      end
  where id = p_order_id
    and courier_id is null
    and status not in ('delivered', 'cancelled');

  get diagnostics v_updated_count = row_count;

  if v_updated_count = 1 then
    insert into public.courier_order_responses(order_id, courier_id, response)
    values (p_order_id, auth.uid(), 'accepted')
    on conflict (order_id, courier_id)
    do update set response = 'accepted', created_at = now();
    return true;
  end if;

  return false;
end;
$$;

create or replace function public.refuse_delivery_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_courier() then
    raise exception 'Profil livreur requis';
  end if;

  insert into public.courier_order_responses(order_id, courier_id, response)
  values (p_order_id, auth.uid(), 'refused')
  on conflict (order_id, courier_id)
  do update set response = 'refused', created_at = now();
end;
$$;

-- Optionnel: realtime sur les commandes/r?ponses si vous remplacez le polling Flutter par Supabase Realtime.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'orders'
  ) then
    alter publication supabase_realtime add table public.orders;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'courier_order_responses'
  ) then
    alter publication supabase_realtime add table public.courier_order_responses;
  end if;
end $$;

-- Pour convertir un compte existant en livreur:
-- update public.profiles set role = 'courier' where email = 'livreur@example.com';
