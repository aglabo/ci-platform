---
title: "Implementation Plan: Secretlint Scan Job (Reusable Workflow)"
version: 1.0.1
based-on: specifications.md v1.0.0
status: Draft
---

<!-- textlint-disable
  ja-technical-writing/sentence-length -->
<!-- markdownlint-disable line-length -->

## 1. Overview

### 1.1 Purpose

This plan records how the `scan-secretlint` job of `.github/workflows/ru-scan-secrets.yml` implements the specification. The job is already in place; this document is the decision basis for changes to it.

### 1.2 Reference

- Specifications: specifications.md
- Output workflow file: `.github/workflows/ru-scan-secrets.yml` (job `scan-secretlint`; the `scan-betterleaks` job belongs to `reusable-workflows/betterleaks`)
- Action: `.github/actions/ca-run-secretlint` (module `composite-action/run-secretlint`)
- Caller: `.github/workflows/ci-scan-secrets.yml`

## 2. Implementation Plan

### Phase 1: Job in the Reusable Workflow

#### Commit 1: ci(workflows): add secretlint scan job to ru-scan-secrets

- Inputs (under `on.workflow_call.inputs`, all `required: false`):
  - `secretlint-version`: `type: string`, `default: "14.0.1"`.
  - `pnpm-version`: `type: string`, `default: ""`.
  - `fetch-depth` already exists (`type: number`, `default: 50`) and is shared.

- Job `scan-secretlint`: `name: Secretlint Secret Scan`, `runs-on: ubuntu-slim`, `timeout-minutes: 10`, `permissions.contents: read`. No `needs`.

- Steps:
  - `target-checkout`: `actions/checkout`, `with.fetch-depth: ${{ inputs.fetch-depth }}`, `with.persist-credentials: false`. No `if`.
  - `secretlint-scan`: `aglabo/ci-platform/.github/actions/ca-run-secretlint@v0.8.1`, `with.pnpm-version: ${{ inputs.pnpm-version }}`, `with.secretlint-version: ${{ inputs.secretlint-version }}`, `if: steps.target-checkout.outcome == 'success'`.

- Do not add `continue-on-error`, `ca-validate-environment`, `_ca-resolve-config`, or an upload step.

- Expected behavior after this commit:
  - Runs in parallel with `scan-betterleaks`.
  - Fails on a finding or on an invalid `secretlint-version`.
  - Operates with `contents: read` at both levels.

## 3. Change History

| Date       | Version | Description                                                    |
| ---------- | ------- | -------------------------------------------------------------- |
| 2026-11-20 | 1.0.1   | Update composite action references from @v0.8.0-pre to @v0.8.1 |
| 2026-11-19 | 1.0.0   | Initial implementation plan                                    |
