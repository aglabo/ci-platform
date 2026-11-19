---
title: "Requirements: ca-validate-environment"
module: "composite-action/validate-environment"
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

> **Normative Statement**
> This document defines binding requirements.
> Implementations MUST conform to this document.
> RFC 2119 keywords apply to this document only.

## 1. Overview

### 1.1 Purpose

ワークフローの実行環境が、後続の処理の前提を満たしているかを検証する公開 Composite Action `ca-validate-environment` を定める。
本書は、現行の実装 (v0.7.1) から導出した要件を記録する。

検証は 3 領域に分ける。

- ランナー: OS、アーキテクチャ、GitHub Actions の環境変数、GitHub-hosted の要否
- 権限: `GITHUB_TOKEN` の存在と、書き込み権限 (commit / pr) の有無
- アプリケーション: Git、curl と、呼び出し元が追加する任意のコマンド

### 1.2 Scope

- `.github/actions/ca-validate-environment/action.yml` の入力・出力・3 ステップ
- `scripts/validate-git-runner.sh`、`scripts/validate-permissions.sh`、`scripts/validate-apps.sh`
- 各ステップの出力 `status` / `message` と、ステップ出力から Action 出力への対応付け

**Out of Scope**:

- Windows と macOS のランナー (REQ-C-001)
- `id-token: write` (OIDC) の検証。`validate_id_token_permissions` は実装にあるが、本 Action では呼ばない
- トークンのスコープ一覧の取得
- ツールのインストール (`ca-setup-tool` / `ca-setup-repo` の責務)
- 共有ライブラリ `.github/actions/_libs/` の仕様

## 2. Context

- Target Environment: GitHub Actions (Composite Action)。Linux ランナー専用。
- Related Components:
  - `.github/actions/_libs/output.lib.sh` (`out_status`, `write_status`)
  - `.github/actions/_libs/env.lib.sh` (`check_env_var`)
  - 利用元: `ru-lint-documents` / `ru-qa-actionlint` / `ru-qa-actions-lock` / `ru-qa-ghalint` / `ru-scan-secrets` / `ci-publish-docs` / `_tests_ca_composite-actions`
- Assumptions:
  - 呼び出し元のジョブは `contents: read` を宣言している。
  - `curl` と `jq` が実行環境に存在する。GitHub-hosted の ubuntu ランナーには標準で入っている。

### System Context Diagram

```text
[Caller inputs] --> +----------------------------------------+
 architecture       | ca-validate-environment/action.yml     |
 actions-type       |  step 1: validate-git-runner.sh        | --> runner-status / runner-message
 additional-apps    |  step 2: validate-permissions.sh       | --> permissions-status / permissions-message
 require-github-    |  step 3: validate-apps.sh              | --> apps-status / apps-message
   hosted           +----------------------------------------+
 github-token                |             ^
                             v             |
                    [GitHub API: probe]   [_libs: output / env]
```

## 3. Design Decisions (Summary)

| ID    | Decision                                                 | Linked Record          |
| ----- | -------------------------------------------------------- | ---------------------- |
| DR-01 | 検証を 3 本のスクリプト・3 ステップに分ける              | ../decision-records.md |
| DR-02 | 対応 OS を Linux に限る                                  | ../decision-records.md |
| DR-03 | 書き込み権限は無効なペイロードのプローブで確認する       | ../decision-records.md |
| DR-04 | `read` では API 確認を行わない                           | ../decision-records.md |
| DR-05 | `require-github-hosted` の既定は Action では `false`     | ../decision-records.md |
| DR-06 | アプリケーション検証はフェイルファストにする             | ../decision-records.md |
| DR-07 | バージョン抽出は接頭辞付き抽出器と許可リストで安全化する | ../decision-records.md |
| DR-08 | 入力はすべて環境変数で渡す                               | ../decision-records.md |
| DR-09 | 追加アプリは最大 30 件に制限する                         | ../decision-records.md |
| DR-10 | 既定の検査対象は Git (2.30 以上) と curl とする          | ../decision-records.md |
| DR-11 | 共有ライブラリは `GITHUB_ACTION_PATH` からの相対で読む   | ../decision-records.md |

