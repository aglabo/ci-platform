---
title: "Implementation Tasks"
module: "reusable-workflows/betterleaks"
status: Active
created: "2026-06-12 00:00:00"
source: specifications.md v2.0.0
---

<!-- textlint-disable
  ja-technical-writing/sentence-length, ja-technical-writing/max-comma
  -->
<!-- markdownlint-disable no-duplicate-heading line-length -->

> This document contains implementation tasks derived from specifications.
> Each task corresponds to a single unit test case (it() block).
> Scope: the `scan-betterleaks` job of `ru-scan-secrets.yml` (the `scan-secretlint` job is covered by `reusable-workflows/secretlint`).
> Test method: static YAML analysis via `jactionlint` (CI) and `yq` attribute inspection (local developer verification only — `yq` is NOT used inside the reusable workflow itself).
> The `yq:` lines in each task are implementation hints for the developer writing the test, not workflow steps.

---

## Task Summary

| Test Target                  | Scenario Groups            | Case Count |
| ---------------------------- | -------------------------- | ---------: |
| T-01: Workflow structure     | Normal / Error / Edge case |          9 |
| T-02: Step chain             | Normal / Error / Edge case |          9 |
| T-03: Failure propagation    | Error / Edge case          |          6 |
| T-04: YAML static validation | Normal                     |          4 |
| T-05: Fetch depth and report | Normal / Error / Edge case |          9 |
| T-06: Config resolution      | Normal / Error / Edge case |          6 |
| **Total**                    | 18 scenario groups         |     **43** |

---

## T-01: Workflow Structure

### [正常] Normal Cases

#### T-01-01: Inputs and triggers are correctly defined

- [x] **T-01-01-01**: Verify `version` input for `workflow_call` has correct default and is optional
  - Target: `on.workflow_call.inputs.version`
  - Scenario: Given the reusable workflow is defined, When `workflow_call` inputs are inspected
  - Expected: Then `required: false` and `default: "1.10.0"`
  - `yq`: `.on.workflow_call.inputs.version.required == false and .on.workflow_call.inputs.version.default == "1.10.0"`

- [x] **T-01-01-02**: Verify `config-repo` input for `workflow_call` defaults to `aglabo/global-configs`
  - Target: `on.workflow_call.inputs.config-repo`
  - Scenario: Given the reusable workflow is defined, When `workflow_call` inputs are inspected
  - Expected: Then `required: false` and `default: aglabo/global-configs`
  - `yq`: `.on.workflow_call.inputs."config-repo".required == false and .on.workflow_call.inputs."config-repo".default == "aglabo/global-configs"`

- [x] **T-01-01-02b**: Verify `fetch-depth` input for `workflow_call` defaults to `50` and is optional
  - Target: `on.workflow_call.inputs.fetch-depth`
  - Scenario: Given the reusable workflow is defined, When `workflow_call` inputs are inspected
  - Expected: Then `required: false`, `default: 50`, `type: number`
  - `yq`: `.on.workflow_call.inputs."fetch-depth".required == false and .on.workflow_call.inputs."fetch-depth".default == 50`

- [x] **T-01-01-03**: Verify `config` input for `workflow_call` defaults to an empty string
  - Target: `on.workflow_call.inputs.config`
  - Scenario: Given the reusable workflow is defined, When `workflow_call` inputs are inspected
  - Expected: Then `required: false`, `type: string`, `default: ""`
  - `yq`: `.on.workflow_call.inputs.config.required == false and .on.workflow_call.inputs.config.default == ""`

- [x] **T-01-01-04**: Verify `version` and `config-repo` inputs declare `type: string` for `workflow_call`
  - Target: `on.workflow_call.inputs`
  - Scenario: Given inputs are defined for `workflow_call`
  - Expected: Then `version` and `config-repo` have `type: string` under `workflow_call`
  - `yq`: `.on.workflow_call.inputs.version.type == "string" and .on.workflow_call.inputs."config-repo".type == "string"`

- [x] **T-01-01-05**: Verify top-level permissions grant only `contents: read`
  - Target: `permissions.contents`
  - Scenario: Given workflow permissions are evaluated, When the top-level permissions block is inspected
  - Expected: Then `permissions.contents` is `read` and no other permissions keys exist at top level
  - `yq`: `.permissions == {"contents": "read"}`

