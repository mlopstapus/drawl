# Contributing to Drawl

Thank you for your interest in contributing to Drawl! This guide covers everything you need to get started.

## What is Drawl?

Drawl is a native macOS menu bar app that provides hold-to-talk voice dictation powered by a local on-device speech model (Whisper). Users hold a configurable hotkey (default ⌥+Space) to dictate; transcribed text is inserted into whatever app has focus. All processing is on-device — no audio data ever leaves the Mac.

## Prerequisites

| Tool | Minimum Version | How to Check |
|------|----------------|-------------|
| macOS | 13 (Ventura) | `sw_vers -productVersion` |
| Xcode | 15.0 | Xcode → About Xcode |
| Xcode Command Line Tools | Any current | `xcode-select --install` |
| git | Any recent | `git --version` |

An Apple Developer account is **not required** for local development or running tests. It is only needed by maintainers performing code-signing and release.

## Clone and Build

```bash
git clone https://github.com/mlopstapus/drawl.git
cd drawl

# Open in Xcode (recommended for first-time setup — resolves SPM packages)
open Drawl.xcodeproj

# Or build from the command line
xcodebuild build \
  -project Drawl.xcodeproj \
  -scheme Drawl \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64'
```

Xcode resolves Swift Package Manager dependencies automatically on first open. The `Package.resolved` file is committed so dependency versions are pinned.

**Expected build time**: < 5 minutes on first build (SPM downloads WhisperKit and GRDB); < 30 seconds on subsequent builds (incremental).

## Run Tests

```bash
xcodebuild test \
  -project Drawl.xcodeproj \
  -scheme DrawlTests \
  -destination 'platform=macOS,arch=arm64'
```

All tests are XCTest-based. Tests that require hardware (microphone, Accessibility APIs) use mock implementations and do not require physical peripherals.

## Project Layout

```
drawl/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml              # PR build + test (runs automatically on PRs)
│   │   └── release.yml         # Tag-triggered release pipeline
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   └── feature_request.md
│   └── PULL_REQUEST_TEMPLATE.md
│
├── Drawl/                      # Swift source (the app)
│   ├── App/                    # Entry point, delegates, entitlements, Info.plist
│   ├── Audio/                  # AVFoundation audio capture
│   ├── Input/                  # Accessibility text insertion
│   ├── Permissions/            # Permission request flows
│   ├── Storage/                # Preferences (UserDefaults) + history (GRDB/SQLite)
│   ├── Transcription/          # Whisper engine integration
│   └── UI/                     # Menu bar, indicator window, preferences, setup wizard
│
├── DrawlTests/                 # XCTest suite (mirrors Drawl/ structure)
├── Drawl.xcodeproj/            # Xcode project
├── scripts/
│   └── create_dmg.sh           # DMG packaging script (used by release pipeline)
│
├── CONTRIBUTING.md             # This file
├── CODE_OF_CONDUCT.md
├── SECURITY.md
├── LICENSE                     # MIT
└── README.md
```

## Making Changes

### Branch naming

```
<type>/<short-description>
```

Examples: `fix/hotkey-not-releasing`, `feat/custom-hotkey`, `docs/update-contributing`

### Commit messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>: <short description in present tense>

[optional body — explain why, not what]
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

### Opening a PR

1. Fork the repository (external contributors) or create a branch (maintainers).
2. Make your changes. Add or update tests for any behaviour changes.
3. Run the test suite locally (`xcodebuild test ...` above) — CI runs the same checks.
4. Open a PR targeting `main`. Fill in the PR template.
5. CI runs automatically. A passing `Build and Test` check is required before merge.
6. A maintainer will review and merge.

## Project Constitution

Drawl has a set of core principles that govern all implementation decisions:

1. **Privacy by Default** — Zero audio data leaves the device; no telemetry.
2. **Native Platform Citizen** — AppKit + native macOS APIs only; no Electron.
3. **Minimal Footprint** — No Dock icon at rest; < 5s launch-to-ready.
4. **Offline-First** — Core transcription works with zero network connectivity.
5. **Test-Driven** — Tests before implementation; XCTest throughout.
6. **YAGNI / Ship Simple** — Smallest working implementation; no premature abstraction.

All PRs are reviewed for constitution compliance.

## Reporting Issues

- **Bugs**: Use the Bug Report template in GitHub Issues.
- **Feature requests**: Use the Feature Request template.
- **Security vulnerabilities**: See [SECURITY.md](SECURITY.md) for private disclosure.

---

## Maintainer Setup

### Branch protection (one-time)

After `ci.yml` has run at least once on `main` (so the check name registers with GitHub):

GitHub → Settings → Branches → Add branch protection rule for `main`:
- ✅ Require pull request before merging
- ✅ Required approving reviews: **1**
- ✅ Dismiss stale reviews when new commits are pushed
- ✅ Require status checks to pass before merging → Add: **`Build and Test`**
- ✅ Require branches to be up to date before merging
- ✅ Restrict who can push to matching branches (maintainers only)

### Release secrets

No secrets are required for the current release pipeline — it builds and publishes an unsigned DMG. Users will need to right-click → Open the first time to bypass Gatekeeper.

To add code signing and notarization in the future (requires an Apple Developer Program membership, $99/year), restore the signing steps in `.github/workflows/release.yml` and add these secrets in GitHub → Settings → Secrets and Variables → Actions:

| Secret Name | How to Obtain |
|-------------|--------------|
| `CERTIFICATE_P12_BASE64` | Export Developer ID Application cert + key from Keychain Access → base64: `base64 -i cert.p12 \| tr -d '\n'` |
| `CERTIFICATE_P12_PASSWORD` | Passphrase set when exporting the .p12 |
| `KEYCHAIN_PASSWORD` | Any strong random string (used for the temporary CI keychain) |
| `NOTARIZATION_APPLE_ID` | Your Apple ID email address |
| `NOTARIZATION_TEAM_ID` | Your 10-character Team ID from developer.apple.com |
| `NOTARIZATION_APP_SPECIFIC_PASSWORD` | App-specific password from appleid.apple.com → Security |

### Cutting a release

```bash
git tag v1.0.0
git push origin v1.0.0
```

The release pipeline runs automatically. Monitor progress in GitHub → Actions → release.yml. A signed, notarized DMG is published to GitHub Releases when the pipeline succeeds.
