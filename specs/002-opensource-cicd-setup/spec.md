# Feature Specification: Drawl — Open Source Infrastructure & CI/CD

**Feature Branch**: `002-opensource-cicd-setup`
**Created**: 2026-06-25
**Status**: Draft
**Input**: User description: "Structure the drawl project as an open source project with releases and CI/CD ready for contributors."

## User Scenarios & Testing *(mandatory)*

### User Story 1 — External Contributor Submits a Pull Request (Priority: P1)

A developer discovers Drawl on GitHub, wants to fix a bug or add a feature, and follows the contribution guide to fork the repo, set up a local build, and open a pull request. Automated checks run immediately on their PR — building the app, running tests — and they receive clear feedback on whether their change is ready. A maintainer reviews the PR and merges it using a documented workflow.

**Why this priority**: Without clear contribution pathways and automated validation, external contributors cannot participate confidently. This is the foundation of any open source project.

**Independent Test**: A person with no prior knowledge of the project can fork the repo, follow CONTRIBUTING.md to build locally, open a PR with a trivial change (e.g., a typo fix), and see automated CI status checks pass — all without asking the maintainer for help.

**Acceptance Scenarios**:

1. **Given** a developer forks the repository, **When** they follow the documented setup steps in CONTRIBUTING.md, **Then** they can build and run the app locally within 30 minutes on a supported macOS version.
2. **Given** a contributor opens a pull request, **When** the PR is created, **Then** automated checks run within 5 minutes and report build and test results as GitHub status checks.
3. **Given** a PR has all checks passing, **When** a maintainer approves and merges it, **Then** the merge is recorded in version control with the PR linked.
4. **Given** a contributor's PR has a failing check, **When** they view the PR, **Then** they see a clear error message indicating what failed and how to reproduce it locally.

---

### User Story 2 — Maintainer Cuts a Release (Priority: P1)

A maintainer is ready to ship a new version of Drawl. They tag a version in git using semantic versioning, and an automated pipeline builds, code-signs, notarizes, and packages the app as a DMG. The pipeline then creates a GitHub Release, attaches the DMG, and publishes release notes generated from the commit log. Users can download a verified, ready-to-install DMG directly from the GitHub Releases page.

**Why this priority**: Reproducible, automated releases remove human error from the shipping process, ensure every release is signed/notarized (so macOS Gatekeeper accepts it), and give users a trustworthy download.

**Independent Test**: A maintainer creates a git tag `v0.2.0`, pushes it, and within 30 minutes a GitHub Release appears with an attached DMG that a fresh macOS user can download, open, and install without a Gatekeeper warning — without the maintainer doing anything beyond pushing the tag.

**Acceptance Scenarios**:

1. **Given** a maintainer pushes a tag matching `v*.*.*`, **When** the pipeline completes, **Then** a GitHub Release is created with the version tag, a release title, and a changelog of commits since the previous tag.
2. **Given** a release is triggered, **When** the pipeline builds successfully, **Then** the DMG attached to the release is code-signed with a valid Apple Developer identity and notarized by Apple.
3. **Given** a user downloads the release DMG, **When** they open it on a Mac that has never run the app, **Then** macOS accepts the app without a Gatekeeper warning.
4. **Given** the pipeline fails during a release, **When** a maintainer views the pipeline run, **Then** they see a clear failure message and no partial GitHub Release is published.

---

### User Story 3 — New Contributor Understands the Project (Priority: P2)

A developer lands on the Drawl GitHub repository for the first time. Within a few minutes of reading the README they understand what the app does, how to install it (for end-users), how to set up a development environment (for contributors), and how the project is governed (license, code of conduct, contribution process).

**Why this priority**: A clear, professional README and supporting documents establish trust and reduce friction for both users and contributors. Without this, the project appears incomplete regardless of code quality.

**Independent Test**: A person unfamiliar with Drawl can answer these four questions from the README alone within 5 minutes: (1) What does this app do? (2) How do I install it? (3) How do I build it from source? (4) How do I report a bug?

