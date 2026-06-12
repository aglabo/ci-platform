---
title: "Design Specification: Actionlint Reusable Workflow"
based-on: requirements.md v1.5
status: Draft
---

<!-- markdownlint-disable line-length -->

## 1. Overview

### 1.1 Purpose

This specification defines the behavioral design for the Actionlint reusable workflow. It describes workflow inputs, validation behavior, installation behavior, external configuration resolution, lint execution, report generation, and failure semantics.

<!-- impl-note: Module path: reusable-workflows/actionlint -->

### 1.2 Scope

This specification covers the reusable workflow behavior from trigger input resolution through environment validation, tool installation, configuration checkout, lint execution, and optional report upload.

It defines observable workflow behavior only. Implementation-specific action wiring, exact YAML syntax, and local file layout are implementation details unless carried in `impl-note` comments.

---

## 2. Design Principles

### 2.1 Classification Philosophy

The workflow SHALL be treated as a fail-fast quality gate.

Each unit SHALL have a single behavioral responsibility:

| Unit            | Responsibility                                                         |
| --------------- | ---------------------------------------------------------------------- |
| trigger-inputs  | Resolve caller-provided inputs and defaults                            |
| target-checkout | Check out the target repository into the workspace                     |
| env-validation  | Verify the runner and workflow environment before downstream execution |
| tool-install    | Install the linter tool into the executable search path                |
| config-checkout | Retrieve the shared linter configuration source                        |
| lint-execute    | Execute the linter and write results to a report file                  |
| report-upload   | Upload the lint report as an artifact on failure only                  |

### 2.2 Design Assumptions

| Assumption                    | Description                                                                                              |
| ----------------------------- | -------------------------------------------------------------------------------------------------------- |
| Hosted runner compatibility   | The workflow runs on a Linux hosted runner compatible with actionlint and local composite actions.       |
| Read-only repository access   | The workflow requires repository read access only.                                                       |
| External configuration source | Linter configuration is obtained from the fixed shared repository `aglabo/.github`, not from the caller. |
| Fixed checkout path           | The configuration source is always checked out into the `shared/` directory.                             |
| Fixed config repo             | The configuration repository is fixed to `aglabo/.github` and is not caller-configurable.                |
| Linter failure semantics      | A non-zero linter exit status represents a workflow failure.                                             |
| No published outputs          | The workflow communicates success or failure through job status only.                                    |
| Fixed timeout                 | The job timeout is fixed at 10 minutes and is not caller-configurable.                                   |

### 2.3 External Design Summary

#### Feature Decomposition

| Unit            | Pre-Conditions                   | Post-Conditions                                                   | Failure Behavior                                       |
| --------------- | -------------------------------- | ----------------------------------------------------------------- | ------------------------------------------------------ |
| trigger-inputs  | Workflow has been invoked        | Effective linter version and configuration file path are resolved | SHALL NOT fail under normal input omission             |
| target-checkout | Inputs resolved                  | Source code is available in the workspace                         | SHALL block all downstream units on checkout error     |
| env-validation  | Target checkout succeeded        | Environment status is successful                                  | SHALL block all downstream units on validation error   |
| tool-install    | Environment validation succeeded | Linter is available in the executable search path                 | SHALL fail the job on installation error               |
| config-checkout | Tool installation succeeded      | Shared linter configuration source is available at `shared/`      | SHALL fail the job when the source cannot be retrieved |
| lint-execute    | Configuration checkout completed | Linter exits and report file is written                           | SHALL fail immediately on non-zero linter exit         |
| report-upload   | lint-execute failed              | Lint report artifact is uploaded                                  | Non-fatal; workflow is already failed at lint-execute  |

<!-- impl-note: Local env-validation composite action inputs: architecture=amd64, actions-type=read, require-github-hosted=false. -->
<!-- impl-note: Local setup-tool composite action inputs: repo=rhysd/actionlint, tool-version=${{ inputs.actionlint-version }}. -->
<!-- impl-note: Configuration checkout path: shared/. Required linter config: shared/configs/actionlint.yaml (default). -->

#### Unit Interaction Map

```text
+----------------+
| trigger-inputs |
+-------+--------+
        |
        v
+-----------------+
| target-checkout |
+-------+---------+
        |
        v
+----------------+
| env-validation |
+-------+--------+
        |
        v
+----------------+
|  tool-install  |
+-------+--------+
        |
        v
+-----------------+
| config-checkout |
+-------+---------+
        |
        v
+----------------+     +---------------+
|  lint-execute  | --> | report-upload |
+----------------+     | (failure only)|
                       +---------------+
```

