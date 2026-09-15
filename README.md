# GitTwig

GitTwig is a compact Git graph and sync app for the macOS menu bar.

It lets you register local Git repositories, switch between them from the menu bar, and quickly inspect the current branch, working tree status, ahead/behind counts, and recent commit graph.

## History and search

Scroll to the end of the commit list to load the next page. General settings control the number of commits loaded per page.
Search by message, author, or commit hash (at least four hexadecimal characters). Message and author searches are case-insensitive literal matches across local history, including commits not yet displayed. Search results also load in pages.
A paging session keeps its starting revisions so new commits do not shift page boundaries; Refresh starts from the latest state. Search results omit graph connections between nonadjacent matches.

## Safety

GitTwig shows changed files and supports explicit Fetch, Pull, and Push actions.
A configured remote tracking branch is required. Push shows its destination for confirmation and sends only the current branch to that tracking branch, without force.
Pull fetches the tracking branch and applies a fast-forward-only merge. It stops if there are uncommitted changes or divergent history. Resolve these cases in your editor or terminal.
Operations use your existing Git authentication; terminal prompts are disabled. Errors appear in the app. A timeout does not prove a remote operation failed; fetch to check the resulting state before retrying.

GitTwig does not provide commit, reset, stash, rebase, branch deletion, or force-push controls.
Ahead/behind counts reflect locally stored remote information; use Fetch to update them.

GitTwig stores repository paths and security-scoped bookmarks locally in `UserDefaults`.

## Privacy

GitTwig does not collect analytics or send repository paths to a telemetry server. User-requested Push sends Git objects to the configured remote.

Network access is used for user-requested Git synchronization with configured remotes and Sparkle update checks against this repository's GitHub Releases appcast. Sparkle system profiling is disabled in packaged builds.

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

The packaging script creates a `.app`, `.zip`, and `.dmg` under `dist/`. It also extracts the ZIP into a temporary folder and runs the packaged executable to verify that its icon loads and renders without the build directory. This check runs before release publication.

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
