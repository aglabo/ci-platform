---
title: "Design Specification: URL Builder"
based-on: requirements.md v1.0.5
status: Draft
---

<!-- textlint-disable ja-technical-writing/sentence-length, ja-technical-writing/max-comma -->
<!-- markdownlint-disable line-length -->

> Part of split specification. See `specifications-index.md` for full scope.

## 1. Overview

### 1.1 Purpose

action 入力のテンプレート文字列と解決済み環境変数から、ダウンロード URL・チェックサム URL・ファイル名を動的に生成する振る舞いルールを定義する。

### 1.2 Scope

本仕様は `url-builder` の **振る舞いルール** と **テンプレート解決セマンティクス** を定義する。実装詳細はスコープ外とする。

---

## 2. Design Principles

### 2.1 Classification Philosophy

URL 組み立てはテンプレート内のプレースホルダを解決済み変数で置換する変換処理である。解決ルールは決定論的であり、同一入力に対して常に同一の出力を返す。`tool-version` は validate-inputs ステップで X.Y.Z 形式（v プレフィックスなし）に確定済みであり、URL 組み立て時に `v` プレフィックスを付与する。

### 2.2 Design Assumptions

- `{os}` および `{arch_suffix}` は resolve-env ステップで確定済みである
- `tool-version` は validate-inputs ステップで X.Y.Z 形式（v プレフィックスなし）に確定済みである。URL 組み立て時に `v` プレフィックスを付与する責務はこのステップが持つ
- `checksum-template` が省略された場合は `checksums.txt` を使用する（REQ-F-003）
- URL の生成元は GitHub Releases のみ（REQ-C-003）

### 2.3 External Design Summary

> **Source**: Derived from the external design dialogue (Phase E) and user-confirmed design direction (Phase D).

#### Feature Decomposition

| Unit                     | Responsibility                                              | REQ Coverage  |
| ------------------------ | ----------------------------------------------------------- | ------------- |
| asset ファイル名生成      | `asset-template` のプレースホルダを解決してファイル名を返す  | REQ-F-002     |
| checksum ファイル名生成   | `checksum-template` のプレースホルダを解決してファイル名を返す | REQ-F-003   |
| ダウンロード URL 生成     | asset ファイル名から GitHub Releases URL を組み立てる        | REQ-F-002     |
| チェックサム URL 生成     | checksum ファイル名から GitHub Releases URL を組み立てる     | REQ-F-002     |

#### Unit Interaction Map

```text
[tool-version]
      |
      v
[バージョン正規化]   [tool-name, os, arch_suffix]
      |                        |
      +-----------+------------+
                  |
                  v
        +------------------+
        | asset ファイル名  | <-- [asset-template]
        | 生成              |
        +------------------+
                  |
                  v
        +------------------+
        | ダウンロード URL  | <-- [repo, normalized_version]
        | 生成              |
        +------------------+

[checksum-template] --> [checksum ファイル名生成] --> [チェックサム URL 生成]
```

#### Data Flow Diagram

```text
[asset-template]
[tool-name, tool-version, os, arch_suffix]
       |
       v
[プレースホルダ解決] --> [asset_filename]
                                |
                                v
[repo, v{normalized_version}] --> [DOWNLOAD_URL]

[checksum-template (or "checksums.txt")]
[tool-name, tool-version, arch_suffix]
       |
       v
[プレースホルダ解決] --> [checksum_filename]
                                |
                                v
[repo, v{normalized_version}] --> [CHECKSUM_URL]
```

### 2.4 Non-Goals

> **Derivation**: All items below originate from REQUIREMENTS Section "Out of Scope".

- URL 組み立てロジックのインライン実装（ライブラリへの委譲）← REQ: Out of Scope
- GitHub Releases 以外のダウンロード元への対応 ← REQ: Out of Scope (REQ-C-003)
- `v` プレフィックスなしタグを使用するツールへの対応 ← REQ: Out of Scope (REQ-C-003)

### 2.5 Behavioral Design Decisions

| ID    | Decision                                                                      | Rationale                                                               | Affected Rules | Status |
| ----- | ----------------------------------------------------------------------------- | ----------------------------------------------------------------------- | -------------- | ------ |
| DD-01 | URL に `v{normalized_version}` 形式を使用し `v` プレフィックスを URL 生成時に付与 | validate-inputs で `v` プレフィックスなし X.Y.Z 形式が確定しており、URL 組み立て時に `v` を付与することで責務を明確に分離する | R-003, R-005 | Active |
| DD-02 | テンプレート内の未定義プレースホルダは空文字に置換（エラーにしない）            | テンプレート設計の柔軟性を確保。必要な検証は validate-inputs ステップが担う | R-002          | Active |

### 2.6 Related Decision Records

| DR-ID | Title                                                  | Phase | Impact on This Spec                          |
| ----- | ------------------------------------------------------ | ----- | -------------------------------------------- |
| DR-05 | URL 組み立てロジックを url-builder ライブラリとして分離 | req   | url-builder が URL 組み立ての唯一の責務を持つ |
| DR-02 | checksum_template デフォルトは `checksums.txt`         | req   | checksum-template 省略時の挙動を規定         |

### 2.7 DD to DR Promotion Criteria

