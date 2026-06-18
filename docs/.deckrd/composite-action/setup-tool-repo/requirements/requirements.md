---
title: "Requirements: setup-tool-repo Composite Action"
module: "composite-action/setup-tool-repo"
status: Draft
version: 1.0.5
created: "2026-06-18"
updated: "2026-06-18"
---

> **Normative Statement**
> This document defines binding requirements.
> Implementations MUST conform to this document.
> RFC 2119 keywords apply to this document only.

## 1. Overview

### 1.1 Purpose

GitHub Actions ワークフロー内で、Node.js ベースのツール管理リポジトリ（例: `aglabo/agla-doc-tools`）を
指定ディレクトリにチェックアウトし、依存パッケージをインストールして、ツール群を後続ステップから
実行可能にするコンポジットアクションを提供する。

### 1.2 Scope

- パブリック GitHub リポジトリを指定ディレクトリに指定 ref でチェックアウトする
- Node.js および pnpm のセットアップをアクション内で実施する（バージョンは入力パラメータで指定可能）
- `pnpm install --frozen-lockfile` で依存パッケージをインストールする（pnpm 固定）
- リポジトリの `bin/` ディレクトリを `$GITHUB_PATH` に追加し、後続ステップからツールを実行可能にする
- post-install で `bin/` と `node_modules/.bin/` の存在および `bin/` の実行権限を検証する

**Out of Scope**:

- プライベートリポジトリへのアクセス（認証トークンは使用しない）
- macOS / Windows ランナーのサポート（Linux ubuntu runner のみ）
- チェックサム検証やセキュリティスキャン（呼び出し元ワークフロー側の責務）
- npm / yarn など pnpm 以外のパッケージマネージャーのサポート
- インストールキャッシュの提供（呼び出し元ワークフロー側の責務）

## 2. Context

- Target Environment: GitHub Actions ubuntu runner（Linux x86_64）
- Related Components:
  - `actions/checkout` — リポジトリチェックアウト
  - `actions/setup-node` — Node.js セットアップ
  - `pnpm/action-setup` — pnpm セットアップ
  - 既存コンポジットアクション `composite-action/setup-tool` — GitHub Releases からバイナリを取得する別アクション
- Assumptions:
  - 呼び出し元リポジトリは既にチェックアウト済みである
  - ツールリポジトリはパブリックリポジトリであり、デフォルトの `GITHUB_TOKEN` でアクセス可能である
  - ツールリポジトリは `package.json` および `pnpm-lock.yaml` をリポジトリルートに持つ
  - ツールリポジトリのルートに `bin/` ディレクトリが存在し、`node_modules/.bin` を内部で呼び出すラッパースクリプトが配置されている
  - `ref` には不変な参照（コミット SHA またはタグ）を指定することを推奨する（サプライチェーンリスク軽減）
  - `path` は `GITHUB_WORKSPACE` 配下の未使用ディレクトリを指定する

### System Context Diagram

```text
[GitHub Actions Workflow] --> +------------------------------------------+
                              |  setup-tool-repo Composite Action         |
[External Tool Repo] -------> |  1. actions/setup-node (node-version)     |
(public GitHub repo,          |  2. pnpm/action-setup (pnpm-version)      |
 e.g. aglabo/agla-doc-tools)  |  3. actions/checkout (repo, path, ref)    |
                              |  4. pnpm install --frozen-lockfile         |
                              |  5. verify bin/ + node_modules/.bin/       |
                              |  6. add <path>/bin/ to GITHUB_PATH         |
                              +------------------------------------------+
                                              |
                                             \|/
                              [Subsequent Steps: run tools via bin/]
```

## 3. Design Decisions (Summary)

