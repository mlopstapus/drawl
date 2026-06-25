# Implementation Plan: Drawl — Open Source Infrastructure & CI/CD

**Branch**: `002-opensource-cicd-setup` | **Date**: 2026-06-25 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/002-opensource-cicd-setup/spec.md`

## Summary

Add the full open-source contributor and release infrastructure to the Drawl repository. The work
splits into three lanes that can proceed in parallel once the research is complete:

1. **Repository documentation** — README refresh, CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md, LICENSE, issue/PR templates.
2. **CI pipeline** — GitHub Actions workflow that builds the Xcode project and runs XCTest on every PR; reports status checks back to GitHub; never exposes secrets to fork PRs.
3. **Release pipeline** — GitHub Actions workflow triggered by `v*.*.*` tags that builds a Release DMG, code-signs and notarizes it, creates a GitHub Release, attaches the artifact, and auto-generates a changelog.

The existing `create_dmg.sh` script is the baseline for DMG packaging. It will be extended with
code-signing (`codesign`) and notarization (`xcrun notarytool`) steps inside the release workflow.
Branch protection rules lock down the `main` branch so merges require a passing CI run and at
least one approving review.

## Technical Context

**Language/Version**: Swift 5.9+ (Xcode 15+); GitHub Actions YAML for pipeline definitions
**Primary Dependencies**: xcodebuild (build + test), xcrun codesign (signing), xcrun notarytool (notarization), gh CLI (GitHub Release creation), hdiutil (DMG packaging — existing)
**Storage**: N/A (infrastructure only; no persistent data model in this feature)
**Testing**: XCTest (existing test suite); CI runs `xcodebuild test` on every PR
**Target Platform**: macOS 13+ (Ventura); GitHub-hosted `macos-15` runners for CI/CD
**Project Type**: CI/CD configuration + repository documentation (infrastructure overlay on existing Swift desktop app)
**Performance Goals**: CI check completes in under 30 minutes; release pipeline completes (including Apple notarization) in under 45 minutes
**Constraints**: Apple Developer ID certificate required for code-signing; App-Specific Password or App Store Connect API key required for notarization; secrets stored in GitHub encrypted secrets; fork PRs triggered via `pull_request` event — secrets unavailable to them by GitHub design
**Scale/Scope**: Single repository, single macOS app target, one Developer ID identity

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. Privacy by Default | ✅ PASS | CI/CD handles only build artifacts (binaries, DMGs) — no audio data, transcriptions, or user data flows through the pipeline. Secrets (signing certs) appear only in encrypted GitHub Secrets storage, never in logs. |
| II. Native Platform Citizen | ✅ PASS | All build, test, sign, and package steps use native Apple toolchain (xcodebuild, codesign, notarytool, hdiutil) on macOS runners. No third-party build wrappers introduced. |
| III. Minimal Footprint | ✅ PASS | Infrastructure adds zero runtime overhead to the app. CI is triggered only by pushes/PRs. |
| IV. Offline-First | ✅ PASS | The app's offline capability is unchanged. GitHub Actions requires network by nature, but this is pipeline infrastructure, not app runtime behavior. |
| V. Test-Driven | ✅ PASS | CI enforces `xcodebuild test` on every PR; failing tests block merge. Test suite pre-exists. |
| VI. YAGNI / Ship Simple | ✅ PASS | Scope is deliberately minimal: one CI workflow, one release workflow, standard open-source docs. No auto-update delivery, no App Store submission, no matrix builds, no Homebrew tap — deferred to future iterations. |

**Gate result**: ALL PASS — proceeding to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/002-opensource-cicd-setup/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── ci-pipeline.md
│   └── release-pipeline.md
└── tasks.md             # Phase 2 output (/speckit-tasks command)
```

### Source Code (repository root — full intended layout)

