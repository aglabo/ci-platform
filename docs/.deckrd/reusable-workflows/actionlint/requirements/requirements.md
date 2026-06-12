---
id: REQ-001
title: Requirements: Actionlint Reusable Workflow
  module: reusable-workflows/actionlint
  status: Draft
  version: "1.0"
  created: 2026-06-12
---

# Requirements: Actionlint Reusable Workflow

## 1. Overview

### Purpose

外部の `aglabo/.github` ワークフローに依存しない独立した GitHub Actions ワークフローとして、
actionlint ベースの GitHub Actions ワークフロー構文検証を実行する。

### Scope

- reusable な GitHub Actions ワークフローの提供
- `workflow_call` トリガーのサポート
- GitHub Actions 環境の検証（`validate-environment` action 使用）
- `setup-tool` action による actionlint インストール
- 設定リポジトリ `aglabo/.github` を `./shared/` にチェックアウト（固定）
- `config-file` 入力パラメータで設定ファイルパスを指定（デフォルト: `./shared/configs/actionlint.yaml`、上書き可能）
- lint エラー検出時のレポートファイル生成とアーティファクトアップロード

### Out of Scope

- ghalint スキャン（別ワークフローで対応）
- セルフホスト以外のランナー対応
- Windows / macOS ランナー対応

---

## 2. Context

### Target Environment

- GitHub Actions 環境
- ランナー: `ubuntu-slim`（セルフホスト）
- 言語: YAML (GitHub Actions workflow syntax)

### Related Components

| コンポーネント         | パス                                    | 役割                                                                                       |
| ---------------------- | --------------------------------------- | ------------------------------------------------------------------------------------------ |
| validate-environment   | `.github/actions/validate-environment`  | 環境検証 composite action                                                                  |
| setup-tool             | `.github/actions/setup-tool`            | バイナリインストール composite action                                                      |
| actionlint 設定        | `shared/configs/actionlint.yaml`        | lint ルール設定（`config-repo` から `./shared/` にチェックアウト後、`config-file` で指定） |
| 呼び出し元ワークフロー | `.github/workflows/ci-workflows-qa.yml` | このワークフローを使用                                                                     |

### Assumptions

- `ubuntu-slim` ランナーが利用可能
- `rhysd/actionlint` リポジトリに GitHub Releases が存在する
- `aglabo/.github` リポジトリに `configs/actionlint.yaml` が存在する
- `setup-tool` action が actionlint バイナリを正常にインストールできる

### System Context Diagram

```text
[呼び出し元ワークフロー]
        |
        | workflow_call
        v
[ci-lint-actionlint.yml]
        |
        +-- [actions/checkout] ─────── ターゲットリポジトリ checkout
        |
        +-- [validate-environment] ── 環境検証
        |
        +-- [setup-tool] ──────────── actionlint インストール (rhysd/actionlint)
        |
        +-- [actions/checkout] ─────── config-repo (aglabo/.github) を ./shared/ にチェックアウト
        |                              fetch-depth: 1, persist-credentials: false
        |
        +-- [actionlint 実行] ──────── デフォルト動作でワークフローファイルを検証
        |                              設定: shared/configs/actionlint.yaml
        |
        +-- [upload-artifact] ──────── エラー時のみ lint レポートをアップロード
```

---

## 3. Design Decisions

| ID    | Decision                                                                                                                                                                                         | Rationale                                                                                                            |
| ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------- |
| DR-01 | 外部 `aglabo/.github` への依存を排除し、ローカル reusable workflow として実装する                                                                                                                | 外部依存によるバージョン管理リスクと可用性問題を解消する                                                             |
| DR-02 | `workflow_call` トリガーのみをサポートする（`workflow_dispatch` は含めない）                                                                                                                     | lint ワークフローは CI トリガーからのみ呼び出すことを明確にする                                                      |
| DR-03 | ローカルの `validate-environment` および `setup-tool` action を使用する                                                                                                                          | 外部 action への依存を排除し、プラットフォーム内で完結させる                                                         |
| DR-04 | actionlint バイナリは `setup-tool` action で GitHub Releases からインストールする                                                                                                                | betterleaks と同一のツールインストールパターンを踏襲する                                                             |
| DR-05 | 設定リポジトリは `aglabo/.github` に固定して `./shared/` にチェックアウトする。設定ファイルパスは `config-file` 入力パラメータで指定し、デフォルト値は `./shared/configs/actionlint.yaml` とする | チェックアウト元を固定することで設定の一元管理を保証しつつ、`config-file` の上書きで別の設定ファイルも指定可能にする |
| DR-06 | lint エラー検出時はレポートファイルを生成してアーティファクトとしてアップロードする                                                                                                              | エラー内容を CI 外でも確認できるようにする                                                                           |
| DR-07 | ステップ間の条件は `steps.<id>.outcome == 'success'` パターンを使用する                                                                                                                          | プロジェクト規約（`outputs.status != 'error'` 禁止）に準拠する                                                       |
| DR-08 | `timeout-minutes`、`persist-credentials: false`、`permissions: contents: read` を明示的に設定する                                                                                                | ghalint の検証を通過し、セキュリティベストプラクティスに準拠する                                                     |

