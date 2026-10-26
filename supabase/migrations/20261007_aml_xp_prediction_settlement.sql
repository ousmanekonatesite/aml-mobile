-- AML: centralise la validation des pronostics et l'attribution XP.
-- Cette migration réutilise les tables existantes : xp_rules, xp_award_keys,
-- xp_transactions, profiles, prediction_questions, prediction_options et user_predictions.

create or replace function public.aml_confirm_prediction_result(
  p_prediction_id uuid,
  p_winner_option_id uuid,
  p_method_option_id uuid default null,
  p_round_option_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_q public.prediction_questions%rowtype;
  v_up record;
  v_winner_correct boolean;
  v_method_correct boolean;
  v_round_correct boolean;
  v_exact_correct boolean;
  v_xp integer;
  v_award_key text;
begin
  if coalesce(public.aml_is_admin(), false) is not true then
    raise exception 'ADMIN_REQUIRED';
  end if;

  select * into v_q
  from public.prediction_questions
  where id = p_prediction_id
  for update;

  if not found then
    raise exception 'PREDICTION_NOT_FOUND';
  end if;

  if v_q.status = 'closed' or v_q.settled_at is not null then
    raise exception 'PREDICTION_ALREADY_SETTLED';
  end if;

  -- Une seule option gagnante par type. Les options choisies deviennent
  -- également la source de vérité de l'affichage public.
  update public.prediction_options
     set is_correct = false
   where prediction_id = p_prediction_id;

  update public.prediction_options
     set is_correct = true
   where id = p_winner_option_id and prediction_id = p_prediction_id and option_type = 'winner';

  if not found then
    raise exception 'INVALID_WINNER_OPTION';
  end if;

  if p_method_option_id is not null then
    update public.prediction_options
       set is_correct = true
     where id = p_method_option_id and prediction_id = p_prediction_id and option_type = 'method';
    if not found then raise exception 'INVALID_METHOD_OPTION'; end if;
  end if;

  if p_round_option_id is not null then
    update public.prediction_options
       set is_correct = true
     where id = p_round_option_id and prediction_id = p_prediction_id and option_type = 'round';
    if not found then raise exception 'INVALID_ROUND_OPTION'; end if;
  end if;

  update public.prediction_questions
     set result_winner_option_id = p_winner_option_id,
         result_method_option_id = p_method_option_id,
         result_round_option_id = p_round_option_id,
         resolved_at = now(),
         settled_at = now(),
         status = 'closed'
   where id = p_prediction_id;

  for v_up in
    select * from public.user_predictions
    where prediction_id = p_prediction_id
    for update
  loop
    v_winner_correct := v_up.winner_option_id = p_winner_option_id;
    v_method_correct := p_method_option_id is not null
                        and v_up.method_option_id = p_method_option_id;
    v_round_correct := p_round_option_id is not null
                       and v_up.round_option_id = p_round_option_id;
    v_exact_correct := v_winner_correct
                       and (p_method_option_id is null or v_method_correct)
                       and (p_round_option_id is null or v_round_correct);

    v_xp := greatest(0, v_q.xp_participation);
    if v_winner_correct then v_xp := v_xp + greatest(0, v_q.xp_winner); end if;
    if v_method_correct then v_xp := v_xp + greatest(0, v_q.xp_method); end if;
    if v_round_correct then v_xp := v_xp + greatest(0, v_q.xp_round); end if;
    if v_exact_correct then v_xp := v_xp + greatest(0, v_q.xp_exact); end if;

    v_award_key := 'prediction_result';

    if not exists (
      select 1 from public.xp_award_keys
      where user_id = v_up.user_id
        and action_code = v_award_key
        and reference_id = p_prediction_id::text
    ) then
      insert into public.xp_award_keys(user_id, action_code, reference_id)
      values (v_up.user_id, v_award_key, p_prediction_id::text);

      if v_xp <> 0 then
        insert into public.xp_transactions(user_id, amount, reason, reference_type, reference_id)
        values (v_up.user_id, v_xp, 'Résultat de pronostic AML', 'prediction', p_prediction_id);

        update public.profiles
           set xp = coalesce(xp, 0) + v_xp,
               updated_at = now()
         where id = v_up.user_id;
      end if;
    end if;

    update public.user_predictions
       set xp_awarded = v_xp,
           scored_at = now()
     where id = v_up.id;
  end loop;
end;
$$;

revoke all on function public.aml_confirm_prediction_result(uuid, uuid, uuid, uuid) from public;
grant execute on function public.aml_confirm_prediction_result(uuid, uuid, uuid, uuid) to authenticated;
