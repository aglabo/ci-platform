---
title: "Design Specification: Ghalint Reusable Workflow"
based-on: requirements.md v1.0
status: Draft
version: 1.0.0
created: "2026-06-13"
---

<!-- markdownlint-disable line-length -->

## 1. Overview

### 1.1 Purpose

本文書は、`ci-qa-ghalint.yml` reusable workflow の振る舞い仕様を定義します。
ghalint によるワークフローポリシー検証を 7 ステップのシーケンシャル実行として記述します。
あわせて、`ci-workflows-qa.yml` における外部依存の置き換え動作も対象に含めます。

### 1.2 Scope

本仕様は `ci-qa-ghalint.yml` の **振る舞いルールと分類セマンティクス** を定義します。
実装の詳細（YAML フィールドの具体的な値、アクションバージョンの SHA 等）は明示的にスコープ外とします。

---

## 2. Design Principles

### 2.1 Classification Philosophy

各実行ステップは前のステップの成功を前提条件とします。
いずれかのステップが失敗した場合、後続のステップはすべてブロックされます。
ただし、report-upload ステップは lint-execute の失敗時のみ実行される例外的な後処理です。

### 2.2 Design Assumptions

- 実行環境は Linux ベースのセルフホストランナーです
- `setup-tool` composite action は指定リポジトリの GitHub Releases からバイナリを取得できます
- `validate-environment` composite action は `actions-type: read` で正常に動作します
- `aglabo/.github` リポジトリは `workflow_call` 実行時にアクセスできます

### 2.3 External Design Summary

> **Source**: Derived from the external design dialogue (Phase E) and user-confirmed design direction (Phase D).

#### Feature Decomposition

| Unit            | Responsibility                                         | REQ Coverage         |
| --------------- | ------------------------------------------------------ | -------------------- |
| trigger-inputs  | 呼び出し側入力とデフォルト値を解決します               | REQ-F-001, REQ-F-002 |
| target-checkout | ターゲットリポジトリをワークスペースに配置します       | REQ-F-003            |
| env-validation  | ランナー環境と権限を検証します                         | REQ-F-004            |
| tool-install    | ghalint バイナリを実行パスにインストールします         | REQ-F-005            |
| config-checkout | 共有設定リポジトリを取得してワークスペースに配置します | REQ-F-006            |
| prepare-report  | レポート出力先ディレクトリを準備します                 | REQ-F-007            |
| lint-execute    | ghalint を実行しポリシー違反を検出します               | REQ-F-007            |
| report-upload   | 失敗時のみレポートをアーティファクトとして保存します   | REQ-F-008            |
| caller-update   | 外部依存をローカル呼び出しに置き換えます               | REQ-F-009            |

#### Unit Interaction Map

```text
[workflow_call] --> +----------------+
                    | trigger-inputs |
                    +----------------+
                           |
                           v
                    +----------------+
                    | target-checkout|
                    +----------------+
                           |
                           v
                    +----------------+
                    | env-validation |
                    +----------------+
                           |
                           v
                    +----------------+
                    |  tool-install  | <-- [suzuki-shunsuke/ghalint Releases]
                    +----------------+
                           |
                           v
                    +----------------+
                    | config-checkout| <-- [aglabo/.github repository]
                    +----------------+
                           |
                           v
                    +----------------+
                    | prepare-report |
                    +----------------+
                           |
                           v
                    +----------------+
                    |  lint-execute  | --> [.github/report/ghalint-report.txt]
                    +----------------+
                     (failure only) |
                           v
                    +----------------+
                    | report-upload  | --> [artifact: ghalint-report]
                    +----------------+
```

#### Data Flow Diagram

```text
[inputs]             --> [trigger-inputs] --> [resolved-version, resolved-config-path]
[target-repo]        --> [target-checkout] --> [workspace/source]
[workspace/source]   --> [env-validation]  --> [env-status]
[ghalint-releases]   --> [tool-install]    --> [ghalint-binary-in-PATH]
[aglabo/.github]     --> [config-checkout] --> [./shared/configs/ghalint.yaml]
[ghalint-binary]     --> [lint-execute]    --> [ghalint-report.txt, exit-code]
[exit-code: failure] --> [report-upload]   --> [artifact: ghalint-report]
```

