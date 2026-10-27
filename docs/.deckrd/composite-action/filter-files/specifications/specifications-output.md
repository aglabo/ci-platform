---
title: "Design Specification: _ca-filter-files (Output)"
based-on: requirements.md v1.0.0
status: Draft
version: 1.0.0
created: "2026-10-27"
---

> Part of split specification. See `specifications-index.md` for full scope.

## 1. Overview

### 1.1 Purpose

本書は、出力先の検証、`files` と `count` の値の組み立て、`$GITHUB_OUTPUT` への書き出しの規則を定義する。
共有ライブラリに追加する出力先の検証と、複数行出力の振る舞いも定義する。

### 1.2 Scope

本書は、出力の書き出しと、その失敗時の振る舞いを定義する。
入力の正規化は specifications-input.md、照合は specifications-matching.md で定義する。

---

## 2. Design Principles

### 2.1 Classification Philosophy

出力先は、最初の書き込みの前に検証する (REQ-F-015)。検証に失敗した場合は、出力を 1 つも書かない。
書き出しを始めた後の失敗は、エラーとして終了する。先に書いた出力が残り得る (DR-09)。

共有ライブラリの出力関数は、エラーを出さず終了コードだけを返す。`::error::` は呼び出し側が出す。
既存の単一行出力関数の契約に合わせる。

<!-- impl-note: original said "既存の `write_output` と同じ契約とする。" -->

### 2.2 Design Assumptions

- 2.2 of `specifications-index.md` の前提を満たす。
- `$GITHUB_OUTPUT` は、GitHub Actions ランナーが設定する出力ファイルのパスである。

### 2.3 External Design Summary

#### Feature Decomposition

| Unit                   | Responsibility                                              | REQ Coverage                               |
| ---------------------- | ----------------------------------------------------------- | ------------------------------------------ |
| output-emission        | 出力先を検証し、`files`・`count` の順に書き出す             | REQ-F-010, REQ-F-011, REQ-F-014, REQ-F-015 |
| output-file-validation | 出力先のパスが書き込める状態かを判定する (共有ライブラリ)   | REQ-F-015                                  |
| multiline-output       | 区切り文字が値と衝突しない複数行出力を書く (共有ライブラリ) | REQ-F-013, REQ-F-014                       |

#### Unit Interaction Map

```text
+--------+  (kept lines)  +-----------------+ --> +------------------------+
| filter | -------------> | output-emission |     | output-file-validation |
+--------+                +-----------------+     +------------------------+
                                 |
                                 +--> [multiline-output] (files)
                                 |
                                 +--> [single-line output] (count)
```

### 2.4 Non-Goals

> **Derivation**: All items below originate from REQUIREMENTS Section "Out of Scope".

- JSON 配列形式の出力 ← REQ: Out of Scope #5

### 2.5 Behavioral Design Decisions

| ID        | Decision                                                                                         | Rationale                                                                                                                       | Affected Rules       | Status           |
| --------- | ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------- | -------------------- | ---------------- |
| DD-OUT-01 | 区切り文字の候補は `EOF`、`EOF_1`、`EOF_2`… の順に試し、値のどの行とも一致しない最初の候補を使う | 候補が決定的なので、衝突の検証に差し替えの仕組みが要らない (AC-010)                                                             | R-OUT-011            | Promoted → DR-13 |
| DD-OUT-02 | 値が空の場合は、内容の行を書かない                                                               | 後続ステップが空文字列として読む (REQ-F-014)。旧実装は空行を 1 行書いていた                                                     | R-OUT-012            | Promoted → DR-13 |
| DD-OUT-03 | 書き出しは `files`、`count` の順とする                                                           | 呼び出し元が `count` を見て分岐する場合、`files` が先に揃っている                                                               | R-OUT-003, R-OUT-005 | Active           |
| DD-OUT-04 | 出力先が存在しない場合は、親ディレクトリに書き込めるかで判定し、ファイルは作らない               | 検証で副作用を起こさない。resolve-sha の内部検証と同じ判定                                                                      | R-OUT-021            | Promoted → DR-13 |
| DD-OUT-05 | 値は LF で行に分けて扱い、1 行ごとに LF を付けて書く。値の末尾の LF は空行を作らない             | 行に改行を含まない形で出力を組み立てる (spec explore review G-01)                                                               | R-OUT-013            | Promoted → DR-13 |
| DD-OUT-06 | キーは英字または `_` で始まり、英数字・`_`・`-` だけからなる文字列に限る                         | キーは出力名であり、ファイル名ではない。ファイル名は値の行として書くので、`<<` や `=` を含んでも通る (spec explore review G-02) | R-OUT-010            | Promoted → DR-13 |

**Status Values:**

- `Active` — Currently in effect within this specification
- `Promoted → DR-xx` — Elevated to formal Decision Record (see Section 2.6)

### 2.6 Related Decision Records

