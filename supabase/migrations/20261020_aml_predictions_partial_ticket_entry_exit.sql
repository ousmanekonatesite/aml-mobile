-- AML migration 2026-10-20: partial predictions, ticket entry/exit tracking.
-- Idempotent; run once in the Supabase SQL Editor.
begin;

-- ---------------------------------------------------------------------------
-- 0. Make sure the unified admin check exists.
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
-- 1. Predictions: one OR several options (winner / method / round).
--    The previous function rejected anything without a valid winner
--    (INVALID_WINNER_OPTION), which forced users to pick everything.
-- ---------------------------------------------------------------------------
alter table public.prediction_questions drop constraint if exists prediction_questions_status_check;
alter table public.prediction_questions add constraint prediction_questions_status_check
  check (status in ('draft','open','locked','resolved','closed','cancelled'));

drop function if exists public.submit_aml_prediction(uuid, uuid, uuid, uuid);
create function public.submit_aml_prediction(
  p_prediction_id uuid,
  p_winner_option_id uuid default null,
  p_method_option_id uuid default null,
  p_round_option_id uuid default null
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_user_id uuid := auth.uid();
  v_question public.prediction_questions%rowtype;
begin
  if v_user_id is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_winner_option_id is null and p_method_option_id is null and p_round_option_id is null then
    raise exception 'NO_PICK';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text || ':' || p_prediction_id::text, 0));

  select * into v_question from public.prediction_questions where id = p_prediction_id for update;
  if not found then raise exception 'PREDICTION_NOT_FOUND'; end if;
  if v_question.status <> 'open' then raise exception 'PREDICTION_CLOSED'; end if;
  if v_question.lock_at is not null and now() >= v_question.lock_at then raise exception 'PREDICTION_LOCKED'; end if;

  if p_winner_option_id is not null and not exists (select 1 from public.prediction_options
        where id = p_winner_option_id and prediction_id = p_prediction_id and option_type = 'winner')
  then raise exception 'INVALID_WINNER_OPTION'; end if;

  if p_method_option_id is not null and not exists (select 1 from public.prediction_options
        where id = p_method_option_id and prediction_id = p_prediction_id and option_type = 'method')
  then raise exception 'INVALID_METHOD_OPTION'; end if;

  if p_round_option_id is not null and not exists (select 1 from public.prediction_options
        where id = p_round_option_id and prediction_id = p_prediction_id and option_type = 'round')
  then raise exception 'INVALID_ROUND_OPTION'; end if;

  if exists (select 1 from public.user_predictions where user_id = v_user_id and prediction_id = p_prediction_id)
  then raise exception 'ALREADY_PREDICTED'; end if;

  insert into public.user_predictions(user_id, prediction_id, winner_option_id, method_option_id,
                                      round_option_id, submitted_at, xp_awarded)
  values (v_user_id, p_prediction_id, p_winner_option_id, p_method_option_id, p_round_option_id, now(), 0);

  return jsonb_build_object('ok', true, 'prediction_id', p_prediction_id);
end $$;

revoke all on function public.submit_aml_prediction(uuid, uuid, uuid, uuid) from public, anon;
grant execute on function public.submit_aml_prediction(uuid, uuid, uuid, uuid) to authenticated;

-- Settlement: null-safe scoring for partial predictions (a missing pick simply scores nothing).
create or replace function public.aml_confirm_prediction_result(
  p_prediction_id uuid,
  p_winner_option_id uuid,
  p_method_option_id uuid default null,
  p_round_option_id uuid default null
)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_q public.prediction_questions%rowtype;
  v_up record;
  v_winner_correct boolean; v_method_correct boolean; v_round_correct boolean; v_exact_correct boolean;
  v_xp integer;
