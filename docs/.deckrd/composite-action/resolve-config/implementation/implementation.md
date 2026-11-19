---
title: "Implementation Plan: _ca-resolve-config"
based-on: specifications.md v1.0.0
status: Draft
version: 1.0.0
created: "2026-11-19"
---

## 1. Overview

### 1.1 Purpose

内部 Composite Action `.github/actions/_ca-resolve-config/` を実装する。
探索順と判定規則は specifications.md §4 に従う。

本書は、すでに実装済みのコード (PR #215、#216) に合わせて書いた。
実装済みの状態を、コミットの単位に分けて記録する。

完了条件は次のとおりとする。

- ShellSpec の全テストに `not ok` が無い
- `pnpm lint:sh` (shellcheck) と `pnpm check:sh` (shfmt) を通過する
- actionlint / ghalint を通過する
- CI の `test-resolve-config` ジョブが成功する

**実装品質基準 (全コミット共通):**

- 各コミットの中で BDD の RGR サイクルを回す。テストとその実装は同じコミットに含める。
- テスト ID は `T-RC-<略語>-<番号>` とする。ケース名には `[Normal]` / `[Error]` / `[Edge]` を付ける。
- テストの実行は `runners/run-shellspec.sh` 経由で行う。
- 内部シンボルは先頭アンダースコアで区別する (`_rc_try`、`_rc_resolve`、`_RC_COMMON_LIB_DIR`)。
- スクリプトは `set -euo pipefail` とし、`main` は実行時だけ呼ぶ (`if ! (return 0 2> /dev/null)`)。

### 1.2 Reference

- Specifications: specifications.md v1.0.0
- Decision Records: DR-01〜DR-06
- Issue #213、PR #215 (Action の新設)、PR #216 (`validate_path` の追加)

### 1.3 Design Decisions

| 単位                  | 略語 | 配置                                                                     |
| --------------------- | ---- | ------------------------------------------------------------------------ |
| 設定ファイルの解決    | RC   | `.github/actions/_ca-resolve-config/scripts/_libs/resolve-config.lib.sh` |
| エントリポイント      | -    | `.github/actions/_ca-resolve-config/scripts/resolve-config.sh`           |
| action.yml の静的検査 | ACT  | `.github/actions/_ca-resolve-config/action.yml`                          |
| パス検査 (共有)       | -    | `.github/actions/_libs/path.lib.sh` (`validate_path`)                    |

**関数ごとの実装上の詳細:**

- `resolve_config`: 戻り値は 0 / 1 だけとする。内部の `_rc_try` が返す 2 (不在) は、ここで 1 に変えるか、次の候補へ進む。
- `_rc_resolve`: `validate_path "$1" "$2" "$GITHUB_WORKSPACE"` を呼ぶだけの薄い関数とする。
- `_rc_try`: 空は 2、`validate_path` の失敗は 1、通常ファイルでなければ 2、採用は 0 とする。
- `main`: `read -r _path _source <<< "$_result"` で分割する。`GITHUB_OUTPUT` の書き出しは、解決の成功後に行う。
- ライブラリのロードガードは `RESOLVE_CONFIG_LIB_LOADED`、共有ライブラリ `path.lib.sh` は `PATH_LIB_LOADED` で守る。
- `_RC_COMMON_LIB_DIR` は `BASH_SOURCE` から求めた `.github/actions/_libs` とする。

## 2. Implementation Plan

### Phase 0: Composite Action

#### Commit 1: feat(composite-actions): add _ca-resolve-config for config resolution (#215)

- `scripts/_libs/resolve-config.lib.sh` を新規作成する (`resolve_config`、`_rc_try`、`_rc_resolve`)
- `scripts/resolve-config.sh` を新規作成する (`main`)
- `action.yml` を新規作成する
  - 入力 3 つ、出力 2 つ、ステップ 1 つ (`id: resolve-config`)
  - 入力と `GITHUB_WORKSPACE` は `env` 経由で渡す
  - `run: bash "${GITHUB_ACTION_PATH}/scripts/resolve-config.sh"`
- テストを追加する
  - `scripts/_libs/__tests__/unit/resolve-config.unit.spec.sh` (RC)
  - `scripts/__tests__/unit/action.unit.spec.sh` (ACT)
  - `scripts/__tests__/functional/resolve-config.functional.spec.sh` (01〜05)

### Phase 1: ワークフローと CI

#### Commit 2: feat(workflows): resolve tool configs via _ca-resolve-config (#213)

- 次のワークフローに `config-checkout` の後ろのステップ `resolve-config` を追加する
  - `ru-lint-documents` (textlint: `configs/textlintrc.yaml`、markdownlint: `configs/.markdownlint-cli2.yaml`)
  - `ru-qa-actionlint` (`configs/jactionlint.yaml`)
  - `ru-qa-ghalint` (`configs/ghalint.yaml`)
  - `ru-scan-secrets` (betterleaks: `configs/betterleaks.toml`)
- `global-config` は `global/configs/<同名>` とする
- ツールの実行ステップは `steps.resolve-config.outputs.config-file` を `CONFIG_FILE` に受け取る
- `.github/workflows/_tests_ca_composite-actions.yml` に `test-resolve-config` ジョブを追加する
  - 空のフィクスチャで input / local / global / 入力不在 / `..` / 候補なしを実行する
  - エラー系は `continue-on-error` で受ける

### Phase 2: パス検査の共有化

#### Commit 3: feat(_libs): add validate_path for root-confined path validation (#216)

- `.github/actions/_libs/path.lib.sh` を新規作成する
- `validate_path <target> <value> <root>` を実装する (specifications.md R-VAL-001..006)
- テストは `_libs/__tests__/unit/path.unit.spec.sh` (`test_scope: PA`、本モジュールの所有ではない)

#### Commit 4: refactor(_ca-resolve-config): delegate path checks to validate_path (#216)

- `resolve-config.lib.sh` の独自のパス検査を `validate_path` の呼び出しに置き換える
- symlink 経由の脱出を扱うケース (T-RC-RC-0208〜0212、0306〜0308) は、`validate_path` の realpath 検査で成り立つ

## 3. Change History

<!-- バージョニングは deckrd-rule-document-versioning.md に従う。 -->

| Date       | Version | Description     |
| ---------- | ------- | --------------- |
| 2026-11-19 | 1.0.0   | Initial release |
