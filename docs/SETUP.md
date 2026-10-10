# Setup and deployment

## Android / GitHub
1. Extract the ZIP and upload **the contents of upc_project**, including `.github`, to a new repository. Do not upload just the ZIP. Do not delete dot directories. GitHub web upload can omit them; Git CLI is safer.
2. Repository Settings → Secrets and variables → Actions → Variables: configure `SUPABASE_URL`, `SUPABASE_ANON_KEY` (publishable/anon client key), and optionally `UPC_PUBLIC_URL`, `SUPPORT_EMAIL`, `SUPPORT_PHONE`. Client values are public. Never put a service-role key here or in an APK.
3. Trigger **Android APK verification**. Every step must pass. Download `upc-android-release-test-signed` under the completed Actions run's Artifacts. No build has been verified by the author of this ZIP.
4. Blank Supabase values intentionally build a configuration-error screen, **not fake login**. A usable application requires migrations and Auth configuration.
5. The release-mode APK uses debug/test signing. It is for installation testing, not a Play Store release. Add private upload-key signing before publication.

### Local commands
- Install Flutter **3.35.7** and JDK 17, Android SDK and licensed tools.
- `bash scripts/bootstrap_android.sh` (PowerShell alternative supplied).
- Copy `config/app.example.json` to `config/app.json`, fill public settings.
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter run --dart-define-from-file=config/app.json`
- `flutter build apk --release --dart-define-from-file=config/app.json`

### Gradle wrapper limitation
The official binary `gradle-wrapper.jar` could not be fetched in the authoring environment. CI obtains that **official** binary from a Flutter-generated Android template before building; it does not regenerate or overwrite app source/configuration. Offline first-time Gradle builds cannot run without completing this bootstrap. This is an explicit deliverable gap, not a claim that a standard wrapper binary is already included.

### Application identity
`com.upc.calculator` is an implementation placeholder, not a verified owner-controlled package. Before production, approve/replace it in the namespace, application ID, Kotlin package/path, OAuth callback and Supabase redirect configuration. Display name is UPC.

## Supabase
- Install Supabase CLI and Docker. `supabase start`, `supabase db reset`, `supabase test db` for local policy tests.
- For a real project, `supabase link --project-ref YOUR_REF`, then inspect and apply `supabase db push` to a **fresh** schema. Migrations have not been exercised here.
- `supabase functions deploy delete-account`.
- Enable email/password Auth, email confirmation, recovery templates and production SMTP. Register callback `com.upc.calculator://login-callback/`.
- Enable Google OAuth in Supabase with your authorized client IDs/secret and callback. Google button launches real Supabase OAuth, but cannot authenticate until configured; this integration is unverified.
- The Android deliverable does not implement Apple/iOS sign-in or an iOS project.
- Sign up the owner account first; assign OWNER using a **trusted SQL administrator**, never a client email comparison. Example after verifying the account UUID: `update public.accounts set role='OWNER' where id='YOUR_VERIFIED_ACCOUNT_UUID';`. This is a setup action, not code that chooses an owner automatically.
- A USER cannot update role, trial, entitlements, archive contents or usage counters. Admin access goes through role-gated, audited functions. No private hotel/archive browser is supplied.
- Configure real contacts and public URL from the Owner dashboard. No fictional contacts or partner URL are seeded.

## Separate admin web portal
`flutter build web --target lib/admin_main.dart --dart-define-from-file=config/app.json`
Deploy `build/web` to your selected HTTPS static host. It uses the same Supabase project. Desktop/tablet and a narrow navigation alternative are included. Only role-authorized server operations execute.

## FX decision
A configurable provider was not supplied. This source uses the documented open ExchangeRate-API endpoint `https://open.er-api.com/v6/latest/USD`, with 24-hour cache validity as an **unapproved implementation choice** requiring owner review. Direction is SAR per 1 USD. No baked-in 3.75 fallback. Manual override is stored per account until explicit Reset to Auto. Check provider terms, attribution and availability before production.

## Mandatory production work
See `DELIVERY_STATUS.md`. Store purchases, receipt verification, push delivery, partner offers, full language coverage, production imagery, privacy terms, security/session analytics and full offline synchronization are not represented as working. Do not distribute this as a complete production application.