| ID    | Decision                                                                              | Linked Record            |
| ----- | ------------------------------------------------------------------------------------- | ------------------------ |
| DR-01 | パブリックリポジトリのみ対応                                                          | decision-record.md#DR-01 |
| DR-02 | パッケージマネージャーは pnpm 固定                                                    | decision-record.md#DR-02 |
| DR-03 | Node.js / pnpm セットアップはアクション内で実施                                       | decision-record.md#DR-03 |
| DR-04 | PATH に追加するのは `bin/` のみ                                                       | decision-record.md#DR-04 |
| DR-05 | `ref` は必須パラメータとする                                                          | decision-record.md#DR-05 |
| DR-06 | Node.js / pnpm バージョンは入力パラメータで指定可能、デフォルト値をアクション側で定義 | decision-record.md#DR-06 |

## 4. Functional Requirements

### REQ-F-001: 外部リポジトリのチェックアウト

- EARS Type: event-driven

```text
GIVEN GitHub Actions ワークフローが setup-tool-repo アクションを呼び出した
  WHEN 入力パラメータ repo（owner/repo 形式）、path（チェックアウト先ディレクトリ）、
       ref（ブランチ/タグ/コミット SHA）がすべて指定された
THEN the system SHALL 指定した ref で外部リポジトリを指定パスにチェックアウトする。
```

**Rationale**: `ref` を必須にすることで、デフォルトブランチの予期しない変更による
サプライチェーンリスクを防ぐ。コミット SHA の使用を推奨する。

**Acceptance Criteria**:

| AC ID  | Scenario                                                                      |
| ------ | ----------------------------------------------------------------------------- |
| AC-001 | 有効な repo・path・ref を指定した場合、指定ディレクトリにチェックアウトされる |
| AC-002 | ref にコミット SHA を指定した場合、そのコミットがチェックアウトされる         |
| AC-003 | ref を省略した場合、アクションがエラーで失敗する                              |

### REQ-F-002: pnpm によるパッケージインストール

- EARS Type: feature/config-based

```text
GIVEN チェックアウトが完了した
  WHERE チェックアウト先ディレクトリに pnpm-lock.yaml が存在する
THEN the system SHALL pnpm install --frozen-lockfile を実行して依存パッケージをインストールする。
```

```text
GIVEN チェックアウトが完了した
  WHERE チェックアウト先ディレクトリに pnpm-lock.yaml が存在しない
THEN the system SHALL エラーメッセージを出力してアクションを失敗させる。
```

**Rationale**: パッケージマネージャーを pnpm に固定することで、ツールリポジトリの設計を
明確化する。`--frozen-lockfile` により lock ファイルとの整合性を保証し再現性を確保する。
`pnpm-lock.yaml` がない場合はリポジトリの設定ミスとみなしてフェイルファーストする。

**Acceptance Criteria**:

| AC ID  | Scenario                                                                      |
| ------ | ----------------------------------------------------------------------------- |
| AC-004 | pnpm-lock.yaml が存在する場合、pnpm install --frozen-lockfile が実行される    |
| AC-005 | pnpm-lock.yaml が存在しない場合、エラーメッセージとともにアクションが失敗する |

### REQ-F-003: インストール後の検証

- EARS Type: event-driven

```text
GIVEN パッケージのインストールが完了した
  WHEN インストール後の post-install 検証フェーズが実行された
THEN the system SHALL 以下をすべて確認し、いずれかが失敗した場合はエラーを出力して
     アクションを失敗させる:
     (1) <path>/bin/ ディレクトリが存在する
     (2) <path>/node_modules/.bin/ ディレクトリが存在する
     (3) <path>/bin/ 配下のすべてのファイルが実行権限（executable bit）を持つ
```

**Rationale**: `bin/` と `node_modules/.bin` の両方が揃って初めてツールが実行できる。
また実行権限がないラッパースクリプトはシェルから直接呼び出せないため、早期検証で
デプロイ後の実行失敗を防ぐ。

**Acceptance Criteria**:

| AC ID  | Scenario                                                                                |
| ------ | --------------------------------------------------------------------------------------- |
| AC-006 | bin/ と node_modules/.bin が両方存在し、bin/ 内ファイルに実行権限がある場合は続行される |
| AC-007 | node_modules/.bin が存在しない場合、エラーメッセージとともにアクションが失敗する        |
| AC-013 | bin/ が存在しない場合、エラーメッセージとともにアクションが失敗する                     |
| AC-014 | bin/ 配下のファイルに実行権限がない場合、エラーメッセージとともにアクションが失敗する   |