## 4. Functional Requirements

### REQ-F-001: 入力と既定値

- EARS Type: WHEN (event-driven)

```text
GIVEN ca-validate-environment が呼び出される
  WHEN 呼び出し元が入力を指定しない
THEN the system SHALL 次の既定値を使う.
  architecture = "amd64"
  actions-type = "read"
  additional-apps = ""
  require-github-hosted = "false"
  github-token = ${{ github.token }}
```

すべての入力は `required: false` とする。入力は `env:` 経由でスクリプトに渡し、`run:` に直接展開しない (DR-08)。

**Acceptance Criteria**:

| AC ID  | Scenario                                                |
| ------ | ------------------------------------------------------- |
| AC-001 | 入力を指定せず呼び出すと、既定値で 3 ステップが成功する |

### REQ-F-002: 出力

- EARS Type: UBIQUITOUS

```text
the system SHALL 次の 6 出力を公開する.
  runner-status / runner-message         <- steps.validate-runner.outputs.{status,message}
  permissions-status / permissions-message <- steps.validate-permissions.outputs.{status,message}
  apps-status / apps-message             <- steps.validate-apps.outputs.{status,message}
```

`status` は `success` または `error` とする。

**Acceptance Criteria**:

| AC ID  | Scenario                                              |
| ------ | ----------------------------------------------------- |
| AC-002 | 成功時に 6 出力すべてが設定される                     |
| AC-003 | ランナー検証が失敗すると、後続 2 領域の出力は空になる |

### REQ-F-003: ステップの順序

- EARS Type: UBIQUITOUS

```text
the system SHALL ステップを validate-runner, validate-permissions, validate-apps の順に実行する.
先行ステップが失敗した場合、後続ステップは実行されない.
```

**Rationale**: composite Action は、失敗したステップの後続を実行しない。Action 全体がゲートとして働く。

**Acceptance Criteria**:

| AC ID  | Scenario                                              |
| ------ | ----------------------------------------------------- |
| AC-003 | ランナー検証が失敗すると、後続 2 領域の出力は空になる |

### REQ-F-004: OS の検証

- EARS Type: WHEN (event-driven)

```text
GIVEN validate-git-runner.sh が実行される
  WHEN 小文字化した uname -s が "linux" でない
THEN the system SHALL ::error:: を出力し、status=error を書いて終了コード 1 で終了する.
```

**Acceptance Criteria**:

| AC ID  | Scenario               |
| ------ | ---------------------- |
| AC-004 | Linux 以外では失敗する |

### REQ-F-005: 期待アーキテクチャの検証

- EARS Type: WHEN (event-driven)

```text
GIVEN architecture 入力が渡される
  WHEN 値が "amd64" または "arm64" 以外である
THEN the system SHALL status=error を書いて終了コード 1 で終了する.
```

### REQ-F-006: 検出アーキテクチャの正規化と一致

- EARS Type: WHEN (event-driven)

```text
GIVEN uname -m の値が得られる
  WHEN 値を正規化する (x86_64, amd64, x64 -> amd64 / aarch64, arm64 -> arm64)
THEN the system SHALL 正規化できない値を "Unsupported architecture" として拒否し、
     正規化した値が architecture 入力と異なる場合は "Architecture mismatch" として拒否する.
```

**Acceptance Criteria**:

| AC ID  | Scenario                                                  |
| ------ | --------------------------------------------------------- |
| AC-005 | x86_64 は amd64 として、aarch64 は arm64 として受理される |
| AC-006 | 期待と異なるアーキテクチャでは失敗する                    |

### REQ-F-007: GitHub Actions 環境の検証

- EARS Type: WHEN (event-driven)

```text
GIVEN ランナー検証が OS とアーキテクチャの検証を通過した
  WHEN 環境変数 GITHUB_ACTIONS が "true" でない
THEN the system SHALL status=error を書いて終了コード 1 で終了する.
```

