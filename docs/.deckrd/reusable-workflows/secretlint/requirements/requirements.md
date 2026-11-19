---
title: "Requirements: Secretlint Scan Job (Reusable Workflow)"
module: "reusable-workflows/secretlint"
status: Draft
version: 1.0.0
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

This document defines the requirements for the `scan-secretlint` job of the reusable workflow `.github/workflows/ru-scan-secrets.yml`. The job scans the repository with secretlint by calling this repository's `ca-run-secretlint` composite action.

The same workflow file also holds the `scan-betterleaks` job (module `reusable-workflows/betterleaks`). The two jobs are independent: neither `needs` the other, and either can fail alone.

### 1.2 Scope

- Provide the `scan-secretlint` job in the reusable workflow, invoked through `workflow_call`.
- Take the secretlint version, the pnpm version, and the checkout depth from inputs with defaults.
- Check out the target repository.
- Run secretlint through `ca-run-secretlint`.
- Fail the job when secretlint reports a finding or cannot run.

**Out of Scope**:

- Implementing or changing secretlint or the `ca-run-secretlint` action (module `composite-action/run-secretlint`).
- Secretlint configuration files (secretlint v14 and later bundles its configuration).
- The `scan-betterleaks` job.
- Environment validation, report files, and artifact upload (the job has none).
- Publishing workflow outputs.

## 2. Context

- Target Environment: GitHub Actions (`ubuntu-slim`)
- Related Components:
  - `ca-run-secretlint` composite action (`aglabo/ci-platform/.github/actions/ca-run-secretlint@v0.8.0-pre`)
  - `.github/workflows/ru-scan-secrets.yml` (shared with `scan-betterleaks`)
  - Caller: `.github/workflows/ci-scan-secrets.yml` (job `scan-secrets`, no `with:` block)
- Assumptions:
  - The job has `contents: read` permission.
  - The runner provides Node.js; `ca-run-secretlint` installs pnpm itself.

### System Context Diagram

```text
Caller (ci-scan-secrets.yml)
        |  workflow_call
        v
+-----------------------------------------+
| ru-scan-secrets.yml                     |
|  scan-betterleaks   (separate module)   |
|  scan-secretlint (ubuntu-slim)          |
|    target-checkout                      |
|    secretlint-scan -> ca-run-secretlint |
+-----------------------------------------+
```

## 3. Design Decisions (Summary)

| ID    | Decision                                                                                 | Linked Record       |
| ----- | ---------------------------------------------------------------------------------------- | ------------------- |
| DR-01 | secretlint SHALL run as its own job, independent of `scan-betterleaks`.                  | decision-records.md |
| DR-02 | The job SHALL delegate to `ca-run-secretlint` and pass version inputs through unchanged. | decision-records.md |
| DR-03 | The job SHALL NOT validate the environment, resolve a configuration, or upload a report. | decision-records.md |

## 4. Functional Requirements

### REQ-F-001: Inputs

- EARS Type: feature-based

```text
GIVEN another workflow needs the secretlint scan
  WHERE the workflow_call trigger is defined
THEN the workflow MUST accept these optional inputs:
     secretlint-version (string, default "14.0.1"),
     pnpm-version (string, default "" meaning use packageManager of package.json),
     fetch-depth (number, default 50; shared with scan-betterleaks).
```

### REQ-F-002: Target Checkout

- EARS Type: event-driven

```text
GIVEN the scan-secretlint job has started
  WHEN the job begins
THEN it MUST check out the target repository with fetch-depth set to the fetch-depth input
     and persist-credentials false.
```

### REQ-F-003: Run secretlint

- EARS Type: event-driven

```text
GIVEN the target repository was checked out
  WHEN the job scans
THEN it MUST run ca-run-secretlint with pnpm-version and secretlint-version
     taken unchanged from the inputs,
     and the step MUST NOT run unless the checkout succeeded.
```

**Rationale**: The action validates the version, sets up pnpm, and runs `pnpm dlx secretlint@<version>`; the workflow only wires inputs.

### REQ-F-004: Fail-Fast

- EARS Type: unwanted behavior

```text
GIVEN secretlint exits with a non-zero status, or the action rejects an input
  NOT DO suppress the failure
THEN the scan-secretlint job MUST fail, and no step MAY use continue-on-error.
```

