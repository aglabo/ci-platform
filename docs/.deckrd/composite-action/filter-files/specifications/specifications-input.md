---
title: "Design Specification: _ca-filter-files (Input)"
based-on: requirements.md v1.5.0
status: approved
version: 1.5.0
created: "2026-10-27"
---

> Part of split specification. See `specifications-index.md` for full scope.

## 1. Overview

### 1.1 Purpose

本書は、`files` と `patterns` の入力を検査し、行に分割して正規化し、パターン行の包含・除外の区別と検査の規則を定義する。

### 1.2 Scope

本書は、入力の検査・行分割・正規化・パターン行の検査・不正な入力の検出を定義する。
照合規則は specifications-matching.md、出力は specifications-output.md で定義する。

---

## 2. Design Principles

### 2.1 Classification Philosophy

入力は、GitHub Actions が YAML として解釈した後の文字列として扱う (DR-11)。
本 Action が行う正規化は、CRLF の LF への変換、行の分割、パターン行の両端の空白の除去、空行の除外に限る (DR-08, REQ-C-009)。
`files` の行は変更しない。不正なファイル行は、正規化の前の検査で拒否し、補正しない (REQ-F-017, DR-14)。

`files` の行は常にファイルパスとして扱い、`!` などの記号に特別な意味を持たせない。
`patterns` の行だけが、`!` による除外の意味を持つ。

### 2.2 Design Assumptions

- 2.2 of `specifications-index.md` の前提を満たす。
- 行の区切りは LF または CRLF とする (REQ-C-009)。CRLF は LF に変換する (DD-IN-01)。LF を伴わない CR はエラーとする (DD-IN-07)。

### 2.3 External Design Summary

#### Feature Decomposition

| Unit           | Responsibility                                                           | REQ Coverage                    |
| -------------- | ------------------------------------------------------------------------ | ------------------------------- |
| parse-input    | 入力を検査し、行に分割する。パターン行だけ両端の空白を除き、空行を捨てる | REQ-F-001, REQ-F-016, REQ-F-017 |
| check-patterns | パターン行の `!` を検査し、不正なパターンを検出する。行は変えない        | REQ-F-002, REQ-F-004            |

#### Unit Interaction Map

```text
+-------------+  (files lines / patterns lines, 入力順)  +--------+
| parse-input | ---------------------------------------> | filter |
+-------------+                                          +--------+
       |
       | (patterns lines)
       v
+----------------+
| check-patterns |  (検査のみ。結果は終了コード)
+----------------+
```

### 2.4 Non-Goals

> **Derivation**: All items below originate from REQUIREMENTS Section "Out of Scope".

- 正規表現パターンの受け付け ← REQ: Out of Scope #4

### 2.5 Behavioral Design Decisions