### 2.4 Non-Goals

> **Derivation**: All items below originate from REQUIREMENTS Section "Out of Scope".

- ghalint ポリシーの追加・変更 ← REQ: Out of Scope
- ghalint 以外の QA ツール（actionlint, betterleaks）の変更 ← REQ: Out of Scope
- `workflow_dispatch` による手動トリガーのサポート ← REQ: Out of Scope
- セルフホストランナー以外の環境サポート ← REQ: Out of Scope

### 2.5 Behavioral Design Decisions

| ID    | Decision                                                            | Rationale                                                                | Affected Rules | Status |
| ----- | ------------------------------------------------------------------- | ------------------------------------------------------------------------ | -------------- | ------ |
| DD-01 | 外部依存を排除しローカル reusable workflow として実装します         | 外部リポジトリの可用性リスクを排除し、バージョン管理を一元化します       | R-001〜R-009   | Active |
| DD-02 | 設定は `aglabo/.github` からチェックアウトします（actionlint 踏襲） | 設定の一元管理と `config-file` 入力による上書き可能性を両立します        | R-006, R-007   | Active |
| DD-03 | 入力パラメータは `ghalint-version` と `config-file` の 2 つとします | 呼び出し側がバージョンと設定パスを制御できる最小限のインターフェースです | R-002          | Active |
| DD-04 | ステップ間条件は `steps.<id>.outcome == 'success'` パターンとします | プロジェクト既存ワークフロー（actionlint）との一貫性を維持します         | R-001〜R-008   | Active |
| DD-05 | 失敗時のみレポートをアーティファクトとしてアップロードします        | 成功時のストレージ消費を抑制し、エラー確認の利便性を確保します           | R-009          | Active |

### 2.6 Related Decision Records

> **Reference**: requirements.md に DR-01〜DR-05 として記載しています。`decision-records.md` は未作成です。
> "No Decision Records currently affect this specification. DR candidates are listed in Section 2.5."

### 2.7 DD to DR Promotion Criteria

DD-01（外部依存排除）と DD-02（設定リポジトリ固定）は、他の reusable workflow モジュールにも共通する設計判断です。
対象となるモジュールは actionlint と betterleaks です。
そのため、将来的に DR へ昇格させることを検討します。

---

## 3. Behavioral Specification

### 3.1 Input Domain

- `ghalint-version`: バージョン文字列（X.Y.Z 形式）です。省略時はデフォルト値を使用します。
- `config-file`: 設定ファイルのパス文字列です。省略時は `./shared/configs/ghalint.yaml` を使用します。
- トリガー: `workflow_call` のみです。他のトリガーは受け付けません。

### 3.2 Output Semantics

- exit code 0: 全ステップが成功し、ポリシー違反が検出されなかったことを表します
- exit code 非ゼロ: ポリシー違反が検出されたか、いずれかのステップが失敗したことを表します
- 副作用:
  - `.github/report/ghalint-report.txt`: lint 実行結果を常に出力します（lint-execute 到達時）
  - `ghalint-report` アーティファクト: lint-execute 失敗時のみ 30 日間保持します

### 3.3 Unit Behavioral Contracts

#### trigger-inputs

- `ghalint-version` が指定された場合、その値をそのまま使用します
- `ghalint-version` が省略された場合、事前定義されたデフォルトバージョンを使用します
- `config-file` が指定された場合、その値をそのまま使用します
- `config-file` が省略された場合、`./shared/configs/ghalint.yaml` を使用します
- この処理は失敗しません。入力の省略はデフォルト値で補完します

#### target-checkout

- 認証情報がワークスペースに残留しないよう保護した状態でチェックアウトします
- チェックアウトに失敗した場合、後続の全ステップをブロックします

#### env-validation

- target-checkout が成功した場合のみ実行します
- 読み取り権限のみを要求する形で環境を検証します
- 検証に失敗した場合、tool-install 以降の全ステップをブロックします

