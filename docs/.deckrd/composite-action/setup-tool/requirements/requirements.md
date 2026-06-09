---
title: "Requirements: setup-tool composite action"
module: "composite-action/setup-tool"
status: Draft
version: 1.0
created: "2026-06-07"
---

<!-- cspell:words rhysd -->
<!-- markdownlint-disable line-length -->

## 1. Overview

### 1.1 Purpose

GitHub Actions の composite action として、指定された GitHub リポジトリのリリースから
ツールをダウンロードし、チェックサム検証・アーカイブ展開を行い、
ツールバイナリを実行可能な PATH に配置する。

### 1.2 Scope

- 呼び出し元ワークフローから `repo`（`owner/repo` 形式）・`tool-name`・`tool-version` を受け取り、
  GitHub Releases から tar.gz アーカイブをダウンロードする
- `runner.arch` から CPU アーキテクチャを自動検出する
- sha256 チェックサム検証を必須で実施する
- tar.gz を展開し、バイナリを `RUNNER_TEMP/bin` に配置して `PATH` に追加する
- Linux（ubuntu runner）のみを対象とする

**Out of Scope**:

- `zip` など tar.gz 以外のアーカイブ形式への対応
- macOS・Windows runner への対応
- チェックサム検証のスキップオプション
- GitHub Releases 以外のダウンロード元への対応

## 2. Context

- Target Environment: GitHub Actions ubuntu runner（Linux x86_64 / ARM64）
- Related Components:
  - `.github/actions/setup-tool/scripts/setup-directories.sh`
  - `.github/actions/setup-tool/scripts/download-tool.sh`
  - `.github/actions/setup-tool/scripts/verify-checksum.sh`
  - `.github/actions/setup-tool/scripts/extract-install.sh`
  - `.github/actions/setup-tool/scripts/cleanup.sh`
  - `.github/actions/setup-tool/scripts/_libs/common.lib.sh`
  - `.github/actions/setup-tool/scripts/_libs/validation.lib.sh`
- Assumptions:
  - GitHub Releases の URL パターンは `{owner}/{repo}/releases/download/v{version}/{tool-name}_{version}_linux_{arch}.tar.gz`
  - checksums.txt が同じリリースに存在する
  - runner は curl および sha256sum を利用可能

### System Context Diagram

```text
[Workflow Caller] --> +----------------------------+ --> [GitHub Releases API]
  (repo,             |   setup-tool               |     (tar.gz + checksums.txt)
   tool-name,        |   composite action         |
   tool-version)     +----------------------------+ --> [Tool Binary]
                             |                              (RUNNER_TEMP/bin,
                      [runner.arch]                          added to PATH)
                      (auto-detected)
```

## 3. Design Decisions (Summary)

| ID    | Decision                                                 | Linked Record            |
| ----- | -------------------------------------------------------- | ------------------------ |
| DR-01 | アーキテクチャは runner.arch から自動検出                | decision-record.md#DR-01 |
| DR-02 | チェックサム検証は必須（スキップ不可）                   | decision-record.md#DR-02 |
| DR-03 | Linux (tar.gz) のみ対応                                  | decision-record.md#DR-03 |
| DR-04 | repo は owner/repo 形式で呼び出し元が明示                | decision-record.md#DR-04 |
| DR-05 | 既存スクリプト群を廃止し、関数ライブラリ式で新規実装する | decision-record.md#DR-05 |

## 4. Functional Requirements

### REQ-F-001: 入力パラメータ検証

- EARS Type: event-driven

```text
GIVEN composite action が呼び出された
  WHEN repo・tool-name・tool-version が渡された
THEN the system SHALL 各パラメータが非空かつ有効な形式であることを検証し、
     不正な場合はエラーメッセージを出力してステップを失敗させる。
```

**Rationale**: 不正な入力値による後続ステップの予期しない失敗を防ぐ。

**Acceptance Criteria**:

| AC ID  | Scenario                                        |
| ------ | ----------------------------------------------- |
| AC-001 | 有効なパラメータ → 検証通過                     |
| AC-002 | tool-name が空文字 → エラー出力してステップ失敗 |

### REQ-F-002: アーキテクチャ自動検出

- EARS Type: event-driven

```text
GIVEN composite action が呼び出された
  WHEN ステップが実行される
THEN the system SHALL runner.arch の値から CPU アーキテクチャ文字列（x64→amd64, arm64→arm64）を
     自動的にマッピングし、ダウンロード URL の構築に使用する。
```

