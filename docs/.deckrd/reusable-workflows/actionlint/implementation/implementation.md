---
title: "Implementation Plan: Actionlint Reusable Workflow"
based-on: specifications.md v1.2.0
version: 1.1.0
status: Draft
---

<!-- cspell:words jactionlint jdx -->
<!-- textlint-disable
  ja-technical-writing/sentence-length -->

## 1. Overview

### 1.1 Purpose

This implementation plan delivers a reusable GitHub Actions workflow for running jactionlint scans from caller repositories.
The workflow will be added at `.github/workflows/ru-qa-actionlint.yml`and will support reusable invocation
through `workflow_call` only.

The workflow implements the following behavioral units in sequence:

- `target-checkout-step` (persist-credentials: false)
- `env-validation-step`
- `tool-install-step`
- `config-checkout-step` (fixed to aglabo/.github, fetch-depth: 1)
- `prepare-report-step`
- `lint-execute-step` (with report output via tee)
- `report-upload-step` (on failure only)

The workflow will enforce read-only repository access with `contents: read`
at both the top-level workflow permissions block and the job-level permissions block.

The caller workflow `ci-workflows-qa.yml` will be updated in Phase 2 to replace
the external `aglabo/.github` actionlint job with a call to the new local reusable workflow.

### 1.2 Reference

- Prior Art/Reference PR: `ci-scan-betterleaks.yml` (same structural pattern)
- Specifications: `specifications.md`
- Output workflow file: `.github/workflows/ru-qa-actionlint.yml`

---

## 2. Implementation Plan

### Phase 1: Reusable Workflow YAML

#### Commit 1: ci(workflows/qa-actionlint): add reusable jactionlint scanning workflow

- Create `.github/workflows/ru-qa-actionlint.yml`.

- Add the reusable workflow skeleton:
  - Set `name` to a descriptive Actionlint reusable workflow name.
  - Add top-level `permissions`.
  - Set `permissions.contents` to `read`.
  - Add a single job `qa-actionlint`.
  - Add job-level `permissions`.
  - Set job-level `permissions.contents` to `read`.
  - Set `runs-on` to `ubuntu-slim`.
  - Set `timeout-minutes` to `10`.

- Add trigger under `on`:
  - Add `workflow_call` only (no `workflow_dispatch`).
  - Define inputs under `on.workflow_call.inputs`.

- Add input `version`:
  - Set `required: false`.
  - Set `type: string`.
  - Set `default: "2.4.0"`.
  - Reference as `${{ inputs.version }}`.

- Add input `config`:
  - Set `required: false`.
  - Set `type: string`.
  - Set `default: "./shared/configs/jactionlint.yaml"`.
  - Reference as `${{ inputs.config }}`.

- Add step ID `target-checkout` as the first step:
  - Use `actions/checkout@9f698171ed81b15d1823a05fc7211befd50c8ae0 # v6.0.3`.
  - Do not set `path` (checks out caller repository to workspace root).
  - Set `with.persist-credentials: false`.
  - Do not add an `if` condition to this first step.

- Add step ID `env-validation` after `target-checkout`:
  - Use the local validate-environment composite action at path `./.github/actions/validate-environment`.
  - Set `with.actions-type: read`.
  - Add `if: steps.target-checkout.outcome == 'success'`.

- Add step ID `tool-install` after `env-validation`:
  - Use the setup-tool composite action `aglabo/ci-platform/.github/actions/ca-setup-tool@v0.4.1`.
  - Set `with.repo: jdx/jactionlint`.
  - Set `with.tool-version: ${{ inputs.version }}`.
  - Add `if: steps.env-validation.outcome == 'success'`.

- Add step ID `config-checkout` after `tool-install`:
  - Use `actions/checkout@9f698171ed81b15d1823a05fc7211befd50c8ae0 # v6.0.3`.
  - Set `with.repository: aglabo/.github` (fixed, not an input).
  - Set `with.path: shared`.
  - Set `with.fetch-depth: 1`.
  - Set `with.persist-credentials: false`.
  - Add `if: steps.tool-install.outcome == 'success'`.

