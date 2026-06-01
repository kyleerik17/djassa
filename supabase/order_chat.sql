-- Messagerie client-vendeur liee aux commandes.
-- A executer dans Supabase SQL editor si les tables n'existent pas encore.

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

create unique index if not exists conversations_order_client_vendor_idx
on public.conversations(order_id, client_id, vendor_id, type)
where type = 'client_vendor';

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists messages_conversation_created_idx
on public.messages(conversation_id, created_at);

alter table public.conversations enable row level security;
alter table public.messages enable row level security;

drop policy if exists "conversations_select_participant" on public.conversations;
create policy "conversations_select_participant"
on public.conversations for select
using (
  client_id = auth.uid()
  or vendor_id = auth.uid()
  or courier_id = auth.uid()
  or public.is_admin()
);

drop policy if exists "conversations_insert_participant" on public.conversations;
create policy "conversations_insert_participant"
on public.conversations for insert
with check (
  client_id = auth.uid()
  or vendor_id = auth.uid()
  or courier_id = auth.uid()
  or public.is_admin()
);

drop policy if exists "conversations_update_participant" on public.conversations;
create policy "conversations_update_participant"
on public.conversations for update
using (
  client_id = auth.uid()
  or vendor_id = auth.uid()
  or courier_id = auth.uid()
  or public.is_admin()
)
with check (
  client_id = auth.uid()
  or vendor_id = auth.uid()
  or courier_id = auth.uid()
  or public.is_admin()
);

drop policy if exists "messages_select_participant" on public.messages;
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

drop policy if exists "messages_insert_participant" on public.messages;
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

do $$
begin
  begin
    alter publication supabase_realtime add table public.messages;
  exception
    when duplicate_object then null;
  end;
end $$;