**Rationale**: 呼び出し元がアーキテクチャを意識せずに利用できる。

**Acceptance Criteria**:

| AC ID  | Scenario                                     |
| ------ | -------------------------------------------- |
| AC-003 | runner.arch=X64 → amd64 にマッピングされる   |
| AC-004 | runner.arch=ARM64 → arm64 にマッピングされる |

### REQ-F-003: ツールダウンロード

- EARS Type: event-driven

```text
GIVEN 入力パラメータが検証済みでアーキテクチャが決定されている
  WHEN ダウンロードステップが実行される
THEN the system SHALL GitHub Releases から tar.gz アーカイブと checksums.txt を
     一時ディレクトリにダウンロードする。
```

**Rationale**: 安定した再現可能なツール取得を実現する。

**Acceptance Criteria**:

| AC ID  | Scenario                                                            |
| ------ | ------------------------------------------------------------------- |
| AC-005 | 有効なリポジトリ・バージョン → ファイルが一時ディレクトリに存在する |
| AC-006 | 存在しないバージョン → curl がエラーで失敗する                      |

### REQ-F-004: チェックサム検証

- EARS Type: event-driven

```text
GIVEN tar.gz と checksums.txt がダウンロード済みである
  WHEN チェックサム検証ステップが実行される
THEN the system SHALL sha256sum でダウンロードファイルのハッシュを検証し、
     不一致の場合はエラーを出力してステップを失敗させる。
```

**Rationale**: ダウンロードファイルの完全性と真正性を保証する。

**Acceptance Criteria**:

| AC ID  | Scenario                                              |
| ------ | ----------------------------------------------------- |
| AC-007 | ハッシュ一致 → 検証通過                               |
| AC-008 | ファイルが破損（ハッシュ不一致） → エラー出力して失敗 |

### REQ-F-005: アーカイブ展開とバイナリ配置

- EARS Type: event-driven

```text
GIVEN チェックサム検証が成功している
  WHEN 展開・配置ステップが実行される
THEN the system SHALL tar.gz を展開し、ツールバイナリを RUNNER_TEMP/bin に配置して
     実行権限（755）を付与し、PATH に追加する。
```

**Rationale**: 後続ステップからツールを直接呼び出せるようにする。

**Acceptance Criteria**:

| AC ID  | Scenario                                              |
| ------ | ----------------------------------------------------- |
| AC-009 | 展開・配置後 → tool-name コマンドが PATH から実行可能 |
| AC-010 | バイナリに実行権限 755 が付与されている               |

### REQ-F-006: 一時ファイルのクリーンアップ

- EARS Type: state-driven

```text
GIVEN composite action のすべてのステップが完了した（成功・失敗問わず）
  WHILE if: always() 条件が成立している
THEN the system SHALL 一時ディレクトリ（TEMP_DIR）を削除する。
```

**Rationale**: ランナーのディスク容量を消費しないようにする。

**Acceptance Criteria**:

| AC ID  | Scenario                                          |
| ------ | ------------------------------------------------- |
| AC-011 | 正常完了後 → 一時ディレクトリが存在しない         |
| AC-012 | 中間ステップ失敗後 → 一時ディレクトリが存在しない |

## 5. Non-Functional Requirements

### REQ-NF-001: セキュリティ

チェックサム検証は SHA256 を使用し、検証失敗時は必ずステップを失敗させる。
バイナリのパーミッションは 755 とし、不要な書き込み権限を付与しない。

### REQ-NF-002: 冪等性

同じパラメータで複数回実行した場合、同じ結果を得られる。

### REQ-NF-003: Maintainability

各処理（ディレクトリ準備・ダウンロード・検証・展開・クリーンアップ）は
独立したスクリプトに分離する。

### REQ-NF-004: Testability

各スクリプトは ShellSpec によるユニットテストが可能な構造とする。

## 6. Constraints

### REQ-C-001: 実行環境

GitHub Actions ubuntu runner（Linux）上でのみ動作を保証する。
macOS・Windows runner は対象外。

### REQ-C-002: アーカイブ形式

tar.gz 形式のみ対応する。zip など他の形式は対象外。

### REQ-C-003: チェックサム検証必須

チェックサム検証をスキップするオプションは提供しない。

### REQ-C-004: GitHub Releases URL パターン

ダウンロード URL は以下のパターンに従う:
`https://github.com/{owner}/{repo}/releases/download/v{version}/{tool-name}_{version}_linux_{arch}.tar.gz`

