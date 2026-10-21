# LottoPattern PH — rewarded ads and Lifetime Premium setup

This update removes the Google sign-in gate. Users can open LottoPattern PH immediately without creating an account. Free users must complete a rewarded video before each generation; Lifetime Premium skips rewarded ads.

## Required dependencies

Ensure these are present under `dependencies` in the full project's `pubspec.yaml` (keep other packages the remaining app uses):

```yaml
google_mobile_ads: ^5.3.1
in_app_purchase: ^3.2.0
```

Run `flutter pub get` after changing dependencies.

## Google Mobile Ads

- The code currently uses Google's official Android **test rewarded-ad unit** (`ca-app-pub-3940256099942544/5224354917`). It is for testing only; replace it with your own rewarded ad unit before release.
- Add your AdMob App ID to Android `AndroidManifest.xml` as documented by Google Mobile Ads. Add the iOS App ID to `Info.plist` only if building for iOS.
- Configure consent/privacy messaging and the required privacy disclosures for your audience and applicable policies.
- If an ad is not loaded or the user closes it before earning the reward, generation is not granted; the user can retry or buy Premium.

## Google Play one-time product

- Create an in-app product in Play Console with product ID exactly `lottopattern_lifetime_199` and set the price to ₱199, or change `lifetimeProductId` in `services/monetization_service.dart` to match your product.
- Configure and test purchases using an internal testing track and a licensed tester. Products may not load until Play Console setup is complete.
- The app uses non-consumable purchase and restore handling.

## Important before publishing

This is an integration scaffold, not a production-complete purchase verification system. Currently, premium entitlement is granted from the client-side Play Billing stream. Before publishing, validate purchase tokens on a trusted backend (for example, a Supabase Edge Function using the Google Play Developer API), handle refunds/revocations, and never include a Google service-account key in the app. The rewarded-ad callback is also handled client-side; consider AdMob server-side verification for stronger anti-tampering.

## What changed

- Removed the Google sign-in screen and Supabase-auth startup gate.
- Removed the old Supabase trial/credit entitlement service from this library patch.
- The app opens directly to the home screen with no signup required.
- Free generation requires a completed rewarded video.
- Lifetime Premium offers ad-free generation for a one-time purchase.
- Latest Draw Results and Pattern Activity remain accessible without an account or trial.
