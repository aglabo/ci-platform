---
title: "Design Specification: _ca-resolve-sha (入力検証とオーバーライド)"
based-on: requirements.md v2.1.0
status: Draft
version: 1.1.2
created: "2026-10-25"
---

> Part of split specification. See `specifications-index.md` for full scope.

## 1. Overview

### 1.1 Purpose

本書は、`_ca-resolve-sha` が受け取る入力の検証規則と、オーバーライドの判定を定義する。
対象は、commit-count と、before-sha / after-sha の明示オーバーライドとする。
これらは、イベント名の検証とイベント別の SHA 解決より前に評価する。

### 1.2 Scope

本書は、入力検証とオーバーライド判定の振る舞い規則と分類の意味を定義する。実装の詳細は対象外とする。

本書は REQ-F-001、REQ-F-002、REQ-F-003、REQ-F-011、REQ-F-015、REQ-F-016 を担当する。
イベント名の検証、イベント別の解決、コミット検査は `specifications-resolution.md` が扱う。
出力の書き出しは `specifications-output.md` が扱う。

---

## 2. Design Principles

### 2.1 Classification Philosophy

入力は、SHA 解決を始める前にすべて確定させる。
不正な入力は、後続の処理に進ませず、発生源で拒否する。
この規則は、イベントの種別を問わず全イベントへ同じく適用する。

評価の順序は §4 の判定規則の順序とする。

### 2.2 Design Assumptions

- 入力は、呼び出し元から文字列として渡される。
- 未指定の入力は、空文字列または既定値として届く。
- 入力の検証はローカルで完結し、git リポジトリの状態には依存しない。

### 2.3 External Design Summary

> **Source**: Derived from the external design dialogue (Phase E) and user-confirmed design direction (Phase D).

#### Feature Decomposition

| Unit                   | Responsibility                                                     | REQ Coverage         |
| ---------------------- | ------------------------------------------------------------------ | -------------------- |
| commit-count 正規化    | 未指定または明示的な空文字列を既定値 1 として扱う                  | REQ-F-001            |
| commit-count 検証      | 正整数の形式と上限を検証し、他の入力より先に完了させる             | REQ-F-002, REQ-F-003 |
| オーバーライド判定     | before-sha と after-sha を、指定なし、両方指定、片方のみに分類する | REQ-F-011, REQ-F-015 |
| オーバーライド形式検証 | 両方指定された値が完全長の小文字 16 進 OID であることを検証する    | REQ-F-016            |

<!-- impl-note: commit-count 正規化と検証は normalize_commit_count (NCC) が担当し、正整数検証は _libs の validate_positive_int (VPI) を使う。
  オーバーライド判定と形式検証は validate_override (VOV) が担当し、形式判定も VOV が行う。VOV は none または override を返す。 -->

#### Unit Interaction Map

```text
+------------------+     +------------------+     +------------------+
| commit-count     | --> | commit-count     | --> | オーバーライド   |
| 正規化           |     | 検証             |     | 判定             |
+------------------+     +------------------+     +------------------+
                                                          |
                                                          v
                                                  +------------------+
                                                  | オーバーライド   |
                                                  | 形式検証         |
                                                  +------------------+
```

前段が失敗した場合は、後段を評価しない。形式検証は、判定結果が両方指定の場合にのみ実行する。

#### Data Flow Diagram

```text
[commit-count 入力] --> [正規化] --> [検証] --> [commit-count 確定値 N]
                                       |
                                       v
                                  (失敗: エラー終了)

[before-sha / after-sha 入力] --> [判定] --> none     --> (イベント名の検証へ)
                                     |
                                     +------> override --> [形式検証] --> (イベント名の検証へ)
                                     |                         |
                                     v                         v
                                (片方のみ: エラー終了)   (不一致: エラー終了)
```

### 2.4 Non-Goals

> **Derivation**: All items below originate from REQUIREMENTS Section "Out of Scope".

