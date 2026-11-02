---
title: "Implementation Plan: Ghalint Reusable Workflow"
based-on: specifications.md v1.1.0
version: 1.1.0
status: Draft
---

## 1. Overview

### 1.1 Purpose

`ru-qa-ghalint.yml` reusable workflow を新規作成します。
そのうえで、`ci-workflows-qa.yml` における
外部リポジトリ (`aglabo/.github`) への ghalint 依存を、ローカル呼び出しに置き換えます。

実装は `ru-qa-actionlint.yml` と同じ 7 ステップパターンに準拠します。
ステップの順序は、次のとおりです。

1. `target-checkout`
2. `env-validation`
3. `tool-install`
4. `config-checkout`
5. `prepare-report`
6. `lint-execute`
7. `report-upload`

### 1.2 Reference

- Prior Art: `docs/.deckrd/reusable-workflows/actionlint/implementation/implementation.md`（直接テンプレート）
- Specifications: `docs/.deckrd/reusable-workflows/ghalint/specifications/specifications.md`
- Pattern reference: `.github/workflows/ru-qa-actionlint.yml`

### 1.3 Open Questions (解決済み)

実装前に確認が必要だった事項と、その結論です。

- ghalint のデフォルトバージョン番号: `1.6.0`（現行実装の既定値）
- `aglabo/global-configs` リポジトリに `ghalint.yaml` が存在するか: リポジトリ直下に存在することを確認済み

---

## 2. Implementation Plan

### Phase 1: Ghalint Reusable Workflow 作成

#### Commit 1: `ci(workflows/ru-qa-ghalint): add reusable ghalint workflow`

- `.github/workflows/ru-qa-ghalint.yml` を新規作成します
- `on.workflow_call` トリガーを定義し、以下の inputs を設定します
  - `version`: string, required: false, default: `1.6.0`
  - `config`: string, required: false, default: `./global/configs/ghalint.yaml`
- `permissions: contents: read` を workflow レベルで設定します
- `jobs.qa-ghalint` を定義します
  - `runs-on: ubuntu-slim`
  - `timeout-minutes: 10`
  - `permissions: contents: read`（job レベルでも明示します）
- Step 1 `target-checkout`: リポジトリをチェックアウトします
  - `actions/checkout@v7.0.1`
  - `persist-credentials: false`
- Step 2 `env-validation`: 実行環境を検証します
  - `aglabo/ci-platform/.github/actions/ca-validate-environment@v0.5.0`
  - `actions-type: read`
  - 条件: `steps.target-checkout.outcome == 'success'`
- Step 3 `tool-install`: ghalint をインストールします
  - `aglabo/ci-platform/.github/actions/ca-setup-tool@v0.5.0`
  - `repo: suzuki-shunsuke/ghalint`
  - `tool-version: ${{ inputs.version }}`
  - 条件: `steps.env-validation.outcome == 'success'`
- Step 4 `config-checkout`: 共有設定リポジトリをチェックアウトします
  - `actions/checkout@v7.0.1`
  - `repository: aglabo/global-configs`、`path: global/configs`
  - `fetch-depth: 1`、`persist-credentials: false`
  - 条件: `steps.tool-install.outcome == 'success'`
- Step 5 `prepare-report`: レポート出力先を作成します
  - `run: mkdir -p .github/report`
  - 条件: `steps.config-checkout.outcome == 'success'`
- Step 6 `lint-execute`: ghalint を実行し、結果をレポートに記録します
  - 条件: `steps.prepare-report.outcome == 'success'`
  - 設定ファイルのパスは `env: CONFIG_FILE: ${{ inputs.config }}` で受け渡します
  - 実行コマンドは、次のとおりです

  ```yaml
  run: |
    ghalint run --config "${CONFIG_FILE}" 2>&1 | tee .github/report/ghalint-report.txt
    exit "${PIPESTATUS[0]}"
  ```

- Step 7 `report-upload`: 失敗時にレポートをアーティファクトとして保存します
  - `actions/upload-artifact@v7.0.2`
  - `name: ghalint-report`、`path: .github/report/ghalint-report.txt`
  - `retention-days: 30`
  - 条件: `failure() && steps.lint-execute.outcome == 'failure'`

### Phase 2: CI Caller 更新

#### Commit 2: `ci(workflows/ci-workflows-qa): replace external ghalint with local reusable workflow`

- `.github/workflows/ci-workflows-qa.yml` の `ghalint` ジョブを編集します
- 次の外部ワークフロー参照を削除します

  ```yaml
  uses: aglabo/.github/.github/workflows/ci-common-lint-ghalint.yml@38070c03acff350b4c8f46d684781052b70c0e58
  ```

- `uses: ./.github/workflows/ru-qa-ghalint.yml` に置き換えます
- `with:` ブロックは指定せず、global-configs の既定設定 (`./global/configs/ghalint.yaml`) を使用します
- `permissions: contents: read` は維持します

---

## 3. Change History

| Date       | Version | Description                                                                                                                                                                                                                                                                                                                                                                             |
| ---------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-06-13 | 1.0.0   | Initial implementation plan                                                                                                                                                                                                                                                                                                                                                             |
| 2026-11-03 | 1.1.0   | 設定リポジトリを aglabo/global-configs に変更 (チェックアウト先 global/configs、config 既定値 ./global/configs/ghalint.yaml)、実装に合わせて参照を更新 (ru-qa-ghalint.yml、入力 version / config、env CONFIG_FILE、ca-* Composite Action @v0.5.0、バージョンタグ固定)、版番号を 3 部構成に修正、Open Questions を解決済みに更新、caller は with: なしで global-configs の既定設定を使用 |
