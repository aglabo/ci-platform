---
title: "Requirements: Betterleaks Reusable Workflow"
module: "reusable-workflows/betterleaks"
status: Draft
version: 2.0.0
created: "2026-06-12"
---

<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/no-exclamation-question-mark
  -->
<!-- markdownlint-disable line-length -->

> **Normative Statement**
> This document defines binding requirements.
> Implementations MUST conform to this document.
> RFC 2119 keywords apply to this document only.

## 1. Overview

### 1.1 Purpose

This document defines the requirements for a standalone reusable GitHub Actions workflow that scans for secrets with betterleaks. The workflow does not depend on the external `aglabo/.github` reusable workflow `r1.1.2`.

The workflow lives in `.github/workflows/ru-scan-secrets.yml`, which holds two independent jobs: `scan-betterleaks` (this module) and `scan-secretlint` (see `reusable-workflows/secretlint`).

Callers invoke the workflow through `workflow_call`. The `scan-betterleaks` job validates the runner environment, then installs the configured betterleaks version with this repository's `ca-setup-tool` composite action. It checks out a configurable configuration repository (default: `aglabo/global-configs`) and resolves the scan configuration with the `_ca-resolve-config` composite action (explicit input, then the repository's own `configs/betterleaks.toml`, then the checked-out global configuration). When the scan detects a secret, the job fails immediately.

### 1.2 Scope

- Provide a reusable GitHub Actions workflow for betterleaks secret scanning.
- Run from caller workflows through `workflow_call`.
- Validate the GitHub Actions environment before tool setup and scan execution.
- Install betterleaks with this repository's `ca-setup-tool` composite action.
- Take the betterleaks version from an input parameter that has a default value.
- Take the configuration repository from an input parameter (default: `aglabo/global-configs`).
- Take the git fetch depth from an input parameter (default: 50, latest 50 commits).
- Take an optional betterleaks configuration path from the `config` input parameter (default: empty).
- Check out the specified configuration repository into `global/configs/`.
- Resolve the betterleaks configuration with `_ca-resolve-config` (input, then local `configs/betterleaks.toml`, then `global/configs/betterleaks.toml`).
- Run betterleaks with the resolved configuration file.
- Write the scan result to a JSON report file.
- Upload the report as a workflow artifact when the scan finds a violation.
- Fail the workflow as soon as betterleaks returns a non-zero exit code.

**Out of Scope**:

- Implementing or changing the betterleaks tool itself.
- Changing the `ca-validate-environment` composite action.
- Changing the `ca-setup-tool` composite action.
- Managing findings suppression policy.
- Supporting runners other than Ubuntu.
- The `scan-secretlint` job in the same workflow file (documented in `reusable-workflows/secretlint`).
- Changing the `_ca-resolve-config` composite action.
- Letting callers configure the config-repo checkout directory or branch.

## 2. Context

- Target Environment: GitHub Actions (ubuntu-slim runner)
- Related Components:
  - `reusable-workflows/betterleaks`
  - `ca-validate-environment` composite action (`aglabo/ci-platform/.github/actions/ca-validate-environment@v0.8.0-pre`)
  - `ca-setup-tool` composite action (`aglabo/ci-platform/.github/actions/ca-setup-tool@v0.8.0-pre`)
  - `_ca-resolve-config` composite action (`aglabo/ci-platform/.github/actions/_ca-resolve-config@v0.8.0-pre`)
  - `aglabo/global-configs` repository
  - `configs/betterleaks.toml` (repository-local configuration)
  - `global/configs/betterleaks.toml` (global fallback configuration)
  - betterleaks CLI
  - Caller workflows using `workflow_call`
- Assumptions:
  - The workflow runs on `ubuntu-slim`.
  - The workflow has `contents: read` permission.
  - The scan job can reach the caller repository before betterleaks runs.
  - The workflow can read the configuration repository given by the input parameter.
  - The default branch of that repository holds the betterleaks configuration at `betterleaks.toml` in the repository root, which the workflow reads as `global/configs/betterleaks.toml` after checking the repository out into `global/configs/`.
  - The `ca-setup-tool` composite action installs betterleaks when given `repo` and `tool-version`.
  - The configured betterleaks version works with the central configuration.
  - The central configuration needs betterleaks `v1.0.0` or later and gitleaks `v8.25.0` or later.

### System Context Diagram