| DR-ID | Title                                                             | Phase  | Impact on This Spec  |
| ----- | ----------------------------------------------------------------- | ------ | -------------------- |
| DR-07 | 複数行出力関数を `_libs` に追加し、区切り文字を一意な文字列にする | req    | R-OUT-010〜R-OUT-014 |
| DR-09 | 非ゼロで終了するのは出力不能時と、spec で不正と決めた入力に限る   | review | 失敗時の振る舞い     |
| DR-12 | 出力先の検証関数を `_libs/output.lib.sh` に追加する               | spec   | R-OUT-020〜R-OUT-022 |
| DR-13 | 共有出力関数の契約を定める                                        | review | 共有関数の契約       |
| DR-15 | エラー形式を内部 Action 共通の形式にそろえる                      | review | エラー形式           |

### 2.7 DD to DR Promotion Criteria

See `specifications-index.md` 2.7.

---

## 3. Behavioral Specification

### 3.1 Input Domain

- Input Type: 保持行 (0 行以上) と、`$GITHUB_OUTPUT` のパス
- Assumptions: specifications-matching.md の規則で保持行が決まっている。入力の検証は成功している (DD-IDX-02)。

### 3.2 Output Semantics

- Output Meaning: `$GITHUB_OUTPUT` に追記された `files` と `count`
- Possible Outcomes:
  - 成功: `files` と `count` を書き、終了コード 0
  - 出力先の検証の失敗: 何も書かず、エラーを出して非ゼロで終了する
  - 書き込みの失敗: エラーを出して非ゼロで終了する。`files` だけが書かれた状態が残り得る

<!-- impl-note: emit_outputs <file> <kept> が R-OUT-001〜005 を担う。
  validate_output_file <file> は 0 = 書き込める、1 = パスが空、2 = 書き込めない を返す。
  write_multiline_output <file> <key> <value> は 1 = 引数不正、2 = 書き込み失敗 を返す。
  いずれも stdout / stderr に何も出さない。count の書き出しには既存の write_output <file> <key> <value> を使う。 -->

---

## 4. Decision Rules

**出力の書き出し (output-emission):**

| Rule ID   | Step | Condition                           | Outcome                                                                   |
| --------- | ---: | ----------------------------------- | ------------------------------------------------------------------------- |
| R-OUT-001 |    1 | 出力先のパスが空 (検証の結果 1)     | エラー。何も書かずに終了する                                              |
| R-OUT-002 |    2 | 出力先に書き込めない (検証の結果 2) | エラー。何も書かずに終了する                                              |
| R-OUT-003 |    3 | 保持行が 1 行以上                   | `files` に、保持行を入力順に LF で連結した値を書く (末尾に LF を付けない) |
| R-OUT-004 |    3 | 保持行が 0 行                       | `files` に空の値を書く。後続ステップは空文字列として読む                  |
| R-OUT-005 |    4 | `files` の書き込みに成功した        | `count` に保持行の数を、先頭ゼロ・前後の空白を含まない 10 進整数で書く    |
| R-OUT-006 |    — | Step 3・4 の書き込みに失敗した      | エラー。以降を書かずに終了する                                            |

No reordering is permitted.

**複数行出力 (multiline-output):**

| Rule ID   | Step | Condition                                                     | Outcome                                                                                                                                |
| --------- | ---: | ------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| R-OUT-010 |    1 | 出力先が空、キーが DD-OUT-06 の形式に合わない、値に CR を含む | 何も書かず、引数不正 (1) を返す                                                                                                        |
| R-OUT-011 |    2 | 区切り文字の候補 `EOF`、`EOF_1`、`EOF_2`…                     | 値のどの行とも一致しない最初の候補を区切り文字とする (DD-OUT-01)                                                                       |
| R-OUT-012 |    3 | 値が空                                                        | `<key><<<区切り>` と `<区切り>` の 2 行を書く (DD-OUT-02)                                                                              |
| R-OUT-013 |    3 | 値が空でない                                                  | `<key><<<区切り>` を書き、値を LF で分けた各行に LF を付けて書き、最後に `<区切り>` を書く。値の末尾の LF は空行を作らない (DD-OUT-05) |
| R-OUT-014 |    4 | 書き込みに失敗した                                            | 書き込み失敗 (2) を返す                                                                                                                |

**出力先の検証 (output-file-validation):**

| Rule ID   | Step | Condition        | Outcome                                                                                                                                     |
| --------- | ---: | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| R-OUT-020 |    1 | パスが空         | 1 を返す                                                                                                                                    |
| R-OUT-021 |    2 | パスが存在しない | 親ディレクトリが存在し、書き込めるディレクトリなら 0、それ以外 (親ディレクトリが無い場合を含む) は 2 を返す。ファイルは作らない (DD-OUT-04) |
| R-OUT-022 |    3 | パスが存在する   | 通常ファイルで書き込めるなら 0、それ以外 (ディレクトリ・FIFO など) は 2 を返す                                                              |

