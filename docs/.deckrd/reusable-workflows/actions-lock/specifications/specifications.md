---
title: "Design Specification: Actions Lock Reusable Workflow"
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

This specification defines the behavioral design of `ru-qa-actions-lock.yml`: input resolution, environment validation, extension installation, lockfile verification, and failure semantics.

<!-- impl-note: Module path: reusable-workflows/actions-lock -->

### 1.2 Scope

Behavior from `workflow_call` input to the uploaded report. Exact YAML syntax is an implementation detail unless carried in an `impl-note`.

## 2. Design Principles

### 2.1 Classification Philosophy

The workflow is a fail-fast quality gate with a single job.

| Unit            | Responsibility                                                               |
| --------------- | ---------------------------------------------------------------------------- |
| trigger-inputs  | Resolve the extension version                                                |
| target-checkout | Retrieve the repository whose lockfile is verified                           |
| env-validation  | Verify the runner and permissions before downstream work                     |
| tool-install    | Install the pinned `gh actions-lock` extension                               |
| tool-version    | Print the installed version for the log                                      |
| prepare-report  | Create the report directory                                                  |
| lock-verify     | Run the verification and keep its output as a report                         |
| report-upload   | Upload the report when verification failed                                   |

### 2.2 Design Assumptions

| Assumption           | Description                                                                    |
| -------------------- | ------------------------------------------------------------------------------ |
| Read-only access     | The job needs `contents: read` only.                                           |
| Token for `gh`       | `github.token` authenticates `gh extension install` and `gh actions-lock`.     |
| No configuration     | The verification has no configuration file; the lockfile is the only input.    |
| No published outputs | The workflow communicates through job status and artifacts only.               |

### 2.3 External Design Summary

#### Unit Interaction Map

```text
trigger-inputs -> target-checkout -> env-validation -> tool-install
  -> tool-version -> prepare-report -> lock-verify -> report-upload (on failure)
```

#### Data Flow

```text
inputs.version --> gh extension install --pin --> gh actions-lock
actions.lock + workflow files --> gh actions-lock --verify --> .github/report/actions-lock-report.txt
report --> artifact actions-lock-report (on failure)
```

### 2.4 Non-Goals

| Non-Goal                         | Reason                                                  |
| -------------------------------- | ------------------------------------------------------- |
| Updating `actions.lock`          | Updates are a deliberate maintainer action.             |
| Custom lockfile path             | The repository's own lockfile is the only target.       |
| Interactive prompts              | `--no-interactive` keeps CI non-blocking.               |
| Publishing workflow outputs      | Results are conveyed by job status and artifacts.       |

### 2.5 Behavioral Design Decisions

| ID     | Decision                                                                 | Rationale                                                     | Affected Rules | Status   |
| ------ | ------------------------------------------------------------------------ | ------------------------------------------------------------- | -------------- | -------- |
| DD-001 | The extension SHALL be installed with `--pin <version>`.                 | Reproducible verification.                                    | R-003          | Accepted |
| DD-002 | `GH_TOKEN` SHALL be set on the steps that call `gh` only.                | Limits token exposure.                                        | R-003, R-004   | Accepted |
| DD-003 | The verify exit status SHALL be taken from `PIPESTATUS[0]`.              | `tee` would otherwise mask a failed verification.             | R-005          | Accepted |
| DD-004 | The report SHALL be uploaded only when `lock-verify` itself failed.      | Setup failures have no report to upload.                      | R-006          | Accepted |

### 2.6 Related Decision Records

| DR ID | Decision                                          | Specification Impact |
| ----- | ------------------------------------------------- | -------------------- |
| DR-01 | Pinned `gh extension install`                     | R-003                |
| DR-02 | `--verify --no-interactive` with a saved report   | R-004, R-005         |
| DR-03 | No `ca-setup-tool` or `_ca-resolve-config`        | R-003                |

## 3. Behavioral Specification

### 3.1 Input Domain

| Input     | Required | Default   | Constraints                                         | Behavior                            |
| --------- | -------- | --------- | --------------------------------------------------- | ----------------------------------- |
| `version` | No       | `v0.4.1`  | A release tag of `github/gh-actions-lock`           | Passed to `--pin` of the install    |

<!-- impl-note: version is exposed to the step as env EXT_VERSION so the shell never interpolates the expression. -->

### 3.2 Output Semantics

The workflow publishes no `workflow_call` outputs and no job outputs.

| Result  | Meaning                                                                      |
| ------- | ---------------------------------------------------------------------------- |
| Success | Every step succeeded and `gh actions-lock --verify` exited `0`.              |
| Failure | Validation, installation, or verification failed.                            |

On a verification failure the job uploads the artifact `actions-lock-report` (`.github/report/actions-lock-report.txt`, retention 30 days).