```text
           +-------------------+
           | Caller Workflow   |
           | workflow_call     |
           +---------+---------+
                     |
                     v
     +---------------------------------------+
     | Betterleaks Reusable Workflow         |
     | runner: ubuntu-slim                   |
     | permissions: contents: read           |
     +-------------------+-------------------+
                         |
                         v
     +---------------------------------------+
     | ca-validate-environment action        |
     | validates runner, permissions, apps   |
     +-------------------+-------------------+
                         |
                         v
     +---------------------------------------+
     | ca-setup-tool action                  |
     | installs configured betterleaks       |
     +-------------------+-------------------+
                         |
                         v
     +---------------------------------------+
     | Checkout config-repo (default:        |
     | aglabo/global-configs)                |
     | into global/configs/                  |
     +-------------------+-------------------+
                         |
                         v
     +---------------------------------------+
     | _ca-resolve-config action             |
     | input > configs/betterleaks.toml      |
     | > global/configs/betterleaks.toml     |
     +-------------------+-------------------+
                         |
                         v
     +---------------------------------------+
     | betterleaks git .                     |
     | --config <resolved config-file>       |
     +-------------------+-------------------+
                         |
           +-------------+-------------+
           |                           |
           v                           v
+---------------------+     +----------------------+
| Exit code 0         |     | Non-zero exit code   |
| Workflow passes     |     | Workflow fails fast  |
+---------------------+     +----------------------+
```

## 3. Design Decisions (Summary)

| ID    | Decision                                                                                                                                                                                                                                                                         | Linked Record |
| ----- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- |
| DR-01 | The betterleaks workflow SHALL be implemented as an independent reusable workflow rather than delegating to the external `aglabo/.github` reusable workflow `r1.1.2`.                                                                                                            | —             |
| DR-02 | The workflow SHALL use this repository's `ca-validate-environment` composite action before installing or running betterleaks.                                                                                                                                                    | —             |
| DR-03 | The workflow SHALL use this repository's `ca-setup-tool` composite action to install betterleaks.                                                                                                                                                                                | —             |
| DR-04 | The betterleaks version SHALL be configurable by workflow input and SHALL provide a default value.                                                                                                                                                                               | —             |
| DR-05 | The workflow SHALL checkout the configuration repository into the `global/configs/` directory (default branch) as the fallback configuration source. (Superseded in part by DR-08: the local `configs/betterleaks.toml` now takes precedence.)                                   | —             |
| DR-06 | A non-zero betterleaks scan exit code SHALL immediately fail the workflow.                                                                                                                                                                                                       | —             |
| DR-07 | The configuration repository SHALL be configurable via an input parameter with `aglabo/global-configs` as the default, because centrally managed tool configurations moved to that dedicated repository; users can still point to their own repository.                          | —             |
| DR-08 | The workflow SHALL resolve the scan configuration with the `_ca-resolve-config` composite action in the order: `config` input, local `configs/betterleaks.toml`, global `global/configs/betterleaks.toml`. This mirrors `runners/run-betterleaks.sh`, which is also local-first. | —             |

## 4. Functional Requirements

### REQ-F-001: Environment Validation

- EARS Type: event-driven

```text
GIVEN the betterleaks reusable workflow has started
  WHEN the scan job begins
THEN the workflow MUST run the ca-validate-environment composite action
     before installing or running betterleaks.
```

```text
GIVEN the ca-validate-environment composite action returns a failed validation state
  WHEN validation fails
THEN the workflow MUST stop before betterleaks installation and scan execution.
```

**Rationale**: Validating first confirms the runner meets its prerequisites before the workflow installs any tool or runs a scan.

### REQ-F-001b: Target Repository Checkout Depth

- EARS Type: feature-based

```text
GIVEN the workflow checks out the target repository for scanning
  WHERE the fetch-depth input is provided
THEN the workflow MUST use the specified fetch-depth value when checking out the target repository.
```

```text
GIVEN no fetch-depth input is provided
  WHEN checking out the target repository
THEN the workflow MUST use a default fetch-depth of 50 (latest 50 commits).
```

**Rationale**: Fetching a limited history (the latest 50 commits) keeps checkout time short while still covering recent commits. Callers who need to scan every commit can still ask for full history with `fetch-depth: 0`.

### REQ-F-002: Tool Installation

- EARS Type: event-driven

