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

## License

MIT
