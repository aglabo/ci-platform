---
title: "Design Specification: _ca-filter-files (Matching)"
based-on: requirements.md v1.4.0
status: approved
version: 1.2.1
created: "2026-10-27"
---

> Part of split specification. See `specifications-index.md` for full scope.

## 1. Overview

### 1.1 Purpose

本書は、glob パターンとファイルパスの照合規則と、ファイルを残すかどうかを決める保持条件を定義する。

### 1.2 Scope

本書は、glob の各記号の意味、パス全体への一致、保持条件、出力前の並びを定義する。
入力の正規化は specifications-input.md、出力の書き出しは specifications-output.md で定義する。

---

## 2. Design Principles

### 2.1 Classification Philosophy

照合はパス全体に対して行う (REQ-F-008)。パターンの一部だけが一致しても、一致とはみなさない。
glob の記号として意味を持つのは `**`・`*`・`?` だけであり、その他の文字はすべて文字そのものとして照合する (DR-03)。

`*`・`**`・`?` の意味は、GitHub Actions の `paths` フィルタと同じにする。
パターンを記述順に適用し、最後に一致したパターンで決める点も同じとする (DR-19)。
ただし、次の 2 点は異なる。どのパターンにも一致しないファイルは、先頭のパターンが除外なら残す (DR-19)。ブラケットは文字クラスとして扱わない (DD-MAT-03)。

### 2.2 Design Assumptions

- 2.2 of `specifications-index.md` の前提を満たす。
- パスの区切り文字は `/` とする (REQ-C-009)。

### 2.3 External Design Summary

#### Feature Decomposition

| Unit          | Responsibility                                       | REQ Coverage                    |
| ------------- | ---------------------------------------------------- | ------------------------------- |
| glob-to-regex | 1 つの glob を、パス全体に一致する照合規則に変換する | REQ-F-005〜REQ-F-009            |
| filter        | 保持条件に従って、ファイルを入力順に残す             | REQ-F-003, REQ-F-010, REQ-F-012 |

#### Unit Interaction Map

```text
+---------------+  (rules, 記述順・種別付き)  +--------+  (kept lines)  +-----------------+
| glob-to-regex | --------------------------> | filter | -------------> | output-emission |
+---------------+                             +--------+                +-----------------+
                                                  ^
                                                  | (files lines / patterns lines)
                                            +-------------+
                                            | parse-input |
                                            +-------------+
```

### 2.4 Non-Goals

> **Derivation**: All items below originate from REQUIREMENTS Section "Out of Scope".

- ファイルの実在確認・ファイルシステムの参照 ← REQ: Out of Scope #3
- 正規表現パターンの受け付け ← REQ: Out of Scope #4

### 2.5 Behavioral Design Decisions

| ID        | Decision                                                                       | Rationale                                                                 | Affected Rules       | Status |
| --------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------- | -------------------- | ------ |
| DD-MAT-01 | `**/` は 0 階層以上のディレクトリに一致する (`**/a.sh` は `a.sh` にも一致する) | GitHub の `paths` フィルタ・`.gitignore` と同じ意味にする                 | R-MAT-002, R-MAT-003 | Active |
| DD-MAT-02 | `/` に挟まれない `**` (例: `a**b`、`**.sh`) は `*` と同じ意味とする            | 階層をまたぐ一致は、`/` で区切られた `**` に限る                          | R-MAT-005            | Active |
| DD-MAT-03 | ブラケット `[...]` は文字クラスとして扱わず、文字そのものとして照合する        | glob の記号を `**`・`*`・`?` に絞り、照合規則を単純に保つ (DR-03)         | R-MAT-008            | Active |
| DD-MAT-04 | `*` と `?` は先頭の `.` (隠しファイル) にも一致する                            | 隠しファイルを特別扱いする規則を設けない                                  | R-MAT-006, R-MAT-007 | Active |
| DD-MAT-05 | `?` の 1 文字は UTF-8 の 1 文字 (コードポイント) とする                        | 非 ASCII のパスをバイト単位で分断しない。結合文字は複数の文字として数える | R-MAT-007            | Active |
| DD-MAT-06 | 照合は大文字・小文字を区別する                                                 | ubuntu runner のファイルシステムと同じ。シェルのオプションに依存しない    | R-MAT-009            | Active |

**Status Values:**

- `Active` — Currently in effect within this specification
- `Promoted → DR-xx` — Elevated to formal Decision Record (see Section 2.6)

### 2.6 Related Decision Records

