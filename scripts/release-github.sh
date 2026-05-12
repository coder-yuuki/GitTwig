#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-${MARKETING_VERSION:-0.1.0}}"
VERSION="${VERSION#v}"
TAG="v$VERSION"
REPO="${GITHUB_REPOSITORY:-coder-yuuki/GitTwig}"
APP_NAME="GitTwig"
DMG_PATH="dist/$APP_NAME-$VERSION.dmg"
ZIP_PATH="dist/$APP_NAME-$VERSION.zip"

if [[ -n "$(git status --porcelain)" ]]; then
    printf 'Working tree must be clean before creating a release.\n' >&2
    exit 1
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
    printf 'Tag already exists: %s\n' "$TAG" >&2
    exit 1
fi

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    printf 'GitHub release already exists: %s\n' "$TAG" >&2
    exit 1
fi

if [[ -z "${CODESIGN_IDENTITY:-}" ]]; then
    CODESIGN_IDENTITY="$(
        security find-identity -v -p codesigning |
            awk -F '"' '/Developer ID Application/ { print $2; exit }'
    )"
fi

if [[ -z "$CODESIGN_IDENTITY" ]]; then
    printf 'Missing Developer ID Application signing identity.\n' >&2
    exit 1
fi

: "${NOTARY_KEYCHAIN_PROFILE:?NOTARY_KEYCHAIN_PROFILE is required}"

MARKETING_VERSION="$VERSION" \
CODESIGN_IDENTITY="$CODESIGN_IDENTITY" \
NOTARIZE=1 \
scripts/package-macos.sh

git tag -a "$TAG" -m "$TAG"
git push origin "$TAG"

gh release create "$TAG" "$DMG_PATH" "$ZIP_PATH" \
    --repo "$REPO" \
    --title "$APP_NAME $VERSION" \
    --notes "$APP_NAME $VERSION"
