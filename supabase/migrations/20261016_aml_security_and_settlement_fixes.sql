-- AML corrective migration 2026-10-16 (b): security + prediction settlement fixes.
-- Based on the live schema export. Idempotent; run once in the Supabase SQL Editor.
begin;

-- ---------------------------------------------------------------------------
-- 0. Unified admin check: role-based OR the legacy owner e-mail (kept as a
--    fallback so the owner is never locked out; remove it once step 9 is done).
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
-- 1. Profiles: a signed-in user must not be able to change role / xp /
--    is_suspended / is_verified on their own row (direct PostgREST update).
--    SECURITY DEFINER RPCs and the SQL Editor run as the owner, so they pass.
-- ---------------------------------------------------------------------------
create or replace function public.aml_guard_profile_sensitive_columns()
returns trigger language plpgsql as $$
begin
  if current_user in ('anon','authenticated') then
    if tg_op = 'INSERT' then
      new.role := 'fan'; new.xp := 0; new.is_suspended := false; new.is_verified := false;
    elsif new.role is distinct from old.role
       or new.xp is distinct from old.xp
       or new.is_suspended is distinct from old.is_suspended
       or new.is_verified is distinct from old.is_verified then
      raise exception 'FORBIDDEN_PROFILE_FIELD';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_aml_guard_profile_sensitive on public.profiles;
create trigger trg_aml_guard_profile_sensitive
before insert or update on public.profiles
for each row execute function public.aml_guard_profile_sensitive_columns();

-- ---------------------------------------------------------------------------
-- 2. Prediction status: the admin UI and aml_confirm_prediction_result both use
--    'closed', which the CHECK constraint rejected. Allow it.
-- ---------------------------------------------------------------------------
alter table public.prediction_questions drop constraint if exists prediction_questions_status_check;
alter table public.prediction_questions add constraint prediction_questions_status_check
  check (status in ('draft','open','locked','resolved','closed','cancelled'));

-- ---------------------------------------------------------------------------
-- 3. Settlement: xp_transactions is the single source of truth. The old code
--    also did "profiles.xp = xp + v_xp", which made the legacy sync trigger
--    insert a second ledger row (XP doubled). Remove that update.
-- ---------------------------------------------------------------------------
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
    v_winner_correct := v_up.winner_option_id = p_winner_option_id;
    v_method_correct := p_method_option_id is not null and v_up.method_option_id = p_method_option_id;
    v_round_correct  := p_round_option_id  is not null and v_up.round_option_id  = p_round_option_id;
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

