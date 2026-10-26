-- AML migration 2026-10-17: admin home RLS fix, shop purchases with credits,
-- automatic prediction for every fight, default home-section settings.
-- Idempotent; run once in the Supabase SQL Editor.
begin;

-- ---------------------------------------------------------------------------
-- 0. Unified admin check (role-based OR legacy owner e-mail).
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
-- 1. Home settings/sections: "new row violates row-level security policy for
--    table app_home_settings" and an empty sections list in the admin screen.
--    Reset EVERY policy on both tables (whatever the live state was).
-- ---------------------------------------------------------------------------
do $$
declare r record;
begin
  for r in select policyname, tablename from pg_policies
            where schemaname = 'public' and tablename in ('app_home_settings','app_home_sections') loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

alter table public.app_home_settings enable row level security;
alter table public.app_home_sections enable row level security;

create policy app_home_settings_public_read on public.app_home_settings for select using (true);
create policy app_home_sections_public_read on public.app_home_sections for select using (true);
create policy app_home_settings_admin_all on public.app_home_settings
  for all to authenticated using (public.aml_is_admin()) with check (public.aml_is_admin());
create policy app_home_sections_admin_all on public.app_home_sections
  for all to authenticated using (public.aml_is_admin()) with check (public.aml_is_admin());

grant select on public.app_home_settings, public.app_home_sections to anon, authenticated;
grant insert, update, delete on public.app_home_settings, public.app_home_sections to authenticated;

-- Default configuration of the configurable home sections (only if still empty).
update public.app_home_sections set content = '{"source":"all","limit":4}'::jsonb
 where section_key = 'results' and content = '{}'::jsonb;
update public.app_home_sections set content = '{"source":"fighters","limit":5}'::jsonb
 where section_key = 'rankings' and content = '{}'::jsonb;

-- ---------------------------------------------------------------------------
-- 2. Shop: pay with AML credits (1 credit = 1 XOF, same rule as tickets).
--    Atomic: stock lock + wallet lock + debit + paid order + ledger entry.
-- ---------------------------------------------------------------------------
alter table public.aml_wallet_ledger drop constraint if exists aml_wallet_ledger_transaction_type_check;
alter table public.aml_wallet_ledger add constraint aml_wallet_ledger_transaction_type_check
  check (transaction_type in ('ticket_purchase','credit_adjustment','xp_conversion','shop_purchase'));

create or replace function public.aml_create_shop_order(
  p_items jsonb, p_shipping_name text, p_shipping_phone text,
  p_shipping_address text, p_shipping_city text, p_payment_method text default 'À confirmer')
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  v_user uuid := auth.uid();
  v_order_id uuid; v_total numeric := 0; v_item jsonb; v_product public.products;
  v_qty integer; v_variant text; v_line numeric;
  v_credits boolean := lower(coalesce(p_payment_method,'')) in ('credits','crédits','credit','crédit');
  v_cost bigint := 0; v_balance bigint := 0;
begin
  if v_user is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'EMPTY_CART';
  end if;
  if coalesce(trim(p_shipping_name),'') = '' or coalesce(trim(p_shipping_phone),'') = ''
     or coalesce(trim(p_shipping_address),'') = '' or coalesce(trim(p_shipping_city),'') = '' then
    raise exception 'SHIPPING_REQUIRED';
  end if;

  for v_item in select value from jsonb_array_elements(p_items) loop
    v_qty := greatest(0, coalesce((v_item->>'quantity')::integer, 0));
    if v_qty <= 0 then raise exception 'INVALID_QUANTITY'; end if;
    select * into v_product from public.products
     where id = (v_item->>'product_id')::uuid and is_active = true for update;
    if v_product.id is null then raise exception 'PRODUCT_UNAVAILABLE'; end if;
    if coalesce(v_product.stock_quantity,0) < v_qty then
      raise exception 'INSUFFICIENT_STOCK:%', v_product.name;
    end if;
    v_line := coalesce(v_product.price, v_product.price_xof, 0) * v_qty;
    if v_line < 0 then raise exception 'INVALID_PRODUCT_PRICE'; end if;
    v_total := v_total + v_line;
  end loop;

  if v_credits then
    v_cost := ceil(v_total)::bigint;
    insert into public.wallet_accounts(user_id, purchased_credits, updated_at)
    values (v_user, 0, now()) on conflict (user_id) do nothing;
    select w.purchased_credits into v_balance from public.wallet_accounts w where w.user_id = v_user for update;
    if coalesce(v_balance,0) < v_cost then raise exception 'INSUFFICIENT_CREDITS'; end if;
  end if;

  insert into public.orders(user_id, status, subtotal, total_amount, currency, shipping_name, shipping_phone,
                            shipping_address, shipping_city, payment_method, payment_status)
  values (v_user, case when v_credits then 'paid' else 'pending' end, v_total, v_total, 'XOF',
          trim(p_shipping_name), trim(p_shipping_phone), trim(p_shipping_address), trim(p_shipping_city),
          case when v_credits then 'credits' else coalesce(nullif(trim(p_payment_method),''),'À confirmer') end,
          case when v_credits then 'paid' else 'pending' end)
  returning id into v_order_id;

  for v_item in select value from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::integer;
    select * into v_product from public.products where id = (v_item->>'product_id')::uuid for update;
    v_line := coalesce(v_product.price, v_product.price_xof, 0) * v_qty;
    v_variant := nullif(v_item->>'variant','');
    insert into public.order_items(order_id, product_id, product_name, quantity, unit_price, line_total, variant)
    values (v_order_id, v_product.id, v_product.name, v_qty,
            coalesce(v_product.price, v_product.price_xof, 0), v_line, v_variant);
    update public.products set stock_quantity = stock_quantity - v_qty where id = v_product.id;
  end loop;

  if v_credits then
    update public.wallet_accounts set purchased_credits = purchased_credits - v_cost, updated_at = now()
     where user_id = v_user;
    insert into public.aml_wallet_ledger(user_id, amount, transaction_type, reference_id, description)
    values (v_user, -v_cost, 'shop_purchase', v_order_id, 'Achat boutique : commande ' || left(v_order_id::text, 8));
    v_balance := v_balance - v_cost;
  end if;

  return jsonb_build_object('order_id', v_order_id, 'total_amount', v_total, 'currency', 'XOF',
           'payment_status', case when v_credits then 'paid' else 'pending' end,
           'credits_spent', v_cost, 'remaining_credits', v_balance);
