---
title: "Design Specification: Lint Documents Reusable Workflow"
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

This specification defines the behavioral design of `ru-lint-documents.yml`: input resolution, changed-file listing, the shared lint-job pipeline, configuration resolution, linter execution, and failure semantics.

<!-- impl-note: Module path: reusable-workflows/lint-documents -->

### 1.2 Scope

It covers behavior from `workflow_call` inputs to the uploaded report. Exact YAML syntax is an implementation detail unless carried in an `impl-note`.

## 2. Design Principles

### 2.1 Classification Philosophy

The workflow is a fail-fast quality gate with one listing job and two independent lint jobs.

| Unit            | Job               | Responsibility                                                      |
| --------------- | ----------------- | ------------------------------------------------------------------- |
| trigger-inputs  | workflow          | Resolve caller inputs and defaults                                  |
| list-files      | get-changed-files | Produce the changed-file list (`files`) and its size (`count`)      |
| env-validation  | all jobs          | Verify the runner and permissions before downstream work            |
| tool-install    | lint jobs         | Install `agla-doc-tools` so the linters are on `PATH`               |
| config-checkout | lint jobs         | Retrieve the global configuration repository                        |
| resolve-config  | lint jobs         | Select one configuration file (input, local, global)                |
| prepare-report  | lint jobs         | Create the report directory                                         |
| lint-execute    | lint jobs         | Run the linter on the changed files and keep its output as a report |
| report-upload   | lint jobs         | Upload the report when `lint-execute` failed                        |

### 2.2 Design Assumptions

| Assumption                  | Description                                                                                |
| --------------------------- | ------------------------------------------------------------------------------------------ |
| Read-only repository access | Every job needs `contents: read` only.                                                     |
| Fixed global configuration  | The global configuration repository is `aglabo/global-configs` and is not an input.        |
| Independent lint jobs       | `qa-textlint` and `qa-markdownlint` share no state except the `get-changed-files` outputs. |
| No published outputs        | The workflow communicates through job status and artifacts only.                           |

### 2.3 External Design Summary

#### Unit Interaction Map

```text
trigger-inputs
      |
      v
get-changed-files: checkout(fetch-depth 0) -> env-validation -> list-files
      | count != '0'
      +--------------------------+
      v                          v
qa-textlint                 qa-markdownlint
 checkout                    checkout
 env-validation              env-validation
 tool-install                tool-install
 config-checkout             config-checkout
 resolve-config              resolve-config
 prepare-report              prepare-report
 lint-execute                lint-execute
 report-upload (on failure)  report-upload (on failure)
```

#### Data Flow

```text
inputs.pattern, inputs.commit-count --> ca-get-changed-files --> files, count
inputs.doc-tools-version, inputs.pnpm-version --> ca-setup-repo (./.tools/agla-doc-tools)
inputs.<tool>-config, configs/<local>, global/configs/<global> --> _ca-resolve-config --> config-file
files + config-file --> linter --> .github/report/<tool>-report.txt --> artifact on failure
```

### 2.4 Non-Goals

| Non-Goal                                   | Reason                                                 |
| ------------------------------------------ | ------------------------------------------------------ |
| Linting the whole repository               | Only changed files matter for review feedback.         |
| Auto-fixing or formatting                  | The workflow reports; it does not modify the checkout. |
| Caller-selectable global config repository | The central policy source is fixed.                    |
| Publishing workflow outputs                | Results are conveyed by job status and artifacts.      |

### 2.5 Behavioral Design Decisions

| ID     | Decision                                                                            | Rationale                                                       | Affected Rules | Status   |
| ------ | ----------------------------------------------------------------------------------- | --------------------------------------------------------------- | -------------- | -------- |
| DD-001 | The file list SHALL be computed once and shared through job outputs.                | Both linters must see the same files.                           | R-003, R-004   | Accepted |
| DD-002 | Lint jobs SHALL be skipped when `count` is `'0'`.                                   | Avoids setup cost with nothing to lint.                         | R-005          | Accepted |
| DD-003 | Each lint job SHALL run its own full pipeline (no shared runner state).             | Jobs run in parallel and fail independently.                    | R-006          | Accepted |
| DD-004 | The linter exit status SHALL come from `PIPESTATUS[0]`.                             | `tee` would otherwise mask the linter failure.                  | R-012          | Accepted |
| DD-005 | The textlint ignore file SHALL fall back from `.textlintignore` to the global copy. | Repositories without their own ignore list use the central one. | R-011          | Accepted |

### 2.6 Related Decision Records

