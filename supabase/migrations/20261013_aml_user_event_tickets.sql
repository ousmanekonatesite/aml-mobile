-- Personal tickets: records are created only after a confirmed payment or explicit admin assignment.
create table if not exists public.user_event_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_id uuid not null references public.events(id) on delete cascade,
  ticket_code text not null unique default ('AML-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,12))),
  quantity integer not null default 1 check (quantity > 0),
  status text not null default 'valid' check (status in ('valid','used','cancelled','refunded')),
  purchased_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index if not exists user_event_tickets_user_date_idx on public.user_event_tickets(user_id, purchased_at desc);
alter table public.user_event_tickets enable row level security;
drop policy if exists "Users can read their own event tickets" on public.user_event_tickets;
create policy "Users can read their own event tickets" on public.user_event_tickets for select to authenticated using (auth.uid() = user_id);
drop policy if exists "Staff can manage event tickets" on public.user_event_tickets;
create policy "Staff can manage event tickets" on public.user_event_tickets for all to authenticated using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_suspended is distinct from true and p.role in ('admin','super_admin','editor','moderator'))) with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_suspended is distinct from true and p.role in ('admin','super_admin','editor','moderator')));