- R-OUT-011 の候補探しは必ず終わる。値が N 行なら、N + 1 個以内の候補で衝突しない区切り文字が見つかる。
- 共有ライブラリの関数 (R-OUT-010〜022) は、標準出力・標準エラー出力に何も出さない (DR-13)。
- 出力先の検証の成功は、後続の書き込みの成功を保証しない。書き込みに失敗した場合は R-OUT-006 に従う。
- 後続ステップは、区切り文字の直前の LF を含まない値を読む (GitHub Actions の複数行出力の解釈)。

**エラーの文言:**

| Rule ID   | 対象              | 問題                                                      |
| --------- | ----------------- | --------------------------------------------------------- |
| R-OUT-001 | `GITHUB_OUTPUT`   | 値が空である (空の形式)                                   |
| R-OUT-002 | `GITHUB_OUTPUT`   | 書き込めるファイルではない (値としてパスを埋め込む)       |
| R-OUT-006 | `files` / `count` | 出力の書き込みに失敗した (値として出力先のパスを埋め込む) |

---

## 5. Edge Cases

| Input                                                 | Classification                         | REQ       | Rationale                      |
| ----------------------------------------------------- | -------------------------------------- | --------- | ------------------------------ |
| `GITHUB_OUTPUT` が未設定                              | エラー、何も書かない                   | REQ-F-015 | R-OUT-001                      |
| `GITHUB_OUTPUT` がディレクトリ                        | エラー、何も書かない                   | REQ-F-015 | R-OUT-002, R-OUT-022           |
| `GITHUB_OUTPUT` が存在しないファイル (親は書き込み可) | 検証は成功し、書き出しで作られる       | REQ-F-015 | R-OUT-021                      |
| 保持行が 0 行                                         | `files` は空、`count` は `0`           | REQ-F-014 | R-OUT-004, R-OUT-012           |
| 保持行が `EOF` を含む                                 | 区切り文字は `EOF_1`                   | REQ-F-013 | R-OUT-011                      |
| 保持行が `EOF` と `EOF_1` を含む                      | 区切り文字は `EOF_2`                   | REQ-F-013 | R-OUT-011                      |
| 保持行が `EOF_1` だけを含む                           | 区切り文字は `EOF`                     | REQ-F-013 | 衝突しない最初の候補           |
| 保持行に `xEOF` や `EOF<SP>` (行全体が一致しない)     | 区切り文字は `EOF`                     | REQ-F-013 | 行全体の一致だけを衝突とする   |
| 値の末尾が LF (`a<LF>b<LF>`)                          | `a<LF>b` と同じ出力 (空行を作らない)   | REQ-F-013 | R-OUT-013, DD-OUT-05           |
| 値の行に `<<` や `=` を含む (`a<<b.sh`)               | そのまま行として書く                   | REQ-F-013 | 区切り文字で囲むため衝突しない |
| キーが `my-key` / `_k1`                               | 書く                                   | REQ-F-013 | DD-OUT-06                      |
| キーが `a=b` / `a<<b` / `1abc` / 空                   | 引数不正 (1)                           | REQ-F-013 | R-OUT-010, DD-OUT-06           |
| `GITHUB_OUTPUT` の親ディレクトリが存在しない          | エラー、何も書かない                   | REQ-F-015 | R-OUT-021                      |
| 保持行が 1000 行                                      | `count` は `1000` (先頭ゼロ・空白なし) | REQ-F-011 | R-OUT-005                      |
| `count` の書き込みだけ失敗                            | エラー。`files` は書かれたまま残り得る | REQ-F-015 | R-OUT-006, DR-09               |

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule                                             | Notes                                    |
| -------------- | ----------------------------------------------------- | ---------------------------------------- |
| REQ-F-010      | R-OUT-003                                             | 保持行の並びは matching が決める         |
| REQ-F-011      | R-OUT-005                                             |                                          |
| REQ-F-013      | R-OUT-010〜R-OUT-014                                  | DD-OUT-01                                |
| REQ-F-014      | R-OUT-004, R-OUT-012                                  | DD-OUT-02                                |
| REQ-F-015      | R-OUT-001, R-OUT-002, R-OUT-006, R-OUT-020〜R-OUT-022 | DD-OUT-04, DR-12                         |
| REQ-C-007      | R-OUT-010〜R-OUT-022                                  | 共有ライブラリへの追加 2 関数            |
| REQ-F-003      | —                                                     | Covered in: `specifications-matching.md` |

---

## 7. Open Questions

> **Status**: COMPLETE

None identified - all requirements are unambiguous.

---

## 8. Change History

| Date       | Version | Description                                                                                         |
| ---------- | ------- | --------------------------------------------------------------------------------------------------- |
| 2026-10-27 | 0.1.0   | Initial draft                                                                                       |
| 2026-10-27 | 0.2.0   | Apply spec explore review: line-based multiline output, output key format, missing parent directory |
| 2026-10-27 | 0.2.1   | Apply spec harden review: promote shared output DDs to DR-13, candidate search terminates           |
| 2026-10-27 | 0.2.2   | Apply spec fix review: unify term 保持行, refresh based-on                                          |
| 2026-10-27 | 1.0.0   | Initial release                                                                                     |