---

## 4. Functional Requirements

### REQ-F-001: 環境検証

**WHEN** ワークフローが開始されたとき、
**THE SYSTEM SHALL** `validate-environment` action を使用して runner と権限を検証する。
**IF** 検証が失敗した場合は後続ステップを実行しない。

### REQ-F-002: ツールインストール

**WHEN** 環境検証が成功したとき、
**THE SYSTEM SHALL** `setup-tool` action を使用して `rhysd/actionlint` の指定バージョンをインストールする。
**THE SYSTEM SHALL** デフォルトバージョン `1.7.12` を使用する（入力で上書き可能）。

### REQ-F-003: 設定リポジトリのチェックアウト

**WHEN** actionlint のインストールが成功したとき、
**THE SYSTEM SHALL** `aglabo/.github` を `./shared/` にチェックアウトする（リポジトリ固定）。
チェックアウト時は `fetch-depth: 1`、`persist-credentials: false` を設定する。

### REQ-F-003b: ワークフロー検証実行

**WHEN** 設定リポジトリのチェックアウトが成功したとき、
**THE SYSTEM SHALL** actionlint のデフォルト動作に従って対象ファイルを検証する。
**THE SYSTEM SHALL** `config-file` 入力パラメータで指定されたパスの設定ファイルを使用する。
デフォルト値は `./shared/configs/actionlint.yaml` とし、呼び出し元が別パスに上書き可能とする。

### REQ-F-004: lint 失敗時の即座の失敗

**WHEN** actionlint がエラーを検出したとき、
**THE SYSTEM SHALL** ワークフローを即座に失敗させる（exit code 1）。

### REQ-F-005: lint レポート出力

**WHEN** actionlint を実行したとき、
**THE SYSTEM SHALL** lint 結果を `.github/report/actionlint-report.txt` に出力する。

### REQ-F-006: エラー時のレポートアップロード

**WHEN** actionlint がエラーを検出したとき、
**THE SYSTEM SHALL** レポートファイルをアーティファクト `actionlint-report` としてアップロードする。
保持期間: 30 日間。

### REQ-F-007: ワークフロートリガー

**THE SYSTEM SHALL** `workflow_call` トリガーをサポートする。

### REQ-F-008: チェックアウト設定

**WHEN** リポジトリをチェックアウトするとき、
**THE SYSTEM SHALL** `persist-credentials: false` を設定する。

### REQ-F-009: ジョブタイムアウト

**THE SYSTEM SHALL** ジョブの `timeout-minutes` を `10` に固定する。
入力パラメータによる上書きは不可とする。

---

## 5. Non-Functional Requirements

### REQ-NF-001: 保守性

ワークフローの各ステップは単一責任を持ち、独立して理解・修正できること。

### REQ-NF-002: セキュリティ（最小権限）

ジョブの権限は `contents: read` のみとする。追加権限は付与しない。

### REQ-NF-003: 再現性

`actionlint-version` 入力によりバージョンを固定可能とし、CI の再現性を確保する。

### REQ-NF-004: 観察性

lint エラー発生時にレポートアーティファクトを通じて問題内容を確認できること。

### REQ-NF-005: 一貫性

betterleaks reusable workflow と同一のステップ構造・命名規則・条件分岐パターンを使用する。

---

## 6. Constraints

### REQ-C-001: ランナー

`ubuntu-slim`（セルフホスト）ランナーを使用する。

### REQ-C-002: 権限

ワークフローレベルおよびジョブレベルで `contents: read` を明示的に設定する。

### REQ-C-003: バージョン形式

`actionlint-version` 入力は `X.Y.Z` 形式（セマンティックバージョニング）とする。

### REQ-C-004: ローカルアクションのみ使用

ステップでは `validate-environment`、`setup-tool` のローカル composite action のみを使用する。
外部 GitHub Actions は `actions/checkout`、`actions/upload-artifact` のみ許可する。

