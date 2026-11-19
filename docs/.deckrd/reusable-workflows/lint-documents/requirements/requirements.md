---
title: "Requirements: Lint Documents Reusable Workflow"
module: "reusable-workflows/lint-documents"
status: Draft
version: 1.0.1
created: "2026-11-19"
---

<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/max-comma,
  ja-technical-writing/no-exclamation-question-mark
  -->
<!-- markdownlint-disable line-length -->

> **Normative Statement**
> This document defines binding requirements.
> Implementations MUST conform to this document.
> RFC 2119 keywords apply to this document only.

## 1. Overview

### 1.1 Purpose

This document defines the requirements for the reusable GitHub Actions workflow `.github/workflows/ru-lint-documents.yml`. The workflow lints the Markdown files that a change touched, using textlint and markdownlint from `aglabo/agla-doc-tools`.

The workflow has three jobs. `get-changed-files` lists the changed files that match the caller's patterns. `qa-textlint` and `qa-markdownlint` run in parallel when at least one file matches. Each lint job installs the tools, resolves its configuration with the `_ca-resolve-config` composite action, runs the linter, and uploads a report when the linter fails.

### 1.2 Scope

- Provide a reusable workflow, invoked through `workflow_call`, that lints changed Markdown files.
- Take the file patterns, commit count, tool version, pnpm version, and both configuration paths as inputs with defaults.
- List changed files with the `ca-get-changed-files` composite action.
- Install `aglabo/agla-doc-tools` with the `ca-setup-repo` composite action.
- Resolve the textlint and markdownlint configurations by precedence (input, local, global).
- Run textlint and markdownlint on the changed files only.
- Upload a text report as an artifact when a linter fails.

**Out of Scope**:

- Implementing or changing textlint, markdownlint, or `agla-doc-tools`.
- Linting files other than the changed files that match `pattern` (for example, the full repository).
- Formatting or auto-fixing documents (dprint, `--fix`).
- Spell checking (cspell) and other document checks.
- Letting callers choose the configuration repository (fixed to `aglabo/global-configs`).
- Publishing workflow outputs.

## 2. Context

- Target Environment: GitHub Actions (`ubuntu-slim` for file listing, `ubuntu-latest` for linting)
- Related Components:
  - `ca-validate-environment`, `ca-get-changed-files`, `ca-setup-repo`, `_ca-resolve-config` composite actions (all `aglabo/ci-platform/.github/actions/...@v0.8.1`)
  - `aglabo/agla-doc-tools` repository (provides `textlint` and `markdownlint`)
  - `aglabo/global-configs` repository (global fallback configuration)
  - Caller: `.github/workflows/ci-docs-qa.yml` (passes `commit-count` and `pnpm-version`)
- Assumptions:
  - The workflow has `contents: read` permission.
  - The caller repository can be checked out in each job.
  - `agla-doc-tools` puts `textlint` and `markdownlint` on `PATH` after `ca-setup-repo` runs.

### System Context Diagram

```text
Caller (ci-docs-qa.yml)
        |  workflow_call
        v
+--------------------------------------+
| get-changed-files (ubuntu-slim)      |
| outputs: files, count                |
+------------------+-------------------+
                   | count != '0'
        +----------+-----------+
        v                      v
+------------------+  +--------------------+
| qa-textlint      |  | qa-markdownlint    |
| (ubuntu-latest)  |  | (ubuntu-latest)    |
+------------------+  +--------------------+
  each: validate env -> setup agla-doc-tools -> checkout global-configs
        -> _ca-resolve-config -> prepare report -> lint -> upload report on failure
```

## 3. Design Decisions (Summary)

| ID    | Decision                                                                                                                 | Linked Record       |
| ----- | ------------------------------------------------------------------------------------------------------------------------ | ------------------- |
| DR-01 | The workflow SHALL lint only the changed files that match `pattern`, listed once by a shared job.                        | decision-records.md |
| DR-02 | textlint and markdownlint SHALL run in two independent jobs.                                                             | decision-records.md |
| DR-03 | Each lint job SHALL resolve its configuration with `_ca-resolve-config` (input, local, global).                          | decision-records.md |
| DR-04 | The documentation tools SHALL come from `aglabo/agla-doc-tools` at a caller-selectable ref installed by `ca-setup-repo`. | decision-records.md |
| DR-05 | The lint jobs SHALL be skipped when no file matches.                                                                     | decision-records.md |

## 4. Functional Requirements

### REQ-F-001: Reusable Trigger and Inputs

- EARS Type: feature-based

```text
GIVEN another workflow needs to lint documents
  WHERE the workflow_call trigger is defined
THEN the workflow MUST be callable as a reusable workflow
     and MUST accept these optional string inputs with defaults:
     pattern ("**/*.md" and "**/*.mdx", one per line),
     commit-count ("1"), doc-tools-version ("v0.3.0"),
     pnpm-version (""), textlint-config (""), markdownlint-config ("").
```

