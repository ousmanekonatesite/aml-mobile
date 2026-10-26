
-- AML: XP configurable + validation des pronostics.
-- Les valeurs restent modifiables depuis l'administration.
create table if not exists public.aml_xp_rules (
  action_code text primary key,
  label text not null,
  xp_amount integer not null default 0 check (xp_amount >= 0),
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.aml_xp_rules(action_code,label,xp_amount) values
 ('post_created','Publication',10),
 ('comment_created','Commentaire',5)
on conflict (action_code) do nothing;

alter table public.xp_transactions
  add column if not exists source_type text,
  add column if not exists source_id text;

create unique index if not exists xp_transactions_source_uidx
  on public.xp_transactions(user_id, source_type, source_id)
  where source_type is not null and source_id is not null;

create or replace function public.aml_award_community_xp()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_xp integer;
  v_user uuid;
  v_source text;
begin
  v_user := new.author_id;
  v_source := case when TG_TABLE_NAME = 'posts' then 'post_created' else 'comment_created' end;
  select xp_amount into v_xp from public.aml_xp_rules
   where action_code = v_source and is_active = true;
  if coalesce(v_xp,0) > 0 and v_user is not null then
    insert into public.xp_transactions(user_id, amount, source_type, source_id)
    values(v_user, v_xp, v_source, new.id::text)
    on conflict do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_aml_post_xp on public.posts;
create trigger trg_aml_post_xp after insert on public.posts
for each row execute function public.aml_award_community_xp();

drop trigger if exists trg_aml_comment_xp on public.comments;
create trigger trg_aml_comment_xp after insert on public.comments
for each row execute function public.aml_award_community_xp();

create or replace function public.aml_confirm_prediction_result(
  p_prediction_id uuid,
  p_winner_option_id uuid,
  p_method_option_id uuid default null,
  p_round_option_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  q record;
  up record;
  v_winner boolean;
  v_method boolean;
  v_round boolean;
  v_exact boolean;
  v_total integer;
begin
  if not public.aml_is_admin() then
    raise exception 'ADMIN_REQUIRED';
  end if;

  select * into q from public.prediction_questions
   where id = p_prediction_id
   for update;

  if not found then raise exception 'PREDICTION_NOT_FOUND'; end if;

  update public.prediction_options
    set is_correct = (id = p_winner_option_id)
    where prediction_id = p_prediction_id and option_type = 'winner';

  if p_method_option_id is not null then
    update public.prediction_options
      set is_correct = (id = p_method_option_id)
      where prediction_id = p_prediction_id and option_type = 'method';
  end if;

  if p_round_option_id is not null then
    update public.prediction_options
      set is_correct = (id = p_round_option_id)
      where prediction_id = p_prediction_id and option_type = 'round';
  end if;

  for up in
    select * from public.user_predictions where prediction_id = p_prediction_id
  loop
    v_winner := up.winner_option_id = p_winner_option_id;
    v_method := p_method_option_id is not null and up.method_option_id = p_method_option_id;
    v_round := p_round_option_id is not null and up.round_option_id = p_round_option_id;
    v_exact := v_winner and (p_method_option_id is null or v_method)
                     and (p_round_option_id is null or v_round);

    v_total := coalesce(q.xp_participation,0)
             + case when v_winner then coalesce(q.xp_winner,0) else 0 end
             + case when v_method then coalesce(q.xp_method,0) else 0 end
             + case when v_round then coalesce(q.xp_round,0) else 0 end
             + case when v_exact then coalesce(q.xp_exact,0) else 0 end;

    update public.user_predictions
      set xp_awarded = v_total
      where id = up.id;

    insert into public.xp_transactions(user_id, amount, source_type, source_id)
      values(up.user_id, v_total, 'prediction_result', up.id::text)
      on conflict do nothing;
  end loop;

  update public.prediction_questions
    set status = 'closed'
    where id = p_prediction_id;

  return jsonb_build_object('prediction_id',p_prediction_id,'status','closed');
end;
$$;

grant execute on function public.aml_confirm_prediction_result(uuid,uuid,uuid,uuid) to authenticated;
