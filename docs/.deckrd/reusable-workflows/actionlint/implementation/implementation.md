---
title: "Implementation Plan: Actionlint Reusable Workflow"
based-on: specifications.md v1.0.0
status: Draft
---

<!-- markdownlint-disable line-length -->

## 1. Overview

### 1.1 Purpose

This implementation plan delivers a reusable GitHub Actions workflow for running actionlint scans from caller repositories. The workflow will be added at `.github/workflows/ci-qa-actionlint.yml` and will support reusable invocation through `workflow_call` only.

The workflow implements the following behavioral units in sequence:

- `target-checkout-step` (persist-credentials: false)
- `env-validation-step`
- `tool-install-step`
- `config-checkout-step` (fixed to aglabo/.github, fetch-depth: 1)
- `prepare-report-step`
- `lint-execute-step` (with report output via tee)
- `report-upload-step` (on failure only)

The workflow will enforce read-only repository access with `contents: read` at both the top-level workflow permissions block and the job-level permissions block.

The caller workflow `ci-workflows-qa.yml` will be updated in Phase 2 to replace the external `aglabo/.github` actionlint job with a call to the new local reusable workflow.

### 1.2 Reference

- Prior Art / Reference PR: `ci-scan-betterleaks.yml` (same structural pattern)
- Specifications: `specifications.md`
- Output workflow file: `.github/workflows/ci-qa-actionlint.yml`

---

## 2. Implementation Plan

### Phase 1: Reusable Workflow YAML

#### Commit 1: ci(workflows/qa-actionlint): add reusable actionlint scanning workflow

- Create `.github/workflows/ci-qa-actionlint.yml`.

- Add the reusable workflow skeleton:
  -- Set `name` to a descriptive Actionlint reusable workflow name.
  -- Add top-level `permissions`.
  -- Set `permissions.contents` to `read`.
  -- Add a single job `qa-actionlint`.
  -- Add job-level `permissions`.
  -- Set job-level `permissions.contents` to `read`.
  -- Set `runs-on` to `ubuntu-slim`.
  -- Set `timeout-minutes` to `10`.

- Add trigger under `on`:
  -- Add `workflow_call` only (no `workflow_dispatch`).
  -- Define inputs under `on.workflow_call.inputs`.

- Add input `actionlint-version`:
  -- Set `required: false`.
  -- Set `type: string`.
  -- Set `default: "1.7.12"`.
  -- Reference as `${{ inputs.actionlint-version }}`.

- Add input `config-file`:
  -- Set `required: false`.
  -- Set `type: string`.
  -- Set `default: "./shared/configs/actionlint.yaml"`.
  -- Reference as `${{ inputs.config-file }}`.

- Add step ID `target-checkout` as the first step:
  -- Use `actions/checkout@9f698171ed81b15d1823a05fc7211befd50c8ae0 # v6.0.3`.
  -- Do not set `path` (checks out caller repository to workspace root).
  -- Set `with.persist-credentials: false`.
  -- Do not add an `if` condition to this first step.

- Add step ID `env-validation` after `target-checkout`:
  -- Use the local validate-environment composite action at path `./.github/actions/validate-environment`.
  -- Set `with.actions-type: read`.
  -- Add `if: steps.target-checkout.outcome == 'success'`.

- Add step ID `tool-install` after `env-validation`:
  -- Use the local setup-tool composite action at path `./.github/actions/setup-tool`.
  -- Set `with.repo: rhysd/actionlint`.
  -- Set `with.tool-version: ${{ inputs.actionlint-version }}`.
  -- Add `if: steps.env-validation.outcome == 'success'`.

- Add step ID `config-checkout` after `tool-install`:
  -- Use `actions/checkout@9f698171ed81b15d1823a05fc7211befd50c8ae0 # v6.0.3`.
  -- Set `with.repository: aglabo/.github` (fixed, not an input).
  -- Set `with.path: shared`.
  -- Set `with.fetch-depth: 1`.
  -- Set `with.persist-credentials: false`.
  -- Add `if: steps.tool-install.outcome == 'success'`.

- Add step ID `prepare-report` after `config-checkout`:
  -- Use a shell `run` step: `mkdir -p .github/report`.
  -- Add `if: steps.config-checkout.outcome == 'success'`.

- Add step ID `lint-execute` after `prepare-report`:
  -- Use a shell `run` step with `tee` and `PIPESTATUS` pattern:
  `actionlint -config-file ${{ inputs.config-file }} 2>&1 | tee .github/report/actionlint-report.txt; exit ${PIPESTATUS[0]}`
  -- Add `if: steps.prepare-report.outcome == 'success'`.
  -- Do not add `continue-on-error`.

- Add step ID `report-upload` after `lint-execute`:
  -- Use `actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1`.
  -- Set `if: failure() && steps.lint-execute.outcome == 'failure'`.
  -- Set `with.name: actionlint-report`.
  -- Set `with.path: .github/report/actionlint-report.txt`.
  -- Set `with.retention-days: 30`.

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
  -- Callable via `workflow_call` only.
  -- Checks out the caller repository with `persist-credentials: false`.
  -- Validates the environment for read-only actions usage.
  -- Installs actionlint from `rhysd/actionlint` using the configured version (default: `1.7.12`).
  -- Checks out `aglabo/.github` (fixed) with `fetch-depth: 1` into `shared/`.
  -- Creates `.github/report/` directory before linting.
  -- Runs actionlint with the resolved `config-file` and writes output to `.github/report/actionlint-report.txt`.
  -- Fails immediately when actionlint reports a non-zero exit.
  -- Uploads the artifact `actionlint-report` only when lint fails.
  -- Operates with `contents: read` at both top-level and job-level.
  -- Enforces `timeout-minutes: 10` at the job level.

---

### Phase 2: Caller Workflow Update

#### Commit 2: ci(workflows/ci-workflows-qa): replace external actionlint with local reusable workflow

- Edit `.github/workflows/ci-workflows-qa.yml`.

- Update the `actionlint` job:
  -- Replace `uses: aglabo/.github/.github/workflows/ci-common-lint-actionlint.yml@38070c03acff350b4c8f46d684781052b70c0e58 # r1.1.2`
  with `uses: ./.github/workflows/ci-qa-actionlint.yml`.
  -- Remove the external commit hash pin (no longer needed for a local reference).
  -- Do not add a `with:` block (use all default input values).
  -- Retain `permissions: contents: read` at the job level.

- Expected behavior after this commit:
  -- The `actionlint` job in `ci-workflows-qa.yml` calls the local reusable workflow.
  -- No dependency on `aglabo/.github` for actionlint linting.
  -- All actionlint behavior is governed by `ci-qa-actionlint.yml`.

---

## 3. Change History

| Date       | Version | Description                 |
| ---------- | ------- | --------------------------- |
| 2026-06-12 | 1.0     | Initial implementation plan |