| DR-ID | Title                                                          | Phase | Impact on This Spec  |
| ----- | -------------------------------------------------------------- | ----- | -------------------- |
| DR-02 | glob を独自に正規表現へ変換して照合する                        | req   | 照合規則の実現方式   |
| DR-03 | パターンは glob のみ受け付け、正規表現は受け付けない           | req   | R-MAT-008            |
| DR-19 | パターンは記述順に適用し、最後に一致したパターンで保持を決める | impl  | R-MAT-010〜R-MAT-013 |

### 2.7 DD to DR Promotion Criteria

See `specifications-index.md` 2.7.

---

## 3. Behavioral Specification

### 3.1 Input Domain

- Input Type: 正規化済みのファイル行 (0 行以上) と、検査済みのパターン行 (`pattern` / `!pattern`、入力の順、0 件以上)
- Assumptions: specifications-input.md の規則で正規化・検査済みである。

### 3.2 Output Semantics

- Output Meaning: 保持行 (保持条件を満たしたファイル行) の並び
- Possible Outcomes:
  - 保持行 (0 行以上、入力順、重複を含む)
  - 本書の範囲ではエラーは発生しない

<!-- impl-note: glob_to_regex <glob> はアンカー付きの ERE を標準出力へ返す。変換例:
  `**/` (先頭または `/` の直後) → `(.*/)?`、末尾の `/**` → `/.+`、パターン全体が `**` → `.*`、
  その他の `**` と `*` → `[^/]*`、`?` → `[^/]`、その他の文字はエスケープする。
  filter_files <files> <patterns> は、parse_patterns の結果 (check_patterns で検査済みの `pattern` / `!pattern` の行、入力の順) を受け取る。
  照合ループの前に、各パターンを 1 回だけ ERE に変換し、種別と ERE を入力の順に持つ。除外は先頭の `!` を 1 つだけ除いてから変換する。
  ファイルごとに最後のパターンから先頭へ照合し、最初に一致したパターンで決める (DR-19)。保持行を LF 区切りで標準出力へ返す。
  照合する関数は本体をサブシェルで書き、その中で `shopt -u nocasematch` と `LC_ALL=C.UTF-8` を設定して行う (呼び出し元のオプションとロケールは変わらない)。
  照合方式 (正規表現への変換か、セグメント単位か) とループ方式は impl で決める (index Open Questions)。 -->

---

## 4. Decision Rules

**照合規則 (1 つのパターンと 1 つのパス):**