-- ---------------------------------------------------------------------------
-- 4. submit_aml_prediction: deployed version lets an option from ANOTHER
--    question pass validation (NULL <> 'winner' is NULL). Replace with the
--    EXISTS-based version from 20261016 (client ignores the return value).
-- ---------------------------------------------------------------------------
drop function if exists public.submit_aml_prediction(uuid, uuid, uuid, uuid);
create function public.submit_aml_prediction(
  p_prediction_id uuid,
  p_winner_option_id uuid,
  p_method_option_id uuid default null,
  p_round_option_id uuid default null
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_user_id uuid := auth.uid();
  v_question public.prediction_questions%rowtype;
begin
  if v_user_id is null then raise exception 'AUTH_REQUIRED'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text || ':' || p_prediction_id::text, 0));

  select * into v_question from public.prediction_questions where id = p_prediction_id for update;
  if not found then raise exception 'PREDICTION_NOT_FOUND'; end if;
  if v_question.status <> 'open' then raise exception 'PREDICTION_CLOSED'; end if;
  if v_question.lock_at is not null and now() >= v_question.lock_at then raise exception 'PREDICTION_LOCKED'; end if;

  if not exists (select 1 from public.prediction_options
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

-- ---------------------------------------------------------------------------
-- 5. Missing RLS policies (found by comparing the live export with the app).
-- ---------------------------------------------------------------------------
-- 5a. The app reads xp_transactions directly (XP screen, wallet, stats) but no
--     SELECT policy existed, so users saw 0 XP.
drop policy if exists "xp own read" on public.xp_transactions;
create policy "xp own read" on public.xp_transactions
  for select to authenticated using (auth.uid() = user_id);

-- 5b. Admin screens write these tables directly; no write policy existed.
drop policy if exists aml_prediction_questions_admin on public.prediction_questions;
create policy aml_prediction_questions_admin on public.prediction_questions
  for all to authenticated using (public.aml_is_admin()) with check (public.aml_is_admin());

drop policy if exists aml_prediction_options_admin on public.prediction_options;
create policy aml_prediction_options_admin on public.prediction_options
  for all to authenticated using (public.aml_is_admin()) with check (public.aml_is_admin());

drop policy if exists aml_xp_rules_admin on public.xp_rules;
create policy aml_xp_rules_admin on public.xp_rules
  for all to authenticated using (public.aml_is_admin()) with check (public.aml_is_admin());

-- 5c. Policy from 20261014_aml_ticket_scan_audit.sql that was never applied.
drop policy if exists ticket_supervisor_read_tickets on public.user_event_tickets;
create policy ticket_supervisor_read_tickets on public.user_event_tickets
  for select to authenticated using (exists (
    select 1 from public.profiles p
     where p.id = auth.uid() and p.is_suspended is distinct from true
       and p.role in ('admin','super_admin','ticket_supervisor')));

-- ---------------------------------------------------------------------------
-- 6. XP -> credit conversion was not recorded in any wallet journal.
-- ---------------------------------------------------------------------------
alter table public.aml_wallet_ledger drop constraint if exists aml_wallet_ledger_transaction_type_check;
alter table public.aml_wallet_ledger add constraint aml_wallet_ledger_transaction_type_check
  check (transaction_type in ('ticket_purchase','credit_adjustment','xp_conversion'));

create or replace function public.aml_convert_xp_to_credit(p_xp integer)
returns table(credits_added bigint, xp_remaining bigint, credit_balance bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := auth.uid(); v_rate integer; v_available bigint; v_credits bigint; v_balance bigint;
begin
  if v_user is null then raise exception 'Authentification requise'; end if;
  perform pg_advisory_xact_lock(hashtext(v_user::text));
  if p_xp is null or p_xp <= 0 then raise exception 'Montant XP invalide'; end if;
  select xp_per_credit into v_rate from public.aml_wallet_settings where id = true;
  if v_rate is null or v_rate <= 0 then raise exception 'Taux de conversion non configuré'; end if;
  select coalesce(sum(amount),0) into v_available from public.xp_transactions where user_id = v_user;
  if v_available < p_xp then raise exception 'Solde XP insuffisant'; end if;
  if p_xp % v_rate <> 0 then raise exception 'Le montant XP doit être un multiple de %', v_rate; end if;
  v_credits := p_xp / v_rate;
  insert into public.wallet_accounts(user_id, purchased_credits, updated_at) values (v_user, v_credits, now())
  on conflict (user_id) do update
    set purchased_credits = public.wallet_accounts.purchased_credits + excluded.purchased_credits, updated_at = now();
  insert into public.xp_transactions(user_id, amount, reason, reference_type)
  values (v_user, -p_xp, 'Conversion XP vers crédit AML', 'wallet_conversion');
  insert into public.aml_wallet_ledger(user_id, amount, transaction_type, description)
  values (v_user, v_credits, 'xp_conversion', 'Conversion de ' || p_xp || ' XP');
  select coalesce(sum(amount),0) into v_available from public.xp_transactions where user_id = v_user;
  select w.purchased_credits into v_balance from public.wallet_accounts w where w.user_id = v_user;
  return query select v_credits, v_available, v_balance;
end $$;

-- ---------------------------------------------------------------------------
-- 7. Redundant legacy trigger (two triggers recomputed profiles.xp per insert).
-- ---------------------------------------------------------------------------
drop trigger if exists trg_aml_sync_profile_xp on public.xp_transactions;

-- ---------------------------------------------------------------------------
-- 8. Function privileges. Supabase grants EXECUTE to anon/authenticated by
--    default; "revoke ... from public" alone does not remove those grants.
-- ---------------------------------------------------------------------------
do $$
declare r record;
begin
  -- Server-only (called by triggers / the CinetPay Edge Function with service_role)
  for r in select p.oid::regprocedure as sig from pg_proc p
           where p.pronamespace = 'public'::regnamespace
             and p.proname in ('aml_award_xp','aml_confirm_wallet_payment') loop
    execute format('revoke all on function %s from public, anon, authenticated', r.sig);
    execute format('grant execute on function %s to service_role', r.sig);
  end loop;

  -- Signed-in users only
  for r in select p.oid::regprocedure as sig from pg_proc p
           where p.pronamespace = 'public'::regnamespace
             and p.proname in (
               'aml_add_comment','aml_admin_adjust_user_balances','aml_admin_delete_user',
               'aml_admin_list_users','aml_admin_prediction_results','aml_admin_set_user_role',
               'aml_admin_set_user_suspended','aml_admin_update_user_profile','aml_buy_event_ticket',
               'aml_confirm_prediction_result','aml_convert_xp_to_credit','aml_create_shop_order',
               'aml_mark_message_thread_read','aml_message_inbox','aml_message_thread',
               'aml_redeem_event_ticket','aml_search_public_profiles','aml_send_private_message',
               'aml_upsert_my_profile','aml_wallet_balance','submit_aml_prediction') loop
    execute format('revoke all on function %s from public, anon', r.sig);
    execute format('grant execute on function %s to authenticated', r.sig);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 9. OPTIONAL (uncomment after reviewing): give the owner a real admin role so
--    is_admin()/is_staff() policies, ticket scanning and every admin screen work
--    without relying on the e-mail fallback.
-- ---------------------------------------------------------------------------
-- update public.profiles p set role = 'super_admin'
--   from auth.users u
--  where u.id = p.id and lower(u.email) = 'idrissjeux1987@gmail.com';

notify pgrst, 'reload schema';
commit;
