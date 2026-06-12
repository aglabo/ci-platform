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

本文書は、`ci-qa-ghalint.yml` reusable workflow の振る舞い仕様を定義する。
ghalint によるワークフローポリシー検証を 7 ステップのシーケンシャル実行として記述し、
`ci-workflows-qa.yml` における外部依存の置き換え動作を含む。

### 1.2 Scope

本仕様は `ci-qa-ghalint.yml` の**振る舞いルールと分類セマンティクス**を定義する。
実装の詳細（YAML フィールドの具体的な値、アクションバージョンの SHA 等）は明示的にスコープ外とする。

---

## 2. Design Principles

### 2.1 Classification Philosophy

各実行ステップは前のステップの成功を前提条件とする。
いずれかのステップが失敗した場合、後続のステップはすべてブロックされる。
ただし、report-upload ステップは lint-execute の失敗時のみ実行される例外的な後処理である。

### 2.2 Design Assumptions

- 実行環境は Linux ベースのセルフホストランナーである
- `setup-tool` composite action は指定リポジトリの GitHub Releases からバイナリを取得できる
- `validate-environment` composite action は `actions-type: read` で正常に動作する
- `aglabo/.github` リポジトリは `workflow_call` 実行時にアクセス可能である

### 2.3 External Design Summary

> **Source**: Derived from the external design dialogue (Phase E) and user-confirmed design direction (Phase D).

#### Feature Decomposition

| Unit            | Responsibility                                              | REQ Coverage               |
| --------------- | ----------------------------------------------------------- | -------------------------- |
| trigger-inputs  | 呼び出し側入力とデフォルト値を解決する                      | REQ-F-001, REQ-F-002       |
| target-checkout | ターゲットリポジトリをワークスペースに配置する              | REQ-F-003                  |
| env-validation  | ランナー環境と権限を検証する                                | REQ-F-004                  |
| tool-install    | ghalint バイナリを実行パスにインストールする                | REQ-F-005                  |
| config-checkout | 共有設定リポジトリを取得してワークスペースに配置する        | REQ-F-006                  |
| prepare-report  | レポート出力先ディレクトリを準備する                        | REQ-F-007                  |
| lint-execute    | ghalint を実行しポリシー違反を検出する                      | REQ-F-007                  |
| report-upload   | 失敗時のみレポートをアーティファクトとして保存する          | REQ-F-008                  |
| caller-update   | 外部依存をローカル呼び出しに置き換える                      | REQ-F-009                  |

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

| ID    | Decision                                                             | Rationale                                                              | Affected Rules          | Status |
| ----- | -------------------------------------------------------------------- | ---------------------------------------------------------------------- | ----------------------- | ------ |
| DD-01 | 外部依存を排除しローカル reusable workflow として実装               | 外部リポジトリの可用性リスクを排除し、バージョン管理を一元化する       | R-001〜R-009            | Active |
| DD-02 | 設定は `aglabo/.github` からチェックアウト（actionlint パターン踏襲） | 設定の一元管理と `config-file` 入力による上書き可能性を両立する        | R-006, R-007            | Active |
| DD-03 | 入力パラメータは `ghalint-version` と `config-file` の 2 つ         | 呼び出し側がバージョンと設定パスを制御できる最小限のインターフェース   | R-002                   | Active |
| DD-04 | ステップ間条件は `steps.<id>.outcome == 'success'` パターン         | プロジェクト既存ワークフロー（actionlint）との一貫性を維持する         | R-001〜R-008            | Active |
| DD-05 | 失敗時のみレポートをアーティファクトアップロード                    | 成功時のストレージ消費を抑制し、エラー確認の利便性を確保する           | R-009                   | Active |

### 2.6 Related Decision Records

> **Reference**: requirements.md に DR-01〜DR-05 として記載。`decision-records.md` は未作成。

> "No Decision Records currently affect this specification. DR candidates are listed in Section 2.5."

### 2.7 DD to DR Promotion Criteria

DD-01（外部依存排除）と DD-02（設定リポジトリ固定）は、他の reusable workflow モジュール（actionlint, betterleaks）にも共通する設計判断であるため、将来的に DR へ昇格させることを検討する。

---

## 3. Behavioral Specification

### 3.1 Input Domain

- `ghalint-version`: バージョン文字列（X.Y.Z 形式）。省略時はデフォルト値を使用する。
- `config-file`: 設定ファイルのパス文字列。省略時は `./shared/configs/ghalint.yaml` を使用する。
- トリガー: `workflow_call` のみ。他のトリガーは受け付けない。

