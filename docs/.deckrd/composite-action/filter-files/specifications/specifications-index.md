---
title: "Design Specification: _ca-filter-files (Index)"
based-on: requirements.md v1.0.0
status: Draft
version: 1.0.0
created: "2026-10-27"
---

> Part of split specification. See `specifications-index.md` for full scope.

## 1. Overview

### 1.1 Purpose

本書は、`_ca-filter-files` 仕様の分割ファイル群の入口とする。
モジュール全体の概要、分割ファイルの一覧、共有インターフェース、共有規約、評価順序を定義する。

FR ごとの詳細な振る舞いは、各分割ファイルで定義する。本書では再掲しない。

### 1.2 Scope

本書は、`_ca-filter-files` の振る舞い規則のうち、複数の分割ファイルが共有する部分を定義する。
実装の詳細は対象外とする。

### 1.3 Split Files

| File                                                       | Covered REQ                                                                 | Summary                                                          |
| ---------------------------------------------------------- | --------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| [specifications-input.md](./specifications-input.md)       | REQ-F-001, REQ-F-002, REQ-F-004, REQ-F-016                                  | 入力の行分割と正規化、パターンの分類、不正なパターンを定義する。 |
| [specifications-matching.md](./specifications-matching.md) | REQ-F-003, REQ-F-005, REQ-F-006, REQ-F-007, REQ-F-008, REQ-F-009, REQ-F-012 | glob の照合規則と保持条件を定義する。                            |
| [specifications-output.md](./specifications-output.md)     | REQ-F-010, REQ-F-011, REQ-F-013, REQ-F-014, REQ-F-015                       | 出力先の検証、出力値の組み立て、複数行出力の書式を定義する。     |

### 1.4 ID Conventions

| 種別     | 書式        | 定義する分割ファイル       |
| -------- | ----------- | -------------------------- |
| 判定規則 | `R-IN-NNN`  | specifications-input.md    |
| 判定規則 | `R-MAT-NNN` | specifications-matching.md |
| 判定規則 | `R-OUT-NNN` | specifications-output.md   |
| 設計判断 | `DD-IDX-NN` | 本書                       |
| 設計判断 | `DD-IN-NN`  | specifications-input.md    |
| 設計判断 | `DD-MAT-NN` | specifications-matching.md |
| 設計判断 | `DD-OUT-NN` | specifications-output.md   |

ID は分割ファイルをまたいで一意とし、廃止した ID は再利用しない。

---

## 2. Design Principles

### 2.1 Classification Philosophy

本 Action は、文字列として受け取ったファイルリストを glob パターンで絞り込む純粋なフィルタとして振る舞う (DR-01)。
git とファイルシステムは参照せず、入力の文字列と照合規則だけで結果を決める (REQ-F-012)。

照合規則は本仕様で定義した glob 規則に限る。正規表現は受け付けない (DR-03)。
シェルのオプションの状態に依存しない (REQ-NF-002)。

一致 0 件・空入力は正常な結果とする。非ゼロで終了するのは、不正なパターンと出力不能の場合に限る (DR-09)。

### 2.2 Design Assumptions

- 呼び出し元は、REQ-C-009 の入力契約を守る。パスはデコード済み・リポジトリ相対・正規化済みで、改行を含まない。
- 入力のダブルクオートは、GitHub Actions が YAML として解釈した後の値で届く (DR-11)。
- 実行環境は GitHub Actions の ubuntu runner の Bash とし、UTF-8 ロケールを利用できる。

<!-- impl-note: original said "UTF-8 ロケール (`C.UTF-8`) を利用できる"。照合は LC_ALL=C.UTF-8 で行う。
  ロケールの有無は検査しない。ubuntu runner (glibc 2.35 以降) では C.UTF-8 が組み込みで必ず使える。 -->

- 本 Action は、`contents: read` 以外の権限を必要としない (REQ-C-002)。
- UTF-8 として不正なバイト列を含む入力は、エラーとする (specifications-input.md R-IN-010)。
- 両端に空白を持つファイル名は、正規化で別の名前になるため保証しない (DR-08)。
- パスは CR・LF を含まない (REQ-C-009)。

前提が破れた場合の挙動は、本仕様で定義した範囲を除き保証しない。

