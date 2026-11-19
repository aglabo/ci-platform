---
title: "Implementation Tasks"
module: "reusable-workflows/lint-documents"
status: Active
created: "2026-11-19 00:00:00"
source: specifications.md v1.0.0, implementation.md v1.0.0
---

<!-- textlint-disable
  ja-technical-writing/sentence-length, ja-technical-writing/max-comma
  -->
<!-- markdownlint-disable no-duplicate-heading line-length -->

> This document contains implementation tasks derived from specifications.
> Each task corresponds to a single check on `.github/workflows/ru-lint-documents.yml`.
> Test method: static YAML analysis via `jactionlint` (CI) and `yq` attribute inspection (local developer verification only; `yq` is NOT used inside the workflow).
> The `yq:` lines are hints for the developer writing the check, not workflow steps.
> No automated test exists yet for this workflow, so every task is unchecked.

---

## Task Summary

| Test Target                 | Scenario Groups            | Case Count |
| --------------------------- | -------------------------- | ---------: |
| T-01: Workflow structure    | Normal / Error / Edge case |          8 |
| T-02: get-changed-files job | Normal / Error             |          4 |
| T-03: Lint job pipeline     | Normal / Error / Edge case |         12 |
| T-04: Static validation     | Normal                     |          3 |
| **Total**                   | 10 scenario groups         |     **27** |

---

## T-01: Workflow Structure

### [正常] Normal Cases

#### T-01-01: Inputs, triggers, and permissions

- [ ] **T-01-01-01**: Verify the six `workflow_call` inputs exist, are optional strings
  - Target: `on.workflow_call.inputs`
  - Scenario: Given the workflow is defined
  - Expected: Then `pattern`, `commit-count`, `doc-tools-version`, `pnpm-version`, `textlint-config`, `markdownlint-config` all have `required: false` and `type: string`
  - `yq`: `[.on.workflow_call.inputs[] | select(.required == false and .type == "string")] | length == 6`

- [ ] **T-01-01-02**: Verify input defaults
  - Target: `on.workflow_call.inputs.*.default`
  - Scenario: Given no caller value
  - Expected: Then `commit-count == "1"`, `doc-tools-version == "v0.3.0"`, `pnpm-version == ""`, `textlint-config == ""`, `markdownlint-config == ""`
  - `yq`: `.on.workflow_call.inputs."doc-tools-version".default == "v0.3.0" and .on.workflow_call.inputs."commit-count".default == "1"`

- [ ] **T-01-01-03**: Verify the `pattern` default lists both Markdown globs
  - Target: `on.workflow_call.inputs.pattern.default`
  - Scenario: Given no caller value
  - Expected: Then the default contains `**/*.md` and `**/*.mdx`
  - `yq`: `.on.workflow_call.inputs.pattern.default | (test("\\*\\*/\\*\\.md")) and (test("\\*\\*/\\*\\.mdx"))`

- [ ] **T-01-01-04**: Verify top-level and job-level permissions are `contents: read` only
  - Target: `permissions`, `jobs.*.permissions`
  - Scenario: Given permissions are evaluated
  - Expected: Then the top level and every job equal `{"contents": "read"}`
  - `yq`: `.permissions == {"contents": "read"} and ([.jobs[].permissions] | all(. == {"contents": "read"}))`

### [異常] Error Cases

#### T-01-02: No workflow outputs

- [ ] **T-01-02-01**: Verify no `workflow_call` outputs are declared
  - Target: `on.workflow_call.outputs`
  - Scenario: Given a caller might expect outputs
  - Expected: Then `on.workflow_call.outputs` is absent or empty
  - `yq`: `(.on.workflow_call.outputs // {}) == {}`

- [ ] **T-01-02-02**: Verify only `get-changed-files` declares job outputs
  - Target: `jobs.*.outputs`
  - Scenario: Given jobs might declare outputs
  - Expected: Then only `get-changed-files` has outputs (`files`, `count`)
  - `yq`: `[.jobs | to_entries[] | select(.value.outputs != null) | .key] == ["get-changed-files"]`

### [エッジケース] Edge Cases

#### T-01-03: Job set

- [ ] **T-01-03-01**: Verify the workflow has exactly the three jobs
  - Target: `jobs`
  - Scenario: Given the workflow is defined
  - Expected: Then job keys are `get-changed-files`, `qa-textlint`, `qa-markdownlint`
  - `yq`: `.jobs | keys == ["get-changed-files","qa-markdownlint","qa-textlint"]`

- [ ] **T-01-03-02**: Verify no step in any job uses `continue-on-error: true`
  - Target: `jobs.*.steps[*].continue-on-error`
  - Scenario: Given any step could be marked to continue
  - Expected: Then none do
  - `yq`: `[.jobs[].steps[] | select(."continue-on-error" == true)] | length == 0`

---

## T-02: get-changed-files Job

### [正常] Normal Cases

