---
title: "Design Specification: _ca-resolve-sha (出力と resolution)"
based-on: requirements.md v2.1.0
status: Draft
version: 1.2.0
created: "2026-10-25"
---

> Part of split specification. See `specifications-index.md` for full scope.

## 1. Overview

### 1.1 Purpose

本書は、`_ca-resolve-sha` が解決結果に付ける `resolution` の値と、結果を呼び出し元へ返す出力の振る舞いを定義する。
本書は REQ-F-010 (出力の書き出し) と REQ-F-012 (resolution 出力) を対象 FR とする。

### 1.2 Scope

本書は、resolution の対応付けと出力の書き出しの振る舞い規則と分類の意味を定義する。実装の詳細は対象外とする。

---

## 2. Design Principles

### 2.1 Classification Philosophy

- 検証の失敗では、出力を 1 つも書き出さない。成功時は 3 つの出力をそろえて返す。
- 書き出し開始後の I/O 失敗は防げないため、部分出力を許容し、呼び出し元の契約で扱う (DR-18)。
- 異常は発生源で検出し、握りつぶさない。出力先の異常も例外としない。
- `resolution` は解決経路だけで決まる。同じ経路であれば、常に同じ値となる。

### 2.2 Design Assumptions

- SHA の解決と検査は、本書の外 (入力検証仕様、解決仕様) で完了している。
- `$GITHUB_OUTPUT` は、GitHub Actions ランナーが各ステップに用意するファイルを指す。
- 呼び出し元は、非ゼロ終了したステップの出力を利用しない (`specifications-index.md` 3.2)。

### 2.3 External Design Summary

> **Source**: Derived from the external design dialogue (Phase E) and user-confirmed design direction (Phase D).

#### Feature Decomposition

| Unit                | Responsibility                                   | REQ Coverage |
| ------------------- | ------------------------------------------------ | ------------ |
| resolution-labeling | 解決経路から `resolution` の値を 1 つに決める    | REQ-F-012    |
| output-emission     | 検査を終えた 3 値を、Action の出力として書き出す | REQ-F-010    |

<!-- impl-note: original units "entry" and "output-mapping"
  - entry = main (MAIN、scripts/resolve-sha.sh)。環境変数を読む唯一の箇所とし、NCC → VOV → RSH → EO の順に呼ぶ。
    「if ! out=$(...); then exit 1; fi」の後に read で 3 値へ分解し、EO へ渡す。
  - output-emission = emit_outputs (EO、resolve-sha.lib.sh)。書き込みは _libs/output.lib.sh の write_output (WO) を使う。
    EO は事前検査 (R-OUT-003 から R-OUT-006) を終えてから WO を 3 回呼び、WO の失敗で直ちに停止する。
    WO は未設定、書き込み不能、改行、および書き込み自体の失敗で 0 以外を返す。
  - resolution-labeling の値は、resolve_sha / resolve_head_n が返す第 3 フィールドとして確定する。ラベル専用の関数は設けない。
  - action.yml の outputs は、step 出力キー before_sha / after_sha / resolution を kebab-case の出力名へ値を加工せずに対応付ける。
    REQ-C-001 に従い、run 内に ${{ }} を書かず env 経由で値を渡す。
  - 書き出しの行順は before_sha、after_sha、resolution とする (契約ではない)。 -->

#### Unit Interaction Map

```text
+-----------------+     +---------------------+     +-----------------+
| (入力検証/解決) | --> | resolution-labeling | --> | output-emission |
|  別仕様で定義   |     +---------------------+     +-----------------+
+-----------------+                                         |
        |                                                   v
        +-----(失敗時は呼び出さない)----------------> [Action 出力]
```

#### Data Flow Diagram

```text
[入力検証] --> [SHA 解決 + ラベル] --> [事前検査] --> [書き出し] --> [Action 出力]
     |                |                    |               |
     v                v                    v               v
(失敗: 終了)     (失敗: 終了)        (失敗: 終了)   (I/O 失敗: 終了。部分出力が残り得る)
```

### 2.4 Non-Goals

