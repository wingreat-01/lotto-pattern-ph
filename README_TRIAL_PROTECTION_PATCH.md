# LottoPattern PH trial-protection patch

This folder contains the supplied LottoPattern PH Flutter project plus an initial Supabase-backed access-control integration.

Start with `docs/TRIAL_PROTECTION_SETUP.md` before running the app. Apply the SQL migration, configure Google OAuth in Supabase, and pass `SUPABASE_URL` and `SUPABASE_ANON_KEY` using `--dart-define`.

**Production note:** Google Play lifetime purchase verification and server-proxied premium data/generation still need to be implemented before describing the system as fully abuse-proof. See the setup guide for exact limitations.