```text
GIVEN environment validation has completed successfully
  WHEN the workflow prepares the scan tool
THEN the workflow MUST run the ca-setup-tool composite action to install betterleaks,
     passing the repo input in owner/repo format and the resolved tool-version.
```

```text
GIVEN no betterleaks version input is provided
  WHEN installing betterleaks
THEN the workflow MUST use the workflow-defined default betterleaks version.
```

**Rationale**: Installing through setup-tool keeps the install logic in one place and verifies the checksum.

### REQ-F-003: Config Checkout and Resolution

- EARS Type: event-driven

```text
GIVEN the workflow needs the betterleaks scan configuration
  WHEN preparing scan inputs
THEN the workflow MUST checkout the repository specified by the config-repo input parameter
     into the global/configs/ directory
     and MUST then run the _ca-resolve-config composite action with
     config=inputs.config, local-config=configs/betterleaks.toml,
     global-config=global/configs/betterleaks.toml.
```

```text
GIVEN no config-repo input is provided
  WHEN checking out the configuration repository
THEN the workflow MUST use aglabo/global-configs as the default configuration repository.
```

```text
GIVEN the config input is empty
  AND the local repository contains configs/betterleaks.toml
  WHEN executing this workflow
THEN the workflow MUST use the local configs/betterleaks.toml
     as the scan configuration.
```

```text
GIVEN the config input is empty
  AND the local repository does not contain configs/betterleaks.toml
  WHEN executing this workflow
THEN the workflow MUST use global/configs/betterleaks.toml from the config-repo checkout.
```

```text
GIVEN the config input is not empty
  WHEN the configuration is resolved
THEN the workflow MUST use only that file, and MUST fail when it does not exist
     (no fallback to the local or global configuration).
```

**Rationale**: A configurable repository lets users fork or replace the central configuration, while `aglabo/global-configs`, the dedicated repository for centrally managed tool configurations, stays a sensible default. Local-first resolution lets a repository override the central policy and matches `runners/run-betterleaks.sh`. This reverses the earlier rule that forbade the local configuration (see DR-08).

### REQ-F-004: Secret Scan Execution

- EARS Type: event-driven

```text
GIVEN betterleaks has been installed and the configuration has been resolved
  WHEN executing the secret scan
THEN the workflow MUST run betterleaks against the target repository
     using the resolved configuration file (steps.resolve-config.outputs.config-file),
     equivalent to: betterleaks git . --config "${CONFIG_FILE}"
     --report-path=.github/report/betterleaks-report.json --exit-code=1 --verbose.
```

**Rationale**: A central configuration gives every repository the same secret detection rules.

### REQ-F-007: Scan Report Output

- EARS Type: event-driven

```text
GIVEN betterleaks is executed
  WHEN the scan runs
THEN the workflow MUST output the scan result as a JSON report file at .github/report/betterleaks-report.json.
```

```text
GIVEN the report directory does not exist
  WHEN the workflow prepares for scanning
THEN the workflow MUST create the .github/report/ directory before running betterleaks.
```

**Rationale**: A machine-readable report lets other tools process the result and keeps an artifact for audits.

### REQ-F-008: Report Upload on Failure

- EARS Type: event-driven

```text
GIVEN betterleaks exits with a non-zero exit code indicating a violation
  WHEN the scan step fails
THEN the workflow MUST upload the scan report as a workflow artifact named betterleaks-report.
```

```text
GIVEN betterleaks exits with exit code 0 (no violations)
  WHEN the scan step succeeds
THEN the workflow MUST NOT upload any artifact.
```

**Rationale**: Uploading only on failure saves storage on clean runs and still preserves evidence when the scan finds a secret.

### REQ-F-005: Fail-Fast on Scan Failure

- EARS Type: unwanted behavior

```text
GIVEN betterleaks exits with a non-zero exit code
  NOT DO suppress the failure with continue-on-error
THEN the workflow MUST immediately fail the scan step and job.
```

**Rationale**: A secret finding has to block an unsafe change every time, with no exceptions.

### REQ-F-006: Workflow Trigger

- EARS Type: feature-based

```text
GIVEN another workflow needs to invoke the betterleaks scan
  WHERE the workflow_call trigger is defined
THEN the betterleaks workflow MUST be executable as a reusable workflow.
```

```text
GIVEN workflow_call is used
  WHEN a version input is supplied
THEN the workflow MUST use the supplied value for tool installation.
```