### 3.3 Step Execution Semantics

```text
target-checkout -> env-validation -> tool-install -> tool-version -> prepare-report -> lock-verify -> report-upload
```

`target-checkout` runs without a condition. Each later step up to `lock-verify` is gated on the previous step id (`steps.<id>.outcome == 'success'`). `report-upload` runs when `failure() && steps.lock-verify.outcome == 'failure'`.

<!-- impl-note: runs-on ubuntu-slim, timeout-minutes 10, job permissions contents: read. -->
<!-- impl-note: target-checkout: actions/checkout with persist-credentials false (default fetch depth). -->
<!-- impl-note: env-validation: aglabo/ci-platform/.github/actions/ca-validate-environment@v0.8.0-pre with actions-type read. -->
<!-- impl-note: tool-install: gh extension install github/gh-actions-lock --pin "${EXT_VERSION}", env GH_TOKEN and EXT_VERSION. -->
<!-- impl-note: lock-verify: gh actions-lock --verify --no-interactive 2>&1 | tee .github/report/actions-lock-report.txt; exit "${PIPESTATUS[0]}". -->

## 4. Decision Rules

| Rule ID | Step           | Condition                                         | Outcome                                                                                                                            |
| ------- | -------------- | ------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| R-001   | trigger-inputs | `version` is omitted                              | The workflow SHALL use `v0.4.1`.                                                                                                   |
| R-002   | env-validation | Validation reports an error                       | The job SHALL stop before installing the extension.                                                                                |
| R-003   | tool-install   | Environment validation succeeded                  | The workflow SHALL install `github/gh-actions-lock` pinned to `version`.                                                           |
| R-004   | tool-version   | Installation succeeded                            | The workflow SHALL print `gh actions-lock --version`.                                                                              |
| R-005   | lock-verify    | The report directory exists                       | The workflow SHALL run `gh actions-lock --verify --no-interactive`, tee the output to the report, and exit with the verify status. |
| R-006   | report-upload  | `lock-verify` failed                              | The report SHALL be uploaded as `actions-lock-report`, retention 30 days.                                                          |
| R-007   | report-upload  | `lock-verify` succeeded or an earlier step failed | No artifact SHALL be uploaded.                                                                                                     |
| R-008   | workflow       | Permissions are evaluated                         | The workflow and job SHALL request `contents: read` only.                                                                          |
| R-009   | workflow       | A step fails                                      | Later steps SHALL be skipped (outcome gating), except `report-upload`.                                                             |

## 5. Edge Cases

| Input                                    | Behavior                                                          | REQ        | Rationale                                      |
| ---------------------------------------- | ----------------------------------------------------------------- | ---------- | ---------------------------------------------- |
| `version` omitted                        | `v0.4.1` is installed.                                            | REQ-F-001  | Callers need no knowledge of the version.      |
| `version` names a nonexistent tag        | `tool-install` fails; no verification runs; no report uploaded.   | REQ-F-003  | Setup failure is blocking.                     |
| `actions.lock` is missing or stale       | `lock-verify` fails and the report is uploaded.                   | REQ-F-004  | The lockfile is the verified artifact.         |
| `lock-verify` output is piped to `tee`   | The job fails with the verify status, not the `tee` status.       | REQ-F-004  | `tee` must not mask failures.                  |

## 6. Requirements Traceability

| REQ ID     | Rule IDs            | Notes                                       |
| ---------- | ------------------- | ------------------------------------------- |
| REQ-F-001  | R-001               | Input and default.                          |
| REQ-F-002  | R-002               | Environment validation.                     |
| REQ-F-003  | R-003, R-004        | Pinned installation and version print.      |
| REQ-F-004  | R-005               | Verification and report.                    |
| REQ-F-005  | R-006, R-007        | Report upload on failure only.              |
| REQ-F-006  | R-009               | Fail-fast chain.                            |
| REQ-NF-001 | R-008               | Minimum permissions.                        |
| REQ-NF-002 | R-003               | Token scope and checkout credentials.       |
| REQ-NF-003 | R-002, R-005        | Named steps.                                |
| REQ-C-001  | R-002               | Runner and timeout.                         |
| REQ-C-002  | R-002               | Repository action at `@v0.8.0-pre`.         |
| REQ-C-003  | R-005               | Own lockfile only.                          |

## 7. Open Questions

| #   | Question                                                     | Source          | Impact                |
| --- | ------------------------------------------------------------ | --------------- | --------------------- |
| 1   | Pin the extension by checksum rather than tag?               | requirements §9 | Supply-chain security |

## 8. Change History

| Date       | Version | Change                |
| ---------- | ------- | --------------------- |
| 2026-11-19 | 1.0.0   | Initial specification |
