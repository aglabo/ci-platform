---
title: "Design Specification: Betterleaks Reusable Workflow"
based-on: requirements.md v1.1
status: Draft
---

<!-- markdownlint-disable line-length -->

## 1. Overview

### 1.1 Purpose

This specification defines the behavioral design for the Betterleaks reusable workflow. It describes workflow inputs, validation behavior, installation behavior, external configuration resolution, scan execution, failure semantics, and traceability to requirements.

<!-- impl-note: Module path: reusable-workflows/betterleaks -->

### 1.2 Scope

This specification covers the reusable workflow behavior from trigger input resolution through environment validation, tool installation, configuration checkout, and secret scan execution.

It defines observable workflow behavior only. Implementation-specific action wiring, exact YAML syntax, and local file layout are implementation details unless carried in `impl-note` comments.

## 2. Design Principles

### 2.1 Classification Philosophy

The workflow SHALL be treated as a fail-fast quality gate.

Each unit SHALL have a single behavioral responsibility:

| Unit            | Responsibility                                                                   |
| --------------- | -------------------------------------------------------------------------------- |
| trigger-inputs  | Resolve caller-provided inputs and defaults                                      |
| env-validation  | Verify the runner and workflow environment before downstream execution           |
| tool-install    | Install the scanner tool into the executable search path                         |
| config-checkout | Retrieve the shared scanner configuration source                                 |
| scan-execute    | Execute the scan and fail immediately on detected violations or execution errors |

### 2.2 Design Assumptions

| Assumption                    | Description                                                                                                     |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Hosted runner compatibility   | The workflow runs on a Linux hosted runner compatible with the scanner and local composite actions.             |
| Read-only repository access   | The workflow requires repository read access only.                                                              |
| External configuration source | Scanner configuration is obtained from the configured shared repository source, not from the caller repository. |
| Fixed checkout path           | The configuration source is always checked out into the `shared/` directory (default branch).                   |
| Scanner failure semantics     | A non-zero scanner exit status represents a workflow failure.                                                   |
| No published outputs          | The workflow communicates success or failure through job status only.                                           |

### 2.3 External Design Summary

#### Feature Decomposition

| Unit            | Pre-Conditions                   | Post-Conditions                                                 | Failure Behavior                                       |
| --------------- | -------------------------------- | --------------------------------------------------------------- | ------------------------------------------------------ |
| trigger-inputs  | Workflow has been invoked        | Effective scanner version and configuration source are resolved | SHALL NOT fail under normal input omission             |
| env-validation  | Workflow has started             | Environment status is successful                                | SHALL block all downstream units on validation error   |
| tool-install    | Environment validation succeeded | Scanner is available in the executable search path              | SHALL fail the job on installation error               |
| config-checkout | Tool installation succeeded      | Shared scanner configuration source is available locally        | SHALL fail the job when the source cannot be retrieved |
| scan-execute    | Configuration checkout completed | Scanner exits successfully                                      | SHALL fail immediately on non-zero scanner exit        |

<!-- impl-note: Local env-validation composite action inputs: architecture=amd64, actions-type=read, require-github-hosted=false. -->
<!-- impl-note: Local setup-tool composite action installs betterleaks/betterleaks into ${RUNNER_TEMP}/bin and appends that directory to GITHUB_PATH. -->
<!-- impl-note: Configuration checkout implementation path: shared. Required scanner config: shared/configs/betterleaks.toml. -->

#### Unit Interaction Map

```text
+----------------+
| trigger-inputs |
+-------+--------+
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
+----------------+
|  scan-execute  |
+----------------+
```

#### Data Flow Diagram

```text
Caller Inputs
  | betterleaks-version
  | config-repo
  v
+----------------+
| trigger-inputs |
+-------+--------+
        |
        | effective scanner version
        | effective configuration source
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
|  scan-execute  |
+----------------+
        |
        v
Workflow Status: success or failed
```

### 2.4 Non-Goals

| Non-Goal                                      | Reason                                                                           |
| --------------------------------------------- | -------------------------------------------------------------------------------- |
| Publishing workflow outputs                   | The workflow is fail-fast only and has no output contract.                       |
| Supporting caller-local scanner configuration | The configuration source is deterministic and external to the caller repository. |
| Supporting a configuration source ref input   | The configuration source is checked out from its default branch into `shared/`.  |
| Requesting write permissions                  | The workflow requires read-only repository access.                               |
| Continuing after scanner failure              | Scanner failure SHALL fail the workflow immediately.                             |
| Delegating to an external reusable workflow   | The architecture uses local composite actions only.                              |

### 2.5 Behavioral Design Decisions

