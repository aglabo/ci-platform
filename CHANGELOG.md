---
title: "ci-platform Change Log"
version: "0.3.5"
date: 2026-09-18
tags:
  - release
  - composite-actions
  - ci-platform
summary: >
  v0.3.5 closes all Dependabot alerts on the documentation site, unifies the pnpm and
  Node.js version requirements across the repository, adds MDX support to textlint,
  and switches the repository `.gitignore` to an allowlist.
---

<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/max-comma
  -->

## [0.3.5] - 2026-09-18

### Overview

This release closes every outstanding Dependabot alert on the documentation site.

It also unifies the pnpm and Node.js version requirements across the repository
and switches `.gitignore` to an allowlist. On the documentation side,
textlint gains MDX support.

No changes were made to composite action or reusable workflow interfaces.
The `on`/`inputs`/`outputs` keys of every `action.yml` and `ru-*.yml` are identical to v0.3.4;
callers require no changes.

Note that the default value of the `pnpm-version` input of `ca-setup-repo` was changed
from `"10"` to `"11.22.0"`. Consumers that do not set this input explicitly will run pnpm 11.22.0.

---

### Added

#### Documentation Tooling

- `textlint`: Enabled the MDX plugin, allowing `.mdx` files to be linted.
- `run-textlint.sh`: Enabled caching, stored at `.cache/textlint/textlintCache`.

---

### Fixed

- Updated all vulnerable dependencies in the documentation site and closed the
  Dependabot alerts: `joi` (18.2.9), `react`/`react-dom` (19.3.0), `nanoid` (3.3.18),
  `js-yaml`, and `fast-uri`.

---

### Changed

#### GitHub Actions

- `ca-setup-repo`: Changed the default of the `pnpm-version` input from `"10"` to `"11.22.0"`.
- Bumped `pnpm/action-setup` from v6.0.10 to v6.1.0.
- Bumped `actions/deploy-pages` from v5.0.0 to v5.0.1.
- Pinned reusable workflow and composite action refs to the v0.3.4 commit (`d49d965`).
- `ci-publish-docs.yml`: Dropped the explicit pnpm version and delegated it to
  the `packageManager` field in `package.json`.

#### Development Environment

- `package.json`: Added `packageManager: pnpm@12.4.2` and `engines` of `node >=24` / `pnpm >=12`.
- `aglabo.github.io/package.json`: Aligned to the same pnpm 12.4.2 and Node.js 24 requirements.
- Switched `.gitignore` to an allowlist: everything is ignored by default and
  repository content is allowed explicitly.
- `.claude/.gitignore`: Narrowed the `.git*` exception to `.gitignore` only.
- `aglabo.github.io/.gitignore`: Added the `versioned_sidebars` directory to tracked paths.
- `dprint`: Migrated the TypeScript, JSON, Markdown, YAML, and TOML plugins to npm packages,
  and bumped the JSON and Markdown plugins to 0.24.0 and the TOML plugin to 0.8.0.
- `.editorconfig`: Moved shell and PowerShell formatting rules into dedicated sections
  and removed duplicate shfmt settings.
- `lefthook.yml`: Changed the `prepare-commit-msg` model from `gpt-5.4-mini` to `gpt-5.6-luna`.

#### Documentation

- Updated the documented default pnpm version to `11.22.0` across the user guide
  and the `docs/.deckrd/` design documents.
- Standardized punctuation and parenthesis notation, and normalized nested list indentation.

---

### Notes

- This release contains no composite action or reusable workflow interface changes.
  The only edits to those files are pinned-SHA bumps and the `ca-setup-repo`
  `pnpm-version` default change.
- The `.gitignore` allowlist migration, the `engines` additions, and the `.editorconfig`
  reorganization are repository-internal development tooling and are outside
  the versioned public surface.

---

## [0.3.4] - 2026-08-09

### Overview

This release adds MDX support to the documentation formatting toolchain,
fixes vulnerable dependencies in the documentation site,
and standardizes development environment configuration, runner scripts, and the setup script.

No changes were made to composite action or reusable workflow interfaces.
The `on`/`inputs`/`outputs` blocks of every `action.yml` and `ru-*.yml` are identical to v0.3.3;
the only edits to those files are pinned-SHA bumps. Callers require no changes.

Note that `actions/setup-node` was bumped to v7.0.0 (major) inside `ca-setup-repo`.
The inputs this action uses (`node-version`, `cache`, `cache-dependency-path`) are unaffected
by the v7 breaking changes, but consumers of `ca-setup-repo` will run the v7 series.

