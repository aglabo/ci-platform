---
title: "Requirements: Betterleaks Reusable Workflow"
module: "reusable-workflows/betterleaks"
status: Draft
version: 1.0
created: "2026-06-12"
---

> **Normative Statement**
> This document defines binding requirements.
> Implementations MUST conform to this document.
> RFC 2119 keywords apply to this document only.

## 1. Overview

### 1.1 Purpose

This document defines the requirements for an independent reusable GitHub Actions workflow that performs betterleaks-based secret scanning without depending on the external `aglabo/.github` reusable workflow version `r1.1.2`. The workflow provides both reusable and manual execution paths, validates the runner environment before scanning, installs the configured betterleaks version through the local setup action, checks out a user-configurable configuration repository (defaulting to `aglabo/.github`) to obtain the betterleaks scan configuration, and fails immediately when secret scanning detects a failure.

### 1.2 Scope

- Provide a reusable GitHub Actions workflow for betterleaks secret scanning.
- Support `workflow_call` execution from caller workflows.
- Support `workflow_dispatch` manual execution.
- Validate the GitHub Actions environment before tool setup and scan execution.
- Install betterleaks through the local `setup-tool` action.
- Allow the betterleaks version to be configured through an input parameter with a default value.
- Allow the configuration repository to be specified via an input parameter (default: `aglabo/.github`).
- Allow the git fetch depth to be configured via an input parameter (default: 1, latest commit only).
- Checkout the specified configuration repository to access the betterleaks configuration.
- Run betterleaks using `shared/configs/betterleaks.toml` from the checked-out configuration repository.
- Output the scan result as a JSON report file.
- Upload the scan report as a workflow artifact when a violation is detected.
- Fail the workflow immediately when betterleaks returns a non-zero exit code.

**Out of Scope**: Implementing or modifying the betterleaks tool itself; changing the local `validate-environment` action; changing the local `setup-tool` action; managing findings suppression policy; supporting non-Ubuntu runners; using the local `configs/betterleaks.toml` as the workflow scan configuration; making the config-repo checkout directory or branch configurable by callers.

## 2. Context

- Target Environment: GitHub Actions (ubuntu-latest runner)
- Related Components:
  - `reusable-workflows/betterleaks`
  - Local `validate-environment` action `v0.1.1`
  - Local `setup-tool` action
  - `aglabo/.github` repository
  - `global/configs/betterleaks.toml`
  - betterleaks CLI
  - Caller workflows using `workflow_call`
  - Manual users using `workflow_dispatch`
- Assumptions:
  - The workflow executes on `ubuntu-latest`.
  - The workflow has `contents: read` permission.
  - The caller repository is checked out or otherwise available to the scan job before betterleaks execution.
  - The configuration repository specified by the input parameter is readable by the workflow.
  - The betterleaks configuration exists at `global/configs/betterleaks.toml` in the default branch of the configuration repository.
  - The local `setup-tool` action can install betterleaks when passed `repo` and `tool-version`.
  - The configured betterleaks version is compatible with the shared configuration.
  - The shared configuration requires betterleaks minimum version `v1.0.0` and gitleaks minimum version `v8.25.0`.

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
        | --config shared/global/configs/       |
        |          betterleaks.toml             |
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

**Rationale**: Environment validation ensures the runner meets prerequisites before any tool installation or scan execution.

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

**Rationale**: Limiting fetch depth to the latest commit reduces checkout time and scan surface. Full history (fetch-depth: 0) is available when callers need to scan all commits.

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

**Rationale**: Using setup-tool centralizes tool installation logic and ensures checksum verification.

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

**Rationale**: Making the configuration repository configurable allows users to fork or replace the shared configuration while keeping `aglabo/.github` as a sensible default.

### REQ-F-004: Secret Scan Execution

- EARS Type: event-driven

```text
GIVEN betterleaks has been installed and the shared configuration has been checked out
  WHEN executing the secret scan
THEN the workflow MUST run betterleaks against the target repository
     using the checked-out shared/configs/betterleaks.toml configuration,
     equivalent to: betterleaks protect --config shared/configs/betterleaks.toml.
```

**Rationale**: Scanning with a shared configuration guarantees uniform secret detection rules.

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

**Rationale**: A machine-readable report enables downstream processing and artifact retention for audit purposes.

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

**Rationale**: Uploading the report only on failure avoids artifact storage costs on clean runs while ensuring evidence is preserved when secrets are detected.

### REQ-F-005: Fail-Fast on Scan Failure

- EARS Type: unwanted behavior

```text
GIVEN betterleaks exits with a non-zero exit code
  NOT DO suppress the failure with continue-on-error
THEN the workflow MUST immediately fail the scan step and job.
```

**Rationale**: Secret findings must block unsafe changes without exception.

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

**Rationale**: Supporting both triggers and configurable inputs provides flexibility for automated and ad-hoc scanning across different configurations.

## 5. Non-Functional Requirements

### REQ-NF-001: Maintainability

The workflow SHOULD keep tool setup, environment validation, configuration checkout, and scan execution as separate named steps.

### REQ-NF-002: Security — Minimum Permissions

The workflow MUST request only the minimum permissions required and MUST include `contents: read`.

### REQ-NF-003: Security — No Hard-coded Tokens

The workflow MUST use GitHub Actions secrets or context values for `github-token` and MUST NOT hard-code tokens.

### REQ-NF-004: Reproducibility — Version Pinning

The betterleaks version MUST be resolved from the explicit workflow input or default value.

### REQ-NF-005: Reproducibility — Config Path

The workflow MUST reference the checked-out `aglabo/.github` configuration path deterministically.

### REQ-NF-006: Observability

Failed step names and command context SHOULD make the failure source identifiable from the GitHub Actions log.

## 6. Constraints

### REQ-C-001: Runner

The scan job MUST run on `ubuntu-latest`.

### REQ-C-002: Permissions

The workflow MUST include `contents: read` in its permissions block.

### REQ-C-003: Tool Version Format

The betterleaks version input SHOULD use `X.Y.Z` version format.

### REQ-C-004: Minimum Compatible Versions

The default betterleaks version SHALL be `1.4.1`, which is compatible with betterleaks minimum version `v1.0.0` and gitleaks minimum version `v8.25.0`.

### REQ-C-005: Local Actions Only

The workflow MUST use local actions from this repository rather than the external `aglabo/.github` reusable workflow `r1.1.2` for environment validation and tool installation.

### REQ-C-006: Configuration Source

The workflow MUST checkout the configuration repository into the `shared/` directory and use `shared/configs/betterleaks.toml` as the scan configuration. The configuration repository MUST default to `aglabo/.github` when no `config-repo` input is provided.

## 7. User Stories

- As a platform engineer, I want a local reusable betterleaks workflow. Because repository workflows should not depend on the external `aglabo/.github` reusable workflow `r1.1.2`.
- As a repository maintainer, I want to call the betterleaks scan from my CI workflow. Because secret scanning should be reusable across repositories.
- As a security engineer, I want the workflow to use the shared `aglabo/.github` betterleaks configuration by default. Because scan policy should be centralized and consistent.
- As a user of a forked environment, I want to specify my own configuration repository. Because my organization may maintain a customized betterleaks configuration.
- As a CI operator, I want betterleaks failures to fail the workflow immediately. Because secret findings must block unsafe changes.
- As a developer, I want to manually run the betterleaks workflow. Because I may need to verify a branch outside normal CI execution.

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
