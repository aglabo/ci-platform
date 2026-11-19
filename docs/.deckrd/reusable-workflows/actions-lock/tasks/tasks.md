---
title: "Implementation Tasks"
module: "reusable-workflows/actions-lock"
status: Active
created: "2026-11-19 00:00:00"
source: specifications.md v1.0.0, implementation.md v1.0.0
---

<!-- textlint-disable
  ja-technical-writing/sentence-length, ja-technical-writing/max-comma
  -->
<!-- markdownlint-disable no-duplicate-heading line-length -->

> This document contains implementation tasks derived from specifications.
> Each task corresponds to a single check on `.github/workflows/ru-qa-actions-lock.yml`.
> Test method: static YAML analysis via `jactionlint` (CI) and `yq` attribute inspection (local developer verification only; `yq` is NOT used inside the workflow).
> The `yq:` lines are hints for the developer writing the check, not workflow steps.
> No automated test exists yet for this workflow, so every task is unchecked.

---

## Task Summary

| Test Target               | Scenario Groups            | Case Count |
| ------------------------- | -------------------------- | ---------: |
| T-01: Workflow structure  | Normal / Error / Edge case |          6 |
| T-02: Step chain          | Normal / Error / Edge case |          8 |
| T-03: Static validation   | Normal                     |          3 |
| **Total**                 | 7 scenario groups          |     **17** |

---

## T-01: Workflow Structure

### [正常] Normal Cases

#### T-01-01: Inputs, trigger, and permissions

- [ ] **T-01-01-01**: Verify the `version` input is optional with default `v0.4.1`
  - Target: `on.workflow_call.inputs.version`
  - Scenario: Given the workflow is defined
  - Expected: Then `required: false`, `type: string`, `default: "v0.4.1"`
  - `yq`: `.on.workflow_call.inputs.version.default == "v0.4.1" and .on.workflow_call.inputs.version.required == false`

- [ ] **T-01-01-02**: Verify permissions are `contents: read` at both levels
  - Target: `permissions`, `jobs.*.permissions`
  - Scenario: Given permissions are evaluated
  - Expected: Then both equal `{"contents": "read"}`
  - `yq`: `.permissions == {"contents": "read"} and ([.jobs[].permissions] | all(. == {"contents": "read"}))`

- [ ] **T-01-01-03**: Verify the job runner and timeout
  - Target: `jobs.qa-actions-lock`
  - Scenario: Given the job is defined
  - Expected: Then `runs-on: ubuntu-slim` and `timeout-minutes: 10`
  - `yq`: `.jobs."qa-actions-lock"."runs-on" == "ubuntu-slim" and .jobs."qa-actions-lock"."timeout-minutes" == 10`

### [異常] Error Cases

#### T-01-02: No outputs

- [ ] **T-01-02-01**: Verify no workflow or job outputs are declared
  - Target: `on.workflow_call.outputs`, `jobs.*.outputs`
  - Scenario: Given a caller might expect outputs
  - Expected: Then neither exists
  - `yq`: `(.on.workflow_call.outputs // {}) == {} and ([.jobs[].outputs // empty] | length == 0)`

### [エッジケース] Edge Cases

#### T-01-03: Job set and credentials

- [ ] **T-01-03-01**: Verify the workflow has exactly one job
  - Target: `jobs`
  - Scenario: Given the workflow is defined
  - Expected: Then `.jobs | keys == ["qa-actions-lock"]`
  - `yq`: `.jobs | keys == ["qa-actions-lock"]`

- [ ] **T-01-03-02**: Verify `target-checkout` sets `persist-credentials: false`
  - Target: `steps.target-checkout.with`
  - Scenario: Given the repository is checked out
  - Expected: Then `with.persist-credentials: false`
  - `yq`: `(.jobs."qa-actions-lock".steps[] | select(.id=="target-checkout")).with."persist-credentials" == false`

---

## T-02: Step Chain

### [正常] Normal Cases

#### T-02-01: Step ids, actions, and gates

- [ ] **T-02-01-01**: Verify step id order
  - Target: `jobs.qa-actions-lock.steps[*].id`
  - Scenario: Given all steps are defined
  - Expected: Then the order is `target-checkout`, `env-validation`, `tool-install`, `tool-version`, `prepare-report`, `lock-verify`, `report-upload`
  - `yq`: `[.jobs."qa-actions-lock".steps[].id] == ["target-checkout","env-validation","tool-install","tool-version","prepare-report","lock-verify","report-upload"]`