| DR ID | Decision                                        | Specification Impact |
| ----- | ----------------------------------------------- | -------------------- |
| DR-01 | Lint changed files only, listed once            | R-003, R-004         |
| DR-02 | Two independent lint jobs                       | R-005, R-006         |
| DR-03 | Resolve configuration with `_ca-resolve-config` | R-008, R-009         |
| DR-04 | Tools from `agla-doc-tools` at a selectable ref | R-007                |
| DR-05 | Skip lint jobs when nothing matches             | R-005                |

## 3. Behavioral Specification

### 3.1 Input Domain

| Input                 | Required | Default                  | Constraints                               | Behavior                                           |
| --------------------- | -------- | ------------------------ | ----------------------------------------- | -------------------------------------------------- |
| `pattern`             | No       | `**/*.md` and `**/*.mdx` | One glob per line; a leading `!` excludes | Passed to `ca-get-changed-files`                   |
| `commit-count`        | No       | `"1"`                    | Positive integer string                   | Passed to `ca-get-changed-files` (HEAD~N fallback) |
| `doc-tools-version`   | No       | `v0.3.0`                 | A git ref of `aglabo/agla-doc-tools`      | Used as `ref` of `ca-setup-repo`                   |
| `pnpm-version`        | No       | `""`                     | Empty means resolve from `packageManager` | Passed to `ca-setup-repo`                          |
| `textlint-config`     | No       | `""`                     | Repository-relative path when supplied    | Explicit textlint configuration (no fallback)      |
| `markdownlint-config` | No       | `""`                     | Repository-relative path when supplied    | Explicit markdownlint configuration (no fallback)  |

<!-- impl-note: The pattern default is a YAML block scalar, so the value ends with a newline. -->
<!-- impl-note: Caller ci-docs-qa.yml passes commit-count and pnpm-version only. -->

### 3.2 Output Semantics

The workflow publishes no `workflow_call` outputs. The `get-changed-files` job exposes `files` and `count` as job outputs for the lint jobs.

| Result  | Meaning                                                                                    |
| ------- | ------------------------------------------------------------------------------------------ |
| Success | `get-changed-files` succeeded and every executed lint job succeeded (or all were skipped). |
| Failure | A job failed validation, setup, resolution, or a linter exited non-zero.                   |

On a linter failure, the job uploads `textlint-report` or `markdownlint-report` (text file under `.github/report/`, retention 30 days).

### 3.3 Step Execution Semantics

`get-changed-files`: `target-checkout` -> `env-validation` -> `changed-files`.

Lint jobs: `target-checkout` -> `env-validation` -> `tool-install` -> `config-checkout` -> `resolve-config` -> `prepare-report` -> `lint-execute` -> `report-upload`.

Each step after `target-checkout` is gated on the previous step id (`steps.<id>.outcome == 'success'`). `report-upload` runs only when `failure() && steps.lint-execute.outcome == 'failure'`.

<!-- impl-note: get-changed-files uses runs-on ubuntu-slim, timeout 10; lint jobs use ubuntu-latest, timeout 15. -->
<!-- impl-note: lint jobs: needs get-changed-files, if needs.get-changed-files.outputs.count != '0'. -->
<!-- impl-note: tool-install: ca-setup-repo with repo aglabo/agla-doc-tools, path ./.tools/agla-doc-tools, ref inputs.doc-tools-version, pnpm-version inputs.pnpm-version. -->
<!-- impl-note: config-checkout: actions/checkout with repository aglabo/global-configs, path global/configs, fetch-depth 1, persist-credentials false. -->
<!-- impl-note: textlint resolve-config: local configs/textlintrc.yaml, global global/configs/textlintrc.yaml. markdownlint: configs/.markdownlint-cli2.yaml, global/configs/.markdownlint-cli2.yaml. -->
<!-- impl-note: lint-execute env: CONFIG_FILE=steps.resolve-config.outputs.config-file, CHANGED_FILES=needs.get-changed-files.outputs.files; targets are read with mapfile -t from CHANGED_FILES. -->
<!-- impl-note: textlint command: textlint --config "$CONFIG_FILE" --ignore-path "$ignore_file" -- "${targets[@]}" 2>&1 | tee .github/report/textlint-report.txt; exit "${PIPESTATUS[0]}". markdownlint command: markdownlint --config "$CONFIG_FILE" -- "${targets[@]}" 2>&1 | tee .github/report/markdownlint-report.txt; exit "${PIPESTATUS[0]}". -->

## 4. Decision Rules

