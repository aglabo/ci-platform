---
title: "Design Specification: ca-validate-environment (Index)"
based-on: requirements.md v1.0.0
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

> Part of split specification. See `specifications-index.md` for full scope.

## 1. Overview

### 1.1 Purpose

本書は、`ca-validate-environment` 仕様の分割ファイル群の入口とする。
全体の概要、分割ファイルの一覧、共有インターフェース、共有規約を定義する。
領域ごとの詳細な振る舞いは、各分割ファイルで定義し、本書では再掲しない。

### 1.2 Scope

3 領域 (ランナー、権限、アプリケーション) の振る舞い規則のうち、複数の分割ファイルが共有する部分を定義する。
実装の詳細は対象外とする。

### 1.3 Split Files

| File                                                             | Covered REQ                                                                            | Summary                                                     |
| ---------------------------------------------------------------- | -------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| [specifications-runner.md](./specifications-runner.md)           | REQ-F-004, REQ-F-005, REQ-F-006, REQ-F-007, REQ-F-008, REQ-F-009                       | OS、アーキテクチャ、GitHub Actions 環境、実行時変数の検証   |
| [specifications-permissions.md](./specifications-permissions.md) | REQ-F-010, REQ-F-011, REQ-F-012, REQ-F-013, REQ-F-014                                  | actions-type の検証、トークンの存在、書き込み権限のプローブ |
| [specifications-apps.md](./specifications-apps.md)               | REQ-F-015, REQ-F-016, REQ-F-017, REQ-F-018, REQ-F-019, REQ-F-020, REQ-F-021, REQ-F-022 | アプリ定義の検証、版の抽出と比較、出力                      |

REQ-F-001 ～ REQ-F-003 (入力・出力・ステップ順) は、本書の 3.1 ～ 3.3 で定義する。

### 1.4 ID Conventions

| 種別     | 書式        | 定義する分割ファイル          |
| -------- | ----------- | ----------------------------- |
| 判定規則 | `R-RUN-NNN` | specifications-runner.md      |
| 判定規則 | `R-PRM-NNN` | specifications-permissions.md |
| 判定規則 | `R-APP-NNN` | specifications-apps.md        |
| 設計判断 | `DD-IDX-NN` | 本書                          |
| 設計判断 | `DD-RUN-NN` | specifications-runner.md      |
| 設計判断 | `DD-PRM-NN` | specifications-permissions.md |
| 設計判断 | `DD-APP-NN` | specifications-apps.md        |

ID は分割ファイルをまたいで一意とし、廃止した ID は再利用しない。

---

## 2. Design Principles

### 2.1 Classification Philosophy

本 Action はゲートとして働く。検証に失敗した時点で、その領域の `status` を `error` にして終了し、後続の処理を行わない。
検証できないものを、検証できたかのように扱わない (DR-04)。

### 2.2 Design Assumptions

- ランナーは Linux である。
- 呼び出し元は `contents: read` 以外の権限を、必要な `actions-type` に応じて宣言している。
- `curl` と `jq` が存在する (REQ-C-002)。
- 共有ライブラリ `output.lib.sh` / `env.lib.sh` が読み込める (DR-11)。

### 2.3 External Design Summary

#### Feature Decomposition

| Unit                 | Responsibility                                     | REQ Coverage        |
| -------------------- | -------------------------------------------------- | ------------------- |
| action-interface     | 入力の受け取り、ステップの順序、出力の対応付け     | REQ-F-001, 002, 003 |
| runner-validation    | OS・アーキテクチャ・環境変数の検証                 | REQ-F-004 ～ 009    |
| permission-probe     | actions-type に応じたトークンと書き込み権限の検証  | REQ-F-010 ～ 014    |
| application-checking | アプリ定義の検証、存在・版・認証の確認、結果の出力 | REQ-F-015 ～ 022    |

#### Unit Interaction Map