### REQ-F-008: GitHub-hosted ランナーの要求

- EARS Type: WHEN (event-driven)

```text
GIVEN REQUIRE_GITHUB_HOSTED が "true" である
  WHEN 環境変数 RUNNER_ENVIRONMENT が "github-hosted" でない
THEN the system SHALL status=error を書いて終了コード 1 で終了する.
```

`REQUIRE_GITHUB_HOSTED` が `"true"` 以外のときは、この検査を行わない。
判定は GitHub の仕様 (セルフホストでは `RUNNER_ENVIRONMENT` が設定されない) に依存する。

**Acceptance Criteria**:

| AC ID  | Scenario                                                 |
| ------ | -------------------------------------------------------- |
| AC-007 | `require-github-hosted: "true"` でセルフホストを拒否する |
| AC-008 | 既定 (`"false"`) ではセルフホストを受理する              |

### REQ-F-009: 実行時変数の検証

- EARS Type: WHEN (event-driven)

```text
GIVEN ランナー検証がここまで通過した
  WHEN RUNNER_TEMP, GITHUB_OUTPUT, GITHUB_PATH のいずれかが空または未設定である
THEN the system SHALL status=error を書いて終了コード 1 で終了する.
```

成功時は `status=success`、`message="GitHub runner validated: Linux <arch>"` を書く。

### REQ-F-010: actions-type の検証

- EARS Type: WHEN (event-driven)

```text
GIVEN validate-permissions.sh が実行される
  WHEN actions-type を小文字化した値が read, commit, pr, any のいずれでもない
THEN the system SHALL ::error:: を出力し、status=error を書いて終了コード 1 で終了する.
```

大文字小文字は区別しない。引数が無いときは環境変数 `ACTIONS_TYPE`、それも無いときは `read` を使う。

**Acceptance Criteria**:

| AC ID  | Scenario                            |
| ------ | ----------------------------------- |
| AC-009 | `COMMIT` は `commit` として扱われる |
| AC-010 | 未知の値は拒否される                |

### REQ-F-011: トークンの存在確認

- EARS Type: WHEN (event-driven)

```text
GIVEN actions-type が有効である
  WHEN 環境変数 GITHUB_TOKEN が空または未設定である
THEN the system SHALL status=error を書いて終了コード 1 で終了する.
```

4 つの `actions-type` すべてで、最初にこの確認を行う。

### REQ-F-012: commit 権限のプローブ

- EARS Type: WHEN (event-driven)

```text
GIVEN actions-type が "commit" である
  WHEN POST /repos/{owner}/{repo}/git/refs に無効な SHA (全ゼロ) を送り、応答が 403 である
THEN the system SHALL status=error, message="Missing commit permissions: contents: write" を書いて終了コード 1 で終了する.
```

応答が 201 / 409 / 422 のときは権限ありと判定する。401、curl の失敗 (`000`)、その他の応答はエラーとする。

**Acceptance Criteria**:

| AC ID  | Scenario                         |
| ------ | -------------------------------- |
| AC-011 | 422 応答を権限ありとして受理する |
| AC-012 | 403 応答を権限なしとして拒否する |

### REQ-F-013: pr 権限のプローブ

- EARS Type: WHEN (event-driven)

```text
GIVEN actions-type が "pr" である
  WHEN POST /repos/{owner}/{repo}/pulls に無効な head を送り、応答が 403 である
THEN the system SHALL status=error, message="Missing PR permissions: pull-requests: write" を書いて終了コード 1 で終了する.
```

base ブランチは `GITHUB_BASE_REF`、無ければ `GITHUB_REF_NAME` から決める。どちらも無いときはエラーとする。
応答の判定は REQ-F-012 と同じ。

### REQ-F-014: read と any の扱い

- EARS Type: WHEN (event-driven)

```text
GIVEN actions-type が "read" または "any" である
  WHEN トークンが存在する
THEN the system SHALL API を呼ばずに status=success, message="GitHub permissions validated" を書く.
```