### REQ-F-004: bin/ ディレクトリの PATH 追加

- EARS Type: event-driven

```text
GIVEN bin/・node_modules/.bin/ の存在確認および bin/ の実行権限検証がすべて成功した
  WHEN アクションの PATH 追加フェーズが実行された
THEN the system SHALL チェックアウト先ディレクトリの bin/ を $GITHUB_PATH に追加し、
     後続ステップからツールが実行可能な状態にする。
```

**Rationale**: `bin/` 配下のラッパースクリプトを後続ステップのシェルから直接呼び出せるようにする。
`node_modules/.bin` は `bin/` が内部的に解決するため、PATH 追加は `bin/` のみとする。

**Acceptance Criteria**:

| AC ID  | Scenario                                                           |
| ------ | ------------------------------------------------------------------ |
| AC-008 | アクション完了後、後続ステップで bin/ 配下のツールが実行可能になる |
| AC-009 | $GITHUB_PATH に bin/ の絶対パスが追加されている                    |

### REQ-F-005: Node.js および pnpm のセットアップ

- EARS Type: event-driven

```text
GIVEN setup-tool-repo アクションが開始した
  WHEN チェックアウトおよびインストールの前に環境セットアップフェーズが実行された
THEN the system SHALL actions/setup-node で Node.js を、pnpm/action-setup で pnpm を
     セットアップする。入力パラメータ node-version および pnpm-version でバージョンを
     指定できるものとし、未指定時はアクション側で定義したデフォルト値を使用する。
```

**Rationale**: ランナーに pnpm がデフォルトでインストールされていない環境を想定し、
アクション内で pnpm のセットアップを保証する。バージョンを入力パラメータ化することで
呼び出し元が将来バージョンを固定できる柔軟性を持たせる。

**Acceptance Criteria**:

| AC ID  | Scenario                                                                          |
| ------ | --------------------------------------------------------------------------------- |
| AC-010 | アクション実行後、指定した pnpm バージョンのコマンドが利用可能になっている        |
| AC-011 | アクション実行後、指定した Node.js バージョンが利用可能になっている               |
| AC-012 | node-version・pnpm-version を省略した場合、アクション定義のデフォルト値が使われる |

## 5. Non-Functional Requirements

### REQ-NF-001: 再現性

インストールは `pnpm install --frozen-lockfile` を使用すること。
lock ファイルとの整合性が取れない場合はインストールを失敗させること。

### REQ-NF-002: 最小権限

アクションに必要な GitHub Actions permissions は `contents: read` のみとする。
`id-token: write` や `contents: write` を追加してはならない。

### REQ-NF-003: Fail-fast

各フェーズ（チェックアウト・インストール・検証）が失敗した場合、後続フェーズを実行せず
即座に明確なエラーメッセージとともにアクションを終了させること。

### REQ-NF-004: 保守性

スクリプトは既存の `composite-action/setup-tool` のライブラリ規約（`set -euo pipefail`、
double-source guard、フェーズ別 exit code）に準拠すること。

## 6. Constraints

### REQ-C-001: Linux ubuntu runner のみ対応

本アクションは GitHub Actions の ubuntu runner（Linux x86_64）のみを対象とする。
macOS および Windows ランナーはサポートしない。

### REQ-C-002: パブリックリポジトリのみ

認証トークンの入力パラメータは提供しない。プライベートリポジトリへのアクセスは対象外とする。
呼び出し元がプライベートリポジトリを使用する場合は、別途アクションを作成すること。

### REQ-C-003: bin/ ディレクトリの存在が前提

ツールリポジトリのルートに `bin/` ディレクトリが存在することを前提とする。
`bin/` が存在しない場合はエラーを出力してアクションを失敗させる。

### REQ-C-004: pnpm-lock.yaml の存在が前提

