-- DJASSA / LE BOLIDE - Couche backend production
-- A executer apres:
-- 1) sql_editor_djassa.sql
-- 2) admin_backoffice.sql
-- 3) vendor_structures.sql
-- 4) courier_orders.sql
-- 5) delivery_tracking.sql
--
-- Objectif:
-- - RLS stricte par role.
-- - RPC metier pour commandes, livraison, paiement, stock.
-- - Triggers d'audit, notifications et historique.
-- - Stats admin, coupons, remboursements, messagerie, signalements.
-- - Storage policies et index de recherche.

create extension if not exists pgcrypto;
create extension if not exists pg_trgm;

-- ============================================================================
-- HELPERS ROLES / ACCES
-- ============================================================================

alter table public.profiles
  add column if not exists role text not null default 'client',
  add column if not exists is_admin boolean not null default false,
  add column if not exists updated_at timestamptz not null default now();

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role in ('client', 'courier', 'vendor', 'admin'));

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    (
      select p.is_admin or p.role = 'admin'
      from public.profiles p
      where p.id = auth.uid()
      limit 1
    ),
    false
  );
$$;

create or replace function public.has_role(p_role text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    (
      select p.role = p_role or public.is_admin()
      from public.profiles p
      where p.id = auth.uid()
      limit 1
    ),
    false
  );
$$;

create or replace function public.is_vendor()
returns boolean
language sql
security definer
set search_path = public
stable
as $$ select public.has_role('vendor'); $$;

create or replace function public.is_courier()
returns boolean
language sql
security definer
set search_path = public
stable
as $$ select public.has_role('courier'); $$;

create or replace function public.owns_structure(p_structure_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    (
      select s.owner_id = auth.uid() or public.is_admin()
      from public.structures s
      where s.id = p_structure_id
      limit 1
    ),
    false
  );
$$;

create or replace function public.can_access_order(p_order_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    (
      select
        o.user_id = auth.uid()
        or o.courier_id = auth.uid()
        or public.is_admin()
        or exists (
          select 1
          from public.order_items oi
          join public.products p on p.id = oi.product_id
          join public.structures s on s.id = p.structure_id
          where oi.order_id = o.id
            and s.owner_id = auth.uid()
        )
      from public.orders o
      where o.id = p_order_id
      limit 1
    ),
    false
  );
$$;

-- ============================================================================
-- COLONNES / TABLES SUPPORT
-- ============================================================================

alter table public.categories
  add column if not exists updated_at timestamptz not null default now();

alter table public.products
  add column if not exists structure_id uuid references public.structures(id),
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists deleted_at timestamptz;

alter table public.products drop constraint if exists products_stock_non_negative;
alter table public.products
  add constraint products_stock_non_negative check (stock >= 0);

alter table public.products drop constraint if exists products_price_non_negative;
alter table public.products
  add constraint products_price_non_negative check (price >= 0 and old_price >= 0);

alter table public.structures
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists deleted_at timestamptz;

alter table public.orders
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists cancelled_at timestamptz,
  add column if not exists delivered_at timestamptz,
  add column if not exists coupon_id uuid,
  add column if not exists discount_total integer not null default 0,
  add column if not exists platform_commission integer not null default 0,
  add column if not exists metadata jsonb not null default '{}'::jsonb;

alter table public.orders drop constraint if exists orders_amounts_non_negative;
alter table public.orders
  add constraint orders_amounts_non_negative check (
    subtotal >= 0
    and delivery_fee >= 0
    and total >= 0
    and discount_total >= 0
    and platform_commission >= 0
  );

alter table public.orders drop constraint if exists orders_status_check;
alter table public.orders
  add constraint orders_status_check check (
    status in (
      'pending_payment', 'pending', 'paid', 'confirmed',
      'courier_assigned', 'shipping', 'delivered', 'cancelled',
      'refunded'
    )
  );

alter table public.order_items
  add column if not exists structure_id uuid references public.structures(id),
  add column if not exists updated_at timestamptz not null default now();

alter table public.order_items drop constraint if exists order_items_quantity_positive;
alter table public.order_items
  add constraint order_items_quantity_positive check (quantity > 0);

