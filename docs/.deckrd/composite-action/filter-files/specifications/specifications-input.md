---
title: "Design Specification: _ca-filter-files (Input)"
based-on: requirements.md v1.0.7
status: Draft
version: 1.1.1
created: "2026-10-27"
---

> Part of split specification. See `specifications-index.md` for full scope.

## 1. Overview

### 1.1 Purpose

本書は、`files` と `patterns` の入力を行に分割して正規化し、パターンを包含と除外に分類する規則を定義する。

### 1.2 Scope

本書は、入力の行分割・正規化・パターンの分類・不正なパターンの検出を定義する。
照合規則は specifications-matching.md、出力は specifications-output.md で定義する。

---

## 2. Design Principles

### 2.1 Classification Philosophy

入力は、GitHub Actions が YAML として解釈した後の文字列として扱う (DR-11)。
本 Action が行う正規化は、行の分割、両端の空白の除去、空行の除外に限る (DR-08, REQ-C-009)。

`files` の行は常にファイルパスとして扱い、`!` などの記号に特別な意味を持たせない。
`patterns` の行だけが、`!` による除外の意味を持つ。

### 2.2 Design Assumptions

- 2.2 of `specifications-index.md` の前提を満たす。
- 行の区切りは LF とする (REQ-C-009)。CR は空白として除去する (DD-IN-01)。

### 2.3 External Design Summary

#### Feature Decomposition

| Unit              | Responsibility                                         | REQ Coverage         |
| ----------------- | ------------------------------------------------------ | -------------------- |
| parse-input       | 入力を行に分割し、両端の空白を除いて空行を捨てる       | REQ-F-001, REQ-F-016 |
| classify-patterns | パターン行を包含と除外に分け、不正なパターンを検出する | REQ-F-002, REQ-F-004 |

#### Unit Interaction Map

```text
+-------------+  (files lines)    +--------+
| parse-input | ----------------> | filter |
+-------------+                   +--------+
       |
       | (patterns lines)
       v
+-------------------+  (include / exclude)  +---------------+
| classify-patterns | --------------------> | glob-to-regex |
+-------------------+                       +---------------+
```

### 2.4 Non-Goals

> **Derivation**: All items below originate from REQUIREMENTS Section "Out of Scope".

- 正規表現パターンの受け付け ← REQ: Out of Scope #4

### 2.5 Behavioral Design Decisions

| ID       | Decision                                                        | Rationale                                                                                                               | Affected Rules     | Status           |
| -------- | --------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | ------------------ | ---------------- |
| DD-IN-01 | 両端から除去する文字に CR を含める                              | CRLF の入力でも行末の CR がパスに残らない (REQ Open Question の解消)                                                    | R-IN-002           | Active           |
| DD-IN-02 | `!` の後の文字列は、そのまま除外パターンとする (再度の除去なし) | REQ-F-002 は「`!` の後のテキストがパターン」とする。正規化は R-IN-002 に限る                                            | R-IN-004           | Active           |
| DD-IN-03 | `!` だけの行は不正なパターンとしてエラーにする                  | 空の除外パターンは意図が読み取れない。DR-09 の「spec で不正と決めた入力」                                               | R-IN-005           | Promoted → DR-14 |
| DD-IN-04 | 空白 (スペース・タブ) で始まる除外パターンはエラーにする        | ファイル行は trim 済みで、そのようなパターンは何にも一致しない。書き間違いを黙って無視しない (spec explore review Q-06) | R-IN-009           | Promoted → DR-14 |
| DD-IN-05 | 不正なパターンは先頭から検査し、最初の 1 件を報告して終了する   | fail-first。報告するエラーは常に 1 行とする (spec explore review G-03)                                                  | R-IN-005, R-IN-009 | Promoted → DR-14 |
| DD-IN-06 | UTF-8 として不正なバイト列を含む行はエラーにする                | `?` の 1 文字 (DD-MAT-05) を定められない入力を、照合の前に拒否する (spec explore review Q-04)                           | R-IN-010           | Promoted → DR-14 |

**Status Values:**

- `Active` — Currently in effect within this specification
- `Promoted → DR-xx` — Elevated to formal Decision Record (see Section 2.6)

### 2.6 Related Decision Records

