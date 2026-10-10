# Delivery status — honest scope and verification

This ZIP contains real source implementation, not a project plan. **It does not fulfill every production requirement in the Master Specification.** Missing integrations and insufficient visual verification are explicit below. The source has not been compiled; it may require corrections after CI runs.

## Implemented in source; execution not verified
- Four mobile tabs; shared Group/Individual mode; independent city inclusion, hotel, dates, guests; read-only Individual guest count.
- Complete room rate plans; no separate meal multiplication. Multiple Individual lines, including same room type with differing plans.
- Inclusive stored price periods; checkout-excluded nights; automatic nightly rate resolution; exact missing-price dates; per-night plan/price overrides; nonoverlap validation in UI and Postgres.
- Integer-minor-unit room/services totals; independent per-person services, Add/Deduct; total SAR/USD.
- Supabase email/password signup/login/recovery request, real Google OAuth launch; requires real provider setup.
- Local calculator draft cache, autosave, cloud draft optimistic revision and explicit local/cloud conflict resolution.
- Server quota consumption at first Save/Share; repeated identity in same mode idempotent; account-bound 7-day trial. No client entitlement writes.
- Immutable archive, confirmed deletion, duplicates frozen night-by-night without repricing.
- Image PNG capture/native share; owner-only text authorization; share-time timestamp; configured footer URL only.
- Private hotels/pricing CRUD; archived prices independent of later database edits.
- Profile name, appearance, FX, language preference, notification preferences, support feedback, configured contacts, password change, sign-out-other-sessions, account-deletion function.
- Owner/admin web source for live account/quota metrics, user search, status changes, audited Premium grants, support inbox/audit reads and contact/public URL configuration.
- Android manifest/Gradle configuration, Kotlin entry point, Flutter calculation/widget tests, Supabase policy/quota tests, two CI workflows.

## Incomplete — not working end-to-end
- **21-language full localization:** English/Uzbek/Arabic core labels only. Many secondary screens/validation/admin strings are still English. Remaining 18 languages are not falsely offered as translated. Arabic core RTL uses Flutter localization; entire Arabic workflow needs QA.
- **Store checkout and receipt verification:** no purchases implemented; Premium panel clearly says unavailable. Google/Apple product IDs, store credentials and server verification integration missing. No fake successful purchase.
- **Notifications:** persisted preferences only. No FCM/APNs delivery, scheduled expiry/trial notifications, login alerts or owner announcements.
- **Haramain Stay:** no partner API, audience configuration or banners implemented. No user data is exchanged. Do not seed fake partner offers.
- **Offline sync:** current draft autosave/retry and conflict handling included; offline hotel mutations, archive deletion queue and preferences retry are not complete. Save/Share require server authorization online; calculator edits remain local. Cross-device conflict UX needs integration testing.
- **Security/device administration:** devices table is present but client registration/list and device-specific revocation/login analytics/rate limiting are not complete. Password change, own other-session signout and account deletion have real API paths. Admin sign-out-all, anti-fraud analytics, audited narrow private support authorization, operational backups and legal deletion/retention policy need implementation/configuration.
- **Admin dashboard:** no revenue/trend charts, purchases list, plan checkout configuration, role-management UI, announcements or partner offers. No illustrative counts; available counts are server-derived. Analyst user-list access is correctly denied, but UX needs refinement.
- **Profile:** full name only; phone/country/photo/agency/logo/WhatsApp fields remain incomplete.
- **Apple/iOS:** not included in Android-only project.
- **Visual fidelity:** compact navy/green/blue/gold forms are implemented; reference boards are packaged. Production scenic backgrounds/hotel photography/custom assets are not recreated. Per-screen side-by-side screenshots and final owner visual approval remain outstanding. This is **not** a pixel-faithful reproduction certified against all references.
- **Official wrapper binary:** not included; CI/local bootstrap fetches it from a real Flutter template. Initial offline build cannot proceed without bootstrap.

## Unverified
- Flutter package resolution, static analysis, calculation/widget tests, Android release-mode APK build.
- Supabase migration syntax/runtime, pgTAP tests, live sign-in/OAuth, quota races, multi-account RLS, draft conflicts, deletion and owner admin operations.
- Every mobile screen at small/large Android sizes, increased text scale, keyboard, dark/RTL layouts, share image long histories and accessibility.
- Admin web compilation, mobile plugin tree shaking, production hosting and role-specific routes.
- GitHub workflow execution and downloadable APK artifact.

## Decisions/configuration to approve
- Android package `com.upc.calculator` is provisional.
- FX provider open.er-api.com and 24-hour cache are provisional; two-decimal inputs are enforced, USD formatting uses Dart's `toStringAsFixed(2)`.
- Actual Supabase client values, OAuth setup, store products, notification infrastructure, UPC link, real support contacts and licensed production imagery are absent.
- Trial consumption policy is server-clock based. Offline Save/Share is blocked rather than claiming privileged authorization offline.

A source ZIP is delivered; a completed/verified production UPC application or APK is **not** claimed.