| ID       | Decision                                                                                                                 | Rationale                                                                                                                 | Affected Rules               | Status           |
| -------- | ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- | ---------------------------- | ---------------- |
| DD-IN-01 | CRLF だけを改行とみなし、行の分割の前に LF に変換する                                                                    | CRLF の入力でも行末の CR がパスに残らない (REQ-F-001)                                                                     | R-IN-013                     | Active           |
| DD-IN-02 | `!` の後の文字列は、そのまま除外パターンとする (再度の除去なし)                                                          | REQ-F-002 は「`!` の後のテキストがパターン」とする。正規化は R-IN-002 に限る                                              | R-IN-004                     | Active           |
| DD-IN-03 | `!` だけの行は不正なパターンとしてエラーにする                                                                           | 空の除外パターンは意図が読み取れない。DR-09 の「spec で不正と決めた入力」                                                 | R-IN-005                     | Promoted → DR-14 |
| DD-IN-04 | 空白 (スペース・タブ) で始まる除外パターンはエラーにする                                                                 | `! a.sh` のような書き間違いを黙って受け付けない。空白で始まるパスは `*` などの glob で指定する (spec explore review Q-06) | R-IN-009                     | Promoted → DR-14 |
| DD-IN-05 | 不正な入力は先頭から検査し、最初の 1 件を報告して終了する                                                                | fail-first。報告するエラーは常に 1 行とする (spec explore review G-03)                                                    | R-IN-005, R-IN-009〜R-IN-012 | Promoted → DR-14 |
| DD-IN-06 | UTF-8 として不正なバイト列を含む行はエラーにする                                                                         | `?` の 1 文字 (DD-MAT-05) を定められない入力を、照合の前に拒否する (spec explore review Q-04)                             | R-IN-010                     | Promoted → DR-14 |
| DD-IN-07 | LF を伴わない CR を含む入力は、変換・分割の前にエラーにする                                                              | パス中の CR で 1 つのパスが分かれるのを防ぐ。CR のみの改行もこのエラーに含める (REQ-F-017)                                | R-IN-011                     | Promoted → DR-14 |
| DD-IN-08 | ダブルクオートを含むファイル行はエラーにする                                                                             | git の引用表記 (`core.quotePath`) をデコードせずに渡した入力を拒否する (REQ-F-017)                                        | R-IN-012                     | Promoted → DR-14 |
| DD-IN-09 | ファイル行は変更せず、長さ 0 の行だけを捨てる                                                                            | 照合・出力するパスを入力と同じ文字列に保つ (REQ-F-001)                                                                    | R-IN-003                     | Promoted → DR-08 |
| DD-IN-10 | 件数の上限は定数 `FF_MAX_FILES` (3000)・`FF_MAX_PATTERNS` (100) とし、空行を捨てた後の行数で判定する                     | 上限ちょうどは受け付ける。パターン行の検査の前に行い、照合の規模を抑える (REQ-F-018)                                      | R-IN-014, R-IN-015           | Promoted → DR-16 |
| DD-IN-11 | バイト数の上限は定数 `FF_MAX_FILES_BYTES`・`FF_MAX_PATTERNS_BYTES` (120000) とし、変換・分割の前の値をバイト単位で数える | 環境変数の上限 (`MAX_ARG_STRLEN`) に余裕を残す。ロケールによらずバイト数で数える (REQ-F-018)                              | R-IN-016, R-IN-017           | Promoted → DR-16 |

**Status Values:**

- `Active` — Currently in effect within this specification
- `Promoted → DR-xx` — Elevated to formal Decision Record (see Section 2.6)

### 2.6 Related Decision Records

| DR-ID | Title                                                                    | Phase  | Impact on This Spec          |
| ----- | ------------------------------------------------------------------------ | ------ | ---------------------------- |
| DR-19 | パターンは記述順に適用し、最後に一致したパターンで保持を決める           | impl   | R-IN-006, R-IN-007           |
| DR-08 | パターン行だけ両端の空白を除去し、ファイル行は変えない                   | review | R-IN-002, R-IN-003           |
| DR-09 | 非ゼロで終了するのは出力不能時と、不正と決めた入力に限る                 | review | R-IN-005, R-IN-011, R-IN-012 |
| DR-10 | 入力の前提を呼び出し元の義務として定める                                 | review | 2.2                          |
| DR-11 | ダブルクオートの解釈は GitHub Actions (YAML) に任せ、Action では外さない | req    | R-IN-008, R-IN-012           |
| DR-14 | 不正な入力を定義し、最初の 1 件で終了する                                | review | 不正な入力と報告の件数       |
| DR-16 | ファイル数・パターン数・バイト数に上限を設け、超えた入力をエラーにする   | review | R-IN-014〜R-IN-017           |

### 2.7 DD to DR Promotion Criteria

See `specifications-index.md` 2.7.

---

## 3. Behavioral Specification

### 3.1 Input Domain

- Input Type: `INPUT_FILES` と `INPUT_PATTERNS` の文字列 (空を含む)
- Assumptions: 2.2 の前提を満たす。

### 3.2 Output Semantics

- Output Meaning: ファイル行の並び (入力のまま) と、検査済みのパターン行の並び (`pattern` / `!pattern`、入力の順)
- Possible Outcomes:
  - ファイル行 (0 行以上) と、検査済みのパターン行 (0 件以上)
  - 不正な入力のエラー (LF を伴わない CR、UTF-8 として不正な行、ダブルクオートを含むファイル行、不正なパターン)

<!-- impl-note: parse_filelist <text> と parse_patterns <text> は、それぞれ files・patterns の正規化済みの行を
  LF 区切りで標準出力へ返す。不正な行では ff_error を出して 1 を返す。
  parse_filelist は 1 行ずつ UTF-8、ダブルクオートの順に判定した結果と同じ最初の 1 件を報告する (DR-14)。
  check_patterns <lines> は parse_patterns の結果を検査するだけで、標準出力には何も出さない。
  正しければ 0 を返し、不正なパターン (R-IN-005、R-IN-009) では ff_error を出して 1 を返す。
  照合へは parse_patterns の結果を `pattern` / `!pattern` の行のまま渡す (DR-19)。
  UTF-8 の検査 (R-IN-010) を担う関数は impl で決める。 -->