#### Data Flow Diagram

```text
Caller Inputs
  | actionlint-version
  | config-file
  v
+----------------+
| trigger-inputs |
+-------+--------+
        |
        | effective linter version
        | effective config file path
        v
+-----------------+
| target-checkout |
+-------+---------+
        | success
        v
+----------------+
| env-validation |
+-------+--------+
        | success
        v
+----------------+
|  tool-install  |
+-------+--------+
        | success
        v
+-----------------+
| config-checkout |
+-------+---------+
        | success
        v
+----------------+
|  lint-execute  |
+-------+--------+
        |
        +-- success --> Workflow Status: success
        |
        +-- failure --> +---------------+
                        | report-upload |
                        +---------------+
                              |
                              v
                        Workflow Status: failed
```

### 2.4 Non-Goals

| Non-Goal                                     | Reason                                                                   |
| -------------------------------------------- | ------------------------------------------------------------------------ |
| Publishing workflow outputs                  | The workflow is fail-fast only and has no output contract.               |
| Supporting caller-local linter configuration | The configuration source is fixed and external to the caller repository. |
| Supporting a configuration repository input  | The configuration repository is fixed to `aglabo/.github`.               |
| Requesting write permissions                 | The workflow requires read-only repository access.                       |
| Continuing after linter failure              | Linter failure SHALL fail the workflow immediately.                      |
| Delegating to an external reusable workflow  | The architecture uses local composite actions only.                      |
| Caller-configurable timeout                  | The job timeout is fixed at 10 minutes.                                  |

### 2.5 Behavioral Design Decisions

| ID     | Decision                                                                                               | Rationale                                                                                   | Affected Rules | Status   |
| ------ | ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------- | -------------- | -------- |
| DD-001 | The workflow SHALL resolve missing linter version input to the default stable version `1.7.12`.        | Callers should be able to use the workflow without specifying a version.                    | R-001          | Accepted |
| DD-002 | The workflow SHALL resolve missing config-file input to `./shared/configs/actionlint.yaml`.            | The default path provides organization-wide linter policy from the fixed config repository. | R-002          | Accepted |
| DD-003 | Environment validation SHALL run before installation and linting.                                      | Invalid runtime conditions should stop the workflow before side effects or lint work occur. | R-003, R-004   | Accepted |
| DD-004 | Tool installation SHALL be gated by successful environment validation.                                 | Installation should occur only in a validated environment.                                  | R-005, R-006   | Accepted |
| DD-005 | Configuration checkout SHALL be gated by successful tool installation.                                 | Configuration should be retrieved only when linting can proceed.                            | R-007, R-008   | Accepted |
| DD-006 | Lint execution SHALL be gated by completed configuration checkout.                                     | The linter requires the shared configuration source.                                        | R-009, R-010   | Accepted |
| DD-007 | Linter non-zero exit SHALL fail the workflow immediately.                                              | Lint errors are blocking quality gate failures.                                             | R-011          | Accepted |
| DD-008 | Workflow permissions SHALL be limited to read-only repository content access.                          | The workflow does not require mutation privileges.                                          | R-012          | Accepted |
| DD-009 | The configuration repository SHALL be fixed to `aglabo/.github` and not caller-configurable.           | Centralizing config management prevents per-caller policy divergence.                       | R-007          | Accepted |
| DD-010 | The config-file path SHALL be caller-overridable with a default of `./shared/configs/actionlint.yaml`. | Allows callers to reference a different config within the checked-out `shared/` directory.  | R-002, R-009   | Accepted |
| DD-011 | The job timeout SHALL be fixed at 10 minutes and not caller-configurable.                              | Lint jobs are expected to complete quickly; a fixed timeout prevents runaway jobs.          | R-013          | Accepted |
| DD-012 | The lint report SHALL be uploaded as an artifact on failure only.                                      | Preserves error details for investigation; avoids artifact storage on clean runs.           | R-017, R-018   | Accepted |

### 2.6 Related Decision Records

