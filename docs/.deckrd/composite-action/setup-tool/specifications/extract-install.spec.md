---
title: "Design Specification: Extract and Install"
based-on: requirements.md v1.0.5
status: Draft
---

<!-- textlint-disable ja-technical-writing/sentence-length, ja-technical-writing/max-comma -->
<!-- markdownlint-disable line-length -->

> Part of split specification. See `specifications-index.md` for full scope.

## 1. Overview

### 1.1 Purpose

SHA256 照合が成功した tar.gz アーカイブを展開し、指定ツールのバイナリを固定インストール先に配置して後続ステップから利用可能にする振る舞いルールを定義する。

### 1.2 Scope

本仕様は `extract-install` ステップの **振る舞いルール** と **バイナリ特定・配置セマンティクス** を定義する。実装詳細はスコープ外とする。

---

## 2. Design Principles

### 2.1 Classification Philosophy

バイナリのインストールは展開・特定・配置・PATH 追加の 4 フェーズで構成される。tar.gz 内のディレクトリ構造に依存せずバイナリを特定し、インストール先バイナリ名を `tool-name` に正規化することで再現性を保証する。

### 2.2 Design Assumptions

- verify-identity ステップ（SHA256 照合）が成功済みである
- tar.gz アーカイブには `tool-name` と一致するファイル名のバイナリが必ず 1 つ含まれる（前提）
- `${RUNNER_TEMP}/bin` ディレクトリは setup-directories ステップで作成済みである
- `GITHUB_PATH` はランナーが提供する特殊ファイルである

### 2.3 External Design Summary

> **Source**: Derived from the external design dialogue (Phase E) and user-confirmed design direction (Phase D).

#### Feature Decomposition

| Unit               | Responsibility                                                      | REQ Coverage            |
| ------------------ | ------------------------------------------------------------------- | ----------------------- |
| tar.gz 展開        | アーカイブを一時ディレクトリに展開する                               | REQ-F-006               |
| バイナリ特定       | 展開物から `tool-name` と一致するファイル（パスの末尾）を探す        | REQ-F-006               |
| バイナリ配置       | 特定したファイルを `${RUNNER_TEMP}/bin/<tool-name>` に 755 権限で置く | REQ-F-006, REQ-F-009   |
| PATH 追加          | `${RUNNER_TEMP}/bin` を GITHUB_PATH に書き込む                       | REQ-F-006               |

#### Unit Interaction Map

```text
[${TEMP_DIR}/asset.tar.gz]
          |
          v
+-------------------+
| tar.gz 展開       | --> [${TEMP_DIR}/extracted/]
+-------------------+
          |
          v
+-------------------+
| バイナリ特定       | <-- [tool-name]
| (ファイル名照合)   |
+-------------------+
          |
    見つからない → exit 4
          |
       見つかった
          v
+-------------------+
| バイナリ配置       | --> [${RUNNER_TEMP}/bin/<tool-name>]
| (install -m 755)  |     (755 権限)
+-------------------+
          |
          v
+-------------------+
| PATH 追加          | --> GITHUB_PATH へ書き込み
+-------------------+
```

#### Data Flow Diagram

```text
[asset.tar.gz] --> [展開] --> [${TEMP_DIR}/extracted/]
                                        |
                  [tool-name] --------> [バイナリ特定]
                                        |
                                   一致ファイル
                                        |
                                        v
                              [${RUNNER_TEMP}/bin/<tool-name>]
                                        |
                                        v
                                   GITHUB_PATH へ書き込み
```

### 2.4 Non-Goals

> **Derivation**: All items below originate from REQUIREMENTS Section "Out of Scope".

- zip 等 tar.gz 以外のアーカイブ形式への対応 ← REQ: Out of Scope (REQ-C-002)
- インストール先ディレクトリのカスタマイズ ← REQ: Out of Scope (REQ-F-009)
- パッケージマネージャ経由のインストール ← REQ: Out of Scope

### 2.5 Behavioral Design Decisions

| ID    | Decision                                                                  | Rationale                                                                     | Affected Rules | Status |
| ----- | ------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | -------------- | ------ |
| DD-01 | インストール先バイナリ名を `tool-name` に正規化する                        | tar.gz 内のディレクトリ構造に依存せず確実にインストールできる（例: `actionlint_1.7.10_linux_amd64/actionlint` → `actionlint`） | R-003          | Active |
| DD-02 | インストール先を `${RUNNER_TEMP}/bin` に固定し外部から変更不可とする       | システムディレクトリへの書き込みリスクを排除する                               | R-003, R-004   | Active |