> **Derivation**: All items below originate from REQUIREMENTS Section "Out of Scope".

- イベント全体の変更網羅の保証 ← REQ: Out of Scope #4。`resolution` に応じた対応は呼び出し元の責務とする。
- `_libs/` の既存関数のシグネチャおよび挙動の変更 ← REQ: Out of Scope #5。出力関数は追加のみとする。
- 近似経路での `::notice::` 出力 ← REQ: Out of Scope #8。経路の通知は `resolution` だけで行う。

### 2.5 Behavioral Design Decisions

| ID        | Decision                                                           | Rationale                                                  | Affected Rules           | Status           |
| --------- | ------------------------------------------------------------------ | ---------------------------------------------------------- | ------------------------ | ---------------- |
| DD-OUT-01 | 解決経路を `resolution` で通知する                                 | 経路に応じた判断を呼び出し元ができるようにするため         | R-OUT-001                | Promoted → DR-08 |
| DD-OUT-02 | 検証の失敗では書き出しを始めず、事前検査は最初の書き込み前に終える | 検証の失敗で部分出力を残さないため                         | R-OUT-002 から R-OUT-006 | Promoted → DR-14 |
| DD-OUT-03 | 書き出し開始後の I/O 失敗による部分出力は許容する                  | 防げない失敗を、防げるように見せかけないため               | R-OUT-008                | Promoted → DR-18 |
| DD-OUT-04 | 本 Action は SHA 解決器であり、変更網羅は保証しない                | ラベルは通知であり、全件検査への切り替えは呼び出し元が担う | R-OUT-001                | Promoted → DR-13 |

> **Note**: すべての DD は、Decision Record へ昇格済みとする。

**Status Values:**

- `Active` — Currently in effect within this specification
- `Promoted → DR-xx` — Elevated to formal Decision Record (see Section 2.6)

### 2.6 Related Decision Records

> **Reference**: This section lists formal DRs that affect this specification.
> DRs are maintained in `decision-records.md` and are authoritative.

| DR-ID | Title                                                         | Phase  | Impact on This Spec                                      |
| ----- | ------------------------------------------------------------- | ------ | -------------------------------------------------------- |
| DR-08 | 解決経路を resolution 出力で通知する                          | req    | resolution の 4 値と経路の対応                           |
| DR-11 | スコープとインターフェースの明確化                            | req    | 汎用出力関数の追加                                       |
| DR-13 | 本 Action は SHA 解決器とし、変更網羅は保証しない             | req    | ラベルが通知に徹し、呼び出し元の判断を縛らないこと       |
| DR-14 | 入力形式・git 障害分類・checkout と出力の契約を厳格化する     | req    | 検証の失敗では書き出さず、出力先の異常をエラーとすること |
| DR-18 | 書き出し中の I/O 失敗による部分出力は、呼び出し元の契約で扱う | review | 書き出し開始後の失敗の扱い                               |
| DR-24 | オーバーライド値に空ツリー SHA を受け付けない                 | review | `override` と `empty-tree` の対応が重ならないこと        |

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

- Input Type: 解決済みの 3 値 (before、after、resolution) と、出力先を示す `GITHUB_OUTPUT`
- Assumptions:
  - before と after は、解決処理が検査を完了した値とする。
  - resolution は、解決経路から決まった 1 つの文字列とする。
  - 環境変数の契約は `specifications-index.md` 3.1 に従う。

<!-- impl-note: original 3.1 の環境変数 8 種の表
  index 3.1 と重複するため削除し、参照に置き換えた。 -->

### 3.2 Output Semantics

- Output Meaning: Action の出力 `before-sha`、`after-sha`、`resolution` を設定する。各値は 1 行とする。
- Possible Outcomes:
  - 成功: 3 つの出力を書き終え、終了コード 0 で終了する。
  - 検証または事前検査の失敗: 出力を 1 つも書かず、エラーを出して非ゼロで終了する。
  - 書き出し開始後の I/O 失敗: エラーを出して非ゼロで終了する。先に書いた出力が残り得る。

エラーの形式は `specifications-index.md` 3.3 に従う。

