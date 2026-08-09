---
title: "Requirements: Betterleaks Reusable Workflow"
module: "reusable-workflows/betterleaks"
status: Draft
version: 1.0
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

Callers invoke the workflow through `workflow_call`, and users can also start it manually through `workflow_dispatch`. The workflow validates the runner environment, then installs the configured betterleaks version with the local setup-tool action. It checks out a configurable configuration repository (default: `aglabo/.github`) to obtain the scan configuration. When the scan detects a secret, the workflow fails immediately.

### 1.2 Scope

- Provide a reusable GitHub Actions workflow for betterleaks secret scanning.
- Run from caller workflows through `workflow_call`.
- Run manually through `workflow_dispatch`.
- Validate the GitHub Actions environment before tool setup and scan execution.
- Install betterleaks with the local `setup-tool` action.
- Take the betterleaks version from an input parameter that has a default value.
- Take the configuration repository from an input parameter (default: `aglabo/.github`).
- Take the git fetch depth from an input parameter (default: 1, latest commit only).
- Check out the specified configuration repository to read the betterleaks configuration.
- Run betterleaks with `shared/configs/betterleaks.toml` from that checkout.
- Write the scan result to a JSON report file.
- Upload the report as a workflow artifact when the scan finds a violation.
- Fail the workflow as soon as betterleaks returns a non-zero exit code.

**Out of Scope**:

- Implementing or changing the betterleaks tool itself.
- Changing the local `validate-environment` action.
- Changing the local `setup-tool` action.
- Managing findings suppression policy.
- Supporting runners other than Ubuntu.
- Using the local `configs/betterleaks.toml` as the scan configuration.
- Letting callers configure the config-repo checkout directory or branch.

## 2. Context

- Target Environment: GitHub Actions (ubuntu-latest runner)
- Related Components:
  - `reusable-workflows/betterleaks`
  - Local `validate-environment` action `v0.1.1`
  - Local `setup-tool` action
  - `aglabo/.github` repository
  - `shared/configs/betterleaks.toml`
  - betterleaks CLI
  - Caller workflows using `workflow_call`
  - Manual users using `workflow_dispatch`
- Assumptions:
  - The workflow runs on `ubuntu-latest`.
  - The workflow has `contents: read` permission.
  - The scan job can reach the caller repository before betterleaks runs.
  - The workflow can read the configuration repository given by the input parameter.
  - The default branch of that repository holds the betterleaks configuration at `configs/betterleaks.toml`, which the workflow reads as `shared/configs/betterleaks.toml` after checking the repository out into `shared/`.
  - The local `setup-tool` action installs betterleaks when given `repo` and `tool-version`.
  - The configured betterleaks version works with the shared configuration.
  - The shared configuration needs betterleaks `v1.0.0` or later and gitleaks `v8.25.0` or later.

### System Context Diagram

```text
+-------------------+        +---------------------+
| Caller Workflow   |        | Manual User         |
| workflow_call     |        | workflow_dispatch   |
+---------+---------+        +----------+----------+
          |                             |
          +-------------+---------------+
                        |
                        v
        +---------------------------------------+
        | Betterleaks Reusable Workflow         |
        | runner: ubuntu-latest                 |
        | permissions: contents: read           |
        +-------------------+-------------------+
                            |
                            v
        +---------------------------------------+
        | validate-environment action v0.1.1    |
        | validates runner, permissions, apps   |
        +-------------------+-------------------+
                            |
                            v
        +---------------------------------------+
        | setup-tool action                     |
        | installs configured betterleaks       |
        +-------------------+-------------------+
                            |
                            v
        +---------------------------------------+
        | Checkout config-repo (default:        |
        | aglabo/.github) into shared/          |
        +-------------------+-------------------+
                            |
                            v
        +---------------------------------------+
        | betterleaks protect                   |
        | --config                              |
        |   shared/configs/betterleaks.toml     |
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

| ID    | Decision                                                                                                                                                                                          | Linked Record |
| ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- |
| DR-01 | The betterleaks workflow SHALL be implemented as an independent reusable workflow rather than delegating to the external `aglabo/.github` reusable workflow `r1.1.2`.                             | —             |
| DR-02 | The workflow SHALL use the local `validate-environment` action before installing or running betterleaks.                                                                                          | —             |
| DR-03 | The workflow SHALL use the local `setup-tool` action to install betterleaks.                                                                                                                      | —             |
| DR-04 | The betterleaks version SHALL be configurable by workflow input and SHALL provide a default value.                                                                                                | —             |
| DR-05 | The workflow SHALL checkout the configuration repository into the `shared/` directory (default branch) and use `shared/configs/betterleaks.toml` instead of the local `configs/betterleaks.toml`. | —             |
| DR-06 | A non-zero betterleaks scan exit code SHALL immediately fail the workflow.                                                                                                                        | —             |
| DR-07 | The configuration repository SHALL be configurable via an input parameter with `aglabo/.github` as the default, allowing users to point to their own repository.                                  | —             |

## 4. Functional Requirements

### REQ-F-001: Environment Validation

- EARS Type: event-driven

```text
GIVEN the betterleaks reusable workflow has started
  WHEN the scan job begins