**Acceptance Scenarios**:

1. **Given** a user visits the GitHub repository, **When** they read the README, **Then** they find: a description, a screenshot or demo GIF, installation instructions (link to latest release DMG), a development setup section, and links to CONTRIBUTING.md and the issue tracker.
2. **Given** a contributor wants to report a bug, **When** they open a new GitHub Issue, **Then** they are presented with a structured bug report template that prompts for steps to reproduce, expected behavior, actual behavior, and macOS version.
3. **Given** a contributor wants to request a feature, **When** they open a new GitHub Issue, **Then** they are presented with a feature request template asking for the problem, proposed solution, and alternatives.
4. **Given** a contributor opens a PR without filling in the template, **When** they submit it, **Then** the PR template reminds them of what to include (description, testing steps, related issue).

---

### User Story 4 — Security Researcher Reports a Vulnerability (Priority: P2)

A security researcher finds a potential vulnerability in Drawl. They look for responsible disclosure guidance in the repository and find a SECURITY.md file with clear instructions on how to privately report the issue, what information to include, and what response time to expect. The maintainer receives the report privately, addresses it, and releases a fix with an appropriate disclosure notice.

**Why this priority**: A public issue tracker is inappropriate for security disclosures. Without a security policy, researchers may either disclose publicly (damaging users) or not report at all.

**Independent Test**: A researcher can find SECURITY.md from the repository root, understand the disclosure process, and submit a private report without needing to contact the maintainer through public channels.

**Acceptance Scenarios**:

1. **Given** a researcher visits the repository, **When** they look for a security policy, **Then** they find a SECURITY.md in the repository root describing the private disclosure process (e.g., GitHub private vulnerability reporting or a designated email).
2. **Given** a researcher submits a private report, **When** it is received, **Then** the SECURITY.md sets expectations for a response acknowledgement within 5 business days.

---

### User Story 5 — Developer Checks Project Health at a Glance (Priority: P3)

A developer considering using or contributing to Drawl visits the repository and sees status badges in the README showing the current build status, latest release version, and license. These badges give an immediate signal that the project is actively maintained and in a healthy state.

**Why this priority**: Badges provide social proof and signal to potential contributors that the project has automated quality gates in place.

**Independent Test**: The README displays at minimum three status badges (CI build, latest release version, license) that accurately reflect the real-time state of the project.

**Acceptance Scenarios**:

1. **Given** the main branch build is passing, **When** a user views the README, **Then** a CI badge displays a green "passing" state.
2. **Given** a new release is published, **When** a user views the README, **Then** the release badge updates to show the new version number.

---

### Edge Cases

