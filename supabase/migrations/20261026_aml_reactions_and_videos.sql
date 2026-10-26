-- AML migration 2026-10-26: emoji reactions + community videos (3 minutes maximum).
-- Idempotent; run once in the Supabase SQL Editor.
begin;

-- ---------------------------------------------------------------------------
-- 1. Reactions: one reaction per member and post (love, like, fire, haha, wow, sad, clap, punch).
--    Replaces the single "like". Existing likes become the "love" reaction.
-- ---------------------------------------------------------------------------
create table if not exists public.post_reactions (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reaction text not null check (reaction in ('love','like','fire','haha','wow','sad','clap','punch')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index if not exists post_reactions_post_idx on public.post_reactions (post_id, reaction);

alter table public.post_reactions enable row level security;
drop policy if exists post_reactions_read on public.post_reactions;
create policy post_reactions_read on public.post_reactions for select using (true);
drop policy if exists post_reactions_insert_own on public.post_reactions;
create policy post_reactions_insert_own on public.post_reactions for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists post_reactions_update_own on public.post_reactions;
create policy post_reactions_update_own on public.post_reactions for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists post_reactions_delete_own on public.post_reactions;
create policy post_reactions_delete_own on public.post_reactions for delete to authenticated using (auth.uid() = user_id);
grant select on public.post_reactions to anon, authenticated;
grant insert, update, delete on public.post_reactions to authenticated;

insert into public.post_reactions (post_id, user_id, reaction, created_at)
select l.post_id, l.user_id, 'love', l.created_at from public.post_likes l
on conflict (post_id, user_id) do nothing;

create or replace view public.aml_community_post_stats as
 select p.id as post_id,
        count(distinct r.user_id) as like_count,
        count(distinct c.id) as comment_count,
        count(distinct b.user_id) as bookmark_count
   from public.posts p
   left join public.post_reactions r on r.post_id = p.id
   left join public.comments c on c.post_id = p.id
   left join public.bookmarks b on b.post_id = p.id
  group by p.id;

-- ---------------------------------------------------------------------------
-- 2. Videos: duration stored with the media, 3 minutes maximum enforced by the database.
-- ---------------------------------------------------------------------------
alter table public.post_media add column if not exists duration_seconds integer;
alter table public.post_media drop constraint if exists post_media_video_duration_check;
alter table public.post_media add constraint post_media_video_duration_check
  check (media_type <> 'video' or (duration_seconds is not null and duration_seconds between 1 and 180)) not valid;

-- The community bucket accepts videos (50 MB per file, the default Supabase limit).
update storage.buckets set file_size_limit = 52428800, allowed_mime_types = null where id = 'community-media';

-- ---------------------------------------------------------------------------
-- 3. Feed: reactions summary, my reaction and video duration.
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
      p.background_key,
      p.created_at,
      jsonb_build_object(
        'id', pr.id, 'username', pr.username, 'first_name', pr.first_name, 'last_name', pr.last_name,
        'city', pr.city, 'profile_type', pr.profile_type, 'avatar_url', pr.avatar_url, 'is_verified', pr.is_verified
      ) as author_profile,
      coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', pm.id, 'media_url', pm.media_url, 'media_type', pm.media_type,
          'storage_path', pm.storage_path, 'duration_seconds', pm.duration_seconds, 'created_at', pm.created_at
        ) order by pm.created_at)
        from public.post_media pm where pm.post_id = p.id
      ), '[]'::jsonb) as post_media,
      (select count(*) from public.post_reactions pr where pr.post_id = p.id)::integer as like_count,
      (select count(*) from public.comments cm where cm.post_id = p.id)::integer as comment_count,
      exists(select 1 from public.post_reactions pr2 where pr2.post_id = p.id and pr2.user_id = v_uid) as liked_by_me,
      (select pr3.reaction from public.post_reactions pr3 where pr3.post_id = p.id and pr3.user_id = v_uid) as my_reaction,
      coalesce((select jsonb_object_agg(x.reaction, x.n)
                  from (select r.reaction, count(*)::integer as n
                          from public.post_reactions r where r.post_id = p.id group by r.reaction) x), '{}'::jsonb) as reactions,
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
