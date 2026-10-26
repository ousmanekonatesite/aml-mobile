# AML — V3 continuation notes

## Included in this archive
- Preserves the current AML TV playback implementation from the V2 baseline.
- Replaces the placeholder `Mes billets` action with a screen backed by `public.user_event_tickets`.
- Replaces the leaderboard-only `Badges & XP` action with a personal XP and badge screen, reading `xp_transactions`, `user_badges`, and `badges`.
- Adds `supabase/migrations/20261013_aml_user_event_tickets.sql` for personal event-ticket records and owner/staff RLS policies.

## Required Supabase action
Apply `supabase/migrations/20261013_aml_user_event_tickets.sql` in the Supabase SQL Editor or through the normal migration workflow.

The new ticket screen intentionally shows an empty state until tickets are issued. This migration does not create purchases, take payments, or assign tickets automatically. Ticket records must be inserted only after confirmed payment or explicit staff assignment by a trusted backend/admin flow.

## Validation status
ZIP integrity can be checked locally. Flutter compilation and device testing have not been run in this environment. The existing home-settings RLS error still requires validation against the actual policies and roles in the live Supabase project; do not assume a migration is applied just because it is present in this ZIP.