### REQ-F-005: Independence from Betterleaks

- EARS Type: unwanted behavior

```text
GIVEN scan-betterleaks fails
  NOT DO skip scan-secretlint
THEN scan-secretlint MUST still run, and the reverse MUST also hold
     (no needs relationship between the two jobs).
```

**Rationale**: A caller sees both scanners' results in one run.

## 5. Non-Functional Requirements

### REQ-NF-001: Minimum Permissions

The workflow and the job MUST declare `permissions: contents: read` and nothing else.

### REQ-NF-002: Credentials

The checkout MUST set `persist-credentials: false`. The job MUST NOT hard-code any token.

### REQ-NF-003: Observability

Step ids (`target-checkout`, `secretlint-scan`) and names MUST identify the failing unit from the Actions log alone.

## 6. Constraints

### REQ-C-001: Runner

The job MUST run on `ubuntu-slim` with a 10-minute timeout.

### REQ-C-002: Repository Action

The scan MUST use `aglabo/ci-platform/.github/actions/ca-run-secretlint@v0.8.0-pre`.

### REQ-C-003: Version Format

`secretlint-version` MUST be `X.Y.Z` with major 14 or later; `ca-run-secretlint` enforces this and the job fails otherwise.

## 7. User Stories

- As a repository maintainer, I want secretlint to run in CI with a pinned version, so that results are reproducible.
- As a security engineer, I want secretlint and betterleaks to run side by side, so that one scanner's failure never hides the other's.

## 8. Acceptance Criteria

```gherkin
# AC-001: Clean Repository Passes
# Requirement: REQ-F-002, REQ-F-003
Scenario: Clean Repository Passes
  Given a caller invokes the workflow and secretlint finds nothing
  When scan-secretlint runs
  Then the repository is checked out
  And ca-run-secretlint runs with the default secretlint-version 14.0.1
  And the job succeeds

# AC-002: Finding Fails the Job
# Requirement: REQ-F-004
Scenario: Finding Fails the Job
  Given secretlint detects a secret
  When secretlint exits non-zero
  Then the secretlint-scan step and the job fail

# AC-003: Supplied Versions Are Forwarded
# Requirement: REQ-F-001, REQ-F-003
Scenario: Supplied Versions Are Forwarded
  Given the caller passes secretlint-version "14.0.2" and pnpm-version "12.21.0"
  When ca-run-secretlint is called
  Then it receives exactly those values

# AC-004: Invalid Version Is Rejected
# Requirement: REQ-F-004, REQ-C-003
Scenario: Invalid Version Is Rejected
  Given the caller passes secretlint-version "13.0.0"
  When ca-run-secretlint validates it
  Then the job fails before secretlint runs

# AC-005: Jobs Are Independent
# Requirement: REQ-F-005
Scenario: Jobs Are Independent
  Given scan-betterleaks fails
  When the workflow runs
  Then scan-secretlint still runs
```

## 9. Open Questions

| Question                                                                           | Type      | Impact Area         | Owner         |
| ---------------------------------------------------------------------------------- | --------- | ------------------- | ------------- |
| Should the job use `ca-validate-environment` like `scan-betterleaks` does?         | Technical | Consistency         | Platform Team |
| Should a secretlint report be uploaded on failure?                                 | Product   | Failure diagnostics | Security Team |
| `fetch-depth` has no effect on a working-tree scan; should secretlint use depth 1? | Technical | Checkout cost       | Platform Team |

## 10. Traceability

| REQ ID     | AC IDs         | Type           |
| ---------- | -------------- | -------------- |
| REQ-F-001  | AC-003         | Functional     |
| REQ-F-002  | AC-001         | Functional     |
| REQ-F-003  | AC-001, AC-003 | Functional     |
| REQ-F-004  | AC-002, AC-004 | Functional     |
| REQ-F-005  | AC-005         | Functional     |
| REQ-NF-001 | -              | Non-functional |
| REQ-NF-002 | -              | Non-functional |
| REQ-NF-003 | -              | Non-functional |
| REQ-C-001  | -              | Constraint     |
| REQ-C-002  | AC-001         | Constraint     |
| REQ-C-003  | AC-004         | Constraint     |

## 11. Change History

| Date       | Version | Description     |
| ---------- | ------- | --------------- |
| 2026-11-19 | 1.0.0   | Initial release |
