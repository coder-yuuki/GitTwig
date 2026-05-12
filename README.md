# GitTwig

GitTwig is a tiny read-only Git graph viewer for the macOS menu bar.

It lets you register local Git repositories, switch between them from the menu bar, and quickly inspect the current branch, working tree status, ahead/behind counts, and recent commit graph.

## Safety

GitTwig only runs read-only Git commands such as `rev-parse`, `branch`, `status`, `rev-list`, and `log`.

It does not run:

- `commit`
- `push`
- `pull`
- `fetch`
- `checkout`
- `merge`
- `rebase`
- `reset`
- `stash`
- branch creation or deletion commands

GitTwig stores repository paths and security-scoped bookmarks locally in `UserDefaults`.

## Privacy

GitTwig does not collect analytics, upload repository contents, or send repository paths to a server.

Network access is used only for Sparkle update checks against this repository's GitHub Releases appcast. Sparkle system profiling is disabled in packaged builds.

## Requirements

- macOS 13 or later
- Git
- Swift 5.9 or later for local builds

## Build

```bash
swift build -c release --product GitTwig
```

## Package

```bash
scripts/package-macos.sh
```

The packaging script creates a `.app`, `.zip`, and `.dmg` under `dist/`.

For Developer ID signing:

```bash
CODESIGN_IDENTITY="Developer ID Application: Example (TEAMID)" scripts/package-macos.sh
```

For notarization:

```bash
xcrun notarytool store-credentials GitTwigNotary

NOTARIZE=1 NOTARY_KEYCHAIN_PROFILE=GitTwigNotary scripts/package-macos.sh
```

## Release

```bash
NOTARY_KEYCHAIN_PROFILE=GitTwigNotary scripts/release-github.sh 0.1.0
```

The release script requires a Developer ID Application certificate and creates a notarized GitHub Release.

## Automated Release

Pushing a version tag builds notarized release assets and uploads them to a GitHub Release:

```bash
git tag v0.1.0
git push origin v0.1.0
```

Required GitHub Actions secrets:

- `MACOS_DEVELOPER_ID_CERTIFICATE_BASE64`
- `MACOS_DEVELOPER_ID_CERTIFICATE_PASSWORD`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `SPARKLE_ED_PRIVATE_KEY`

`MACOS_DEVELOPER_ID_CERTIFICATE_BASE64` must be a base64-encoded `.p12` export of a Developer ID Application certificate.
`SPARKLE_ED_PRIVATE_KEY` must be the exported Sparkle EdDSA private key used to sign appcast entries.
Do not commit the `.p12` file, certificate password, Apple ID password, or app-specific password.

The `gh secret set` commands can be run from any directory when `--repo` is provided:

```bash
base64 -i DeveloperID.p12 -o DeveloperID.p12.base64

gh secret set MACOS_DEVELOPER_ID_CERTIFICATE_BASE64 --repo coder-yuuki/GitTwig < DeveloperID.p12.base64
gh secret set MACOS_DEVELOPER_ID_CERTIFICATE_PASSWORD --repo coder-yuuki/GitTwig
gh secret set APPLE_ID --repo coder-yuuki/GitTwig
gh secret set APPLE_TEAM_ID --repo coder-yuuki/GitTwig
gh secret set APPLE_APP_SPECIFIC_PASSWORD --repo coder-yuuki/GitTwig
gh secret set SPARKLE_ED_PRIVATE_KEY --repo coder-yuuki/GitTwig

rm -f DeveloperID.p12 DeveloperID.p12.base64
```

## License

MIT