```text
GIVEN workflow_call is used
  WHEN a config-repo input is supplied
THEN the workflow MUST use the supplied value as the configuration repository to checkout.
```

```text
GIVEN workflow_call is used
  WHEN a config input is supplied
THEN the workflow MUST pass the supplied value to _ca-resolve-config as the explicit configuration path.
```

**Rationale**: A reusable trigger with configurable inputs lets caller workflows run the scan across different configurations.

## 5. Non-Functional Requirements

### REQ-NF-001: Maintainability

The workflow SHOULD keep environment validation, tool setup, configuration checkout, and the scan as separate named steps.

### REQ-NF-002: Security — Minimum Permissions

The workflow MUST request only the permissions it needs and MUST include `contents: read`.

### REQ-NF-003: Security — No Hard-coded Tokens

The workflow does not use a token of its own (`persist-credentials: false` on every checkout) and MUST NOT hard-code any token.

### REQ-NF-004: Reproducibility — Version Pinning

The workflow MUST take the betterleaks version from the workflow input, or from the default value when no input is given.

### REQ-NF-005: Reproducibility — Config Path

The workflow MUST resolve the configuration with the same candidate paths and precedence on every run (`config` input, `configs/betterleaks.toml`, `global/configs/betterleaks.toml`).

### REQ-NF-006: Observability

Step names and command output SHOULD make the cause of a failure clear from the GitHub Actions log alone.

## 6. Constraints

### REQ-C-001: Runner

The scan job MUST run on `ubuntu-slim`.

### REQ-C-002: Permissions

The workflow MUST include `contents: read` in its permissions block.

### REQ-C-003: Tool Version Format

The betterleaks version input SHOULD use the `X.Y.Z` format.

### REQ-C-004: Minimum Compatible Versions

The default betterleaks version SHALL be `1.10.0`. This version meets the central configuration's minimums of betterleaks `v1.0.0` and gitleaks `v8.25.0`.

### REQ-C-005: Repository Actions Only

The workflow MUST NOT use the external `aglabo/.github` reusable workflow `r1.1.2`.
It MUST use these composite actions of this repository instead:

- `aglabo/ci-platform/.github/actions/ca-validate-environment@v0.8.0-pre` (environment validation)
- `aglabo/ci-platform/.github/actions/ca-setup-tool@v0.8.0-pre` (tool installation)
- `aglabo/ci-platform/.github/actions/_ca-resolve-config@v0.8.0-pre` (configuration resolution)

### REQ-C-006: Configuration Source

The workflow MUST check out the configuration repository into the `global/configs/` directory, and MUST resolve the scan configuration by precedence (`config` input, `configs/betterleaks.toml`, `global/configs/betterleaks.toml`). When no `config-repo` input is given, the repository MUST default to `aglabo/global-configs`.

## 7. User Stories

- As a platform engineer, I want a local reusable betterleaks workflow, so that our workflows no longer depend on the external `aglabo/.github` workflow `r1.1.2`.
- As a repository maintainer, I want to call the betterleaks scan from my CI workflow, so that every repository can reuse the same scan.
- As a security engineer, I want the central `aglabo/global-configs` configuration by default, so that scan policy stays central and consistent.
- As a user of a forked environment, I want to name my own configuration repository, so that I can use my organization's customized betterleaks configuration.
- As a CI operator, I want a betterleaks failure to fail the workflow at once, so that a secret finding blocks the unsafe change.

## 8. Acceptance Criteria

