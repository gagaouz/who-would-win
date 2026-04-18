# Android Security & Signing

Everything here is about keeping your release signing key safe. Lose it and you
can never update the app on Google Play under the same listing — you'd have to
publish a brand-new app and ask users to migrate. Take this seriously.

## One-time keystore generation

Do this once on your Mac. The keystore is a single encrypted file that holds
your release signing key.

```bash
cd ~/WWW/who-would-win/android
keytool -genkeypair -v \
  -keystore whowouldwin-release.jks \
  -alias whowouldwin \
  -keyalg RSA -keysize 4096 \
  -validity 10000 \
  -storetype JKS
```

It will prompt for:
- **Keystore password** — pick a strong one, save in your password manager
- **Key password** — can be the same as keystore password (simpler)
- **Name / org / locality** — use "KPT LLC" for the org, the rest can be approximate

Output: `whowouldwin-release.jks` in the `android/` folder. **This file is
already in `.gitignore`** — double-check before every commit that it is not
staged.

## keystore.properties

Next to the `.jks` file, create `keystore.properties` (also gitignored):

```properties
storeFile=whowouldwin-release.jks
storePassword=YOUR_KEYSTORE_PASSWORD
keyAlias=whowouldwin
keyPassword=YOUR_KEY_PASSWORD
```

`app/build.gradle.kts` reads this file to sign release builds. If the file is
missing, release builds will fail with a clear error — that is intentional so
you cannot accidentally ship an unsigned build.

## Backup strategy

Back up BOTH files immediately:

1. **iCloud Drive** (encrypted at rest): copy the `.jks` and `keystore.properties`
   to `~/Library/Mobile Documents/com~apple~CloudDocs/KeyBackups/whowouldwin/`.
2. **Password manager**: paste the two passwords into 1Password / Apple Passwords.
3. **Offline copy** (optional but recommended): encrypted USB stick in a drawer.

If your Mac dies and you have no backup, the signing key is gone — there is no
recovery.

## Play App Signing (strongly recommended)

When you upload your first AAB to Play Console, Google will offer to manage
your app signing key in their HSM. Accept this. What it means:

- You generate an **upload key** (the `.jks` above) and use it to sign AABs you
  upload to Google.
- Google holds the actual **app signing key** in their hardware security module
  and signs the APKs that go to devices.
- If you ever lose your upload key, Google can reset it — email Play support,
  prove ownership, and upload a new upload-key certificate. You do not lose
  the app.

Without Play App Signing, losing your signing key = losing the app. So: enroll.

## HTTPS enforcement

`res/xml/network_security_config.xml` sets `cleartextTrafficPermitted="false"`.
All traffic must be HTTPS. The Railway backend already serves HTTPS, so this is
a belt-and-suspenders check — any future code that accidentally points at
`http://` will fail loudly in development.

## No secrets in the client

The Android app holds **zero** API keys or secrets. All Claude API calls go
through the Railway backend, which holds the Anthropic key in its env. If you
ever find yourself tempted to put a key in `BuildConfig` or `strings.xml`,
stop — ship a new backend endpoint instead.

## ProGuard / R8

Release builds run R8 with `isMinifyEnabled = true` and `isShrinkResources = true`.
This obfuscates class names, strips unused code, and shrinks resources. Keep
rules for Moshi/Retrofit/OkHttp are in `app/proguard-rules.pro`. If you add a
new library that uses reflection, add its keep rules there.

## Data handling

- `DataStore` (user settings, coins, stats) is local-only. Auto-Backup
  **excludes** `device_auth.xml` via `backup_rules.xml` and
  `data_extraction_rules.xml` — see the comments in those files.
- No PII is collected. No analytics SDK is wired up. If you add one later,
  update the Play Console Data Safety form the same day.

## Before every release

1. `git status` — confirm no `.jks`, `.keystore`, or `keystore.properties` are staged.
2. Build a release AAB (`./gradlew bundleRelease`).
3. Install it on a real device via `bundletool` and smoke-test.
4. Bump `versionCode` in `app/build.gradle.kts` — Play rejects re-uploads of the same code.
5. Upload to Play Console **internal testing** track first, never straight to production.
