---
title: "Implementation Plan: Actions Lock Reusable Workflow"
version: 1.0.1
based-on: specifications.md v1.0.0
status: Draft
---

<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/max-comma -->
<!-- markdownlint-disable line-length -->

## 1. Overview

### 1.1 Purpose

This plan records how `.github/workflows/ru-qa-actions-lock.yml` implements the specification. The workflow is already in place; this document is the decision basis for changes to it.

### 1.2 Reference

- Specifications: specifications.md
- Output workflow file: `.github/workflows/ru-qa-actions-lock.yml`
- Caller: `.github/workflows/ci-workflows-qa.yml` (job `actions-lock`)

## 2. Implementation Plan

### Phase 1: Reusable Workflow YAML

#### Commit 1: ci(workflows): add actions-lock reusable workflow

- Skeleton:
  - `name: "Reusable: QA by gh actions-lock"`, top-level `permissions.contents: read`, `defaults.run.shell: bash`, trigger `workflow_call`.
  - Header `# @version` follows the repository release (currently `0.7.0`).

- Input `version`: `required: false`, `type: string`, `default: "v0.4.1"`.

- Job `qa-actions-lock`: `runs-on: ubuntu-slim`, `timeout-minutes: 10`, `permissions.contents: read`.

- Steps:
  - `target-checkout`: `actions/checkout`, `persist-credentials: false`. No `if`.
  - `env-validation`: `aglabo/ci-platform/.github/actions/ca-validate-environment@v0.8.1`, `actions-type: read`, `if: steps.target-checkout.outcome == 'success'`.
  - `tool-install`: `if: steps.env-validation.outcome == 'success'`, env `GH_TOKEN: ${{ github.token }}` and `EXT_VERSION: ${{ inputs.version }}`, run `gh extension install github/gh-actions-lock --pin "${EXT_VERSION}"`.
  - `tool-version`: `if: steps.tool-install.outcome == 'success'`, env `GH_TOKEN`, run `gh actions-lock --version`.
  - `prepare-report`: `if: steps.tool-version.outcome == 'success'`, run `mkdir -p .github/report`.
  - `lock-verify`: `if: steps.prepare-report.outcome == 'success'`, env `GH_TOKEN`, run
    `gh actions-lock --verify --no-interactive 2>&1 | tee .github/report/actions-lock-report.txt` then `exit "${PIPESTATUS[0]}"`.
  - `report-upload`: `actions/upload-artifact`, `if: failure() && steps.lock-verify.outcome == 'failure'`, `name: actions-lock-report`, `path: .github/report/actions-lock-report.txt`, `retention-days: 30`.

- Do not add `continue-on-error`, `ca-setup-tool`, or `_ca-resolve-config`.

- Expected behavior after this commit:
  - Callable through `workflow_call` with no `with:` block.
  - Fails when `actions.lock` does not match the workflows, and uploads the report.
  - Operates with `contents: read` at both levels.

## 3. Change History

| Date       | Version | Description                                                    |
| ---------- | ------- | -------------------------------------------------------------- |
| 2026-11-20 | 1.0.1   | Update composite action references from @v0.8.0-pre to @v0.8.1 |
| 2026-11-19 | 1.0.0   | Initial implementation plan                                    |