- [x] **T-01-01-06**: Verify job-level permissions grant only `contents: read`
  - Target: `jobs.*.permissions.contents`
  - Scenario: Given job permissions are evaluated
  - Expected: Then each job declares `permissions.contents: read` with no additional keys
  - `yq`: `[.jobs."scan-betterleaks".permissions] | all(. == {"contents": "read"})`

### [異常] Error Cases

#### T-01-02: Workflow does not expose outputs

- [x] **T-01-02-01**: Verify no `workflow_call` outputs are declared
  - Target: `on.workflow_call.outputs`
  - Scenario: Given a caller might expect outputs
  - Expected: Then `on.workflow_call.outputs` is absent or empty
  - `yq`: `(.on.workflow_call.outputs // {}) == {}`

- [x] **T-01-02-02**: Verify no job-level outputs are declared
  - Target: `jobs.*.outputs`
  - Scenario: Given jobs might declare outputs
  - Expected: Then no job has an `outputs` block
  - `yq`: `[.jobs."scan-betterleaks".outputs // empty] | length == 0`

### [エッジケース] Edge Cases

#### T-01-03: Input defaults are explicitly declared

- [x] **T-01-03-01**: Verify `version` and `config-repo` have non-empty defaults under `workflow_call`
  - Target: `on.workflow_call.inputs`
  - Scenario: Given no value is supplied by a caller
  - Expected: Then `version` default is `"1.10.0"` and `config-repo` default is `"aglabo/global-configs"` under `workflow_call` (the workflow defines no `workflow_dispatch` trigger)
  - `yq`: `.on.workflow_call.inputs.version.default == "1.10.0" and .on.workflow_call.inputs."config-repo".default == "aglabo/global-configs"`

---

## T-02: Step Chain

### [正常] Normal Cases

#### T-02-01: Each step exists with the correct ID, action reference, and gate condition

- [x] **T-02-01-01**: Verify `target-checkout` runs first with no gate condition
  - Target: `steps` (index 0)
  - Scenario: Given the workflow starts, When the first step is evaluated
  - Expected: Then the first step has `id: target-checkout`, uses `actions/checkout`, has no `if` condition, has no `with.repository` and no `with.path`
  - `yq`: `(.jobs."scan-betterleaks".steps[0].uses | test("actions/checkout")) and (.jobs."scan-betterleaks".steps[0].if // null) == null`

- [x] **T-02-01-01b**: Verify `target-checkout` passes `fetch-depth` and `persist-credentials: false`
  - Target: `steps` (index 0) `.with`
  - Scenario: Given the workflow starts, When the first step is inspected
  - Expected: Then `with.fetch-depth: ${{ inputs.fetch-depth }}` and `with.persist-credentials: false`
  - `yq`: `.jobs."scan-betterleaks".steps[0].with."fetch-depth" == "${{ inputs.fetch-depth }}" and .jobs."scan-betterleaks".steps[0].with."persist-credentials" == false`

- [x] **T-02-01-02**: Verify `env-validation` step runs second and is gated on `target-checkout`
  - Target: `steps.env-validation`
  - Scenario: Given `target-checkout` completed, When the second step is evaluated
  - Expected: Then step with `id: env-validation` uses `aglabo/ci-platform/.github/actions/ca-validate-environment@v0.8.1`, sets `with.actions-type: read`, has `if: steps.target-checkout.outcome == 'success'`, and appears at index 1 in the step list
  - `yq`: `.jobs."scan-betterleaks".steps[1].id == "env-validation"` and `.jobs."scan-betterleaks".steps[1].if == "steps.target-checkout.outcome == 'success'"`

- [x] **T-02-01-03**: Verify `tool-install` uses the `ca-setup-tool` action with correct inputs and gate
  - Target: `steps.tool-install`
  - Scenario: Given `env-validation` completed
  - Expected: Then step `tool-install` uses `aglabo/ci-platform/.github/actions/ca-setup-tool@v0.8.1`, sets `with.repo: betterleaks/betterleaks`, `with.tool-version: ${{ inputs.version }}`, and has `if: steps.env-validation.outcome == 'success'`
  - `yq`: `(.jobs."scan-betterleaks".steps[] | select(.id=="tool-install")).with.repo == "betterleaks/betterleaks" and (.jobs."scan-betterleaks".steps[] | select(.id=="tool-install")).if == "steps.env-validation.outcome == 'success'"`