---

### Added

#### Documentation Tooling

- `dprint`: Added `.mdx` file formatting support.
- `markdownlint`: Added support for the nested `siblings_only` option and MDX emphasis handling.
- VS Code: Added markdown formatting settings for `.mdx` files.

---

### Fixed

- `dprint`: Corrected a typo in the markdown associations key that prevented
  the intended file patterns from being matched.
- Updated vulnerable dependencies in the documentation site.

---

### Changed

#### Documentation

- Migrated the Docusaurus site to `aglabo.github.io`.
- Unified documentation style across all documents.

#### Development Environment

- Standardized development environment configs, runner scripts, and `setup-dev-env.sh`.
- Renamed `commitlint.config.cjs` → `commitlint.config.mjs`.
- Relocated runner lib tests to `runners/libs/__tests__/`.
- Removed obsolete PowerShell setup scripts: `install-dev-tools.ps1`, `install-doc-tools.ps1`,
  `libs/AgInstaller.ps1`, and `common/init.ps1`.
- Removed the superseded `scripts/run-specs.sh` and `scripts/lint-actionlint.sh`.

---

### Notes

- Changes under `.github/actions/**/scripts/` in this release are `shfmt` formatting only
  (redirection spacing, `case` indentation, statement separation) with no behavioral change.
- The removed PowerShell scripts and the reworked `runners/` scripts are repository-internal
  development tooling and are outside the versioned public surface.

---

## [0.3.3] - 2026-06-28

### Overview

This release normalizes input parameter names across reusable workflows for consistency.

**Breaking change:** Reusable workflow input parameter names have changed.
Callers passing the old parameter names must update them.

---

### Breaking Changes

- `ru-qa-actionlint.yml`: Renamed inputs `actionlint-version` → `version`,
  `config-file` → `config`.
- `ru-qa-ghalint.yml`: Renamed inputs `ghalint-version` → `version`,
  `config-file` → `config`.
- `ru-scan-betterleaks.yml`: Renamed input `betterleaks-version` → `version`.

**Policy note:** Under the backward compatibility policy, an input rename is a breaking change
and warrants a MAJOR bump. This release was published as a PATCH tag before that policy was
applied consistently. The tag is left as-is for reproducibility; callers pinned to v0.3.2
or earlier are unaffected.

Migration: update `with:` keys in caller workflows.

```yaml
# Before (v0.3.2)
uses: aglabo/ci-platform/.github/workflows/ru-qa-actionlint.yml@v0.3.2
with:
  actionlint-version: "1.7.7"
  config-file: ./configs/actionlint.yaml

# After (v0.3.3)
uses: aglabo/ci-platform/.github/workflows/ru-qa-actionlint.yml@v0.3.3
with:
  version: "1.7.7"
  config: ./configs/actionlint.yaml
```

---

## [0.3.2] - 2026-06-24

### Overview

This release extends `ca-get-changed-files` with event-aware SHA resolution,
adding `pull_request` support alongside `push`, and updates GitHub Actions dependencies
across all workflows.

The `before-sha`/`after-sha` inputs shipped in v0.3.1; this release implements the
resolution logic behind them.

---

### Added

#### Composite Actions

- `ca-get-changed-files`: Added `pull_request` event support.
  A `resolve-sha` step now derives base/head SHAs for pull request events,
  and the `before-sha`/`after-sha` inputs default to empty.
- `ca-get-changed-files`: `resolve_sha_for_event` now honors explicitly supplied
  `before-sha`/`after-sha` values, taking precedence over event-derived SHAs.
  Supplying only one of the pair is rejected with an error.

---

### Fixed

- `ca-get-changed-files`: Added `push` event SHA resolution via `GITHUB_BEFORE_SHA`/
  `GITHUB_AFTER_SHA`. Events other than `push` and `pull_request` are now explicitly
  rejected instead of silently passing through unresolved values.
- Fixed the `ca-validate-environment` action reference in reusable workflows.

---

### Changed

#### Dependencies

- `actions/checkout`: v6.0.2/v6.0.3 → v7.0.0.
- `pnpm/action-setup`: v4.2.0 → v6.0.9.
- `actions/setup-node`: v6.2.0 → v6.4.0.
- Updated pinned self-reference SHAs to the v0.3.2 commit hash across all workflows.

---

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
  Accepts an optional `pattern` input for glob filtering, and exposes `before-sha`/`after-sha`
  inputs to override the default commit SHAs (`github.event.before`/`github.sha`).
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
