-- AML migration 2026-10-23:
--  1) prediction trends: working aml_prediction_stats + admin-editable adjustments
--  2) sign-up: the profile is created from the sign-up form data (no second registration)
-- Idempotent; run once in the Supabase SQL Editor.
begin;

-- ---------------------------------------------------------------------------
-- 0. Unified admin check.
-- ---------------------------------------------------------------------------
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
-- 1. Trends. The tendency always showed 0 because aml_prediction_stats was never
--    deployed (it lived in a migration that was not applied). It is created here.
--    Admin adjustments are added to the real picks of the users:
--    - prediction_options.trend_boost        : extra picks for one option
--    - prediction_questions.trend_participants: extra participants
-- ---------------------------------------------------------------------------
alter table public.prediction_options   add column if not exists trend_boost integer not null default 0 check (trend_boost >= 0);
alter table public.prediction_questions add column if not exists trend_participants integer not null default 0 check (trend_participants >= 0);

create or replace function public.aml_prediction_stats(p_prediction_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_real integer := 0;
  v_boost integer := 0;
  result jsonb;
begin
  select count(*) into v_real from public.user_predictions up where up.prediction_id = p_prediction_id;
  select coalesce(q.trend_participants, 0) into v_boost from public.prediction_questions q where q.id = p_prediction_id;

  with opt as (
    select po.id, po.label, po.option_type, coalesce(po.trend_boost, 0) as boost,
           (select count(*) from public.user_predictions up
             where up.prediction_id = po.prediction_id
               and (up.winner_option_id = po.id or up.method_option_id = po.id or up.round_option_id = po.id))::int as real_count
      from public.prediction_options po
     where po.prediction_id = p_prediction_id
  ),
  cnt as (
    select o.*, o.real_count + o.boost as total_count,
           sum(o.real_count + o.boost) over (partition by o.option_type) as group_total
      from opt o
  )
  select jsonb_build_object(
    'participants', v_real + coalesce(v_boost, 0),
    'real_participants', v_real,
    'winner', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'label', label, 'count', total_count,
                 'real_count', real_count, 'boost', boost,
                 'percentage', case when group_total = 0 then 0 else round(total_count * 100.0 / group_total, 1) end)
                 order by total_count desc, label) from cnt where option_type = 'winner'), '[]'::jsonb),
    'method', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'label', label, 'count', total_count,
                 'real_count', real_count, 'boost', boost,
                 'percentage', case when group_total = 0 then 0 else round(total_count * 100.0 / group_total, 1) end)
                 order by total_count desc, label) from cnt where option_type = 'method'), '[]'::jsonb),
    'round', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'label', label, 'count', total_count,
                 'real_count', real_count, 'boost', boost,
                 'percentage', case when group_total = 0 then 0 else round(total_count * 100.0 / group_total, 1) end)
                 order by total_count desc, label) from cnt where option_type = 'round'), '[]'::jsonb)
  ) into result;

  return result;
end $$;
grant execute on function public.aml_prediction_stats(uuid) to anon, authenticated;