- [x] **T-02-01-04**: Verify `config-checkout` checks out `config-repo` (default branch) into `global/configs/`
  - Target: `steps.config-checkout`
  - Scenario: Given `tool-install` completed
  - Expected: Then step `config-checkout` uses `actions/checkout`, sets `with.repository: ${{ inputs.config-repo }}`, `with.path: global/configs`, does NOT set `with.ref`, and has `if: steps.tool-install.outcome == 'success'`
  - `yq`: `(.jobs."scan-betterleaks".steps[] | select(.id=="config-checkout")).with.path == "global/configs" and (.jobs."scan-betterleaks".steps[] | select(.id=="config-checkout")).with.repository == "${{ inputs.config-repo }}" and ((.jobs."scan-betterleaks".steps[] | select(.id=="config-checkout")).with.ref // null) == null`

- [x] **T-02-01-05**: Verify `scan-execute` runs the correct betterleaks command and is gated on `prepare-report`
  - Target: `steps.scan-execute`
  - Scenario: Given `prepare-report` completed
  - Expected: Then step `scan-execute` has `if: steps.prepare-report.outcome == 'success'`, `env.CONFIG_FILE: ${{ steps.resolve-config.outputs.config-file }}`, and its `run` field contains `betterleaks git .` and `--config "${CONFIG_FILE}"`
  - `yq`: `(.jobs."scan-betterleaks".steps[] | select(.id=="scan-execute")).env.CONFIG_FILE == "${{ steps.resolve-config.outputs.config-file }}" and (.jobs."scan-betterleaks".steps[] | select(.id=="scan-execute")).run | test("--config \"\\$\\{CONFIG_FILE\\}\"")`

- [x] **T-02-01-06**: Verify step execution order is target-checkout → env-validation → tool-install → config-checkout → resolve-config → prepare-report → scan-execute
  - Target: `jobs.*.steps[*]`
  - Scenario: Given all steps are defined
  - Expected: Then the steps appear in the declared order: checkout first, then env-validation, then tool-install, config-checkout, resolve-config, prepare-report, scan-execute
  - `yq`: `[.jobs."scan-betterleaks".steps[].id] | (index("env-validation") < index("tool-install")) and (index("tool-install") < index("config-checkout")) and (index("config-checkout") < index("resolve-config")) and (index("resolve-config") < index("prepare-report")) and (index("prepare-report") < index("scan-execute"))`

### [異常] Error Cases

#### T-02-02: Scan step does not suppress failures

- [x] **T-02-02-01**: Verify `scan-execute` has no `continue-on-error: true`
  - Target: `steps.scan-execute.continue-on-error`
  - Scenario: Given the scanner exits with a non-zero code
  - Expected: Then `continue-on-error` is absent or `false` in `scan-execute`
  - `yq`: `((.jobs."scan-betterleaks".steps[] | select(.id=="scan-execute"))."continue-on-error" // false) == false`

### [エッジケース] Edge Cases

#### T-02-03: If-conditions use only immediate-upstream outcome gates

- [x] **T-02-03-01**: Verify each downstream step gates only on the immediate preceding step's outcome
  - Target: `steps.*.if`
  - Scenario: Given any upstream unit fails
  - Expected: Then `env-validation`, `tool-install`, `config-checkout`, `resolve-config`, `prepare-report`, `scan-execute` each have exactly one `if` expression referencing only the preceding step outcome, with no `always()`, `failure()`, `cancelled()`, or `||` logic
  - `yq`: `(.jobs."scan-betterleaks".steps[] | select(.id=="tool-install")).if == "steps.env-validation.outcome == 'success'"` (repeat for each step); none contain `always(`, `failure(`, `cancelled(`

- [x] **T-02-03-02**: Verify no operational step has `continue-on-error: true`
  - Target: `steps.tool-install`, `steps.config-checkout`, `steps.resolve-config`, `steps.prepare-report`, `steps.scan-execute`
  - Scenario: Given any step could be marked to continue on error
  - Expected: Then none of the operational steps declare `continue-on-error: true`
  - `yq`: `[.jobs."scan-betterleaks".steps[] | select(.id == "tool-install" or .id == "config-checkout" or .id == "resolve-config" or .id == "prepare-report" or .id == "scan-execute") | select(."continue-on-error" == true)] | length == 0`

---

## T-03: Failure Propagation

