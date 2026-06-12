---
title: "Implementation Plan: Betterleaks Reusable Workflow"
based-on: specifications.md v1.1
status: Draft
---

<!-- markdownlint-disable line-length -->

## 1. Overview

### 1.1 Purpose

This implementation plan delivers a reusable GitHub Actions workflow for running Betterleaks scans from caller repositories. The workflow will be added at `.github/workflows/ci-scan-betterleaks.yml` and will support both reusable invocation through `workflow_call` and manual execution through `workflow_dispatch`.

The workflow implements the following behavioral units in sequence:

- `workflow-skeleton`
- `env-validation-step`
- `target-checkout-step` (with fetch-depth and persist-credentials)
- `tool-install-step`
- `config-checkout-step`
- `prepare-report-step`
- `scan-execute-step` (with report output and exit-code capture)
- `upload-report-step` (on failure only)

The workflow will enforce read-only repository access with `contents: read` at both the top-level workflow permissions block and the job-level permissions block.

### 1.2 Reference

- Prior Art / Reference PR: none
- Specifications: specifications.md
- Output workflow file: `.github/workflows/ci-scan-betterleaks.yml`

## 2. Implementation Plan

### Phase 1: Reusable Workflow YAML

#### Commit 1: ci(workflows): add betterleaks reusable workflow

- Create `.github/workflows/ci-scan-betterleaks.yml`.

- Add the reusable workflow skeleton:
  -- Set `name` to a descriptive Betterleaks reusable workflow name.
  -- Add top-level `permissions`.
  -- Set `permissions.contents` to `read`.
  -- Add a single job for the Betterleaks scan.
  -- Add job-level `permissions`.
  -- Set job-level `permissions.contents` to `read`.
  -- Set `runs-on` to `ubuntu-latest`.

- Add triggers under `on`:
  -- Add `workflow_call`.
  -- Add `workflow_dispatch`.
  -- Define matching inputs for both triggers.

- Add input `betterleaks-version`:
  -- Define under `on.workflow_call.inputs` and `on.workflow_dispatch.inputs`.
  -- Set `required: false`.
  -- Set `default: "1.4.1"` (compatible with betterleaks >= v1.0.0 and gitleaks >= v8.25.0).
  -- Reference as `${{ inputs.betterleaks-version }}`.

- Add input `config-repo`:
  -- Define under `on.workflow_call.inputs` and `on.workflow_dispatch.inputs`.
  -- Set `required: false`.
  -- Set `default: aglabo/.github`.
  -- Reference as `${{ inputs.config-repo }}`.

- Add input `fetch-depth`:
  -- Define under `on.workflow_call.inputs` and `on.workflow_dispatch.inputs`.
  -- Set `required: false`.
  -- Set `type: number`.
  -- Set `default: 1` (latest commit only; use 0 for full history).
  -- Reference as `${{ inputs.fetch-depth }}`.

- Add step ID `env-validation` as the first step:
  -- Use the local validate-environment composite action at path `.github/actions/validate-environment`.
  -- Set `with.actions-type: read`.
  -- Do not add an `if` condition to this first step.
  -- Exposes `steps.env-validation.outputs.runner-status`.

- Add step ID `target-checkout` after `env-validation`:
  -- Use `actions/checkout`.
  -- Do not set `path` (checks out caller repository to workspace root).
  -- Set `with.fetch-depth: ${{ inputs.fetch-depth }}`.
  -- Set `with.persist-credentials: false`.
  -- Add `if: steps.env-validation.outcome == 'success'`.

- Add step ID `tool-install` after `target-checkout`:
  -- Use the local setup-tool composite action at path `.github/actions/setup-tool`.
  -- Set `with.repo: betterleaks/betterleaks`.
  -- Set `with.tool-version: ${{ inputs.betterleaks-version }}`.
  -- Add `if: steps.target-checkout.outcome == 'success'`.

- Add step ID `config-checkout` after `tool-install`:
  -- Use `actions/checkout`.
  -- Set `with.repository: ${{ inputs.config-repo }}`.
  -- Set `with.path: shared`.
  -- Do NOT set `with.ref` (check out default branch).
  -- Add `if: steps.tool-install.outcome == 'success'`.

- Add step ID `prepare-report` after `config-checkout`:
  -- Use a shell `run` step: `mkdir -p .github/report`.
  -- Add `if: steps.config-checkout.outcome == 'success'`.

- Add step ID `scan-execute` after `prepare-report`:
  -- Use a shell `run` step with `set +e` / `set -e` pattern to capture exit code.
  -- Run betterleaks with:
  `betterleaks protect --config shared/configs/betterleaks.toml --report-path=.github/report/betterleaks-report.json --exit-code=1 --verbose`
  -- Capture exit code into `$GITHUB_OUTPUT` as `status`.
  -- Re-exit with the captured exit code so the step fails on non-zero.
  -- Add `if: steps.prepare-report.outcome == 'success'`.
  -- Do not add `continue-on-error`.

- Add step ID `upload-report` after `scan-execute`:
  -- Use `actions/upload-artifact`.
  -- Set `if: failure() && steps.scan-execute.outputs.status != '0'`.
  -- Set `with.name: betterleaks-report`.
  -- Set `with.path: .github/report/betterleaks-report.json`.
  -- Set `with.retention-days: 30`.

- Final step order and gating summary:
  -- `env-validation` — no if condition
  -- `target-checkout` — `if: steps.env-validation.outcome == 'success'`
  -- `tool-install` — `if: steps.target-checkout.outcome == 'success'`
  -- `config-checkout` — `if: steps.tool-install.outcome == 'success'`
  -- `prepare-report` — `if: steps.config-checkout.outcome == 'success'`
  -- `scan-execute` — `if: steps.prepare-report.outcome == 'success'`
  -- `upload-report` — `if: failure() && steps.scan-execute.outputs.status != '0'`

- Expected behavior after this commit:
  -- Callable via `workflow_call` or `workflow_dispatch`.
  -- Validates the environment for read-only actions usage.
  -- Checks out the caller repository with configurable fetch-depth (default: 1).
  -- Installs Betterleaks from `betterleaks/betterleaks` using the configured version.
  -- Checks out `${{ inputs.config-repo }}` (default branch) into `shared/`.
  -- Creates `.github/report/` directory before scanning.
  -- Runs Betterleaks with `shared/configs/betterleaks.toml` and writes report to `.github/report/betterleaks-report.json`.
  -- Fails immediately when Betterleaks reports a non-zero exit.
  -- Uploads the report artifact `betterleaks-report` only when scan fails.
  -- Operates with `contents: read` at both top-level and job-level.

## 3. Change History

| Date       | Version | Description                                                                         |
| ---------- | ------- | ----------------------------------------------------------------------------------- |
| 2026-06-12 | 1.2     | Add fetch-depth input, prepare-report step, report output, upload-report on failure |
| 2026-06-12 | 1.1     | Set default betterleaks version to `1.4.1`                                          |
| 2026-06-12 | 1.0     | Initial implementation plan                                                         |