- Add step ID `prepare-report` after `config-checkout`:
  - Use a shell `run` step: `mkdir -p .github/report`.
  - Add `if: steps.config-checkout.outcome == 'success'`.

- Add step ID `lint-execute` after `prepare-report`:
  - Use a shell `run` step with `tee` and `PIPESTATUS` pattern:
    `jactionlint --config-file "${CONFIG_FILE}" 2>&1 | tee .github/report/jactionlint-report.txt; exit "${PIPESTATUS[0]}"`
  - Pass the config path through step `env` as `CONFIG_FILE: ${{ inputs.config }}` (no direct expression in `run`).
  - Add `if: steps.prepare-report.outcome == 'success'`.
  - Do not add `continue-on-error`.

- Add step ID `report-upload` after `lint-execute`:
  - Use `actions/upload-artifact@v7.0.2`.
  - Set `if: failure() && steps.lint-execute.outcome == 'failure'`.
  - Set `with.name: jactionlint-report`.
  - Set `with.path: .github/report/jactionlint-report.txt`.
  - Set `with.retention-days: 30`.

- Final step order and gating summary:

  | Step ID         | if condition                                           |
  | --------------- | ------------------------------------------------------ |
  | target-checkout | (none)                                                 |
  | env-validation  | `steps.target-checkout.outcome == 'success'`           |
  | tool-install    | `steps.env-validation.outcome == 'success'`            |
  | config-checkout | `steps.tool-install.outcome == 'success'`              |
  | prepare-report  | `steps.config-checkout.outcome == 'success'`           |
  | lint-execute    | `steps.prepare-report.outcome == 'success'`            |
  | report-upload   | `failure() && steps.lint-execute.outcome == 'failure'` |

- Expected behavior after this commit:
  - Callable via `workflow_call` only.
  - Checks out the caller repository with `persist-credentials: false`.
  - Validates the environment for read-only actions usage.
  - Installs jactionlint from `jdx/jactionlint` using the configured version (default: `2.4.0`).
  - Checks out `aglabo/.github` (fixed) with `fetch-depth: 1` into `shared/`.
  - Creates `.github/report/` directory before linting.
  - Runs jactionlint with the resolved `config` and
    writes output to `.github/report/jactionlint-report.txt`.
  - Fails immediately when jactionlint reports a non-zero exit.
  - Uploads the artifact `jactionlint-report` only when lint fails.
  - Operates with `contents: read` at both top-level and job-level.
  - Enforces `timeout-minutes: 10` at the job level.

---

### Phase 2: Caller Workflow Update

#### Commit 2: ci(workflows/ci-workflows-qa): replace external actionlint with local reusable workflow

- Edit `.github/workflows/ci-workflows-qa.yml`.

- Update the `actionlint` job:
  - Replace `uses: aglabo/.github/.github/workflows/ci-common-lint-actionlint.yml@<hash> # r1.1.2`
    with `uses: ./.github/workflows/ru-qa-actionlint.yml`.
  - Remove the external commit hash pin (no longer needed for a local reference).
  - Do not add a `with:` block (use all default input values).
  - Retain `permissions: contents: read` at the job level.

- Expected behavior after this commit:
  - The `actionlint` job in `ci-workflows-qa.yml` calls the local reusable workflow.
  - No dependency on `aglabo/.github` for jactionlint linting.
  - All jactionlint behavior is governed by `ru-qa-actionlint.yml`.

---

## 3. Change History

| Date       | Version | Description                                                                                                                                                               |
| ---------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-11-01 | 1.1.0   | Update references for the jactionlint migration (jdx/jactionlint, inputs version / config, ru-qa-actionlint.yml); lint command reads the config path from env CONFIG_FILE |
| 2026-06-12 | 1.0.0   | Initial implementation plan                                                                                                                                               |