| ID     | Decision                                                                                    | Rationale                                                                                   | Affected Rules | Status   |
| ------ | ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | -------------- | -------- |
| DD-001 | The workflow SHALL resolve missing scanner version input to a default stable version.       | Callers should be able to use the workflow without specifying a version.                    | R-001          | Accepted |
| DD-002 | The workflow SHALL resolve missing configuration source input to the shared default source. | The default source provides organization-wide scanner policy.                               | R-002          | Accepted |
| DD-003 | Environment validation SHALL run before installation and scanning.                          | Invalid runtime conditions should stop the workflow before side effects or scan work occur. | R-003, R-004   | Accepted |
| DD-004 | Tool installation SHALL be gated by successful environment validation.                      | Installation should occur only in a validated environment.                                  | R-005, R-006   | Accepted |
| DD-005 | Configuration checkout SHALL be gated by successful tool installation.                      | Configuration should be retrieved only when scanning can proceed.                           | R-007, R-008   | Accepted |
| DD-006 | Scan execution SHALL be gated by completed configuration checkout.                          | The scanner requires the shared configuration source.                                       | R-009, R-010   | Accepted |
| DD-007 | Scanner non-zero exit SHALL fail the workflow immediately.                                  | Secret detection and execution errors are blocking quality gate failures.                   | R-011          | Accepted |
| DD-008 | Workflow permissions SHALL be limited to read-only repository content access.               | The workflow does not require mutation privileges.                                          | R-012          | Accepted |

### 2.6 Related Decision Records

| DR ID | Decision                                                 | Specification Impact                                                                        |
| ----- | -------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| DR-01 | Independent reusable workflow                            | The workflow SHALL use local composition rather than external reusable workflow delegation. |
| DR-02 | Validate environment before install and scan             | Environment validation SHALL be the first executable gate after input resolution.           |
| DR-03 | Use local tool installer                                 | Tool installation SHALL be performed by the local installation unit.                        |
| DR-04 | Scanner version configurable via input with default      | The scanner version SHALL be caller-configurable and defaulted when omitted.                |
| DR-05 | Configuration from checked-out repository source         | Scanner configuration SHALL come from the configured external source.                       |
| DR-06 | Fail-fast on non-zero scanner exit                       | Scan failure SHALL fail the workflow immediately.                                           |
| DR-07 | Configuration source configurable via input with default | The configuration source SHALL be caller-configurable and defaulted when omitted.           |

### 2.7 DD to DR Promotion Criteria

A design decision SHOULD be promoted to a decision record when any of the following are true:

| Criterion              | Promotion Trigger                                                                               |
| ---------------------- | ----------------------------------------------------------------------------------------------- |
| Cross-module impact    | The decision affects other reusable workflows or shared composite actions.                      |
| Public contract impact | The decision changes workflow inputs, permissions, triggers, or failure semantics.              |
| Migration cost         | Reversing the decision would require caller changes.                                            |
| Security posture       | The decision changes token usage, permissions, configuration source trust, or failure handling. |
| Operational policy     | The decision encodes organization-wide CI policy.                                               |

## 3. Behavioral Specification

### 3.1 Input Domain

| Input               | Required | Default        | Constraints                                                                                                    | Behavior                                     |
| ------------------- | -------- | -------------- | -------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| betterleaks-version | No       | `1.4.1`        | MUST be compatible with supported scanner releases; SHALL use semantic version format when explicitly supplied | Determines the scanner version to install    |
| config-repo         | No       | aglabo/.github | MUST identify an accessible repository source                                                                  | Determines the external configuration source |
| fetch-depth         | No       | `1`            | MUST be a non-negative integer; `0` means full history                                                         | Controls git fetch depth for target checkout |

<!-- impl-note: betterleaks-version maps to setup-tool tool-version and must satisfy X.Y.Z format. -->
<!-- impl-note: config-repo default is aglabo/.github. The configuration source is checked out into shared/ (default branch, no ref specified). -->
<!-- impl-note: fetch-depth maps to actions/checkout with.fetch-depth. Default 1 fetches latest commit only. -->

### 3.2 Output Semantics

The workflow SHALL publish no reusable workflow outputs.

The observable result SHALL be one of:

| Result  | Meaning                                                                                         |
| ------- | ----------------------------------------------------------------------------------------------- |
| Success | All units completed successfully and the scanner exited with status `0`.                        |
| Failure | Environment validation, tool installation, configuration checkout, or scanner execution failed. |

On failure, the workflow SHALL produce a JSON report artifact named `betterleaks-report` at `.github/report/betterleaks-report.json`.

### 3.3 Step Execution Semantics

The workflow SHALL execute units in this order:

```text
trigger-inputs -> env-validation -> target-checkout -> tool-install -> config-checkout -> prepare-report -> scan-execute -> upload-report
```

Each executable unit after input resolution SHALL be conditioned on the previous unit succeeding.

The scanner execution unit SHALL fail fast. It MUST NOT ignore a non-zero scanner exit status and MUST NOT continue on scan failure.