#### 3.2.1 resolution の値と解決経路の対応

| resolution      | 解決経路                                                                          | REQ                             |
| --------------- | --------------------------------------------------------------------------------- | ------------------------------- |
| override        | 入力 before-sha と after-sha の両方指定 (どちらも実在するコミット)                | REQ-F-011                       |
| event           | push の通常解決、または pull_request                                              | REQ-F-004, REQ-F-008            |
| fallback-head-n | HEAD~N を解決できた経路 (push のフォールバック、その他イベント)                   | REQ-F-005, REQ-F-006, REQ-F-009 |
| empty-tree      | HEAD~N が履歴終端または shallow 境界を越え、空ツリー SHA へフォールバックした経路 | REQ-F-007                       |

- 1 回の実行で設定する値は 1 つだけとする。どの経路も、上の表のちょうど 1 行に該当する。
- 表にない値を `resolution` に設定してはならない。
- resolution は解決経路を示すだけであり、比較範囲が呼び出し元の目的に適していることは示さない (`specifications-index.md` 2.1)。

---

## 4. Decision Rules

Evaluation MUST follow this order:

| Rule ID   | Step | Condition                                                               | Outcome                                                        |
| --------- | ---: | ----------------------------------------------------------------------- | -------------------------------------------------------------- |
| R-OUT-001 |    1 | 解決経路が確定した                                                      | 3.2.1 の対応表に従い resolution を 1 つ決める                  |
| R-OUT-002 |    2 | `specifications-index.md` §4 の Step 1 から Step 6 のいずれかが失敗した | 書き出しを開始せず、非ゼロで終了する                           |
| R-OUT-003 |    3 | `GITHUB_OUTPUT` が未設定または空                                        | エラー終了する。出力は書かない                                 |
| R-OUT-004 |    4 | `GITHUB_OUTPUT` が書き込み不能                                          | エラー終了する。出力は書かない                                 |
| R-OUT-005 |    5 | 3 つの値のいずれかに改行が含まれる                                      | エラー終了する。出力は書かない                                 |
| R-OUT-006 |    6 | resolution が 4 値のいずれでもない                                      | エラー終了する。出力は書かない                                 |
| R-OUT-007 |    7 | R-OUT-003 から R-OUT-006 にいずれも当たらない                           | 3 つの出力を書き出し、終了コード 0 で終了する                  |
| R-OUT-008 |    8 | R-OUT-007 の書き出し中に、書き込みが失敗した                            | エラー終了する。残りの出力は書かない。先に書いた出力は残り得る |

No reordering is permitted.

- R-OUT-003 から R-OUT-006 は、最初の出力を書く前にすべて検査する。
- 書き出しは追記のみとし、既存の出力行を変更しない。
- R-OUT-008 の部分出力は許容する (DR-18)。呼び出し元は、非ゼロ終了時の出力を使わない。

**エラーの文言:**

| Rule ID   | 対象                     | 問題                    |
| --------- | ------------------------ | ----------------------- |
| R-OUT-003 | `GITHUB_OUTPUT`          | 値が空 (空の形式を使う) |
| R-OUT-004 | `GITHUB_OUTPUT`          | 書き込みできない        |
| R-OUT-005 | 改行を含む出力名         | 値が改行を含む          |
| R-OUT-006 | `resolution`             | 4 値のいずれでもない    |
| R-OUT-008 | 書き込みに失敗した出力名 | 書き込みに失敗した      |

エラーの形式は `specifications-index.md` 3.3 に従う。

<!-- impl-note: original R-OUT-002 "環境変数を読むのはエントリ処理だけとし、他の処理には引数で渡す"
  外部から観測できない内部構造のため、規則から外し 2.3 の impl-note へ移した。 -->
<!-- impl-note: original R-OUT-004 "GITHUB_EVENT_NAME が空または未設定である"
  イベント名の検証は resolution 分割ファイルの R-RES-001 に一本化した (DR-17)。 -->
