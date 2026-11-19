---
title: "Requirements: Actions Lock Reusable Workflow"
module: "reusable-workflows/actions-lock"
status: Draft
version: 1.0.1
created: "2026-11-19"
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

This document defines the requirements for the reusable workflow `.github/workflows/ru-qa-actions-lock.yml`. The workflow verifies that the repository's `.github/workflows/actions.lock` file matches the `uses:` references of its workflows, with the `gh actions-lock` extension in `--verify` mode.

### 1.2 Scope

- Provide a reusable workflow, invoked through `workflow_call`, that runs `gh actions-lock --verify`.
- Take the extension version from an input with a default.
- Validate the runner environment before installing the extension.
- Install the extension with `gh extension install` pinned to that version.
- Save the verification output as a report and upload it when verification fails.

**Out of Scope**:

- Generating or updating `actions.lock` (the workflow only verifies).
- Implementing or changing `gh-actions-lock`.
- Configuration files (the workflow takes none).
- Publishing workflow outputs.

## 2. Context

- Target Environment: GitHub Actions (`ubuntu-slim`)
- Related Components:
  - `ca-validate-environment` composite action (`aglabo/ci-platform/.github/actions/ca-validate-environment@v0.8.1`)
  - `github/gh-actions-lock` GitHub CLI extension
  - `.github/workflows/actions.lock` (the lockfile under verification)
  - Caller: `.github/workflows/ci-workflows-qa.yml` (job `actions-lock`, no `with:` block)
- Assumptions:
  - The workflow has `contents: read` permission.
  - `gh` is available on the runner and authenticates with `github.token`.

### System Context Diagram

```text
Caller (ci-workflows-qa.yml)
        |  workflow_call
        v
+--------------------------------------+
| qa-actions-lock (ubuntu-slim)     |
| --------------------------------- |
| -> install extension (pinned)     |
| -> show version -> prepare report |
| -> gh actions-lock --verify       |
| -> upload report on failure       |
+--------------------------------------+
```

## 3. Design Decisions (Summary)

| ID    | Decision                                                                                   | Linked Record       |
| ----- | ------------------------------------------------------------------------------------------ | ------------------- |
| DR-01 | The extension SHALL be installed with `gh extension install --pin` with the version input. | decision-records.md |
| DR-02 | Verification SHALL use `--verify --no-interactive` and keep its output as a report.        | decision-records.md |
| DR-03 | The workflow SHALL NOT use `ca-setup-tool` or `_ca-resolve-config`.                        | decision-records.md |

## 4. Functional Requirements

### REQ-F-001: Reusable Trigger and Version Input

- EARS Type: feature-based

```text
GIVEN another workflow needs to verify the lockfile
  WHERE the workflow_call trigger is defined
THEN the workflow MUST be callable as a reusable workflow
     and MUST accept the optional string input version with the default "v0.4.1".
```

**Rationale**: A default lets callers use the workflow without a `with:` block; the input lets them move to a newer extension.

### REQ-F-002: Environment Validation

- EARS Type: event-driven

```text
GIVEN the target repository has been checked out
  WHEN the job continues
THEN the workflow MUST run ca-validate-environment with actions-type read
     before installing the extension, and MUST stop when validation fails.
```

### REQ-F-003: Extension Installation

- EARS Type: event-driven

```text
GIVEN environment validation succeeded
  WHEN the workflow prepares the tool
THEN it MUST run: gh extension install github/gh-actions-lock --pin "<version input>"
     with GH_TOKEN set to the workflow token,
     and MUST then print the installed version with gh actions-lock --version.
```

**Rationale**: Pinning makes the verification rules reproducible.

### REQ-F-004: Lockfile Verification

- EARS Type: event-driven

```text
GIVEN the extension is installed and the report directory exists
  WHEN the workflow verifies the lockfile
THEN it MUST run: gh actions-lock --verify --no-interactive,
     MUST copy the combined output to .github/report/actions-lock-report.txt,
     and MUST exit with the exit status of gh actions-lock (not of tee).
```

**Rationale**: The status of `gh actions-lock` decides the job result; the report preserves its message.

### REQ-F-005: Report Upload on Failure

- EARS Type: unwanted behavior

