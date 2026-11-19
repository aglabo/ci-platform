---
title: "Implementation Plan: ca-run-secretlint"
based-on: specifications.md v1.0.0
status: Draft
version: 1.0.0
created: "2026-11-19"
---

## 1. Overview

### 1.1 Purpose

公開 Composite Action `.github/actions/ca-run-secretlint/` を実装する。
判定規則は specifications.md §4 に従う。

本書は、すでに実装済みのコード (PR #209) に合わせて書いた。

完了条件は次のとおりとする。

- ShellSpec の全テストに `not ok` が無い
- `pnpm lint:sh` (shellcheck) と `pnpm check:sh` (shfmt) を通過する
- actionlint / ghalint を通過する
- `_tests_ru_reusable-workflows.yml` が `ru-scan-secrets.yml` を呼んで成功する

**実装品質基準 (全コミット共通):**

- 各コミットの中で BDD の RGR サイクルを回す。テストとその実装は同じコミットに含める。
- テスト ID は `T-RSL-<略語>-<連番>` とする。ケース名には `[Normal]` / `[Error]` / `[Edge]` を付ける。
- テストの実行は `runners/run-shellspec.sh` 経由で行う。
- 内部シンボルは先頭アンダースコアで区別する。ライブラリはロードガード (`RSL_INPUTS_LIB_LOADED`) を持つ。
- スクリプトは `set -euo pipefail` とし、`main` は実行時だけ呼ぶ (`if ! (return 0 2> /dev/null)`)。

### 1.2 Reference

- Specifications: specifications.md v1.0.0
- Decision Records: DR-01〜DR-05
- PR #209 (Action とスキャンジョブの追加)

### 1.3 Design Decisions

| 単位                  | 略語 | 配置                                                            |
| --------------------- | ---- | --------------------------------------------------------------- |
| バージョンの検証      | VER  | `.github/actions/ca-run-secretlint/scripts/_libs/inputs.lib.sh` |
| エントリポイント      | RUN  | `.github/actions/ca-run-secretlint/scripts/run-secretlint.sh`   |
| action.yml の静的検査 | ACT  | `.github/actions/ca-run-secretlint/action.yml`                  |

**関数ごとの実装上の詳細:**

- `validate_secretlint_version`: 引数が無い場合は空として扱う (`${1:-}`)。
  不一致なら `gha_error "secretlint-version" "<問題>" "<値>"` を呼び、1 を返す。
  問題の文言は `must be in X.Y.Z format with major version 14 or later` とする。
- `main`: `validate_secretlint_version "${INPUT_SECRETLINT_VERSION:-}" || return 1` を先に実行する。
  続けて `pnpm dlx "secretlint@${INPUT_SECRETLINT_VERSION}"` を実行し、その終了コードを戻り値にする。
- `run-secretlint.sh` は `_libs/error.lib.sh` を `SCRIPT_DIR` 基準で読み込む。
- `action.yml` の pnpm ステップ (`setup-pnpm`) は、次の Action を使う。
  - `pnpm/action-setup@73e46992e05b19abd31f2f3c20e0e7370d762115 # v6.1.1`

## 2. Implementation Plan

### Phase 0: Composite Action

#### Commit 1: feat(ca-run-secretlint): add secretlint action and scan job (#209)

- `scripts/_libs/inputs.lib.sh` を新規作成する (`validate_secretlint_version`)
- `scripts/run-secretlint.sh` を新規作成する (`main`)
- `action.yml` を新規作成する
  - 入力 2 つ (`pnpm-version`、`secretlint-version`)、ステップ 2 つ (`setup-pnpm`、`Run secretlint`)
  - `INPUT_SECRETLINT_VERSION` は `env` 経由で渡す
  - `run: bash "${GITHUB_ACTION_PATH}/scripts/run-secretlint.sh"`
- テストを追加する
  - `scripts/__tests__/unit/inputs.unit.spec.sh` (VER)
  - `scripts/__tests__/unit/action.unit.spec.sh` (ACT)
  - `scripts/__tests__/functional/run-secretlint.functional.spec.sh` (RUN、`pnpm` をスタブに差し替える)

### Phase 1: ワークフロー

#### Commit 2: feat(ru-scan-secrets): add scan-secretlint job (#209)

- `ru-scan-secrets.yml` に `scan-secretlint` ジョブを追加する
  - `runs-on: ubuntu-slim`、`timeout-minutes: 10`、`permissions: contents: read`
  - `actions/checkout` (`fetch-depth: ${{ inputs.fetch-depth }}`、`persist-credentials: false`)
  - `ca-run-secretlint@v0.8.0-pre` に `pnpm-version` と `secretlint-version` を渡す
- ワークフローの入力 `secretlint-version` (既定 "14.0.1") と `pnpm-version` (既定 "") を追加する
- betterleaks のジョブとは `needs` で結ばない

## 3. Change History

<!-- バージョニングは deckrd-rule-document-versioning.md に従う。 -->

| Date       | Version | Description     |
| ---------- | ------- | --------------- |
| 2026-11-19 | 1.0.0   | Initial release |
