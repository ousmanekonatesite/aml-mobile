-- AML: aggregate prediction trends + configurable mobile home presentation.
-- Does not replace any existing AML business tables.

create or replace function public.aml_prediction_stats(p_prediction_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  total integer := 0;
  result jsonb;
begin
  select count(*) into total
  from public.user_predictions up
  where up.prediction_id = p_prediction_id;

  with groups as (
    select po.option_type, po.id, po.label, count(up.id)::int as count
    from public.prediction_options po
    left join public.user_predictions up
      on up.prediction_id = po.prediction_id
     and (up.winner_option_id = po.id or up.method_option_id = po.id or up.round_option_id = po.id)
    where po.prediction_id = p_prediction_id
    group by po.option_type, po.id, po.label
  )
  select jsonb_build_object(
    'participants', total,
    'winner', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'label', label, 'count', count, 'percentage', case when total = 0 then 0 else round((count::numeric * 100) / total, 1) end) order by count desc, label) from groups where option_type = 'winner'), '[]'::jsonb),
    'method', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'label', label, 'count', count, 'percentage', case when total = 0 then 0 else round((count::numeric * 100) / total, 1) end) order by count desc, label) from groups where option_type = 'method'), '[]'::jsonb),
    'round', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'label', label, 'count', count, 'percentage', case when total = 0 then 0 else round((count::numeric * 100) / total, 1) end) order by count desc, label) from groups where option_type = 'round'), '[]'::jsonb)
  ) into result;

  return result;
end;
$$;

grant execute on function public.aml_prediction_stats(uuid) to anon, authenticated;

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

insert into public.app_home_settings (id) values (true) on conflict (id) do nothing;

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

alter table public.app_home_settings enable row level security;
alter table public.app_home_sections enable row level security;

drop policy if exists app_home_settings_public_read on public.app_home_settings;
create policy app_home_settings_public_read on public.app_home_settings for select using (true);
drop policy if exists app_home_sections_public_read on public.app_home_sections;
create policy app_home_sections_public_read on public.app_home_sections for select using (true);

drop policy if exists app_home_settings_admin_write on public.app_home_settings;
create policy app_home_settings_admin_write on public.app_home_settings for all using (public.aml_is_admin()) with check (public.aml_is_admin());
drop policy if exists app_home_sections_admin_write on public.app_home_sections;
create policy app_home_sections_admin_write on public.app_home_sections for all using (public.aml_is_admin()) with check (public.aml_is_admin());

create index if not exists app_home_sections_sort_idx on public.app_home_sections(sort_order);