### [異常] Error Cases

#### T-03-01: Upstream failures block all downstream steps via chained gates

- [x] **T-03-01-01**: Verify all downstream `if` expressions form a complete failure-propagation chain
  - Target: `steps.tool-install.if`, `steps.config-checkout.if`, `steps.resolve-config.if`, `steps.prepare-report.if`, `steps.scan-execute.if`
  - Scenario: Given any upstream step fails, When each downstream step is evaluated
  - Expected: Then each downstream step's `if` references only the immediately preceding step's outcome, so failure cascades without any `always()` or `continue-on-error` bypass
  - `yq`: all `if` values match their respective predecessor patterns (exact string match)

- [x] **T-03-01-02**: Verify `config-checkout` has no `continue-on-error` so an inaccessible config-repo fails the job
  - Target: `steps.config-checkout.continue-on-error`
  - Scenario: Given `config-repo` is inaccessible
  - Expected: Then `continue-on-error` is absent or `false` in `config-checkout`
  - `yq`: `((.jobs."scan-betterleaks".steps[] | select(.id=="config-checkout"))."continue-on-error" // false) == false`

- [x] **T-03-01-03**: Verify `scan-execute` takes its config from `resolve-config` so an unresolved config blocks the scan
  - Target: `steps.scan-execute.env`, `steps.scan-execute.if`
  - Scenario: Given no candidate configuration file exists, When `resolve-config` fails
  - Expected: Then `scan-execute` is gated (through `prepare-report`) on `resolve-config` and reads `CONFIG_FILE` from `steps.resolve-config.outputs.config-file`, so the scan does not run
  - `yq`: `(.jobs."scan-betterleaks".steps[] | select(.id=="prepare-report")).if == "steps.resolve-config.outcome == 'success'"`

### [エッジケース] Edge Cases

#### T-03-02: Edge inputs and output suppression

- [x] **T-03-02-01**: Verify `version` default is non-empty (stable version is declared)
  - Target: `on.workflow_call.inputs.version.default`
  - Scenario: Given `version` is omitted by the caller
  - Expected: Then `default == "1.10.0"`
  - `yq`: `.on.workflow_call.inputs.version.default == "1.10.0"`

- [x] **T-03-02-02**: Verify `config-repo` default is exactly `aglabo/global-configs`
  - Target: `on.workflow_call.inputs.config-repo.default`
  - Scenario: Given `config-repo` is omitted by the caller
  - Expected: Then `default == "aglabo/global-configs"`
  - `yq`: `.on.workflow_call.inputs."config-repo".default == "aglabo/global-configs"`

- [x] **T-03-02-03**: Verify no outputs exist at workflow or job level (fail-fast only, no status outputs)
  - Target: `on.workflow_call.outputs`, `jobs.*.outputs`
  - Scenario: Given a caller expects output values from the workflow
  - Expected: Then neither the workflow nor any job declares outputs
  - `yq`: `(.on.workflow_call.outputs // {}) == {} and ([.jobs."scan-betterleaks".outputs // empty] | length == 0)`

---

## T-04: YAML Static Validation

### [正常] Normal Cases

#### T-04-01: jactionlint and structural invariants

- [x] **T-04-01-01**: `jactionlint` passes with no errors
  - Target: `.github/workflows/ru-scan-secrets.yml`
  - Scenario: Given the workflow YAML is created
  - Expected: Then `jactionlint .github/workflows/ru-scan-secrets.yml` exits 0 with no error output

- [x] **T-04-01-02**: Verify the `scan-betterleaks` job contains all required step IDs
  - Target: `jobs`, `jobs.*.steps[*].id`
  - Scenario: Given the workflow is defined
  - Expected: Then `.jobs` has the two jobs `scan-betterleaks` and `scan-secretlint`, and the `scan-betterleaks` job's steps include all of: `target-checkout`, `env-validation`, `tool-install`, `config-checkout`, `resolve-config`, `prepare-report`, `scan-execute`, `upload-report`
  - `yq`: `[.jobs."scan-betterleaks".steps[].id] | contains(["target-checkout","env-validation","tool-install","config-checkout","resolve-config","prepare-report","scan-execute","upload-report"])`

- [x] **T-04-01-03**: Verify all step IDs are unique
  - Target: `jobs.*.steps[*].id`
  - Scenario: Given all steps are declared
  - Expected: Then the list of step IDs has no duplicates
  - `yq`: `[.jobs."scan-betterleaks".steps[].id] | (unique | length) == length`

