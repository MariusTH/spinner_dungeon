# TestFlight Deployment

This project deploys iOS builds to TestFlight from GitHub Actions whenever `master` receives a push.

The workflow builds bundle id `no.mariushorne.ssc` with Apple team `5LMLNW3DV5`, marketing version `0.0.1`, and a unique build number from `GITHUB_RUN_NUMBER`.

## GitHub Secrets

Add these repository secrets in GitHub under `Settings > Secrets and variables > Actions > Repository secrets`.

- `APP_STORE_CONNECT_API_KEY_ID`: App Store Connect API key id.
- `APP_STORE_CONNECT_ISSUER_ID`: App Store Connect issuer id.
- `APP_STORE_CONNECT_API_KEY`: Full contents of the App Store Connect `.p8` private key.
- `IOS_DISTRIBUTION_CERTIFICATE_BASE64`: Base64-encoded Apple Distribution `.p12` certificate.
- `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`: Password used when exporting the `.p12` certificate.
- `IOS_PROVISIONING_PROFILE_BASE64`: Base64-encoded App Store provisioning profile for `no.mariushorne.ssc`.
- `IOS_PROVISIONING_PROFILE_NAME`: Exact provisioning profile name from Apple Developer.
- `KEYCHAIN_PASSWORD`: Any strong temporary password for the CI keychain.

## Apple Setup

1. In Apple Developer, confirm the App ID exists for `no.mariushorne.ssc` under team `5LMLNW3DV5`.
2. In App Store Connect, create the app record for bundle id `no.mariushorne.ssc` if it does not already exist.
3. Create or reuse an `Apple Distribution` certificate and export it from Keychain Access as a `.p12` file with a password.
4. Create an `App Store` provisioning profile for bundle id `no.mariushorne.ssc`, using the Apple Distribution certificate from the previous step.
5. Create an App Store Connect API key with access to upload builds. `Developer` or `App Manager` access is typically enough.

## Encoding Signing Files

Run these commands locally and paste the output into the matching GitHub secrets.

```sh
base64 -i path/to/apple_distribution.p12 | pbcopy
```

Paste that into `IOS_DISTRIBUTION_CERTIFICATE_BASE64`.

```sh
base64 -i path/to/profile.mobileprovision | pbcopy
```

Paste that into `IOS_PROVISIONING_PROFILE_BASE64`.

For `APP_STORE_CONNECT_API_KEY`, paste the full `.p8` file contents, including:

```text
-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----
```

## First Deploy

After all secrets are set, push to `master`. The workflow at `.github/workflows/testflight.yml` will run analysis, tests, an iOS archive, IPA export, and upload the IPA to TestFlight.

The first TestFlight build can take several minutes to process in App Store Connect before it is available for testers.