| DR-ID | Title                                                                    | Phase  | Impact on This Spec    |
| ----- | ------------------------------------------------------------------------ | ------ | ---------------------- |
| DR-04 | 包含パターンが 0 件の場合は全ファイルを通す                              | req    | R-IN-007               |
| DR-08 | 入力行の両端の空白を除去し、空になった行を無視する                       | review | R-IN-002, R-IN-003     |
| DR-09 | 非ゼロで終了するのは出力不能時と、spec で不正と決めた入力に限る          | review | R-IN-005               |
| DR-10 | 入力の前提を呼び出し元の義務として定める                                 | review | 2.2                    |
| DR-11 | ダブルクオートの解釈は GitHub Actions (YAML) に任せ、Action では外さない | req    | R-IN-008               |
| DR-14 | 不正な入力を定義し、最初の 1 件で終了する                                | review | 不正な入力と報告の件数 |

### 2.7 DD to DR Promotion Criteria

See `specifications-index.md` 2.7.

---

## 3. Behavioral Specification

### 3.1 Input Domain

- Input Type: `INPUT_FILES` と `INPUT_PATTERNS` の文字列 (空を含む)
- Assumptions: 2.2 の前提を満たす。

### 3.2 Output Semantics

- Output Meaning: 正規化済みのファイル行の並びと、包含パターン・除外パターンの並び
- Possible Outcomes:
  - 正規化済みの行 (0 行以上) と、分類済みのパターン (0 件以上)
  - 不正なパターンのエラー

<!-- impl-note: parse_lines <text> は正規化済みの行を LF 区切りで標準出力へ返す。
  classify_patterns <lines> は包含・除外を分けて返す (受け渡し方式は impl で決める)。不正なパターンでは ff_error を出して 1 を返す。 -->

---

## 4. Decision Rules

Evaluation MUST follow this order:

| Rule ID  | Step | Condition                                            | Outcome                                                                      |
| -------- | ---: | ---------------------------------------------------- | ---------------------------------------------------------------------------- |
| R-IN-001 |    1 | `files` / `patterns` の値                            | LF で行に分割する。入力の順序を保つ                                          |
| R-IN-010 |    1 | 行が UTF-8 として不正なバイト列を含む                | エラー。最初の 1 件を報告し、出力を書き出す前に終了する (DD-IN-06)           |
| R-IN-002 |    2 | 各行                                                 | 両端からスペース・タブ・CR を除去する。行の途中の文字は除去しない            |
| R-IN-003 |    3 | 除去後に空の行                                       | 捨てる。`files` と `patterns` の両方に適用する                               |
| R-IN-004 |    4 | `patterns` の行が `!` で始まる                       | 先頭の `!` を除いた残りを除外パターンとする (DD-IN-02)                       |
| R-IN-005 |    5 | R-IN-004 で残りが空 (`!` だけの行)                   | エラー。最初の 1 件を報告し、出力を書き出す前に終了する (DD-IN-03, DD-IN-05) |
| R-IN-009 |    5 | R-IN-004 の残りが空白 (スペース・タブ) で始まる      | エラー。最初の 1 件を報告し、出力を書き出す前に終了する (DD-IN-04, DD-IN-05) |
| R-IN-006 |    6 | `patterns` のその他の行                              | 包含パターンとする                                                           |
| R-IN-007 |    7 | 包含パターン・除外パターンがともに 0 件              | パターン無しとして照合へ渡す。エラーにしない (REQ-F-004)                     |
| R-IN-008 |    — | 行にダブルクオート (`"`) が含まれる (全 Step に共通) | 除去も解釈もせず、文字として扱う (REQ-F-016)                                 |

No reordering is permitted.

- R-IN-010 は `files` の行を先に、`patterns` の行を後に検査する。各入力の中では先頭の行から検査する。
- R-IN-005 と R-IN-009 は、パターン行を先頭から 1 行ずつ評価する。各行では R-IN-005、R-IN-009 の順で判定する。
- 報告するのは、最初に規則へ当たった 1 行だけとする。報告する行は、規則の順ではなく行の順で決まる (DR-14)。

**エラーの文言:**

| Rule ID  | 対象                 | 問題                                                     |
| -------- | -------------------- | -------------------------------------------------------- |
| R-IN-005 | `patterns`           | 除外パターンが空である (値として、その行 `!` を埋め込む) |
| R-IN-009 | `patterns`           | 除外パターンが空白で始まる (値として、その行を埋め込む)  |
| R-IN-010 | `files` / `patterns` | UTF-8 として不正な行がある (値として、その行を埋め込む)  |

