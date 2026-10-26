-- AML migration 2026-10-24:
--  1) configurable badges + automatic awarding + the first 10 badges
--  2) REAL community counters for the home page (members, online now) with admin settings
-- Idempotent; run once in the Supabase SQL Editor.
begin;

-- Unified admin check.
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

-- ===========================================================================
-- 1. BADGES
-- ===========================================================================
alter table public.badges add column if not exists code text;
alter table public.badges add column if not exists icon_emoji text;
alter table public.badges add column if not exists criteria_type text not null default 'manual';
alter table public.badges add column if not exists criteria_value integer not null default 1;
alter table public.badges add column if not exists is_active boolean not null default true;
alter table public.badges add column if not exists sort_order integer not null default 100;
alter table public.badges add column if not exists updated_at timestamptz not null default now();

alter table public.badges drop constraint if exists badges_criteria_type_check;
alter table public.badges add constraint badges_criteria_type_check
  check (criteria_type in ('manual','profile_complete','posts','comments','predictions',
                           'correct_predictions','connections','tickets','orders','xp'));
alter table public.badges drop constraint if exists badges_criteria_value_check;
alter table public.badges add constraint badges_criteria_value_check check (criteria_value >= 1);
create unique index if not exists badges_code_key on public.badges (code) where code is not null;

-- Admin manages badges; members read their own earned badges.
drop policy if exists aml_admin_all on public.badges;
create policy aml_admin_all on public.badges for all to authenticated
  using (public.aml_is_admin()) with check (public.aml_is_admin());
grant select on public.badges to anon, authenticated;
grant insert, update, delete on public.badges to authenticated;

drop policy if exists user_badges_read_own on public.user_badges;
create policy user_badges_read_own on public.user_badges for select to authenticated
  using (auth.uid() = user_id or public.aml_is_admin());

-- Metric used by each criteria type.
create or replace function public.aml_badge_metric(p_user uuid, p_type text)
returns bigint language plpgsql stable security definer set search_path = public as $$
declare v bigint := 0;
begin
  if p_user is null then return 0; end if;
  case p_type
    when 'profile_complete' then
      select case when coalesce(nullif(p.username,''),'') <> '' and coalesce(nullif(p.first_name,''),'') <> ''
                   and coalesce(nullif(p.last_name,''),'') <> '' and coalesce(nullif(p.city,''),'') <> ''
                  then 1 else 0 end into v from public.profiles p where p.id = p_user;
    when 'posts' then
      select count(*) into v from public.posts where author_id = p_user;
    when 'comments' then
      select count(*) into v from public.comments where author_id = p_user;
    when 'predictions' then
      select count(*) into v from public.user_predictions where user_id = p_user;
    when 'correct_predictions' then
      select count(*) into v from public.user_predictions up
       where up.user_id = p_user
         and exists (select 1 from public.prediction_options po
                      where po.is_correct and po.id in (up.winner_option_id, up.method_option_id, up.round_option_id));
    when 'connections' then
      select count(*) into v from public.follows f1
        join public.follows f2 on f2.follower_id = f1.following_id and f2.following_id = f1.follower_id
       where f1.follower_id = p_user;
    when 'tickets' then
      select count(*) into v from public.user_event_tickets where user_id = p_user and status in ('valid','used');
    when 'orders' then
      select count(*) into v from public.orders
       where user_id = p_user and status in ('paid','processing','shipped','delivered');
    when 'xp' then
      select coalesce(sum(amount), 0) into v from public.xp_transactions where user_id = p_user;
    else
      v := 0;
  end case;
  return coalesce(v, 0);
end $$;