### 2.3 External Design Summary

> **Source**: Derived from the external design dialogue (Phase E) and user-confirmed design direction (Phase D).

#### Feature Decomposition

| Unit              | Responsibility                                         | REQ Coverage                    |
| ----------------- | ------------------------------------------------------ | ------------------------------- |
| parse-input       | 入力を行に分割し、両端の空白を除いて空行を捨てる       | REQ-F-001, REQ-F-016            |
| classify-patterns | パターン行を包含と除外に分け、不正なパターンを検出する | REQ-F-002, REQ-F-004            |
| glob-to-regex     | 1 つの glob を、パス全体に一致する照合規則に変換する   | REQ-F-005〜REQ-F-009            |
| filter            | 保持条件に従って、ファイルを入力順に残す               | REQ-F-003, REQ-F-010, REQ-F-012 |
| output-emission   | 出力先を検証してから、`files` と `count` を書き出す    | REQ-F-011, REQ-F-013〜REQ-F-015 |

#### Unit Interaction Map

```text
+-------------+     +-------------------+     +---------------+
| parse-input | --> | classify-patterns | --> | glob-to-regex |
+-------------+     +-------------------+     +---------------+
       |                                              |
       | (files)                                      | (rules)
       v                                              v
+-----------------------------------------------------------+
|                          filter                           |
+-----------------------------------------------------------+
                              |
                              v
                    +-------------------+
                    |  output-emission  |
                    +-------------------+
```

いずれかのユニットでエラーが起きた場合は、後続のユニットを呼び出さずに終了する。

#### Data Flow Diagram

```text
[INPUT_FILES / INPUT_PATTERNS] --> [parse-input] --> [classify-patterns] --> [glob-to-regex]
                                                            |                       |
                                                            v                       v
                                                     [::error:: exit]          [filter] --> [output-emission] --> [outputs]
                                                                                                   |
                                                                                                   v
                                                                                            [::error:: exit]
```

### 2.4 Non-Goals

> **Derivation**: All items below originate from REQUIREMENTS Section "Out of Scope".

- `ca-get-changed-files` の置き換え ← REQ: Out of Scope #1
- ファイル一覧の取得 ← REQ: Out of Scope #2
- ファイルの実在確認・ファイルシステムの参照 ← REQ: Out of Scope #3
- 正規表現パターンの受け付け ← REQ: Out of Scope #4
- JSON 配列形式の出力 ← REQ: Out of Scope #5

### 2.5 Behavioral Design Decisions

| ID        | Decision                                                       | Rationale                                                    | Affected Rules             | Status           |
| --------- | -------------------------------------------------------------- | ------------------------------------------------------------ | -------------------------- | ---------------- |
| DD-IDX-01 | エラー形式を `_ca-resolve-sha` と同じ 3.3 の形式にする         | 内部 Action 間でエラーの読み方をそろえる (spec Phase 6)      | 全分割ファイルのエラー規則 | Promoted → DR-15 |
| DD-IDX-02 | 入力の検証をすべて終えてから、出力先を検証し、書き出しを始める | 出力の一部だけが書かれた状態を、検証の失敗で残さない (DR-09) | 4. Evaluation Order        | Active           |

> **Note**: DD-IDX-01 と DD-IDX-02 は、REQUIREMENTS の記述ではなく、確定した外部設計に由来する。
> 正式な Decision Record へ昇格する場合は `/deckrd dr --add` を使う。

**Status Values:**

- `Active` — Currently in effect within this specification
- `Promoted → DR-xx` — Elevated to formal Decision Record (see Section 2.6)

### 2.6 Related Decision Records

> **Reference**: This section lists formal DRs that affect this specification.
> DRs are maintained in `decision-records.md` and are authoritative.

