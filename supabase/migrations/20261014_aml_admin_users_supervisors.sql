-- Administration des utilisateurs AML : superviseurs de billetterie, suspensions,
-- recherche et ajustements de portefeuille/XP. Les opérations sont vérifiées côté serveur.

create or replace function public.aml_admin_list_users(p_search text default '')
returns setof jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if coalesce(public.aml_is_admin(), false) is not true then raise exception 'ADMIN_REQUIRED'; end if;
  return query
  select jsonb_build_object(
    'id', p.id,
    'display_name', p.display_name,
    'username', p.username,
    'role', p.role,
    'is_suspended', coalesce(p.is_suspended,false),
    'credit_balance', coalesce(w.purchased_credits,0),
    'xp_balance', coalesce(x.total_xp,0)
  )
  from public.profiles p
  left join public.wallet_accounts w on w.user_id=p.id
  left join lateral (select sum(t.amount) total_xp from public.xp_transactions t where t.user_id=p.id) x on true
  where coalesce(p.username,'') ilike '%'||coalesce(trim(p_search),'')||'%'
     or coalesce(p.display_name,'') ilike '%'||coalesce(trim(p_search),'')||'%'
     or p.id::text ilike '%'||coalesce(trim(p_search),'')||'%'
  order by p.display_name nulls last, p.username nulls last
  limit 500;
end; $$;