本書に関わる Non-Goals は、`specifications-index.md` 2.4 を参照する。
特に、オーバーライド値に対する祖先関係の検証は行わない (REQ: Out of Scope #7)。

### 2.5 Behavioral Design Decisions

| ID       | Decision                                                                  | Rationale                                                     | Affected Rules     | Status           |
| -------- | ------------------------------------------------------------------------- | ------------------------------------------------------------- | ------------------ | ---------------- |
| DD-IN-01 | commit-count の検証は、イベントに関わらず常に最初に行う                   | 全イベントで同一の入力契約を保証するため                      | R-IN-002, R-IN-003 | Promoted → DR-05 |
| DD-IN-02 | 明示的に渡された空文字列の commit-count は、未指定と同じく既定値 1 にする | 空文字列が渡された場合も、既定値の契約を保つため              | R-IN-001           | Active           |
| DD-IN-03 | オーバーライドは両方指定か指定なしのみ許可し、片方のみの指定は拒否する    | 片方のみの指定は意図が不明で、黙って切り替えると誤るため      | R-IN-004, R-IN-005 | Promoted → DR-07 |
| DD-IN-04 | オーバーライド値は、完全長の小文字 16 進 OID だけを許可する               | リビジョン式や短縮形では、出力が固定 SHA という契約にならない | R-IN-006           | Promoted → DR-14 |

> **Note**: DD-IN-02 は REQUIREMENTS の記述ではなく、確定した外部設計に由来する。
> 正式な Decision Record へ昇格する場合は `/deckrd dr --add` を使う。

DD-IN-02 は REQ-F-001 を明確化する。要件本文は「指定しない場合」を扱い、本書は明示的な空文字列も同じ場合に含める。

**Status Values:**

- `Active` — Currently in effect within this specification
- `Promoted → DR-xx` — Elevated to formal Decision Record (see Section 2.6)

### 2.6 Related Decision Records

> **Reference**: This section lists formal DRs that affect this specification.
> DRs are maintained in `decision-records.md` and are authoritative.

| DR-ID | Title                                                      | Phase  | Impact on This Spec                                       |
| ----- | ---------------------------------------------------------- | ------ | --------------------------------------------------------- |
| DR-05 | commit-count の検証は常に先頭で行う (fail-first)           | req    | 評価順序の第 1 段を commit-count 検証に固定する           |
| DR-07 | 明示オーバーライド入力 before-sha / after-sha を継承する   | req    | 両方指定は採用し、片方のみは拒否する (R-IN-004, R-IN-005) |
| DR-11 | スコープとインターフェースの明確化                         | req    | 入力名と既定値の契約を定める                              |
| DR-14 | 入力形式・git 障害分類・checkout と出力の契約を厳格化する  | req    | commit-count の上限とオーバーライド値の形式を定める       |
| DR-17 | GITHUB_EVENT_NAME はオーバーライドの有無に関わらず検証する | review | 本書の判定の後に、イベント名を検証する                    |

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

- Input Type: commit-count、before-sha、after-sha の 3 つの文字列入力
- Assumptions:
  - commit-count は、未指定、空文字列、または任意の文字列として届く。
  - before-sha と after-sha は、未指定の場合に空文字列として届く。
  - 3 つの入力は、いずれも前後の空白を取り除かずに評価する。

### 3.2 Output Semantics

- Output Meaning: 後続の処理に渡す、確定済みの commit-count とオーバーライドの判定結果
- Possible Outcomes:
  - commit-count の確定値は、1 以上 1000 以下の正整数となる。
  - オーバーライドの判定結果は、`none` か `override` のいずれかとなる。
  - いずれかの検証に失敗した場合は、エラー終了となる。

入力検証は、出力を書き出さない。
検証に失敗した場合は、イベント名の検証、SHA 解決、出力の書き出しのいずれも行わない。

---

## 4. Decision Rules

Evaluation MUST follow this order:

| Rule ID  | Step | Condition                                                                          | Outcome                                                                  |
| -------- | ---: | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| R-IN-001 |    1 | commit-count が未指定、または明示的な空文字列                                      | commit-count を "1" として扱い、R-IN-002 へ進む                          |
| R-IN-002 |    2 | commit-count が ^[1-9][0-9]*$ に一致しない、5 桁以上である、または 1000 を超える   | エラー終了する。以降の規則は評価しない                                   |
| R-IN-003 |    3 | commit-count が R-IN-002 を通過した                                                | commit-count を確定し、オーバーライドの判定へ進む                        |
| R-IN-004 |    4 | before-sha と after-sha の一方のみが空でない                                       | エラー終了する                                                           |
| R-IN-005 |    5 | before-sha と after-sha がどちらも空                                               | 判定結果を `none` とし、イベント名の検証へ進む                           |
| R-IN-006 |    6 | before-sha と after-sha がどちらも空でなく、いずれかが ^[0-9a-f]{40}$ に一致しない | エラー終了する                                                           |
| R-IN-007 |    7 | before-sha と after-sha がどちらも空でなく、両方が ^[0-9a-f]{40}$ に一致する       | 判定結果を `override` とし、指定値を採用候補としてイベント名の検証へ進む |

No reordering is permitted.

- R-IN-002 の上限判定は、桁数の判定を数値の比較より先に行う。桁数の多い値を数値として比較すると、桁あふれで上限をすり抜け得るため。
- R-IN-004、R-IN-006 のエラーは、エラーが見つかった入力名を対象とする。
- R-IN-007 の後に行うイベント名の検証とコミット検査は、`specifications-resolution.md` が扱う。

**エラーの文言:**

| Rule ID  | 対象                                        | 問題                                   |
| -------- | ------------------------------------------- | -------------------------------------- |
| R-IN-002 | `commit-count`                              | 正整数でない、または上限 1000 を超える |
| R-IN-004 | 空の側の入力名 (`before-sha` / `after-sha`) | 片方のみが指定されている               |
| R-IN-006 | 形式に一致しない側の入力名                  | 完全長の小文字 16 進 OID ではない      |

エラーの形式は `specifications-index.md` 3.3 に従う。

<!-- impl-note: original "R-002、R-004、R-006 のエラーは、DD-05 の形式で stderr に出力し、非ゼロで終了する"
  エラー形式の定義は index 3.3 に一本化した。 -->

---

## 5. Edge Cases

| Input                                      | Classification            | REQ                  | Rationale                                                   |
| ------------------------------------------ | ------------------------- | -------------------- | ----------------------------------------------------------- |
| commit-count が未指定                      | 既定値 1 として受理       | REQ-F-001            | 既定値の契約による                                          |
| commit-count が明示的な空文字列            | 既定値 1 として受理       | REQ-F-001            | DD-IN-02 により、未指定と同じ扱いとする                     |
| commit-count が "1000"                     | 受理                      | REQ-F-002            | 上限の境界値であり、上限を超えない                          |
| commit-count が "1001"                     | エラー                    | REQ-F-002            | 上限 1000 を超える                                          |
| commit-count が "10000"                    | エラー                    | REQ-F-002            | 5 桁の最小値。桁数だけで上限超過とする                      |
| commit-count が 20 桁の数字列              | エラー                    | REQ-F-002            | 桁数だけで上限超過とし、数値としては比較しない              |
| commit-count が "0" または "-1"            | エラー                    | REQ-F-002            | 正整数ではない                                              |
| commit-count が "01" または "abc"          | エラー                    | REQ-F-002            | 先頭ゼロまたは非数値は許容形式ではない                      |
| commit-count が " 2" のように空白を含む    | エラー                    | REQ-F-002            | 前後の空白は取り除いて救済しない                            |
| commit-count が空白のみ                    | エラー                    | REQ-F-002            | 空文字列ではないため、未指定として扱わない                  |
| 不正な commit-count と不正なオーバーライド | commit-count のエラーのみ | REQ-F-003            | commit-count の検証が先に完了し、オーバーライドは評価しない |
| 不正な commit-count と任意のイベント       | エラー                    | REQ-F-002, REQ-F-003 | イベント種別に依存せず、同じ検証を適用する                  |
| before-sha と after-sha がどちらも空       | `none`                    | REQ-F-011            | オーバーライドは指定されていない                            |
| before-sha のみ有効値、after-sha が空      | エラー                    | REQ-F-015            | 片方のみの指定は拒否する                                    |
| before-sha が空、after-sha のみ有効値      | エラー                    | REQ-F-015            | 片方のみの指定は拒否する                                    |
| 片方のみの指定で、その値が不正な形式       | 片方のみ指定のエラー      | REQ-F-015            | 片方のみの判定を形式検証より先に行う                        |
| 両方が有効な完全長の小文字 OID             | `override`                | REQ-F-011            | 形式検証を通過し、指定値が採用候補となる                    |
| 両方が同一の有効 OID                       | `override`                | REQ-F-011            | 形式上の制約はなく、同一値も受理する                        |
| オーバーライド値が "HEAD~1" のリビジョン式 | エラー                    | REQ-F-016            | リビジョン式は固定 SHA の契約を満たさない                   |
| オーバーライド値が 7 桁の短縮 SHA          | エラー                    | REQ-F-016            | 完全長ではない                                              |
| オーバーライド値が大文字を含む 40 桁       | エラー                    | REQ-F-016            | 小文字 16 進のみを許可する                                  |
| オーバーライド値が空白のみ                 | 指定ありとして形式エラー  | REQ-F-015, REQ-F-016 | 空文字列ではないため、指定されたものとして扱う              |

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule              | Notes                                                       |
| -------------- | ---------------------- | ----------------------------------------------------------- |
| REQ-F-001      | R-IN-001, §5           | 明示的な空文字列も既定値 1 とする (DD-IN-02)                |
| REQ-F-002      | R-IN-002, §5           | 形式と上限 1000 を検証する                                  |
| REQ-F-003      | R-IN-001 から R-IN-003 | commit-count の検証完了前は、他の入力もイベントも評価しない |
| REQ-F-011      | R-IN-005, R-IN-007, §5 | コミット検査は `specifications-resolution.md`               |
| REQ-F-015      | R-IN-004, §5           | 片方のみの指定は、形式検証より先に拒否する                  |
| REQ-F-016      | R-IN-006, R-IN-007, §5 | 完全長の小文字 16 進 OID 以外は拒否する                     |
| その他の REQ   | —                      | Covered in: `specifications-index.md` §6 の対応表           |

---

## 7. Open Questions

> **Status**: COMPLETE

| # | Question                                                                 | Source | Impact |
| - | ------------------------------------------------------------------------ | ------ | ------ |
| — | None identified - all requirements in this file's scope are unambiguous. | —      | —      |

---

## 8. Change History

| Date       | Version | Description                                                                              |
| ---------- | ------- | ---------------------------------------------------------------------------------------- |
| 2026-10-25 | 1.0.0   | Initial specification                                                                    |
| 2026-10-25 | 1.1.0   | Apply requirements v1.2.0: R-IN-/DD-IN- IDs, error wording table, DR-17 evaluation order |
| 2026-10-25 | 1.1.1   | Follow requirements v2.0.0: drop annotated tag edge case and IFO reference               |
| 2026-10-25 | 1.1.2   | Follow requirements v2.1.0: digit-length upper bound check in R-IN-002                   |
