-- AML migration 2026-10-22: follow requests that must be accepted.
-- Following someone sends a request; when the other person accepts, both follow each
-- other (mutual). Only mutual followers can exchange private messages, and they are
-- notified of each other's posts. Idempotent; run once in the Supabase SQL Editor.
begin;

-- ---------------------------------------------------------------------------
-- 1. Follow requests
-- ---------------------------------------------------------------------------
create table if not exists public.follow_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  target_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','declined')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  unique (requester_id, target_id),
  check (requester_id <> target_id)
);
create index if not exists follow_requests_target_idx on public.follow_requests (target_id, status, created_at desc);

alter table public.follow_requests enable row level security;
drop policy if exists follow_requests_read_own on public.follow_requests;
create policy follow_requests_read_own on public.follow_requests
  for select to authenticated using (auth.uid() = requester_id or auth.uid() = target_id);
-- No direct writes: everything goes through the functions below.

-- ---------------------------------------------------------------------------
-- 2. Mutual-follow helper
-- ---------------------------------------------------------------------------
create or replace function public.aml_are_connected(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select a is not null and b is not null and a <> b
     and exists (select 1 from public.follows f where f.follower_id = a and f.following_id = b)
     and exists (select 1 from public.follows f where f.follower_id = b and f.following_id = a);
$$;
revoke all on function public.aml_are_connected(uuid, uuid) from public, anon;
grant execute on function public.aml_are_connected(uuid, uuid) to authenticated;

-- Display name helper (never fails).
create or replace function public.aml_display_name(p_user uuid)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(nullif(trim(concat_ws(' ', p.first_name, p.last_name)), ''),
                  nullif(p.display_name, ''), nullif(p.username, ''), 'Un membre AML')
    from public.profiles p where p.id = p_user;
$$;
revoke all on function public.aml_display_name(uuid) from public, anon;
grant execute on function public.aml_display_name(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Functions used by the app
-- ---------------------------------------------------------------------------
drop function if exists public.aml_respond_follow_request(uuid, boolean);
create function public.aml_respond_follow_request(p_request_id uuid, p_accept boolean)
returns text language plpgsql security definer set search_path = public as $$
declare v_req public.follow_requests%rowtype;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into v_req from public.follow_requests where id = p_request_id for update;
  if not found then raise exception 'REQUEST_NOT_FOUND'; end if;
  if v_req.target_id <> auth.uid() then raise exception 'FORBIDDEN'; end if;
  if v_req.status <> 'pending' then return v_req.status; end if;

  if p_accept then
    insert into public.follows(follower_id, following_id)
    values (v_req.requester_id, v_req.target_id), (v_req.target_id, v_req.requester_id)
    on conflict do nothing;
    update public.follow_requests set status = 'accepted', responded_at = now() where id = v_req.id;
    insert into public.notifications(user_id, actor_id, type, title, body, data)
    values (v_req.requester_id, v_req.target_id, 'follow_accepted', 'Demande acceptée',
            public.aml_display_name(v_req.target_id) || ' a accepté ta demande. Vous pouvez maintenant vous écrire.',
            jsonb_build_object('user_id', v_req.target_id));
  else
    update public.follow_requests set status = 'declined', responded_at = now() where id = v_req.id;
  end if;

  update public.notifications set is_read = true, read_at = coalesce(read_at, now())
   where user_id = v_req.target_id and type = 'follow_request' and data->>'request_id' = v_req.id::text;
  return case when p_accept then 'accepted' else 'declined' end;
end $$;

drop function if exists public.aml_follow_request(uuid);
create function public.aml_follow_request(p_target uuid)
returns text language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_req uuid;
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_target is null or p_target = v_me then raise exception 'INVALID_TARGET'; end if;
  if not exists (select 1 from public.profiles p where p.id = p_target and p.is_suspended is distinct from true) then
    raise exception 'USER_NOT_FOUND';
  end if;
  if public.aml_are_connected(v_me, p_target) then return 'connected'; end if;

  -- The other person already asked to follow me: accepting is enough.
  select r.id into v_req from public.follow_requests r
   where r.requester_id = p_target and r.target_id = v_me and r.status = 'pending';
  if v_req is not null then
    perform public.aml_respond_follow_request(v_req, true);
    return 'connected';
  end if;

  v_req := null;
  insert into public.follow_requests(requester_id, target_id, status)
  values (v_me, p_target, 'pending')
  on conflict (requester_id, target_id) do update
     set status = 'pending', created_at = now(), responded_at = null
   where public.follow_requests.status = 'accepted'
      or public.follow_requests.responded_at < now() - interval '7 days'
  returning id into v_req;

  if v_req is not null then
    insert into public.notifications(user_id, actor_id, type, title, body, data)
    values (p_target, v_me, 'follow_request', 'Demande de suivi',
            public.aml_display_name(v_me) || ' souhaite te suivre.',
            jsonb_build_object('request_id', v_req, 'requester_id', v_me));
  end if;
  return 'pending_out';
end $$;

drop function if exists public.aml_cancel_follow_request(uuid);
create function public.aml_cancel_follow_request(p_target uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_req uuid;
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  select r.id into v_req from public.follow_requests r
   where r.requester_id = v_me and r.target_id = p_target and r.status = 'pending';
  if v_req is null then return; end if;
  delete from public.follow_requests where id = v_req;
  delete from public.notifications where type = 'follow_request' and data->>'request_id' = v_req::text;
end $$;

drop function if exists public.aml_remove_connection(uuid);
create function public.aml_remove_connection(p_other uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  delete from public.follows
   where (follower_id = v_me and following_id = p_other) or (follower_id = p_other and following_id = v_me);
  delete from public.follow_requests
   where (requester_id = v_me and target_id = p_other) or (requester_id = p_other and target_id = v_me);
end $$;

drop function if exists public.aml_follow_status(uuid);
create function public.aml_follow_status(p_other uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_req uuid;
begin
  if v_me is null or p_other is null or p_other = v_me then
    return jsonb_build_object('status', 'none');
  end if;
  if public.aml_are_connected(v_me, p_other) then
    return jsonb_build_object('status', 'connected');
  end if;
  select r.id into v_req from public.follow_requests r
   where r.requester_id = p_other and r.target_id = v_me and r.status = 'pending';
  if v_req is not null then return jsonb_build_object('status', 'pending_in', 'request_id', v_req); end if;
  if exists (select 1 from public.follow_requests r
              where r.requester_id = v_me and r.target_id = p_other and r.status = 'pending') then
    return jsonb_build_object('status', 'pending_out');
  end if;
  return jsonb_build_object('status', 'none');
end $$;

drop function if exists public.aml_follow_requests_incoming();
create function public.aml_follow_requests_incoming()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at desc), '[]'::jsonb)
  from (
    select r.id, r.requester_id, r.created_at,
           p.username, p.first_name, p.last_name, p.display_name, p.avatar_url, p.profile_type, p.is_verified
      from public.follow_requests r
      join public.profiles p on p.id = r.requester_id
     where r.target_id = auth.uid() and r.status = 'pending'
     limit 100
  ) q;
$$;

drop function if exists public.aml_connections();
create function public.aml_connections()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(to_jsonb(q) order by q.sort_name), '[]'::jsonb)
  from (
    select p.id, p.username, p.first_name, p.last_name, p.display_name, p.avatar_url, p.profile_type, p.is_verified,
           lower(coalesce(nullif(trim(concat_ws(' ', p.first_name, p.last_name)), ''), p.display_name, p.username, '')) as sort_name
      from public.follows f1
      join public.follows f2 on f2.follower_id = f1.following_id and f2.following_id = f1.follower_id
      join public.profiles p on p.id = f1.following_id
     where f1.follower_id = auth.uid() and p.is_suspended is distinct from true
     limit 500
  ) q;
$$;

do $$
declare r record;
begin
  for r in select p.oid::regprocedure as sig from pg_proc p
           where p.pronamespace = 'public'::regnamespace
             and p.proname in ('aml_respond_follow_request','aml_follow_request','aml_cancel_follow_request',
                               'aml_remove_connection','aml_follow_status','aml_follow_requests_incoming','aml_connections') loop
    execute format('revoke all on function %s from public, anon', r.sig);
    execute format('grant execute on function %s to authenticated', r.sig);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 4. Existing one-way follows become pending requests (the other side must accept).
-- ---------------------------------------------------------------------------
insert into public.follow_requests(requester_id, target_id, status)
select f.follower_id, f.following_id, 'pending'
  from public.follows f
 where not exists (select 1 from public.follows r where r.follower_id = f.following_id and r.following_id = f.follower_id)
on conflict (requester_id, target_id) do nothing;

insert into public.notifications(user_id, actor_id, type, title, body, data)
select fr.target_id, fr.requester_id, 'follow_request', 'Demande de suivi',
       public.aml_display_name(fr.requester_id) || ' souhaite te suivre.',
       jsonb_build_object('request_id', fr.id, 'requester_id', fr.requester_id)
  from public.follow_requests fr
 where fr.status = 'pending'
   and not exists (select 1 from public.notifications n
                    where n.type = 'follow_request' and n.data->>'request_id' = fr.id::text);

delete from public.follows f
 where not exists (select 1 from public.follows r where r.follower_id = f.following_id and r.following_id = f.follower_id);

-- Clients can no longer create or delete follows directly.
drop policy if exists "own follows" on public.follows;
revoke insert, update, delete on public.follows from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. Private messages only between mutual followers.
-- ---------------------------------------------------------------------------
drop policy if exists aml_dm_insert_own on public.direct_messages;
create policy aml_dm_insert_own on public.direct_messages
  for insert to authenticated
  with check (auth.uid() = sender_id and sender_id <> receiver_id and public.aml_are_connected(sender_id, receiver_id));

create or replace function public.aml_send_private_message(p_receiver_id uuid, p_body text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_body text := trim(coalesce(p_body, ''));
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_receiver_id is null or p_receiver_id = v_uid then raise exception 'DESTINATAIRE_INVALIDE'; end if;
  if not public.aml_are_connected(v_uid, p_receiver_id) then raise exception 'NOT_CONNECTED'; end if;
  if char_length(v_body) < 1 or char_length(v_body) > 2000 then raise exception 'MESSAGE_INVALIDE'; end if;

  insert into public.direct_messages(sender_id, receiver_id, body)
  values (v_uid, p_receiver_id, v_body)
  returning id into v_id;

  return jsonb_build_object('id', v_id, 'sender_id', v_uid, 'receiver_id', p_receiver_id,
                            'body', v_body, 'created_at', now(), 'read_at', null);
end $$;
revoke all on function public.aml_send_private_message(uuid, text) from public, anon;
grant execute on function public.aml_send_private_message(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Followers (= mutual followers) are notified of new posts.
-- ---------------------------------------------------------------------------
create or replace function public.aml_notify_followers_new_post()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_name text;
begin
  begin
    if coalesce(new.is_hidden, false) then return new; end if;
    v_name := public.aml_display_name(new.author_id);
    insert into public.notifications(user_id, actor_id, type, title, body, data)
    select f.follower_id, new.author_id, 'new_post', 'Nouvelle publication',
           v_name || ' a publié.',
           jsonb_build_object('post_id', new.id, 'author_id', new.author_id)
      from public.follows f
     where f.following_id = new.author_id
       and f.follower_id <> new.author_id
       and public.aml_are_connected(f.follower_id, new.author_id)
     limit 500;
  exception when others then
    null; -- never block a publication because of notifications
  end;
  return new;
end $$;

drop trigger if exists trg_aml_notify_followers_new_post on public.posts;
create trigger trg_aml_notify_followers_new_post
after insert on public.posts
for each row execute function public.aml_notify_followers_new_post();

-- ---------------------------------------------------------------------------
-- 7. Community feed: follow_status (none / pending_out / pending_in / connected).
--    Also stops exposing hidden posts and followers-only posts to strangers.
-- ---------------------------------------------------------------------------
create or replace function public.aml_community_feed(p_limit integer default 30, p_post_id uuid default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_result jsonb;
begin
  select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at desc), '[]'::jsonb)
    into v_result
  from (
    select
      p.id,
      p.author_id,
      p.content,
      p.created_at,
      jsonb_build_object(
        'id', pr.id, 'username', pr.username, 'first_name', pr.first_name, 'last_name', pr.last_name,
        'city', pr.city, 'profile_type', pr.profile_type, 'avatar_url', pr.avatar_url, 'is_verified', pr.is_verified
      ) as author_profile,
      coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', pm.id, 'media_url', pm.media_url, 'media_type', pm.media_type,
          'storage_path', pm.storage_path, 'created_at', pm.created_at
        ) order by pm.created_at)
        from public.post_media pm where pm.post_id = p.id
      ), '[]'::jsonb) as post_media,
      (select count(*) from public.post_likes pl where pl.post_id = p.id)::integer as like_count,
      (select count(*) from public.comments cm where cm.post_id = p.id)::integer as comment_count,
      exists(select 1 from public.post_likes pl2 where pl2.post_id = p.id and pl2.user_id = v_uid) as liked_by_me,
      public.aml_are_connected(v_uid, p.author_id) as following_author,
      case
        when public.aml_are_connected(v_uid, p.author_id) then 'connected'
        when exists (select 1 from public.follow_requests r
                      where r.requester_id = v_uid and r.target_id = p.author_id and r.status = 'pending') then 'pending_out'
        when exists (select 1 from public.follow_requests r
                      where r.requester_id = p.author_id and r.target_id = v_uid and r.status = 'pending') then 'pending_in'
        else 'none'
      end as follow_status,
      exists(select 1 from public.bookmarks b where b.user_id = v_uid and b.post_id = p.id) as bookmarked_by_me
    from public.posts p
    left join public.profiles pr on pr.id = p.author_id
    where (p_post_id is null or p.id = p_post_id)
      and coalesce(p.is_hidden, false) = false
      and (p.visibility = 'public' or p.author_id = v_uid
           or (p.visibility = 'followers' and public.aml_are_connected(v_uid, p.author_id)))
    order by p.created_at desc
    limit greatest(1, least(coalesce(p_limit, 30), 100))
  ) q;

  return v_result;
end $$;

notify pgrst, 'reload schema';
commit;