#### tool-install

- env-validation が成功した場合のみ実行します
- `suzuki-shunsuke/ghalint` リポジトリの解決済みバージョンをインストールします
- インストール後、ghalint バイナリは実行パスから呼び出し可能な状態になります
- インストールに失敗した場合、config-checkout 以降の全ステップをブロックします

#### config-checkout

- tool-install が成功した場合のみ実行します
- `aglabo/.github` リポジトリを浅いチェックアウト（履歴 1 件）で取得します
- 認証情報がワークスペースに残留しないよう保護した状態でチェックアウトします
- チェックアウト後、`./shared/` 配下に設定ファイルが配置された状態になります
- チェックアウトに失敗した場合、prepare-report 以降の全ステップをブロックします

#### prepare-report

- config-checkout が成功した場合のみ実行します
- レポート出力先ディレクトリが存在しない場合は作成します
- ディレクトリが既に存在する場合も失敗しません（冪等）
- 準備に失敗した場合、lint-execute をブロックします

#### lint-execute

- prepare-report が成功した場合のみ実行します
- 解決済みの設定ファイルパスを使用して ghalint を実行します
- 実行結果をレポートファイルに出力します
- ポリシー違反が検出された場合、非ゼロ終了コードを伝播してジョブを失敗させます
- ポリシー違反がない場合、ゼロ終了コードでジョブを成功させます

#### report-upload

- lint-execute が失敗した場合のみ実行します（成功時は実行しません）
- lint-execute のレポートファイルをアーティファクトとして保存します
- アーティファクトの保持期間は 30 日間とします
- このステップ自体の失敗は非致命的です（既にジョブは失敗状態のため）

---

## 4. Decision Rules

Evaluation MUST follow this order:

| Rule ID | Step | Condition                                   | Outcome                                              |
| ------- | ---: | ------------------------------------------- | ---------------------------------------------------- |
| R-001   |    1 | workflow_call で呼び出された                | trigger-inputs を実行し入力値を解決します            |
| R-002   |    2 | ghalint-version が指定された                | 指定バージョンを使用します                           |
| R-002a  |    2 | ghalint-version が省略された                | デフォルトバージョンを使用します                     |
| R-003   |    3 | config-file が指定された                    | 指定パスを使用します                                 |
| R-003a  |    3 | config-file が省略された                    | `./shared/configs/ghalint.yaml` を使用します         |
| R-004   |    4 | target-checkout が成功した                  | env-validation を実行します                          |
| R-004a  |    4 | target-checkout が失敗した                  | 後続全ステップをブロックしジョブを失敗させます       |
| R-005   |    5 | env-validation が成功した                   | tool-install を実行します                            |
| R-005a  |    5 | env-validation が失敗した                   | tool-install 以降をブロックしジョブを失敗させます    |
| R-006   |    6 | tool-install が成功した                     | config-checkout を実行します                         |
| R-006a  |    6 | tool-install が失敗した                     | config-checkout 以降をブロックしジョブを失敗させます |
| R-007   |    7 | config-checkout が成功した                  | prepare-report を実行します                          |
| R-007a  |    7 | config-checkout が失敗した                  | prepare-report 以降をブロックしジョブを失敗させます  |
| R-008   |    8 | prepare-report が成功した                   | lint-execute を実行します                            |
| R-008a  |    8 | prepare-report が失敗した                   | lint-execute をブロックしジョブを失敗させます        |
| R-009   |    9 | lint-execute が成功した（exit code 0）      | ジョブを成功させます。アーティファクトは保存しません |
| R-009a  |    9 | lint-execute が失敗した（exit code 非ゼロ） | report-upload を実行しアーティファクトを保存します   |

No reordering is permitted.

---

## 5. Edge Cases

