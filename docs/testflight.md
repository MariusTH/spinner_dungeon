# TestFlight Deploy

Deploys run from a Mac; there is no CI path.

```bash
./tool/deploy_testflight.sh
```

It runs `flutter analyze` + `flutter test`, archives via `flutter build ipa`
(build number = minutes since the Unix epoch, marketing version from
`pubspec.yaml`), then uploads with `xcodebuild -exportArchive` using
`destination: upload`. Signing is Xcode automatic signing; the App Store
provisioning profile is created on demand through the API key.

Flags: `--skip-checks`, `--no-upload` (archive + local .ipa only),
`--build-number N`.

Everything below is one-time setup.

## 1. App Store Connect app record

The upload is rejected if the app does not already exist.

- [ ] [App Store Connect](https://appstoreconnect.apple.com) → **Apps** → **+** → New App
- [x] Created: bundle ID `com.badweather.chorus`, SKU `spin-spin-carnage`,
      Apple ID `6827164261`

## 2. API key

Same Team Key as the other apps on team `5LMLNW3DV5` works.

- [ ] **Users and Access → Integrations → App Store Connect API** → a **Team
      Key** with role **App Manager** (an Individual key cannot reach
      provisioning endpoints)
- [ ] Note the **Key ID** and **Issuer ID**; keep the `.p8`

## 3. Distribution certificate

- [ ] `security find-identity -v -p codesigning | grep "Apple Distribution"`
      — if missing: Xcode → Settings → Accounts → Manage Certificates → + →
      Apple Distribution

## 4. Credentials file

```bash
cp tool/testflight.env.example tool/testflight.env   # gitignored
```

Fill in `APPSTORE_CONNECT_API_KEY_ID`, `APPSTORE_CONNECT_ISSUER_ID`, and either
`APPSTORE_CONNECT_API_KEY_PATH` or `APPSTORE_CONNECT_API_KEY_CONTENT`.

## 5. After upload

1. **TestFlight** → wait for processing (5–30 min). Export compliance is
   answered by `ITSAppUsesNonExemptEncryption = false` in `Info.plist`.
2. **Internal Testing** → create a group → add testers.
3. Testers accept the invite in the TestFlight app.
