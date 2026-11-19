---
title: "Implementation Tasks"
module: "reusable-workflows/secretlint"
status: Active
created: "2026-11-19 00:00:00"
source: specifications.md v1.0.0, implementation.md v1.0.0
---

<!-- textlint-disable
  ja-technical-writing/sentence-length, ja-technical-writing/max-comma
  -->
<!-- markdownlint-disable no-duplicate-heading line-length -->

> This document contains implementation tasks derived from specifications.
> Each task corresponds to a single check on the `scan-secretlint` job of `.github/workflows/ru-scan-secrets.yml`.
> Test method: static YAML analysis via `jactionlint` (CI) and `yq` attribute inspection (local developer verification only; `yq` is NOT used inside the workflow).
> The `yq:` lines are hints for the developer writing the check, not workflow steps.
> The whole workflow is exercised by `.github/workflows/_tests_ru_reusable-workflows.yml`; no job-specific automated test exists, so every task is unchecked.

---

## Task Summary

| Test Target             | Scenario Groups            | Case Count |
| ----------------------- | -------------------------- | ---------: |
| T-01: Inputs and job    | Normal / Error / Edge case |          7 |
| T-02: Step chain        | Normal / Error / Edge case |          5 |
| T-03: Static validation | Normal                     |          2 |
| **Total**               | 7 scenario groups          |     **14** |

---

## T-01: Inputs and Job

### [正常] Normal Cases

#### T-01-01: Inputs and job settings

- [ ] **T-01-01-01**: Verify `secretlint-version` input
  - Target: `on.workflow_call.inputs.secretlint-version`
  - Scenario: Given the workflow is defined
  - Expected: Then `required: false`, `type: string`, `default: "14.0.1"`
  - `yq`: `.on.workflow_call.inputs."secretlint-version".default == "14.0.1"`

- [ ] **T-01-01-02**: Verify `pnpm-version` input
  - Target: `on.workflow_call.inputs.pnpm-version`
  - Scenario: Given the workflow is defined
  - Expected: Then `required: false`, `type: string`, `default: ""`
  - `yq`: `.on.workflow_call.inputs."pnpm-version".default == ""`

- [ ] **T-01-01-03**: Verify the job runner, timeout, and permissions
  - Target: `jobs.scan-secretlint`
  - Scenario: Given the job is defined
  - Expected: Then `runs-on: ubuntu-slim`, `timeout-minutes: 10`, `permissions == {"contents": "read"}`
  - `yq`: `.jobs."scan-secretlint"."runs-on" == "ubuntu-slim" and .jobs."scan-secretlint".permissions == {"contents": "read"}`

### [異常] Error Cases

#### T-01-02: No outputs

- [ ] **T-01-02-01**: Verify no workflow or job outputs are declared
  - Target: `on.workflow_call.outputs`, `jobs.scan-secretlint.outputs`
  - Scenario: Given a caller might expect outputs
  - Expected: Then neither exists
  - `yq`: `(.on.workflow_call.outputs // {}) == {} and (.jobs."scan-secretlint".outputs // {}) == {}`

- [ ] **T-01-02-02**: Verify the job does not depend on `scan-betterleaks`
  - Target: `jobs.scan-secretlint.needs`
  - Scenario: Given `scan-betterleaks` fails
  - Expected: Then `scan-secretlint` has no `needs`, so it still runs
  - `yq`: `(.jobs."scan-secretlint".needs // null) == null and (.jobs."scan-betterleaks".needs // null) == null`

### [エッジケース] Edge Cases

#### T-01-03: Shared workflow file

- [ ] **T-01-03-01**: Verify the workflow holds exactly the two scan jobs
  - Target: `jobs`
  - Scenario: Given the workflow is defined
  - Expected: Then job keys are `scan-betterleaks` and `scan-secretlint`
  - `yq`: `.jobs | keys == ["scan-betterleaks","scan-secretlint"]`