THEN the workflow MUST run the local validate-environment action v0.1.1
     before installing or running betterleaks.
```

```text
GIVEN the local validate-environment action returns a failed validation state
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
THEN the workflow MUST use a default fetch-depth of 1 (latest commit only).
```

**Rationale**: Fetching only the latest commit shortens checkout time and narrows the scan surface. Callers who need to scan every commit can still ask for full history with `fetch-depth: 0`.

### REQ-F-002: Tool Installation

- EARS Type: event-driven

```text
GIVEN environment validation has completed successfully
  WHEN the workflow prepares the scan tool
THEN the workflow MUST run the local setup-tool action to install betterleaks,
     passing the repo input in owner/repo format and the resolved tool-version.
```

```text
GIVEN no betterleaks version input is provided
  WHEN installing betterleaks
THEN the workflow MUST use the workflow-defined default betterleaks version.
```

**Rationale**: Installing through setup-tool keeps the install logic in one place and verifies the checksum.

### REQ-F-003: Config Checkout

- EARS Type: event-driven

```text
GIVEN the workflow needs the betterleaks scan configuration
  WHEN preparing scan inputs
THEN the workflow MUST checkout the repository specified by the config-repo input parameter
     into the shared/ directory and MUST use shared/configs/betterleaks.toml from that checkout.
```

```text
GIVEN no config-repo input is provided
  WHEN checking out the configuration repository
THEN the workflow MUST use aglabo/.github as the default configuration repository.
```

```text
GIVEN the local repository contains configs/betterleaks.toml
  WHEN executing this workflow
THEN the workflow MUST NOT use the local configs/betterleaks.toml
     as the scan configuration.
```

**Rationale**: A configurable repository lets users fork or replace the shared configuration, while `aglabo/.github` stays a sensible default.

### REQ-F-004: Secret Scan Execution

- EARS Type: event-driven

```text
GIVEN betterleaks has been installed and the shared configuration has been checked out
  WHEN executing the secret scan
THEN the workflow MUST run betterleaks against the target repository
     using the checked-out shared/configs/betterleaks.toml configuration,
     equivalent to: betterleaks protect --config shared/configs/betterleaks.toml.
```

**Rationale**: A shared configuration gives every repository the same secret detection rules.

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

### REQ-F-006: Workflow Triggers

- EARS Type: feature-based

```text
GIVEN another workflow needs to invoke the betterleaks scan
  WHERE the workflow_call trigger is defined
THEN the betterleaks workflow MUST be executable as a reusable workflow.
```

```text
GIVEN a user needs to run the betterleaks scan manually
  WHERE the workflow_dispatch trigger is defined
THEN the betterleaks workflow MUST support manual execution from GitHub Actions.
```

```text
GIVEN either workflow_call or workflow_dispatch is used
  WHEN a betterleaks version input is supplied
THEN the workflow MUST use the supplied value for tool installation.
```

```text
GIVEN either workflow_call or workflow_dispatch is used
  WHEN a config-repo input is supplied