| DR ID | Decision                                                                  | Specification Impact                                                                        |
| ----- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| DR-01 | Independent reusable workflow                                             | The workflow SHALL use local composition rather than external reusable workflow delegation. |
| DR-02 | `workflow_call` trigger only                                              | The workflow SHALL support `workflow_call` invocation only.                                 |
| DR-03 | Use local composite actions                                               | Tool installation and environment validation SHALL use local composite actions.             |
| DR-04 | Linter version configurable via input with default                        | The linter version SHALL be caller-configurable and defaulted when omitted.                 |
| DR-05 | Configuration from fixed external repository with caller-overridable path | Config repo is fixed; config file path is caller-overridable with a default.                |
| DR-06 | Fail-fast on non-zero linter exit                                         | Lint failure SHALL fail the workflow immediately.                                           |
| DR-07 | Step gating with `steps.<id>.outcome == 'success'`                        | Each unit SHALL be conditioned on the previous unit's `outcome` field.                      |
| DR-08 | Security: timeout, persist-credentials, permissions                       | Fixed timeout, no persisted credentials, read-only permissions are required.                |

### 2.7 DD to DR Promotion Criteria

A design decision SHOULD be promoted to a decision record when any of the following are true:

| Criterion              | Promotion Trigger                                                                               |
| ---------------------- | ----------------------------------------------------------------------------------------------- |
| Cross-module impact    | The decision affects other reusable workflows or shared composite actions.                      |
| Public contract impact | The decision changes workflow inputs, permissions, triggers, or failure semantics.              |
| Migration cost         | Reversing the decision would require caller changes.                                            |
| Security posture       | The decision changes token usage, permissions, configuration source trust, or failure handling. |
| Operational policy     | The decision encodes organization-wide CI policy.                                               |

---

## 3. Behavioral Specification

### 3.1 Input Domain

| Input              | Required | Default                            | Constraints                                                                          | Behavior                                      |
| ------------------ | -------- | ---------------------------------- | ------------------------------------------------------------------------------------ | --------------------------------------------- |
| actionlint-version | No       | `1.7.12`                           | SHALL use semantic version format `X.Y.Z` when explicitly supplied                   | Determines the linter version to install      |
| config-file        | No       | `./shared/configs/actionlint.yaml` | SHALL be a valid path within the `shared/` directory after config-checkout completes | Determines the linter configuration file path |

<!-- impl-note: actionlint-version maps to setup-tool tool-version and must satisfy X.Y.Z format. -->
<!-- impl-note: config-file default is ./shared/configs/actionlint.yaml. The configuration source is always aglabo/.github checked out into shared/. -->
<!-- impl-note: target-checkout uses persist-credentials: false. -->

### 3.2 Output Semantics

The workflow SHALL publish no reusable workflow outputs.

The observable result SHALL be one of:

| Result  | Meaning                                                                                        |
| ------- | ---------------------------------------------------------------------------------------------- |
| Success | All units completed successfully and the linter exited with status `0`.                        |
| Failure | Environment validation, tool installation, configuration checkout, or linter execution failed. |

On failure caused by lint errors, the workflow SHALL produce a text report artifact named `actionlint-report` at `.github/report/actionlint-report.txt`.

### 3.3 Step Execution Semantics

The workflow SHALL execute units in this order:

```text
trigger-inputs -> target-checkout -> env-validation -> tool-install -> config-checkout -> prepare-report -> lint-execute -> report-upload
```

Each executable unit after input resolution SHALL be conditioned on the previous unit succeeding.

The lint execution unit SHALL fail fast. It MUST NOT ignore a non-zero linter exit status and MUST NOT continue on lint failure.

<!-- impl-note: Step gating pattern: if: steps.<id>.outcome == 'success'. -->
<!-- impl-note: Linter command: actionlint -config-file ${{ inputs.config-file }} 2>&1 | tee .github/report/actionlint-report.txt; exit ${PIPESTATUS[0]} -->
<!-- impl-note: prepare-report step: mkdir -p .github/report -->
<!-- impl-note: report-upload step: actions/checkout@9f698171ed81b15d1823a05fc7211befd50c8ae0 # v6.0.3 -->
<!-- impl-note: report-upload step: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1, if: failure() && steps.lint-execute.outcome == 'failure', name: actionlint-report, path: .github/report/actionlint-report.txt, retention-days: 30 -->
<!-- impl-note: target-checkout and config-checkout both use actions/checkout@9f698171ed81b15d1823a05fc7211befd50c8ae0 # v6.0.3 -->
<!-- impl-note: config-checkout: repository: aglabo/.github, path: shared, fetch-depth: 1, persist-credentials: false -->
<!-- impl-note: job timeout-minutes: 10 (fixed) -->

---

## 4. Decision Rules

