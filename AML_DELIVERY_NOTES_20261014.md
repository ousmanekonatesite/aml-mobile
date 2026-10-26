# AML delivery changes (14 October 2026)

## Included in this source archive
- Added a real settings screen for password change through Supabase Auth.
- Added a direct “Mise à jour AML” entry in Mon espace wired to the existing GitHub Release APK installer.
- Added QR rendering for valid personal event tickets.
- Added ticket offer browsing and credit-based checkout via `aml_buy_event_ticket`.
- Added XP-to-credit conversion UI using the configurable `aml_wallet_settings.xp_per_credit` rate.
- Added a Supabase migration with transactional RPCs for XP conversion, ticket purchase, and staff ticket redemption.

## Required before testing these new database-backed flows
Apply `supabase/migrations/20261014_aml_xp_credit_conversion.sql` after the existing `20261013_aml_user_event_tickets.sql` migration. Confirm the deployed `event_ticket_offers` and `wallet_accounts` schemas match the project schema export. The migration treats `event_ticket_offers.price_xof` as the ticket price in AML credits for this first version; set offer prices accordingly.

## Important limits
- Ticket QR codes are displayed in the app. The server-side `aml_redeem_event_ticket` RPC prevents duplicate redemption, but a scanner UI still needs to call this RPC after scanning/entering the code.
- Admin editing of quiz outcomes and dedicated winning/losing prediction-ticket reports are not fully implemented by this patch. Existing event/fight result and prediction administration screens remain in the project.
- No Flutter build was run in this environment; test the APK build before release.