### REQ-C-005: 設定ファイルパス

`config-file` 入力パラメータのデフォルト値は `./shared/configs/actionlint.yaml` とする。
呼び出し元が明示的に上書きすることで `./shared/` 配下の別パスを指定可能とする。
チェックアウト元リポジトリ（`aglabo/.github`）は固定であり入力パラメータによる変更は不可とする。

### REQ-C-006: ステップ条件

ステップの実行条件には `steps.<id>.outcome == 'success'` パターンを使用する。

### REQ-C-007: 認証情報の保持禁止

`actions/checkout` では `persist-credentials: false` を設定する。

### REQ-C-008: タイムアウト設定

ジョブの `timeout-minutes` は `10` に固定する。入力パラメータによる変更は不可。

---

## 7. User Stories

### US-001: プラットフォームエンジニア

**As** プラットフォームエンジニアとして、
**I want** actionlint の reusable workflow をローカルに実装したい、
**So that** 外部リポジトリへの依存なしに GitHub Actions 構文検証を CI に組み込める。

### US-002: リポジトリメンテナー

**As** リポジトリメンテナーとして、
**I want** `workflow_call` で actionlint を実行したい、
**So that** push や PR 時に自動で Actions ワークフローの構文エラーを検出できる。

### US-003: 開発者

**As** 開発者として、
**I want** lint エラー時にレポートをダウンロードしたい、
**So that** CI ログを参照せずにエラー詳細を確認できる。

### US-004: セキュリティエンジニア

**As** セキュリティエンジニアとして、
**I want** ワークフローが最小権限で動作することを確認したい、
**So that** CI パイプラインのセキュリティリスクを最小化できる。

---

## 8. Acceptance Criteria

### AC-001: Reusable Workflow が正常に実行される

```gherkin
Given リポジトリに .github/workflows/*.yml が存在する
And   configs/actionlint.yaml が存在する
When  workflow_call で ci-lint-actionlint.yml が呼び出される
Then  actionlint が .github/workflows/*.yml を検証する
And   lint エラーがなければワークフローが成功する
```

### AC-002: デフォルトバージョンが使用される

```gherkin
Given actionlint-version 入力が省略されている
When  ワークフローが実行される
Then  actionlint 1.7.12 がインストールされる
```

### AC-003: lint エラー時にワークフローが失敗する

```gherkin
Given .github/workflows/ 内にシンタックスエラーのある YAML が存在する
When  ワークフローが実行される
Then  actionlint がエラーを検出しワークフローが失敗する
And   レポートファイルがアーティファクトとしてアップロードされる
```

### AC-004: 環境検証失敗が後続ステップをブロックする

```gherkin
Given validate-environment が失敗する
When  ワークフローが実行される
Then  actionlint のインストールおよび実行ステップがスキップされる
```

### AC-005: カスタム設定ファイルが使用される

```gherkin
Given config-file 入力に "./configs/custom-actionlint.yaml" が指定されている
When  ワークフローが実行される
Then  actionlint がカスタム設定ファイルを使用して実行される
```

---

## 9. Open Questions

| ID    | Question                                                             | Status                                 |
| ----- | -------------------------------------------------------------------- | -------------------------------------- |
| OQ-01 | actionlint の出力形式（デフォルト出力 vs JSON 等）はどれを採用するか | 解決済み: テキスト形式（`.txt`）を採用 |
| OQ-02 | `workflow_dispatch` を将来的に追加する可能性はあるか                 | 未解決（現在は含めない）               |

---

## 10. Change History

| Version | Date       | Description                                                                                                                      |
| ------- | ---------- | -------------------------------------------------------------------------------------------------------------------------------- |
| 1.5     | 2026-06-12 | config-repo を aglabo/.github に固定（入力パラメータ廃止）、config-file のみ上書き可能に確定                                     |
| 1.4     | 2026-06-12 | config-file 入力パラメータ追加（デフォルト: shared/configs/actionlint.yaml）、config-repo チェックアウトと組み合わせる設計に確定 |
| 1.3     | 2026-06-12 | 設定ファイルを aglabo/.github から取得する方式に変更（betterleaks 同様の config-repo チェックアウト）                            |
| 1.2     | 2026-06-12 | timeout-minutes を固定値 10 分に変更（入力パラメータ廃止）                                                                       |
| 1.1     | 2026-06-12 | ghalint 対応要件追加: timeout-minutes, persist-credentials: false, permissions 明示                                              |
| 1.0     | 2026-06-12 | 初版作成（rev コマンドによるリバースエンジニアリング）                                                                           |