| Rule ID   | Step | Condition                                        | Outcome                                                        |
| --------- | ---: | ------------------------------------------------ | -------------------------------------------------------------- |
| R-MAT-001 |    1 | パターンとパス                                   | パターン全体がパス全体に一致した場合だけ一致とする             |
| R-MAT-002 |    2 | パターン全体が `**`                              | すべてのパスに一致する                                         |
| R-MAT-003 |    3 | パターンの先頭、または `/` の直後にある `**/`    | 0 個以上のディレクトリ (`<名前>/` の繰り返し) に一致する       |
| R-MAT-004 |    4 | パターンの末尾にある `/**`                       | `/` と、それに続く 1 文字以上の任意の文字列に一致する          |
| R-MAT-005 |    5 | R-MAT-002〜004 に当たらない `**`                 | `*` と同じ意味とする (DD-MAT-02)                               |
| R-MAT-006 |    6 | `*`                                              | `/` 以外の 0 文字以上に一致する                                |
| R-MAT-007 |    7 | `?`                                              | `/` 以外の 1 文字 (UTF-8 の 1 文字) に一致する                 |
| R-MAT-008 |    8 | その他の文字 (`.`・`[`・`]`・`\`・`+`・`(` など) | 文字そのものに一致する                                         |
| R-MAT-009 |    — | すべての照合 (全 Step に共通)                    | 大文字・小文字を区別する。シェルのオプションの状態に依存しない |

パターンは先頭から読み、`**` を `*` より先に判定する (最長一致)。
照合規則への変換は失敗しない。すべての文字が R-MAT-002〜008 のいずれかに当たるため、本書の範囲でエラーは起きない。
`**/` として消費した後に残る `**` は、R-MAT-002〜004 の条件を改めて判定する。末尾の `/**` に当たらなければ R-MAT-005 とする。

**保持条件 (1 つのパス):**

| Rule ID   | Step | Condition                                                      | Outcome                                              |
| --------- | ---: | -------------------------------------------------------------- | ---------------------------------------------------- |
| R-MAT-010 |    1 | パターンが 0 件                                                | 残す (REQ-F-004)                                     |
| R-MAT-011 |    2 | パスに一致したパターンのうち、記述順で最後のものが包含パターン | 残す (DR-19)                                         |
| R-MAT-012 |    3 | パスに一致したパターンのうち、記述順で最後のものが除外パターン | 捨てる (DR-19)                                       |
| R-MAT-013 |    4 | どのパターンにも一致しない                                     | 先頭のパターンが除外なら残し、包含なら捨てる (DR-19) |

- 包含と除外は 1 つの並びとして扱い、入力の行の順を保つ。パターンの順序を入れ替えると結果が変わり得る。
- 除外パターンの照合には、先頭の `!` を 1 つだけ除いた残りを使う (R-IN-004)。
- 保持行は、入力の順序を保ち、重複を除かない。
- 判定はパスの文字列だけで行い、git とファイルシステムは参照しない (REQ-F-012)。

No reordering is permitted.

---

## 5. Edge Cases

| Pattern                                    | Path                               | Result               | REQ       | Rationale                                                        |
| ------------------------------------------ | ---------------------------------- | -------------------- | --------- | ---------------------------------------------------------------- |
| `*.sh`                                     | `a.sh` / `dir/a.sh`                | 一致 / 不一致        | REQ-F-006 | R-MAT-006                                                        |
| `**`                                       | `a.sh` / `dir/sub/a.sh`            | 一致 / 一致          | REQ-F-005 | R-MAT-002                                                        |
| `**/a.sh`                                  | `a.sh` / `x/a.sh` / `x/y/a.sh`     | すべて一致           | REQ-F-005 | R-MAT-003, DD-MAT-01                                             |
| `dir/**`                                   | `dir/a.sh` / `dir/sub/a.sh`        | 一致 / 一致          | REQ-F-005 | R-MAT-004                                                        |
| `dir/**`                                   | `dir` / `dirx/a.sh`                | 不一致 / 不一致      | REQ-F-005 | `/` の後に 1 文字以上が必要                                      |
| `a/**/b.sh`                                | `a/b.sh` / `a/x/y/b.sh`            | 一致 / 一致          | REQ-F-005 | R-MAT-003                                                        |
| `**/**`                                    | `a.sh` / `x/y/a.sh`                | 一致 / 一致          | REQ-F-005 | `**/` の後に残る `**` は R-MAT-005                               |
| `a/**/**/b`                                | `a/b` / `a/x/y/b`                  | 一致 / 一致          | REQ-F-005 | `**/` の連続はそれぞれ 0 階層以上                                |
| `a\` (末尾が `\`)                          | `a\` / `a`                         | 一致 / 不一致        | REQ-F-009 | `\` は文字そのもの (R-MAT-008)                                   |
| `a**/b`                                    | `ax/b` / `a/x/b`                   | 一致 / 不一致        | REQ-F-005 | `/` の直後ではない `**/` は R-MAT-005 の `**` と文字 `/`         |
| `a**b`                                     | `axxb` / `ax/xb`                   | 一致 / 不一致        | REQ-F-005 | R-MAT-005, DD-MAT-02                                             |
| `***.sh`                                   | `a.sh` / `d/a.sh`                  | 一致 / 不一致        | REQ-F-005 | `**` (R-MAT-005) と `*` の連続                                   |
| `dir/?.sh`                                 | `dir/a.sh` / `dir/ab.sh`           | 一致 / 不一致        | REQ-F-007 | R-MAT-007                                                        |
| `?.sh`                                     | `あ.sh`                            | 一致                 | REQ-F-007 | DD-MAT-05                                                        |
| `*`                                        | `.env` / `dir/.env`                | 一致 / 不一致        | REQ-F-006 | DD-MAT-04                                                        |
| `a.sh`                                     | `aXsh`                             | 不一致               | REQ-F-009 | `.` は文字そのもの (R-MAT-008)                                   |
| `[ab].sh`                                  | `a.sh` / `[ab].sh`                 | 不一致 / 一致        | REQ-F-009 | DD-MAT-03                                                        |
| `a+(b).sh`                                 | `a+(b).sh`                         | 一致                 | REQ-F-009 | R-MAT-008                                                        |
| `*.SH`                                     | `a.sh`                             | 不一致               | REQ-F-006 | DD-MAT-06                                                        |
| `src`                                      | `src/a.sh`                         | 不一致               | REQ-F-008 | パス全体への一致 (R-MAT-001)                                     |
| `"b.sh"`                                   | `b.sh`                             | 不一致               | REQ-F-016 | クオートは文字そのもの。`"` を含むファイル行は R-IN-012 でエラー |
| `!*.md` (除外のみ)                         | `a.sh` / `a.md`                    | 残す / 捨てる        | REQ-F-003 | R-MAT-013 (先頭が除外), R-MAT-012                                |
| `*.sh` (包含のみ)                          | `a.sh` / `README.md`               | 残す / 捨てる        | REQ-F-003 | R-MAT-011, R-MAT-013 (先頭が包含)                                |
| `src/**`, `!src/gen/**`                    | `src/a.sh` / `src/gen/b.sh`        | 残す / 捨てる        | REQ-F-003 | R-MAT-011, R-MAT-012 (後の除外が先の包含を打ち消す)              |
| `!src/gen/**`, `src/**`                    | `src/a.sh` / `src/gen/b.sh`        | 残す / 残す          | REQ-F-003 | R-MAT-011 (後の包含が先の除外を打ち消す。順序で結果が変わる)     |
| `src/**`, `!src/gen/**`, `src/gen/keep.sh` | `src/gen/b.sh` / `src/gen/keep.sh` | 捨てる / 残す        | REQ-F-003 | R-MAT-012, R-MAT-011 (除外の後の包含で戻す。AC-019)              |
| `!*.md`, `docs/*.md`                       | `a.sh` / `b.md` / `docs/c.md`      | 残す / 捨てる / 残す | REQ-F-003 | R-MAT-013 (先頭が除外), R-MAT-012, R-MAT-011                     |
| `!!a.sh`                                   | `!a.sh` / `a.sh`                   | 捨てる / 残す        | REQ-F-003 | 除外パターンは `!a.sh` (R-IN-004)。`a.sh` は R-MAT-013           |

<!-- impl-note: テストでの検証方法 (fix review TS-02 / TS-03)
  - REQ-F-012: git リポジトリ外の作業ディレクトリで実行し、実在しないが一致するパスと、実在するが一致しないパスを混ぜて結果を確認する。
  - REQ-NF-002: `shopt -s globstar extglob nocasematch nocaseglob` を有効にした状態でも、結果が変わらないことを確認する。 -->

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule            | Notes                                  |
| -------------- | -------------------- | -------------------------------------- |
| REQ-F-003      | R-MAT-011〜R-MAT-013 | DR-19                                  |
| REQ-F-004      | R-MAT-010            | 入力側は R-IN-007                      |
| REQ-F-005      | R-MAT-002〜R-MAT-005 | DD-MAT-01, DD-MAT-02                   |
| REQ-F-006      | R-MAT-006            | DD-MAT-04                              |
| REQ-F-007      | R-MAT-007            | DD-MAT-04, DD-MAT-05                   |
| REQ-F-008      | R-MAT-001            |                                        |
| REQ-F-009      | R-MAT-008            | DD-MAT-03                              |
| REQ-F-012      | R-MAT-013 の注記     | 判定はパスの文字列だけで行う           |
| REQ-NF-002     | R-MAT-009            | DD-MAT-06                              |
| REQ-F-010      | —                    | Covered in: `specifications-output.md` |

---

## 7. Open Questions

> **Status**: COMPLETE

spec の範囲では無い。照合方式とループ方式は impl で決定した (DR-17、`specifications-index.md` 7)。

---

## 8. Change History

| Date       | Version | Description                                                                                                                                                                            |
| ---------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-10-27 | 0.1.0   | Initial draft                                                                                                                                                                          |
| 2026-10-27 | 0.1.1   | Apply spec explore review: add a**/b edge case, state conversion never fails, locale note                                                                                              |
| 2026-10-27 | 0.1.2   | Apply spec fix review: unify term 保持行, refresh based-on                                                                                                                             |
| 2026-10-27 | 1.0.0   | Initial release                                                                                                                                                                        |
| 2026-10-27 | 1.0.1   | Follow requirements v1.1.0: quoted files lines are rejected in input, refresh based-on, approve                                                                                        |
| 2026-10-27 | 1.0.2   | Refresh based-on (requirements v1.2.0)                                                                                                                                                 |
| 2026-10-27 | 1.0.3   | Refresh based-on (requirements v1.3.0)                                                                                                                                                 |
| 2026-10-27 | 1.0.4   | Point open questions to DR-17 (matching method decided in impl)                                                                                                                        |
| 2026-10-29 | 1.1.0   | filter_files takes the classified pattern list as one argument (DR-19)                                                                                                                 |
| 2026-10-29 | 1.2.0   | Follow requirements v1.4.0: rewrite R-MAT-010 to R-MAT-013 to last match wins with the first pattern deciding unmatched files, filter_files takes pattern lines in input order (DR-19) |
| 2026-10-29 | 1.2.1   | Align the locale impl-note with the code: filter_files runs in a subshell and sets LC_ALL=C.UTF-8 there                                                                                |
