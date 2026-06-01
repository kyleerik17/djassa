-- Patch paiement GeniusPay
-- A executer dans Supabase SQL Editor si les logs indiquent:
-- "Could not find the 'checkout_url' column of 'payments' in the schema cache".

alter table public.payments
  add column if not exists provider_payment_id text,
  add column if not exists status_message text not null default '',
  add column if not exists checkout_url text,
  add column if not exists webhook_url text,
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists updated_at timestamptz not null default now();

alter table public.payments drop constraint if exists payments_status_check;
alter table public.payments
  add constraint payments_status_check check (
    status in ('pending', 'processing', 'completed', 'paid', 'failed', 'cancelled', 'refunded')
  );

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

drop trigger if exists payments_apply_status on public.payments;
create trigger payments_apply_status
after update of status on public.payments
for each row execute function public.apply_payment_status_to_order();

create index if not exists payments_order_id_idx on public.payments(order_id);
create index if not exists payments_reference_idx on public.payments(reference);

notify pgrst, 'reload schema';