ツールリポジトリのルートに `pnpm-lock.yaml` が存在することを前提とする。
存在しない場合はリポジトリの設定ミスとみなしてアクションを失敗させる。

### REQ-C-005: repo パラメータのフォーマット

`repo` パラメータは `<owner>/<repo>` 形式（英数字・ハイフン・アンダースコア、スラッシュ1つ）でなければならない。
フォーマットが不正な場合はエラーを出力してアクションを失敗させる。

### REQ-C-006: path パラメータのフォーマット

`path` パラメータは `./` で始まる相対パス、または `/` で始まる絶対パスのいずれかでなければならない。
それ以外の形式（例: `tools/agla`、`../foo`）はエラーを出力してアクションを失敗させる。

## 7. User Stories

| Story ID | Role             | Goal                                                    | Reason                                                      | Related Requirements  |
| -------- | ---------------- | ------------------------------------------------------- | ----------------------------------------------------------- | --------------------- |
| US-001   | ワークフロー作者 | ツールリポジトリを1ステップでセットアップしたい         | ワークフローの記述量を削減するため                          | REQ-F-001, REQ-F-002  |
| US-002   | ワークフロー作者 | 特定バージョンのツールリポジトリを固定して使いたい      | CI の再現性を保証するため                                   | REQ-F-001             |
| US-003   | ワークフロー作者 | インストール後に即座にツールを呼び出したい              | 追加の PATH 設定なしにツールを使いたいため                  | REQ-F-004             |
| US-004   | CI メンテナー    | pnpm ベースのツールリポジトリを確実にセットアップしたい | pnpm-lock.yaml による再現性の高いインストールを保証するため | REQ-F-002, REQ-NF-001 |
| US-005   | CI メンテナー    | インストール失敗を早期に検知したい                      | デバッグ時間を削減するため                                  | REQ-F-003, REQ-NF-003 |

## 8. Acceptance Criteria

```gherkin
# AC-001: 有効な repo と path を指定してチェックアウトが成功する
# Requirement: REQ-F-001
Scenario: 有効な repo と path を指定してチェックアウトが成功する
  Given GitHub Actions ワークフローが setup-tool-repo アクションを呼び出す
  When repo="aglabo/agla-doc-tools" path="./tools/agla" ref="v1.0.0" を入力として渡す
  Then "./tools/agla" ディレクトリにリポジトリがチェックアウトされる

# AC-002: ref を指定した場合に特定バージョンがチェックアウトされる
# Requirement: REQ-F-001
Scenario: ref を指定して特定タグがチェックアウトされる
  Given setup-tool-repo アクションを呼び出す
  When repo="aglabo/agla-doc-tools" path="./tools/agla" ref="v1.2.3" を渡す
  Then "./tools/agla" に v1.2.3 タグのコードがチェックアウトされる

# AC-004: pnpm-lock.yaml が存在する場合 pnpm install が実行される
# Requirement: REQ-F-002
Scenario: pnpm-lock.yaml があるリポジトリで pnpm install が実行される
  Given チェックアウト先に pnpm-lock.yaml が存在する
  When インストールフェーズが実行される
  Then pnpm install が実行されて node_modules が作成される

# AC-007: node_modules/.bin が存在しない場合アクションが失敗する
# Requirement: REQ-F-003
Scenario: node_modules/.bin が存在しない場合アクションが失敗する
  Given インストールが完了したが node_modules/.bin が存在しない
  When post-install 検証フェーズが実行される
  Then アクションがエラーメッセージとともに非ゼロ exit code で終了する

# AC-008: アクション完了後に後続ステップでツールが実行可能になる
# Requirement: REQ-F-004
Scenario: bin/ が PATH に追加されてツールが実行可能になる
  Given setup-tool-repo アクションが正常に完了した
  When 後続ステップでツール名をコマンドとして実行する
  Then ツールが正常に起動する

# AC-015: repo が不正フォーマットの場合アクションが失敗する
# Requirement: REQ-C-005
Scenario: repo に owner/repo 形式でない値を指定した場合アクションが失敗する
  Given setup-tool-repo アクションを呼び出す
  When repo="agla-doc-tools"（スラッシュなし）を渡す
  Then アクションがエラーメッセージとともに非ゼロ exit code で終了する

# AC-016: path が不正フォーマットの場合アクションが失敗する
# Requirement: REQ-C-006
Scenario: path に ./ でも / でも始まらない値を指定した場合アクションが失敗する
  Given setup-tool-repo アクションを呼び出す
  When path="tools/agla"（./ も / も始まらない）を渡す
  Then アクションがエラーメッセージとともに非ゼロ exit code で終了する
```