- [ ] **T-01-03-02**: Verify `fetch-depth` is a number with default `50`
  - Target: `on.workflow_call.inputs.fetch-depth`
  - Scenario: Given the input is shared with `scan-betterleaks`
  - Expected: Then `type: number`, `default: 50`
  - `yq`: `.on.workflow_call.inputs."fetch-depth".default == 50 and .on.workflow_call.inputs."fetch-depth".type == "number"`

---

## T-02: Step Chain

### [正常] Normal Cases

#### T-02-01: Steps and wiring

- [ ] **T-02-01-01**: Verify step id order
  - Target: `jobs.scan-secretlint.steps[*].id`
  - Scenario: Given all steps are defined
  - Expected: Then the order is `target-checkout`, `secretlint-scan`
  - `yq`: `[.jobs."scan-secretlint".steps[].id] == ["target-checkout","secretlint-scan"]`

- [ ] **T-02-01-02**: Verify `target-checkout` passes the fetch depth and drops credentials
  - Target: `steps.target-checkout.with`
  - Scenario: Given the repository is checked out
  - Expected: Then `fetch-depth: ${{ inputs.fetch-depth }}`, `persist-credentials: false`, and no `if`
  - `yq`: `(.jobs."scan-secretlint".steps[] | select(.id=="target-checkout")).with."fetch-depth" == "${{ inputs.fetch-depth }}"`

- [ ] **T-02-01-03**: Verify `secretlint-scan` uses the repository action and forwards the inputs
  - Target: `steps.secretlint-scan`
  - Scenario: Given the checkout succeeded
  - Expected: Then `uses` is `aglabo/ci-platform/.github/actions/ca-run-secretlint@v0.8.1`, `with.pnpm-version: ${{ inputs.pnpm-version }}`, `with.secretlint-version: ${{ inputs.secretlint-version }}`
  - `yq`: `(.jobs."scan-secretlint".steps[] | select(.id=="secretlint-scan")).with."secretlint-version" == "${{ inputs.secretlint-version }}"`

### [異常] Error Cases

#### T-02-02: Gating and failure handling

- [ ] **T-02-02-01**: Verify `secretlint-scan` is gated on the checkout
  - Target: `steps.secretlint-scan.if`
  - Scenario: Given the checkout fails
  - Expected: Then `if: steps.target-checkout.outcome == 'success'`
  - `yq`: `(.jobs."scan-secretlint".steps[] | select(.id=="secretlint-scan")).if == "steps.target-checkout.outcome == 'success'"`

### [エッジケース] Edge Cases

#### T-02-03: No suppression and no extras

- [ ] **T-02-03-01**: Verify no `continue-on-error` and no upload step
  - Target: `jobs.scan-secretlint.steps`
  - Scenario: Given secretlint exits non-zero
  - Expected: Then no step has `continue-on-error: true` and no step uses `actions/upload-artifact`
  - `yq`: `[.jobs."scan-secretlint".steps[] | select(."continue-on-error" == true or ((.uses // "") | test("upload-artifact")))] | length == 0`

---

## T-03: Static Validation

### [正常] Normal Cases

#### T-03-01: jactionlint and invariants

- [ ] **T-03-01-01**: `jactionlint` passes with no errors
  - Target: `.github/workflows/ru-scan-secrets.yml`
  - Scenario: Given the workflow YAML exists
  - Expected: Then `jactionlint .github/workflows/ru-scan-secrets.yml` exits 0

- [ ] **T-03-01-02**: Verify the repository action is pinned to `@v0.8.1`
  - Target: `jobs.scan-secretlint.steps[*].uses`
  - Scenario: Given the job uses a repository composite action
  - Expected: Then every `aglabo/ci-platform/` reference ends with `@v0.8.1`
  - `yq`: `[.jobs."scan-secretlint".steps[].uses | select(. != null and test("^aglabo/ci-platform/"))] | all(test("@v0\\.8\\.0-pre$"))`