THEN the workflow MUST use the supplied value as the configuration repository to checkout.
```

**Rationale**: Two triggers and configurable inputs cover both automated and ad-hoc scans across different configurations.

## 5. Non-Functional Requirements

### REQ-NF-001: Maintainability

The workflow SHOULD keep environment validation, tool setup, configuration checkout, and the scan as separate named steps.

### REQ-NF-002: Security — Minimum Permissions

The workflow MUST request only the permissions it needs and MUST include `contents: read`.

### REQ-NF-003: Security — No Hard-coded Tokens

The workflow MUST take `github-token` from a GitHub Actions secret or context value and MUST NOT hard-code any token.

### REQ-NF-004: Reproducibility — Version Pinning

The workflow MUST take the betterleaks version from the workflow input, or from the default value when no input is given.

### REQ-NF-005: Reproducibility — Config Path

The workflow MUST point to the same configuration path on every run, relative to the `aglabo/.github` checkout.

### REQ-NF-006: Observability

Step names and command output SHOULD make the cause of a failure clear from the GitHub Actions log alone.

## 6. Constraints

### REQ-C-001: Runner

The scan job MUST run on `ubuntu-latest`.

### REQ-C-002: Permissions

The workflow MUST include `contents: read` in its permissions block.

### REQ-C-003: Tool Version Format

The betterleaks version input SHOULD use the `X.Y.Z` format.

### REQ-C-004: Minimum Compatible Versions

The default betterleaks version SHALL be `1.4.1`. This version meets the shared configuration's minimums of betterleaks `v1.0.0` and gitleaks `v8.25.0`.

### REQ-C-005: Local Actions Only

For environment validation and tool installation, the workflow MUST use local actions from this repository instead of the external `aglabo/.github` reusable workflow `r1.1.2`.

### REQ-C-006: Configuration Source

The workflow MUST check out the configuration repository into the `shared/` directory and MUST use `shared/configs/betterleaks.toml` as the scan configuration. When no `config-repo` input is given, the repository MUST default to `aglabo/.github`.

## 7. User Stories

- As a platform engineer, I want a local reusable betterleaks workflow, so that our workflows no longer depend on the external `aglabo/.github` workflow `r1.1.2`.
- As a repository maintainer, I want to call the betterleaks scan from my CI workflow, so that every repository can reuse the same scan.
- As a security engineer, I want the shared `aglabo/.github` configuration by default, so that scan policy stays central and consistent.
- As a user of a forked environment, I want to name my own configuration repository, so that I can use my organization's customized betterleaks configuration.
- As a CI operator, I want a betterleaks failure to fail the workflow at once, so that a secret finding blocks the unsafe change.
- As a developer, I want to run the workflow by hand, so that I can check a branch outside the normal CI run.

## 8. Acceptance Criteria

```gherkin
# AC-001: Reusable Workflow Runs Successfully
# Requirement: REQ-F-001, REQ-F-002, REQ-F-003, REQ-F-004, REQ-F-006
Scenario: Reusable Workflow Runs Successfully
  Given a caller workflow invokes the betterleaks workflow through workflow_call
  And no secrets are detected by betterleaks
  When the workflow runs on ubuntu-latest
  Then the workflow validates the environment
  And installs the configured betterleaks version
  And checks out the default aglabo/.github configuration repository
  And runs betterleaks using shared/configs/betterleaks.toml from that checkout
  And the workflow completes successfully

# AC-002: Manual Workflow Runs Successfully
# Requirement: REQ-F-002, REQ-F-004, REQ-F-006
Scenario: Manual Workflow Runs Successfully
  Given a user starts the betterleaks workflow through workflow_dispatch
  And the user provides a valid betterleaks version input
  And no secrets are detected by betterleaks
  When the workflow runs
  Then the workflow installs the provided betterleaks version
  And runs betterleaks with the shared configuration
  And the workflow completes successfully

# AC-003: Default Betterleaks Version Is Used
# Requirement: REQ-F-002, REQ-F-006
Scenario: Default Betterleaks Version Is Used
  Given the betterleaks workflow is started without a betterleaks version input
  When the setup-tool action installs betterleaks
  Then the workflow uses the default betterleaks version
  And the scan runs with the shared betterleaks configuration

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
  And validate-environment reports a failed validation state
  When the validation step completes
  Then the workflow fails before setup-tool runs
  And betterleaks is not executed
```

## 9. Open Questions

| Question                                                                                                | Type      | Impact Area                                | Owner               |
| ------------------------------------------------------------------------------------------------------- | --------- | ------------------------------------------ | ------------------- |
| ~~What exact default betterleaks version should the workflow use?~~                                     | Product   | Tool installation, reproducibility         | **Resolved: 1.4.1** |
| Should the `shared` branch name be hardcoded or made configurable in a future version?                  | Technical | Configuration reproducibility, flexibility | Platform Team       |
| Should the workflow scan the entire repository by default or support path filtering in a later version? | Product   | Scan scope                                 | Security Team       |

## 10. Change History

| Date       | Version | Description                                                                                              |
| ---------- | ------- | -------------------------------------------------------------------------------------------------------- |
| 2026-06-12 | 1.5.0   | Add fetch-depth input (REQ-F-001b), scan report output (REQ-F-007), report upload on failure (REQ-F-008) |
| 2026-06-12 | 1.4.0   | Change config-repo checkout: path=shared/ (default branch), config=shared/configs/betterleaks.toml       |
| 2026-06-12 | 1.3.0   | Fix default betterleaks version to `1.4.1`                                                               |
| 2026-06-12 | 1.2.0   | Fix config-repo checkout branch to `shared` (not default branch) — superseded by 1.4.0                   |
| 2026-06-12 | 1.1.0   | Add config-repo input parameter (user-configurable configuration repository, default: aglabo/.github)    |
| 2026-06-12 | 1.0.0   | Initial release                                                                                          |
