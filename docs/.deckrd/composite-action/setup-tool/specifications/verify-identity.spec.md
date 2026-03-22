---
title: "Design Specification: Verify Identity"
based-on: requirements.md v1.0.5
status: Draft
---

<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/max-comma -->
<!-- markdownlint-disable line-length -->

> Part of split specification. See `specifications-index.md` for full scope.

## 1. Overview

### 1.1 Purpose

ダウンロード済みのバイナリが改ざんされていないことを SHA256 チェックサムで照合する振る舞いルールを定義する。照合に失敗した場合は後続のインストールステップを実行させない。

> **Note**: v1.x では SHA256 チェックサム照合のみを実装する。署名検証（supply chain attack 対策の第二層）は信頼アンカー設計（公開鍵配布元・署名対象・鍵ローテーション）が未解決のため次 Version へ繰り延べる（REQ-F-012 Rationale 参照）。

### 1.2 Scope

本仕様は `verify-identity` ステップの **振る舞いルール** と **SHA256 照合セマンティクス** を定義する。実装詳細はスコープ外とする。

---

## 2. Design Principles

### 2.1 Classification Philosophy

バイナリの同一性検証は checksums ファイルのパース・ハッシュ取得・照合の 3 ステップで構成される。各ステップは独立した責務を持ち、前のステップが成功した場合のみ次のステップへ進む。

### 2.2 Design Assumptions

- checksums ファイルは `<hash>  <filename>` 形式（sha256sum 標準出力形式、スペース 2 個区切り）のみを対象とする
- `sha256sum` コマンドが Linux ランナーで利用可能である（REQ-C-001）
- ダウンロードステップ完了後、`${TEMP_DIR}` に asset ファイルと checksums ファイルが存在する

### 2.3 External Design Summary

> **Source**: Derived from the external design dialogue (Phase E) and user-confirmed design direction (Phase D).

#### Feature Decomposition

| Unit                     | Responsibility                                                  | REQ Coverage         |
| ------------------------ | --------------------------------------------------------------- | -------------------- |
| checksums ファイルパース | `<hash>  <filename>` 形式から対象ファイル名の期待ハッシュを取得 | REQ-F-004            |
| 実際ハッシュ計算         | sha256sum コマンドでダウンロード済みファイルのハッシュを計算    | REQ-F-004            |
| ハッシュ照合             | 期待値と実際値を比較し一致・不一致を判定                        | REQ-F-004, REQ-F-012 |

#### Unit Interaction Map

```text
[${TEMP_DIR}/checksums_file]
          |
          v
+-----------------------+
| checksums パース       | <-- [asset_filename]
| (期待ハッシュ取得)     |
+-----------------------+
          |
       期待ハッシュ
          |
          v
+-----------------------+    [${TEMP_DIR}/asset_file]
| 実際ハッシュ計算       | <---------------------------+
+-----------------------+                             |
          |                                           |
       実際ハッシュ                                   |
          |                                           |
          v                                           |
+-----------------------+                             |
| ハッシュ照合           |                             |
+-----------------------+                             |
          |
     一致 / 不一致
          |
     exit 0 / exit 3
```

#### Data Flow Diagram

```text
[checksums_file, asset_filename]
       |
       v
[期待ハッシュ取得] --エントリ不存在--> exit 3
       |
    期待ハッシュ
       |
       v
[実際ハッシュ計算] <-- [asset_file]
       |
    実際ハッシュ
       |
       v
[ハッシュ照合] --不一致--> exit 3
       |
     一致
       v
exit 0（インストールステップへ）
```

### 2.4 Non-Goals

> **Derivation**: All items below originate from REQUIREMENTS Section "Out of Scope".

- 署名検証（次 Version への繰り延べ）← REQ-F-012 Rationale
- `sha256sum` 以外のハッシュアルゴリズム ← REQ: Out of Scope
- macOS フォールバック（`shasum -a 256`）← REQ: Out of Scope (REQ-C-001, DR-06)

### 2.5 Behavioral Design Decisions

