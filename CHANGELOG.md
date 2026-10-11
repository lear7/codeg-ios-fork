# Changelog

All notable changes to Codeg for iOS are recorded here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Add changes under `## [Unreleased]` as you land them. When you cut a release,
`scripts/release.sh` moves that section under a new version heading and reuses
the text as the git tag message and the GitHub Release notes.

## Unreleased (fork)

### Added

- Remote relay support with QR/paste pairing, TLS certificate pinning and TOFU,
  fast LAN-to-relay failover, and custom request headers.
- Resilient streaming with large snapshots, liveness and network-change checks,
  unlimited reconnect attempts, sequence recovery, and reconciliation when a
  reply finishes during a connection gap.
- Windowed transcripts and older-page loading that preserve the reading anchor.
- Localized error mapping for network, relay, authentication, and attachment failures.
- Custom and unknown agent identities throughout sessions and agent selection.
- Folderless chat creation and management alongside project conversations.
- Side-by-side Codeg-Fork builds, XCTest coverage, and an optional UI-test target.
- Session list long-press can delete a conversation. Confirming the alert calls
  `delete_conversation` and drops the row; a failure leaves the list and shows
  the existing error banner.

### Changed

- Published fork setup and troubleshooting guidance; replaced machine-specific
  examples and E2E paths with portable configuration and removed internal logs.
- Fork home-screen name is `Codeg New`. Codemagic `ios-unsigned-sideload` and
  `scripts/build-fork.sh` pass `CODEG_DISPLAY_NAME=Codeg New`. Bundle IDs are
  unchanged. The official `project.yml` default stays `Codeg`.

### Fixed

- Unsigned Xcode 26.6 builds compile `RequestCancellation.checkDeadline`. The
  deadline closure no longer captures its result local before that local is
  declared.
- New-task "Start chat (no folder)" stays on one line on narrow phones. The
  pills sit side by side when they fit and stack when they do not.

## [Unreleased]

### Added

### Changed

- Apple signing now uses an ignored local configuration instead of a committed
  development team identifier.
### Fixed

## [1.0.1] - 2026-07-07

### Added

- **New agent types** — CodeBuddy, Kimi Code, and Pi.
- One-command release automation: `scripts/release.sh` bumps the version, files
  the release notes, tags, pushes, and creates a GitHub Release (with an
  optional `--archive` App Store Connect upload leg).
- This `CHANGELOG.md` as the home for version notes.

### Changed

- The app version is now single-sourced from `MARKETING_VERSION` /
  `CURRENT_PROJECT_VERSION` in `project.yml`.

### Fixed

- Streaming no longer rebuilds the entire transcript on every token, keeping
  long sessions smooth.
- The pending approval card is restored after a mid-turn stream reconnect.
- `Info.plist` no longer hardcodes `CFBundleShortVersionString`, which had
  silently overridden `MARKETING_VERSION` so version bumps didn't take effect.

## [1.0.0] - 2026-06-07

### Added

- Initial Codeg for iOS release.
