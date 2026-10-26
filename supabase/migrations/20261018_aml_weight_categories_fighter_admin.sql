-- AML migration 2026-10-18: default weight categories + admin rights to edit
-- fighters, their professional record (fighter_stats), clubs, social links.
-- Idempotent; run once in the Supabase SQL Editor.
begin;

-- Make sure the unified admin check exists (role-based OR legacy owner e-mail).
create or replace function public.aml_is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (
    exists (select 1 from public.profiles p
            where p.id = auth.uid()
              and p.role in ('admin','super_admin')
              and coalesce(p.is_suspended,false) = false)
    or lower(coalesce(auth.email(),'')) = 'idrissjeux1987@gmail.com'
  );
$$;

-- ---------------------------------------------------------------------------
-- 1. Weight categories: the table was empty, so the fight form had nothing to pick.
--    Standard MMA divisions (limit in kg), men and women.
-- ---------------------------------------------------------------------------
insert into public.weight_categories (name, gender, min_weight_kg, max_weight_kg) values
  ('Poids mouche',        'male',   52.2,  56.7),
  ('Poids coq',           'male',   56.7,  61.2),
  ('Poids plume',         'male',   61.2,  65.8),
  ('Poids léger',         'male',   65.8,  70.3),
  ('Poids mi-moyen',      'male',   70.3,  77.1),
  ('Poids moyen',         'male',   77.1,  83.9),
  ('Poids mi-lourd',      'male',   83.9,  93.0),
  ('Poids lourd',         'male',   93.0, 120.2),
  ('Poids paille (F)',    'female', 47.6,  52.2),
  ('Poids mouche (F)',    'female', 52.2,  56.7),
  ('Poids coq (F)',       'female', 56.7,  61.2),
  ('Poids plume (F)',     'female', 61.2,  65.8)
on conflict (name) do nothing;

-- ---------------------------------------------------------------------------
-- 2. Admin can create/edit categories, clubs, fighters, pro records, social links.
--    (RLS stays on; these policies are added next to the existing public-read ones.)
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['weight_categories','clubs','fighters','fighter_stats','fighter_social_links'] loop
    execute format('drop policy if exists aml_admin_all on public.%I', t);
    execute format('create policy aml_admin_all on public.%I for all to authenticated using (public.aml_is_admin()) with check (public.aml_is_admin())', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end $$;

-- Public read of social links and clubs (shown on the fighter profile).
drop policy if exists aml_public_read on public.fighter_social_links;
create policy aml_public_read on public.fighter_social_links for select using (true);
drop policy if exists aml_public_read on public.clubs;
create policy aml_public_read on public.clubs for select using (true);

notify pgrst, 'reload schema';
commit;