| DR-ID | Title                                                                    | Phase  | Impact on This Spec      |
| ----- | ------------------------------------------------------------------------ | ------ | ------------------------ |
| DR-01 | ファイルフィルタを git diff から独立した内部 Action に切り出す           | req    | モジュール全体の存在理由 |
| DR-02 | glob を独自に正規表現へ変換して照合する                                  | req    | 照合規則の実現方式       |
| DR-03 | パターンは glob のみ受け付け、正規表現は受け付けない                     | req    | 照合規則の範囲           |
| DR-04 | 包含パターンが 0 件の場合は全ファイルを通す                              | req    | 保持条件                 |
| DR-05 | 除外パターンは包含パターンより優先する                                   | req    | 保持条件                 |
| DR-06 | ca-get-changed-files の置き換えは get-changed-files 側で扱う             | req    | Non-Goals                |
| DR-07 | 複数行出力関数を `_libs` に追加し、区切り文字を一意な文字列にする        | req    | 複数行出力の書式         |
| DR-08 | 入力行の両端の空白を除去し、空になった行を無視する                       | review | 入力の正規化             |
| DR-09 | 非ゼロで終了するのは出力不能時と、spec で不正と決めた入力に限る          | review | 失敗条件と評価順序       |
| DR-10 | 入力の前提を呼び出し元の義務として定める                                 | review | 前提                     |
| DR-11 | ダブルクオートの解釈は GitHub Actions (YAML) に任せ、Action では外さない | req    | 入力の正規化             |
| DR-12 | 出力先の検証関数を `_libs/output.lib.sh` に追加する                      | spec   | 出力先の検証             |
| DR-13 | 共有出力関数の契約を定める                                               | review | 共有関数の契約           |
| DR-14 | 不正な入力を定義し、最初の 1 件で終了する                                | review | 不正な入力と報告の件数   |
| DR-15 | エラー形式を内部 Action 共通の形式にそろえる                             | review | エラー形式               |

### 2.7 DD to DR Promotion Criteria

> **Purpose**: Guidelines for determining when a DD should be promoted to a formal DR.
> Promotion is a **human judgment** — these criteria inform, not automate.

**Consider promoting a DD when:**

1. Cross-specification Impact — The decision affects multiple specifications or modules
2. Architectural Significance — The decision constrains future design choices
3. Non-trivial Alternatives — Multiple viable options existed
4. Stakeholder Visibility Required — The decision should be reviewable by external parties

**Keep as DD when:**

- Decision is local to this specification only
- No significant alternatives existed
- Rationale is self-evident from context

> **Action**: To promote, run `/deckrd dr --add` with the DD context,
> then update DD Status to `Promoted → DR-xx`.

---

## 3. Behavioral Specification

### 3.1 Input Domain

- Input Type: 呼び出し元が指定する 2 つの入力と、実行環境が提供する出力先
- Assumptions: 2.2 の前提を満たす。

**Action 入力:**

| Input      | required | 既定値 | 意味                                           |
| ---------- | -------- | ------ | ---------------------------------------------- |
| `files`    | true     | —      | 絞り込み対象のファイルパス。1 行 1 件          |
| `patterns` | false    | ""     | glob パターン。1 行 1 件。`!` で始まる行は除外 |

GitHub Actions は Composite Action の `required: true` を強制しない。`files` が未指定の場合は空として届き、0 行として扱う。

**環境変数契約:**

| Variable         | 由来                    | 備考                                   |
| ---------------- | ----------------------- | -------------------------------------- |
| `INPUT_FILES`    | 入力 `files`            | 規則は input 分割ファイルが定義する。  |
| `INPUT_PATTERNS` | 入力 `patterns`         | 同上                                   |
| `GITHUB_OUTPUT`  | GitHub Actions ランナー | 規則は output 分割ファイルが定義する。 |

- 値は環境変数経由でのみ受け取る (REQ-C-001)。`run` 内に `${{ }}` を書かない。
- Composite Action は `INPUT_*` を自動設定しない。`action.yml` は、各入力を上表の環境変数へ step の `env` で明示的に対応付ける (REQ-C-005)。

### 3.2 Output Semantics

- Output Meaning: 保持されたファイルパスと、その件数
- Possible Outcomes:
  - 成功: `files` と `count` が設定され、終了コードは 0 となる。一致 0 件でも成功とする。
  - 入力の検証の失敗 (不正なパターン・UTF-8 として不正な行): 出力を 1 つも書き出さず、最初のエラーを 1 件出して非ゼロで終了する。
  - 出力先の検証の失敗: 出力を 1 つも書き出さず、エラーを出して非ゼロで終了する。
  - 書き出し開始後の書き込み失敗: エラーを出して非ゼロで終了する。`files` だけが書かれた状態が残り得る (DR-09)。