- [x] **T-04-01-04**: Verify the job runs on `ubuntu-slim`
  - Target: `jobs.*.runs-on`
  - Scenario: Given the job runner is configured
  - Expected: Then `runs-on: ubuntu-slim` (GitHub-hosted runner label; jactionlint accepts it without a self-hosted-runner setting)
  - `yq`: `.jobs."scan-betterleaks"."runs-on" == "ubuntu-slim"`

---

## T-05: Fetch Depth and Report

### [正常] Normal Cases

#### T-05-01: fetch-depth input and target-checkout configuration

- [x] **T-05-01-01**: Verify `fetch-depth` input is declared with default `50` for `workflow_call`
  - Target: `on.workflow_call.inputs.fetch-depth`
  - Scenario: Given the workflow is defined, When `workflow_call` inputs are inspected
  - Expected: Then `fetch-depth` exists with `required: false`, `default: 50`, `type: number`
  - `yq`: `.on.workflow_call.inputs."fetch-depth".default == 50 and .on.workflow_call.inputs."fetch-depth".required == false`

- [x] **T-05-01-02**: Verify `target-checkout` passes `fetch-depth: ${{ inputs.fetch-depth }}`
  - Target: `steps` (index 0, `id: target-checkout`) `.with.fetch-depth`
  - Scenario: Given the workflow runs with a fetch-depth input
  - Expected: Then `with.fetch-depth` equals `${{ inputs.fetch-depth }}`
  - `yq`: `.jobs."scan-betterleaks".steps[0].with."fetch-depth" == "${{ inputs.fetch-depth }}"`

- [x] **T-05-01-03**: Verify `target-checkout` sets `persist-credentials: false`
  - Target: `steps` (index 0, `id: target-checkout`) `.with.persist-credentials`
  - Scenario: Given the target repository is checked out
  - Expected: Then `with.persist-credentials: false`
  - `yq`: `.jobs."scan-betterleaks".steps[0].with."persist-credentials" == false`

#### T-05-02: Report preparation and scan output

- [x] **T-05-02-01**: Verify `prepare-report` step creates `.github/report/` directory
  - Target: `steps.prepare-report`
  - Scenario: Given `resolve-config` completed, When the report directory step runs
  - Expected: Then step with `id: prepare-report` runs `mkdir -p .github/report` and is gated on `steps.resolve-config.outcome == 'success'`
  - `yq`: `(.jobs."scan-betterleaks".steps[] | select(.id=="prepare-report")).run | test("mkdir -p .github/report")`

- [x] **T-05-02-02**: Verify `scan-execute` writes report to `.github/report/betterleaks-report.json`
  - Target: `steps.scan-execute.run`
  - Scenario: Given `prepare-report` completed, When scan runs
  - Expected: Then the run command includes `--report-path=.github/report/betterleaks-report.json`
  - `yq`: `(.jobs."scan-betterleaks".steps[] | select(.id=="scan-execute")).run | test("--report-path=\\.github/report/betterleaks-report\\.json")`

- [x] **T-05-02-03**: Verify `scan-execute` exposes exit code as step output `status`
  - Target: `steps.scan-execute.run`
  - Scenario: Given the scanner runs, When the step completes
  - Expected: Then the run script writes `status=<exit-code>` to `$GITHUB_OUTPUT`
  - `yq`: `(.jobs."scan-betterleaks".steps[] | select(.id=="scan-execute")).run | test("GITHUB_OUTPUT")`

### [異常] Error Cases

#### T-05-03: Report upload on failure

- [x] **T-05-03-01**: Verify `upload-report` step exists and uploads on failure only
  - Target: `steps.upload-report`
  - Scenario: Given the scanner exits with a non-zero code
  - Expected: Then step with `id: upload-report` exists with `if: failure() && steps.scan-execute.outputs.status != '0'`
  - `yq`: `(.jobs."scan-betterleaks".steps[] | select(.id=="upload-report")).if | test("failure\\(\\)")`