### REQ-C-005: 関数ライブラリ式の新規実装

既存の個別スクリプト（`setup-directories.sh`, `download-tool.sh`, `verify-checksum.sh`,
`extract-install.sh`, `cleanup.sh`）を参考実装として扱い、新規実装を作成する。
各処理（ディレクトリ準備・URL構築・ダウンロード・検証・展開・配置・クリーンアップ）は
ファイル分割の有無に関わらず、関数として定義し関数呼び出しで構造化する。
コードは読みやすさを優先し、処理の意図が関数名と呼び出し順から明確に読み取れる構成とする。

## 7. User Stories

- As a CI engineer, I want to install a specific version of a tool in a GitHub Actions workflow. Because I want reproducible builds.
- As a CI engineer, I want the architecture to be auto-detected. Because I don't want to hardcode platform-specific values in each workflow.
- As a security engineer, I want checksum verification to be mandatory. Because I want to ensure the integrity of downloaded binaries.
- As a workflow author, I want cleanup to run even on failure. Because I want to avoid leaving temporary files on the runner.
- As a workflow author, I want to specify the tool repository as owner/repo. Because it uniquely identifies the source of the binary.

## 8. Acceptance Criteria

```gherkin
# AC-001: 有効なパラメータで検証が通過する
# Requirement: REQ-F-001
Scenario: 有効なパラメータで検証が通過する
  Given composite action が repo="rhysd/actionlint" tool-name="actionlint" tool-version="1.7.7" で呼び出された
  When 入力検証ステップが実行される
  Then ステップが成功する

# AC-007: チェックサムが一致する場合に検証が通過する
# Requirement: REQ-F-004
Scenario: チェックサムが一致する場合に検証が通過する
  Given checksums.txt とアーカイブが一時ディレクトリにダウンロードされている
  When チェックサム検証ステップが実行される
  Then ステップが成功する

# AC-009: ツールバイナリが PATH から実行可能になる
# Requirement: REQ-F-005
Scenario: ツールバイナリが PATH から実行可能になる
  Given アーカイブが展開・配置済みである
  When 後続ステップで tool-name コマンドを実行する
  Then コマンドが正常に起動する

# AC-008: ハッシュ不一致でステップが失敗する
# Requirement: REQ-F-004
Scenario: ハッシュ不一致でステップが失敗する
  Given 破損したアーカイブが一時ディレクトリにある
  When チェックサム検証ステップが実行される
  Then ステップがエラーメッセージを出力して失敗する

# AC-012: 中間ステップ失敗後でもクリーンアップが実行される
# Requirement: REQ-F-006
Scenario: 中間ステップ失敗後でもクリーンアップが実行される
  Given ダウンロードステップが失敗した
  When クリーンアップステップが if: always() で実行される
  Then 一時ディレクトリが削除されている
```

## 9. Open Questions

| Question                                                                | Type       | Impact Area     | Owner |
| ----------------------------------------------------------------------- | ---------- | --------------- | ----- |
| runner.arch に X64/ARM64 以外の値が来た場合の動作を定義する必要があるか | EARS/GIVEN | REQ-F-002 scope | TBD   |
| tool-version に "latest" などの動的な値を許容するか                     | scope      | REQ-F-001       | TBD   |
| checksums.txt が存在しないリリースへの対処は必要か                      | scope      | REQ-F-004       | TBD   |

## 10. Traceability

| REQ ID     | AC IDs         | Type           |
| ---------- | -------------- | -------------- |
| REQ-F-001  | AC-001, AC-002 | Functional     |
| REQ-F-002  | AC-003, AC-004 | Functional     |
| REQ-F-003  | AC-005, AC-006 | Functional     |
| REQ-F-004  | AC-007, AC-008 | Functional     |
| REQ-F-005  | AC-009, AC-010 | Functional     |
| REQ-F-006  | AC-011, AC-012 | Functional     |
| REQ-NF-001 | —              | Non-Functional |
| REQ-NF-002 | —              | Non-Functional |
| REQ-NF-003 | —              | Non-Functional |
| REQ-NF-004 | —              | Non-Functional |
| REQ-C-001  | —              | Constraint     |
| REQ-C-002  | —              | Constraint     |
| REQ-C-003  | —              | Constraint     |
| REQ-C-004  | —              | Constraint     |
| REQ-C-005  | —              | Constraint     |

## 11. Change History

| Date       | Version | Description     |
| ---------- | ------- | --------------- |
| 2026-06-07 | 1.0.0   | Initial release |
