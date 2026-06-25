# Contributor Quick Start: Drawl

**Branch**: `002-opensource-cicd-setup` | **Date**: 2026-06-25 | **Plan**: [plan.md](plan.md)

*This document is the source material for `CONTRIBUTING.md` at the repository root.*

---

## What is Drawl?

Drawl is a native macOS menu bar app that provides hold-to-talk voice dictation powered by
a local on-device speech model (Whisper). Users hold ⌥+Space to dictate; transcribed text
is inserted into whatever app has focus. All processing is on-device — no audio data ever
leaves the Mac.

---

## Prerequisites

| Tool | Minimum Version | How to Check |
|------|----------------|-------------|
| macOS | 13 (Ventura) | `sw_vers -productVersion` |
| Xcode | 15.0 | `xcode-select -p` then check in Xcode → About |
| Xcode Command Line Tools | Any current | `xcode-select --install` |
| git | Any recent | `git --version` |

An Apple Developer account is **not required** for local development or running tests.
It is only needed by maintainers performing code-signing and release.

---

## Clone and Build

```bash
git clone https://github.com/[org]/drawl.git
cd drawl

# Open in Xcode (recommended for first-time setup to resolve SPM packages)
open Drawl.xcodeproj

# Or build from the command line
xcodebuild build \
  -project Drawl.xcodeproj \
  -scheme Drawl \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64'
```

Xcode resolves Swift Package Manager dependencies automatically on first open.
The `Package.resolved` file is committed, so dependency versions are pinned.

**Expected build time**: < 5 minutes on first build (SPM downloads whisper.spm and GRDB);
< 30 seconds on subsequent builds (incremental).

---

## Run Tests

```bash
xcodebuild test \
  -project Drawl.xcodeproj \
  -scheme DrawlTests \
  -destination 'platform=macOS,arch=arm64'
```

All tests are XCTest-based. Tests that require hardware (microphone, Accessibility APIs)
use mock implementations and do not require physical peripherals to run.

---

## Project Layout

```
drawl/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml              # PR build + test (auto-runs on PRs)
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
│
├── Drawl.xcodeproj/            # Xcode project
├── project.yml                 # XcodeGen project definition
│
├── CONTRIBUTING.md             # This document (abbreviated)
├── CODE_OF_CONDUCT.md
├── SECURITY.md
├── LICENSE                     # MIT
├── README.md
└── create_dmg.sh               # DMG packaging script (used by release pipeline)
```

---

## Making Changes

### Branch naming

```
<type>/<short-description>
```

Examples: `fix/hotkey-not-releasing`, `feat/custom-hotkey`, `docs/update-contributing`

### Commit messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>: <short description>

[optional body]
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

### Opening a PR

1. Fork the repository (external contributors) or create a branch (maintainers).
2. Make your changes. Add or update tests for any behaviour changes.
3. Run the test suite locally (`xcodebuild test ...` above) — CI will run the same.
4. Open a PR targeting `main`. Fill in the PR template.
5. CI runs automatically. A passing `Build and Test` check is required before merge.
6. A maintainer will review and merge.

---

## Maintainer Setup (one-time)

### Branch protection

In GitHub → Settings → Branches → Add rule for `main`:
- Require pull request before merging ✓
- Required approving reviews: 1
- Dismiss stale reviews ✓
- Require status checks: `Build and Test` (from `ci.yml`)
- Require branches to be up to date ✓
- Restrict pushes to main: maintainers only ✓

### Release secrets

In GitHub → Settings → Secrets and Variables → Actions, add:

| Secret Name | How to Obtain |
|-------------|--------------|
| `CERTIFICATE_P12_BASE64` | Export Developer ID Application cert + key from Keychain → base64 encode: `base64 -i cert.p12 \| tr -d '\n'` |
| `CERTIFICATE_P12_PASSWORD` | The passphrase you set when exporting the .p12 |
| `KEYCHAIN_PASSWORD` | Any strong random password (used for the temp CI keychain) |
| `NOTARIZATION_APPLE_ID` | Your Apple ID email |
| `NOTARIZATION_TEAM_ID` | Your 10-character Team ID from developer.apple.com |
| `NOTARIZATION_APP_SPECIFIC_PASSWORD` | App-specific password from appleid.apple.com |

### Cutting a release

```bash
git tag v1.0.0
git push origin v1.0.0
```

The release pipeline runs automatically. Monitor it in GitHub → Actions → release.yml.

---

## Constitution

Drawl has a project constitution at `.specify/memory/constitution.md` that governs all
implementation decisions. Key principles:

1. **Privacy by Default** — zero audio data leaves the device; no telemetry.
2. **Native Platform Citizen** — AppKit + native macOS APIs only; no Electron.
3. **Minimal Footprint** — no Dock icon at rest; < 5s launch-to-ready.
4. **Offline-First** — core transcription works with zero network connectivity.
5. **Test-Driven** — tests before implementation; XCTest throughout.
6. **YAGNI / Ship Simple** — smallest working implementation; no premature abstraction.

All PRs are reviewed for constitution compliance.

---

## Reporting Issues

- **Bugs**: Use the Bug Report template in GitHub Issues.
- **Feature requests**: Use the Feature Request template.
- **Security vulnerabilities**: See `SECURITY.md` for the private disclosure process.
- **Questions**: GitHub Discussions (if enabled) or open a plain Issue.
