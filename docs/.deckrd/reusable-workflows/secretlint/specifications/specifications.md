---
title: "Design Specification: Secretlint Scan Job (Reusable Workflow)"
version: 1.0.0
based-on: requirements.md v1.0.0
status: Draft
---

<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/max-comma,
  ja-technical-writing/no-exclamation-question-mark
  -->
<!-- markdownlint-disable line-length -->

## 1. Overview

### 1.1 Purpose

This specification defines the behavioral design of the `scan-secretlint` job in `ru-scan-secrets.yml`: input resolution, checkout, delegation to `ca-run-secretlint`, and failure semantics.

<!-- impl-note: Module path: reusable-workflows/secretlint -->

### 1.2 Scope

Behavior from `workflow_call` inputs to the job result. The job shares the workflow file with `scan-betterleaks`; that job is specified in `reusable-workflows/betterleaks`.

## 2. Design Principles

### 2.1 Classification Philosophy

The job is a fail-fast quality gate with two units.

| Unit            | Responsibility                                                       |
| --------------- | -------------------------------------------------------------------- |
| trigger-inputs  | Resolve the secretlint version, pnpm version, and fetch depth        |
| target-checkout | Retrieve the repository to scan                                      |
| secretlint-scan | Delegate validation, pnpm setup, and the scan to `ca-run-secretlint` |

### 2.2 Design Assumptions

| Assumption            | Description                                                            |
| --------------------- | ---------------------------------------------------------------------- |
| Read-only access      | The job needs `contents: read` only.                                   |
| Bundled configuration | secretlint v14+ ships its rules; the job takes no configuration input. |
| Job independence      | The job has no `needs`; it runs in parallel with `scan-betterleaks`.   |
| No published outputs  | The workflow communicates through job status only.                     |

### 2.3 External Design Summary

#### Unit Interaction Map

```text
trigger-inputs -> target-checkout -> secretlint-scan (ca-run-secretlint)
```

#### Data Flow

```text
inputs.fetch-depth --> actions/checkout (fetch-depth)
inputs.pnpm-version, inputs.secretlint-version --> ca-run-secretlint --> pnpm dlx secretlint@<version>
secretlint exit status --> job status
```

### 2.4 Non-Goals

| Non-Goal                           | Reason                                                    |
| ---------------------------------- | --------------------------------------------------------- |
| Environment validation in this job | The action validates its own inputs; see requirements §9. |
| Configuration or ignore-file input | secretlint v14 bundles its configuration.                 |
| Report artifact                    | secretlint writes to the log only.                        |
| Publishing workflow outputs        | Results are conveyed by job status.                       |

### 2.5 Behavioral Design Decisions

| ID     | Decision                                                                | Rationale                                            | Affected Rules | Status   |
| ------ | ----------------------------------------------------------------------- | ---------------------------------------------------- | -------------- | -------- |
| DD-001 | The job SHALL have no `needs` relationship with `scan-betterleaks`.     | Both scanners report in one run.                     | R-006          | Accepted |
| DD-002 | Version inputs SHALL be forwarded unchanged to the action.              | Validation lives in one place (`ca-run-secretlint`). | R-003, R-004   | Accepted |
| DD-003 | `fetch-depth` SHALL be passed to the checkout even though it is shared. | One input shape for both scanning jobs.              | R-002          | Accepted |

### 2.6 Related Decision Records

| DR ID | Decision                                | Specification Impact |
| ----- | --------------------------------------- | -------------------- |
| DR-01 | Separate, independent secretlint job    | R-006                |
| DR-02 | Delegate to `ca-run-secretlint`         | R-003, R-004         |
| DR-03 | No validation, configuration, or report | R-005                |

## 3. Behavioral Specification

### 3.1 Input Domain

| Input                | Required | Default  | Constraints                                        | Behavior                           |
| -------------------- | -------- | -------- | -------------------------------------------------- | ---------------------------------- |
| `secretlint-version` | No       | `14.0.1` | `X.Y.Z`, major 14 or later (checked by the action) | Passed to `ca-run-secretlint`      |
| `pnpm-version`       | No       | `""`     | Empty means resolve from `packageManager`          | Passed to `ca-run-secretlint`      |
| `fetch-depth`        | No       | `50`     | Non-negative integer; `0` means full history       | Controls the target checkout depth |

<!-- impl-note: betterleaks-specific inputs (version, config-repo, config) exist in the same workflow and are ignored by this job. -->