`read` では `contents: read` を `permissions` に明示するよう促すメッセージを標準出力に出す (DR-04)。

### REQ-F-015: 既定のアプリケーション検証

- EARS Type: UBIQUITOUS

```text
the system SHALL 常に Git (2.30 以上、3 番目のフィールドから抽出) と curl (バージョン検査なし) を検査する.
```

**Acceptance Criteria**:

| AC ID  | Scenario                                    |
| ------ | ------------------------------------------- |
| AC-013 | 追加アプリが無くても Git と curl を検査する |

### REQ-F-016: additional-apps の書式

- EARS Type: WHEN (event-driven)

```text
GIVEN additional-apps が標準入力として渡される
  WHEN 行が cmd|app_name または cmd|app_name|extractor|min_version の 2 / 4 フィールドでない
THEN the system SHALL ::error:: を出力して失敗する.
```

`#` 以降は行内コメントとして除去し、前後の空白を除く。空行は無視する。
`cmd` は、制御文字・相対パス (`./`, `../`)・シェルメタ文字 (セミコロン、パイプ、アンパサンド、ドル記号、バッククォート、括弧、`*`、`?`、波括弧) と空白を含んではならない。
`app_name` は、改行・CR・タブを含んではならない。

### REQ-F-017: バージョン抽出

- EARS Type: WHEN (event-driven)

```text
GIVEN min_version が指定されている
  WHEN extractor が field:N, regex:PATTERN, auto (空) のいずれかである
THEN the system SHALL --version の 1 行目から版を取り出す.
```

- `field:N`: 空白区切りの N 番目のフィールド。N は数字のみ
- `regex:PATTERN`: 最初のキャプチャグループ。パターンは `is_safe_regex` で検査する (DR-07)
- 空 / `auto`: 最初に現れる `X.Y` または `X.Y.Z`
- 上記以外の方式はエラーとする

**Acceptance Criteria**:

| AC ID  | Scenario                                             |
| ------ | ---------------------------------------------------- |
| AC-014 | `git version 2.52.0` から `field:3` で 2.52.0 を得る |
| AC-015 | 危険なパターンは拒否される                           |

### REQ-F-018: 最小バージョンの比較

- EARS Type: WHEN (event-driven)

```text
GIVEN 版が抽出された
  WHEN sort -V で比べて版が min_version 未満である
THEN the system SHALL "<app> version <v> is below minimum required <min>" を出力して失敗する.
```

`min_version` が空のときは比較を省略し、警告 (`::warning::`) を出して成功とする。

### REQ-F-019: gh の認証確認

- EARS Type: WHEN (event-driven)

```text
GIVEN 検査対象のコマンド名 (basename) が "gh" である
  WHEN gh auth status が失敗する
THEN the system SHALL "<app> is not authenticated" を出力して失敗する.
```

`gh` 以外のコマンドには追加の検査を行わない。

### REQ-F-020: アプリ件数の上限

- EARS Type: WHEN (event-driven)

```text
GIVEN 既定アプリと標準入力のアプリを合わせる
  WHEN 件数が 30 を超える
THEN the system SHALL "Too many apps specified (max: 30)" を出力して失敗する.
```

### REQ-F-021: アプリ検証の成功出力

- EARS Type: WHEN (event-driven)

```text
GIVEN すべてのアプリが検証を通過した
THEN the system SHALL status=success と、"Applications validated:" に続けて各アプリの
     `<app> <version>` を 2 スペースで字下げして 1 行ずつ並べた message を書く.
```

`message` は複数行の出力形式 (`message<<MULTILINE_EOF`) で書く。

### REQ-F-022: 失敗時の挙動

- EARS Type: WHEN (event-driven)

```text
GIVEN 検証ループでいずれかのアプリが失敗した
THEN the system SHALL 最初の失敗で status=error と原因を書き、残りのアプリを検証せずに終了コード 1 で終了する.
```

## 5. Non-Functional Requirements

### REQ-NF-001: インジェクション耐性

