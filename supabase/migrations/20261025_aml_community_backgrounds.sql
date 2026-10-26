-- AML migration 2026-10-25: coloured backgrounds for text-only community posts.
-- Idempotent; run once in the Supabase SQL Editor.
begin;

alter table public.posts add column if not exists background_key text;
alter table public.posts drop constraint if exists posts_background_key_check;
alter table public.posts add constraint posts_background_key_check
  check (background_key is null or background_key ~ '^[a-z0-9_]{2,24}$');

-- Feed: now returns background_key (same filters and follow status as before).
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
