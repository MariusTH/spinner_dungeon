#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC_PATH="${ROOT_DIR}/pubspec.yaml"
MODE="${1:---build}"

VERSION_LINE="$(grep -E '^version:\s*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+' "${PUBSPEC_PATH}" | head -n 1 || true)"
if [[ -z "${VERSION_LINE}" ]]; then
  echo "Could not find a valid version line in ${PUBSPEC_PATH}" >&2
  exit 1
fi

if [[ ! "${VERSION_LINE}" =~ ^version:\ ([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)$ ]]; then
  echo "Unsupported version format: ${VERSION_LINE}" >&2
  exit 1
fi

MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
PATCH="${BASH_REMATCH[3]}"
BUILD="${BASH_REMATCH[4]}"

case "${MODE}" in
  --build)
    BUILD=$((BUILD + 1))
    ;;
  --patch)
    PATCH=$((PATCH + 1))
    BUILD=$((BUILD + 1))
    ;;
  --minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    BUILD=$((BUILD + 1))
    ;;
  --major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    BUILD=$((BUILD + 1))
    ;;
  *)
    echo "Unknown mode: ${MODE}" >&2
    echo "Usage: tool/bump_version.sh [--build|--patch|--minor|--major]" >&2
    exit 1
    ;;
esac

NEW_VERSION="version: ${MAJOR}.${MINOR}.${PATCH}+${BUILD}"
perl -0777 -i -pe "s/^version:\\s*\\d+\\.\\d+\\.\\d+\\+\\d+/${NEW_VERSION}/m" "${PUBSPEC_PATH}"

echo "Updated ${PUBSPEC_PATH}"
echo "${VERSION_LINE} -> ${NEW_VERSION}"
