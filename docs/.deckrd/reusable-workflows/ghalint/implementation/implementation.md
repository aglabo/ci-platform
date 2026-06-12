---
title: "Implementation Plan: Ghalint Reusable Workflow"
based-on: specifications.md v1.0.0
status: Draft
---

<!-- markdownlint-disable line-length -->

## 1. Overview

### 1.1 Purpose

`ci-qa-ghalint.yml` reusable workflow を新規作成し、`ci-workflows-qa.yml` における
外部リポジトリ (`aglabo/.github`) への ghalint 依存をローカル呼び出しに置き換える。

実装は `ci-qa-actionlint.yml` と同じ 7 ステップパターンに完全に準拠する:
target-checkout → env-validation → tool-install → config-checkout →
prepare-report → lint-execute → report-upload。

### 1.2 Reference

- Prior Art: `docs/.deckrd/reusable-workflows/actionlint/implementation/implementation.md`（直接テンプレート）
- Specifications: `docs/.deckrd/reusable-workflows/ghalint/specifications/specifications.md`
- Pattern reference: `.github/workflows/ci-qa-actionlint.yml`

### 1.3 Open Questions (解決必要)

以下は実装前に確認が必要な未解決事項:

- ghalint のデフォルトバージョン番号: `1.5.6`（最新安定版、2026-06-13 確認済み）
- `aglabo/.github` リポジトリに `shared/configs/ghalint.yaml` が存在するか

---

## 2. Implementation Plan

### Phase 1: Ghalint Reusable Workflow 作成

#### Commit 1: `ci(workflows/ci-qa-ghalint): add reusable ghalint workflow`

- `.github/workflows/ci-qa-ghalint.yml` を新規作成する
- `on.workflow_call` トリガーを定義し、以下の inputs を設定する:
  -- `ghalint-version`: string, required: false, default: `<最新安定版>` (Open Question)
  -- `config-file`: string, required: false, default: `./shared/configs/ghalint.yaml`
- `permissions: contents: read` を workflow レベルで設定する
- `jobs.qa-ghalint` を定義する:
  -- `runs-on: ubuntu-slim`
  -- `timeout-minutes: 10`
  -- `permissions: contents: read`（job レベルでも明示）
- Step 1 `target-checkout`: `actions/checkout@9f698171ed81b15d1823a05fc7211befd50c8ae0 # v6.0.3` で `persist-credentials: false`
- Step 2 `env-validation`: `./.github/actions/validate-environment` で `actions-type: read`、条件: `steps.target-checkout.outcome == 'success'`
- Step 3 `tool-install`: `./.github/actions/setup-tool` で `repo: suzuki-shunsuke/ghalint`、`tool-version: ${{ inputs.ghalint-version }}`、条件: `steps.env-validation.outcome == 'success'`
- Step 4 `config-checkout`: `actions/checkout@9f698171ed81b15d1823a05fc7211befd50c8ae0 # v6.0.3` で `repository: aglabo/.github`、`path: shared`、`fetch-depth: 1`、`persist-credentials: false`、条件: `steps.tool-install.outcome == 'success'`
- Step 5 `prepare-report`: `run: mkdir -p .github/report`、条件: `steps.config-checkout.outcome == 'success'`
- Step 6 `lint-execute`: `run: ghalint run --config "${{ inputs.config-file }}" 2>&1 | tee .github/report/ghalint-report.txt; exit "${PIPESTATUS[0]}"`、条件: `steps.prepare-report.outcome == 'success'`
- Step 7 `report-upload`: `actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1`、`name: ghalint-report`、`path: .github/report/ghalint-report.txt`、`retention-days: 30`、条件: `failure() && steps.lint-execute.outcome == 'failure'`

### Phase 2: CI Caller 更新

#### Commit 2: `ci(workflows/ci-workflows-qa): replace external ghalint with local reusable workflow`

- `.github/workflows/ci-workflows-qa.yml` の `ghalint` ジョブを編集する
- `uses: aglabo/.github/.github/workflows/ci-common-lint-ghalint.yml@38070c03acff350b4c8f46d684781052b70c0e58` を削除する
- `uses: ./.github/workflows/ci-qa-ghalint.yml` に置き換える
- `with:` ブロックは不要（全デフォルト値を使用）
- `permissions: contents: read` は維持する

---

## 3. Change History

| Date       | Version | Description                 |
| ---------- | ------- | --------------------------- |
| 2026-06-13 | 1.0     | Initial implementation plan |