| Rule ID | Step           | Condition                                     | Outcome                                                                                       |
| ------- | -------------- | --------------------------------------------- | --------------------------------------------------------------------------------------------- |
| R-001   | trigger-inputs | An input is omitted                           | The workflow SHALL use the default in section 3.1.                                            |
| R-002   | env-validation | Validation reports an error in any job        | The job SHALL stop before its next unit.                                                      |
| R-003   | list-files     | The job starts                                | The job SHALL check out with `fetch-depth: 0` so the diff base is reachable.                  |
| R-004   | list-files     | `ca-get-changed-files` completes              | The job SHALL expose `files` and `count`.                                                     |
| R-005   | lint jobs      | `count` equals `'0'`                          | `qa-textlint` and `qa-markdownlint` SHALL be skipped.                                         |
| R-006   | lint jobs      | `count` differs from `'0'`                    | Both lint jobs SHALL run, independently of each other.                                        |
| R-007   | tool-install   | Environment validation succeeded              | The job SHALL install `agla-doc-tools` at `doc-tools-version` into `./.tools/agla-doc-tools`. |
| R-008   | resolve-config | The tool-specific config input is non-empty   | Only that file SHALL be used; a missing file SHALL fail the step (no fallback).               |
| R-009   | resolve-config | The input is empty and the local file exists  | The local file SHALL be used.                                                                 |
| R-010   | resolve-config | The input is empty and no local file exists   | The global file under `global/configs/` SHALL be used; if it is missing the step SHALL fail.  |
| R-011   | lint-execute   | textlint runs and `.textlintignore` is absent | `global/configs/.textlintignore` SHALL be the ignore file.                                    |
| R-012   | lint-execute   | The linter exits non-zero                     | The step and job SHALL fail with the linter's status (from `PIPESTATUS[0]`).                  |
| R-013   | report-upload  | `lint-execute` failed                         | The report SHALL be uploaded as `textlint-report` / `markdownlint-report`, retention 30 days. |
| R-014   | report-upload  | `lint-execute` succeeded                      | No artifact SHALL be uploaded.                                                                |
| R-015   | workflow       | Permissions are evaluated                     | The workflow and each job SHALL request `contents: read` only.                                |
| R-016   | workflow       | A downstream step follows a failed step       | The downstream step SHALL be skipped (outcome gating), except `report-upload`.                |

## 5. Edge Cases

| Input                                  | Behavior                                                        | REQ       | Rationale                                          |
| -------------------------------------- | --------------------------------------------------------------- | --------- | -------------------------------------------------- |
| No file matches `pattern`              | Both lint jobs are skipped; the workflow succeeds.              | REQ-F-003 | Nothing to lint.                                   |
| `textlint-config` names a missing file | `resolve-config` fails; textlint does not run.                  | REQ-F-005 | An explicit choice must not fall back silently.    |
| Only one linter fails                  | That job fails and uploads its report; the other job completes. | REQ-F-003 | Independent results.                               |
| `.textlintignore` absent               | The global ignore file is used.                                 | REQ-F-006 | Central default.                                   |
| `pnpm-version` empty                   | `ca-setup-repo` resolves pnpm from `packageManager`.            | REQ-F-004 | Avoids a pinned version conflicting with the repo. |
| `doc-tools-version` is an unknown ref  | `ca-setup-repo` fails; the linter does not run.                 | REQ-F-004 | Setup failure is blocking.                         |

## 6. Requirements Traceability

| REQ ID     | Rule IDs            | Notes                                           |
| ---------- | ------------------- | ----------------------------------------------- |
| REQ-F-001  | R-001               | Inputs and defaults.                            |
| REQ-F-002  | R-003, R-004        | Listing job and outputs.                        |
| REQ-F-003  | R-005, R-006        | Gating and independence.                        |
| REQ-F-004  | R-007               | Tool setup.                                     |
| REQ-F-005  | R-008, R-009, R-010 | Configuration resolution.                       |
| REQ-F-006  | R-011, R-012        | textlint execution.                             |
| REQ-F-007  | R-012               | markdownlint execution.                         |
| REQ-F-008  | R-012, R-013, R-014 | Failure propagation and report upload.          |
| REQ-F-009  | R-002               | Environment validation in every job.            |
| REQ-NF-001 | R-015               | Minimum permissions.                            |
| REQ-NF-002 | R-016               | Outcome gating.                                 |
| REQ-NF-003 | R-003               | `persist-credentials: false` on every checkout. |
| REQ-NF-004 | R-002, R-012        | Named steps identify the failed unit.           |
| REQ-C-001  | R-003               | Runner and timeout constraints.                 |
| REQ-C-002  | R-002, R-007, R-009 | Repository composite actions at `@v0.8.0-pre`.  |
| REQ-C-003  | R-010               | Fixed global configuration repository.          |
| REQ-C-004  | R-004               | Job outputs only.                               |

## 7. Open Questions

| # | Question                                                     | Source          | Impact        |
| - | ------------------------------------------------------------ | --------------- | ------------- |
| 1 | Should markdownlint get a local/global ignore-file fallback? | requirements §9 | Linter parity |

## 8. Change History

| Date       | Version | Change                |
| ---------- | ------- | --------------------- |
| 2026-11-19 | 1.0.0   | Initial specification |