drop function if exists public.aml_admin_set_prediction_trends(uuid, integer, jsonb);
create function public.aml_admin_set_prediction_trends(p_prediction_id uuid, p_participants integer, p_boosts jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  if coalesce(public.aml_is_admin(), false) is not true then raise exception 'ADMIN_REQUIRED'; end if;
  if not exists (select 1 from public.prediction_questions where id = p_prediction_id) then
    raise exception 'PREDICTION_NOT_FOUND';
  end if;

  update public.prediction_questions
     set trend_participants = greatest(0, coalesce(p_participants, 0))
   where id = p_prediction_id;

  update public.prediction_options po
     set trend_boost = greatest(0, coalesce((p_boosts ->> po.id::text)::integer, 0))
   where po.prediction_id = p_prediction_id
     and p_boosts is not null
     and jsonb_exists(p_boosts, po.id::text);
end $$;
revoke all on function public.aml_admin_set_prediction_trends(uuid, integer, jsonb) from public, anon;
grant execute on function public.aml_admin_set_prediction_trends(uuid, integer, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Sign-up: create/complete the profile from the form data stored with the account
--    (raw_user_meta_data). Before, with e-mail confirmation the profile stayed empty
--    until the user edited it by hand.
-- ---------------------------------------------------------------------------
create or replace function public.aml_pick_username(p_candidate text, p_user uuid)
returns text language plpgsql stable security definer set search_path = public as $$
declare
  v_base text := lower(regexp_replace(trim(coalesce(p_candidate, '')), '^@+', ''));
  v_try text;
  v_i integer := 0;
begin
  if v_base !~ '^[a-z0-9_.-]{3,24}$' then return null; end if;
  v_try := v_base;
  while exists (select 1 from public.profiles p where lower(p.username) = v_try and p.id <> p_user) and v_i < 25 loop
    v_i := v_i + 1;
    v_try := left(v_base, 19) || (floor(random() * 9000 + 1000))::integer::text;
  end loop;
  return v_try;
end $$;

create or replace function public.aml_fill_profile_from_auth_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  m jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_type text := coalesce(nullif(trim(m ->> 'profile_type'), ''), 'fan');
begin
  begin
    if v_type not in ('fan','fighter','coach','referee','media','organization','other') then v_type := 'fan'; end if;
    insert into public.profiles(id, username, first_name, last_name, phone, city, profile_type)
    values (new.id,
            public.aml_pick_username(m ->> 'username', new.id),
            nullif(trim(m ->> 'first_name'), ''), nullif(trim(m ->> 'last_name'), ''),
            nullif(trim(m ->> 'phone'), ''), nullif(trim(m ->> 'city'), ''), v_type)
    on conflict (id) do update set
      username   = coalesce(nullif(public.profiles.username, ''),   excluded.username),
      first_name = coalesce(nullif(public.profiles.first_name, ''), excluded.first_name),
      last_name  = coalesce(nullif(public.profiles.last_name, ''),  excluded.last_name),
      phone      = coalesce(nullif(public.profiles.phone, ''),      excluded.phone),
      city       = coalesce(nullif(public.profiles.city, ''),       excluded.city),
      profile_type = case when public.profiles.profile_type is null or public.profiles.profile_type = 'fan'
                          then excluded.profile_type else public.profiles.profile_type end;
  exception when others then
    null; -- never block the creation of an account
  end;
  return new;
end $$;

-- Named "zz_" so it runs after any existing profile-creation trigger and only fills empty fields.
drop trigger if exists zz_aml_fill_profile_from_auth_user on auth.users;
create trigger zz_aml_fill_profile_from_auth_user
after insert on auth.users
for each row execute function public.aml_fill_profile_from_auth_user();

-- Backfill: accounts created before this fix whose profile is empty.
insert into public.profiles(id)
select u.id from auth.users u
 where not exists (select 1 from public.profiles p where p.id = u.id)
on conflict (id) do nothing;

do $$
declare r record;
begin
  for r in
    select p.id, u.raw_user_meta_data as m
      from public.profiles p
      join auth.users u on u.id = p.id
     where (p.username is null or p.username = '' or p.first_name is null or p.first_name = '')
       and jsonb_exists(u.raw_user_meta_data, 'username')
  loop
    update public.profiles p set
      username   = coalesce(nullif(p.username, ''),   public.aml_pick_username(r.m ->> 'username', p.id)),
      first_name = coalesce(nullif(p.first_name, ''), nullif(trim(r.m ->> 'first_name'), '')),
      last_name  = coalesce(nullif(p.last_name, ''),  nullif(trim(r.m ->> 'last_name'), '')),
      phone      = coalesce(nullif(p.phone, ''),      nullif(trim(r.m ->> 'phone'), '')),
      city       = coalesce(nullif(p.city, ''),       nullif(trim(r.m ->> 'city'), ''))
    where p.id = r.id;
  end loop;
end $$;

notify pgrst, 'reload schema';
commit;