<!-- impl-note: Step gating pattern: if: steps.<id>.outcome == 'success'. -->
<!-- impl-note: Scanner command: betterleaks protect --config shared/configs/betterleaks.toml --report-path=.github/report/betterleaks-report.json --exit-code=1 -->
<!-- impl-note: upload-report step uses: actions/upload-artifact, if: failure() && steps.scan-execute.outputs.status != '0', name: betterleaks-report, path: .github/report/betterleaks-report.json -->
<!-- impl-note: target-checkout uses fetch-depth: ${{ inputs.fetch-depth }} and persist-credentials: false -->

## 4. Decision Rules

| Rule ID | Step            | Condition                                                | Outcome                                                                                                               |
| ------- | --------------- | -------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| R-001   | trigger-inputs  | `betterleaks-version` is omitted                         | The workflow SHALL resolve the default scanner version `1.4.1`.                                                       |
| R-002   | trigger-inputs  | `config-repo` is omitted                                 | The workflow SHALL resolve the default shared configuration source (`aglabo/.github`).                                |
| R-003   | env-validation  | Workflow execution has started                           | The workflow SHALL validate the runner and action environment before installation or scanning.                        |
| R-004   | env-validation  | Environment validation reports an error status           | The workflow SHALL block tool installation, configuration checkout, and scan execution.                               |
| R-005   | tool-install    | Environment validation succeeded                         | The workflow SHALL install the requested scanner version into the executable search path.                             |
| R-006   | tool-install    | Tool installation fails                                  | The workflow SHALL fail the job and SHALL NOT run configuration checkout or scan execution.                           |
| R-007   | config-checkout | Tool installation succeeded                              | The workflow SHALL checkout the configured shared configuration source into the `shared/` directory (default branch). |
| R-008   | config-checkout | The configured source is inaccessible                    | The workflow SHALL fail the job and SHALL NOT run scan execution.                                                     |
| R-009   | scan-execute    | Configuration checkout completed                         | The workflow SHALL execute the scanner using the shared scanner configuration.                                        |
| R-010   | scan-execute    | Shared scanner configuration is absent or unusable       | The scanner execution SHALL fail and the workflow SHALL fail immediately.                                             |
| R-011   | scan-execute    | Scanner exits with a non-zero status                     | The workflow MUST fail immediately and MUST NOT continue on error.                                                    |
| R-012   | workflow        | Workflow permissions are evaluated                       | The workflow SHALL request read-only repository contents permission.                                                  |
| R-013   | workflow        | Workflow is invoked by reusable call or manual dispatch  | The workflow SHALL expose the same behavioral inputs for both invocation modes.                                       |
| R-014   | workflow        | A downstream unit is evaluated after an upstream failure | The downstream unit SHALL be skipped unless explicitly covered by fail-fast scan behavior.                            |
| R-015   | trigger-inputs  | `fetch-depth` is omitted                                 | The workflow SHALL resolve the default fetch depth `1`.                                                               |
| R-016   | target-checkout | fetch-depth is resolved                                  | The workflow SHALL pass the resolved fetch-depth to the target repository checkout.                                   |
| R-017   | prepare-report  | scan-execute is about to run                             | The workflow SHALL create the `.github/report/` directory before executing the scanner.                               |
| R-018   | scan-execute    | Scanner runs                                             | The workflow SHALL write scan results to `.github/report/betterleaks-report.json`.                                    |
| R-019   | scan-execute    | Scanner exits with non-zero status                       | The workflow SHALL expose the scanner exit code as a step output named `status`.                                      |
| R-020   | upload-report   | Scan step exits with non-zero status                     | The workflow SHALL upload `.github/report/betterleaks-report.json` as artifact `betterleaks-report` on failure only.  |
| R-021   | upload-report   | Scan step exits with status `0`                          | The workflow MUST NOT upload any artifact.                                                                            |

## 5. Edge Cases