-- Awards every active badge whose condition is met (idempotent). Gives the XP reward once.
create or replace function public.aml_award_badges(p_user uuid)
returns integer language plpgsql security definer set search_path = public as $$
declare b record; v_ins integer; v_new integer := 0;
begin
  if p_user is null then return 0; end if;
  for b in
    select * from public.badges bd
     where bd.is_active and bd.criteria_type <> 'manual'
       and not exists (select 1 from public.user_badges ub where ub.user_id = p_user and ub.badge_id = bd.id)
  loop
    if public.aml_badge_metric(p_user, b.criteria_type) >= b.criteria_value then
      insert into public.user_badges(user_id, badge_id) values (p_user, b.id) on conflict do nothing;
      get diagnostics v_ins = row_count;
      if v_ins > 0 then
        v_new := v_new + 1;
        if coalesce(b.xp_reward, 0) > 0 then
          insert into public.xp_transactions(user_id, amount, reason, reference_type, reference_id)
          values (p_user, b.xp_reward, 'Badge : ' || b.name, 'badge', b.id);
        end if;
        insert into public.notifications(user_id, type, title, body, data)
        values (p_user, 'badge_earned', 'Nouveau badge !', 'Tu as débloqué « ' || b.name || ' ».',
                jsonb_build_object('badge_id', b.id));
      end if;
    end if;
  end loop;
  return v_new;
end $$;

create or replace function public.aml_check_my_badges()
returns integer language sql security definer set search_path = public as $$
  select public.aml_award_badges(auth.uid());
$$;

create or replace function public.aml_my_badge_progress()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(to_jsonb(q) order by q.sort_order, q.name), '[]'::jsonb)
  from (
    select b.id, b.name, b.description, b.icon_emoji, b.icon_url, b.xp_reward,
           b.criteria_type, b.criteria_value, b.sort_order,
           least(public.aml_badge_metric(auth.uid(), b.criteria_type), b.criteria_value)::bigint as current_value,
           (ub.user_id is not null) as earned, ub.earned_at
      from public.badges b
      left join public.user_badges ub on ub.badge_id = b.id and ub.user_id = auth.uid()
     where b.is_active
  ) q;
$$;

revoke all on function public.aml_badge_metric(uuid, text) from public, anon, authenticated;
revoke all on function public.aml_award_badges(uuid) from public, anon, authenticated;
revoke all on function public.aml_check_my_badges() from public, anon;
revoke all on function public.aml_my_badge_progress() from public, anon;
grant execute on function public.aml_check_my_badges() to authenticated;
grant execute on function public.aml_my_badge_progress() to authenticated;

-- Automatic awarding after each relevant action.
create or replace function public.aml_trg_award_badges()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_user uuid;
begin
  if pg_trigger_depth() > 3 then return null; end if;
  begin
    v_user := nullif(to_jsonb(new) ->> TG_ARGV[0], '')::uuid;
    perform public.aml_award_badges(v_user);
  exception when others then
    null; -- badges must never block the action itself
  end;
  return null;
end $$;

drop trigger if exists trg_badges_posts on public.posts;
create trigger trg_badges_posts after insert on public.posts
  for each row execute function public.aml_trg_award_badges('author_id');
drop trigger if exists trg_badges_comments on public.comments;
create trigger trg_badges_comments after insert on public.comments
  for each row execute function public.aml_trg_award_badges('author_id');
drop trigger if exists trg_badges_predictions on public.user_predictions;
create trigger trg_badges_predictions after insert on public.user_predictions
  for each row execute function public.aml_trg_award_badges('user_id');
drop trigger if exists trg_badges_tickets on public.user_event_tickets;
create trigger trg_badges_tickets after insert on public.user_event_tickets
  for each row execute function public.aml_trg_award_badges('user_id');
drop trigger if exists trg_badges_orders on public.orders;
create trigger trg_badges_orders after insert or update of status on public.orders
  for each row execute function public.aml_trg_award_badges('user_id');
drop trigger if exists trg_badges_follows_a on public.follows;
create trigger trg_badges_follows_a after insert on public.follows
  for each row execute function public.aml_trg_award_badges('follower_id');
drop trigger if exists trg_badges_follows_b on public.follows;
create trigger trg_badges_follows_b after insert on public.follows
  for each row execute function public.aml_trg_award_badges('following_id');
drop trigger if exists trg_badges_profiles on public.profiles;
create trigger trg_badges_profiles after insert or update of username, first_name, last_name, city on public.profiles
  for each row execute function public.aml_trg_award_badges('id');
