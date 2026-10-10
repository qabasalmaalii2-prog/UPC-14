# UPC — Umrah Package Calculator

**Source implementation / unverified integration release. Not a completed production app.**

The approved functional source of truth is `docs/UPC_Master_Specification.pdf`. All eight approved visual boards are included in `assets/references`. Written requirements override obsolete labels and examples.

## Included
- Flutter Android application: account-required Supabase authentication, Group / Individual calculators, per-city inputs, complete rate plans, multiple room lines, nightly price lookup/overrides, additional service signs, SAR/USD, private hotel pricing periods, draft persistence, immutable archive, duplicate, image sharing and server-authorized owner text sharing.
- Supabase schema, RLS, hotel-period exclusion constraint, account-bound trial, atomic quota/idempotency functions, archive guards, role-gated admin functions, account-deletion edge function and pgTAP tests.
- Separate Flutter web admin entry point `lib/admin_main.dart`.
- Domain calculation tests and a narrow-layout widget test.
- GitHub Actions APK workflow and backend test workflow.

## Read first
1. `DELIVERY_STATUS.md` — implemented vs missing vs unverified.
2. `docs/SETUP.md` — exact setup/build instructions and production gaps.
3. `docs/ACCEPTANCE.md` — verification checklist.

**No Flutter analysis, tests, APK build, emulator run or live Supabase test was performed in the authoring environment.** Flutter/Dart SDK was absent and the SDK download hostname could not resolve. GitHub Actions is configured to perform analysis/tests/build; a green run has not been observed.

All monetary calculation inputs use integer SAR minor units. Quota enforcement runs in database transactions. No Catering, Buy/Sell, Combined mode, Profit, Archive Edit, PDF sharing or hardcoded owner email is implemented.

Public configurations and original imagery are still required. The official Gradle wrapper JAR is restored by the supplied bootstrap script/CI and is not included as a fabricated binary. Release-mode APKs are test-signed, not Play-ready.