begin
  if coalesce(public.aml_is_admin(), false) is not true then raise exception 'ADMIN_REQUIRED'; end if;

  select * into v_q from public.prediction_questions where id = p_prediction_id for update;
  if not found then raise exception 'PREDICTION_NOT_FOUND'; end if;
  if v_q.status in ('closed','resolved') or v_q.settled_at is not null then
    raise exception 'PREDICTION_ALREADY_SETTLED';
  end if;

  update public.prediction_options set is_correct = false where prediction_id = p_prediction_id;

  update public.prediction_options set is_correct = true
   where id = p_winner_option_id and prediction_id = p_prediction_id and option_type = 'winner';
  if not found then raise exception 'INVALID_WINNER_OPTION'; end if;

  if p_method_option_id is not null then
    update public.prediction_options set is_correct = true
     where id = p_method_option_id and prediction_id = p_prediction_id and option_type = 'method';
    if not found then raise exception 'INVALID_METHOD_OPTION'; end if;
  end if;

  if p_round_option_id is not null then
    update public.prediction_options set is_correct = true
     where id = p_round_option_id and prediction_id = p_prediction_id and option_type = 'round';
    if not found then raise exception 'INVALID_ROUND_OPTION'; end if;
  end if;

  update public.prediction_questions
     set result_winner_option_id = p_winner_option_id,
         result_method_option_id = p_method_option_id,
         result_round_option_id  = p_round_option_id,
         resolved_at = now(), settled_at = now(), status = 'closed'
   where id = p_prediction_id;

  for v_up in select * from public.user_predictions where prediction_id = p_prediction_id for update loop
    v_winner_correct := coalesce(v_up.winner_option_id = p_winner_option_id, false);
    v_method_correct := coalesce(p_method_option_id is not null and v_up.method_option_id = p_method_option_id, false);
    v_round_correct  := coalesce(p_round_option_id  is not null and v_up.round_option_id  = p_round_option_id, false);
    -- Bonus « score exact » : le pronostic couvre TOUTES les dimensions publiées dans le résultat et elles sont justes.
    v_exact_correct  := v_winner_correct
                        and (p_method_option_id is null or v_method_correct)
                        and (p_round_option_id  is null or v_round_correct);

    v_xp := greatest(0, v_q.xp_participation);
    if v_winner_correct then v_xp := v_xp + greatest(0, v_q.xp_winner); end if;
    if v_method_correct then v_xp := v_xp + greatest(0, v_q.xp_method); end if;
    if v_round_correct  then v_xp := v_xp + greatest(0, v_q.xp_round);  end if;
    if v_exact_correct  then v_xp := v_xp + greatest(0, v_q.xp_exact);  end if;

    if not exists (select 1 from public.xp_award_keys
                    where user_id = v_up.user_id and action_code = 'prediction_result'
                      and reference_id = p_prediction_id::text) then
      insert into public.xp_award_keys(user_id, action_code, reference_id)
      values (v_up.user_id, 'prediction_result', p_prediction_id::text);

      if v_xp <> 0 then
        -- profiles.xp is synchronised by trigger aml_xp_ledger_sync_profile.
        insert into public.xp_transactions(user_id, amount, reason, reference_type, reference_id)
        values (v_up.user_id, v_xp, 'Résultat de pronostic AML', 'prediction', p_prediction_id);
      end if;
    end if;

    update public.user_predictions set xp_awarded = v_xp, scored_at = now() where id = v_up.id;
  end loop;
end $$;

revoke all on function public.aml_confirm_prediction_result(uuid, uuid, uuid, uuid) from public, anon;
grant execute on function public.aml_confirm_prediction_result(uuid, uuid, uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Tickets: a scanned ticket can leave and come back.
--    is_inside = currently in the venue, entry_count = number of entries,
--    every scan is logged in aml_ticket_scans. The app (Mes billets, Contrôle
--    des billets) already reads is_inside / entry_count: without these columns
--    "Mes billets" fails to load.
-- ---------------------------------------------------------------------------
alter table public.user_event_tickets add column if not exists is_inside boolean not null default false;
alter table public.user_event_tickets add column if not exists entry_count integer not null default 0 check (entry_count >= 0);
alter table public.user_event_tickets add column if not exists last_scan_at timestamptz;

create table if not exists public.aml_ticket_scans (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.user_event_tickets(id) on delete cascade,
  event_id uuid references public.events(id) on delete set null,
  scan_action text not null check (scan_action in ('entry','exit')),
  scanned_by uuid references auth.users(id) on delete set null,
  scanned_at timestamptz not null default now()
);
create index if not exists aml_ticket_scans_ticket_idx on public.aml_ticket_scans (ticket_id, scanned_at desc);
create index if not exists aml_ticket_scans_event_idx on public.aml_ticket_scans (event_id, scanned_at desc);

alter table public.aml_ticket_scans enable row level security;
drop policy if exists aml_ticket_scans_staff_read on public.aml_ticket_scans;
create policy aml_ticket_scans_staff_read on public.aml_ticket_scans
  for select to authenticated using (
    public.aml_is_admin() or exists (
      select 1 from public.profiles p
       where p.id = auth.uid() and p.is_suspended is distinct from true
         and p.role in ('admin','super_admin','ticket_supervisor')));

-- Tickets already scanned before this migration are considered inside the venue.
update public.user_event_tickets
   set is_inside = true, entry_count = greatest(entry_count, 1),
       last_scan_at = coalesce(last_scan_at, checked_at)
 where status = 'used' and entry_count = 0;

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
    from public.aml_ticket_scans s where s.ticket_id = v_t.id order by s.scanned_at desc limit 1;
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

  insert into public.aml_ticket_scans(ticket_id, event_id, scan_action, scanned_by, scanned_at)
  values (v_t.id, v_t.event_id, v_action, auth.uid(), v_now);

  select t.* into v_t from public.user_event_tickets t where t.id = v_t.id;
  return query select v_t.id, v_t.event_id, v_t.status, v_t.checked_at, v_action,
                      v_t.is_inside, v_t.entry_count, v_t.quantity, false;
end $$;

revoke all on function public.aml_redeem_event_ticket(text, text) from public, anon;
grant execute on function public.aml_redeem_event_ticket(text, text) to authenticated;

notify pgrst, 'reload schema';
commit;