```text
+------------------+    +-----------------------+    +----------------------+
| runner-validation| -> | permission-probe      | -> | application-checking |
+------------------+    +-----------------------+    +----------------------+
        |                        |                              |
        v                        v                              v
  steps.validate-runner   steps.validate-permissions     steps.validate-apps
        \                        |                              /
         +-----------> action-interface (outputs) <-------------+
```

先行ユニットが失敗した場合は、後続のユニットを呼び出さずに終了する。

### 2.4 Non-Goals

- Windows / macOS ランナー ← REQ: Out of Scope
- OIDC (`id-token: write`) の検証。`validate_id_token_permissions` は実装にあるが、本 Action では呼ばない
- トークンのスコープ一覧の取得
- ツールのインストール

### 2.5 Behavioral Design Decisions

| ID        | Decision                                                                                         | Rationale                          |
| --------- | ------------------------------------------------------------------------------------------------ | ---------------------------------- |
| DD-IDX-01 | 各スクリプトは `status` / `message` を `$GITHUB_OUTPUT` に書く。ファイルが無いときは `/dev/null` | 単体実行でもスクリプトが失敗しない |
| DD-IDX-02 | スクリプトは `BASH_SOURCE` と `$0` が一致するときだけ実行する。読み込み (source) では実行しない  | テストで関数を個別に呼べる         |
| DD-IDX-03 | エラーは `::error::` を標準エラーに出し、同時に `status=error` を書く                            | ログと出力の両方に原因が残る       |

### 2.6 Related Decision Records

DR-01, DR-02, DR-05, DR-08, DR-11 (ファイル全体)。領域ごとの DR は各分割ファイルを参照する。

### 2.7 DD to DR Promotion Criteria

複数の領域に影響する設計判断になった DD は、DR に昇格する。

---

## 3. Behavioral Specification

### 3.1 Input Domain (REQ-F-001)

| Input                   | Type   | Default               | Env 変数                       | 渡し先のスクリプト      |
| ----------------------- | ------ | --------------------- | ------------------------------ | ----------------------- |
| `architecture`          | string | `"amd64"`             | `EXPECTED_ARCHITECTURE`        | validate-git-runner.sh  |
| `require-github-hosted` | string | `"false"`             | `REQUIRE_GITHUB_HOSTED`        | validate-git-runner.sh  |
| `actions-type`          | string | `"read"`              | `ACTIONS_TYPE` (引数にも渡す)  | validate-permissions.sh |
| `github-token`          | string | `${{ github.token }}` | `GITHUB_TOKEN`                 | validate-permissions.sh |
| `additional-apps`       | string | `""`                  | `ADDITIONAL_APPS` (標準入力へ) | validate-apps.sh        |

`additional-apps` は `printf '%s\n' "$ADDITIONAL_APPS"` でパイプし、標準入力として渡す。

### 3.2 Output Semantics (REQ-F-002)

| Action output         | 元のステップ出力                             | 値                                   |
| --------------------- | -------------------------------------------- | ------------------------------------ |
| `runner-status`       | `steps.validate-runner.outputs.status`       | `success` / `error`                  |
| `runner-message`      | `steps.validate-runner.outputs.message`      | 要約または原因                       |
| `permissions-status`  | `steps.validate-permissions.outputs.status`  | `success` / `error`                  |
| `permissions-message` | `steps.validate-permissions.outputs.message` | 要約または原因                       |
| `apps-status`         | `steps.validate-apps.outputs.status`         | `success` / `error`                  |
| `apps-message`        | `steps.validate-apps.outputs.message`        | 複数行 (成功時は版の一覧) または原因 |

### 3.3 Step Order (REQ-F-003)

1. `validate-runner` (`bash "${GITHUB_ACTION_PATH}/scripts/validate-git-runner.sh"`)
2. `validate-permissions` (`bash "${GITHUB_ACTION_PATH}/scripts/validate-permissions.sh" "$ACTIONS_TYPE"`)
3. `validate-apps` (`printf '%s\n' "$ADDITIONAL_APPS" | bash "${GITHUB_ACTION_PATH}/scripts/validate-apps.sh"`)

