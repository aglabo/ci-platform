---
title: "Requirements: _ca-resolve-config"
module: "composite-action/resolve-config"
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

品質ツールの設定ファイルは、呼び出し元の指定、リポジトリ内の設定、グローバル設定リポジトリの設定の順に探す。
この探索を、再利用可能ワークフローごとに書くと、優先順位と検査が揺れる。
そこで探索を内部 Composite Action `.github/actions/_ca-resolve-config/` に切り出す (Issue #213, PR #215)。

本 Action は、使う設定ファイルの絶対パスと、その出所を出力する。
パスは `GITHUB_WORKSPACE` の内側に限る。`..` を含むパスと空白を含むパスは受け付けない (PR #216)。

### 1.2 Scope

- `.github/actions/_ca-resolve-config/` Composite Action
- 入力 `config` / `local-config` / `global-config` (いずれも required: false, default "")
- 出力 `config-file` (絶対パス) / `source` (`input` | `local` | `global`)
- スクリプト `scripts/resolve-config.sh` と、関数ライブラリ `scripts/_libs/resolve-config.lib.sh`
- 候補の探索順、パスの検査、成功時だけの出力の書き出し

**Out of Scope**:

- 設定ファイルの内容の検証
- グローバル設定リポジトリのチェックアウト (呼び出し元ワークフローの責務)
- パス検査の実装 (共有ライブラリ `_libs/path.lib.sh` の `validate_path` が持つ)
- ツールごとの既定の設定パス (呼び出し元が `local-config` / `global-config` で渡す)

## 2. Context

- Target Environment: GitHub Actions (Composite Action, Linux ランナー)
- Related Components:
  - `.github/actions/_libs/path.lib.sh` (`validate_path`)
  - `.github/actions/_libs/error.lib.sh` (`gha_error`)
  - `.github/actions/_libs/output.lib.sh` (`write_output`)
  - 呼び出し元:
    - `ru-lint-documents` (textlint / markdownlint)
    - `ru-qa-actionlint`
    - `ru-qa-ghalint`
    - `ru-scan-secrets` (betterleaks)
- Assumptions:
  - 呼び出し元は、`global-config` を使う場合、設定リポジトリを `global/` にチェックアウト済みである。
  - `GITHUB_WORKSPACE` は GitHub Actions ランナーが常に設定する。

### System Context Diagram

```text
[Caller inputs:           --> +--------------------------+ --> [Caller: config-file / source]
 config, local-config,        |  _ca-resolve-config      |
 global-config]               |   scripts/resolve-config |
[GITHUB_WORKSPACE]        --> |        |                 | --> [$GITHUB_OUTPUT (on success only)]
                              |        v                 | --> [::notice:: / ::error::]
[Workspace files]         <-- |  _libs/path.lib.sh       |
                              |  (validate_path)         |
                              +--------------------------+
```

## 3. Design Decisions (Summary)

| ID    | Decision                                                                  | Linked Record          |
| ----- | ------------------------------------------------------------------------- | ---------------------- |
| DR-01 | 明示入力 `config` は唯一の候補とし、不在でもフォールバックしない          | ../decision-records.md |
| DR-02 | 探索順は `config` → `local-config` → `global-config` とする               | ../decision-records.md |
| DR-03 | パス検査は共有ライブラリの `validate_path` に任せ、workspace に閉じ込める | ../decision-records.md |
| DR-04 | 拒否したパスは「不在」と区別し、後続の候補へフォールバックしない          | ../decision-records.md |
| DR-05 | 出力は解決に成功した後にだけ書き出す                                      | ../decision-records.md |
| DR-06 | 空白を含むパスは、実在しても拒否する                                      | ../decision-records.md |

## 4. Functional Requirements

### REQ-F-001: 明示入力の優先

- EARS Type: WHEN (event-driven)

```text
GIVEN 呼び出し元が config を指定している
  WHEN 設定ファイルを解決する
THEN the system SHALL config だけを候補とし、通常ファイルであれば source を "input" として採用する.
```

**Rationale**: 呼び出し元の明示指定は、他の設定より常に優先する (DR-01)。

**Acceptance Criteria**:

| AC ID  | Scenario                                                           |
| ------ | ------------------------------------------------------------------ |
| AC-001 | config が存在すると source=input になる (相対・workspace 内の絶対) |
| AC-002 | config が存在しなければ、local が存在してもエラーになる            |

### REQ-F-002: local と global の探索

- EARS Type: WHEN (event-driven)

```text
GIVEN config が空である
  WHEN 設定ファイルを解決する
THEN the system SHALL local-config、global-config の順に探し、最初の通常ファイルを採用する.
```

**Rationale**: リポジトリ固有の設定を、グローバル設定より優先する (DR-02)。

**Acceptance Criteria**:

| AC ID  | Scenario                                   |
| ------ | ------------------------------------------ |
| AC-003 | local のみ存在すると source=local になる   |
| AC-004 | global のみ存在すると source=global になる |
| AC-005 | 両方存在すると local を優先する            |

### REQ-F-003: 出力

- EARS Type: WHEN (event-driven)

```text
GIVEN 設定ファイルを 1 つ採用した
  WHEN Action が完了する
THEN the system SHALL 出力 config-file に絶対パス、出力 source に input / local / global のいずれかを書き出す.
```

**Rationale**: 呼び出し元は、絶対パスをそのままツールの設定オプションに渡す。出所は診断に使う。

**Acceptance Criteria**:

| AC ID  | Scenario                                                  |
| ------ | --------------------------------------------------------- |
| AC-006 | `GITHUB_OUTPUT` のキーは config-file と source だけである |
| AC-007 | outputs が step の出力に写像される                        |

### REQ-F-004: パスの閉じ込め

- EARS Type: WHEN (event-driven)

```text
GIVEN 候補のパスが指定されている
  WHEN 候補を検査する
THEN the system SHALL ".." セグメントを含むパス、空白を含むパス、
     GITHUB_WORKSPACE の外を指すパス (symlink 経由を含む) を拒否する.
```

**Rationale**: 設定のパスは呼び出し元の入力であり、workspace の外のファイルを読ませない (DR-03, DR-06)。

**Acceptance Criteria**:

| AC ID  | Scenario                                                             |
| ------ | -------------------------------------------------------------------- |
| AC-008 | ".." を含むパスは、workspace 内で完結する場合も拒否する              |
| AC-009 | workspace 外の絶対パスと、外部を指す symlink (多段を含む) を拒否する |
| AC-010 | 空白を含むパスは、実在しても拒否する                                 |
| AC-011 | workspace 内を指す symlink は受理する                                |

### REQ-F-005: 拒否と不在の区別

- EARS Type: IF (unwanted-behavior)

```text
GIVEN local-config のパスが拒否された
  IF global-config が存在する
THEN the system SHALL global-config へフォールバックせず、エラーで終了する.
```

**Rationale**: 拒否したパスを黙って飛ばすと、不正な入力が検知されない (DR-04)。

**Acceptance Criteria**:

| AC ID  | Scenario                                            |
| ------ | --------------------------------------------------- |
| AC-012 | 外部を指す local は、フォールバックせずエラーになる |

### REQ-F-006: 候補は通常ファイル

- EARS Type: IF (unwanted-behavior)

```text
GIVEN 候補のパスがディレクトリ、または参照先のない symlink である
  IF 検査する
THEN the system SHALL その候補を不在として扱う.
```

**Acceptance Criteria**:

| AC ID  | Scenario                                  |
| ------ | ----------------------------------------- |
| AC-013 | config がディレクトリならエラーになる     |
| AC-014 | dangling symlink は file not found になる |

### REQ-F-007: 候補なし

- EARS Type: IF (unwanted-behavior)

```text
GIVEN どの候補も採用できない
  IF 3 つの入力がすべて空、または local / global が不在である
THEN the system SHALL エラーで終了する.
```

**Acceptance Criteria**:

| AC ID  | Scenario                   |
| ------ | -------------------------- |
| AC-015 | 3 つとも不在ならエラー     |
| AC-016 | 3 引数がすべて空ならエラー |

### REQ-F-008: workspace 未設定

- EARS Type: IF (unwanted-behavior)

```text
GIVEN GITHUB_WORKSPACE が未設定または空である
  IF 設定ファイルを解決する
THEN the system SHALL エラーで終了する.
```

**Acceptance Criteria**:

| AC ID  | Scenario                        |
| ------ | ------------------------------- |
| AC-017 | GITHUB_WORKSPACE 未設定でエラー |

### REQ-F-009: 成功時だけの出力

- EARS Type: WHEN (event-driven)

```text
GIVEN 解決がエラーで終了した
  WHEN Action が終了する
THEN the system SHALL GITHUB_OUTPUT に何も書き出さない.
```

成功時は、source とパスを含む `::notice::` を 1 行出力する (DR-05)。

**Acceptance Criteria**:

| AC ID  | Scenario                                                |
| ------ | ------------------------------------------------------- |
| AC-018 | 成功時に `::notice::` が source と path を含み 1 行出る |
| AC-019 | エラー時に GITHUB_OUTPUT へ書き出さない                 |

## 5. Non-Functional Requirements

### REQ-NF-001: スクリプトインジェクションの防止

入力と `GITHUB_WORKSPACE` は `env` 経由で渡す。`run` の中に GitHub の式 (`${{ }}`) を置かない。
`run` は `GITHUB_ACTION_PATH` からスクリプトを実行する。

### REQ-NF-002: 入力値を評価しない

入力値は、コマンド置換などとして評価しない。文字列のまま扱う。

### REQ-NF-003: エラーの形式

エラーは `gha_error` により、`::error::<対象>: <問題> (got: '<値>')` の 1 行で標準エラー出力へ出す。
値の改行と `%` はエンコードする。

## 6. Constraints

### REQ-C-001: 内部 Composite Action

`name` は `_ca-resolve-config`、`using: composite` とし、シェルは bash とする。
Action に `permissions` の要求は無い。権限は呼び出し元が決める。

### REQ-C-002: 共有ライブラリの利用

エラー出力は `_libs/error.lib.sh`、パス検査は `_libs/path.lib.sh`、出力の書き出しは `_libs/output.lib.sh` を使う。
ライブラリを読み込めない場合は、読み込みを失敗させる。

### REQ-C-003: テストの階層

テストは ShellSpec の unit と functional で書く。integration / e2e は持たない。
CI では `_tests_ca_composite-actions.yml` の `test-resolve-config` ジョブが Action を実際に呼び出す。

### REQ-C-004: ライセンスヘッダー

`action.yml` と各スクリプトに、`src` / `@(#)` / Copyright / MIT License のヘッダーを付ける。
`action.yml` には `# @version` を付ける。

## 7. User Stories

| Story ID | Role                   | Goal                                    | Reason                                 | Related Requirements |
| -------- | ---------------------- | --------------------------------------- | -------------------------------------- | -------------------- |
| US-001   | ワークフロー作成者     | 設定ファイルを 1 つの Action で決めたい | 探索順と検査を揃えたい                 | REQ-F-001, REQ-F-002 |
| US-002   | セキュリティ担当       | 設定のパスを workspace に閉じ込めたい   | workspace 外のファイルを読ませたくない | REQ-F-004, REQ-F-005 |
| US-003   | 呼び出し元ワークフロー | 採用された設定の出所を知りたい          | ログで診断したい                       | REQ-F-003, REQ-F-009 |

## 8. Acceptance Criteria

受け入れ基準 AC-001〜AC-019 は、4 章の各要求の表で定義する。
テストとの対応は 10 章に示す。

## 9. Open Questions

| Question                                                                                 | Type          | Impact Area | Owner      |
| ---------------------------------------------------------------------------------------- | ------------- | ----------- | ---------- |
| `configs/jactionlint.yaml` と `configs/ghalint.yaml` はリポジトリに無く、global に落ちる | Repo state    | 呼び出し元  | maintainer |
| 参照先のない symlink は不在として扱う。検査で拒否する選択肢もある                        | Design choice | REQ-F-006   | maintainer |

## 10. Traceability

| REQ ID     | AC IDs                         | Type |
| ---------- | ------------------------------ | ---- |
| REQ-F-001  | AC-001, AC-002                 | F    |
| REQ-F-002  | AC-003, AC-004, AC-005         | F    |
| REQ-F-003  | AC-006, AC-007                 | F    |
| REQ-F-004  | AC-008, AC-009, AC-010, AC-011 | F    |
| REQ-F-005  | AC-012                         | F    |
| REQ-F-006  | AC-013, AC-014                 | F    |
| REQ-F-007  | AC-015, AC-016                 | F    |
| REQ-F-008  | AC-017                         | F    |
| REQ-F-009  | AC-018, AC-019                 | F    |
| REQ-NF-001 | (T-RC-ACT-04, T-RC-ACT-05)     | NF   |
| REQ-NF-002 | (T-RC-RC-0304)                 | NF   |
| REQ-NF-003 | (specifications.md R-ERR-001)  | NF   |

## 11. Change History

| Date       | Version | Description     |
| ---------- | ------- | --------------- |
| 2026-11-19 | 1.0.0   | Initial release |