| Rule ID | Step            | Condition                                                | Outcome                                                                                                                           |
| ------- | --------------- | -------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| R-001   | trigger-inputs  | `actionlint-version` is omitted                          | The workflow SHALL resolve the default linter version `1.7.12`.                                                                   |
| R-002   | trigger-inputs  | `config-file` is omitted                                 | The workflow SHALL resolve the default configuration file path `./shared/configs/actionlint.yaml`.                                |
| R-003   | env-validation  | Workflow execution has started                           | The workflow SHALL validate the runner and action environment before installation or linting.                                     |
| R-004   | env-validation  | Environment validation reports an error status           | The workflow SHALL block tool installation, configuration checkout, and lint execution.                                           |
| R-005   | tool-install    | Environment validation succeeded                         | The workflow SHALL install the requested linter version into the executable search path.                                          |
| R-006   | tool-install    | Tool installation fails                                  | The workflow SHALL fail the job and SHALL NOT run configuration checkout or lint execution.                                       |
| R-007   | config-checkout | Tool installation succeeded                              | The workflow SHALL checkout `aglabo/.github` into the `shared/` directory with `fetch-depth: 1` and `persist-credentials: false`. |
| R-008   | config-checkout | The configuration source is inaccessible                 | The workflow SHALL fail the job and SHALL NOT run lint execution.                                                                 |
| R-009   | lint-execute    | Configuration checkout completed                         | The workflow SHALL execute the linter using the resolved configuration file path.                                                 |
| R-010   | lint-execute    | Resolved configuration file is absent or unusable        | The linter execution SHALL fail and the workflow SHALL fail immediately.                                                          |
| R-011   | lint-execute    | Linter exits with a non-zero status                      | The workflow MUST fail immediately and MUST NOT continue on error.                                                                |
| R-012   | workflow        | Workflow permissions are evaluated                       | The workflow SHALL request read-only repository contents permission at workflow and job level.                                    |
| R-013   | workflow        | Job timeout is evaluated                                 | The job SHALL enforce a fixed timeout of 10 minutes.                                                                              |
| R-014   | workflow        | A downstream unit is evaluated after an upstream failure | The downstream unit SHALL be skipped unless explicitly covered by fail-fast lint behavior.                                        |
| R-015   | target-checkout | Checkout is performed                                    | The workflow SHALL set `persist-credentials: false` on the target repository checkout.                                            |
| R-016   | prepare-report  | lint-execute is about to run                             | The workflow SHALL create the `.github/report/` directory before executing the linter.                                            |
| R-017   | lint-execute    | Linter runs                                              | The workflow SHALL write lint results to `.github/report/actionlint-report.txt`.                                                  |
| R-018   | report-upload   | lint-execute exits with non-zero status                  | The workflow SHALL upload `.github/report/actionlint-report.txt` as artifact `actionlint-report` on failure only.                 |
| R-019   | report-upload   | lint-execute exits with status `0`                       | The workflow MUST NOT upload any artifact.                                                                                        |
| R-020   | target-checkout | Checkout is performed                                    | The workflow SHALL declare step ID `target-checkout` explicitly on the first checkout step.                                       |
| R-021   | trigger-inputs  | Inputs are declared                                      | Each workflow input SHALL include a non-empty `description` field.                                                                |
| R-022   | workflow        | Workflow identity is declared                            | The workflow SHALL declare a non-empty `name` field at the top level.                                                             |

---

## 5. Edge Cases

| Input / Condition                           | Behavior                                                             | REQ                  | Rationale                                                             |
| ------------------------------------------- | -------------------------------------------------------------------- | -------------------- | --------------------------------------------------------------------- |
| `actionlint-version` omitted                | The workflow SHALL use the default linter version `1.7.12`.          | REQ-F-002            | Callers should not need to know the current approved version.         |
| `config-file` omitted                       | The workflow SHALL use `./shared/configs/actionlint.yaml`.           | REQ-F-003b           | Organization-wide policy should apply by default.                     |
| `config-file` points to a non-existent path | Linter execution SHALL fail and the workflow SHALL fail immediately. | REQ-F-004            | Missing configuration is a blocking lint setup error.                 |
| Explicit linter version is not available    | Tool installation SHALL fail the job.                                | REQ-C-003, REQ-C-004 | Invalid or unavailable versions cannot produce reliable lint results. |
| Configuration source is inaccessible        | Configuration checkout SHALL fail the job.                           | REQ-F-003            | A lint run without configuration is not valid.                        |
| Linter detects a syntax error               | Lint execution SHALL fail fast; report SHALL be uploaded.            | REQ-F-004, REQ-F-006 | Lint errors are blocking quality gate failures.                       |
| Linter detects no errors                    | Workflow SHALL succeed; no artifact SHALL be uploaded.               | REQ-F-006            | Avoids unnecessary artifact storage on clean runs.                    |
| Environment validation reports an error     | All downstream units SHALL be blocked.                               | REQ-F-001            | Invalid execution environments should stop before install or lint.    |
| Caller expects workflow outputs             | No outputs SHALL be produced.                                        | Function Decisions   | The workflow communicates only by job status.                         |
| `.github/report/` directory does not exist  | The workflow SHALL create it before running the linter.              | REQ-F-005            | Ensures the report output path exists before the linter writes to it. |

