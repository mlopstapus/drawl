# Contract: CI Pipeline (`ci.yml`)

**Workflow file**: `.github/workflows/ci.yml`
**Feature**: Open Source Infrastructure & CI/CD | [plan.md](../plan.md)

---

## Trigger Contract

| Event | Conditions | Runs on |
|-------|-----------|---------|
| `pull_request` | Targeting `main` branch | GitHub-hosted `macos-15` |
| `push` | To `main` branch (post-merge validation) | GitHub-hosted `macos-15` |

**Fork PR behaviour**: Runs without any repository secrets. `GITHUB_TOKEN` is read-only.
The workflow MUST NOT reference any repository secrets — this is enforced by design (no secret references in the YAML).

---

## Job: `build-and-test`

### Inputs

| Input | Source | Notes |
|-------|--------|-------|
| Xcode project | `Drawl.xcodeproj` at repo root | Resolved via `Package.resolved` |
| Scheme (build) | `Drawl` | Must produce `Drawl.app` in `Release` config |
| Scheme (test) | `DrawlTests` | Must reference host app target |
| Destination | `platform=macOS,arch=arm64` | Matches M-series runner architecture |

### Steps

1. **Checkout** — `actions/checkout@v4` (full history not required)
2. **Select Xcode** — `sudo xcode-select -s /Applications/Xcode_16.2.app` (pin version)
3. **Resolve packages** — `xcodebuild -resolvePackageDependencies` (uses `Package.resolved`)
4. **Build** — `xcodebuild build -project Drawl.xcodeproj -scheme Drawl -configuration Release -destination 'platform=macOS,arch=arm64'`
5. **Test** — `xcodebuild test -project Drawl.xcodeproj -scheme DrawlTests -destination 'platform=macOS,arch=arm64' -resultBundlePath build/TestResults.xcresult`
6. **Upload test results** (on failure) — `actions/upload-artifact` with `build/TestResults.xcresult`

### Outputs

| Output | Type | Success Condition |
|--------|------|-----------------|
| Build status | GitHub check (`Build and Test`) | All 6 steps exit 0 |
| Test result bundle | Artifact (on failure only) | Uploaded for debugging |

### Failure Behaviour

- Any step failure marks the job `failure`.
- The GitHub check `Build and Test` turns red on the PR.
- Merge is blocked by branch protection until the check passes.
- No artifacts are uploaded on success (keeps storage usage minimal).

### Secrets Used

**None.** This workflow intentionally uses no repository secrets.

---

## Performance Contract

| Metric | Target | Action if Violated |
|--------|--------|-------------------|
| Total job duration | < 30 minutes | Investigate slow package resolution or test suite |
| PR check start latency | < 5 minutes after PR open | No action (GitHub runner queue; not controllable) |

---

## Status Check Name

GitHub branch protection must reference this exact check name:

```
Build and Test
```

This is the value set via the `name:` field of the job in `ci.yml`.