- [ ] **T-02-01-02**: Verify `env-validation` uses the repository action with `actions-type: read`
  - Target: `steps.env-validation`
  - Scenario: Given the checkout completed
  - Expected: Then `uses` is `aglabo/ci-platform/.github/actions/ca-validate-environment@v0.8.0-pre`, `with.actions-type: read`, `if: steps.target-checkout.outcome == 'success'`
  - `yq`: `(.jobs."qa-actions-lock".steps[] | select(.id=="env-validation")).with."actions-type" == "read"`

- [ ] **T-02-01-03**: Verify `tool-install` pins the extension
  - Target: `steps.tool-install`
  - Scenario: Given validation succeeded
  - Expected: Then `env.EXT_VERSION == ${{ inputs.version }}`, `env.GH_TOKEN == ${{ github.token }}`, and `run` is `gh extension install github/gh-actions-lock --pin "${EXT_VERSION}"`
  - `yq`: `(.jobs."qa-actions-lock".steps[] | select(.id=="tool-install")).env.EXT_VERSION == "${{ inputs.version }}"`

- [ ] **T-02-01-04**: Verify `lock-verify` command and status propagation
  - Target: `steps.lock-verify.run`
  - Scenario: Given the report directory exists
  - Expected: Then `run` contains `gh actions-lock --verify --no-interactive`, `tee .github/report/actions-lock-report.txt`, and `exit "${PIPESTATUS[0]}"`
  - `yq`: `(.jobs."qa-actions-lock".steps[] | select(.id=="lock-verify")).run | test("PIPESTATUS\\[0\\]")`

### [異常] Error Cases

#### T-02-02: Failure handling

- [ ] **T-02-02-01**: Verify `report-upload` runs only after a `lock-verify` failure
  - Target: `steps.report-upload`
  - Scenario: Given verification failed
  - Expected: Then `if: failure() && steps.lock-verify.outcome == 'failure'`, `name: actions-lock-report`, `path: .github/report/actions-lock-report.txt`, `retention-days: 30`
  - `yq`: `(.jobs."qa-actions-lock".steps[] | select(.id=="report-upload")).if == "failure() && steps.lock-verify.outcome == 'failure'"`

- [ ] **T-02-02-02**: Verify no step uses `continue-on-error: true`
  - Target: `steps.*.continue-on-error`
  - Scenario: Given any step could continue on error
  - Expected: Then none do
  - `yq`: `[.jobs[].steps[] | select(."continue-on-error" == true)] | length == 0`

### [エッジケース] Edge Cases

#### T-02-03: Gating and token scope

- [ ] **T-02-03-01**: Verify each step after the checkout gates on the previous step id
  - Target: `steps.*.if`
  - Scenario: Given any upstream step fails
  - Expected: Then `env-validation`, `tool-install`, `tool-version`, `prepare-report`, `lock-verify` each gate on the previous step's `outcome == 'success'`
  - `yq`: `(.jobs."qa-actions-lock".steps[] | select(.id=="prepare-report")).if == "steps.tool-version.outcome == 'success'"`

- [ ] **T-02-03-02**: Verify `GH_TOKEN` is set only on the three steps that call `gh`
  - Target: `steps.*.env.GH_TOKEN`
  - Scenario: Given token exposure should be minimal
  - Expected: Then only `tool-install`, `tool-version`, `lock-verify` set `GH_TOKEN`
  - `yq`: `[.jobs."qa-actions-lock".steps[] | select(.env.GH_TOKEN != null) | .id] == ["tool-install","tool-version","lock-verify"]`

---

## T-03: Static Validation

### [正常] Normal Cases

#### T-03-01: jactionlint and invariants

- [ ] **T-03-01-01**: `jactionlint` passes with no errors
  - Target: `.github/workflows/ru-qa-actions-lock.yml`
  - Scenario: Given the workflow YAML exists
  - Expected: Then `jactionlint .github/workflows/ru-qa-actions-lock.yml` exits 0

- [ ] **T-03-01-02**: Verify step ids are unique
  - Target: `jobs.*.steps[*].id`
  - Scenario: Given all steps are declared
  - Expected: Then the id list has no duplicates
  - `yq`: `[.jobs[].steps[].id] | (unique | length) == length`

- [ ] **T-03-01-03**: Verify the repository action is pinned to `@v0.8.0-pre`
  - Target: `jobs.*.steps[*].uses`
  - Scenario: Given the workflow uses a repository composite action
  - Expected: Then every `aglabo/ci-platform/` reference ends with `@v0.8.0-pre`
  - `yq`: `[.jobs[].steps[].uses | select(. != null and test("^aglabo/ci-platform/"))] | all(test("@v0\\.8\\.0-pre$"))`
