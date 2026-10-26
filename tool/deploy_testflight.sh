#!/usr/bin/env bash
# Build SSC and upload it to TestFlight from this Mac — flutter + xcodebuild only.
#
#   ./tool/deploy_testflight.sh                    # analyze, test, archive, upload
#   ./tool/deploy_testflight.sh --skip-checks      # skip analyze + test
#   ./tool/deploy_testflight.sh --no-upload        # archive + local .ipa only
#   ./tool/deploy_testflight.sh --build-number N   # override the build number
#
# Signing is Xcode automatic signing against the App Store Connect API key (the
# App Store profile is created on demand); the upload is `xcodebuild
# -exportArchive` with destination=upload. Credentials: tool/testflight.env.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

BUNDLE_ID="com.badweather.chorus"
TEAM_ID="5LMLNW3DV5"
ENV_FILE="tool/testflight.env"

SKIP_CHECKS=0
UPLOAD=1

fail() {
  echo "error: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-checks) SKIP_CHECKS=1 ;;
    --no-upload) UPLOAD=0 ;;
    --build-number) BUILD_NUMBER="${2:?missing build number}"; shift ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    *) fail "unknown option '$1' (try --help)" ;;
  esac
  shift
done

# --- Environment -------------------------------------------------------------

[[ "$(uname -s)" == "Darwin" ]] || fail "iOS builds require macOS."
for tool in flutter xcodebuild plutil; do
  command -v "${tool}" >/dev/null || fail "'${tool}' not found in PATH."
done

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

# Minutes since the Unix epoch: always increasing, so repeat deploys from the
# same commit never collide with a build number Apple has already accepted.
: "${BUILD_NUMBER:=$(($(date +%s) / 60))}"

if [[ "${UPLOAD}" -eq 1 ]]; then
  [[ -n "${APPSTORE_CONNECT_API_KEY_ID:-}" ]] ||
    fail "APPSTORE_CONNECT_API_KEY_ID unset. Run: cp tool/testflight.env.example ${ENV_FILE}"
  [[ -n "${APPSTORE_CONNECT_ISSUER_ID:-}" ]] || fail "APPSTORE_CONNECT_ISSUER_ID unset in ${ENV_FILE}."

  # xcodebuild wants a key file; materialize inline content inside WORK_DIR.
  KEY_PATH="${APPSTORE_CONNECT_API_KEY_PATH:-}"
  if [[ -z "${KEY_PATH}" ]]; then
    [[ -n "${APPSTORE_CONNECT_API_KEY_CONTENT:-}" ]] ||
      fail "Set APPSTORE_CONNECT_API_KEY_PATH or APPSTORE_CONNECT_API_KEY_CONTENT in ${ENV_FILE}"
    KEY_PATH="${WORK_DIR}/AuthKey_${APPSTORE_CONNECT_API_KEY_ID}.p8"
    ( umask 077; printf '%s\n' "${APPSTORE_CONNECT_API_KEY_CONTENT}" >"${KEY_PATH}" )
  fi
  KEY_PATH="${KEY_PATH/#\~/$HOME}"
  [[ -f "${KEY_PATH}" ]] || fail "API key not found at ${KEY_PATH}"
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "warning: working tree is dirty; this build will not match any commit."
  read -r -p "Continue? [y/N] " reply
  [[ "${reply}" =~ ^[Yy]$ ]] || exit 1
fi

flutter pub get

if [[ "${SKIP_CHECKS}" -eq 0 ]]; then
  echo "==> flutter analyze + test (--skip-checks to bypass)"
  flutter analyze --no-fatal-infos || fail "Analyzer found problems."
  flutter test || fail "Tests failed."
fi

# --- Export options ----------------------------------------------------------

# destination=export writes a local .ipa; destination=upload sends the archive
# to App Store Connect. Everything else is identical.
write_options() {
  local path="$1" destination="$2"
  cat >"${path}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>${destination}</string>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>stripSwiftSymbols</key>
	<true/>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
PLIST
  plutil -lint "${path}" >/dev/null || fail "Generated a malformed plist at ${path}"
}

write_options "${WORK_DIR}/export.plist" export
write_options "${WORK_DIR}/upload.plist" upload

# --- Archive -----------------------------------------------------------------

echo "==> Archiving ${BUNDLE_ID} build ${BUILD_NUMBER}"
flutter build ipa \
  --release \
  --build-number="${BUILD_NUMBER}" \
  --export-options-plist="${WORK_DIR}/export.plist"

ARCHIVE="$(ls -td build/ios/archive/*.xcarchive 2>/dev/null | head -1 || true)"
[[ -n "${ARCHIVE}" ]] || fail "No .xcarchive under build/ios/archive — the archive step failed."

IPA="$(ls -t build/ios/ipa/*.ipa 2>/dev/null | head -1 || true)"
[[ -n "${IPA}" ]] && echo "==> Local artifact: ${IPA}"

if [[ "${UPLOAD}" -eq 0 ]]; then
  echo "==> --no-upload set; stopping after archive."
  exit 0
fi

# --- Upload ------------------------------------------------------------------

echo "==> Uploading to App Store Connect"
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE}" \
  -exportPath "${WORK_DIR}/upload" \
  -exportOptionsPlist "${WORK_DIR}/upload.plist" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "${KEY_PATH}" \
  -authenticationKeyID "${APPSTORE_CONNECT_API_KEY_ID}" \
  -authenticationKeyIssuerID "${APPSTORE_CONNECT_ISSUER_ID}"

echo
echo "Uploaded build ${BUILD_NUMBER}. App Store Connect -> TestFlight -> wait for processing (5-30 min)."
