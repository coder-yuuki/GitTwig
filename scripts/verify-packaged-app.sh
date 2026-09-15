#!/usr/bin/env bash
set -euo pipefail

archive="${1:?Pass the packaged GitTwig zip}"
verification_dir="$(mktemp -d "${TMPDIR:-/tmp}/gittwig-package-check.XXXXXX")"
trap 'rm -rf "$verification_dir"' EXIT

ditto -xk "$archive" "$verification_dir"
(
    cd "$verification_dir"
    "./GitTwig.app/Contents/MacOS/GitTwig" --verify-packaged-resources
)
