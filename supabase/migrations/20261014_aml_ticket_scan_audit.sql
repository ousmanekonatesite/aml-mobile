-- Audit de contrôle des tickets d'entrée AML.
-- À appliquer après 20261013_aml_user_event_tickets.sql et 20261014_aml_xp_credit_conversion.sql.
alter table public.user_event_tickets
  add column if not exists checked_at timestamptz,
  add column if not exists checked_by uuid references auth.users(id);

create index if not exists user_event_tickets_status_checked_idx
  on public.user_event_tickets(status, checked_at desc);

create or replace function public.aml_redeem_event_ticket(p_ticket_code text)
returns table(ticket_id uuid, event_id uuid, ticket_status text, checked_at timestamptz)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_role text;
  v_ticket public.user_event_tickets%rowtype;
  v_checked_at timestamptz := now();
begin
  if auth.uid() is null then raise exception 'Authentification requise'; end if;

  select role into v_role
  from public.profiles
  where id = auth.uid() and is_suspended is distinct from true;

  if v_role not in ('admin','super_admin','ticket_supervisor') then
    raise exception 'Accès contrôle refusé';
  end if;

  select * into v_ticket
  from public.user_event_tickets
  where ticket_code = trim(p_ticket_code)
  for update;

  if not found then raise exception 'Ticket inconnu'; end if;
  if v_ticket.status <> 'valid' then raise exception 'Ticket déjà utilisé, annulé ou invalide'; end if;

  update public.user_event_tickets
  set status = 'used', checked_at = v_checked_at, checked_by = auth.uid()
  where id = v_ticket.id;

  return query select v_ticket.id, v_ticket.event_id, 'used'::text, v_checked_at;
end;
$$;

revoke all on function public.aml_redeem_event_ticket(text) from public;
grant execute on function public.aml_redeem_event_ticket(text) to authenticated;

-- Les superviseurs peuvent consulter le registre pour contrôler les entrées, sans gérer les offres.
drop policy if exists ticket_supervisor_read_tickets on public.user_event_tickets;
create policy ticket_supervisor_read_tickets on public.user_event_tickets
for select to authenticated using (exists (
  select 1 from public.profiles p where p.id=auth.uid()
  and p.is_suspended is distinct from true and p.role in ('admin','super_admin','ticket_supervisor')
));
