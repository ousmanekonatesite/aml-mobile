-- XP-to-credit conversion: conversion ratio is editable by authorized admins.
create table if not exists public.aml_wallet_settings (
  id boolean primary key default true check (id),
  xp_per_credit integer not null default 100 check (xp_per_credit > 0),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);
insert into public.aml_wallet_settings(id, xp_per_credit) values (true, 100) on conflict (id) do nothing;
alter table public.aml_wallet_settings enable row level security;
drop policy if exists "Authenticated users can read wallet conversion rate" on public.aml_wallet_settings;
create policy "Authenticated users can read wallet conversion rate" on public.aml_wallet_settings for select to authenticated using (true);
drop policy if exists "Admins manage wallet conversion rate" on public.aml_wallet_settings;
create policy "Admins manage wallet conversion rate" on public.aml_wallet_settings for all to authenticated
using (exists(select 1 from public.profiles p where p.id=auth.uid() and p.is_suspended is distinct from true and p.role in ('admin','super_admin')))
with check (exists(select 1 from public.profiles p where p.id=auth.uid() and p.is_suspended is distinct from true and p.role in ('admin','super_admin')));

create or replace function public.aml_convert_xp_to_credit(p_xp integer)
returns table(credits_added bigint, xp_remaining bigint, credit_balance bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_rate integer;
  v_available bigint;
  v_credits bigint;
  v_balance bigint;
begin
  if v_user is null then raise exception 'Authentification requise'; end if;
  perform pg_advisory_xact_lock(hashtext(v_user::text));
  if p_xp is null or p_xp <= 0 then raise exception 'Montant XP invalide'; end if;
  select xp_per_credit into v_rate from public.aml_wallet_settings where id=true;
  if v_rate is null or v_rate <= 0 then raise exception 'Taux de conversion non configuré'; end if;
  select coalesce(sum(amount),0) into v_available from public.xp_transactions where user_id=v_user;
  if v_available < p_xp then raise exception 'Solde XP insuffisant'; end if;
  if p_xp % v_rate <> 0 then raise exception 'Le montant XP doit être un multiple de %', v_rate; end if;
  v_credits := p_xp / v_rate;
  insert into public.wallet_accounts(user_id,purchased_credits,updated_at) values(v_user,v_credits,now())
  on conflict(user_id) do update set purchased_credits=public.wallet_accounts.purchased_credits + excluded.purchased_credits, updated_at=now();
  insert into public.xp_transactions(user_id,amount,reason,reference_type) values(v_user,-p_xp,'Conversion XP vers crédit AML','wallet_conversion');
  select coalesce(sum(amount),0) into v_available from public.xp_transactions where user_id=v_user;
  select purchased_credits into v_balance from public.wallet_accounts where user_id=v_user;
  return query select v_credits,v_available,v_balance;
end; $$;
revoke all on function public.aml_convert_xp_to_credit(integer) from public;
grant execute on function public.aml_convert_xp_to_credit(integer) to authenticated;

-- In-app ticket checkout paid from AML credits. price_xof is treated as the
-- configured credit price for the first release; admins should set offer prices accordingly.
alter table public.user_event_tickets add column if not exists offer_id uuid references public.event_ticket_offers(id);
alter table public.user_event_tickets add column if not exists amount_credits bigint not null default 0;
create table if not exists public.aml_wallet_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  amount bigint not null,
  transaction_type text not null check (transaction_type in ('ticket_purchase','credit_adjustment')),
  reference_id uuid,
  description text not null,
  created_at timestamptz not null default now()
);
create index if not exists aml_wallet_ledger_user_date_idx on public.aml_wallet_ledger(user_id,created_at desc);
alter table public.aml_wallet_ledger enable row level security;
drop policy if exists "Users read own wallet ledger" on public.aml_wallet_ledger;
create policy "Users read own wallet ledger" on public.aml_wallet_ledger for select to authenticated using (auth.uid()=user_id);

create or replace function public.aml_buy_event_ticket(p_offer_id uuid, p_quantity integer default 1)
returns table(ticket_id uuid, ticket_code text, credits_spent bigint, remaining_credits bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := auth.uid(); v_offer public.event_ticket_offers%rowtype; v_cost bigint; v_balance bigint; v_ticket_id uuid; v_code text;
begin
  if v_user is null then raise exception 'Authentification requise'; end if;
  if p_quantity is null or p_quantity < 1 or p_quantity > 10 then raise exception 'Quantité invalide (1 à 10)'; end if;
  select * into v_offer from public.event_ticket_offers where id=p_offer_id for update;
  if not found or v_offer.sales_status <> 'on_sale' then raise exception 'Cette offre n’est pas en vente'; end if;
  if v_offer.stock_remaining is not null and v_offer.stock_remaining < p_quantity then raise exception 'Stock insuffisant'; end if;
  if v_offer.price_xof is null or v_offer.price_xof <= 0 then raise exception 'Prix de billet invalide'; end if;
  v_cost := round(v_offer.price_xof)::bigint * p_quantity;
  select purchased_credits into v_balance from public.wallet_accounts where user_id=v_user for update;
  if coalesce(v_balance,0) < v_cost then raise exception 'Crédit AML insuffisant'; end if;
  update public.wallet_accounts set purchased_credits=purchased_credits-v_cost, updated_at=now() where user_id=v_user;
  if v_offer.stock_remaining is not null then update public.event_ticket_offers set stock_remaining=stock_remaining-p_quantity where id=p_offer_id; end if;
  insert into public.user_event_tickets(user_id,event_id,quantity,status,offer_id,amount_credits)
  values(v_user,v_offer.event_id,p_quantity,'valid',p_offer_id,v_cost) returning id,ticket_code into v_ticket_id,v_code;
  insert into public.aml_wallet_ledger(user_id,amount,transaction_type,reference_id,description)
  values(v_user,-v_cost,'ticket_purchase',v_ticket_id,'Achat ticket : '||v_offer.name);
  return query select v_ticket_id,v_code,v_cost,(v_balance-v_cost);
end; $$;
revoke all on function public.aml_buy_event_ticket(uuid,integer) from public;
grant execute on function public.aml_buy_event_ticket(uuid,integer) to authenticated;


create or replace function public.aml_redeem_event_ticket(p_ticket_code text)
returns table(ticket_id uuid, event_id uuid, ticket_status text, checked_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_role text; v_ticket public.user_event_tickets%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentification requise'; end if;
  select role into v_role from public.profiles where id=auth.uid() and is_suspended is distinct from true;
  if v_role not in ('admin','super_admin','editor','moderator','event_staff') then raise exception 'Accès contrôle refusé'; end if;
  select * into v_ticket from public.user_event_tickets where ticket_code=trim(p_ticket_code) for update;
  if not found then raise exception 'Ticket inconnu'; end if;
  if v_ticket.status <> 'valid' then raise exception 'Ticket déjà utilisé, annulé ou invalide'; end if;
  update public.user_event_tickets set status='used' where id=v_ticket.id;
  return query select v_ticket.id,v_ticket.event_id,'used'::text,now();
end; $$;
revoke all on function public.aml_redeem_event_ticket(text) from public;
grant execute on function public.aml_redeem_event_ticket(text) to authenticated;