---

## 4. Decision Rules

Evaluation MUST follow this order:

| Rule ID  | Step | Condition                                                         | Outcome                                                                                |
| -------- | ---: | ----------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| R-IN-016 |    1 | `files` の値が `FF_MAX_FILES_BYTES` (120000) バイトを超える       | エラー。出力を書き出す前に終了する (DD-IN-11)                                          |
| R-IN-017 |    1 | `patterns` の値が `FF_MAX_PATTERNS_BYTES` (120000) バイトを超える | エラー。出力を書き出す前に終了する (DD-IN-11)                                          |
| R-IN-011 |    2 | `files` / `patterns` の値が LF を伴わない CR を含む               | エラー。最初の 1 件を報告し、出力を書き出す前に終了する (DD-IN-07)                     |
| R-IN-013 |    3 | `files` / `patterns` の値                                         | CRLF を LF に変換する (DD-IN-01)                                                       |
| R-IN-001 |    4 | `files` / `patterns` の値                                         | LF で行に分割する。入力の順序を保つ                                                    |
| R-IN-010 |    5 | 行が UTF-8 として不正なバイト列を含む                             | エラー。最初の 1 件を報告し、出力を書き出す前に終了する (DD-IN-06)                     |
| R-IN-012 |    5 | `files` の行がダブルクオート (`"`) を含む                         | エラー。最初の 1 件を報告し、出力を書き出す前に終了する (DD-IN-08)                     |
| R-IN-002 |    6 | `patterns` の各行                                                 | 両端からスペース・タブを除去する。行の途中の文字は除去しない。`files` の行は変更しない |
| R-IN-003 |    7 | 空の行                                                            | 捨てる。`files` は長さ 0 の行だけ、`patterns` は R-IN-002 の除去後に空の行 (DD-IN-09)  |
| R-IN-014 |    8 | `files` の行数が `FF_MAX_FILES` (3000) を超える                   | エラー。出力を書き出す前に終了する (DD-IN-10)                                          |
| R-IN-015 |    8 | `patterns` の行数が `FF_MAX_PATTERNS` (100) を超える              | エラー。出力を書き出す前に終了する (DD-IN-10)                                          |
| R-IN-004 |    9 | `patterns` の行が `!` で始まる                                    | 先頭の `!` を除いた残りを除外パターンとする (DD-IN-02)                                 |
| R-IN-005 |   10 | R-IN-004 で残りが空 (`!` だけの行)                                | エラー。最初の 1 件を報告し、出力を書き出す前に終了する (DD-IN-03, DD-IN-05)           |
| R-IN-009 |   10 | R-IN-004 の残りが空白 (スペース・タブ) で始まる                   | エラー。最初の 1 件を報告し、出力を書き出す前に終了する (DD-IN-04, DD-IN-05)           |
| R-IN-006 |   11 | `patterns` のその他の行                                           | 包含パターンとする。パターン行は包含・除外とも入力の順のまま照合へ渡す (DR-19)         |
| R-IN-007 |   12 | パターンが 0 件                                                   | パターン無しとして照合へ渡す。エラーにしない (REQ-F-004)                               |
| R-IN-008 |    — | `patterns` の行にダブルクオート (`"`) が含まれる (全 Step に共通) | 除去も解釈もせず、文字として扱う (REQ-F-016)                                           |

No reordering is permitted.

- R-IN-016 は R-IN-017 より先に検査する。バイト数は `LC_ALL=C` で数え、文字数として数えない。
- R-IN-011 は `files` を先に、`patterns` を後に検査する。各入力の中では先頭から検査し、最初の CR を含む行 (LF で区切った範囲) を報告する。
- R-IN-010 と R-IN-012 は `files` の行を先に、`patterns` の行を後に検査する。各入力の中では先頭の行から検査し、ファイル行では R-IN-010、R-IN-012 の順で判定する。
- R-IN-014 は R-IN-015 より先に検査する。行数は R-IN-003 で捨てた行を含めない。
- R-IN-005 と R-IN-009 は、パターン行を先頭から 1 行ずつ評価する。各行では R-IN-005、R-IN-009 の順で判定する。
- 報告するのは、最初に規則へ当たった 1 行だけとする。報告する行は、規則の順ではなく行の順で決まる (DR-14)。