```gherkin
# AC-001: Reusable Workflow Runs Successfully
# Requirement: REQ-F-001, REQ-F-002, REQ-F-003, REQ-F-004, REQ-F-006
Scenario: Reusable Workflow Runs Successfully
  Given a caller workflow invokes the betterleaks workflow through workflow_call
  And no secrets are detected by betterleaks
  When the workflow runs on ubuntu-slim
  Then the workflow validates the environment
  And installs the configured betterleaks version
  And checks out the default aglabo/global-configs configuration repository into global/configs/
  And resolves the configuration with _ca-resolve-config
  And runs betterleaks using the resolved configuration file
  And the workflow completes successfully

# AC-002: Supplied Betterleaks Version Is Used
# Requirement: REQ-F-002, REQ-F-004, REQ-F-006
Scenario: Supplied Betterleaks Version Is Used
  Given a caller workflow invokes the betterleaks workflow through workflow_call
  And the caller provides a valid version input
  And no secrets are detected by betterleaks
  When the workflow runs
  Then the workflow installs the provided betterleaks version
  And runs betterleaks with the central configuration
  And the workflow completes successfully

# AC-003: Default Betterleaks Version Is Used
# Requirement: REQ-F-002, REQ-F-006
Scenario: Default Betterleaks Version Is Used
  Given the betterleaks workflow is started without a version input
  When the setup-tool action installs betterleaks
  Then the workflow uses the default betterleaks version
  And the scan runs with the central betterleaks configuration

# AC-004: Scan Failure Fails Fast
# Requirement: REQ-F-005
Scenario: Scan Failure Fails Fast
  Given the betterleaks workflow is running
  And betterleaks detects a secret
  When betterleaks exits with a non-zero exit code
  Then the scan step fails immediately
  And the job fails
  And the workflow does not suppress the failure

# AC-005: Environment Validation Failure Blocks Scan
# Requirement: REQ-F-001
Scenario: Environment Validation Failure Blocks Scan
  Given the betterleaks workflow has started
  And ca-validate-environment reports a failed validation state
  When the validation step completes
  Then the workflow fails before ca-setup-tool runs
  And betterleaks is not executed

# AC-006: Local Configuration Takes Precedence
# Requirement: REQ-F-003, REQ-F-004
Scenario: Local Configuration Takes Precedence
  Given the config input is empty
  And the repository contains configs/betterleaks.toml
  When the configuration is resolved
  Then the local configs/betterleaks.toml is passed to betterleaks

# AC-007: Global Configuration Is the Fallback
# Requirement: REQ-F-003
Scenario: Global Configuration Is the Fallback
  Given the config input is empty
  And the repository does not contain configs/betterleaks.toml
  When the configuration is resolved
  Then global/configs/betterleaks.toml is passed to betterleaks

# AC-008: Missing Explicit Configuration Fails
# Requirement: REQ-F-003, REQ-F-006
Scenario: Missing Explicit Configuration Fails
  Given the caller supplies a config input naming a file that does not exist
  When the configuration is resolved
  Then the resolve-config step fails
  And betterleaks is not executed
```

## 9. Open Questions

| Question                                                                                                | Type      | Impact Area                                | Owner                                 |
| ------------------------------------------------------------------------------------------------------- | --------- | ------------------------------------------ | ------------------------------------- |
| ~~What exact default betterleaks version should the workflow use?~~                                     | Product   | Tool installation, reproducibility         | **Resolved: 1.10.0**                  |
| ~~Should the configuration branch be hardcoded or made configurable in a future version?~~              | Technical | Configuration reproducibility, flexibility | **Resolved: default branch (no ref)** |
| Should the workflow scan the entire repository by default or support path filtering in a later version? | Product   | Scan scope                                 | Security Team                         |

## 10. Change History

| Date       | Version | Description                                                                                                                                                                                                             |
| ---------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-11-19 | 2.0.0   | Align with ru-scan-secrets.yml: resolve config via _ca-resolve-config (local-first; reverses the ban on configs/betterleaks.toml, DR-08), add config input and AC-006..008, default version 1.10.0, actions @v0.8.0-pre |
| 2026-11-03 | 1.6.1   | Update ca-* composite action references from @v0.5.0 to @v0.6.0                                                                                                                                                         |
| 2026-11-03 | 1.6.0   | Change config-repo default to aglabo/global-configs (checkout path global/configs); align version input, runner, trigger, and actions with ru-scan-betterleaks.yml                                                      |
| 2026-06-12 | 1.5.0   | Add fetch-depth input (REQ-F-001b), scan report output (REQ-F-007), report upload on failure (REQ-F-008)                                                                                                                |
| 2026-06-12 | 1.4.0   | Change config-repo checkout: path=shared/ (default branch), config=shared/configs/betterleaks.toml                                                                                                                      |
| 2026-06-12 | 1.3.0   | Fix default betterleaks version to `1.4.1`                                                                                                                                                                              |
| 2026-06-12 | 1.2.0   | Fix config-repo checkout branch to `shared` (not default branch) — superseded by 1.4.0                                                                                                                                  |
| 2026-06-12 | 1.1.0   | Add config-repo input parameter (user-configurable configuration repository, default: aglabo/.github)                                                                                                                   |
| 2026-06-12 | 1.0.0   | Initial release                                                                                                                                                                                                         |
