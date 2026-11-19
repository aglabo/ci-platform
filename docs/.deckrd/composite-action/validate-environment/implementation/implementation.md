---
title: "Implementation Plan: ca-validate-environment"
based-on: specifications-index.md v1.0.0
status: Draft
version: 1.0.0
created: "2026-11-19"
---

<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/max-comma,
  ja-technical-writing/no-doubled-joshi,
  ja-technical-writing/no-mix-dearu-desumasu,
  ja-technical-writing/ja-no-redundant-expression,
  @textlint-ja/no-synonyms
  -->
<!-- markdownlint-disable line-length -->

## 1. Overview

### 1.1 Purpose

`ca-validate-environment` の実装を、コミット単位に分けて記録する。
本書は現行の実装 (v0.7.1) から導出した。各コミットは、すでに実装済みの内容を表す。

### 1.2 Reference

- requirements.md v1.0.0
- specifications-index.md v1.0.0 / specifications-runner.md v1.0.0 / specifications-permissions.md v1.0.0 / specifications-apps.md v1.0.0
- decision-records.md v1.0.0

### 1.3 Design Decisions

| 領域        | 単位                      | 場所                                                 |
| ----------- | ------------------------- | ---------------------------------------------------- |
| action      | 入力・出力・3 ステップ    | `.github/actions/ca-validate-environment/action.yml` |
| runner      | `validate-git-runner.sh`  | `.github/actions/ca-validate-environment/scripts/`   |
| permissions | `validate-permissions.sh` | 同上                                                 |
| apps        | `validate-apps.sh`        | 同上                                                 |
| tests       | 3 スクリプト × 4 階層     | `scripts/__tests__/<script>/<tier>/*.spec.sh`        |

## 2. Implementation Plan

### Phase 0: Preparation (Documents)

#### Commit 1: docs(ca/validate-environment): declare module ownership and design

- `workspaces/module/module.md` に `test_scope: VEN` と `owns` を宣言する。
- requirements / specifications / decision-records を追加する。

### Phase 1: runner

#### Commit 2: feat(ca/validate-environment): add validate-git-runner

- `scripts/validate-git-runner.sh`: `detect_os`, `detect_architecture`, `normalize_architecture`, `validate_os`, `validate_expected_arch`, `is_supported_architecture`, `validate_arch_match`, `validate_github_actions_env`, `validate_github_hosted_runner`, `validate_runtime_variables`, `validate_git_runner`。
- 共有ライブラリ `output.lib.sh` / `env.lib.sh` を `GITHUB_ACTION_PATH/../_libs` から読む (DR-11)。
- `BASH_SOURCE == $0` のときだけ実行する (DD-IDX-02)。
- 検証順は R-RUN-001 ～ 008 のとおりとする。

### Phase 2: permissions

#### Commit 3: feat(ca/validate-environment): add validate-permissions

- `scripts/validate-permissions.sh`: `check_curl`, `determine_base_branch`, `github_api_post`, `probe_github_write_permission`, `validate_id_token_permissions` (未使用), `check_github_token`, `validate_permissions`。
- プローブは `commit` が `git/refs`、`pr` が `pulls` への POST とする (DR-03)。
- `read` と `any` は API を呼ばない (DR-04)。
- 注意: `github_api_post` の `curl -w` 書式は OQ-01 を参照。

### Phase 3: apps

#### Commit 4: feat(ca/validate-environment): add validate-apps

- `scripts/validate-apps.sh`: 抽出 (`is_safe_regex`, `extract_version_by_regex`, `extract_version_number`, `check_version`, `get_app_version`)、検証 (`is_safe_command`, `validate_app_format`, `validate_app_exists`, `validate_app_version`, `validate_app_special`, `check_jq`, `check_gh_authentication`, `handle_validation_error`)、初期化 (`initialize_apps_list`)、出力 (`output_success`)、制御 (`validate_apps`, `main`)。
- `MAX_APPS=30` (DR-09)、既定アプリは Git と curl (DR-10)。
- `eval` を使わない (DR-07)。

### Phase 4: action

#### Commit 5: feat(ca/validate-environment): add composite action

- `action.yml`: 5 入力、6 出力、3 ステップ (`validate-runner`, `validate-permissions`, `validate-apps`)。
- すべての入力を `env:` で渡し、`run:` に `${{ }}` を展開しない (DR-08)。
- ヘッダーに `# @version : 0.7.1` を持つ (リリース作業 #212 で追加)。

### Phase 5: tests

#### Commit 6: test(ca/validate-environment): add specs per script and tier

- `scripts/__tests__/validate-git-runner/{unit,functional,integration,e2e}`
- `scripts/__tests__/validate-permissions/{unit,functional,integration,e2e}`
- `scripts/__tests__/validate-apps/{unit,functional,integration,e2e}`
- スペックファイルは既存のものを変更しない。テスト ID の付与とギャップの解消は別タスクとする (OQ-07)。

## 3. Change History

<!-- version: 内容が変わる追加は MINOR、明確化は PATCH (deckrd-rule-document-versioning) -->

| Date       | Version | Description                                      |
| ---------- | ------- | ------------------------------------------------ |
| 2026-11-19 | 1.0.0   | Initial release: implementation plan from v0.7.1 |