```text
GIVEN the lock-verify step failed
  WHEN the job reports
THEN the workflow MUST upload .github/report/actions-lock-report.txt
     as the artifact actions-lock-report with a retention of 30 days.
```

```text
GIVEN verification succeeded
THEN the workflow MUST NOT upload any artifact.
```

### REQ-F-006: Fail-Fast

- EARS Type: unwanted behavior

```text
GIVEN a verification or setup step fails
  NOT DO continue with later steps
THEN the job MUST fail, and no step MAY use continue-on-error.
```

## 5. Non-Functional Requirements

### REQ-NF-001: Minimum Permissions

The workflow and its job MUST declare `permissions: contents: read` and nothing else.

### REQ-NF-002: Credentials

The target checkout MUST set `persist-credentials: false`. `GH_TOKEN` MUST come from `github.token` and MUST be scoped to the steps that run `gh`.

### REQ-NF-003: Observability

Step ids and names MUST identify the failing unit from the Actions log alone.

## 6. Constraints

### REQ-C-001: Runner

The job MUST run on `ubuntu-slim` with a 10-minute timeout.

### REQ-C-002: Repository Actions

The workflow MUST use this repository's `ca-validate-environment` at `@v0.8.1`.

### REQ-C-003: Lockfile Location

The lockfile verified is the repository's own `.github/workflows/actions.lock`; the workflow does not accept a path input.

## 7. User Stories

- As a repository maintainer, I want CI to fail when `actions.lock` is out of date, so that workflows never run unapproved action versions.
- As a platform engineer, I want the extension version pinned, so that verification does not change under my feet.

## 8. Acceptance Criteria

```gherkin
# AC-001: Matching Lockfile Passes
# Requirement: REQ-F-002, REQ-F-003, REQ-F-004
Scenario: Matching Lockfile Passes
  Given actions.lock matches the workflows
  When the workflow runs
  Then the extension is installed at the pinned version
  And gh actions-lock --verify exits 0
  And no artifact is uploaded

# AC-002: Stale Lockfile Fails with a Report
# Requirement: REQ-F-004, REQ-F-005
Scenario: Stale Lockfile Fails with a Report
  Given actions.lock does not match the workflows
  When gh actions-lock --verify exits non-zero
  Then the job fails with that status
  And the artifact actions-lock-report is uploaded

# AC-003: Supplied Version Is Installed
# Requirement: REQ-F-001, REQ-F-003
Scenario: Supplied Version Is Installed
  Given the caller passes version "v0.5.0"
  When the extension is installed
  Then gh extension install uses --pin "v0.5.0"

# AC-004: Environment Validation Failure Blocks Installation
# Requirement: REQ-F-002
Scenario: Environment Validation Failure Blocks Installation
  Given ca-validate-environment fails
  When the validation step completes
  Then the extension is not installed
```

## 9. Open Questions

| Question                                                             | Type      | Impact Area           | Owner         |
| -------------------------------------------------------------------- | --------- | --------------------- | ------------- |
| Should the extension version be pinned by checksum instead of a tag? | Technical | Supply-chain security | Security Team |

## 10. Traceability

| REQ ID     | AC IDs         | Type           |
| ---------- | -------------- | -------------- |
| REQ-F-001  | AC-003         | Functional     |
| REQ-F-002  | AC-001, AC-004 | Functional     |
| REQ-F-003  | AC-001, AC-003 | Functional     |
| REQ-F-004  | AC-001, AC-002 | Functional     |
| REQ-F-005  | AC-002         | Functional     |
| REQ-F-006  | AC-002, AC-004 | Functional     |
| REQ-NF-001 | -              | Non-functional |
| REQ-NF-002 | -              | Non-functional |
| REQ-NF-003 | -              | Non-functional |
| REQ-C-001  | -              | Constraint     |
| REQ-C-002  | AC-004         | Constraint     |
| REQ-C-003  | AC-001         | Constraint     |

## 11. Change History

| Date       | Version | Description                                                    |
| ---------- | ------- | -------------------------------------------------------------- |
| 2026-11-20 | 1.0.1   | Update composite action references from @v0.8.0-pre to @v0.8.1 |
| 2026-11-19 | 1.0.0   | Initial release                                                |