### 3.2 Output Semantics

The workflow publishes no `workflow_call` outputs and the job has no job outputs. The result is the job status: success when secretlint exits `0`, failure otherwise. No artifact is uploaded.

### 3.3 Step Execution Semantics

```text
target-checkout -> secretlint-scan
```

`target-checkout` has no condition. `secretlint-scan` is gated on `steps.target-checkout.outcome == 'success'`.

<!-- impl-note: runs-on ubuntu-slim, timeout-minutes 10, job permissions contents: read. -->
<!-- impl-note: target-checkout: actions/checkout with fetch-depth ${{ inputs.fetch-depth }}, persist-credentials false. -->
<!-- impl-note: secretlint-scan: aglabo/ci-platform/.github/actions/ca-run-secretlint@v0.8.0-pre with pnpm-version ${{ inputs.pnpm-version }} and secretlint-version ${{ inputs.secretlint-version }}. -->

## 4. Decision Rules

| Rule ID | Step            | Condition                               | Outcome                                                                                   |
| ------- | --------------- | --------------------------------------- | ----------------------------------------------------------------------------------------- |
| R-001   | trigger-inputs  | An input is omitted                     | The job SHALL use the default in section 3.1.                                             |
| R-002   | target-checkout | The job starts                          | The job SHALL check out with the resolved `fetch-depth` and `persist-credentials: false`. |
| R-003   | secretlint-scan | The checkout succeeded                  | The job SHALL call `ca-run-secretlint` with both version inputs unchanged.                |
| R-004   | secretlint-scan | The action rejects `secretlint-version` | The step and job SHALL fail before secretlint runs.                                       |
| R-005   | secretlint-scan | secretlint exits non-zero               | The step and job SHALL fail; no `continue-on-error` and no report upload.                 |
| R-006   | workflow        | `scan-betterleaks` fails                | `scan-secretlint` SHALL still run, and the reverse SHALL hold.                            |
| R-007   | workflow        | Permissions are evaluated               | The workflow and job SHALL request `contents: read` only.                                 |
| R-008   | secretlint-scan | The checkout failed                     | The step SHALL be skipped.                                                                |

## 5. Edge Cases

| Input                                  | Behavior                                                  | REQ       | Rationale                                          |
| -------------------------------------- | --------------------------------------------------------- | --------- | -------------------------------------------------- |
| `secretlint-version` omitted           | `14.0.1` is used.                                         | REQ-F-001 | Callers need no knowledge of the version.          |
| `secretlint-version` below 14 or a tag | `ca-run-secretlint` rejects it; the job fails.            | REQ-C-003 | Older versions need a configuration file.          |
| `pnpm-version` empty                   | pnpm is resolved from `packageManager` of `package.json`. | REQ-F-003 | Avoids a pinned version conflicting with the repo. |
| `fetch-depth: 0`                       | Full history is fetched; the scan result is unchanged.    | REQ-F-002 | secretlint scans the working tree.                 |
| `scan-betterleaks` fails               | `scan-secretlint` still runs.                             | REQ-F-005 | Independent results.                               |

## 6. Requirements Traceability

| REQ ID     | Rule IDs     | Notes                                  |
| ---------- | ------------ | -------------------------------------- |
| REQ-F-001  | R-001        | Inputs and defaults.                   |
| REQ-F-002  | R-002        | Target checkout.                       |
| REQ-F-003  | R-003, R-008 | Delegation to the action.              |
| REQ-F-004  | R-004, R-005 | Fail-fast.                             |
| REQ-F-005  | R-006        | Independence from betterleaks.         |
| REQ-NF-001 | R-007        | Minimum permissions.                   |
| REQ-NF-002 | R-002        | Credentials not persisted.             |
| REQ-NF-003 | R-003        | Named steps.                           |
| REQ-C-001  | R-002        | Runner and timeout.                    |
| REQ-C-002  | R-003        | Repository action at `@v0.8.0-pre`.    |
| REQ-C-003  | R-004        | Version format enforced by the action. |

## 7. Open Questions

| # | Question                                  | Source          | Impact              |
| - | ----------------------------------------- | --------------- | ------------------- |
| 1 | Add `ca-validate-environment` to the job? | requirements §9 | Consistency         |
| 2 | Upload a report on failure?               | requirements §9 | Failure diagnostics |

## 8. Change History

| Date       | Version | Change                |
| ---------- | ------- | --------------------- |
| 2026-11-19 | 1.0.0   | Initial specification |