**Rationale**: Defaults let a caller use the workflow with no `with:` block.

### REQ-F-002: Changed File Listing

- EARS Type: event-driven

```text
GIVEN the workflow has started
  WHEN the get-changed-files job runs
THEN it MUST check out the target repository with fetch-depth 0,
     MUST validate the environment (actions-type: read),
     and MUST run ca-get-changed-files with the commit-count and pattern inputs.
```

```text
GIVEN ca-get-changed-files has run
  WHEN the job ends
THEN the job MUST expose the matched file list as the output files
     and the number of matched files as the output count.
```

**Rationale**: A single listing job keeps both linters on the same file set.

### REQ-F-003: Lint Job Gating

- EARS Type: unwanted behavior

```text
GIVEN the get-changed-files output count is '0'
  NOT DO run the qa-textlint or qa-markdownlint jobs
THEN both lint jobs MUST be skipped.
```

```text
GIVEN the get-changed-files output count is not '0'
  WHEN get-changed-files completes
THEN qa-textlint and qa-markdownlint MUST run, and MUST NOT depend on each other.
```

**Rationale**: No linting cost is paid when no document changed, and one linter failing does not hide the other's result.

### REQ-F-004: Tool Setup

- EARS Type: event-driven

```text
GIVEN environment validation succeeded in a lint job
  WHEN the job prepares the tools
THEN it MUST run ca-setup-repo with repo aglabo/agla-doc-tools,
     path ./.tools/agla-doc-tools, ref set to the doc-tools-version input,
     and pnpm-version set to the pnpm-version input.
```

**Rationale**: One tool repository supplies both linters; a pinned ref keeps runs reproducible.

### REQ-F-005: Configuration Resolution

- EARS Type: event-driven

```text
GIVEN the tools are installed
  WHEN a lint job prepares its configuration
THEN it MUST check out aglabo/global-configs into global/configs with fetch-depth 1
     and MUST run _ca-resolve-config.
```

```text
GIVEN qa-textlint resolves its configuration
THEN it MUST pass config=inputs.textlint-config,
     local-config=configs/textlintrc.yaml,
     global-config=global/configs/textlintrc.yaml.
```

```text
GIVEN qa-markdownlint resolves its configuration
THEN it MUST pass config=inputs.markdownlint-config,
     local-config=configs/.markdownlint-cli2.yaml,
     global-config=global/configs/.markdownlint-cli2.yaml.
```

**Rationale**: A repository can override the central policy; the global configuration is the fallback; an explicit input wins.

### REQ-F-006: Run textlint

- EARS Type: event-driven

```text
GIVEN the report directory exists in qa-textlint
  WHEN textlint runs
THEN the job MUST pass the changed files as targets,
     MUST use the resolved configuration file,
     MUST use .textlintignore when it exists and global/configs/.textlintignore otherwise,
     MUST print the textlint version, and MUST tee the output to .github/report/textlint-report.txt.
```

**Rationale**: The ignore-file fallback gives repositories without their own ignore list the central one.

### REQ-F-007: Run markdownlint

- EARS Type: event-driven

```text
GIVEN the report directory exists in qa-markdownlint
  WHEN markdownlint runs
THEN the job MUST pass the changed files as targets,
     MUST use the resolved configuration file,
     and MUST tee the output to .github/report/markdownlint-report.txt.
```

### REQ-F-008: Linter Failure and Report Upload

- EARS Type: unwanted behavior

```text
GIVEN a linter exits with a non-zero status
  NOT DO hide the failure
THEN the lint step and its job MUST fail with the linter's exit status
     (taken from PIPESTATUS, not from tee).
```

```text
GIVEN the lint-execute step failed
  WHEN the job reports
THEN the job MUST upload the report as the artifact textlint-report or markdownlint-report
     with a retention of 30 days.
```

```text
GIVEN the linter succeeded
THEN the job MUST NOT upload any artifact.
```

**Rationale**: The report keeps the evidence of a failure; clean runs store nothing.

### REQ-F-009: Environment Validation

- EARS Type: event-driven

```text
GIVEN a job (get-changed-files, qa-textlint, or qa-markdownlint) has checked out the target repository
  WHEN the job continues
THEN it MUST run ca-validate-environment (actions-type: read) before any other action,
     and MUST stop when validation fails.
```

## 5. Non-Functional Requirements

### REQ-NF-001: Minimum Permissions

The workflow and every job MUST declare `permissions: contents: read` and nothing else.

### REQ-NF-002: Fail-Fast Chain

Each step after the target checkout MUST be gated on the outcome of the previous step (`steps.<id>.outcome == 'success'`), and no operational step MAY use `continue-on-error`.

### REQ-NF-003: Credentials

Every `actions/checkout` MUST set `persist-credentials: false`.

### REQ-NF-004: Observability

Step names and ids MUST identify the failed unit from the Actions log alone.

## 6. Constraints

### REQ-C-001: Runners and Timeouts

