#!/usr/bin/env bash
# Build SSC and install it on a physical phone (cable or wireless), without
# going through TestFlight.
#
#   ./tool/deploy_phone.sh                 # release build, first physical device
#   ./tool/deploy_phone.sh --debug         # debug build, stays attached (hot reload)
#   ./tool/deploy_phone.sh --profile       # profile build (perf testing)
#   ./tool/deploy_phone.sh -d <device-id>  # pick a device (see `flutter devices`)
#   ./tool/deploy_phone.sh --skip-checks   # skip analyze + test
#
# Release/profile builds are installed and then detached, so the app keeps
# working after you unplug. iOS signing uses the Automatic team already set in
# ios/Runner.xcodeproj (5LMLNW3DV5); the phone must have Developer Mode on.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

MODE="release"
DEVICE_ID=""
SKIP_CHECKS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release) MODE="release" ;;
    --profile) MODE="profile" ;;
    --debug) MODE="debug" ;;
    -d|--device) DEVICE_ID="${2:?missing device id}"; shift ;;
    --skip-checks) SKIP_CHECKS=1 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

# Pick the first non-emulator iOS/Android device when none was given.
if [[ -z "${DEVICE_ID}" ]]; then
  DEVICE_ID="$(
    flutter devices --machine 2>/dev/null | python3 -c '
import json, sys
for d in json.load(sys.stdin):
    if not d.get("emulator") and d.get("targetPlatform", "").startswith(("ios", "android")):
        print(d["id"]); break
'
  )"
fi
if [[ -z "${DEVICE_ID}" ]]; then
  echo "No physical phone found. Plug it in (or join the same Wi-Fi), unlock it," >&2
  echo "and check \`flutter devices\`. Then retry, optionally with -d <id>." >&2
  exit 1
fi

PLATFORM="$(
  flutter devices --machine 2>/dev/null | DEVICE_ID="${DEVICE_ID}" python3 -c '
import json, os, sys
for d in json.load(sys.stdin):
    if d["id"] == os.environ["DEVICE_ID"]:
        print(d.get("targetPlatform", "")); break
'
)"
echo "==> Deploying ${MODE} build to ${DEVICE_ID} (${PLATFORM:-unknown platform})"

flutter pub get

if [[ "${SKIP_CHECKS}" -eq 0 ]]; then
  echo "==> flutter analyze + test (same gate as CI; --skip-checks to bypass)"
  flutter analyze --no-fatal-infos
  flutter test
fi

if [[ "${MODE}" == "debug" ]]; then
  # Debug builds only run while attached; this keeps the session open for
  # hot reload (r) / restart (R) / quit (q).
  exec flutter run --debug -d "${DEVICE_ID}"
fi

case "${PLATFORM}" in
  ios*) flutter build ios "--${MODE}" ;;
  android*) flutter build apk "--${MODE}" ;;
  *) echo "Unsupported platform '${PLATFORM}' for ${DEVICE_ID}" >&2; exit 1 ;;
esac

flutter install "--${MODE}" -d "${DEVICE_ID}"
echo "==> Installed. Open \"Spin Spin Carnage\" on the phone."