---

## 6. Requirements Traceability

| REQ ID     | Rule IDs                   | Notes                                                                                                    |
| ---------- | -------------------------- | -------------------------------------------------------------------------------------------------------- |
| REQ-F-001  | R-003, R-004, R-014        | Environment validation runs before install and lint and blocks downstream failure paths.                 |
| REQ-F-002  | R-001, R-005, R-006        | Linter installation uses the resolved version and fails the job on installation error.                   |
| REQ-F-003  | R-007, R-008               | Configuration checkout is fixed to `aglabo/.github` into `shared/` with fetch-depth 1.                   |
| REQ-F-003b | R-002, R-009, R-010        | Lint execution uses the resolved config-file path; fails on absent or unusable configuration.            |
| REQ-F-004  | R-009, R-010, R-011        | Lint execution uses shared configuration and fails immediately on non-zero exit.                         |
| REQ-F-005  | R-016, R-017               | Report directory is created before lint; lint results written to `.github/report/actionlint-report.txt`. |
| REQ-F-006  | R-018, R-019               | Report uploaded as artifact on failure only; no upload on success.                                       |
| REQ-F-007  | R-003 (workflow)           | `workflow_call` trigger only.                                                                            |
| REQ-F-008  | R-015                      | `persist-credentials: false` on all checkout steps.                                                      |
| REQ-F-009  | R-013                      | Job timeout fixed at 10 minutes.                                                                         |
| REQ-NF-001 | R-003, R-005, R-007, R-009 | Each unit is represented by a separate named workflow step.                                              |
| REQ-NF-002 | R-012                      | Permissions limited to read-only repository contents access.                                             |
| REQ-NF-003 | R-001, R-005               | Linter version comes from input resolution.                                                              |
| REQ-NF-004 | R-018                      | Lint report artifact enables error investigation without CI log access.                                  |
| REQ-NF-005 | R-007, R-009               | Configuration location and source are deterministic.                                                     |
| REQ-C-001  | R-003                      | Runner compatibility is validated before downstream execution.                                           |
| REQ-C-002  | R-012                      | Read-only contents permission at workflow and job level.                                                 |
| REQ-C-003  | R-001                      | `actionlint-version` input uses `X.Y.Z` semantic version format.                                         |
| REQ-C-004  | R-003, R-005               | Local composite actions provide validation and installation behavior.                                    |
| REQ-C-005  | R-002, R-007, R-009        | `config-file` default resolves to `./shared/configs/actionlint.yaml`.                                    |
| REQ-C-006  | R-014                      | Step gating uses `steps.<id>.outcome == 'success'` pattern.                                              |
| REQ-C-007  | R-015                      | `persist-credentials: false` on all `actions/checkout` steps.                                            |
| REQ-C-008  | R-013                      | Job `timeout-minutes` fixed at 10.                                                                       |
| REQ-NF-001 | R-020                      | Each step SHALL declare an explicit step ID.                                                             |
| (implicit) | R-021                      | Each input SHALL include a description for maintainability.                                              |
| (implicit) | R-022                      | The workflow SHALL declare a name for observability in the Actions UI.                                   |

---

## 7. Open Questions

| # | Question                                             | Source    | Impact                          |
| - | ---------------------------------------------------- | --------- | ------------------------------- |
| 1 | `workflow_dispatch` を将来的に追加する可能性はあるか | REQ OQ-02 | Trigger section change if added |

---

## 8. Change History

| Date       | Version | Change                                                                                  |
| ---------- | ------- | --------------------------------------------------------------------------------------- |
| 2026-06-12 | 1.1.0   | Add R-020 (step ID), R-021 (input description), R-022 (workflow name) from tasks review |
| 2026-06-12 | 1.0.0   | Initial specification                                                                   |