| ID    | Decision                                                        | Rationale                                                            | Affected Rules | Status |
| ----- | --------------------------------------------------------------- | -------------------------------------------------------------------- | -------------- | ------ |
| DD-01 | checksums フォーマットを `<hash>  <filename>` 形式に固定        | sha256sum 標準形式に固定することでパース実装をシンプルかつ確実にする | R-001          | Active |
| DD-02 | エントリ不存在・ハッシュ不一致の両方を同一エラーコード 3 で返す | 呼び出し元への一貫したエラーセマンティクスを提供する                 | R-002, R-003   | Active |

### 2.6 Related Decision Records

| DR-ID | Title                                                | Phase | Impact on This Spec                      |
| ----- | ---------------------------------------------------- | ----- | ---------------------------------------- |
| DR-06 | sha256sum を Linux 限定とし macOS フォールバックなし | req   | sha256sum コマンドを前提とした設計の根拠 |

### 2.7 DD to DR Promotion Criteria

> **Purpose**: Guidelines for determining when a DD should be promoted to a formal DR.
> Promotion is a **human judgment** — these criteria inform, not automate.

DD-01 の checksums フォーマット固定は他のツール対応時に影響するため、DR 昇格を検討する。

---

## 3. Behavioral Specification

### 3.1 Input Domain

- `checksums_file`: `<hash>  <filename>` 形式の行を含むテキストファイルへのパス
- `asset_filename`: checksums ファイル内のエントリと照合するファイル名（パスなし、名前のみ）
- `asset_file`: SHA256 を計算する対象のバイナリファイルへのパス

### 3.2 Output Semantics

- SHA256 照合成功: exit 0（後続の extract-install ステップへ続行）
- エントリ不存在: `::error::` プレフィックスのエラーメッセージを出力し、exit 3
- ハッシュ不一致: `::error::` プレフィックスのエラーメッセージを出力し、exit 3

---

## 4. Decision Rules

Evaluation MUST follow this order:

| Rule ID | Step | Condition                                                         | Outcome                      |
| ------- | ---: | ----------------------------------------------------------------- | ---------------------------- |
| R-001   |    1 | `checksums_file` をパースして `asset_filename` に一致する行を探す | 行が存在しない場合: exit 3   |
| R-002   |    2 | 一致した行から期待ハッシュ値を取得する                            | ハッシュ値を確定             |
| R-003   |    3 | `sha256sum` で `asset_file` の実際の SHA256 を計算する            | 実際ハッシュ値を確定         |
| R-004   |    4 | 期待ハッシュ値と実際ハッシュ値を比較する                          | 不一致: exit 3、一致: exit 0 |

No reordering is permitted.

<!-- impl-note: checksum.lib.sh の get_expected_checksum(), calc_actual_checksum(), verify_checksum() を使用 -->
<!-- impl-note: ファイルパースは awk または grep で `<hash>  <filename>` の2フィールド形式を処理 -->

---

## 5. Edge Cases

| Input                                                      | Classification         | REQ       | Rationale                                           |
| ---------------------------------------------------------- | ---------------------- | --------- | --------------------------------------------------- |
| checksums ファイルに asset_filename のエントリが存在しない | R-001 失敗             | REQ-F-004 | エントリ不存在は設定ミスとして exit 3               |
| ハッシュ値が一致しない（改ざん検出）                       | R-004 失敗             | REQ-F-004 | 改ざんや転送エラーとして exit 3                     |
| ハッシュ値が一致する                                       | exit 0                 | REQ-F-012 | インストールステップへ続行                          |
| checksums フォーマットがスペース 1 個区切り（非標準）      | R-001 失敗または誤解析 | REQ-F-004 | `sha256sum` 標準形式（スペース 2 個）のみをサポート |

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule    | Notes                                           |
| -------------- | ------------ | ----------------------------------------------- |
| REQ-F-004      | R-001〜R-004 | checksums パース・SHA256 計算・照合の全ステップ |
| REQ-F-012      | R-004        | verify-identity ステップとして REQ-F-004 を包含 |
| REQ-F-001      | —            | Covered in: `orchestration.spec.md`             |
| REQ-F-002      | —            | Covered in: `build-url.spec.md`                 |
| REQ-F-006      | —            | Covered in: `extract-install.spec.md`           |

---

## 7. Open Questions

> **Status**: COMPLETE

None identified — all requirements are unambiguous.

---

## 8. Change History

| Date       | Version | Description           |
| ---------- | ------- | --------------------- |
| 2026-03-23 | 1.0.0   | Initial specification |