> **Purpose**: Guidelines for determining when a DD should be promoted to a formal DR.
> Promotion is a **human judgment** — these criteria inform, not automate.

DD-01 の `v{normalized_version}` 方式は他ツール対応時にも影響する可能性があり、DR 昇格を検討する余地がある。

---

## 3. Behavioral Specification

### 3.1 Input Domain

- `tool-name`: 検証済みの識別子文字列
- `tool-version`: validate-inputs で検証済みの X.Y.Z 形式文字列（v プレフィックスなし確定）
- `repo`: `org/repo` 形式の文字列
- `asset-template`: `{tool_name}`, `{tool_version}`, `{os}`, `{arch_suffix}` を含みうるテンプレート文字列
- `checksum-template`: テンプレート文字列。省略時は `"checksums.txt"` を使用
- `os`: resolve-env ステップで解決済みの `"linux"` 固定値
- `arch_suffix`: resolve-env ステップで解決済みの `"amd64"` または `"arm64"`

### 3.2 Output Semantics

- `asset_filename`: asset-template を解決した文字列
- `checksum_filename`: checksum-template を解決した文字列
- `DOWNLOAD_URL`: `https://github.com/{repo}/releases/download/v{X.Y.Z}/{asset_filename}`
- `CHECKSUM_URL`: `https://github.com/{repo}/releases/download/v{X.Y.Z}/{checksum_filename}`

ここで `{X.Y.Z}` は validate-inputs で `normalize_version()` により確定済みの X.Y.Z 形式値（`v` プレフィックスなし）。

---

## 4. Decision Rules

Evaluation MUST follow this order:

| Rule ID | Step | Condition                                    | Outcome                                        |
| ------- | ---: | -------------------------------------------- | ---------------------------------------------- |
| R-001   |    1 | `checksum-template` が省略または空            | `checksum-template = "checksums.txt"` として扱う |
| R-002   |    2 | テンプレート内のプレースホルダを該当値で置換  | 未定義プレースホルダは空文字で置換               |
| R-003   |    3 | `tool-version`（X.Y.Z 形式確定済み）に `v` プレフィックスを付与して URL 用バージョン文字列を生成 | `v{X.Y.Z}` を確定 |
| R-004   |    4 | `asset_filename` を生成（R-002 の解決済みテンプレート） | asset ファイル名文字列を出力              |
| R-005   |    5 | `DOWNLOAD_URL` を `https://github.com/{repo}/releases/download/v{normalized_version}/{asset_filename}` で生成 | URL 文字列を出力 |
| R-006   |    6 | `checksum_filename` を生成（R-001 適用後のテンプレートから） | checksum ファイル名文字列を出力          |
| R-007   |    7 | `CHECKSUM_URL` を `https://github.com/{repo}/releases/download/v{normalized_version}/{checksum_filename}` で生成 | URL 文字列を出力 |

No reordering is permitted.

<!-- impl-note: url-builder.lib.sh の build_asset_filename(), build_checksum_filename(), build_download_url(), build_checksum_url() を使用 -->
<!-- impl-note: バージョン正規化は common.lib.sh の normalize_version() を使用 -->

---

## 5. Edge Cases

| Input                                                                | Classification    | REQ       | Rationale                                                        |
| -------------------------------------------------------------------- | ----------------- | --------- | ---------------------------------------------------------------- |
| `tool-version="1.7.10"` → URL に `v1.7.10`                          | R-003 適用        | REQ-F-002 | validate で確定済み X.Y.Z に v を付与                            |
| `checksum-template` 省略 → `checksums.txt`                           | R-001 適用        | REQ-F-003 | デフォルト動作                                                   |
| `asset-template="{tool_name}_{tool_version}_linux_{arch_suffix}.tar.gz"`, `tool-name=actionlint`, `tool-version=1.7.10`, `arch_suffix=amd64` → `actionlint_1.7.10_linux_amd64.tar.gz` | R-002, R-004 適用 | REQ-F-002 | 標準的なテンプレート解決（{tool_version} は v なし X.Y.Z）|

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule         | Notes                                       |
| -------------- | ----------------- | ------------------------------------------- |
| REQ-F-002      | R-002, R-004, R-005 | URL 組み立てとテンプレート解決の全体        |
| REQ-F-003      | R-001, R-006, R-007 | checksum-template デフォルト動作            |
| REQ-F-001      | —                 | Covered in: `orchestration.spec.md`（OS/arch 解決） |
| REQ-F-004      | —                 | Covered in: `verify-identity.spec.md`       |
| REQ-F-010      | —                 | Covered in: `validate.spec.md`              |
| REQ-F-011      | —                 | Covered in: `validate.spec.md`              |

---

## 7. Open Questions

> **Status**: COMPLETE

None identified — all requirements are unambiguous.

---

## 8. Change History

| Date       | Version | Description           |
| ---------- | ------- | --------------------- |
| 2026-03-23 | 1.0.0   | Initial specification |
| 2026-03-23 | 1.1.0   | tool-version 責務変更: validate で normalize_version() 確定済み X.Y.Z を受け取る設計に変更。DD-01 Rationale 更新、Output Semantics 更新、Edge Cases を確定済み X.Y.Z 入力前提に刷新 |