`get-changed-files` MUST run on `ubuntu-slim` with a 10-minute timeout. `qa-textlint` and `qa-markdownlint` MUST run on `ubuntu-latest` with a 15-minute timeout.

### REQ-C-002: Repository Actions

The workflow MUST use this repository's composite actions at `@v0.8.1` for validation, file listing, tool setup, and configuration resolution.

### REQ-C-003: Configuration Repository

The global configuration repository MUST be `aglabo/global-configs`, checked out into `global/configs` (not caller-configurable).

### REQ-C-004: No Workflow Outputs

The workflow MUST NOT declare `workflow_call` outputs. The job-level outputs `files` and `count` serve the lint jobs only.

## 7. User Stories

- As a documentation author, I want only the Markdown files I changed to be linted, so that feedback is fast.
- As a repository maintainer, I want to override the textlint and markdownlint configuration locally, so that repository-specific rules apply.
- As a platform engineer, I want both linters to share one file listing and one tool installation source, so that results stay consistent.

## 8. Acceptance Criteria

```gherkin
# AC-001: Changed Markdown Files Are Linted
# Requirement: REQ-F-002, REQ-F-003, REQ-F-006, REQ-F-007
Scenario: Changed Markdown Files Are Linted
  Given a caller invokes the workflow and one Markdown file changed
  When get-changed-files reports count 1
  Then qa-textlint and qa-markdownlint both run on that file
  And the workflow succeeds when both linters exit 0

# AC-002: No Changed Files Skips Linting
# Requirement: REQ-F-003
Scenario: No Changed Files Skips Linting
  Given no changed file matches pattern
  When get-changed-files reports count 0
  Then qa-textlint and qa-markdownlint are skipped

# AC-003: Local Configuration Takes Precedence
# Requirement: REQ-F-005
Scenario: Local Configuration Takes Precedence
  Given textlint-config is empty and configs/textlintrc.yaml exists
  When the configuration is resolved
  Then textlint runs with configs/textlintrc.yaml

# AC-004: Global Configuration Is the Fallback
# Requirement: REQ-F-005
Scenario: Global Configuration Is the Fallback
  Given markdownlint-config is empty and configs/.markdownlint-cli2.yaml does not exist
  When the configuration is resolved
  Then markdownlint runs with global/configs/.markdownlint-cli2.yaml

# AC-005: Linter Failure Uploads the Report
# Requirement: REQ-F-008
Scenario: Linter Failure Uploads the Report
  Given textlint reports a violation
  When the lint-execute step exits non-zero
  Then the job fails
  And the artifact textlint-report is uploaded with 30 days retention

# AC-006: Environment Validation Failure Blocks the Job
# Requirement: REQ-F-009
Scenario: Environment Validation Failure Blocks the Job
  Given ca-validate-environment fails in a lint job
  When the validation step completes
  Then ca-setup-repo and the linter are not executed

# AC-007: Textlint Ignore File Fallback
# Requirement: REQ-F-006
Scenario: Textlint Ignore File Fallback
  Given .textlintignore does not exist in the repository
  When textlint runs
  Then global/configs/.textlintignore is used as the ignore file
```

## 9. Open Questions

| Question                                                                                     | Type      | Impact Area   | Owner         |
| -------------------------------------------------------------------------------------------- | --------- | ------------- | ------------- |
| Should markdownlint also honor a local ignore file, as textlint does with `.textlintignore`? | Technical | Linter parity | Docs Team     |
| Should the lint jobs move to `ubuntu-slim` once `agla-doc-tools` runs on it?                 | Technical | Runner cost   | Platform Team |

## 10. Traceability

| REQ ID     | AC IDs         | Type           |
| ---------- | -------------- | -------------- |
| REQ-F-001  | AC-001         | Functional     |
| REQ-F-002  | AC-001, AC-002 | Functional     |
| REQ-F-003  | AC-001, AC-002 | Functional     |
| REQ-F-004  | AC-001         | Functional     |
| REQ-F-005  | AC-003, AC-004 | Functional     |
| REQ-F-006  | AC-001, AC-007 | Functional     |
| REQ-F-007  | AC-001         | Functional     |
| REQ-F-008  | AC-005         | Functional     |
| REQ-F-009  | AC-006         | Functional     |
| REQ-NF-001 | -              | Non-functional |
| REQ-NF-002 | AC-006         | Non-functional |
| REQ-NF-003 | -              | Non-functional |
| REQ-NF-004 | -              | Non-functional |
| REQ-C-001  | -              | Constraint     |
| REQ-C-002  | -              | Constraint     |
| REQ-C-003  | AC-004         | Constraint     |
| REQ-C-004  | -              | Constraint     |

## 11. Change History

| Date       | Version | Description                                                    |
| ---------- | ------- | -------------------------------------------------------------- |
| 2026-11-20 | 1.0.1   | Update composite action references from @v0.8.0-pre to @v0.8.1 |
| 2026-11-19 | 1.0.0   | Initial release                                                |
