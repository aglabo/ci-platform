---
title: "ci-platform Change Log"
version: "0.3.1"
date: 2026-06-22
tags:
  - release
  - composite-actions
  - ci-platform
summary: >
  v0.3.1 adds the ca-get-changed-files composite action for detecting changed files
  between commits in push events.
---

<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/max-comma
  -->

## [0.3.1] - 2026-06-22

### Overview

This release adds `ca-get-changed-files`, a composite action that detects changed files
between before/after commits in push events.

It supports glob pattern filtering and outputs the changed file list and count,
enabling downstream jobs and steps to use them for conditional branching or file processing.

---

### Added

#### Composite Actions

- `ca-get-changed-files`: Detects changed files between commits in push events.
  Accepts an optional `pattern` input for glob filtering, and exposes `before-sha` / `after-sha`
  inputs to override the default commit SHAs (`github.event.before` / `github.sha`).
  Outputs `files` (newline-separated paths) and `count` (number of changed files).
  Requires `actions/checkout` with `fetch-depth: 0`.

---

### Notes

- `ca-get-changed-files` behavior is verified by integration tests covering
  no-pattern, pattern-match, and pattern-no-match scenarios.

---

## [0.3.0] - 2026-06-21

### Overview

This release standardizes naming conventions across composite actions and reusable workflows,
adds a new `ca-setup-repo` composite action, and introduces a Docusaurus-based documentation site.

All caller workflows now reference reusable workflows and composite actions via pinned external
repository SHA instead of local paths.

**Breaking change:** Composite action directory names have changed. Update external references
from `validate-environment`, `setup-tool`, and `setup-tool-repo` to `ca-validate-environment`,
`ca-setup-tool`, and `ca-setup-repo`.

---

### Added

#### Composite Actions

- `ca-setup-repo`: Checks out an external repository, installs dependencies via pnpm,
  and adds its `bin/` directory to `GITHUB_PATH`.
  Includes input validation, duplicate-checkout detection via `.repo` marker files,
  and atomic locking to prevent race conditions.

#### CI / Workflows

- `ci-publish-docs.yml`: Builds the Docusaurus site and deploys it to GitHub Pages.
  Replaces the removed `static.yml`.
- `_tests_ca_composite-actions.yml`: Added test jobs for `ca-setup-tool` and `ca-setup-repo`.

#### Documentation

- Docusaurus versioning configured for v0.3.0 as the default stable version.
- Developer Guide: overview, core philosophy, gate pattern, architecture, design principles,
  security model, and versioning/release policy.
- User Guide: platform overview, how-to-use, validate-environment reference, quickstart,
  basic scenarios, troubleshooting, and feedback.

---

### Changed

#### Naming Conventions

- Renamed `validate-environment` → `ca-validate-environment`.
- Renamed `setup-tool` → `ca-setup-tool`.
- Renamed `setup-tool-repo` → `ca-setup-repo`.
- Renamed reusable workflows with `ru-` prefix:
  - `ci-qa-actionlint.yml` → `ru-qa-actionlint.yml`
  - `ci-qa-ghalint.yml` → `ru-qa-ghalint.yml`
  - `ci-scan-betterleaks.yml` → `ru-scan-betterleaks.yml`

#### Workflow References

- All caller workflows now use pinned external repository SHA references
  (`aglabo/ci-platform@<sha>`) instead of local paths.

---

### Improved

- Replaced `rg --files` with `fd -tf` for file enumeration in runner libs.
- Replaced loop-based executable validation in `ca-setup-repo` with `find` + `grep`
  for better reliability and space-safe path handling.
- Updated website dependencies: Node.js engine requirement raised to `>=22.0`,
  pnpm `>=10.0` added.

---

### Notes

- `_tests_ca_composite-actions.yml` keeps local path references intentionally
  to test composite actions within the same repository.

---

## [0.2.1] - 2026-06-13

### Overview

Patch release restoring local workflow references that were prematurely changed to
external pins in v0.2.0. Also updates pinned action SHAs to the v0.2.1 commit hash.

---

### Fixed

- Reverted reusable workflow references in `ci-scan-secrets.yml` and `ci-workflows-qa.yml`
  back to local paths after premature external pinning.
- Restored `build` job in `ci-publish-docs.yml` that was accidentally removed.

### Changed

- Updated pinned SHA references for `validate-environment` and `setup-tool` actions
  to v0.2.1 commit hash across `ci-qa-ghalint.yml` and `ci-scan-betterleaks.yml`.
- Updated `actions/checkout` from v6.0.2 to v6.0.3 in `ci-scan-betterleaks.yml`.

---

## [0.1.0] - 2026-02-21

### Overview

Initial public foundation release of the **validate-environment** GitHub Action.

This release establishes a structured validation framework for CI environments.
It includes runner verification, application validation, and GitHub token permission checks.
It introduces a comprehensive ShellSpec-based testing architecture.
It also establishes standardized repository governance.

v0.1.0 provides a stable baseline for reusable CI platform actions across the ecosystem.

---

### Added

#### Environment Validation

- Runner OS validation
- Application existence and version validation
- GitHub token permission validation
  - Supports explicit permission checks
  - Adds flexible `any` permission type

#### Testing & CI

- ShellSpec-based test framework
- Comprehensive unit tests for runner and validation architecture
- CI scanning workflow (`scan-all`)
- CI linting configuration

#### Developer Tooling

- Commit message generator script and agent
- Development setup scripts
- Test runner scripts
- Lefthook integration

#### Repository Governance

- LICENSE, README, SECURITY policy
- AI collaboration guidelines (`CLAUDE.md`)
- Documentation lint configuration
- Commit and secret validation rules
- Renovate configuration
- git-cliff changelog configuration

### Improved

- Simplified validation scripts for clarity and maintainability
- Reduced global variables in runner validation
- Unified validation output format
- Improved OS detection logic
- Increased test coverage across validation modules

### Notes

This version focuses on architectural stability and reproducibility.
Future releases will expand reusable workflows and additional CI platform utilities.