end $$;

revoke all on function public.aml_create_shop_order(jsonb,text,text,text,text,text) from public, anon;
grant execute on function public.aml_create_shop_order(jsonb,text,text,text,text,text) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. One prediction question per scheduled fight, created automatically
--    (winner A/B, method, round) so users can always predict from the fight page.
-- ---------------------------------------------------------------------------
create or replace function public.aml_ensure_fight_prediction(p_fight_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_fight public.fights%rowtype; v_q uuid; v_name_a text; v_name_b text;
  v_lock timestamptz; v_rounds integer; v_i integer;
begin
  select * into v_fight from public.fights where id = p_fight_id;
  if not found or v_fight.status <> 'scheduled' then return null; end if;

  select pq.id into v_q from public.prediction_questions pq
   where pq.fight_id = p_fight_id order by pq.created_at limit 1;
  if v_q is not null then return v_q; end if;

  select trim(concat_ws(' ', f.first_name, f.last_name)) into v_name_a from public.fighters f where f.id = v_fight.fighter_a_id;
  if coalesce(v_name_a,'') = '' then
    select trim(concat_ws(' ', f.first_name, f.last_name)) into v_name_a from public.external_fighters f where f.id = v_fight.external_fighter_a_id;
  end if;
  select trim(concat_ws(' ', f.first_name, f.last_name)) into v_name_b from public.fighters f where f.id = v_fight.fighter_b_id;
  if coalesce(v_name_b,'') = '' then
    select trim(concat_ws(' ', f.first_name, f.last_name)) into v_name_b from public.external_fighters f where f.id = v_fight.external_fighter_b_id;
  end if;
  if coalesce(v_name_a,'') = '' or coalesce(v_name_b,'') = '' then return null; end if;

  select e.starts_at into v_lock from public.events e where e.id = v_fight.event_id;
  v_rounds := least(greatest(coalesce(v_fight.scheduled_rounds, 3), 1), 5);

  insert into public.prediction_questions(fight_id, title, question_type, status, lock_at)
  values (p_fight_id, v_name_a || ' vs ' || v_name_b, 'winner', 'open', v_lock)
  returning id into v_q;

  insert into public.prediction_options(prediction_id, label, option_type, option_value) values
    (v_q, v_name_a, 'winner', coalesce(v_fight.fighter_a_id, v_fight.external_fighter_a_id)::text),
    (v_q, v_name_b, 'winner', coalesce(v_fight.fighter_b_id, v_fight.external_fighter_b_id)::text),
    (v_q, 'KO / TKO', 'method', 'ko_tko'),
    (v_q, 'Soumission', 'method', 'submission'),
    (v_q, 'Décision', 'method', 'decision');
  for v_i in 1..v_rounds loop
    insert into public.prediction_options(prediction_id, label, option_type, option_value)
    values (v_q, 'Round ' || v_i, 'round', v_i::text);
  end loop;
  return v_q;
end $$;

revoke all on function public.aml_ensure_fight_prediction(uuid) from public, anon;
grant execute on function public.aml_ensure_fight_prediction(uuid) to authenticated;

create or replace function public.aml_trg_fight_prediction()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  begin
    perform public.aml_ensure_fight_prediction(new.id);
  exception when others then
    null; -- never block the creation of a fight
  end;
  return new;
end $$;

drop trigger if exists trg_aml_fight_prediction on public.fights;
create trigger trg_aml_fight_prediction after insert on public.fights
for each row execute function public.aml_trg_fight_prediction();

-- Backfill: every scheduled fight that has no question yet gets one.
select public.aml_ensure_fight_prediction(f.id) from public.fights f where f.status = 'scheduled';

notify pgrst, 'reload schema';
commit;
