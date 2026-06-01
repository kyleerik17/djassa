-- DJASSA / LE Djassa - Backoffice articles
-- À exécuter dans Supabase > SQL Editor > Run.
-- Ensuite, remplace l'email en bas du fichier par ton email admin et relance seulement l'UPDATE.

alter table public.profiles
add column if not exists is_admin boolean not null default false;

-- Fonction utilisée par les policies RLS.
-- SECURITY DEFINER évite les problèmes de lecture de profiles depuis une policy.
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
return coalesce(
    (
      select p.is_admin
      from public.profiles p
      where p.id = auth.uid()
      limit 1
    ),
    false
  );

-- Sécurité: un client connecté ne doit jamais pouvoir se donner is_admin lui-même
-- via la policy "profiles_update_own" existante.
create or replace function public.prevent_self_admin_escalation()
returns trigger
language plpgsql
security definer
set search_path = public
as '
begin
  if auth.uid() is not null
     and old.is_admin is distinct from new.is_admin
     and not public.is_admin()
  then
    raise exception ''Modification du role admin interdite'';
  end if;

  return new;
end;
';

drop trigger if exists profiles_prevent_self_admin_escalation on public.profiles;
create trigger profiles_prevent_self_admin_escalation
before update on public.profiles
for each row execute function public.prevent_self_admin_escalation();

-- Lecture complète du catalogue pour les admins, en plus de la lecture publique active.
drop policy if exists "categories_admin_select_all" on public.categories;
create policy "categories_admin_select_all"
on public.categories
for select
using (public.is_admin());

drop policy if exists "products_admin_select_all" on public.products;
create policy "products_admin_select_all"
on public.products
for select
using (public.is_admin());

-- Gestion complète des rayons / catégories depuis le backoffice admin.
drop policy if exists "categories_admin_insert" on public.categories;
create policy "categories_admin_insert"
on public.categories
for insert
with check (public.is_admin());

drop policy if exists "categories_admin_update" on public.categories;
create policy "categories_admin_update"
on public.categories
for update
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "categories_admin_delete" on public.categories;
create policy "categories_admin_delete"
on public.categories
for delete
using (public.is_admin());

-- Gestion complète des articles / produits.
drop policy if exists "products_admin_insert" on public.products;
create policy "products_admin_insert"
on public.products
for insert
with check (public.is_admin());

drop policy if exists "products_admin_update" on public.products;
create policy "products_admin_update"
on public.products
for update
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "products_admin_delete" on public.products;
create policy "products_admin_delete"
on public.products
for delete
using (public.is_admin());

-- À faire une seule fois pour ton compte admin:
-- 1) Inscris-toi / connecte-toi dans l'app
-- 2) Mets ton vrai email ci-dessous
-- 3) Exécute l'UPDATE
--
-- update public.profiles
-- set is_admin = true
-- where email = 'ton-email@example.com';

select 'admin_backoffice_sql_ok' as status;
