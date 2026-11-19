---
title: "Requirements: ca-run-secretlint"
module: "composite-action/run-secretlint"
status: Draft
version: 1.0.0
created: "2026-11-19"
---

> **Normative Statement**
> This document defines binding requirements.
> Implementations MUST conform to this document.
> RFC 2119 keywords apply to this document only.

## 1. Overview

### 1.1 Purpose

secretlint によるシークレット検査を、公開 Composite Action `.github/actions/ca-run-secretlint/` として提供する (PR #209)。
呼び出し元は、チェックアウト済みのリポジトリに対して、この Action を 1 ステップで実行できる。

secretlint v14 以降は設定を同梱する。このため、本 Action は設定ファイルを受け取らない。
バージョンは入力で指定し、`pnpm dlx` で実行する。

### 1.2 Scope

- `.github/actions/ca-run-secretlint/` Composite Action
- 入力 `pnpm-version` (default "") / `secretlint-version` (default "14.0.1")
- pnpm のセットアップ (`pnpm/action-setup`)
- `secretlint-version` の検証
- `pnpm dlx "secretlint@<version>"` の引数なしの実行と、終了コードの伝搬
- スクリプト `scripts/run-secretlint.sh` と、検証ライブラリ `scripts/_libs/inputs.lib.sh`

**Out of Scope**:

- リポジトリのチェックアウト (呼び出し元の責務)
- Node.js のセットアップ (GitHub-hosted ランナーのものを使う)
- secretlint の設定ファイル、無視ファイルの指定
- secretlint 13 以前のサポート
- 出力 (本 Action に outputs は無い)

## 2. Context

- Target Environment: GitHub Actions (Composite Action, Linux ランナー)
- Related Components:
  - `.github/actions/_libs/error.lib.sh` (`gha_error`)
  - `pnpm/action-setup` (SHA で固定した外部 Action)
  - 呼び出し元: `ru-scan-secrets.yml` の `scan-secretlint` ジョブ
- Assumptions:
  - 呼び出し元は `actions/checkout` を済ませている。
  - ランナーに Node.js がある。
  - `pnpm-version` が空の場合、リポジトリの `package.json` の `packageManager` から pnpm の版を決める。

### System Context Diagram

```text
[Caller inputs:           --> +------------------------+ --> [Caller: exit code]
 pnpm-version,                |  ca-run-secretlint     |
 secretlint-version]          |   pnpm/action-setup    |
                              |   scripts/run-         |
[Checked-out repository]  <-> |     secretlint.sh      | --> [::error:: (invalid version)]
                              |        |               |
                              |  scripts/_libs/        |
                              |   inputs.lib.sh        |
                              +------------------------+
                                   |  pnpm dlx secretlint@<version>
                                   v
                              [secretlint (bundled config)]
```

## 3. Design Decisions (Summary)

| ID    | Decision                                                         | Linked Record          |
| ----- | ---------------------------------------------------------------- | ---------------------- |
| DR-01 | secretlint は `pnpm dlx` で実行し、リポジトリへ導入しない        | ../decision-records.md |
| DR-02 | バージョンは major 14 以上の X.Y.Z だけを受け付ける              | ../decision-records.md |
| DR-03 | 設定ファイルの入力は設けず、同梱設定を使う                       | ../decision-records.md |
| DR-04 | 外部 Action は SHA で固定し、チェックアウトと Node.js は扱わない | ../decision-records.md |
| DR-05 | 入力の検証は pnpm の呼び出しより前に行う (fail-first)            | ../decision-records.md |

## 4. Functional Requirements

### REQ-F-001: pnpm のセットアップ

- EARS Type: WHEN (event-driven)

```text
GIVEN Action が呼び出された
  WHEN secretlint を実行する前に
THEN the system SHALL pnpm/action-setup で pnpm をセットアップし、
     入力 pnpm-version をその version に渡す.
```

**Rationale**: `pnpm dlx` の実行に pnpm が要る。`pnpm-version` が空なら `packageManager` に委ねる。

**Acceptance Criteria**:

| AC ID  | Scenario                                            |
| ------ | --------------------------------------------------- |
| AC-001 | pnpm のセットアップが secretlint の実行より前にある |
| AC-002 | `pnpm-version` を pnpm のセットアップへ渡す         |
| AC-003 | `pnpm-version` は任意で、既定が空である             |

### REQ-F-002: secretlint の実行

- EARS Type: WHEN (event-driven)

```text
GIVEN secretlint-version が検証を通った
  WHEN secretlint を実行する
THEN the system SHALL pnpm dlx "secretlint@<secretlint-version>" を、他の引数なしで実行する.
```

**Rationale**: 設定は secretlint が同梱する。引数を足すと、同梱設定の前提が崩れる。

**Acceptance Criteria**:

| AC ID  | Scenario                                           |
| ------ | -------------------------------------------------- |
| AC-004 | `dlx` と `secretlint@<version>` だけを pnpm へ渡す |
| AC-005 | 設定ファイル、無視ファイルのオプションを渡さない   |

### REQ-F-003: 終了コードの伝搬

- EARS Type: WHEN (event-driven)

```text
GIVEN secretlint が終了した
  WHEN Action が完了する
THEN the system SHALL secretlint の終了コードをそのまま Action の終了コードとする.
```

**Acceptance Criteria**:

| AC ID  | Scenario                               |
| ------ | -------------------------------------- |
| AC-006 | 検出あり (終了コード 1) を伝搬する     |
| AC-007 | ツールエラー (終了コード 2) を伝搬する |

### REQ-F-004: バージョンの検証

- EARS Type: IF (unwanted-behavior)

```text
GIVEN secretlint-version が指定されている
  IF 値が X.Y.Z の数字だけで、かつ major が 14 以上でない
THEN the system SHALL ::error:: を出して失敗し、pnpm を呼び出さない.
```

受け付ける値は、先頭に 0 を持たない major が 14 以上の `X.Y.Z` だけとする。
`v` 接頭辞、接尾辞 (`-beta.1`)、dist-tag (`latest`)、空、複数行、コマンド連結を含む値は拒否する。

**Rationale**: 値は `pnpm dlx` の引数になる。厳密な形式にして、dist-tag や引数の混入を防ぐ。

**Acceptance Criteria**:

| AC ID  | Scenario                                                             |
| ------ | -------------------------------------------------------------------- |
| AC-008 | 14.0.0、14.0.1、14.10.100、15.0.0、100.0.0 を受け付ける              |
| AC-009 | 14.0、v14.0.0、空、latest、`14.0.0; id`、14.0.0-beta.1、複数行を拒否 |
| AC-010 | 13.x、0.0.0、9.9.9、先頭 0 の 014.0.0、00.1.2 を拒否                 |
| AC-011 | エラー文に `X.Y.Z` と「major」「14 or later」が含まれる              |
| AC-012 | 不正な値では `::error::` を出し、pnpm を呼ばない                     |

## 5. Non-Functional Requirements

### REQ-NF-001: スクリプトインジェクションの防止

入力は `env` 経由でスクリプトへ渡す。`run` の中に GitHub の式 (`${{ }}`) を置かない。
`run` は `GITHUB_ACTION_PATH` からスクリプトを実行する。

### REQ-NF-002: 最小権限

Action は `contents: write` / `id-token: write` を要求しない。
呼び出し元ジョブは `contents: read` で足りる。

### REQ-NF-003: エラーの形式

エラーは `gha_error` により、`::error::secretlint-version: <問題> (got: '<値>')` の形式で標準エラー出力へ出す。

## 6. Constraints

### REQ-C-001: 公開 Composite Action

`name` は `run-secretlint`、`using: composite` とする。ディレクトリは `ca-run-secretlint`。

### REQ-C-002: 外部 Action

`uses:` は `pnpm/action-setup` の 1 つだけとし、コミット SHA で固定する (コメントに版 `v6.1.1` を残す)。
`actions/checkout` と Node.js のセットアップは使わない。

### REQ-C-003: 設定ファイルの入力を持たない

`secretlintrc` や `config` の入力を設けない。入力は `pnpm-version` と `secretlint-version` の 2 つに限る。

### REQ-C-004: テストの階層

テストは ShellSpec の unit と functional で書く。functional は `pnpm` をスタブに差し替える。
integration / e2e は持たない。ワークフロー全体は、`_tests_ru_reusable-workflows.yml` が `ru-scan-secrets.yml` を呼んで確かめる。

### REQ-C-005: ライセンスヘッダー

`action.yml` と各スクリプトに、`src` / `@(#)` / Copyright / MIT License のヘッダーを付ける。
`action.yml` には `# @version` を付ける。

## 7. User Stories

| Story ID | Role               | Goal                                       | Reason                          | Related Requirements  |
| -------- | ------------------ | ------------------------------------------ | ------------------------------- | --------------------- |
| US-001   | ワークフロー作成者 | 1 ステップで secretlint を実行したい       | 設定や導入の手間を省きたい      | REQ-F-001, REQ-F-002  |
| US-002   | セキュリティ担当   | 入力が実行コマンドに混入しないようにしたい | dist-tag や引数の混入を防ぎたい | REQ-F-004, REQ-NF-001 |
| US-003   | CI の利用者        | 検出結果を終了コードで受け取りたい         | ジョブの成否に反映したい        | REQ-F-003             |

## 8. Acceptance Criteria

受け入れ基準 AC-001〜AC-012 は、4 章の各要求の表で定義する。
テストとの対応は tasks.md に示す。

## 9. Open Questions

| Question                                                           | Type        | Impact Area | Owner      |
| ------------------------------------------------------------------ | ----------- | ----------- | ---------- |
| action.yml の説明は「14.0.0 or later」、既定は 14.0.1 で、揃えるか | Doc wording | REQ-C-003   | maintainer |

## 10. Traceability

| REQ ID     | AC IDs                                 | Type |
| ---------- | -------------------------------------- | ---- |
| REQ-F-001  | AC-001, AC-002, AC-003                 | F    |
| REQ-F-002  | AC-004, AC-005                         | F    |
| REQ-F-003  | AC-006, AC-007                         | F    |
| REQ-F-004  | AC-008, AC-009, AC-010, AC-011, AC-012 | F    |
| REQ-NF-001 | (T-RSL-ACT-05, T-RSL-ACT-09)           | NF   |
| REQ-NF-002 | (T-RSL-ACT-07)                         | NF   |
| REQ-NF-003 | (T-RSL-VER-19)                         | NF   |

## 11. Change History

| Date       | Version | Description     |
| ---------- | ------- | --------------- |
| 2026-11-19 | 1.0.0   | Initial release |
