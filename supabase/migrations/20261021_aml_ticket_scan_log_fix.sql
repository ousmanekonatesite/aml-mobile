-- AML migration 2026-10-21: fix ticket scanning ("column s.scan_action does not exist").
-- 1) UNDOES the manual "correction de la colonne scan_action" script.
-- 2) Stops depending on the legacy table public.aml_ticket_scans (unknown structure):
--    scans are now logged in a table this migration fully controls: aml_ticket_scan_log.
-- Idempotent; run once in the Supabase SQL Editor.
begin;

-- ---------------------------------------------------------------------------
-- 1. Undo the manual script: remove the constraint and the column it added.
--    The legacy table and all its original columns/rows are left untouched.
-- ---------------------------------------------------------------------------
alter table if exists public.aml_ticket_scans drop constraint if exists aml_ticket_scans_scan_action_check;
alter table if exists public.aml_ticket_scans drop column if exists scan_action;

-- ---------------------------------------------------------------------------
-- 2. Entry/exit state on tickets (idempotent, already present if 20261020 ran).
-- ---------------------------------------------------------------------------
alter table public.user_event_tickets add column if not exists is_inside boolean not null default false;
alter table public.user_event_tickets add column if not exists entry_count integer not null default 0 check (entry_count >= 0);
alter table public.user_event_tickets add column if not exists last_scan_at timestamptz;

-- ---------------------------------------------------------------------------
-- 3. New scan log (own table, known columns).
-- ---------------------------------------------------------------------------
create table if not exists public.aml_ticket_scan_log (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.user_event_tickets(id) on delete cascade,
  event_id uuid references public.events(id) on delete set null,
  scan_action text not null check (scan_action in ('entry','exit')),
  scanned_by uuid references auth.users(id) on delete set null,
  scanned_at timestamptz not null default now()
);
create index if not exists aml_ticket_scan_log_ticket_idx on public.aml_ticket_scan_log (ticket_id, scanned_at desc);
create index if not exists aml_ticket_scan_log_event_idx on public.aml_ticket_scan_log (event_id, scanned_at desc);

alter table public.aml_ticket_scan_log enable row level security;
drop policy if exists aml_ticket_scan_log_staff_read on public.aml_ticket_scan_log;
create policy aml_ticket_scan_log_staff_read on public.aml_ticket_scan_log
  for select to authenticated using (
    public.aml_is_admin() or exists (
      select 1 from public.profiles p
       where p.id = auth.uid() and p.is_suspended is distinct from true
         and p.role in ('admin','super_admin','ticket_supervisor')));

-- Tickets already scanned before the entry/exit model are considered inside the venue.
update public.user_event_tickets
   set is_inside = true, entry_count = greatest(entry_count, 1),
       last_scan_at = coalesce(last_scan_at, checked_at)
 where status = 'used' and entry_count = 0 and is_inside = false;

-- ---------------------------------------------------------------------------
-- 4. Scan function using the new log table.
-- ---------------------------------------------------------------------------
drop function if exists public.aml_redeem_event_ticket(text);
drop function if exists public.aml_redeem_event_ticket(text, text);

create function public.aml_redeem_event_ticket(p_ticket_code text, p_mode text default 'auto')
returns table(ticket_id uuid, event_id uuid, ticket_status text, checked_at timestamptz,
              scan_action text, is_inside boolean, entry_count integer, quantity integer, duplicate boolean)
language plpgsql security definer set search_path to 'public', 'pg_temp' as $$
#variable_conflict use_column
declare
  v_role text;
  v_t public.user_event_tickets%rowtype;
  v_mode text := lower(coalesce(nullif(trim(p_mode), ''), 'auto'));
  v_action text;
  v_now timestamptz := now();
  v_last timestamptz;
  v_last_action text;
begin
  if auth.uid() is null then raise exception 'Authentification requise'; end if;

  select p.role into v_role from public.profiles p
   where p.id = auth.uid() and p.is_suspended is distinct from true;
  if not (coalesce(public.aml_is_admin(), false) or v_role in ('admin','super_admin','ticket_supervisor')) then
    raise exception 'Accès contrôle refusé';
  end if;
  if v_mode not in ('auto','entry','exit') then raise exception 'Mode de contrôle invalide'; end if;

  select t.* into v_t from public.user_event_tickets t
   where t.ticket_code = upper(trim(p_ticket_code)) for update;
  if not found then raise exception 'Ticket inconnu'; end if;
  if v_t.status not in ('valid','used') then raise exception 'Ticket annulé ou remboursé'; end if;

  -- Double scan of the same QR within a few seconds: report the current state, do not toggle.
  select s.scan_action, s.scanned_at into v_last_action, v_last
    from public.aml_ticket_scan_log s where s.ticket_id = v_t.id order by s.scanned_at desc limit 1;
  if v_last is not null and v_now - v_last < interval '6 seconds'
     and (v_mode = 'auto' or v_mode = v_last_action) then
    return query select v_t.id, v_t.event_id, v_t.status, v_last, v_last_action,
                        v_t.is_inside, v_t.entry_count, v_t.quantity, true;
    return;
  end if;

  v_action := case when v_mode = 'auto' then (case when v_t.is_inside then 'exit' else 'entry' end) else v_mode end;
  if v_action = 'entry' and v_t.is_inside then
    raise exception 'Ce billet est déjà dans la salle. Scanne-le en sortie avant de le faire rentrer.';
  end if;
  if v_action = 'exit' and not v_t.is_inside then
    raise exception 'Ce billet n’est pas dans la salle : aucune entrée à clôturer.';
  end if;

  update public.user_event_tickets t
     set status = 'used',
         is_inside = (v_action = 'entry'),
         entry_count = t.entry_count + (case when v_action = 'entry' then 1 else 0 end),
         last_scan_at = v_now, checked_at = v_now, checked_by = auth.uid()
   where t.id = v_t.id;

  insert into public.aml_ticket_scan_log(ticket_id, event_id, scan_action, scanned_by, scanned_at)
  values (v_t.id, v_t.event_id, v_action, auth.uid(), v_now);

  select t.* into v_t from public.user_event_tickets t where t.id = v_t.id;
  return query select v_t.id, v_t.event_id, v_t.status, v_t.checked_at, v_action,
                      v_t.is_inside, v_t.entry_count, v_t.quantity, false;
end $$;

revoke all on function public.aml_redeem_event_ticket(text, text) from public, anon;
grant execute on function public.aml_redeem_event_ticket(text, text) to authenticated;

notify pgrst, 'reload schema';
commit;