```text
drawl/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                    # PR build + test (new)
│   │   └── release.yml               # Tag-triggered sign + notarize + publish (new)
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md             # (new)
│   │   └── feature_request.md        # (new)
│   └── PULL_REQUEST_TEMPLATE.md      # (new)
│
├── Drawl/                            # Swift source (unchanged)
│   ├── App/
│   ├── Audio/
│   ├── Input/
│   ├── Permissions/
│   ├── Storage/
│   ├── Transcription/
│   └── UI/
│
├── DrawlTests/                       # XCTest suite (unchanged)
│
├── Drawl.xcodeproj/                  # Xcode project (unchanged)
│
├── scripts/
│   └── create_dmg.sh                 # Moved from repo root; release.yml uses this path
│
├── specs/                            # Feature specs (public; contains constitution)
│
├── CONTRIBUTING.md                   # (new)
├── CODE_OF_CONDUCT.md                # (new)
├── SECURITY.md                       # (new)
├── LICENSE                           # (new — MIT)
├── README.md                         # (new — badges, demo, install, dev setup)
└── project.yml                       # XcodeGen definition (unchanged)
```

**Gitignored internal tooling** (added to `.gitignore`):
```
.claude/          # AI tool configuration
.agents/          # Agent configuration
.specify/         # Speckit tooling config (specs/ directory remains public)
context/          # Internal RCA documents
*.profraw         # Profiling data
```

**Structure Decision**: All new files are documentation and CI configuration overlays.
`create_dmg.sh` moves from the root into `scripts/` for a cleaner root directory.
The Swift source (`Drawl/`, `Drawl.xcodeproj/`, `DrawlTests/`, `project.yml`) is
unchanged — the CI pipeline invokes but does not modify it. Internal AI/developer
tooling directories are gitignored so they don't appear to open source contributors.

---

## Phase 0: Research

*Resolved findings captured in [research.md](research.md)*

### Research Tasks Dispatched

| # | Question | Resolution |
|---|----------|------------|
| R-001 | Which GitHub Actions runner image supports Xcode 15+ and what xcodebuild invocation is needed? | See research.md |
| R-002 | How do we handle the `whisper.spm` package (branch dependency) reliably in CI — is package resolution deterministic? | See research.md |
| R-003 | What is the correct flow for code-signing a macOS app for distribution (Developer ID, not App Store) in a headless CI environment? | See research.md |
| R-004 | What is the correct flow for Apple notarization using `notarytool` — App-Specific Password vs App Store Connect API key? | See research.md |
| R-005 | Does the DMG itself need to be signed, notarized, and stapled (not just the .app inside it)? | See research.md |
| R-006 | How does GitHub Actions prevent secrets from leaking to fork PRs — `pull_request` vs `pull_request_target` event semantics? | See research.md |
| R-007 | How do we generate a per-release changelog from git commits using only standard tools (gh CLI + git log)? | See research.md |
| R-008 | What branch protection settings are available via GitHub API / gh CLI that can be configured without the UI? | See research.md |

---

## Phase 1: Design & Contracts

*Outputs: data-model.md, contracts/, quickstart.md (all in this spec directory)*

### 1a. Data Model

Entities from the spec that have structured attributes are captured in [data-model.md](data-model.md).

### 1b. Interface Contracts

Two pipeline contracts define the trigger conditions, inputs, required secrets, outputs, and failure behaviour for each GitHub Actions workflow:

- [contracts/ci-pipeline.md](contracts/ci-pipeline.md) — PR build + test
- [contracts/release-pipeline.md](contracts/release-pipeline.md) — tag-triggered sign + notarize + publish

### 1c. Contributor Quick Start

[quickstart.md](quickstart.md) — the developer-facing guide that will be the basis for the CONTRIBUTING.md content.

### 1d. Constitution Check (Post-Design)

Re-evaluated after Phase 1 design:

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Privacy by Default | ✅ PASS | Secret masking in GitHub Actions logs prevents certificate/password exposure. No user data in pipeline. |
| II. Native Platform Citizen | ✅ PASS | All signing/notarization via Apple's official toolchain; no third-party signing services. |
| III. Minimal Footprint | ✅ PASS | No new runtime dependencies added to the app. |
| IV. Offline-First | ✅ PASS | Unchanged. |
| V. Test-Driven | ✅ PASS | CI enforces test gate; `xcodebuild test` must pass before any merge is possible. |
| VI. YAGNI / Ship Simple | ✅ PASS | Two focused YAML workflows. No matrix strategy, no Fastlane, no Homebrew formula, no App Store lane — each is a distinct future feature if ever needed. |