create or replace function public.aml_admin_set_user_role(p_user_id uuid, p_role text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if coalesce(public.aml_is_admin(), false) is not true then raise exception 'ADMIN_REQUIRED'; end if;
  if p_role not in ('user','ticket_supervisor','moderator','editor') then raise exception 'ROLE_NOT_ALLOWED'; end if;
  if p_user_id = auth.uid() then raise exception 'CANNOT_CHANGE_OWN_ROLE'; end if;
  update public.profiles set role=p_role where id=p_user_id;
  if not found then raise exception 'USER_NOT_FOUND'; end if;
end; $$;

create or replace function public.aml_admin_set_user_suspended(p_user_id uuid, p_suspended boolean)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare v_role text;
begin
  if coalesce(public.aml_is_admin(), false) is not true then raise exception 'ADMIN_REQUIRED'; end if;
  if p_user_id = auth.uid() then raise exception 'CANNOT_SUSPEND_SELF'; end if;
  select role into v_role from public.profiles where id=p_user_id;
  if not found then raise exception 'USER_NOT_FOUND'; end if;
  if v_role in ('admin','super_admin') then raise exception 'CANNOT_SUSPEND_ADMIN'; end if;
  update public.profiles set is_suspended=coalesce(p_suspended,false) where id=p_user_id;
end; $$;

create or replace function public.aml_admin_adjust_user_balances(
  p_user_id uuid, p_credits bigint default 0, p_xp bigint default 0, p_reason text default 'Ajustement administrateur'
) returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare v_balance bigint; v_xp bigint;
begin
  if coalesce(public.aml_is_admin(), false) is not true then raise exception 'ADMIN_REQUIRED'; end if;
  if p_user_id is null or (coalesce(p_credits,0)=0 and coalesce(p_xp,0)=0) then raise exception 'INVALID_ADJUSTMENT'; end if;
  if length(trim(coalesce(p_reason,''))) < 3 then raise exception 'REASON_REQUIRED'; end if;
  perform pg_advisory_xact_lock(hashtext(p_user_id::text));
  if not exists(select 1 from public.profiles where id=p_user_id) then raise exception 'USER_NOT_FOUND'; end if;
  if coalesce(p_credits,0) <> 0 then
    insert into public.wallet_accounts(user_id,purchased_credits,updated_at) values(p_user_id,0,now()) on conflict(user_id) do nothing;
    select purchased_credits into v_balance from public.wallet_accounts where user_id=p_user_id for update;
    if coalesce(v_balance,0)+p_credits < 0 then raise exception 'INSUFFICIENT_CREDIT_BALANCE'; end if;
    update public.wallet_accounts set purchased_credits=purchased_credits+p_credits,updated_at=now() where user_id=p_user_id;
    insert into public.aml_wallet_ledger(user_id,amount,transaction_type,description)
      values(p_user_id,p_credits,'credit_adjustment','Admin: '||trim(p_reason));
  end if;
  if coalesce(p_xp,0) <> 0 then
    select coalesce(sum(amount),0) into v_xp from public.xp_transactions where user_id=p_user_id;
    if coalesce(v_xp,0)+p_xp < 0 then raise exception 'INSUFFICIENT_XP_BALANCE'; end if;
    insert into public.xp_transactions(user_id,amount,reason,reference_type) values(p_user_id,p_xp,'Admin: '||trim(p_reason),'admin_adjustment');
  end if;
  select purchased_credits into v_balance from public.wallet_accounts where user_id=p_user_id;
  select coalesce(sum(amount),0) into v_xp from public.xp_transactions where user_id=p_user_id;
  return jsonb_build_object('credit_balance',coalesce(v_balance,0),'xp_balance',coalesce(v_xp,0));
end; $$;

revoke all on function public.aml_admin_list_users(text) from public;
revoke all on function public.aml_admin_set_user_role(uuid,text) from public;
revoke all on function public.aml_admin_set_user_suspended(uuid,boolean) from public;
revoke all on function public.aml_admin_adjust_user_balances(uuid,bigint,bigint,text) from public;
grant execute on function public.aml_admin_list_users(text) to authenticated;
grant execute on function public.aml_admin_set_user_role(uuid,text) to authenticated;
grant execute on function public.aml_admin_set_user_suspended(uuid,boolean) to authenticated;
grant execute on function public.aml_admin_adjust_user_balances(uuid,bigint,bigint,text) to authenticated;

create or replace function public.aml_admin_update_user_profile(p_user_id uuid, p_display_name text, p_username text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if coalesce(public.aml_is_admin(), false) is not true then raise exception 'ADMIN_REQUIRED'; end if;
  if p_user_id=auth.uid() then raise exception 'CANNOT_EDIT_OWN_ADMIN_PROFILE_HERE'; end if;
  if length(trim(coalesce(p_display_name,''))) < 1 or length(trim(coalesce(p_username,''))) < 2 then raise exception 'INVALID_PROFILE_FIELDS'; end if;
  update public.profiles set display_name=trim(p_display_name), username=trim(p_username) where id=p_user_id;
  if not found then raise exception 'USER_NOT_FOUND'; end if;
end; $$;

create or replace function public.aml_admin_delete_user(p_user_id uuid)
returns void language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare v_role text;
begin
  if coalesce(public.aml_is_admin(), false) is not true then raise exception 'ADMIN_REQUIRED'; end if;
  if p_user_id=auth.uid() then raise exception 'CANNOT_DELETE_SELF'; end if;
  select role into v_role from public.profiles where id=p_user_id;
  if not found then raise exception 'USER_NOT_FOUND'; end if;
  if v_role in ('admin','super_admin') then raise exception 'CANNOT_DELETE_ADMIN'; end if;
  delete from auth.users where id=p_user_id;
  if not found then raise exception 'AUTH_USER_NOT_FOUND'; end if;
end; $$;

revoke all on function public.aml_admin_update_user_profile(uuid,text,text) from public;
revoke all on function public.aml_admin_delete_user(uuid) from public;
grant execute on function public.aml_admin_update_user_profile(uuid,text,text) to authenticated;
grant execute on function public.aml_admin_delete_user(uuid) to authenticated;

-- Autorise uniquement l'administrateur et les superviseurs explicitement désignés à scanner.
create or replace function public.aml_redeem_event_ticket(p_ticket_code text)
returns table(ticket_id uuid, event_id uuid, ticket_status text, checked_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_role text; v_ticket public.user_event_tickets%rowtype; v_checked_at timestamptz := now();
begin
  if auth.uid() is null then raise exception 'Authentification requise'; end if;
  select role into v_role from public.profiles where id=auth.uid() and is_suspended is distinct from true;
  if v_role not in ('admin','super_admin','ticket_supervisor') then raise exception 'Accès contrôle refusé'; end if;
  select * into v_ticket from public.user_event_tickets where ticket_code=trim(p_ticket_code) for update;
  if not found then raise exception 'Ticket inconnu'; end if;
  if v_ticket.status <> 'valid' then raise exception 'Ticket déjà utilisé, annulé ou invalide'; end if;
  update public.user_event_tickets set status='used', checked_at=v_checked_at, checked_by=auth.uid() where id=v_ticket.id;
  return query select v_ticket.id, v_ticket.event_id, 'used'::text, v_checked_at;
end; $$;
revoke all on function public.aml_redeem_event_ticket(text) from public;
grant execute on function public.aml_redeem_event_ticket(text) to authenticated;