### 2.6 Related Decision Records

| DR-ID | Title                                                          | Phase | Impact on This Spec                              |
| ----- | -------------------------------------------------------------- | ----- | ------------------------------------------------ |
| DR-04 | インストール先を `${RUNNER_TEMP}/bin` に固定（セキュリティ）    | req   | インストール先固定の根拠                         |

### 2.7 DD to DR Promotion Criteria

> **Purpose**: Guidelines for determining when a DD should be promoted to a formal DR.
> Promotion is a **human judgment** — these criteria inform, not automate.

DD-01 および DD-02 は DR-04 の実装詳細であるため、現時点では DD として維持する。

---

## 3. Behavioral Specification

### 3.1 Input Domain

- `asset_file`: `${TEMP_DIR}` 内の tar.gz ファイルへのパス
- `tool-name`: インストールするバイナリの名前（インストール後のファイル名に使用）
- `BIN_DIR`: `${RUNNER_TEMP}/bin` 固定値（外部から変更不可）
- `TEMP_DIR`: 展開先として使用する一時ディレクトリ

### 3.2 Output Semantics

- 成功: `${RUNNER_TEMP}/bin/<tool-name>` に 755 権限でバイナリが配置され、`${RUNNER_TEMP}/bin` が GITHUB_PATH に追加される（exit 0）
- tool-name 不一致: `::error::` プレフィックスのエラーメッセージを出力し、exit 4

---

## 4. Decision Rules

Evaluation MUST follow this order:

| Rule ID | Step | Condition                                                                   | Outcome                    |
| ------- | ---: | --------------------------------------------------------------------------- | -------------------------- |
| R-001   |    1 | `asset.tar.gz` を `${TEMP_DIR}` の展開先ディレクトリに展開する              | 展開ファイル群を確定        |
| R-002   |    2 | 展開物からファイル名（パスの末尾）が `tool-name` と一致するファイルを探す   | 候補ファイルを特定          |
| R-003   |    3 | 一致するファイルが存在しない                                                | exit 4                     |
| R-004   |    4 | 一致したファイルを `${RUNNER_TEMP}/bin/<tool-name>` に 755 権限でコピーする | バイナリを配置              |
| R-005   |    5 | `${RUNNER_TEMP}/bin` を GITHUB_PATH に書き込む                              | PATH への追加               |

No reordering is permitted.

<!-- impl-note: extract-install.sh を関数化し各ステップを独立してテスト可能にする -->
<!-- impl-note: バイナリ探索は `find "${EXTRACT_DIR}" -name "${TOOL_NAME}" -type f` 等で実現 -->
<!-- impl-note: `install -m 755 <src> <dst>` でコピーと権限設定を同時に行う -->

---

## 5. Edge Cases

| Input                                                                      | Classification | REQ       | Rationale                                                     |
| -------------------------------------------------------------------------- | -------------- | --------- | ------------------------------------------------------------- |
| tar.gz 内にネストされたディレクトリ構造（例: `actionlint_1.7.10_linux_amd64/actionlint`） | R-002 で特定成功 | REQ-F-006 | ファイル名のみで照合するため、ディレクトリ構造に依存しない |
| tar.gz 内に `tool-name` に一致するファイルが存在しない                       | R-003 失敗     | REQ-F-006 | 設定ミス（asset-template 誤り等）として exit 4              |
| 同一ジョブで action を 2 回呼び出す                                          | R-004 で上書き | REQ-F-006 | `${RUNNER_TEMP}/bin/<tool-name>` を上書きするため冪等         |
| 展開先に同名ファイルが既に存在する                                           | R-004 で上書き | REQ-F-006 | install コマンドによる上書きは正常動作                        |

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule    | Notes                                               |
| -------------- | ------------ | --------------------------------------------------- |
| REQ-F-006      | R-001〜R-005 | tar.gz 展開・バイナリ特定・配置・PATH 追加の全体    |
| REQ-F-009      | R-004        | インストール先 `${RUNNER_TEMP}/bin` 固定            |
| REQ-F-001      | —            | Covered in: `orchestration.spec.md`                 |
| REQ-F-004      | —            | Covered in: `verify-identity.spec.md`               |
| REQ-F-007      | —            | Covered in: `orchestration.spec.md`（outputs 提供） |

---

## 7. Open Questions

> **Status**: COMPLETE

None identified — all requirements are unambiguous.

---

## 8. Change History

| Date       | Version | Description           |
| ---------- | ------- | --------------------- |
| 2026-03-23 | 1.0.0   | Initial specification |
