# Store Submission Guide

Step-by-step for shipping WhoWouldWin to Google Play and Amazon Appstore.
v1.1 adds AAOS (Android Automotive OS) as a Parked App — see the last section.

---

## Google Play Console

### Account setup (you do this)

1. Go to https://play.google.com/console/signup
2. Pick **Organization** account (since KPT LLC is publishing, not you personally).
3. Pay the **$25 one-time** registration fee.
4. Google will ask for a D-U-N-S number for org accounts — you have this from
   the Dun & Bradstreet form you already submitted.
5. Verification takes 1–3 business days.

### First-time app creation

1. Play Console → **Create app**.
2. App name: **Who Would Win?** · Default language: English (US)
3. App or game: **Game** · Free or paid: **Free** (with in-app purchases)
4. Declarations: confirm Play policies and US export laws.

### Required forms before you can publish

Each of these is a blocker — Play will not let you promote to production until
every section is green.

- **App content** → Privacy policy URL: `https://animal-vs-animal.com/privacy.html`
- **App content** → App access: "All functionality available without restrictions"
- **App content** → Ads: **No** (we do not run ads)
- **App content** → Content rating: fill the IARC questionnaire. For a kids
  battle game with no violence/gore, expect **Everyone** or **Everyone 10+**.
- **App content** → Target audience: **Ages 5–8** and **9–12**. This triggers
  the **Designed for Families** policy — see the COPPA section below.
- **App content** → Data safety form: "Does your app collect or share user data?"
  → **No** (DataStore is local-only, no analytics). Confirm encryption in
  transit (HTTPS). Users can request data deletion via a contact email.
- **App content** → Government apps: **No**
- **App content** → Financial features: **No**
- **App content** → Health: **No**
- **Store settings** → App category: **Games → Casual** (or Educational)
- **Store settings** → Contact details: your support email

### COPPA / Designed for Families

Because the target audience includes under-13s:
- No third-party ads, no behavioral ads ever.
- No collection of persistent identifiers tied to a child.
- IAPs must be gated behind a parental gate (time-based math problem before
  purchase confirmation). **Wire this into the IAP sheets** — port the iOS
  version's confirmation if one exists, or add a simple "What is 7 × 8?" gate.

### Store listing content

- **Short description** (80 chars): "Who would win? Pick two animals and let AI battle them!"
- **Full description** (up to 4000 chars): write this in a plain text file in
  the repo (`store/play-description.txt`) so you can iterate on it.
- **App icon**: 512×512 PNG, 32-bit with alpha. Export from the same Figma/Illustrator
  source as the iOS icon for brand consistency.
- **Feature graphic**: 1024×500 PNG. Shows at the top of the listing.
- **Phone screenshots**: min 2, max 8. Portrait, 1080×1920 or larger. Use real
  device screenshots from the emulator, not the marketing mockups.
- **7-inch tablet screenshots**: recommended (helps with tablet discoverability).
- **10-inch tablet screenshots**: recommended.
- **Promo video** (optional): YouTube URL.

### Build upload

1. **Production → Release → Create new release**
2. Enroll in **Play App Signing** when prompted. Accept.
3. Upload the signed AAB built from `./gradlew bundleRelease`.
4. Release name auto-fills from versionName. Release notes (500 chars): write
   plain-English changelog ("Brand-new Android version of Who Would Win?").
5. **Review release** → fix any warnings → **Start rollout to Internal testing** FIRST.
6. Test on 2+ real devices via the internal-testing opt-in link.
7. Promote to **Closed testing** (optional, for friends/family).
8. Promote to **Production** with a **staged rollout** (start at 20%, then 50%,
   then 100% over a few days). This limits blast radius if a crash slips through.

### Review time

Expect **2–7 days** for first review. Subsequent updates usually clear in under 24h.

---

## Amazon Appstore

### Account setup (you do this)

1. Go to https://developer.amazon.com
2. Sign in with your Amazon account; opt into the **Amazon Developer Program** (free).
3. No D-U-N-S needed for Amazon, but fill in tax info (W-9 for a US LLC).

### App submission

1. Developer Console → **Apps & Services → Add a New App → Android**.
2. General information: copy the title, description, category, and keywords
   from the Play listing to keep parity.
3. Availability & Pricing: **Free** everywhere, or restrict to US if you want
   to start small.
4. Content Rating: Amazon uses their own questionnaire — similar answers to
   Play's IARC. Expect **Guidance Suggested** or **All Ages**.
5. **Amazon Kids / FreeTime**: opt in. This gets the app on Fire Kids tablets.
   Amazon will re-review under stricter rules (no external links, no IAP
   without parental gate — same parental gate we built for Play COPPA).

### Build upload

- Amazon accepts **APK only** for now (not AAB). Build with:
  `./gradlew assembleRelease`
- Upload the signed APK from `app/build/outputs/apk/release/app-release.apk`.
- Amazon will re-sign the APK with their own key for DRM — this is their norm.

### Review time

Amazon review is typically **1–3 days**.

---

## v1.1 — AAOS (Android Automotive OS) Parked App

This is what shows up in your Volvo's in-car Play Store. Scope is limited: the
app must pause automatically when the car is not parked. Google calls this a
**Parked App**.

### Requirements

1. Add `distractionOptimized="false"` app metadata (apps must explicitly declare
   they are parked-only).
2. Add `<uses-feature android:name="android.hardware.type.automotive" android:required="false"/>`.
3. Listen for `CarPropertyManager.PARKING_BRAKE_ON` and pause the game UI when
   the brake is released. Display a "Please park to play" overlay.
4. Build a separate `:automotive` module or an AAOS-specific flavor — AAOS
   builds need their own manifest with a `<category>` of `CATEGORY_LAUNCHER`
   but no phone launcher activity.
5. Use the **Car App Quality** checklist:
   https://developer.android.com/docs/quality-guidelines/car-app-quality

### Submission

- Same Play Console, different **Automotive OS** track.
- Will be reviewed by a separate Automotive team — expect **1–2 weeks** the
  first time.
- Certification requires testing on the **Automotive OS emulator** (comes with
  Android Studio as a system image).

---

## Version bumps

Every store upload needs a new `versionCode` (integer, monotonic) in
`app/build.gradle.kts`. The `versionName` (user-visible string like `1.0.1`)
can stay the same for hotfixes, but bump it for feature releases.

Suggested scheme:
- `versionCode` = date-based integer: `20260417` for Apr 17, 2026
- `versionName` = semver: `1.0.0`, `1.0.1`, `1.1.0`

---

## Checklist for every release

- [ ] `versionCode` bumped
- [ ] Release notes written (one file, reused across stores)
- [ ] Smoke-tested on a real Android phone
- [ ] Smoke-tested on a real Android tablet (or emulator equivalent)
- [ ] No secrets in the APK (`unzip -p app-release.apk | strings | grep -i api_key` returns nothing)
- [ ] `git status` clean, nothing gitignored staged
- [ ] Tagged in git: `git tag android-v1.0.0 && git push --tags`
- [ ] Uploaded to Play Internal Testing → verified install on a real device
- [ ] Promoted to Production with staged rollout
- [ ] Uploaded to Amazon Developer Console