各ステップは `set -euo pipefail` で始める。いずれかが非ゼロで終了すると、後続は実行されない。

### 3.4 External Dependencies

| 依存                  | 用途                             |
| --------------------- | -------------------------------- |
| `_libs/output.lib.sh` | `out_status`, `write_status`     |
| `_libs/env.lib.sh`    | `check_env_var`                  |
| `curl`                | GitHub API の呼び出し            |
| `jq`                  | アプリ検証結果の JSON 組み立て   |
| `sort -V`             | 版の比較                         |
| `gh` (任意)           | `additional-apps` に指定した場合 |

### 3.5 Function List

| 領域        | 関数                                                                                                                                                                                                                                                                                                                                                            |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| runner      | `detect_os`, `detect_architecture`, `normalize_architecture`, `validate_os`, `validate_expected_arch`, `is_supported_architecture`, `validate_arch_match`, `validate_github_actions_env`, `validate_github_hosted_runner`, `validate_runtime_variables`, `validate_git_runner`                                                                                  |
| permissions | `check_curl`, `determine_base_branch`, `github_api_post`, `probe_github_write_permission`, `validate_id_token_permissions` (未使用), `check_github_token`, `validate_permissions`                                                                                                                                                                               |
| apps        | `is_safe_regex`, `extract_version_by_regex`, `extract_version_number`, `check_version`, `get_app_version`, `is_safe_command`, `validate_app_format`, `validate_app_exists`, `validate_app_version`, `validate_app_special`, `check_jq`, `check_gh_authentication`, `handle_validation_error`, `initialize_apps_list`, `output_success`, `validate_apps`, `main` |

## 4. Decision Rules

action-interface の規則を示す。領域ごとの規則は各分割ファイルを参照する。

| Rule ID   | Step | Condition          | Outcome                                              |
| --------- | ---- | ------------------ | ---------------------------------------------------- |
| R-IDX-001 | 1    | 入力が未指定である | 3.1 の既定値を使う (REQ-F-001)                       |
| R-IDX-002 | 2    | ステップが成功する | そのステップの `status=success` が Action 出力に出る |
| R-IDX-003 | 3    | ステップが失敗する | 後続ステップは実行されず、後続の出力は空になる       |

評価は上記の順序で行う。順序の入れ替えは許さない。

## 5. Edge Cases

| Input                               | Classification | REQ       | Rationale                                             |
| ----------------------------------- | -------------- | --------- | ----------------------------------------------------- |
| `additional-apps` が空              | 正常           | REQ-F-001 | 標準入力は空になり、既定の 2 アプリだけを検査する     |
| `GITHUB_OUTPUT` が未設定 (単体実行) | 正常           | REQ-F-002 | 出力は `/dev/null` に捨てられ、スクリプトは失敗しない |
| 先行ステップの失敗                  | エラー         | REQ-F-003 | 後続の出力は空 (OQ-05 も参照)                         |

## 6. Requirements Traceability

| REQ ID           | 定義する節 / ファイル         |
| ---------------- | ----------------------------- |
| REQ-F-001 ～ 003 | 本書 3.1 ～ 3.3               |
| REQ-F-004 ～ 009 | specifications-runner.md      |
| REQ-F-010 ～ 014 | specifications-permissions.md |
| REQ-F-015 ～ 022 | specifications-apps.md        |

## 7. Open Questions

OQ-01 ～ OQ-07 は requirements.md の 9 節に記録する。仕様は、記録した観察を意図した挙動としては扱わない。

## 8. Change History

| Date       | Version | Description                                   |
| ---------- | ------- | --------------------------------------------- |
| 2026-11-19 | 1.0.0   | Initial release: index and shared conventions |
