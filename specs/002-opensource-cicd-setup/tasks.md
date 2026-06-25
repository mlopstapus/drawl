# Tasks: Drawl — Open Source Infrastructure & CI/CD

**Input**: Design documents from `specs/002-opensource-cicd-setup/`
**Prerequisites**: plan.md ✅ spec.md ✅ research.md ✅ data-model.md ✅ contracts/ ✅ quickstart.md ✅

**Organization**: Tasks are grouped by user story to enable independent implementation and delivery.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (no dependencies on other in-progress tasks)
- **[Story]**: Which user story this task belongs to (US1–US5)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the clean repo layout before any content files are added.

- [x] T001 Create `.github/workflows/`, `.github/ISSUE_TEMPLATE/`, and `scripts/` directories at the repo root
- [x] T002 Move `create_dmg.sh` from repo root to `scripts/create_dmg.sh` (git mv to preserve history) — must run after T001 since `scripts/` dir is created there
- [x] T003 [P] Update `.gitignore` to add `.claude/`, `.agents/`, `.specify/`, `context/`, `*.profraw`, `*.log` (remove `*.log` if it's already there and replace with the full set); also run `git rm --cached default.profraw drawl_run.log` to untrack the already-committed files (`.gitignore` has no effect on tracked files)
- [x] T004 [P] Create `LICENSE` at repo root — MIT license, copyright `Ben Anderson`, year `2026`
- [x] T005 [P] Update `AGENTS.md` to reference `specs/002-opensource-cicd-setup/plan.md` between the `<!-- SPECKIT START -->` and `<!-- SPECKIT END -->` markers (same change already made to `CLAUDE.md`)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Lock down SPM dependency versions so CI builds are reproducible.

**⚠️ CRITICAL**: CI builds depend on a committed `Package.resolved`; no workflow can succeed without it.

- [x] T006 Run `xcodebuild -resolvePackageDependencies -project Drawl.xcodeproj` to generate `Drawl.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`; remove the existing `.gitignore` exclusion for `*.xcworkspace` if it blocks committing this specific file; commit `Package.resolved`

**Checkpoint**: Repo layout is clean and SPM dependencies are pinned — CI can now build reproducibly.

---

## Phase 3: User Story 1 — External Contributor Submits a PR (Priority: P1) 🎯 MVP

**Goal**: Any developer can fork the repo, build locally, open a PR, and get automated pass/fail feedback within 5 minutes — all without asking the maintainer anything.

**Independent Test**: Fork the repo on a fresh machine, follow CONTRIBUTING.md, open a trivial PR (e.g., add a comment), and confirm the `Build and Test` status check appears and passes.

### Implementation

- [x] T007 [US1] Create `CONTRIBUTING.md` at repo root using `specs/002-opensource-cicd-setup/quickstart.md` as source — sections: What is Drawl?, Prerequisites, Clone and Build, Run Tests, Project Layout, Making Changes (branch naming + commit format), Opening a PR, Maintainer Setup (branch protection settings + release secrets table), Constitution summary
- [x] T008 [P] [US1] Create `CODE_OF_CONDUCT.md` at repo root using Contributor Covenant v2.1 full text; set enforcement contact email to maintainer's address
- [x] T009 [US1] Create `.github/workflows/ci.yml` per `specs/002-opensource-cicd-setup/contracts/ci-pipeline.md`:
  - (FR-015 / SC-005 note: branch protection must be configured after this workflow runs once on `main` so the `Build and Test` check name registers with GitHub — see T009a below)
  - Triggers: `on: [pull_request, push]` targeting `main`
  - Runner: `macos-15`
  - Xcode pin: `sudo xcode-select -s /Applications/Xcode_16.2.app`
  - Steps: checkout → select Xcode → resolve packages → build (`xcodebuild build -project Drawl.xcodeproj -scheme Drawl -configuration Release -destination 'platform=macOS,arch=arm64'`) → test (`xcodebuild test -project Drawl.xcodeproj -scheme DrawlTests -destination 'platform=macOS,arch=arm64' -resultBundlePath build/TestResults.xcresult`) → upload test results on failure
  - Job name MUST be `Build and Test` (used in branch protection required check)
  - No repository secrets referenced anywhere in this file

- [ ] T009a [US1] Configure branch protection on `main` **after** `ci.yml` has run at least once (so the `Build and Test` check is registered with GitHub):
  - GitHub → Settings → Branches → Add branch protection rule for `main`
  - Enable: Require pull request before merging, Required approving reviews: 1, Dismiss stale reviews, Require status checks (`Build and Test`), Require branches to be up to date, Block direct pushes
  - **Verify**: Attempt a direct push to `main` from a maintainer account and confirm it is rejected

**Checkpoint**: Push the `ci.yml` to the feature branch, open a test PR, and verify `Build and Test` appears as a passing status check within 30 minutes. Then merge to `main` and configure branch protection (T009a).

---

## Phase 4: User Story 2 — Maintainer Cuts a Release (Priority: P1)

**Goal**: Pushing a `v*.*.*` tag produces a signed, notarized DMG on GitHub Releases automatically — no manual steps beyond the git tag push.

**Independent Test**: Push `v0.1.0-test` (non-matching) → pipeline does not trigger. Push `v0.1.0` → pipeline runs, GitHub Release is created with DMG attached (once secrets are configured).

### Implementation

- [x] T010 [US2] Create `.github/workflows/release.yml` per `specs/002-opensource-cicd-setup/contracts/release-pipeline.md`:
  - Trigger: `on: push: tags: ['v[0-9]+.[0-9]+.[0-9]+']`
  - Runner: `macos-15`
  - Steps in exact order: checkout (fetch-depth: 0) → select Xcode → resolve packages → build Release → test (must pass) → import certificate to temp keychain → sign app (codesign --deep --force --options runtime) → package DMG (`bash scripts/create_dmg.sh --app-path build/Build/Products/Release/Drawl.app`) → notarize (`xcrun notarytool submit --wait --timeout 30m build/Drawl.dmg`) → staple (`xcrun stapler staple build/Drawl.dmg`) → validate (`xcrun stapler validate build/Drawl.dmg`) → delete keychain (runs `if: always()`) → create GitHub Release (`gh release create ${{ github.ref_name }} --generate-notes --title "Drawl ${{ github.ref_name }}" build/Drawl.dmg`)
  - Secrets referenced: `CERTIFICATE_P12_BASE64`, `CERTIFICATE_P12_PASSWORD`, `KEYCHAIN_PASSWORD`, `NOTARIZATION_APPLE_ID`, `NOTARIZATION_TEAM_ID`, `NOTARIZATION_APP_SPECIFIC_PASSWORD`
  - If any step before the `create GitHub Release` step fails, no release is published
- [x] T011 [P] [US2] Refactor `scripts/create_dmg.sh` for use both locally and by CI:
  - Add `--app-path <path>` argument: when provided, skip the `xcodebuild` build step and use the supplied `.app` path directly (this prevents CI from overwriting the already-signed app with an unsigned rebuild)
  - Fix `cd "$(dirname "$0")"` — after the move to `scripts/`, this changes CWD to `scripts/` which breaks the relative `Drawl.xcodeproj` path in the xcodebuild call; instead resolve the repo root as `cd "$(dirname "$0")/.."` so the script always runs from the repo root regardless of where it lives
  - Default behavior (no `--app-path`): unchanged — runs xcodebuild clean build then packages (for local developer use)
  - Output path remains `build/Drawl.dmg` in both modes

**Checkpoint**: In `release.yml`, verify no secrets are logged. Confirm the keychain cleanup step has `if: always()` so it runs even on failure.

---

## Phase 5: User Story 3 — New Contributor Understands the Project (Priority: P2)

**Goal**: A first-time visitor to the GitHub repo can answer "What does this do?", "How do I install it?", "How do I build it?", and "How do I report a bug?" within 5 minutes from the README alone.

**Independent Test**: Open the README in a GitHub preview. Answer the four questions above without clicking any links.

### Implementation

- [x] T012 [US3] Create `README.md` at repo root — sections: project title + one-line description, demo screenshot or animated GIF placeholder (`<!-- Add demo GIF here -->`), "Install" (link to latest GitHub Release), "Features" (bullet list from spec US1–US4), "Development" (link to CONTRIBUTING.md for full setup), "Contributing" (link to CONTRIBUTING.md + CODE_OF_CONDUCT.md), "Security" (link to SECURITY.md), "License" (MIT badge + link)
- [x] T013 [P] [US3] Create `.github/ISSUE_TEMPLATE/bug_report.md` with frontmatter `name: Bug Report`, `about: Report a bug`, `labels: bug`; body fields: **Describe the bug**, **Steps to reproduce**, **Expected behavior**, **Actual behavior**, **macOS version** (`sw_vers -productVersion`), **Drawl version** (from About menu), **Crash log** (if applicable)
- [x] T014 [P] [US3] Create `.github/ISSUE_TEMPLATE/feature_request.md` with frontmatter `name: Feature Request`, `about: Suggest a new feature`, `labels: enhancement`; body fields: **Problem to solve**, **Proposed solution**, **Alternatives considered**, **Additional context**
- [x] T015 [P] [US3] Create `.github/PULL_REQUEST_TEMPLATE.md` — sections: **Description** (what and why), **Related Issue** (`Closes #`), **Testing** (how to test the change manually), **Checklist** (`- [ ] Tests pass locally`, `- [ ] Follows contribution guide`, `- [ ] No secrets or credentials added`)

**Checkpoint**: Open a new GitHub Issue on the branch and confirm the bug/feature templates appear as options. Open a new PR and confirm the PR template body is pre-filled.

---

## Phase 6: User Story 4 — Security Researcher Reports a Vulnerability (Priority: P2)

**Goal**: A researcher finds the private disclosure path immediately from the repo root without needing public channels.

**Independent Test**: Navigate to the repo root on GitHub. Find `SECURITY.md`. Confirm it explains the disclosure process and a response timeline without requiring the researcher to open a public issue.

### Implementation

- [x] T016 [US4] Create `SECURITY.md` at repo root — sections: **Supported Versions** (table: current release = ✅ supported, older = ❌); **Reporting a Vulnerability** (use GitHub's "Report a security vulnerability" private reporting button — Settings → Security → Advisories, or email to maintainer if private reporting not enabled); **What to Include** (description, steps to reproduce, potential impact, macOS + Drawl version); **Response Timeline** (acknowledgement within 5 business days, status update within 14 days); **Disclosure Policy** (fix released first, public disclosure after patch is available)

**Checkpoint**: Navigate to `SECURITY.md` on GitHub. Confirm the private reporting path is clear with no ambiguity about where to send the report.

---

## Phase 7: User Story 5 — Developer Checks Project Health (Priority: P3)

**Goal**: The README shows live CI/release/license badges that reflect the real project state.

**Independent Test**: After `ci.yml` runs at least once on `main`, the CI badge in the README shows `passing`. The release badge shows the latest version after the first release.

### Implementation

- [x] T017 [US5] Update `README.md` to add three badges immediately below the project title:
  - CI badge: `[![CI](https://github.com/[owner]/drawl/actions/workflows/ci.yml/badge.svg)](https://github.com/[owner]/drawl/actions/workflows/ci.yml)`
  - Latest release badge: `[![Latest Release](https://img.shields.io/github/v/release/[owner]/drawl)](https://github.com/[owner]/drawl/releases/latest)`
  - License badge: `[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)`
  - Replace `[owner]` with the actual GitHub username/org when the repo is public

**Checkpoint**: After the first CI run on `main` succeeds, confirm the badge shows green in the README preview.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, consistency checks, and clean-up across all phases.

- [x] T018 [P] Audit all references to `create_dmg.sh` across the repo (in `release.yml`, `CONTRIBUTING.md`, any documentation) and confirm they all use the new path `scripts/create_dmg.sh`
- [x] T019 [P] Verify `.gitignore` is effective: confirm that `build/`, `.claude/`, `.agents/`, `.specify/`, `context/`, `default.profraw`, and `drawl_run.log` are all untracked by running `git status` and confirming none appear (T003 must have run `git rm --cached` for already-tracked files)
- [ ] T020 Run the quickstart validation from `specs/002-opensource-cicd-setup/quickstart.md` — follow each step as if a new contributor: clone (or use the existing checkout), run build command, run test command, confirm both succeed
- [x] T021 [P] Verify `CONTRIBUTING.md` Maintainer Setup section accurately lists all 6 required GitHub Secrets and matches the names used in `release.yml` exactly
- [x] T022 [P] Confirm `ci.yml` job name is exactly `Build and Test` (case-sensitive) so branch protection status check reference works correctly
- [ ] T023 [P] SC-006 verification: after `release.yml` runs once (can use a dry-run / test tag), inspect the workflow run log in GitHub Actions and confirm none of the 6 secret values appear in plain text; GitHub secret masking should show `***` for any accidental log echoes
- [x] T024 [P] Badge URL validation: before merging T017, replace `[owner]` with the actual GitHub username/org and confirm each badge URL resolves correctly in a browser preview

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 completion (directories must exist)
- **US1 (Phase 3)**: Depends on Foundational — needs `Package.resolved` for CI to build; T009a (branch protection) must run after `ci.yml` has executed at least once on `main`
- **US2 (Phase 4)**: Depends on Foundational; `release.yml` references `scripts/create_dmg.sh` (moved in Phase 1)
- **US3 (Phase 5)**: Can start after Phase 1 (directories exist); independent of US1/US2
- **US4 (Phase 6)**: Can start after Phase 1; fully independent — just a markdown file
- **US5 (Phase 7)**: Depends on US3 (README must exist before adding badges)
- **Polish (Phase 8)**: Depends on all phases completing

### User Story Dependencies

- **US1 (P1)**: Foundational complete → can start
- **US2 (P1)**: Foundational complete + `scripts/create_dmg.sh` moved (T002) → can start
- **US3 (P2)**: Phase 1 complete → can start in parallel with US1/US2
- **US4 (P2)**: Phase 1 complete → fully independent
- **US5 (P3)**: US3 complete (README must exist) → can start

### Parallel Opportunities Within Phases

- **Phase 1**: T002, T003, T004, T005 all run in parallel after T001
- **Phase 3**: T007 and T008 run in parallel; T009 starts after T007 (references Contributing guide content)
- **Phase 5**: T013, T014, T015 all run in parallel after T012

---

## Parallel Execution Example: Phase 1

```
T001 (create directories)
  ├──→ T002 (move script)   [sequential — scripts/ must exist]
  ├──→ T003 (gitignore + git rm --cached)  [parallel]
  ├──→ T004 (LICENSE)       [parallel]
  └──→ T005 (AGENTS.md)     [parallel]
        └──→ T006 (Package.resolved) — all Phase 1 must complete first
```

## Parallel Execution Example: Phase 3 (US1)

```
T007 (CONTRIBUTING.md) [parallel with T008]
T008 (CODE_OF_CONDUCT.md) [parallel with T007]
  └──→ T009 (ci.yml) — after T007 complete (references CONTRIBUTING.md content)
```

---

## Implementation Strategy

### MVP First (US1 + US2 — the two P1 stories)

1. Complete Phase 1: Setup (clean repo layout)
2. Complete Phase 2: Foundational (Package.resolved)
3. Complete Phase 3: US1 (contributor guide + CI workflow)
4. **STOP and VALIDATE**: Open a test PR, confirm CI runs and passes
5. Complete Phase 4: US2 (release workflow)
6. **STOP and VALIDATE**: Push a test tag, confirm pipeline runs (may need secrets configured)
7. Ship — the project is now CI/CD-enabled for contributors and releases

### Full Delivery (all 5 user stories)

After MVP, add in priority order:
- Phase 5 (US3): README + issue/PR templates — adds polish and discoverability
- Phase 6 (US4): SECURITY.md — responsible disclosure path
- Phase 7 (US5): README badges — live project health signals
- Phase 8: Polish + validation

---

## Notes

- `[P]` tasks touch different files and have no incomplete dependencies — safe to run in parallel
- `[Story]` label maps each task to the user story it enables for traceability
- No test tasks are generated — the spec does not request TDD for infrastructure files; the CI pipeline itself IS the test for the workflows
- Commit after each logical group (e.g., after Phase 1, after T009, after T010)
- `CONTRIBUTING.md` secret names table (T021 validation) is the contract between docs and release.yml — keep them in sync