#### T-02-01: Listing job wiring

- [ ] **T-02-01-01**: Verify runner, timeout, and checkout depth
  - Target: `jobs.get-changed-files`
  - Scenario: Given the listing job is defined
  - Expected: Then `runs-on: ubuntu-slim`, `timeout-minutes: 10`, and the first step uses `actions/checkout` with `fetch-depth: 0` and `persist-credentials: false`
  - `yq`: `.jobs."get-changed-files"."runs-on" == "ubuntu-slim" and .jobs."get-changed-files".steps[0].with."fetch-depth" == 0`

- [ ] **T-02-01-02**: Verify `changed-files` passes `commit-count` and `pattern`
  - Target: `steps.changed-files.with`
  - Scenario: Given validation succeeded
  - Expected: Then `uses` is `ca-get-changed-files@v0.8.0-pre`, `with.commit-count: ${{ inputs.commit-count }}`, `with.pattern: ${{ inputs.pattern }}`, `if: steps.env-validation.outcome == 'success'`
  - `yq`: `(.jobs."get-changed-files".steps[] | select(.id=="changed-files")).with.pattern == "${{ inputs.pattern }}"`

- [ ] **T-02-01-03**: Verify job outputs map to the `changed-files` step
  - Target: `jobs.get-changed-files.outputs`
  - Scenario: Given the step outputs
  - Expected: Then `files == ${{ steps.changed-files.outputs.files }}` and `count == ${{ steps.changed-files.outputs.count }}`
  - `yq`: `.jobs."get-changed-files".outputs.count == "${{ steps.changed-files.outputs.count }}"`

### [異常] Error Cases

#### T-02-02: Validation gate

- [ ] **T-02-02-01**: Verify `env-validation` gates the listing step
  - Target: `steps.env-validation`, `steps.changed-files.if`
  - Scenario: Given environment validation fails
  - Expected: Then `changed-files` has `if: steps.env-validation.outcome == 'success'` and `env-validation` uses `actions-type: read`
  - `yq`: `(.jobs."get-changed-files".steps[] | select(.id=="changed-files")).if == "steps.env-validation.outcome == 'success'"`

---

## T-03: Lint Job Pipeline

### [正常] Normal Cases

#### T-03-01: Gating and runners

- [ ] **T-03-01-01**: Verify both lint jobs need the listing job and skip when `count` is `'0'`
  - Target: `jobs.qa-textlint`, `jobs.qa-markdownlint`
  - Scenario: Given no changed files
  - Expected: Then `needs: get-changed-files` and `if: needs.get-changed-files.outputs.count != '0'`
  - `yq`: `[.jobs["qa-textlint"], .jobs["qa-markdownlint"]] | all(.if == "needs.get-changed-files.outputs.count != '0'")`

- [ ] **T-03-01-02**: Verify runner and timeout of the lint jobs
  - Target: `jobs.qa-*`
  - Scenario: Given the lint jobs are defined
  - Expected: Then `runs-on: ubuntu-latest` and `timeout-minutes: 15`
  - `yq`: `[.jobs["qa-textlint"], .jobs["qa-markdownlint"]] | all(."runs-on" == "ubuntu-latest" and ."timeout-minutes" == 15)`

- [ ] **T-03-01-03**: Verify the step id order in both lint jobs
  - Target: `jobs.qa-*.steps[*].id`
  - Scenario: Given the pipeline is defined
  - Expected: Then ids are `target-checkout`, `env-validation`, `tool-install`, `config-checkout`, `resolve-config`, `prepare-report`, `lint-execute`, `report-upload`
  - `yq`: `[.jobs["qa-textlint"].steps[].id] == ["target-checkout","env-validation","tool-install","config-checkout","resolve-config","prepare-report","lint-execute","report-upload"]`

#### T-03-02: Tool setup and configuration resolution

- [ ] **T-03-02-01**: Verify `tool-install` uses `ca-setup-repo` with `agla-doc-tools`
  - Target: `steps.tool-install.with`
  - Scenario: Given validation succeeded
  - Expected: Then `repo: aglabo/agla-doc-tools`, `path: ./.tools/agla-doc-tools`, `ref: ${{ inputs.doc-tools-version }}`, `pnpm-version: ${{ inputs.pnpm-version }}`
  - `yq`: `(.jobs["qa-textlint"].steps[] | select(.id=="tool-install")).with.ref == "${{ inputs.doc-tools-version }}"`

- [ ] **T-03-02-02**: Verify the textlint configuration candidates
  - Target: `jobs.qa-textlint.steps.resolve-config.with`
  - Scenario: Given `textlint-config` is empty
  - Expected: Then `config: ${{ inputs.textlint-config }}`, `local-config: configs/textlintrc.yaml`, `global-config: global/configs/textlintrc.yaml`
  - `yq`: `(.jobs["qa-textlint"].steps[] | select(.id=="resolve-config")).with."local-config" == "configs/textlintrc.yaml"`