- `eval` を使わない。
- `action.yml` の `run:` に `${{ }}` を展開しない。
- 抽出器は接頭辞付きの 3 方式に限り、正規表現は許可リストで検査する。

### REQ-NF-002: 副作用なし

権限のプローブは、リポジトリにリソースを作ってはならない。無効なペイロードで必ず検証エラーになるようにする。

### REQ-NF-003: トークンの秘匿

`GITHUB_TOKEN` の値をログに出力してはならない。

### REQ-NF-004: テスト階層

各スクリプトは unit / functional / integration / e2e の 4 階層でテストする (スペックファイルは `scripts/__tests__/<script>/<tier>/` に置く)。

## 6. Constraints

### REQ-C-001: Linux 専用

Linux ランナー (ubuntu 系) だけを対象とする。Windows と macOS は対象外とする (DR-02)。

### REQ-C-002: 外部コマンド

権限検証には `curl`、アプリ検証には `jq` と GNU coreutils の `sort -V` が必要である。
`curl` が無いときは `validate-permissions.sh` が、`jq` が無いときは `validate-apps.sh` が終了コード 1 で失敗する。

### REQ-C-003: サードパーティ Action を使わない

`uses:` で外部の Action を呼ばない。`run:` のみで構成する。

### REQ-C-004: 共有ライブラリの解決

共有ライブラリは `${GITHUB_ACTION_PATH}/../_libs` から読む。`GITHUB_ACTION_PATH` が空のときは `${SHELLSPEC_PROJECT_ROOT}/.github/actions/_libs` を使う (DR-11)。

## 7. User Stories

| Story ID | Role             | Goal                                         | Reason                           | Related Requirements |
| -------- | ---------------- | -------------------------------------------- | -------------------------------- | -------------------- |
| US-001   | ワークフロー作者 | ジョブの先頭で環境を検証する                 | 後続の失敗を原因の近くで知りたい | REQ-F-001..009       |
| US-002   | ワークフロー作者 | 書き込み権限が足りないことを早く知る         | 途中で 403 になるのを避けたい    | REQ-F-010..014       |
| US-003   | ワークフロー作者 | 必要なコマンドとバージョンを宣言して検査する | 古いツールによる不具合を避けたい | REQ-F-015..022       |

## 8. Acceptance Criteria

```gherkin
# AC-001: 既定値で成功する
# Requirement: REQ-F-001
Scenario: 入力なしで呼び出す
  Given Linux の amd64 ランナーである
  When 入力を指定せず ca-validate-environment を実行する
  Then runner-status, permissions-status, apps-status はすべて "success" である

# AC-003: 先行失敗で後続が実行されない
# Requirement: REQ-F-002, REQ-F-003
Scenario: ランナー検証の失敗
  Given architecture に実機と異なる値を指定する
  When ca-validate-environment を実行する
  Then runner-status は "error" である
  And permissions-status と apps-status は空である

# AC-007: GitHub-hosted の要求
# Requirement: REQ-F-008
Scenario: セルフホストの拒否
  Given RUNNER_ENVIRONMENT が設定されていない
  When require-github-hosted を "true" にして実行する
  Then runner-status は "error" である

# AC-012: 書き込み権限の不足
# Requirement: REQ-F-012
Scenario: commit 権限なし
  Given contents: read のみのトークンである
  When actions-type を "commit" にして実行する
  Then permissions-status は "error" である

# AC-014: バージョン抽出
# Requirement: REQ-F-017, REQ-F-018
Scenario: Git の版を検査する
  Given git --version が "git version 2.52.0" を返す
  When 既定の Git 検査を実行する
  Then apps-message に "Git 2.52.0" が含まれる
```

## 9. Open Questions

実装を読んで見つけた、仕様として確定していない項目を記録する。いずれもコードは変更しない。

