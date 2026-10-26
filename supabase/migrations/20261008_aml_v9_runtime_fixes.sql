-- AML V9 runtime compatibility fixes.
-- Reuses existing AML tables and keeps business data in Supabase.

-- 1) Community: RPC used by V8, with the existing comments table as source of truth.
create or replace function public.aml_add_comment(
  p_post_id uuid,
  p_body text,
  p_parent_comment_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_comment public.comments%rowtype;
begin
  if v_user is null then
    raise exception 'AUTH_REQUIRED';
  end if;
  if coalesce(trim(p_body), '') = '' then
    raise exception 'COMMENT_EMPTY';
  end if;

  insert into public.comments(post_id, author_id, body, parent_comment_id)
  values (p_post_id, v_user, trim(p_body), p_parent_comment_id)
  returning * into v_comment;

  return to_jsonb(v_comment);
end;
$$;

grant execute on function public.aml_add_comment(uuid, text, uuid) to authenticated;

-- 2) Shop compatibility: some legacy server-side routines refer to
-- products.price_xof while the current AML app writes products.price.
-- Add/synchronize the compatibility field instead of changing the app's
-- current price model.
do $$
begin
  if to_regclass('public.products') is not null
     and not exists (
       select 1 from information_schema.columns
       where table_schema='public' and table_name='products' and column_name='price_xof'
     ) then
    alter table public.products add column price_xof numeric;
  end if;
end $$;

update public.products
set price_xof = price
where price_xof is null;

create or replace function public.aml_sync_product_price_xof()
returns trigger
language plpgsql
as $$
begin
  new.price_xof := new.price;
  return new;
end;
$$;

drop trigger if exists trg_aml_sync_product_price_xof on public.products;
create trigger trg_aml_sync_product_price_xof
before insert or update of price on public.products
for each row execute function public.aml_sync_product_price_xof();

-- 3) Home: ensure the configurable homepage structures exist even when
-- the previous home-config migration was not executed yet.
create table if not exists public.app_home_settings (
  id boolean primary key default true check (id),
  hero_enabled boolean not null default true,
  hero_title text not null default 'African MMA League',
  hero_subtitle text,
  hero_image_url text,
  updated_at timestamptz not null default now()
);

create table if not exists public.app_home_sections (
  id uuid primary key default gen_random_uuid(),
  section_key text not null unique,
  title text not null,
  action_label text,
  is_visible boolean not null default true,
  sort_order integer not null default 100,
  updated_at timestamptz not null default now()
);

insert into public.app_home_settings (id) values (true)
on conflict (id) do nothing;

insert into public.app_home_sections(section_key,title,action_label,is_visible,sort_order) values
('featured_event','ÉVÉNEMENT VEDETTE','Voir les combats',true,10),
('next_fight','PROCHAIN COMBAT','Tous les combats',true,20),
('results','DERNIERS RÉSULTATS','Voir tout',true,30),
('rankings','CLASSEMENTS AML','Classements',true,40),
('fighters','FIGHTERS VEDETTES','Voir les fighters',true,50),
('tv','AML TV','Tout voir',true,60),
('tickets','TICKETS','',true,70),
('shop','AML SHOP','Boutique',true,80)
on conflict (section_key) do nothing;

-- Editable business content for homepage sections.
alter table public.app_home_sections
  add column if not exists description text,
  add column if not exists image_url text,
  add column if not exists content jsonb not null default '{}'::jsonb;

create index if not exists app_home_sections_sort_idx
on public.app_home_sections(sort_order);

-- 4) Keep the existing public-read/admin-write security model.
alter table public.app_home_sections enable row level security;

-- Force PostgREST to refresh its schema cache after this migration.
notify pgrst, 'reload schema';