### 3.2 Output Semantics

- exit code 0: 全ステップが成功し、ポリシー違反が検出されなかった
- exit code 非ゼロ: ポリシー違反が検出されたか、いずれかのステップが失敗した
- 副作用:
  - `.github/report/ghalint-report.txt`: lint 実行結果を常に出力する（lint-execute 到達時）
  - `ghalint-report` アーティファクト: lint-execute 失敗時のみ 30 日間保持する

### 3.3 Unit Behavioral Contracts

#### trigger-inputs

- `ghalint-version` が指定された場合、その値をそのまま使用する
- `ghalint-version` が省略された場合、事前定義されたデフォルトバージョンを使用する
- `config-file` が指定された場合、その値をそのまま使用する
- `config-file` が省略された場合、`./shared/configs/ghalint.yaml` を使用する
- この処理は失敗しない（入力省略はデフォルト値で補完される）

#### target-checkout

- 認証情報がワークスペースに残留しないよう保護した状態でチェックアウトする
- チェックアウト失敗時、後続の全ステップをブロックする

#### env-validation

- target-checkout が成功した場合のみ実行する
- 読み取り権限のみを要求する環境検証を実行する
- 検証失敗時、tool-install 以降の全ステップをブロックする

#### tool-install

- env-validation が成功した場合のみ実行する
- `suzuki-shunsuke/ghalint` リポジトリの解決済みバージョンをインストールする
- インストール後、ghalint バイナリは実行パスから呼び出し可能な状態になる
- インストール失敗時、config-checkout 以降の全ステップをブロックする

#### config-checkout

- tool-install が成功した場合のみ実行する
- `aglabo/.github` リポジトリを浅いチェックアウト（履歴 1 件）で取得する
- 認証情報がワークスペースに残留しないよう保護した状態でチェックアウトする
- チェックアウト後、`./shared/` 配下に設定ファイルが配置された状態になる
- チェックアウト失敗時、prepare-report 以降の全ステップをブロックする

#### prepare-report

- config-checkout が成功した場合のみ実行する
- レポート出力先ディレクトリが存在しない場合は作成する
- ディレクトリが既に存在する場合も失敗しない（冪等）
- 準備失敗時、lint-execute をブロックする

#### lint-execute

- prepare-report が成功した場合のみ実行する
- 解決済みの設定ファイルパスを使用して ghalint を実行する
- 実行結果をレポートファイルに出力する
- ポリシー違反が検出された場合、非ゼロ終了コードを伝播してジョブを失敗させる
- ポリシー違反がない場合、ゼロ終了コードでジョブを成功させる

#### report-upload

- lint-execute が失敗した場合のみ実行する（成功時は実行しない）
- lint-execute のレポートファイルをアーティファクトとして保存する
- アーティファクトの保持期間は 30 日間とする
- このステップ自体の失敗は非致命的（既にジョブは失敗状態）

---

## 4. Decision Rules

Evaluation MUST follow this order:

| Rule ID | Step | Condition                                              | Outcome                                          |
| ------- | ---: | ------------------------------------------------------ | ------------------------------------------------ |
| R-001   |    1 | workflow_call で呼び出された                           | trigger-inputs を実行し入力値を解決する          |
| R-002   |    2 | ghalint-version が指定された                           | 指定バージョンを使用する                         |
| R-002a  |    2 | ghalint-version が省略された                           | デフォルトバージョンを使用する                   |
| R-003   |    3 | config-file が指定された                               | 指定パスを使用する                               |
| R-003a  |    3 | config-file が省略された                               | `./shared/configs/ghalint.yaml` を使用する       |
| R-004   |    4 | target-checkout が成功した                             | env-validation を実行する                        |
| R-004a  |    4 | target-checkout が失敗した                             | 後続全ステップをブロックしジョブを失敗させる     |
| R-005   |    5 | env-validation が成功した                              | tool-install を実行する                          |
| R-005a  |    5 | env-validation が失敗した                              | tool-install 以降をブロックしジョブを失敗させる  |
| R-006   |    6 | tool-install が成功した                                | config-checkout を実行する                       |
| R-006a  |    6 | tool-install が失敗した                                | config-checkout 以降をブロックしジョブを失敗させる |
| R-007   |    7 | config-checkout が成功した                             | prepare-report を実行する                        |
| R-007a  |    7 | config-checkout が失敗した                             | prepare-report 以降をブロックしジョブを失敗させる |
| R-008   |    8 | prepare-report が成功した                              | lint-execute を実行する                          |
| R-008a  |    8 | prepare-report が失敗した                              | lint-execute をブロックしジョブを失敗させる      |
| R-009   |    9 | lint-execute が成功した（exit code 0）                 | ジョブを成功させる。アーティファクトを保存しない |
| R-009a  |    9 | lint-execute が失敗した（exit code 非ゼロ）            | report-upload を実行してアーティファクトを保存する |