## 9. Open Questions

| Question                                                                                      | Type   | Impact Area          | Owner | Status    |
| --------------------------------------------------------------------------------------------- | ------ | -------------------- | ----- | --------- |
| OQ-001: bin/ が存在しない場合エラーにするか → **エラーで失敗させる**                          | Design | REQ-F-004, REQ-C-003 | —     | ✅ Closed |
| OQ-002: Node.js バージョンを入力パラメータで指定できるようにするか → **可能、デフォルトあり** | Scope  | REQ-F-005            | —     | ✅ Closed |
| OQ-003: pnpm バージョンを入力パラメータで指定できるようにするか → **可能、デフォルトあり**    | Scope  | REQ-F-005            | —     | ✅ Closed |
| OQ-004: インストール時のキャッシュ（actions/cache）をアクション内で提供するか                 | Scope  | REQ-NF-001           | TBD   | Open      |
| OQ-005: pnpm install --frozen-lockfile は必須か → **必須（固定）**                            | Design | REQ-NF-001           | —     | ✅ Closed |
| OQ-006: `ref` 未指定時の挙動 → **エラーで失敗させる（ref は必須）**                           | Design | REQ-F-001            | —     | ✅ Closed |

## 10. Traceability

| REQ ID     | AC IDs                         | Type           |
| ---------- | ------------------------------ | -------------- |
| REQ-F-001  | AC-001, AC-002, AC-003         | Functional     |
| REQ-F-002  | AC-004, AC-005                 | Functional     |
| REQ-F-003  | AC-006, AC-007, AC-013, AC-014 | Functional     |
| REQ-F-004  | AC-008, AC-009                 | Functional     |
| REQ-F-005  | AC-010, AC-011, AC-012         | Functional     |
| REQ-NF-001 | N/A                            | Non-Functional |
| REQ-NF-002 | N/A                            | Non-Functional |
| REQ-NF-003 | N/A                            | Non-Functional |
| REQ-NF-004 | N/A                            | Non-Functional |
| REQ-C-001  | N/A                            | Constraint     |
| REQ-C-002  | N/A                            | Constraint     |
| REQ-C-003  | N/A                            | Constraint     |
| REQ-C-004  | N/A                            | Constraint     |
| REQ-C-005  | AC-015                         | Constraint     |
| REQ-C-006  | AC-016                         | Constraint     |

## 11. Change History

| Date       | Version | Description                                                                                |
| ---------- | ------- | ------------------------------------------------------------------------------------------ |
| 2026-06-18 | 1.0.0   | Initial release                                                                            |
| 2026-06-18 | 1.0.1   | ref 必須化、pnpm 固定、Node.js/pnpm バージョンパラメータ化（Codex review 反映）            |
| 2026-06-18 | 1.0.2   | REQ-F-003 拡張: bin/ 存在確認・node_modules/.bin 存在確認・実行権限チェックを追加          |
| 2026-06-18 | 1.0.3   | review explore 反映: Section 1.2・図・US-004 を pnpm 固定設計に整合                        |
| 2026-06-18 | 1.0.4   | REQ-C-005 追加: repo は owner/repo 形式必須、REQ-C-006 追加: path は ./ または絶対パス必須 |
| 2026-06-18 | 1.0.5   | review explore 反映: AC-001/002 の path 修正、REQ-F-004 GIVEN 更新、AC-015/016 追加        |