drop trigger if exists trg_badges_xp on public.xp_transactions;
create trigger trg_badges_xp after insert on public.xp_transactions
  for each row execute function public.aml_trg_award_badges('user_id');

-- The first 10 badges (editable afterwards from the admin area).
insert into public.badges (code, name, description, icon_emoji, xp_reward, criteria_type, criteria_value, sort_order) values
  ('welcome',        'Bienvenue chez AML',    'Complète ton profil : nom, pseudo et ville.',        '👋',  20, 'profile_complete',    1,    10),
  ('first_post',     'Première publication', 'Publie ton premier message dans la communauté.',     '✍️', 10, 'posts',               1,    20),
  ('voice',          'Voix de la communauté','Écris 10 commentaires.',                              '💬',  30, 'comments',           10,   30),
  ('first_predict',  'Premier pronostic',    'Envoie ton premier pronostic sur un combat.',         '🎯',  10, 'predictions',        1,    40),
  ('regular',        'Pronostiqueur assidu', 'Envoie 10 pronostics.',                               '🔥',  50, 'predictions',        10,   50),
  ('lynx',           'Œil de lynx',          'Fais 5 pronostics justes.',                           '🦅', 100, 'correct_predictions', 5,    60),
  ('network',        'Réseau AML',           'Crée 5 liens de suivi mutuel.',                       '🤝',  40, 'connections',        5,    70),
  ('first_ticket',   'Premier billet',       'Achète ton premier billet pour un événement.',        '🎟️', 30, 'tickets',             1,    80),
  ('supporter',      'Supporter officiel',   'Passe ta première commande dans la boutique AML.',    '🛍️', 30, 'orders',              1,    90),
  ('legend',         'Légende AML',          'Atteins 1 000 XP.',                                   '👑', 200, 'xp',                  1000, 100)
on conflict (name) do nothing;

-- Admin: re-evaluate every member (after creating a badge or changing a threshold).
create or replace function public.aml_admin_recalculate_badges()
returns integer language plpgsql security definer set search_path = public as $$
declare r record; v integer := 0;
begin
  if coalesce(public.aml_is_admin(), false) is not true then raise exception 'ADMIN_REQUIRED'; end if;
  for r in select id from public.profiles loop
    v := v + public.aml_award_badges(r.id);
  end loop;
  return v;
end $$;
revoke all on function public.aml_admin_recalculate_badges() from public, anon;
grant execute on function public.aml_admin_recalculate_badges() to authenticated;

-- Backfill: members who already meet a condition get their badge now.
select public.aml_award_badges(p.id) from public.profiles p;

-- ===========================================================================
-- 2. REAL community counters (members registered, members online now)
-- ===========================================================================
alter table public.profiles add column if not exists last_seen_at timestamptz;
create index if not exists profiles_last_seen_idx on public.profiles (last_seen_at desc);

create or replace function public.aml_touch_presence()
returns void language sql security definer set search_path = public as $$
  update public.profiles set last_seen_at = now()
   where id = auth.uid() and (last_seen_at is null or last_seen_at < now() - interval '60 seconds');
$$;
revoke all on function public.aml_touch_presence() from public, anon;
grant execute on function public.aml_touch_presence() to authenticated;

create or replace function public.aml_community_stats()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'members', count(*) filter (where is_suspended is distinct from true),
    'online',  count(*) filter (where is_suspended is distinct from true and last_seen_at > now() - interval '5 minutes')
  ) from public.profiles;
$$;
grant execute on function public.aml_community_stats() to anon, authenticated;

-- Home section (visible by default; the admin can hide it or change its settings).
insert into public.app_home_sections (section_key, title, action_label, is_visible, sort_order, content)
values ('community_stats', 'COMMUNAUTÉ AML', null, true, 15,
        '{"show_members":true,"show_online":true,"min_members":0,"min_online":0,"members_label":"membres inscrits","online_label":"en ligne maintenant"}'::jsonb)
on conflict (section_key) do nothing;

notify pgrst, 'reload schema';
commit;