| Input                                      | Behavior                                                            | REQ                   | Rationale                                                             |
| ------------------------------------------ | ------------------------------------------------------------------- | --------------------- | --------------------------------------------------------------------- |
| `betterleaks-version` omitted              | The workflow SHALL use the default scanner version `1.4.1`.         | REQ-F-002, REQ-NF-004 | Callers should not need to know the current approved version.         |
| `config-repo` omitted                      | The workflow SHALL use the default shared configuration source.     | REQ-F-003, REQ-C-006  | Organization-wide policy should apply by default.                     |
| Explicit scanner version is not acceptable | Tool installation SHALL fail the job.                               | REQ-C-003, REQ-C-004  | Invalid or unsupported versions cannot produce reliable scan results. |
| Configuration source is inaccessible       | Configuration checkout SHALL fail the job.                          | REQ-F-003, REQ-F-005  | A scan without policy configuration is not valid.                     |
| Shared scanner configuration is absent     | Scanner execution SHALL fail fast.                                  | REQ-F-004, REQ-F-005  | Missing configuration is a blocking scan setup error.                 |
| Scanner detects a violation                | Scanner execution SHALL fail fast.                                  | REQ-F-005             | Secret findings are blocking quality gate failures.                   |
| Environment validation reports an error    | All downstream units SHALL be blocked.                              | REQ-F-001             | Invalid execution environments should stop before install or scan.    |
| Caller expects workflow outputs            | No outputs SHALL be produced.                                       | Function Decisions    | The workflow communicates only by job status.                         |
| `fetch-depth` omitted                      | The workflow SHALL use fetch-depth `1`.                             | REQ-F-001b            | Default fetches only the latest commit for efficiency.                |
| `fetch-depth: 0` supplied                  | The workflow SHALL fetch full git history for the target repo.      | REQ-F-001b            | Full history scanning when required by the caller.                    |
| Scanner detects violation (report upload)  | The scan report SHALL be uploaded as artifact `betterleaks-report`. | REQ-F-008             | Preserves evidence for audit when secrets are found.                  |
| Scanner succeeds (no violation)            | No artifact SHALL be uploaded.                                      | REQ-F-008             | Avoids unnecessary artifact storage on clean runs.                    |

## 6. Requirements Traceability

| REQ ID     | Rule IDs                          | Notes                                                                                    |
| ---------- | --------------------------------- | ---------------------------------------------------------------------------------------- |
| REQ-F-001  | R-003, R-004, R-014               | Environment validation runs before install and scan and blocks downstream failure paths. |
| REQ-F-002  | R-001, R-005, R-006               | Scanner installation uses the resolved version and fails the job on installation error.  |
| REQ-F-003  | R-002, R-007, R-008, R-010        | Configuration comes from the configured shared source and is required for scanning.      |
| REQ-F-004  | R-009, R-010, R-011               | Scanner execution uses the shared configuration and fails on execution error.            |
| REQ-F-005  | R-010, R-011                      | Scan setup errors and non-zero scanner exits are fail-fast failures.                     |
| REQ-F-006  | R-013                             | Both reusable and manual invocation expose the same behavioral inputs.                   |
| REQ-NF-001 | R-003, R-005, R-007, R-009        | Each unit is represented by a separate named workflow step.                              |
| REQ-NF-002 | R-012                             | Permissions are limited to read-only repository contents access.                         |
| REQ-NF-003 | R-012                             | No hard-coded tokens are required by the behavioral contract.                            |
| REQ-NF-004 | R-001, R-005                      | Scanner version comes from input resolution.                                             |
| REQ-NF-005 | R-007, R-009, R-010               | Configuration location and source are deterministic.                                     |
| REQ-NF-006 | R-004, R-006, R-008, R-010, R-011 | Failure occurs in the named unit responsible for the failed behavior.                    |
| REQ-C-001  | R-003                             | Runner compatibility is validated before downstream execution.                           |
| REQ-C-002  | R-012                             | Read-only contents permission is required.                                               |
| REQ-C-003  | R-005, R-006                      | Explicit scanner versions must satisfy installer constraints.                            |
| REQ-C-004  | R-001, R-005                      | Default version must remain compatible with supported scanner releases.                  |
| REQ-C-005  | R-003, R-005                      | Local composite actions provide validation and installation behavior.                    |
| REQ-C-006  | R-002, R-007, R-009               | Shared configuration source and default are part of the workflow contract.               |
| REQ-F-001b | R-015, R-016                      | fetch-depth input controls target checkout depth; default 1.                             |
| REQ-F-007  | R-017, R-018                      | Report directory is created before scan; report written to .github/report/.              |
| REQ-F-008  | R-019, R-020, R-021               | Report uploaded as artifact on failure only; exit code exposed as step output.           |

## 7. Open Questions

| #     | Question                                                             | Source             | Impact                |
| ----- | -------------------------------------------------------------------- | ------------------ | --------------------- |
| ~~1~~ | ~~What exact scanner version is the default latest stable version?~~ | Function Decisions | **Resolved: `1.4.1`** |

## 8. Change History

| Date       | Version | Change                                                                                                  |
| ---------- | ------- | ------------------------------------------------------------------------------------------------------- |
| 2026-06-12 | 1.3.0   | Add fetch-depth input (R-015/R-016), report output (R-017/R-018), upload on failure (R-019/R-020/R-021) |
| 2026-06-12 | 1.2.0   | Set default betterleaks version to `1.4.1`                                                              |
| 2026-06-12 | 1.1.0   | Fix config-repo checkout branch to `shared` (not default branch)                                        |
| 2026-06-12 | 1.0.0   | Initial specification                                                                                   |
