---
title: "Implementation Plan: Lint Documents Reusable Workflow"
version: 1.0.0
based-on: specifications.md v1.0.0
status: Draft
---

<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/max-comma -->
<!-- markdownlint-disable line-length -->

## 1. Overview

### 1.1 Purpose

This plan records how `.github/workflows/ru-lint-documents.yml` implements the specification. The workflow is already in place; this document is the decision basis for changes to it.

Units: `workflow-skeleton`, `get-changed-files` job, `qa-textlint` job, `qa-markdownlint` job. The two lint jobs share one step pattern and differ in the tool, the configuration candidates, and the report name.

### 1.2 Reference

- Specifications: specifications.md
- Output workflow file: `.github/workflows/ru-lint-documents.yml`
- Caller: `.github/workflows/ci-docs-qa.yml`

## 2. Implementation Plan

### Phase 1: Reusable Workflow YAML

#### Commit 1: ci(workflows): add lint-documents reusable workflow

- Skeleton:
  - `name: "Reusable: Lint Documents"`, top-level `permissions.contents: read`, `defaults.run.shell: bash`, trigger `workflow_call`.
  - Header `# @version` follows the repository release (currently `0.7.0`).

- Inputs (all `required: false`, `type: string`): `pattern` (block scalar `**/*.md` / `**/*.mdx`), `commit-count` (`"1"`), `doc-tools-version` (`v0.3.0`), `pnpm-version` (`""`), `textlint-config` (`""`), `markdownlint-config` (`""`).

- Job `get-changed-files` (`ubuntu-slim`, timeout 10, `permissions.contents: read`):
  - Job outputs: `files: ${{ steps.changed-files.outputs.files }}`, `count: ${{ steps.changed-files.outputs.count }}`.
  - `target-checkout` (`actions/checkout`, `fetch-depth: 0`, `persist-credentials: false`).
  - `env-validation`: `ca-validate-environment@v0.8.0-pre`, `actions-type: read`, `if: steps.target-checkout.outcome == 'success'`.
  - `changed-files`: `ca-get-changed-files@v0.8.0-pre` with `commit-count` and `pattern`, `if: steps.env-validation.outcome == 'success'`.

- Jobs `qa-textlint` and `qa-markdownlint` (`ubuntu-latest`, timeout 15, `needs: get-changed-files`, `if: needs.get-changed-files.outputs.count != '0'`, `permissions.contents: read`). Shared steps, each gated on the previous step id:
  - `target-checkout` (`persist-credentials: false`).
  - `env-validation` (`ca-validate-environment@v0.8.0-pre`, `actions-type: read`).
  - `tool-install` (`ca-setup-repo@v0.8.0-pre`: `repo: aglabo/agla-doc-tools`, `path: ./.tools/agla-doc-tools`, `ref: ${{ inputs.doc-tools-version }}`, `pnpm-version: ${{ inputs.pnpm-version }}`).
  - `config-checkout` (`actions/checkout`: `repository: aglabo/global-configs`, `path: global/configs`, `fetch-depth: 1`, `persist-credentials: false`).
  - `resolve-config` (`_ca-resolve-config@v0.8.0-pre`).
  - `prepare-report` (`mkdir -p .github/report`).
  - `lint-execute` (env `CONFIG_FILE`, `CHANGED_FILES`; reads targets with `mapfile -t targets <<< "${CHANGED_FILES}"`; pipes through `tee`; `exit "${PIPESTATUS[0]}"`).
  - `report-upload` (`actions/upload-artifact`, `if: failure() && steps.lint-execute.outcome == 'failure'`, `retention-days: 30`).

- Tool-specific values:

  | Job               | `resolve-config` (config / local / global)                                                                  | `lint-execute`                                                                       | Artifact name         | Report path                              |
  | ----------------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | --------------------- | ---------------------------------------- |
  | `qa-textlint`     | `inputs.textlint-config` / `configs/textlintrc.yaml` / `global/configs/textlintrc.yaml`                     | `textlint --version`, then `textlint --config ... --ignore-path <ignore> -- targets` | `textlint-report`     | `.github/report/textlint-report.txt`     |
  | `qa-markdownlint` | `inputs.markdownlint-config` / `configs/.markdownlint-cli2.yaml` / `global/configs/.markdownlint-cli2.yaml` | `markdownlint --config ... -- targets`                                               | `markdownlint-report` | `.github/report/markdownlint-report.txt` |

  - The textlint ignore file is `.textlintignore` when present, otherwise `global/configs/.textlintignore`.

- Expected behavior after this commit:
  - Callable through `workflow_call` with no `with:` block.
  - Lints only the changed Markdown files, with both linters in parallel.
  - Uses the local configuration when present, otherwise the global one.
  - Uploads a report artifact only for the linter that failed.

## 3. Change History

| Date       | Version | Description                 |
| ---------- | ------- | --------------------------- |
| 2026-11-19 | 1.0.0   | Initial implementation plan |