- [x] **T-05-03-02**: Verify `upload-report` uses `actions/upload-artifact` with artifact name `betterleaks-report`
  - Target: `steps.upload-report.with`
  - Scenario: Given a scan violation is detected
  - Expected: Then `with.name: betterleaks-report` and `with.path: .github/report/betterleaks-report.json`
  - `yq`: `(.jobs."scan-betterleaks".steps[] | select(.id=="upload-report")).with.name == "betterleaks-report" and (.jobs."scan-betterleaks".steps[] | select(.id=="upload-report")).with.path == ".github/report/betterleaks-report.json"`

### [エッジケース] Edge Cases

#### T-05-04: fetch-depth edge values

- [x] **T-05-04-01**: Verify `fetch-depth` default resolves to `50` when omitted
  - Target: `on.workflow_call.inputs.fetch-depth.default`
  - Scenario: Given `fetch-depth` is omitted by the caller
  - Expected: Then `default == 50` (not 0, not null)
  - `yq`: `.on.workflow_call.inputs."fetch-depth".default == 50`

---

## T-06: Config Resolution

### [正常] Normal Cases

#### T-06-01: resolve-config step wiring

- [x] **T-06-01-01**: Verify `resolve-config` uses `_ca-resolve-config` with the three candidates
  - Target: `steps.resolve-config`
  - Scenario: Given `config-checkout` completed
  - Expected: Then step `resolve-config` uses `aglabo/ci-platform/.github/actions/_ca-resolve-config@v0.8.1`, sets `with.config: ${{ inputs.config }}`, `with.local-config: configs/betterleaks.toml`, `with.global-config: global/configs/betterleaks.toml`, and has `if: steps.config-checkout.outcome == 'success'`
  - `yq`: `(.jobs."scan-betterleaks".steps[] | select(.id=="resolve-config")).with."local-config" == "configs/betterleaks.toml" and (.jobs."scan-betterleaks".steps[] | select(.id=="resolve-config")).with."global-config" == "global/configs/betterleaks.toml"`

- [x] **T-06-01-02**: Verify `scan-execute` reads the resolved config file
  - Target: `steps.scan-execute.env.CONFIG_FILE`
  - Scenario: Given the configuration is resolved
  - Expected: Then `CONFIG_FILE == ${{ steps.resolve-config.outputs.config-file }}`
  - `yq`: `(.jobs."scan-betterleaks".steps[] | select(.id=="scan-execute")).env.CONFIG_FILE == "${{ steps.resolve-config.outputs.config-file }}"`

### [異常] Error Cases

#### T-06-02: Resolution failures (behavior of `_ca-resolve-config`, exercised in its own module)

- [x] **T-06-02-01**: Verify `resolve-config` has no `continue-on-error` so a missing explicit config fails the job
  - Target: `steps.resolve-config.continue-on-error`
  - Scenario: Given `config` names a missing file
  - Expected: Then `continue-on-error` is absent or `false`, so the job fails before `scan-execute`
  - `yq`: `((.jobs."scan-betterleaks".steps[] | select(.id=="resolve-config"))."continue-on-error" // false) == false`

- [x] **T-06-02-02**: Verify the no-fallback rule is delegated to `_ca-resolve-config` (an explicit `config` is the only candidate)
  - Target: `steps.resolve-config.with.config`
  - Scenario: Given the caller supplies `config`
  - Expected: Then the workflow forwards `inputs.config` unchanged and adds no fallback logic of its own
  - `yq`: `(.jobs."scan-betterleaks".steps[] | select(.id=="resolve-config")).with.config == "${{ inputs.config }}"`

### [エッジケース] Edge Cases

#### T-06-03: Candidate paths

- [x] **T-06-03-01**: Verify the local candidate is repository-relative and the global candidate lies under the config checkout
  - Target: `steps.resolve-config.with`, `steps.config-checkout.with.path`
  - Scenario: Given `config` is empty
  - Expected: Then `local-config` is `configs/betterleaks.toml` and `global-config` starts with the `config-checkout` path (`global/configs`)
  - `yq`: `(.jobs."scan-betterleaks".steps[] | select(.id=="resolve-config")).with."global-config" | startswith("global/configs/")`

- [x] **T-06-03-02**: Verify `config-checkout` runs before `resolve-config` so the global candidate exists
  - Target: `jobs.scan-betterleaks.steps[*].id`
  - Scenario: Given `config` is empty and no local file exists
  - Expected: Then `config-checkout` precedes `resolve-config`
  - `yq`: `[.jobs."scan-betterleaks".steps[].id] | index("config-checkout") < index("resolve-config")`