- [ ] **T-03-02-03**: Verify the markdownlint configuration candidates
  - Target: `jobs.qa-markdownlint.steps.resolve-config.with`
  - Scenario: Given `markdownlint-config` is empty
  - Expected: Then `config: ${{ inputs.markdownlint-config }}`, `local-config: configs/.markdownlint-cli2.yaml`, `global-config: global/configs/.markdownlint-cli2.yaml`
  - `yq`: `(.jobs["qa-markdownlint"].steps[] | select(.id=="resolve-config")).with."global-config" == "global/configs/.markdownlint-cli2.yaml"`

- [ ] **T-03-02-04**: Verify `config-checkout` fetches `aglabo/global-configs` into `global/configs`
  - Target: `steps.config-checkout.with`
  - Scenario: Given the tools are installed
  - Expected: Then `repository: aglabo/global-configs`, `path: global/configs`, `fetch-depth: 1`, `persist-credentials: false`
  - `yq`: `(.jobs["qa-textlint"].steps[] | select(.id=="config-checkout")).with.path == "global/configs"`

### [異常] Error Cases

#### T-03-03: Failure handling

- [ ] **T-03-03-01**: Verify linters propagate their own exit status
  - Target: `steps.lint-execute.run`
  - Scenario: Given a linter exits non-zero while piped to `tee`
  - Expected: Then the script ends with `exit "${PIPESTATUS[0]}"`
  - `yq`: `[.jobs["qa-textlint"], .jobs["qa-markdownlint"]] | all(.steps[] | select(.id=="lint-execute") | .run | test("PIPESTATUS\\[0\\]"))`

- [ ] **T-03-03-02**: Verify the report upload condition and artifacts
  - Target: `steps.report-upload`
  - Scenario: Given a linter failed
  - Expected: Then `if: failure() && steps.lint-execute.outcome == 'failure'`, artifact names `textlint-report` / `markdownlint-report`, `retention-days: 30`
  - `yq`: `(.jobs["qa-textlint"].steps[] | select(.id=="report-upload")).with.name == "textlint-report"`

### [エッジケース] Edge Cases

#### T-03-04: Ignore file and gating

- [ ] **T-03-04-01**: Verify the textlint ignore-file fallback
  - Target: `jobs.qa-textlint.steps.lint-execute.run`
  - Scenario: Given `.textlintignore` is absent
  - Expected: Then the script falls back to `global/configs/.textlintignore`
  - `yq`: `(.jobs["qa-textlint"].steps[] | select(.id=="lint-execute")).run | test("global/configs/\\.textlintignore")`

- [ ] **T-03-04-02**: Verify each step after the checkout is gated on the previous step id
  - Target: `steps.*.if`
  - Scenario: Given any upstream step fails
  - Expected: Then `env-validation`, `tool-install`, `config-checkout`, `resolve-config`, `prepare-report`, `lint-execute` each gate on the previous step's `outcome == 'success'`
  - `yq`: `(.jobs["qa-textlint"].steps[] | select(.id=="prepare-report")).if == "steps.resolve-config.outcome == 'success'"`

- [ ] **T-03-04-03**: Verify `lint-execute` reads the resolved config file and the changed-files list
  - Target: `steps.lint-execute.env`
  - Scenario: Given the config is resolved
  - Expected: Then `CONFIG_FILE == ${{ steps.resolve-config.outputs.config-file }}` and `CHANGED_FILES == ${{ needs.get-changed-files.outputs.files }}`
  - `yq`: `(.jobs["qa-markdownlint"].steps[] | select(.id=="lint-execute")).env.CHANGED_FILES == "${{ needs.get-changed-files.outputs.files }}"`

---

## T-04: Static Validation

### [正常] Normal Cases

#### T-04-01: jactionlint and structural invariants

- [ ] **T-04-01-01**: `jactionlint` passes with no errors
  - Target: `.github/workflows/ru-lint-documents.yml`
  - Scenario: Given the workflow YAML exists
  - Expected: Then `jactionlint .github/workflows/ru-lint-documents.yml` exits 0

- [ ] **T-04-01-02**: Verify step ids are unique within each job
  - Target: `jobs.*.steps[*].id`
  - Scenario: Given all steps are declared
  - Expected: Then no job has duplicate step ids
  - `yq`: `[.jobs[].steps | ([.[].id] | (unique | length) == length)] | all`

- [ ] **T-04-01-03**: Verify every action reference from this repository is pinned to `@v0.8.0-pre`
  - Target: `jobs.*.steps[*].uses`
  - Scenario: Given the workflow uses repository composite actions
  - Expected: Then every `aglabo/ci-platform/` reference ends with `@v0.8.0-pre`
  - `yq`: `[.jobs[].steps[].uses | select(. != null and test("^aglabo/ci-platform/"))] | all(test("@v0\\.8\\.0-pre$"))`