---

## 5. Edge Cases

`<SP>` はスペース、`<TAB>` はタブ、`<CR>` は CR を表す。

| Input                                                       | Classification                                     | REQ                  | Rationale                          |
| ----------------------------------------------------------- | -------------------------------------------------- | -------------------- | ---------------------------------- |
| `files` が空文字列・空白のみ・改行のみ                      | 0 行                                               | REQ-F-001, REQ-F-014 | R-IN-003                           |
| `files: \|` による末尾の改行                                | 末尾の空行は捨てる                                 | REQ-F-001            | R-IN-003                           |
| 行が `<SP><SP>a.sh` / `a.sh<TAB>` / `a.sh<CR>`              | `a.sh`                                             | REQ-F-001            | R-IN-002, DD-IN-01                 |
| パス `my file.sh` (途中に空白)                              | `my file.sh` のまま                                | REQ-F-001            | 途中の空白は除去しない             |
| 行の途中に CR を含むパス                                    | 対象外 (入力契約違反)。出力で拒否され得る          | REQ-C-009            | R-OUT-010                          |
| `files` の行が `!a.sh`                                      | パス `!a.sh` として扱う                            | REQ-F-002            | `!` の意味は `patterns` だけ       |
| `!` で始まるパスだけを包含したい                            | 指定する方法は無い (`\!a.sh` も除外パターンになる) | REQ-F-002            | エスケープ記法を設けない (制約)    |
| `patterns` の行が `!` / `!<SP><SP><SP>` / `<SP><SP>!`       | エラー                                             | REQ-F-002            | 除去後は `!` だけになる (R-IN-005) |
| `patterns` の行が `!<SP>a.sh` / `!<TAB>a.sh`                | エラー                                             | REQ-F-002            | R-IN-009, DD-IN-04                 |
| `patterns` の行が `!!a.sh`                                  | 除外パターン `!a.sh`                               | REQ-F-002            | 先頭の `!` を 1 つだけ除く         |
| `patterns` に `!` だけの行と `!<SP>a.sh` の行がこの順にある | 最初の `!` の行だけを報告してエラー                | REQ-F-002            | DD-IN-05                           |
| 行が UTF-8 として不正なバイト列を含む                       | エラー                                             | REQ-C-009            | R-IN-010, DD-IN-06                 |
| `patterns` が除外パターンだけ                               | 包含 0 件・除外 1 件以上                           | REQ-F-003            | 照合は R-MAT-010 に従う            |
| `patterns` が未指定・空・空白行のみ                         | パターン無し                                       | REQ-F-004            | R-IN-007                           |
| 行が `"b.sh"`                                               | 文字列 `"b.sh"` (クオートを含む)                   | REQ-F-016            | R-IN-008                           |
| `files` に同じパスが複数回ある                              | すべて残す (重複を除かない)                        | REQ-F-010            | 照合と出力で入力どおりに扱う       |

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule                    | Notes                                    |
| -------------- | ---------------------------- | ---------------------------------------- |
| REQ-F-001      | R-IN-001〜R-IN-003, R-IN-010 | DD-IN-01, DD-IN-06                       |
| REQ-F-002      | R-IN-004〜R-IN-006, R-IN-009 | DD-IN-02〜DD-IN-05                       |
| REQ-F-004      | R-IN-007                     | 照合側は R-MAT-010                       |
| REQ-F-016      | R-IN-008                     |                                          |
| REQ-F-003      | —                            | Covered in: `specifications-matching.md` |
| REQ-F-010      | —                            | Covered in: `specifications-output.md`   |

---

## 7. Open Questions

> **Status**: COMPLETE

None identified - all requirements are unambiguous.

---

## 8. Change History

| Date       | Version | Description                                                                                           |
| ---------- | ------- | ----------------------------------------------------------------------------------------------------- |
| 2026-10-27 | 1.0.0   | Initial specification                                                                                 |
| 2026-10-27 | 1.1.0   | Apply spec explore review: error on whitespace-led exclude and invalid UTF-8, report first error only |
| 2026-10-27 | 1.1.1   | Apply spec harden review: promote DD-IN-03 to DD-IN-06 to DR-14, clarify check order                  |
