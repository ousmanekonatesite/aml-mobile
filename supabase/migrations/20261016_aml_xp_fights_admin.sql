-- AML migration 2026-10-16 (c): admin role, single XP source, fight competitions, home section.
-- Independent from the previous security migration; idempotent; run once in the SQL Editor.
begin;

-- ---------------------------------------------------------------------------
-- 1. Admin role for the owner account (fixes "Accès contrôle refusé" and makes
--    is_admin()/is_staff() policies work for every admin screen).
--    Runs as the SQL Editor owner, so it is not blocked by any profile guard.
-- ---------------------------------------------------------------------------
do $$
declare v_count integer;
begin
  update public.profiles p set role = 'super_admin'
    from auth.users u
   where u.id = p.id and lower(u.email) = 'idrissjeux1987@gmail.com';
  get diagnostics v_count = row_count;
  if v_count = 0 then
    raise notice 'Aucun profil trouvé pour cet email : connecte-toi une fois dans l’app puis relance cette requête.';
  end if;
end $$;

-- Ticket scan: accept DB admins as well as ticket supervisors.
create or replace function public.aml_redeem_event_ticket(p_ticket_code text)
returns table(ticket_id uuid, event_id uuid, ticket_status text, checked_at timestamp with time zone)
language plpgsql security definer set search_path to 'public', 'pg_temp' as $$
declare v_role text; v_ticket public.user_event_tickets%rowtype; v_checked_at timestamptz := now();
begin
  if auth.uid() is null then raise exception 'Authentification requise'; end if;
  select p.role into v_role from public.profiles p
   where p.id = auth.uid() and p.is_suspended is distinct from true;
  if not (coalesce(public.aml_is_admin(), false) or v_role in ('admin','super_admin','ticket_supervisor')) then
    raise exception 'Accès contrôle refusé';
  end if;
  select t.* into v_ticket from public.user_event_tickets t
   where t.ticket_code = trim(p_ticket_code) for update;
  if not found then raise exception 'Ticket inconnu'; end if;
  if v_ticket.status <> 'valid' then raise exception 'Ticket déjà utilisé, annulé ou invalide'; end if;
  update public.user_event_tickets t
     set status = 'used', checked_at = v_checked_at, checked_by = auth.uid()
   where t.id = v_ticket.id;
  return query select v_ticket.id, v_ticket.event_id, 'used'::text, v_checked_at;
end $$;

-- Ticket registry must be readable by supervisors (policy was never applied).
drop policy if exists ticket_supervisor_read_tickets on public.user_event_tickets;
create policy ticket_supervisor_read_tickets on public.user_event_tickets
  for select to authenticated using (exists (
    select 1 from public.profiles p
     where p.id = auth.uid() and p.is_suspended is distinct from true
       and p.role in ('admin','super_admin','ticket_supervisor')));

-- ---------------------------------------------------------------------------
-- 2. One XP everywhere: the ledger (xp_transactions) is the only source.
--    The leaderboard already used it; the wallet/badges screens read the table
--    directly, which RLS blocked (no SELECT policy) -> they displayed 0.
-- ---------------------------------------------------------------------------
create or replace function public.aml_my_xp()
returns bigint language sql stable security definer set search_path = public as $$
  select coalesce(sum(t.amount), 0)::bigint from public.xp_transactions t where t.user_id = auth.uid();
$$;
revoke all on function public.aml_my_xp() from public, anon;
grant execute on function public.aml_my_xp() to authenticated;

drop policy if exists "xp own read" on public.xp_transactions;
create policy "xp own read" on public.xp_transactions
  for select to authenticated using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 3. Fights by competition. The in-app event form never saved competition_id,
--    so AML events had NULL and the "African MMA League" filter found nothing.
-- ---------------------------------------------------------------------------
update public.competitions set is_aml = true
 where is_aml = false and (lower(slug) = 'aml' or lower(name) like '%african mma league%');

-- External fights: take the competition of their external fighters.
update public.events e set competition_id = x.competition_id
  from (
    select distinct on (f.event_id) f.event_id, ef.competition_id
      from public.fights f
      join public.external_fighters ef on ef.id = f.external_fighter_a_id
     where f.event_id is not null
     order by f.event_id
  ) x
 where e.id = x.event_id and e.competition_id is null;

-- Everything else created in the app is an AML card.
update public.events e set competition_id = (
    select c.id from public.competitions c where c.is_aml order by c.is_active desc, c.created_at limit 1)
 where e.competition_id is null;

create or replace function public.aml_default_event_competition()
returns trigger language plpgsql as $$
begin
  if new.competition_id is null then
    select c.id into new.competition_id from public.competitions c
     where c.is_aml order by c.is_active desc, c.created_at limit 1;
  end if;
  return new;
end $$;

drop trigger if exists trg_aml_default_event_competition on public.events;
create trigger trg_aml_default_event_competition
before insert on public.events
for each row execute function public.aml_default_event_competition();

create index if not exists events_starts_at_idx on public.events (starts_at desc);

-- ---------------------------------------------------------------------------
-- 4. Home "Prochain combat" section is configurable (mode / event / competition / limit).
-- ---------------------------------------------------------------------------
insert into public.app_home_sections (section_key, title, action_label, is_visible, sort_order, content)
values ('next_fight', 'PROCHAIN COMBAT', 'Tous les combats', true, 20, '{"mode":"auto","limit":1}'::jsonb)
on conflict (section_key) do update
   set content = case when public.app_home_sections.content = '{}'::jsonb
                      then excluded.content else public.app_home_sections.content end;

notify pgrst, 'reload schema';
commit;
