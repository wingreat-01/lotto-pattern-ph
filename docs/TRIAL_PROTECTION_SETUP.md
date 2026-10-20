# LottoPattern PH — Trial Protection Setup

This patch adds the first Supabase-backed entitlement layer to the supplied Flutter project. It is a setup scaffold and must be configured against your own Supabase and Google Cloud projects before release.

## Policy in this patch

- Google sign-in is required before using the generator.
- Trial begins on the first successful pattern generation.
- The default allowance is 20 generated combinations; each combination costs one credit.
- Latest Results and the 30-day Activity Pattern screen require an active five-day trial or a verified lifetime entitlement.
- Trial timestamps and credit balance are stored in Postgres, not local preferences.
- Generation credit consumption is transactional and accepts a request UUID for retry idempotency.
- The `trial_eligibility` ledger keeps the Google provider subject after the app account is deleted, preventing that same Google identity from claiming another trial.

## 1. Configure Supabase

1. Create a Supabase project.
2. In Authentication → Providers, enable Google and configure the Google OAuth client credentials from Google Cloud Console.
3. Add this callback to Supabase's allowed redirect URLs: `io.supabase.lottopattern://login-callback/`.
4. Run `supabase/migrations/202610200001_trial_entitlements.sql` in the Supabase SQL Editor (or apply it with the Supabase CLI).
5. In Authentication → URL Configuration, make sure your app callback is allowed. Keep the Supabase project URL and publishable/anon key in your build configuration; never put a service-role key in Flutter.

## 2. Run the Flutter app

From the project root:

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY
```

The Android manifest and iOS Info.plist in this patch include the callback scheme `io.supabase.lottopattern`. If you change the callback scheme, change both platform configuration and `lib/screens/sign_in_screen.dart` consistently.

## 3. Important limitations before production

### Lifetime purchase verification is not yet wired

The database has a `play_purchases` table, but this patch intentionally does not grant lifetime access from the client. Before launch, implement a Supabase Edge Function that verifies the Google Play purchase token with the Google Play Developer API, checks the expected one-time product ID, handles refunds/revocations, records each token uniquely, and then updates `user_entitlements.lifetime_unlocked` using privileged server credentials. Do not add the service-role key or Google service-account credentials to the app.

### Strict anti-abuse has limits

The ledger blocks reuse of the same Google provider subject after a Supabase account is deleted. It cannot reliably prove that two different Google accounts belong to the same human. Add rate limits and risk signals if abuse appears; avoid invasive fingerprinting.

### Public PCSO data and client-side generation

The current generator still runs in Flutter, and the results screen still reads publicly available PCSO results from the app. The server checks in this patch protect the official app's normal flow, but a modified client could bypass UI checks or call public PCSO sources directly. For strong enforcement, move generation into a trusted server function and proxy premium result/activity data through a server endpoint that checks entitlement before returning it.

### Test the migration and build

This environment did not run `flutter pub get`, compile the app, or apply the SQL to a live Supabase project. Test with a separate Supabase project first. Verify Google OAuth callbacks on a real Android device, a new eligible account, the same Google account after account deletion/recreation, expired trial, zero credits, concurrent generation taps, offline behavior, and purchase restore/refund scenarios.