**エラーの文言:**

| Rule ID  | 対象                 | 問題                                                               |
| -------- | -------------------- | ------------------------------------------------------------------ |
| R-IN-005 | `patterns`           | 除外パターンが空である (値として、その行 `!` を埋め込む)           |
| R-IN-009 | `patterns`           | 除外パターンが空白で始まる (値として、その行を埋め込む)            |
| R-IN-010 | `files` / `patterns` | UTF-8 として不正な行がある (値として、その行を埋め込む)            |
| R-IN-011 | `files` / `patterns` | LF を伴わない CR がある (値として、その行を埋め込む)               |
| R-IN-012 | `files`              | ダブルクオートを含む行がある (値として、その行を埋め込む)          |
| R-IN-014 | `files`              | `exceeds the limit of 3000 lines` (値として、行数を埋め込む)       |
| R-IN-015 | `patterns`           | `exceeds the limit of 100 lines` (値として、行数を埋め込む)        |
| R-IN-016 | `files`              | `exceeds the limit of 120000 bytes` (値として、バイト数を埋め込む) |
| R-IN-017 | `patterns`           | `exceeds the limit of 120000 bytes` (値として、バイト数を埋め込む) |

---

## 5. Edge Cases

`<SP>` はスペース、`<TAB>` はタブ、`<CR>` は CR を表す。

| Input                                                       | Classification                                     | REQ                  | Rationale                          |
| ----------------------------------------------------------- | -------------------------------------------------- | -------------------- | ---------------------------------- |
| `files` が空文字列・改行のみ                                | 0 行                                               | REQ-F-001, REQ-F-014 | R-IN-003                           |
| `files` の行が空白のみ (`<SP><SP>`)                         | パス `<SP><SP>` として 1 行                        | REQ-F-001            | R-IN-003, DD-IN-09                 |
| `files: \|` による末尾の改行                                | 末尾の空行は捨てる                                 | REQ-F-001            | R-IN-003                           |
| `files` の行が `<SP><SP>a.sh` / `a.sh<TAB>`                 | そのまま (`<SP><SP>a.sh` / `a.sh<TAB>`)            | REQ-F-001            | R-IN-002, DD-IN-09                 |
| `patterns` の行が `<SP><SP>*.sh` / `*.sh<TAB>`              | `*.sh`                                             | REQ-F-001            | R-IN-002                           |
| 行が `a.sh<CR><LF>`                                         | `a.sh`                                             | REQ-F-001            | R-IN-013, DD-IN-01                 |
| 値が `a.sh<CR>` / `a<CR>b.sh` (LF を伴わない CR)            | エラー                                             | REQ-F-017            | R-IN-011, DD-IN-07                 |
| パス `my file.sh` (途中に空白)                              | `my file.sh` のまま                                | REQ-F-001            | 途中の空白は除去しない             |
| `files` の行が `!a.sh`                                      | パス `!a.sh` として扱う                            | REQ-F-002            | `!` の意味は `patterns` だけ       |
| `!` で始まるパスだけを包含したい                            | 指定する方法は無い (`\!a.sh` も除外パターンになる) | REQ-F-002            | エスケープ記法を設けない (制約)    |
| `patterns` の行が `!` / `!<SP><SP><SP>` / `<SP><SP>!`       | エラー                                             | REQ-F-002            | 除去後は `!` だけになる (R-IN-005) |
| `patterns` の行が `!<SP>a.sh` / `!<TAB>a.sh`                | エラー                                             | REQ-F-002            | R-IN-009, DD-IN-04                 |
| `patterns` の行が `!!a.sh`                                  | 除外パターン `!a.sh`                               | REQ-F-002            | 先頭の `!` を 1 つだけ除く         |
| `patterns` に `!` だけの行と `!<SP>a.sh` の行がこの順にある | 最初の `!` の行だけを報告してエラー                | REQ-F-002            | DD-IN-05                           |
| 行が UTF-8 として不正なバイト列を含む                       | エラー                                             | REQ-C-009            | R-IN-010, DD-IN-06                 |
| `patterns` の先頭が除外パターン                             | 入力の順のまま照合へ渡す                           | REQ-F-003            | 照合は R-MAT-013 に従う            |
| `patterns` が未指定・空・空白行のみ                         | パターン無し                                       | REQ-F-004            | R-IN-007                           |
| `files` の行が `"b.sh"` / `"a\nb.sh"`                       | エラー                                             | REQ-F-017            | R-IN-012, DD-IN-08                 |
| `patterns` の行が `"b.sh"`                                  | 文字列 `"b.sh"` (クオートを含む)                   | REQ-F-016            | R-IN-008                           |
| `files` に同じパスが複数回ある                              | すべて残す (重複を除かない)                        | REQ-F-010            | 照合と出力で入力どおりに扱う       |
| `files` が 3000 行 / 3001 行                                | 受け付ける / エラー                                | REQ-F-018            | R-IN-014                           |
| `files` が 3000 行と、末尾の改行による空行                  | 受け付ける (空行は数えない)                        | REQ-F-018            | R-IN-003, R-IN-014                 |
| `patterns` が 100 行 / 101 行                               | 受け付ける / エラー                                | REQ-F-018            | R-IN-015                           |
| `files` の値が 120000 バイト / 120001 バイト                | 受け付ける / エラー                                | REQ-F-018            | R-IN-016                           |
| `files` が 40001 文字の日本語 (120003 バイト)               | エラー (文字数ではなくバイト数で数える)            | REQ-F-018            | R-IN-016, DD-IN-11                 |
| `patterns` の値が 120001 バイト                             | エラー                                             | REQ-F-018            | R-IN-017                           |

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule                              | Notes                                    |
| -------------- | -------------------------------------- | ---------------------------------------- |
| REQ-F-001      | R-IN-001〜R-IN-003, R-IN-010, R-IN-013 | DD-IN-01, DD-IN-06, DD-IN-09             |
| REQ-F-002      | R-IN-004〜R-IN-006, R-IN-009           | DD-IN-02〜DD-IN-05                       |
| REQ-F-004      | R-IN-007                               | 照合側は R-MAT-010                       |
| REQ-F-016      | R-IN-008                               |                                          |
| REQ-F-017      | R-IN-011, R-IN-012                     | DD-IN-07, DD-IN-08                       |
| REQ-F-018      | R-IN-014〜R-IN-017                     | DD-IN-10, DD-IN-11                       |
| REQ-F-003      | —                                      | Covered in: `specifications-matching.md` |
| REQ-F-010      | —                                      | Covered in: `specifications-output.md`   |