alter table public.order_items drop constraint if exists order_items_amounts_non_negative;
alter table public.order_items
  add constraint order_items_amounts_non_negative check (unit_price >= 0 and total >= 0);

create table if not exists public.platform_settings (
  key text primary key,
  value jsonb not null,
  description text not null default '',
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);

insert into public.platform_settings(key, value, description)
values
  ('platform_commission_percent', '10', 'Commission plateforme en pourcentage'),
  ('base_delivery_fee', '2500', 'Frais de livraison par defaut en FCFA'),
  ('free_delivery_minimum', '0', 'Minimum panier pour livraison gratuite'),
  ('support_phone', '""', 'Telephone support'),
  ('support_email', '""', 'Email support')
on conflict (key) do nothing;

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  provider text not null,
  phone text not null default '',
  reference text not null unique,
  provider_payment_id text,
  amount integer not null check (amount >= 0),
  status text not null default 'pending' check (
    status in ('pending', 'processing', 'completed', 'failed', 'cancelled', 'refunded')
  ),
  status_message text not null default '',
  checkout_url text,
  webhook_url text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.webhook_logs (
  id uuid primary key default gen_random_uuid(),
  event_id text not null unique,
  event_type text not null default 'unknown',
  payload_summary jsonb not null default '{}'::jsonb,
  processed_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  old_status text,
  new_status text not null,
  changed_by uuid references public.profiles(id) on delete set null,
  note text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  table_name text not null,
  row_id uuid,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.coupons (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  description text not null default '',
  discount_type text not null check (discount_type in ('percent', 'fixed')),
  discount_value integer not null check (discount_value > 0),
  starts_at timestamptz,
  ends_at timestamptz,
  max_uses integer,
  per_user_limit integer not null default 1,
  min_order_total integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.coupon_redemptions (
  id uuid primary key default gen_random_uuid(),
  coupon_id uuid not null references public.coupons(id) on delete cascade,
  order_id uuid not null references public.orders(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  discount_amount integer not null default 0,
  created_at timestamptz not null default now(),
  unique (coupon_id, order_id)
);

create table if not exists public.refund_requests (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null,
  amount integer not null check (amount >= 0),
  status text not null default 'pending' check (
    status in ('pending', 'approved', 'rejected', 'paid', 'cancelled')
  ),
  admin_id uuid references public.profiles(id) on delete set null,
  admin_note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references public.orders(id) on delete cascade,
  client_id uuid not null references public.profiles(id) on delete cascade,
  vendor_id uuid references public.profiles(id) on delete cascade,
  courier_id uuid references public.profiles(id) on delete cascade,
  type text not null check (type in ('client_vendor', 'client_courier')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('product', 'user', 'order', 'message')),
  target_id uuid not null,
  reason text not null,
  details text not null default '',
  status text not null default 'open' check (status in ('open', 'reviewing', 'resolved', 'rejected')),
  admin_id uuid references public.profiles(id) on delete set null,
  admin_note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================================
-- GENERIC TRIGGERS
-- ============================================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.attach_order_item_structure()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.product_id is not null then
    select p.structure_id into new.structure_id
    from public.products p
    where p.id = new.product_id;
  end if;

  new.total = new.quantity * new.unit_price;
  return new;
end;
$$;

create or replace function public.log_order_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.order_status_history(order_id, old_status, new_status, changed_by, note)
    values (new.id, null, new.status, auth.uid(), 'creation');
    return new;
  end if;

  if old.status is distinct from new.status then
    insert into public.order_status_history(order_id, old_status, new_status, changed_by)
    values (new.id, old.status, new.status, auth.uid());
  end if;

  return new;
end;
$$;

create or replace function public.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row_id uuid;
begin
  v_row_id := nullif(
    case
      when tg_op = 'DELETE' then coalesce(to_jsonb(old)->>'id', '')
      else coalesce(to_jsonb(new)->>'id', '')
    end,
    ''
  )::uuid;

  insert into public.audit_logs(actor_id, action, table_name, row_id, old_data, new_data)
  values (
    auth.uid(),
    tg_op,
    tg_table_name,
    v_row_id,
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) else null end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) else null end
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create or replace function public.create_notification(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_icon_name text default 'notifications_active'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  insert into public.notifications(user_id, title, body, icon_name)
  values (p_user_id, p_title, p_body, p_icon_name)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.notify_order_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_vendor_id uuid;
begin
  if tg_op = 'INSERT' then
    perform public.create_notification(
      new.user_id,
      'Commande creee',
      'Votre commande ' || coalesce(new.order_number, '') || ' a ete enregistree.',
      'shopping_bag'
    );

    for v_vendor_id in
      select distinct s.owner_id
      from public.order_items oi
      join public.products p on p.id = oi.product_id
      join public.structures s on s.id = p.structure_id
      where oi.order_id = new.id
    loop
      perform public.create_notification(
        v_vendor_id,
        'Nouvelle commande',
        'Une commande contient un article de votre boutique.',
        'storefront_rounded'
      );
    end loop;

    return new;
  end if;

  if old.status is distinct from new.status then
    if new.status = 'paid' then
      perform public.create_notification(new.user_id, 'Paiement recu', 'Votre paiement a ete confirme.', 'payments');
    elsif new.status = 'courier_assigned' then
      perform public.create_notification(new.user_id, 'Livreur assigne', 'Un livreur a pris en charge votre commande.', 'local_shipping');
      if new.courier_id is not null then
        perform public.create_notification(new.courier_id, 'Livraison assignee', 'Une livraison vous a ete assignee.', 'local_shipping');
      end if;
    elsif new.status = 'delivered' then
      perform public.create_notification(new.user_id, 'Commande livree', 'Votre commande a ete livree.', 'check_circle');
    elsif new.status = 'cancelled' then
      perform public.create_notification(new.user_id, 'Commande annulee', 'Votre commande a ete annulee.', 'cancel');
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.apply_payment_status_to_order()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status in ('completed', 'paid') and old.status is distinct from new.status then
    update public.orders
    set status = 'paid',
        updated_at = now()
    where id = new.order_id
      and status in ('pending_payment', 'pending', 'confirmed');

    perform public.create_notification(
      new.user_id,
      'Paiement recu',
      'Votre paiement de ' || new.amount || ' FCFA a ete confirme.',
      'payments'
    );
  elsif new.status in ('failed', 'cancelled') and old.status is distinct from new.status then
    perform public.create_notification(
      new.user_id,
      'Paiement non finalise',
      'Votre paiement n''a pas ete confirme.',
      'payments'
    );
  end if;

  return new;
end;
$$;

create or replace function public.prevent_negative_stock()
returns trigger
language plpgsql
as $$
begin
  if new.stock < 0 then
    raise exception 'Stock negatif interdit';
  end if;
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles', 'categories', 'products', 'structures', 'orders', 'order_items',
    'payments', 'coupons', 'refund_requests', 'conversations', 'reports',
    'platform_settings'
  ] loop
    execute format('drop trigger if exists set_%I_updated_at on public.%I', t, t);
    execute format(
      'create trigger set_%I_updated_at before update on public.%I for each row execute function public.set_updated_at()',
      t,
      t
    );
  end loop;
end $$;

drop trigger if exists order_items_attach_structure on public.order_items;
create trigger order_items_attach_structure
before insert or update on public.order_items
for each row execute function public.attach_order_item_structure();

drop trigger if exists orders_status_history on public.orders;
create trigger orders_status_history
after insert or update of status on public.orders
for each row execute function public.log_order_status_change();

drop trigger if exists orders_notifications on public.orders;
create trigger orders_notifications
after insert or update of status, courier_id on public.orders
for each row execute function public.notify_order_change();

drop trigger if exists payments_apply_status on public.payments;
create trigger payments_apply_status
after update of status on public.payments
for each row execute function public.apply_payment_status_to_order();

drop trigger if exists products_prevent_negative_stock on public.products;
create trigger products_prevent_negative_stock
before insert or update of stock on public.products
for each row execute function public.prevent_negative_stock();

do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles', 'categories', 'products', 'structures', 'orders', 'order_items',
    'payments', 'coupons', 'refund_requests', 'conversations', 'messages',
    'reports', 'platform_settings'
  ] loop
    execute format('drop trigger if exists audit_%I_changes on public.%I', t, t);
    execute format(
      'create trigger audit_%I_changes after insert or update or delete on public.%I for each row execute function public.audit_row_change()',
      t,
      t
    );
  end loop;
end $$;

-- ============================================================================
-- RPC METIER COMMANDES / STOCK / LIVRAISON
-- ============================================================================

create or replace function public.get_setting_int(p_key text, p_fallback integer)
returns integer
language sql
security definer
set search_path = public
stable
as $$
  select coalesce((select (value #>> '{}')::integer from public.platform_settings where key = p_key), p_fallback);
$$;

create or replace function public.calculate_delivery_fee(p_subtotal integer)
returns integer
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_base integer := public.get_setting_int('base_delivery_fee', 2500);
  v_free_min integer := public.get_setting_int('free_delivery_minimum', 0);
begin
  if v_free_min > 0 and p_subtotal >= v_free_min then
    return 0;
  end if;
  return greatest(v_base, 0);
end;
$$;

create or replace function public.calculate_coupon_discount(
  p_code text,
  p_user_id uuid,
  p_subtotal integer
)
returns table(coupon_id uuid, discount_amount integer)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_coupon public.coupons%rowtype;
  v_total_uses integer;
  v_user_uses integer;
begin
  coupon_id := null;
  discount_amount := 0;

  if p_code is null or btrim(p_code) = '' then
    return next;
    return;
  end if;

  select * into v_coupon
  from public.coupons
  where lower(code) = lower(btrim(p_code))
    and is_active = true
    and (starts_at is null or starts_at <= now())
    and (ends_at is null or ends_at >= now())
    and min_order_total <= p_subtotal
  limit 1;

  if not found then
    return next;
    return;
  end if;

  select count(*) into v_total_uses
  from public.coupon_redemptions
  where coupon_redemptions.coupon_id = v_coupon.id;

  if v_coupon.max_uses is not null and v_total_uses >= v_coupon.max_uses then
    return next;
    return;
  end if;

  select count(*) into v_user_uses
  from public.coupon_redemptions
  where coupon_redemptions.coupon_id = v_coupon.id
    and coupon_redemptions.user_id = p_user_id;

  if v_user_uses >= v_coupon.per_user_limit then
    return next;
    return;
  end if;

  coupon_id := v_coupon.id;
  if v_coupon.discount_type = 'percent' then
    discount_amount := floor(p_subtotal * least(v_coupon.discount_value, 100) / 100.0)::integer;
  else
    discount_amount := v_coupon.discount_value;
  end if;
  discount_amount := least(discount_amount, p_subtotal);
  return next;
end;
$$;

create or replace function public.create_order(
  p_customer_name text,
  p_customer_phone text,
  p_delivery_address text,
  p_items jsonb,
  p_coupon_code text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_order_id uuid;
  v_item jsonb;
  v_product record;
  v_quantity integer;
  v_subtotal integer := 0;
  v_delivery_fee integer := 0;
  v_discount integer := 0;
  v_coupon_id uuid;
  v_total integer := 0;
  v_items_count integer := 0;
  v_commission_percent integer := public.get_setting_int('platform_commission_percent', 10);
begin
  if v_user_id is null then
    raise exception 'Utilisateur non authentifie';
  end if;

  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Panier vide';
  end if;

  insert into public.orders(
    user_id, customer_name, customer_phone, delivery_address,
    subtotal, delivery_fee, discount_total, total, items_count,
    status, platform_commission
  )
  values (
    v_user_id, coalesce(p_customer_name, ''), coalesce(p_customer_phone, ''),
    coalesce(p_delivery_address, ''), 0, 0, 0, 0, 0,
    'pending_payment', 0
  )
  returning id into v_order_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_quantity := greatest(coalesce((v_item->>'quantity')::integer, 1), 1);

    select p.id, p.name, p.price, p.stock, p.structure_id
    into v_product
    from public.products p
    where p.id = (v_item->>'product_id')::uuid
      and p.is_active = true
      and p.deleted_at is null
    for update;

    if not found then
      raise exception 'Article introuvable';
    end if;

    if v_product.stock < v_quantity then
      raise exception 'Stock insuffisant pour %', v_product.name;
    end if;

    update public.products
    set stock = stock - v_quantity
    where id = v_product.id;

    insert into public.order_items(
      order_id, product_id, product_name, quantity, unit_price, total, structure_id
    )
    values (
      v_order_id, v_product.id, v_product.name, v_quantity, v_product.price,
      v_product.price * v_quantity, v_product.structure_id
    );

    v_subtotal := v_subtotal + (v_product.price * v_quantity);
    v_items_count := v_items_count + v_quantity;
  end loop;

  select c.coupon_id, c.discount_amount
  into v_coupon_id, v_discount
  from public.calculate_coupon_discount(p_coupon_code, v_user_id, v_subtotal) c;

  v_delivery_fee := public.calculate_delivery_fee(v_subtotal);
  v_total := greatest(v_subtotal + v_delivery_fee - v_discount, 0);

  update public.orders
  set subtotal = v_subtotal,
      delivery_fee = v_delivery_fee,
      discount_total = v_discount,
      total = v_total,
      items_count = v_items_count,
      coupon_id = v_coupon_id,
      platform_commission = floor(v_subtotal * v_commission_percent / 100.0)::integer
  where id = v_order_id;

  if v_coupon_id is not null and v_discount > 0 then
    insert into public.coupon_redemptions(coupon_id, order_id, user_id, discount_amount)
    values (v_coupon_id, v_order_id, v_user_id, v_discount);
  end if;

  return v_order_id;
exception
  when others then
    if v_order_id is not null then
      delete from public.orders where id = v_order_id;
    end if;
    raise;
end;
$$;

create or replace function public.cancel_order(p_order_id uuid, p_reason text default '')
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
begin
  select * into v_order
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'Commande introuvable';
  end if;

  if not (v_order.user_id = auth.uid() or public.is_admin()) then
    raise exception 'Acces refuse';
  end if;

  if v_order.status in ('delivered', 'cancelled', 'refunded') then
    raise exception 'Commande non annulable';
  end if;

  update public.products p
  set stock = p.stock + oi.quantity
  from public.order_items oi
  where oi.order_id = p_order_id
    and oi.product_id = p.id;

  update public.orders
  set status = 'cancelled',
      cancelled_at = now(),
      metadata = metadata || jsonb_build_object('cancel_reason', coalesce(p_reason, ''))
  where id = p_order_id;
end;
$$;

create or replace function public.assign_courier(p_order_id uuid, p_courier_id uuid default null)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_courier_id uuid := coalesce(p_courier_id, auth.uid());
  v_updated integer;
begin
  if not (public.is_admin() or (public.is_courier() and v_courier_id = auth.uid())) then
    raise exception 'Profil livreur requis';
  end if;

  update public.orders
  set courier_id = v_courier_id,
      courier_accepted_at = now(),
      status = 'courier_assigned'
  where id = p_order_id
    and courier_id is null
    and status in ('paid', 'confirmed');

  get diagnostics v_updated = row_count;
  return v_updated = 1;
end;
$$;

create or replace function public.confirm_delivery(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.orders
  set status = 'delivered',
      delivered_at = now()
  where id = p_order_id
    and status in ('courier_assigned', 'shipping')
    and (courier_id = auth.uid() or public.is_admin());

  if not found then
    raise exception 'Livraison non confirmable';
  end if;
end;
$$;

-- Compatibilite avec l'ancien RPC courier_orders.sql.
create or replace function public.accept_delivery_order(p_order_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.assign_courier(p_order_id, auth.uid());
end;
$$;

-- ============================================================================
-- RLS PRODUCTION
-- ============================================================================

alter table public.platform_settings enable row level security;
alter table public.payments enable row level security;
alter table public.webhook_logs enable row level security;
alter table public.order_status_history enable row level security;
alter table public.audit_logs enable row level security;
alter table public.coupons enable row level security;
alter table public.coupon_redemptions enable row level security;
alter table public.refund_requests enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.reports enable row level security;

drop policy if exists "profiles_select_own_or_admin" on public.profiles;
create policy "profiles_select_own_or_admin"
on public.profiles for select
using (id = auth.uid() or public.is_admin());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles for update
using (id = auth.uid() or public.is_admin())
with check (
  public.is_admin()
  or (
    id = auth.uid()
    and role = (select p.role from public.profiles p where p.id = auth.uid())
    and is_admin = false
  )
);

drop policy if exists "structures_select_public" on public.structures;
create policy "structures_select_public_or_owner"
on public.structures for select
using (
  (is_active = true and deleted_at is null)
  or owner_id = auth.uid()
  or public.is_admin()
);

drop policy if exists "structures_manage_own" on public.structures;
create policy "structures_manage_own"
on public.structures for all
using (owner_id = auth.uid() or public.is_admin())
with check (owner_id = auth.uid() or public.is_admin());

drop policy if exists "products_public_select_active" on public.products;
create policy "products_select_public_vendor_admin"
on public.products for select
using (
  (is_active = true and deleted_at is null)
  or public.owns_structure(structure_id)
  or public.is_admin()
);

drop policy if exists "products_vendor_insert_own" on public.products;
create policy "products_vendor_insert_own"
on public.products for insert
with check (public.owns_structure(structure_id));

drop policy if exists "products_vendor_update_own" on public.products;
create policy "products_vendor_update_own"
on public.products for update
using (public.owns_structure(structure_id))
with check (public.owns_structure(structure_id));

drop policy if exists "products_vendor_delete_own" on public.products;
create policy "products_vendor_delete_own"
on public.products for delete
using (public.owns_structure(structure_id));

drop policy if exists "orders_select_own_courier_admin" on public.orders;
drop policy if exists "orders_courier_select_available_or_own" on public.orders;
create policy "orders_select_by_role"
on public.orders for select
using (
  user_id = auth.uid()
  or courier_id = auth.uid()
  or public.is_admin()
  or (
    public.is_courier()
    and courier_id is null
    and status in ('paid', 'confirmed')
  )
  or exists (
    select 1
    from public.order_items oi
    join public.products p on p.id = oi.product_id
    join public.structures s on s.id = p.structure_id
    where oi.order_id = orders.id
      and s.owner_id = auth.uid()
  )
);

drop policy if exists "orders_insert_own" on public.orders;
create policy "orders_insert_service_or_admin"
on public.orders for insert
with check (user_id = auth.uid() or public.is_admin());

drop policy if exists "orders_update_own_or_admin" on public.orders;
create policy "orders_update_admin_courier_limited"
on public.orders for update
using (
  public.is_admin()
  or courier_id = auth.uid()
  or user_id = auth.uid()
)
with check (
  public.is_admin()
  or courier_id = auth.uid()
  or user_id = auth.uid()
);

drop policy if exists "order_items_select_own_order" on public.order_items;
create policy "order_items_select_by_order_access"
on public.order_items for select
using (public.can_access_order(order_id));

drop policy if exists "order_items_insert_own_order" on public.order_items;
create policy "order_items_insert_own_order"
on public.order_items for insert
with check (
  exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and o.user_id = auth.uid()
      and o.status = 'pending_payment'
  )
  or public.is_admin()
);

create policy "payments_select_own_or_admin"
on public.payments for select
using (user_id = auth.uid() or public.is_admin());

create policy "payments_insert_own_or_admin"
on public.payments for insert
with check (user_id = auth.uid() or public.is_admin());

create policy "payments_update_admin_only"
on public.payments for update
using (public.is_admin())
with check (public.is_admin());

create policy "webhook_logs_admin_only"
on public.webhook_logs for all
using (public.is_admin())
with check (public.is_admin());

create policy "order_status_history_select_by_order_access"
on public.order_status_history for select
using (public.can_access_order(order_id) or public.is_admin());

create policy "audit_logs_admin_only"
on public.audit_logs for select
using (public.is_admin());

create policy "platform_settings_public_read"
on public.platform_settings for select
using (true);

create policy "platform_settings_admin_all"
on public.platform_settings for all
using (public.is_admin())
with check (public.is_admin());

create policy "coupons_public_active_read"
on public.coupons for select
using (
  is_active = true
  and (starts_at is null or starts_at <= now())
  and (ends_at is null or ends_at >= now())
);

create policy "coupons_admin_all"
on public.coupons for all
using (public.is_admin())
with check (public.is_admin());

create policy "coupon_redemptions_select_own_admin"
on public.coupon_redemptions for select
using (user_id = auth.uid() or public.is_admin());

create policy "refund_requests_select_own_admin"
on public.refund_requests for select
using (user_id = auth.uid() or public.is_admin());

create policy "refund_requests_insert_own"
on public.refund_requests for insert
with check (user_id = auth.uid());

create policy "refund_requests_update_admin"
on public.refund_requests for update
using (public.is_admin())
with check (public.is_admin());

create policy "conversations_select_participant"
on public.conversations for select
using (
  client_id = auth.uid()
  or vendor_id = auth.uid()
  or courier_id = auth.uid()
  or public.is_admin()
);

create policy "conversations_insert_participant"
on public.conversations for insert
with check (
  client_id = auth.uid()
  or vendor_id = auth.uid()
  or courier_id = auth.uid()
  or public.is_admin()
);

create policy "messages_select_participant"
on public.messages for select
using (
  exists (
    select 1
    from public.conversations c
    where c.id = messages.conversation_id
      and (
        c.client_id = auth.uid()
        or c.vendor_id = auth.uid()
        or c.courier_id = auth.uid()
        or public.is_admin()
      )
  )
);

create policy "messages_insert_participant"
on public.messages for insert
with check (
  sender_id = auth.uid()
  and exists (
    select 1
    from public.conversations c
    where c.id = messages.conversation_id
      and (
        c.client_id = auth.uid()
        or c.vendor_id = auth.uid()
        or c.courier_id = auth.uid()
      )
  )
);

create policy "reports_select_own_or_admin"
on public.reports for select
using (reporter_id = auth.uid() or public.is_admin());

create policy "reports_insert_own"
on public.reports for insert
with check (reporter_id = auth.uid());

create policy "reports_update_admin"
on public.reports for update
using (public.is_admin())
with check (public.is_admin());

-- ============================================================================
-- RECHERCHE / INDEX
-- ============================================================================

create index if not exists products_name_trgm_idx
on public.products using gin (name gin_trgm_ops);

create index if not exists products_description_trgm_idx
on public.products using gin (description gin_trgm_ops);

create index if not exists products_active_category_idx
on public.products(category_id, is_active)
where deleted_at is null;

create index if not exists products_structure_active_idx
on public.products(structure_id, is_active)
where deleted_at is null;

create index if not exists orders_user_created_idx
on public.orders(user_id, created_at desc);

create index if not exists orders_courier_status_idx
on public.orders(courier_id, status, created_at desc);

create index if not exists order_items_structure_idx
on public.order_items(structure_id, created_at desc);

create index if not exists payments_reference_idx
on public.payments(reference);

create index if not exists notifications_user_created_idx
on public.notifications(user_id, created_at desc);

-- ============================================================================
-- DASHBOARD ADMIN / VUES SQL
-- ============================================================================

create or replace view public.admin_sales_summary as
select
  count(*) filter (where status not in ('cancelled')) as orders_count,
  coalesce(sum(total) filter (where status in ('paid', 'confirmed', 'courier_assigned', 'shipping', 'delivered')), 0) as revenue_total,
  coalesce(sum(platform_commission) filter (where status in ('paid', 'confirmed', 'courier_assigned', 'shipping', 'delivered')), 0) as platform_revenue,
  count(*) filter (where status = 'delivered') as delivered_count,
  count(*) filter (where status = 'cancelled') as cancelled_count
from public.orders;

create or replace view public.admin_top_products as
select
  p.id,
  p.name,
  coalesce(sum(oi.quantity), 0) as quantity_sold,
  coalesce(sum(oi.total), 0) as revenue
from public.products p
left join public.order_items oi on oi.product_id = p.id
left join public.orders o on o.id = oi.order_id and o.status <> 'cancelled'
group by p.id, p.name
order by quantity_sold desc, revenue desc;

create or replace view public.admin_vendor_revenues as
select
  s.id as structure_id,
  s.name as structure_name,
  s.owner_id as vendor_id,
  coalesce(sum(oi.total), 0) as revenue,
  coalesce(sum(oi.quantity), 0) as items_sold,
  count(distinct oi.order_id) as orders_count
from public.structures s
left join public.order_items oi on oi.structure_id = s.id
left join public.orders o on o.id = oi.order_id and o.status <> 'cancelled'
group by s.id, s.name, s.owner_id
order by revenue desc;

create or replace view public.admin_courier_activity as
select
  p.id as courier_id,
  trim(coalesce(p.name, '') || ' ' || coalesce(p.surname, '')) as courier_name,
  count(o.id) as assigned_orders,
  count(o.id) filter (where o.status = 'delivered') as delivered_orders,
  count(o.id) filter (where o.status = 'cancelled') as cancelled_orders
from public.profiles p
left join public.orders o on o.courier_id = p.id
where p.role = 'courier'
group by p.id, p.name, p.surname
order by delivered_orders desc;

create or replace view public.monthly_sales_report as
select
  date_trunc('month', created_at)::date as month,
  count(*) as orders_count,
  coalesce(sum(total), 0) as revenue,
  coalesce(sum(platform_commission), 0) as platform_revenue
from public.orders
where status in ('paid', 'confirmed', 'courier_assigned', 'shipping', 'delivered')
group by date_trunc('month', created_at)
order by month desc;

-- ============================================================================
-- STORAGE
-- ============================================================================

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 2097152, array['image/jpeg', 'image/png', 'image/webp']),
  ('products', 'products', true, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('structures', 'structures', true, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('courier-documents', 'courier-documents', false, 5242880, array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "storage_public_read_media" on storage.objects;
create policy "storage_public_read_media"
on storage.objects for select
using (bucket_id in ('avatars', 'products', 'structures'));

drop policy if exists "storage_user_upload_avatar" on storage.objects;
create policy "storage_user_upload_avatar"
on storage.objects for insert
with check (
  bucket_id = 'avatars'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists "storage_user_update_avatar" on storage.objects;
create policy "storage_user_update_avatar"
on storage.objects for update
using (
  bucket_id = 'avatars'
  and auth.uid()::text = (storage.foldername(name))[1]
)
with check (
  bucket_id = 'avatars'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists "storage_vendor_manage_products" on storage.objects;
create policy "storage_vendor_manage_products"
on storage.objects for all
using (
  bucket_id in ('products', 'structures')
  and (
    public.is_admin()
    or exists (
      select 1
      from public.structures s
      where s.owner_id = auth.uid()
        and s.id::text = (storage.foldername(name))[1]
    )
  )
)
with check (
  bucket_id in ('products', 'structures')
  and (
    public.is_admin()
    or exists (
      select 1
      from public.structures s
      where s.owner_id = auth.uid()
        and s.id::text = (storage.foldername(name))[1]
    )
  )
);

drop policy if exists "storage_courier_documents_own" on storage.objects;
create policy "storage_courier_documents_own"
on storage.objects for all
using (
  bucket_id = 'courier-documents'
  and (public.is_admin() or auth.uid()::text = (storage.foldername(name))[1])
)
with check (
  bucket_id = 'courier-documents'
  and (public.is_admin() or auth.uid()::text = (storage.foldername(name))[1])
);

-- ============================================================================
-- REALTIME
-- ============================================================================

do $$
declare
  t text;
begin
  foreach t in array array[
    'orders', 'order_items', 'notifications', 'delivery_locations',
    'messages', 'payments'
  ] loop
    if exists (
      select 1
      from information_schema.tables
      where table_schema = 'public'
        and table_name = t
    )
    and not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

select 'production_backend_sql_ok' as status;