**Action 出力:**

| Output  | 意味                                                                 |
| ------- | -------------------------------------------------------------------- |
| `files` | 保持されたファイルパス。1 行 1 件、入力順。0 件なら空文字列          |
| `count` | 保持されたファイル数。先頭ゼロ・前後の空白を含まない 10 進整数文字列 |

- 呼び出し元は、非ゼロ終了したステップの出力を利用してはならない。

### 3.3 Shared Conventions

**エラー形式 (DD-IDX-01):**

- エラーは `::error::<対象>: <問題> (got: '<値>')` の形式で、標準エラー出力へ 1 行で出す。
- 対象は、入力名・環境変数名・出力名のいずれかとする。
- 値が空の場合は、`::error::<対象>: value must not be empty` の形式とする。
- エラーを出した後は、非ゼロの終了コードで終了する。
- `<値>` は、`%` を `%25`、CR を `%0D`、LF を `%0A` に置き換えて埋め込む。

各分割ファイルのエラー規則は、この形式に従う。分割ファイルでは形式を再定義しない。

### 3.4 Evaluation Order

評価は次の順で行う (DD-IDX-02)。

| Step | 処理                                                                         | 定義                       |
| ---: | ---------------------------------------------------------------------------- | -------------------------- |
|    1 | `files` と `patterns` を行に分割し、UTF-8 として正しいかを検査し、正規化する | specifications-input.md    |
|    2 | パターンを分類し、不正なパターンを検出する                                   | specifications-input.md    |
|    3 | 各パターンを照合規則に変換し、ファイルを絞り込む                             | specifications-matching.md |
|    4 | 出力先を検証する                                                             | specifications-output.md   |
|    5 | `files`、`count` の順に書き出す                                              | specifications-output.md   |

No reordering is permitted. 各 Step でエラーが起きた場合は、後続の Step を実行しない。

### 3.5 Function List

<!-- impl-note: public function list and test ID abbreviations
  テスト ID は T-FF-<略称>-NN とする。略称はレイヤサフィックスを除いたベース略称とする。

  | 略称 | 関数                                        | 所在                                | 担当分割ファイル    |
  | ---- | ------------------------------------------- | ----------------------------------- | ------------------- |
  | VOF  | validate_output_file <file>                 | _libs/output.lib.sh                 | output              |
  | WMO  | write_multiline_output <file> <key> <value> | _libs/output.lib.sh                 | output              |
  | FE   | ff_error <target> <problem> [<value>]       | scripts/_libs/filter-files.lib.sh   | index 3.3           |
  | PL   | parse_lines <text>                          | scripts/_libs/filter-files.lib.sh   | input               |
  | CP   | classify_patterns <lines>                   | scripts/_libs/filter-files.lib.sh   | input               |
  | GTR  | glob_to_regex <glob>                        | scripts/_libs/filter-files.lib.sh   | matching            |
  | FF   | filter_files <files> <include> <exclude>    | scripts/_libs/filter-files.lib.sh   | matching            |
  | EO   | emit_outputs <file> <kept>                  | scripts/_libs/filter-files.lib.sh   | output              |
  | MAIN | main (scripts/filter-files.sh)              | scripts/filter-files.sh             | output (functional) |
  | ACT  | action.yml の静的検査                       | action.yml                          | index 3.1           |

  - write_output は既存の共有関数 (resolve-sha が所有) を使う。テスト ID は割り当てない。
  - 共有ライブラリへの追加は VOF と WMO の 2 点のみとする (REQ-C-007)。
  - VOF と WMO はエラーを出さず、終了コードだけを返す。エラーは呼び出し側が FE で 3.3 の形式で出す。
  - 環境変数を読むのは MAIN のみとし、他の関数は引数だけを入力とする。
  - CP の包含・除外の受け渡し方式 (配列名の受け渡し、区切り出力など) は impl で決める。
  - module.md の owns に `_libs/__tests__/unit/` の VOF / WMO のテストファイルを明示する (テスト ID 検査 A)。
-->

---

## 4. Decision Rules

本書は判定規則を持たない。評価順序は 3.4、各判定規則は分割ファイルが定義する。

---

## 5. Edge Cases