| ID    | Question                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | Type        | Impact Area | Owner |
| ----- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- | ----------- | ----- |
| OQ-01 | `validate-permissions.sh` の `github_api_post` は `curl -w "%{http_status}"` を使う。curl の書式変数は `http_code` で、`http_status` は未知の変数である。curl 8.23.0 では `unknown --write-out variable` と報告され、標準出力は空になった (確認日 2026-11-19)。この場合 `commit` / `pr` はすべて "Unexpected HTTP response" で失敗する。テストは `github_api_post` を差し替えており、この書式を検証していない。REQ-F-012 / REQ-F-013 の意図 (403 は拒否、201 / 409 / 422 は受理) とは異なる動きになりうる | Observation | permissions | -     |
| OQ-02 | `probe_github_write_permission` は `local owner_repo="${GITHUB_REPOSITORY}"` を `set -u` 下で参照する。未設定だと、直後の空文字検査に至る前に "unbound variable" で終了する                                                                                                                                                                                                                                                                                                                               | Observation | permissions | -     |
| OQ-03 | `validate-apps.sh` の冒頭コメントは `gh` を既定の検査対象と書くが、`main` の既定アプリは Git と curl だけである (DR-10)                                                                                                                                                                                                                                                                                                                                                                                   | Observation | apps        | -     |
| OQ-04 | `validate-git-runner.sh` 単体の `REQUIRE_GITHUB_HOSTED` 既定値は `true`、`action.yml` の既定値は `"false"` で、食い違う (DR-05)                                                                                                                                                                                                                                                                                                                                                                           | Observation | runner      | -     |
| OQ-05 | `validate-apps.sh` は `jq` が無いとき、または件数超過・書式不正のとき、`status` / `message` を出力せずに終了する。`apps-status` が空になり、`error` にならない                                                                                                                                                                                                                                                                                                                                            | Observation | apps        | -     |
| OQ-06 | `action.yml` の `# src:` ヘッダーは `./.github/actions/validate-environment/action.yml` のままで、`ca-` 接頭辞を欠く。`permissions-message` の説明は "empty if not checked" だが、`any` / `read` でも成功メッセージを書く                                                                                                                                                                                                                                                                                 | Observation | action.yml  | -     |
| OQ-07 | 既存のスペックファイルにテスト ID (`T-VEN-...`) が無く、`action.yml` の静的検査 (`ACT`) のスペックも無い。ID の付与は別タスクとする                                                                                                                                                                                                                                                                                                                                                                       | Observation | tests       | -     |

## 10. Traceability

| REQ ID     | AC IDs         | Type           |
| ---------- | -------------- | -------------- |
| REQ-F-001  | AC-001         | Functional     |
| REQ-F-002  | AC-002, AC-003 | Functional     |
| REQ-F-003  | AC-003         | Functional     |
| REQ-F-004  | AC-004         | Functional     |
| REQ-F-005  | AC-006         | Functional     |
| REQ-F-006  | AC-005, AC-006 | Functional     |
| REQ-F-007  | AC-001         | Functional     |
| REQ-F-008  | AC-007, AC-008 | Functional     |
| REQ-F-009  | AC-001         | Functional     |
| REQ-F-010  | AC-009, AC-010 | Functional     |
| REQ-F-011  | AC-012         | Functional     |
| REQ-F-012  | AC-011, AC-012 | Functional     |
| REQ-F-013  | AC-011, AC-012 | Functional     |
| REQ-F-014  | AC-001         | Functional     |
| REQ-F-015  | AC-013         | Functional     |
| REQ-F-016  | AC-015         | Functional     |
| REQ-F-017  | AC-014, AC-015 | Functional     |
| REQ-F-018  | AC-014         | Functional     |
| REQ-F-019  | AC-013         | Functional     |
| REQ-F-020  | AC-013         | Functional     |
| REQ-F-021  | AC-014         | Functional     |
| REQ-F-022  | AC-014         | Functional     |
| REQ-NF-001 | AC-015         | Non-Functional |
| REQ-NF-002 | AC-011         | Non-Functional |

## 11. Change History

| Date       | Version | Description                                              |
| ---------- | ------- | -------------------------------------------------------- |
| 2026-11-19 | 1.0.0   | Initial release: REQ-F-001..022 derived from v0.7.1 code |