| Scenario                                                 | 振る舞い                                               | REQ       | Rationale                                             |
| -------------------------------------------------------- | ------------------------------------------------------ | --------- | ----------------------------------------------------- |
| `config-file` に存在しないパスを指定                     | lint-execute が失敗し report-upload が実行されます     | REQ-F-007 | ghalint は設定ファイル不在時に非ゼロ終了します        |
| `ghalint-version` に存在しないバージョンを指定           | tool-install が失敗し後続がブロックされます            | REQ-F-005 | setup-tool は Releases に存在しない版を取得できません |
| `aglabo/.github` に `shared/configs/ghalint.yaml` が不在 | lint-execute が失敗し report-upload が実行されます     | REQ-F-006 | Open Question — 存在確認が必要です                    |
| `.github/report/` が既に存在する状態で再実行             | prepare-report が正常終了し lint-execute へ進みます    | REQ-F-007 | ディレクトリ作成は冪等です                            |
| ポリシー違反がゼロ件                                     | lint-execute が exit code 0 で終了しジョブが成功します | REQ-F-007 | 正常系です                                            |
| ポリシー違反が 1 件以上                                  | lint-execute が非ゼロで終了しジョブが失敗します        | REQ-F-007 | 違反を CI 失敗として確実に伝播させます                |
| report-upload 自体が失敗                                 | ジョブはすでに失敗状態であり追加エラーを記録します     | REQ-F-008 | 非致命的な後処理です                                  |

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule                    | Notes                                                                            |
| -------------- | ---------------------------- | -------------------------------------------------------------------------------- |
| REQ-F-001      | R-001                        | workflow_call トリガーのみ受け付けます                                           |
| REQ-F-002      | R-002, R-002a, R-003, R-003a | 入力パラメータのデフォルトを解決します                                           |
| REQ-F-003      | R-004, R-004a                | target-checkout の成功/失敗で分岐します                                          |
| REQ-F-004      | R-005, R-005a                | env-validation の成功/失敗で分岐します                                           |
| REQ-F-005      | R-006, R-006a                | tool-install の成功/失敗で分岐します                                             |
| REQ-F-006      | R-007, R-007a                | config-checkout の成功/失敗で分岐します                                          |
| REQ-F-007      | R-008, R-008a, R-009         | prepare-report と lint-execute を実行し結果を伝播します                          |
| REQ-F-008      | R-009a                       | 失敗時のみ report-upload を実行します                                            |
| REQ-F-009      | DD-01                        | ci-workflows-qa.yml の外部依存をローカルに置き換えます（実装フェーズで扱います） |
| REQ-NF-001     | Section 3.3 全 Unit          | 全チェックアウトで認証情報を保護し、最小権限を適用します                         |
| REQ-NF-002     | Section 2.3                  | actionlint の 7 ステップパターンに準拠します                                     |
| REQ-NF-003     | Section 2.5 DD-04            | SHA ピンとタイムアウト設定は実装フェーズで扱います                               |
| REQ-NF-004     | Section 2.3 Unit 名          | ステップ ID 命名規則は actionlint と統一します                                   |
| REQ-C-001      | Section 2.2                  | ubuntu-slim ランナーを前提とします                                               |
| REQ-C-002      | Section 2.5 DD-04            | `steps.<id>.outcome == 'success'` パターンのみを使用します                       |
| REQ-C-003      | R-001                        | workflow_call トリガーのみを使用します                                           |
| REQ-C-004      | Section 3.3 config-checkout  | aglabo/.github を設定ソースとして使用します                                      |

---

## 7. Open Questions

> **Status**: INCOMPLETE

| # | Question                                                                             | Source    | Impact                                                       |
| - | ------------------------------------------------------------------------------------ | --------- | ------------------------------------------------------------ |
| 1 | ghalint のデフォルトバージョン番号は何ですか（`suzuki-shunsuke/ghalint` 最新安定版） | REQ-F-005 | trigger-inputs のデフォルト値が未確定です                    |
| 2 | `aglabo/.github` リポジトリに `shared/configs/ghalint.yaml` が存在しますか           | REQ-F-006 | 存在しない場合、config-checkout ステップの設計変更が必要です |

---

## 8. Change History

| Date       | Version | Description           |
| ---------- | ------- | --------------------- |
| 2026-06-13 | 1.0.0   | Initial specification |