- What happens if the code-signing certificate is expired or unavailable during a release run? The pipeline fails with a clear error; no unsigned artifact is published.
- What happens if a contributor opens a PR from a fork (not a branch)? CI must still run, but secrets (e.g., signing keys) must not be exposed to fork PRs.
- What happens if a tag is pushed that doesn't match the version pattern (e.g., `test-tag`)? The release pipeline does not trigger.
- What happens if two maintainers push release tags simultaneously? Each tag triggers an independent pipeline; both releases are created for their respective tags.
- What happens if notarization takes longer than expected (Apple's service can be slow)? The pipeline waits up to 30 minutes before failing with a timeout error.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The repository MUST include a CONTRIBUTING.md that covers: prerequisites, local build steps, branching and commit conventions, how to run tests, and the PR review process.
- **FR-002**: The repository MUST include a CODE_OF_CONDUCT.md (e.g., Contributor Covenant) linked from CONTRIBUTING.md and the README.
- **FR-003**: The repository MUST include a SECURITY.md with a private vulnerability disclosure process and expected response timeline.
- **FR-004**: The repository MUST include a LICENSE file containing the full license text.
- **FR-005**: The repository MUST include a `.github/ISSUE_TEMPLATE/` directory with at minimum a bug report template and a feature request template.
- **FR-006**: The repository MUST include a `.github/PULL_REQUEST_TEMPLATE.md` prompting contributors for a description, testing steps, and linked issue.
- **FR-007**: The CI pipeline MUST automatically run on every pull request targeting the main branch and report pass/fail status back to GitHub.
- **FR-008**: The CI pipeline MUST build the macOS app and run the test suite on every PR; a failing build or test MUST block merge.
- **FR-009**: The release pipeline MUST trigger automatically when a git tag matching `v[0-9]+.[0-9]+.[0-9]+` is pushed to the repository.
- **FR-010**: The release pipeline MUST produce a code-signed and Apple-notarized DMG artifact.
- **FR-011**: The release pipeline MUST create a GitHub Release, attach the DMG, and generate a changelog from commits since the previous version tag.
- **FR-012**: Code-signing credentials MUST be stored as encrypted repository secrets and MUST NOT be exposed to pull requests from forks.
- **FR-013**: The README MUST be updated to include: a project description, a demo or screenshot, end-user installation instructions (link to latest release), development setup instructions, and links to CONTRIBUTING.md, CODE_OF_CONDUCT.md, and the issue tracker.
- **FR-014**: The README MUST display CI status, latest release version, and license badges.
- **FR-015**: The main branch MUST be protected: direct pushes are blocked, at least one approving review is required, and all required CI checks must pass before merging.

### Key Entities

- **Release**: A versioned, signed, and published build of the app identified by a semver tag (e.g., `v1.0.0`), associated with a GitHub Release entry and a DMG artifact.
- **CI Pipeline Run**: An automated execution triggered by a PR or tag push that builds the app, runs tests, and (for releases) packages and publishes artifacts. Records pass/fail status and logs.
- **Contributor**: Any person who forks the repository, makes changes, and opens a pull request. May not have write access to the repository.
- **Maintainer**: A person with write access to the repository who can approve PRs, push tags, and manage repository settings.
- **Secret**: An encrypted credential (e.g., Apple Developer certificate, notarization API key) stored in GitHub and available only to trusted pipeline runs, not fork PRs.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer with macOS experience and no prior knowledge of Drawl can fork the repo, follow CONTRIBUTING.md, and produce a working local build in under 30 minutes.
- **SC-002**: CI checks begin running on a new PR within 5 minutes of the PR being opened.
- **SC-003**: A full release — from pushing a version tag to a notarized DMG published on GitHub Releases — completes within 45 minutes under normal conditions.
- **SC-004**: 100% of public DMG releases pass macOS Gatekeeper verification without requiring the user to bypass security settings.
- **SC-005**: The main branch cannot be merged to without at least one approving review and all required CI checks passing (enforced by branch protection).
- **SC-006**: Zero code-signing secrets or credentials appear in public CI logs or artifact outputs.
- **SC-007**: A new contributor can identify where to report a bug, request a feature, or disclose a security issue — all from the repository root — without asking a maintainer.

## Assumptions

- The project is hosted on GitHub; GitHub Actions is used for CI/CD; GitHub Releases is used for distribution.
- The maintainer holds an Apple Developer Program membership with a valid Developer ID certificate for code-signing and notarization.
- The initial open source license is MIT (permissive); if a different license is preferred, the license file content changes but the infrastructure is the same.
- Branch protection settings are configurable by the maintainer in GitHub repository settings; no third-party branch protection service is required.
- Fork PRs from external contributors run CI but do not have access to encrypted secrets; release signing only runs on tags pushed by maintainers.
- The existing `create_dmg.sh` script is the baseline for DMG packaging; the CI/CD pipeline will invoke or replace it as appropriate during the planning phase.
- Semantic versioning (MAJOR.MINOR.PATCH) is used for all releases.
- The Drawl app is already buildable from source (Xcode project exists); this feature adds automation and documentation, not build system changes.
