# Data Model: Drawl — Open Source Infrastructure & CI/CD

**Branch**: `002-opensource-cicd-setup` | **Date**: 2026-06-25 | **Plan**: [plan.md](plan.md)

---

## Overview

This feature is infrastructure-only. There is no persistent application data model and no
database or file-based storage added to the app itself. The entities below are conceptual
models of the CI/CD system's key objects — they inform what the pipeline workflows must
produce, validate, and track, but they exist as GitHub's internal records (workflow runs,
releases, artifacts), not as code the app manages.

---

## Entities

### Release

Represents a versioned, signed, and published build of the Drawl app.

| Attribute | Description | Validation |
|-----------|-------------|------------|
| `version` | Semantic version string (e.g., `1.0.0`) | Matches `[0-9]+\.[0-9]+\.[0-9]+` |
| `tag` | Git tag (e.g., `v1.0.0`) | Matches `v[0-9]+\.[0-9]+\.[0-9]+`; unique in repo |
| `title` | Human-readable release name (e.g., `Drawl v1.0.0`) | Non-empty string |
| `release_notes` | Changelog since previous tag | Auto-generated from merged PRs |
| `dmg_artifact` | Downloadable DMG file | Signed + notarized + stapled; `Drawl.dmg` |
| `published_at` | Timestamp when GitHub Release was created | UTC, set by GitHub |
| `status` | Outcome of the release pipeline | `success` or `failed` (no partial releases) |

**State transitions**:
```
tag pushed → pipeline triggered → build → sign → package → notarize → staple → publish
                                                                               └──→ GitHub Release (success)
           → [any step fails] → pipeline fails → no GitHub Release created
```

**Constraints**:
- A Release is only created if all steps (build, sign, notarize, staple, publish) succeed.
- The `version` in the tag must not already exist as a GitHub Release tag.
- The DMG must pass `xcrun stapler validate` before publication.

---

### CI Pipeline Run

Represents a single automated execution of the CI workflow triggered by a PR or push.

| Attribute | Description | Validation |
|-----------|-------------|------------|
| `trigger` | What caused the run | `pull_request` or `push` (tags only for release pipeline) |
| `ref` | Branch name, PR head SHA, or tag | Non-empty; format varies by trigger |
| `status` | Outcome | `success`, `failure`, `cancelled` |
| `build_passed` | Whether `xcodebuild build` succeeded | Boolean |
| `tests_passed` | Whether `xcodebuild test` succeeded | Boolean |
| `duration_seconds` | Total wall-clock time | Integer; must be < 1800 (30 min) |

**Constraints**:
- A PR cannot be merged unless `status = success` for the latest run on its head commit (enforced by branch protection).
- Secrets (`CERTIFICATE_P12_BASE64`, `NOTARIZATION_APP_SPECIFIC_PASSWORD`) are unavailable for runs triggered by fork PRs (`trigger = pull_request` from a fork).

---

### Contributor

Represents a person who opens a pull request or issue against the Drawl repository.

| Attribute | Description |
|-----------|-------------|
| `github_username` | GitHub handle |
| `fork_user` | Whether they contributed from a fork (true) or branch (false) |
| `pr_count` | Number of merged PRs |
| `role` | `external` (fork-based) or `maintainer` (push access) |

**Constraints**:
- `maintainer` role is required to push tags and trigger the release pipeline.
- `external` contributors cannot access repository secrets via CI.

---

### Secret

Represents an encrypted credential stored in GitHub for use by CI/CD workflows.

| Name | Used By | Exposed To Forks |
|------|---------|-----------------|
| `CERTIFICATE_P12_BASE64` | `release.yml` (sign step) | No |
| `CERTIFICATE_P12_PASSWORD` | `release.yml` (sign step) | No |
| `KEYCHAIN_PASSWORD` | `release.yml` (sign step) | No |
| `NOTARIZATION_APPLE_ID` | `release.yml` (notarize step) | No |
| `NOTARIZATION_TEAM_ID` | `release.yml` (notarize step) | No |
| `NOTARIZATION_APP_SPECIFIC_PASSWORD` | `release.yml` (notarize step) | No |

**Constraints**:
- All secrets are repository-scoped (not environment-scoped) for v1.
- Secrets are never printed in workflow logs; GitHub automatically masks them.
- No secret is referenced in `ci.yml`; `ci.yml` runs without any repository secrets.
