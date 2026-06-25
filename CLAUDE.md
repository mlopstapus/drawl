<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan
at specs/002-opensource-cicd-setup/plan.md
<!-- SPECKIT END -->

## Project

Native macOS Swift app (AppKit). No web stack, no Docker, no linter configured (SwiftLint not installed).
Test scheme: `DrawlTests`. App scheme: `Drawl`. Pass `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO` for local unsigned builds.

## Key conventions

- `/.xcworkspace` is root-anchored in `.gitignore` intentionally — allows `Drawl.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` to be committed. Do not change to `*.xcworkspace`.
- DMG packaging: `scripts/create_dmg.sh`. Use `--app-path <signed.app>` to skip the internal xcodebuild rebuild when passing a pre-signed app (required by release pipeline).
- Secret scanning: `.gitleaks.toml` suppresses `build/` false positives from SPM dependency checkouts.
- `default.profraw` is gitignored. If it appears tracked, remove with `git rm --cached default.profraw`.

## Post-merge manual steps

- **Branch protection**: After `ci.yml` runs once on `main`, configure branch protection in GitHub Settings (steps in CONTRIBUTING.md#maintainer-setup).
- **Release secrets**: Six GitHub Actions secrets must be set before the release pipeline can run (see CONTRIBUTING.md#release-secrets).