横断的なエッジケースのみを示す。個別のエッジケースは各分割ファイルで定義する。

| Input                                  | Classification                   | REQ                  | Rationale                            |
| -------------------------------------- | -------------------------------- | -------------------- | ------------------------------------ |
| 不正なパターンがあり、出力先も使えない | 不正なパターンのエラーで終了する | REQ-F-002, REQ-F-015 | 入力の検証が先 (DD-IDX-02)           |
| `files` が未指定 (空として届く)        | 0 件の正常終了                   | REQ-F-014            | `required: true` は強制されない      |
| `files` 0 行で、不正なパターンがある   | 不正なパターンのエラーで終了する | REQ-F-002            | パターンの検証はファイル数によらない |

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule                    | Notes                                    |
| -------------- | ---------------------------- | ---------------------------------------- |
| REQ-F-001      | R-IN-001〜R-IN-003, R-IN-010 | Covered in: `specifications-input.md`    |
| REQ-F-002      | R-IN-004〜R-IN-006, R-IN-009 | Covered in: `specifications-input.md`    |
| REQ-F-003      | R-MAT-010〜R-MAT-013         | Covered in: `specifications-matching.md` |
| REQ-F-004      | R-IN-007, R-MAT-010          | input / matching                         |
| REQ-F-005      | R-MAT-002〜R-MAT-005         | Covered in: `specifications-matching.md` |
| REQ-F-006      | R-MAT-006                    | Covered in: `specifications-matching.md` |
| REQ-F-007      | R-MAT-007                    | Covered in: `specifications-matching.md` |
| REQ-F-008      | R-MAT-001                    | Covered in: `specifications-matching.md` |
| REQ-F-009      | R-MAT-008                    | Covered in: `specifications-matching.md` |
| REQ-F-010      | R-OUT-003                    | Covered in: `specifications-output.md`   |
| REQ-F-011      | R-OUT-005                    | Covered in: `specifications-output.md`   |
| REQ-F-012      | 2.1, R-MAT-013 の注記        | Covered in: `specifications-matching.md` |
| REQ-F-013      | R-OUT-010〜R-OUT-014         | Covered in: `specifications-output.md`   |
| REQ-F-014      | R-OUT-004                    | Covered in: `specifications-output.md`   |
| REQ-F-015      | R-OUT-001, R-OUT-002, 3.4    | Covered in: `specifications-output.md`   |
| REQ-F-016      | R-IN-008                     | Covered in: `specifications-input.md`    |
| REQ-NF-002     | 2.1, R-MAT-009               | Covered in: `specifications-matching.md` |
| REQ-C-001      | 3.1                          | 環境変数契約                             |
| REQ-C-005      | 3.1, 3.2                     | Action 入出力                            |
| REQ-C-006      | 3.3, 3.5                     | エラー形式と関数構成                     |
| REQ-C-007      | 3.5                          | 共有ライブラリへの追加                   |
| REQ-C-009      | 2.2                          | 前提                                     |

---

## 7. Open Questions

> **Status**: COMPLETE

spec で決める項目は、すべて各分割ファイルで決定した。impl で決める項目を次に示す。

| # | Question                                                                                    | Source             | Impact               |
| - | ------------------------------------------------------------------------------------------- | ------------------ | -------------------- |
| 1 | 照合方式: 正規表現への変換 (DR-02) と、`/` 区切りのセグメント単位照合の実装量・テスト容易性 | REQ Open Questions | matching の実現方式  |
| 2 | 照合をファイルごとのループで行うか、`grep -E` などでまとめて行うか                          | REQ Open Questions | 入力順・正規化の保持 |

---

## 8. Change History

| Date       | Version | Description                                                               |
| ---------- | ------- | ------------------------------------------------------------------------- |
| 2026-10-27 | 0.1.0   | Initial draft                                                             |
| 2026-10-27 | 0.1.1   | Apply spec explore review: assumptions, failure outcomes and locale note  |
| 2026-10-27 | 0.1.2   | Apply spec harden review: promote DD-IDX-01 to DR-15, list DR-13 to DR-15 |
| 2026-10-27 | 0.1.3   | Apply spec fix review: UTF-8 check in evaluation step 1, refresh based-on |
| 2026-10-27 | 1.0.0   | Initial release                                                           |