No reordering is permitted.

---

## 5. Edge Cases

| Scenario                                               | 振る舞い                                        | REQ           | Rationale                                      |
| ------------------------------------------------------ | ----------------------------------------------- | ------------- | ---------------------------------------------- |
| `config-file` に存在しないパスを指定                   | lint-execute が失敗し report-upload が実行される | REQ-F-007     | ghalint は設定ファイル不在時に非ゼロ終了する   |
| `ghalint-version` に存在しないバージョンを指定         | tool-install が失敗し後続がブロックされる        | REQ-F-005     | setup-tool は Releases に存在しない版を取得できない |
| `aglabo/.github` に `shared/configs/ghalint.yaml` が不在 | lint-execute が失敗し report-upload が実行される | REQ-F-006     | Open Question — 存在確認が必要                 |
| `.github/report/` が既に存在する状態で再実行           | prepare-report が正常終了し lint-execute へ進む  | REQ-F-007     | ディレクトリ作成は冪等                         |
| ポリシー違反がゼロ件                                   | lint-execute が exit code 0 で終了しジョブ成功   | REQ-F-007     | 正常系                                         |
| ポリシー違反が 1 件以上                                | lint-execute が非ゼロで終了しジョブ失敗          | REQ-F-007     | 違反を CI 失敗として確実に伝播させる           |
| report-upload 自体が失敗                               | ジョブはすでに失敗状態であり追加エラーは記録される | REQ-F-008   | 非致命的な後処理                               |

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule            | Notes                                             |
| -------------- | -------------------- | ------------------------------------------------- |
| REQ-F-001      | R-001                | workflow_call トリガーのみ受け付ける              |
| REQ-F-002      | R-002, R-002a, R-003, R-003a | 入力パラメータのデフォルト解決                  |
| REQ-F-003      | R-004, R-004a        | target-checkout の成功/失敗分岐                  |
| REQ-F-004      | R-005, R-005a        | env-validation の成功/失敗分岐                   |
| REQ-F-005      | R-006, R-006a        | tool-install の成功/失敗分岐                     |
| REQ-F-006      | R-007, R-007a        | config-checkout の成功/失敗分岐                  |
| REQ-F-007      | R-008, R-008a, R-009 | prepare-report + lint-execute の実行と結果伝播   |
| REQ-F-008      | R-009a               | 失敗時のみ report-upload を実行                  |
| REQ-F-009      | DD-01                | ci-workflows-qa.yml の外部依存をローカルに置き換える（実装フェーズで扱う） |
| REQ-NF-001     | Section 3.3 全 Unit  | 全チェックアウトで認証情報保護、最小権限を適用   |
| REQ-NF-002     | Section 2.3          | actionlint 7 ステップパターンに準拠              |
| REQ-NF-003     | Section 2.5 DD-04    | SHA ピン・タイムアウト設定は実装フェーズで扱う   |
| REQ-NF-004     | Section 2.3 Unit 名  | ステップ ID 命名規則は actionlint と統一          |
| REQ-C-001      | Section 2.2          | ubuntu-slim ランナーを前提とする                 |
| REQ-C-002      | Section 2.5 DD-04    | `steps.<id>.outcome == 'success'` パターンのみ   |
| REQ-C-003      | R-001                | workflow_call トリガーのみ                       |
| REQ-C-004      | Section 3.3 config-checkout | aglabo/.github を設定ソースとして使用    |

---

## 7. Open Questions

> **Status**: INCOMPLETE

| # | Question                                                                              | Source        | Impact                                                        |
| - | ------------------------------------------------------------------------------------- | ------------- | ------------------------------------------------------------- |
| 1 | ghalint のデフォルトバージョン番号は何か（`suzuki-shunsuke/ghalint` 最新安定版）      | REQ-F-005     | trigger-inputs のデフォルト値が未確定                         |
| 2 | `aglabo/.github` リポジトリに `shared/configs/ghalint.yaml` が存在するか              | REQ-F-006     | 存在しない場合、config-checkout ステップの設計変更が必要      |

---

## 8. Change History

| Date       | Version | Description           |
| ---------- | ------- | --------------------- |
| 2026-06-13 | 1.0.0   | Initial specification |