---

## 7. Open Questions

> **Status**: COMPLETE

None identified - all requirements are unambiguous.

---

## 8. Change History

| Date       | Version | Description                                                                                                                               |
| ---------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-10-27 | 0.1.0   | Initial draft                                                                                                                             |
| 2026-10-27 | 0.2.0   | Apply spec explore review: error on whitespace-led exclude and invalid UTF-8, report first error only                                     |
| 2026-10-27 | 0.2.1   | Apply spec harden review: promote DD-IN-03 to DD-IN-06 to DR-14, clarify check order                                                      |
| 2026-10-27 | 0.2.2   | Apply spec fix review: UTF-8 error in outcomes, refresh based-on                                                                          |
| 2026-10-27 | 1.0.0   | Initial release                                                                                                                           |
| 2026-10-27 | 1.1.0   | Follow requirements v1.1.0: keep files lines unchanged, trim patterns only, convert CRLF, reject lone CR and quoted files lines, approve  |
| 2026-10-27 | 1.2.0   | Follow requirements v1.2.0: add line count limits (R-IN-014, R-IN-015, DD-IN-10)                                                          |
| 2026-10-27 | 1.3.0   | Follow requirements v1.3.0: add byte size limits before other checks (R-IN-016, R-IN-017, DD-IN-11)                                       |
| 2026-10-27 | 1.3.1   | Apply impl second opinion: split parse_lines into parse_filelist and parse_patterns in impl-note                                          |
| 2026-10-29 | 1.4.0   | Follow requirements v1.4.0: classify_patterns becomes check_patterns (validation only, no stdout), pattern lines keep input order (DR-19) |
| 2026-10-29 | 1.5.0   | Follow requirements v1.5.0: lower FF_MAX_PATTERNS from 1000 to 100 (DD-IN-10, R-IN-015, DR-16)                                            |