<!-- impl-note: original R-OUT-009 "before_sha、after_sha、resolution の順に 1 行ずつ追記する"
  行の順序は契約ではないため、2.3 の impl-note へ移した。 -->

---

## 5. Edge Cases

| Input                                                             | Classification                                  | REQ                  | Rationale                                                      |
| ----------------------------------------------------------------- | ----------------------------------------------- | -------------------- | -------------------------------------------------------------- |
| `GITHUB_OUTPUT` が未設定                                          | エラー終了。出力なし                            | REQ-F-010            | 出力先が無いまま成功すると、呼び出し元が空の出力を受け取るため |
| `GITHUB_OUTPUT` が書き込み不能 (読み取り専用、不在ディレクトリ等) | エラー終了。出力なし                            | REQ-F-010            | 書き込み失敗を成功として扱わない                               |
| before、after、resolution のいずれかに改行を含む                  | エラー終了。出力なし                            | REQ-F-010            | 1 行の契約を保ち、出力の注入を防ぐため                         |
| 検証の失敗 (commit-count 不正、コミット不在 等)                   | 出力なし。非ゼロ終了                            | REQ-F-010            | 検証の失敗では書き出しを開始しない                             |
| 2 つ目の出力を書く途中で I/O 障害が起きる                         | 非ゼロ終了。1 つ目の出力が残り得る              | REQ-F-010            | 部分出力は許容し、呼び出し元の契約で扱う (DR-18)               |
| 履歴が初回コミットのみで HEAD~N を解決できない                    | resolution は empty-tree。終了コード 0          | REQ-F-007, REQ-F-012 | 履歴不足は異常ではなく、空ツリーへのフォールバック経路         |
| 入力 before-sha と after-sha の両方を指定                         | resolution は override                          | REQ-F-011, REQ-F-012 | オーバーライドはイベント別解決より優先する                     |
| オーバーライドの before が空ツリー SHA                            | エラー終了。出力なし                            | REQ-F-013            | オーバーライドは実在コミットのペアに限る (DR-24)               |
| オーバーライドなしのタグの push、またはブランチ削除の push        | エラー終了。出力なし                            | REQ-F-020            | ブランチの作成・更新以外の push は解決しない (DR-25)           |
| push で before と after が同一の SHA                              | resolution は event                             | REQ-F-004, REQ-F-012 | 値の同一性は経路の判定に影響しない                             |
| pull_request_target                                               | resolution は fallback-head-n または empty-tree | REQ-F-009, REQ-F-012 | その他イベントとして扱う (DR-06)                               |

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule                    | Notes                                                 |
| -------------- | ---------------------------- | ----------------------------------------------------- |
| REQ-F-010      | R-OUT-002 から R-OUT-008, §5 | 検証の失敗では書かず、出力先の異常と I/O 失敗はエラー |
| REQ-F-012      | R-OUT-001, R-OUT-006, 3.2.1  | 経路と 4 値の対応。4 値以外を拒否する                 |
| その他の REQ   | —                            | Covered in: `specifications-index.md` §6 の対応表     |

---

## 7. Open Questions

> **Status**: COMPLETE

| # | Question                                                                 | Source | Impact |
| - | ------------------------------------------------------------------------ | ------ | ------ |
| — | None identified - all requirements in this file's scope are unambiguous. | —      | —      |

旧版の Open Question (書き出し中の I/O 失敗による部分出力) は、DR-18 で解消した (R-OUT-008)。

---

## 8. Change History

<!-- SemVer: see .claude/rules/deckrd-rule-document-versioning.md -->

| Date       | Version | Description                                                                                        |
| ---------- | ------- | -------------------------------------------------------------------------------------------------- |
| 2026-10-25 | 1.0.0   | Initial specification                                                                              |
| 2026-10-25 | 1.1.0   | Apply requirements v1.2.0: partial write on I/O failure, empty-tree label, R-OUT- renumbering      |
| 2026-10-25 | 1.1.1   | Follow requirements v2.0.0 (based-on refresh only)                                                 |
| 2026-10-25 | 1.2.0   | Apply requirements v2.1.0: override with empty tree before is an error, empty-tree route condition |
