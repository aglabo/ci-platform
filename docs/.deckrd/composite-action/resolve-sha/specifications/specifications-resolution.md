---
title: "Design Specification: _ca-resolve-sha (Resolution)"
based-on: requirements.md v1.2.0
status: Draft
version: 1.1.0
created: "2026-10-25"
---

> Part of split specification. See `specifications-index.md` for full scope.

## 1. Overview

### 1.1 Purpose

本書は、イベント名の検証、イベント種別ごとの SHA 解決、HEAD~N 解決、コミット検査、git 障害の分類について振る舞いの規則を定義する。
本書は REQ-F-004 から REQ-F-009、REQ-F-013、REQ-F-014、REQ-F-017、REQ-F-018 を対象 FR とする。
入力検証 (commit-count、オーバーライドの対と形式) と出力の書き出しは、別ファイルで扱う。

### 1.2 Scope

本書は、SHA 解決の振る舞い規則と分類の意味を定義する。実装の詳細は対象外とする。

本書の解決処理は、検証済みの入力を受け取り、3 値の組 (before、after、resolution) を返すか、エラーを返す。
解決処理自体は、出力を書き出さない。

---

## 2. Design Principles

### 2.1 Classification Philosophy

- 解決処理は、ローカルの git の状態だけを根拠に分類する。
- 「履歴の不足」と「異常」は区別する。
  - 履歴終端 (root コミット) または shallow 境界への到達は、履歴の不足として空ツリー SHA へフォールバックする。
  - それ以外の失敗は異常として、フォールバックせずエラーにする。
- 分類の根拠は終了コードの推測ではなく、第一親をたどった世代数の数え上げとする。
- 出力する SHA は、完全長の OID であり、かつ OID 自体が commit 型のオブジェクトとする (before 側の空ツリー SHA を除く)。
- push の before だけは、検査に失敗しても異常とせずフォールバックする。原因 (不在、破損、型の不一致) は区別しない (DR-20)。

### 2.2 Design Assumptions

- 入力検証は完了している (`specifications-input.md`)。
- git 操作は、`specifications-index.md` 3.1 の git 実行環境の契約に従う。
- checkout の前提は REQ-C-003 に従う。契約違反の場合の挙動も、本書で定義する。
- 解決処理は、作業ディレクトリを変更しない。

### 2.3 External Design Summary

> **Source**: Derived from the external design dialogue (Phase E) and user-confirmed design direction (Phase D).

#### Feature Decomposition

| Unit                | Responsibility                                                               | REQ Coverage                                                     |
| ------------------- | ---------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| event-resolution    | イベント名を検証し、オーバーライドとイベント値から経路を選び、3 値の組を返す | REQ-F-004, REQ-F-005, REQ-F-006, REQ-F-008, REQ-F-009, REQ-F-018 |
| head-n-resolution   | HEAD を基準に HEAD~N を解決し、履歴不足を空ツリー SHA に分類する             | REQ-F-005, REQ-F-006, REQ-F-007, REQ-F-009, REQ-F-014            |
| commit-verification | 出力しようとする SHA の形式と、commit 型のオブジェクトであることを確認する   | REQ-F-013, REQ-F-017                                             |

<!-- impl-note: event-resolution = resolve_sha (RSH)、head-n-resolution = resolve_head_n (RHN)、commit-verification = verify_commit (VC)。
  push の before の検査は、エラーを出さない is_commit (IC) で行う。形式判定は is_full_oid (IFO) を使う。
  RSH は引数だけを入力とし、環境変数を読まない。RSH と RHN は "<before> <after> <resolution>" を 1 行で標準出力へ返す。
  VC は成功で 0、失敗で 1 を返し、失敗時は <field> を対象とするエラーを出す。空ツリー SHA の定数はモジュール専用ライブラリに置く。 -->

#### Unit Interaction Map

```text
+------------------+     +---------------------+
| event-resolution | --> | commit-verification |
+------------------+     +---------------------+
        |
        v
+-------------------+
| head-n-resolution |
+-------------------+
```

event-resolution が、他の 2 つの単位を呼び出す。
head-n-resolution と commit-verification は、互いに呼び出さない。
いずれかの単位がエラーを返した場合は処理を打ち切り、以降の単位を実行しない。

#### Data Flow Diagram

```text
[Event name / SHAs / N] --> [event name check] --> [event-resolution] --> [Triple: before, after, resolution]
                                  |                      |
                                  v                      +--> [commit-verification]   (override / pull_request / push after)
                           (empty: error)                |
                                                         +--> [head-n-resolution]     (push fallback / other events)
                                                                     |
                                                                     v
                                                              [HEAD check] --> [HEAD~N check] --(fail)--> [first-parent count]
```

### 2.4 Non-Goals

> **Derivation**: All items below originate from REQUIREMENTS Section "Out of Scope".

本書に関わる Non-Goals は、`specifications-index.md` 2.4 を参照する。特に次の 3 点は本書の規則に関わる。

- merge-base の計算は行わない ← REQ: Out of Scope #1
- before が after の祖先であるかは検証しない ← REQ: Out of Scope #7
- 旧形式の graft ファイルによる履歴の変更は考慮しない ← REQ: Out of Scope #9

### 2.5 Behavioral Design Decisions

| ID        | Decision                                                                  | Rationale                                                      | Affected Rules           | Status           |
| --------- | ------------------------------------------------------------------------- | -------------------------------------------------------------- | ------------------------ | ---------------- |
| DD-RES-01 | push の before が無効な場合は、エラーにせず HEAD~N へフォールバックする   | force push と新規ブランチで旧 SHA が使えないため               | R-RES-003, R-RES-004     | Promoted → DR-02 |
| DD-RES-02 | HEAD~N を解決できない場合は、空ツリー SHA を before とする                | 履歴不足でもエラー終了を避けるため                             | R-RES-014                | Promoted → DR-03 |
| DD-RES-03 | pull_request の base と head は、そのまま採用し検査だけを行う             | merge-base 計算はスコープ外のため                              | R-RES-006                | Promoted → DR-04 |
| DD-RES-04 | その他イベントは HEAD~N / HEAD で解決する                                 | 全イベントで解決可能にして再利用性を保つため                   | R-RES-007                | Promoted → DR-06 |
| DD-RES-05 | フォールバックの基準は checkout 済みの HEAD とし、HEAD~N は第一親をたどる | before と after を同一履歴上にそろえるため                     | R-RES-011, R-RES-012     | Promoted → DR-09 |
| DD-RES-06 | 履歴不足か異常かは、HEAD~N の解決失敗後に第一親の世代数を数えて分類する   | 終了コードだけでは root / shallow 境界と欠損を区別できないため | R-RES-013 から R-RES-015 | Promoted → DR-14 |
| DD-RES-07 | 空ツリー SHA の検査免除は before 側に限る                                 | after が空ツリーなら、差分の終点が無いのと同じであるため       | R-RES-022                | Promoted → DR-14 |
| DD-RES-08 | イベント名の空・未設定は、オーバーライドの有無に関わらずエラーにする      | すべての実行で同じ環境の契約を保つため                         | R-RES-001                | Promoted → DR-17 |
| DD-RES-09 | 形式検証を、コミット検査より先に行う                                      | リビジョン式やブランチ名はコミット検査を通過し得るため         | R-RES-023                | Promoted → DR-15 |
| DD-RES-10 | コミット検査は、OID 自体の型が commit であることの確認とする              | 注釈付きタグは参照解除するとコミットへ解決できてしまうため     | R-RES-024                | Promoted → DR-21 |
| DD-RES-11 | push の before の検査失敗は、原因を問わずフォールバックする               | 不在と破損は同じ終了コードとなり区別できないため               | R-RES-004                | Promoted → DR-20 |

> **Note**: すべての DD は、Decision Record へ昇格済みとする。

**Status Values:**

- `Active` — Currently in effect within this specification
- `Promoted → DR-xx` — Elevated to formal Decision Record (see Section 2.6)

### 2.6 Related Decision Records

> **Reference**: This section lists formal DRs that affect this specification.
> DRs are maintained in `decision-records.md` and are authoritative.

| DR-ID | Title                                                                               | Phase  | Impact on This Spec                                    |
| ----- | ----------------------------------------------------------------------------------- | ------ | ------------------------------------------------------ |
| DR-02 | push の before が無効な場合は HEAD~N に fall back する                              | req    | R-RES-003、R-RES-004 の分岐                            |
| DR-03 | 履歴不足時は空ツリー SHA を before-sha とする                                       | req    | R-RES-014 の結果                                       |
| DR-04 | pull_request は base.sha をそのまま使う                                             | req    | R-RES-006 が merge-base を計算しないこと               |
| DR-06 | その他イベントは HEAD~N / HEAD で解決する                                           | req    | R-RES-007 でエラーにせず解決する                       |
| DR-09 | フォールバックとその他イベントの基準は checkout 済み HEAD とする                    | req    | R-RES-011、R-RES-012 の基準                            |
| DR-10 | 出力 SHA のコミット実在検証と git エラーの区別                                      | req    | 検査の失敗と履歴不足を別の結果にする                   |
| DR-12 | checkout の fetch-depth はイベントごとに N+1 / base を含む深さとする                | req    | 契約違反時の結果 (R-RES-014) と pull_request のエラー  |
| DR-13 | 本 Action は SHA 解決器とし、変更網羅は保証しない                                   | req    | 本書の規則が二点比較の基準に限られること               |
| DR-14 | 入力形式・git 障害分類・checkout と出力の契約を厳格化する                           | req    | R-RES-013 から R-RES-015 の分類と R-RES-022 の免除範囲 |
| DR-15 | イベント由来の SHA にも完全長 OID の形式検証を適用する                              | review | R-RES-003、R-RES-023                                   |
| DR-16 | push の通常解決は after に github.sha を使い続ける                                  | review | R-RES-005 の after                                     |
| DR-17 | GITHUB_EVENT_NAME はオーバーライドの有無に関わらず検証する                          | review | R-RES-001 の位置                                       |
| DR-19 | 前提と非保証を明記し、追加の入出力は設けない                                        | review | PR 系の他イベントをその他イベントとする                |
| DR-20 | push の before の検査障害は近似解決の例外とし、遅延取得を抑止する                   | review | R-RES-004 の例外、欠損コミットの扱い                   |
| DR-21 | コミット実在検証を OID 自体の型検査とし、replace refs を無効にする                  | req    | R-RES-024 と push の before の検査                     |
| DR-22 | 遅延取得抑止に未対応の git での partial clone は対象外とし、AC-017 を全経路に広げる | req    | partial clone での欠損コミットの扱い                   |

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

- Input Type: イベント名、イベントが提供する SHA 群、検証済みの commit-count (N)、オーバーライドの判定結果と値
- Assumptions:
  - 入力検証は完了している (2.2)。
  - イベントが提供する SHA は、空文字列を含む任意の文字列であり得る。
  - 未設定の値は、空文字列と同じに扱う。

### 3.2 Output Semantics

- Output Meaning: 二点比較の基準となる (before、after、resolution) の 3 値の組
  - before と after は完全長の OID とする。before は空ツリー SHA の場合がある。
  - resolution の値と経路の対応は、`specifications-output.md` 3.2.1 が定義する。
- Possible Outcomes:
  - 成功: 3 値の組を返す。
  - 失敗: エラーを出して非ゼロで終了する。3 値の組は返さない。

<!-- impl-note: original resolution 3.2 の「経路 → resolution」対応表
  output 3.2.1 と重複するため削除し、参照に置き換えた。 -->

### 3.3 Git Operations

解決処理が使う git 操作は、次の 3 種類に限る (REQ-NF-002)。

| 操作                         | 用途                                                   |
| ---------------------------- | ------------------------------------------------------ |
| リビジョンの解決             | HEAD と HEAD~N を、コミットとして完全長 OID へ解決する |
| オブジェクトの型の取得       | 指定 OID 自体の型を、参照解除せずに取得する            |
| 第一親をたどった世代数の取得 | HEAD から第一親をたどって到達できるコミットを数える    |

- いずれも `specifications-index.md` 3.1 の git 実行環境の契約の下で実行する。
- HEAD~N の「~N」は、第一親を N 世代たどることを指す。merge コミットでは、第二親以降をたどらない。
- 履歴の取得と GitHub API の呼び出しは行わない。

<!-- impl-note: original 3.3 の git コマンド行
  - リビジョンの解決: git rev-parse --verify -q "<rev>^{commit}"
  - オブジェクトの型の取得: git cat-file -t <oid> (終了コード 0 かつ出力 commit を成功とする)
  - 世代数の取得: git rev-list --first-parent --count HEAD
  すべて rs_git (RG) 経由で実行する。旧版の git cat-file -e <sha>^{commit} は注釈付きタグを受理するため廃止した。 -->

### 3.4 HEAD~N Resolution Algorithm

HEAD~N の解決は、次の手順を上から順に評価する。前の手順が結論を出した場合、後続の手順は実行しない。

| Step | 操作                                        | 結果                                                                 |
| ---: | ------------------------------------------- | -------------------------------------------------------------------- |
|    1 | HEAD をコミットとして解決する               | 成功なら、その値を after とし手順 2 へ進む。失敗なら git エラー      |
|    2 | HEAD~N をコミットとして解決する             | 成功なら、その値を before とし `fallback-head-n` で完了する          |
|    3 | 手順 2 の失敗時に、第一親の世代数を取得する | 失敗、または結果が数値でなければ git エラー。成功なら手順 4 へ進む   |
|    4 | 手順 3 の件数 C を N と比較する             | C が N 以下なら、空ツリー SHA を before とし `empty-tree` で完了する |
|    5 | C が N を超える場合                         | HEAD~N が解決できるはずなのに失敗したため、git エラー                |

- C は、HEAD から第一親をたどって到達できるコミットの総数とする。
- C が N 以下であれば、HEAD~N は履歴終端または shallow 境界の先にある。
- C が N を超えるのに HEAD~N を解決できない場合は、祖先オブジェクトの欠損等の異常とする。
- 手順 2 の失敗理由は、終了コードからは判定しない。
- git エラーの場合は、空ツリー SHA へフォールバックしない。

---

## 4. Decision Rules

### 4.1 Event Resolution

Evaluation MUST follow this order:

| Rule ID   | Step | Condition                                                                                        | Outcome                                                                       |
| --------- | ---: | ------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------- |
| R-RES-001 |    1 | `GITHUB_EVENT_NAME` が空または未設定                                                             | エラー終了する。オーバーライドの有無は問わない                                |
| R-RES-002 |    2 | オーバーライドの判定結果が `override`                                                            | before、after の順に 4.3 で検査し、成功なら (指定値, 指定値, override) を返す |
| R-RES-003 |    3 | イベントが push で、before が空、40 桁の 0、または ^[0-9a-f]{40}$ に一致しない                   | 4.2 の HEAD~N 解決を行う                                                      |
| R-RES-004 |    4 | イベントが push で、before が R-RES-003 に当たらず、commit 型として確認できない                  | 4.2 の HEAD~N 解決を行う                                                      |
| R-RES-005 |    5 | イベントが push で、before が commit 型として確認できる                                          | github.sha を 4.3 で検査し、成功なら (before, github.sha, event) を返す       |
| R-RES-006 |    6 | イベントが pull_request                                                                          | base、head の順に 4.3 で検査し、成功なら (base, head, event) を返す           |
| R-RES-007 |    7 | 上記以外のイベント (workflow_dispatch、pull_request_target、pull_request_review、merge_group 等) | 4.2 の HEAD~N 解決を行う                                                      |

No reordering is permitted.

- R-RES-002 が成立した場合、イベント種別は参照しない。
- R-RES-004 の確認では、エラーを出さない。確認の失敗は、原因 (不在、破損、commit 以外の型、遅延取得の抑止) を問わずフォールバックの条件とする (DR-20)。
- R-RES-004 で旧コミット側の障害を検出しないことは、保証の例外とする。HEAD 側の障害は 4.2 で検出する。
- R-RES-005 で github.sha の検査に失敗した場合は、HEAD~N へフォールバックせずエラーにする。R-RES-006 も同様とする。
- R-RES-005 の after は github.sha とし、checkout 済み HEAD とは限らない (DR-16)。

### 4.2 HEAD~N Resolution

Evaluation MUST follow this order:

| Rule ID   | Step | Condition                                                  | Outcome                                  |
| --------- | ---: | ---------------------------------------------------------- | ---------------------------------------- |
| R-RES-011 |    1 | HEAD がコミットとして解決できない                          | エラー終了する                           |
| R-RES-012 |    2 | 第一親を N 世代たどった祖先がコミットとして解決できる      | (その祖先, HEAD, fallback-head-n) を返す |
| R-RES-013 |    3 | 第一親をたどった世代数の取得に失敗、または結果が数値でない | エラー終了する                           |
| R-RES-014 |    4 | 世代数が N 以下                                            | (空ツリー SHA, HEAD, empty-tree) を返す  |
| R-RES-015 |    5 | 世代数が N を超える                                        | エラー終了する                           |

No reordering is permitted.

- R-RES-011 の対象には、git リポジトリでない場合、コミットが 1 件もない場合、git が作業ディレクトリを信頼しない場合を含む。
- R-RES-012 から R-RES-015 では、after に常に R-RES-011 で解決した HEAD の OID を使う。

### 4.3 Commit Verification

Evaluation MUST follow this order:

| Rule ID   | Step | Condition                                                  | Outcome                |
| --------- | ---: | ---------------------------------------------------------- | ---------------------- |
| R-RES-021 |    1 | 検査対象の値が空                                           | エラーで失敗する       |
| R-RES-022 |    2 | 検査対象が before 側で、値が空ツリー SHA に等しい          | 検査を免除して成功する |
| R-RES-023 |    3 | 値が ^[0-9a-f]{40}$ に一致しない                           | エラーで失敗する       |
| R-RES-024 |    4 | 値の OID 自体が、commit 型のオブジェクトとして確認できない | エラーで失敗する       |
| R-RES-025 |    5 | 上記のいずれにも当たらない                                 | 成功する               |

No reordering is permitted.

- R-RES-022 の免除は before 側に限る。after 側の空ツリー SHA は、型が tree のため R-RES-024 でエラーになる。
- R-RES-023 は、オーバーライド値では入力検証で通過済みのため成立しない。イベント由来の値に対して働く (REQ-F-017)。
- R-RES-024 の確認は、指定 OID を参照解除せずに型を取得し、終了コード 0 かつ型 commit の場合だけ成功とする。
  終了コードが 0 以外の場合は、値を問わず失敗とする。
- 注釈付きタグの OID は、参照先がコミットでも R-RES-024 で失敗する。lightweight tag の参照先として得た OID は commit 型のため成功する。
- 2 つの値を検査する規則 (R-RES-002、R-RES-006) は、先に失敗した側のエラーだけを出す。

**エラーの文言:**

| Rule ID   | 対象                                    | 問題                                      |
| --------- | --------------------------------------- | ----------------------------------------- |
| R-RES-001 | `GITHUB_EVENT_NAME`                     | 値が空 (空の形式を使う)                   |
| R-RES-011 | `HEAD`                                  | コミットとして解決できない                |
| R-RES-013 | `HEAD~N`                                | 世代数を取得できない                      |
| R-RES-015 | `HEAD~N`                                | 履歴があるのに解決できない                |
| R-RES-021 | 検査対象の名前 (入力名または環境変数名) | 値が空 (空の形式を使う)                   |
| R-RES-023 | 同上                                    | 完全長の小文字 16 進 OID ではない         |
| R-RES-024 | 同上                                    | commit 型のオブジェクトとして見つからない |

エラーの形式は `specifications-index.md` 3.3 に従う。

---

## 5. Edge Cases

| Input                                                                         | Classification                                 | REQ                   | Rationale                                                   |
| ----------------------------------------------------------------------------- | ---------------------------------------------- | --------------------- | ----------------------------------------------------------- |
| `GITHUB_EVENT_NAME` が空 (オーバーライドなし)                                 | エラー (R-RES-001)                             | REQ-F-018             | イベント種別が不明なまま、その他イベントとして扱わない      |
| `GITHUB_EVENT_NAME` が空 (オーバーライドあり)                                 | エラー (R-RES-001)                             | REQ-F-018             | オーバーライドの有無に関わらず検証する                      |
| `GITHUB_EVENT_NAME` が未設定                                                  | 空と同じ扱い。エラー (R-RES-001)               | REQ-F-018             | 未設定と空を区別しない                                      |
| push で before が 40 桁の 0 (新規ブランチ、タグの作成)                        | HEAD~N 解決 (R-RES-003)                        | REQ-F-005             | 旧 SHA が無い                                               |
| push で before が空文字列                                                     | HEAD~N 解決 (R-RES-003)                        | REQ-F-005             | 旧 SHA が無い                                               |
| push で before が "0" のように 40 桁でない 0 の列                             | HEAD~N 解決 (R-RES-003)                        | REQ-F-005             | 形式に一致しないため無効な before とする                    |
| push で before が "main"                                                      | HEAD~N 解決 (R-RES-003)                        | REQ-F-005             | 形式に一致しない before はエラーにしない                    |
| push で before がコミットとして存在しない                                     | HEAD~N 解決 (R-RES-004)                        | REQ-F-006             | force push で旧 SHA が失われている                          |
| push で before が shallow 範囲外                                              | HEAD~N 解決 (R-RES-004)                        | REQ-F-006             | 取得済みの履歴に存在しない                                  |
| push で before が注釈付きタグの OID                                           | HEAD~N 解決 (R-RES-004)                        | REQ-F-006, REQ-F-013  | commit 型ではないため、無効な before とする                 |
| push で before が空ツリー SHA                                                 | HEAD~N 解決 (R-RES-004)                        | REQ-F-006             | 型が tree のため commit 型として確認できない                |
| push で before のオブジェクトが破損している                                   | HEAD~N 解決 (R-RES-004)                        | REQ-F-006             | 保証の例外。不在と区別できない (DR-20)                      |
| push で before と github.sha が同一のコミット                                 | 通常解決 (R-RES-005)。resolution は event      | REQ-F-004             | 差分が空になるだけで、解決としては正常                      |
| push で before が存在し、github.sha が空                                      | エラー (R-RES-021)                             | REQ-F-013             | 通常解決の after は検査が必要。フォールバックはしない       |
| push で before が存在し、github.sha が "HEAD~1"                               | エラー (R-RES-023)                             | REQ-F-017             | 固定 SHA ではない                                           |
| push で before が存在し、github.sha が 40 桁の 0 (ref の削除等)               | エラー (R-RES-024)                             | REQ-F-013             | 全ゼロの OID は commit として存在しない                     |
| push で before が存在し、github.sha がコミットとして存在しない                | エラー (R-RES-024)                             | REQ-F-013             | 不在コミットを出力しない                                    |
| push で checkout したコミットが github.sha と異なる                           | 通常解決は github.sha、フォールバックは HEAD   | REQ-F-004             | 経路による after の違いは許容する (DR-16)                   |
| pull_request で base または head が空                                         | エラー (R-RES-021)                             | REQ-F-013             | 空のイベント値は異常                                        |
| pull_request で head が "main"、または base が 7 桁の短縮 SHA                 | エラー (R-RES-023)                             | REQ-F-017             | 固定 SHA ではない                                           |
| pull_request で base または head が不在                                       | エラー (R-RES-024)                             | REQ-F-013             | checkout の契約違反を発生源で検出する                       |
| pull_request で head が、タグを指す注釈付きタグの OID                         | エラー (R-RES-024)                             | REQ-F-013             | 型が tag のため commit ではない                             |
| pull_request で base が、replace ref でコミットに置換された注釈付きタグの OID | エラー (R-RES-024)                             | REQ-F-013             | replace refs を無効にするため、元の型 tag で判定する        |
| pull_request_target、pull_request_review、merge_group                         | その他イベント (R-RES-007)                     | REQ-F-009             | pull_request と同一視しない (DR-06, DR-19)                  |
| オーバーライドの after が空ツリー SHA                                         | エラー (R-RES-024)                             | REQ-F-013             | 免除は before 側に限る                                      |
| オーバーライドの before が空ツリー SHA                                        | 検査を免除 (R-RES-022)。resolution は override | REQ-F-013             | 免除は before 側の空ツリー SHA に適用する                   |
| オーバーライドの一方がコミットとして存在しない                                | エラー (R-RES-024)                             | REQ-F-013             | オーバーライド値にも検査を適用する                          |
| オーバーライドの after が注釈付きタグの OID                                   | エラー (R-RES-024)                             | REQ-F-013             | 型が tag のため commit ではない                             |
| オーバーライドの両方が lightweight tag の参照先 OID                           | 成功 (R-RES-025)。resolution は override       | REQ-F-013             | 参照先 OID は commit 型                                     |
| HEAD が merge コミット                                                        | HEAD~N は第一親をたどる (R-RES-012)            | REQ-F-009             | 第二親以降は基準にしない                                    |
| 履歴が初回コミットのみで N が 1 以上                                          | empty-tree (R-RES-014)                         | REQ-F-007             | 世代数 1 は N 以下                                          |
| 履歴が 2 コミットで N が 3                                                    | empty-tree (R-RES-014)                         | REQ-F-007             | 一部の不足も履歴不足として扱う                              |
| 履歴がちょうど N+1 コミット                                                   | fallback-head-n (R-RES-012)                    | REQ-F-009             | N 世代たどれるため履歴不足ではない                          |
| shallow clone の深さが N+1 以上                                               | fallback-head-n (R-RES-012)                    | REQ-F-009             | 必要な深さを満たしている                                    |
| shallow clone の深さが N                                                      | empty-tree (R-RES-014)                         | REQ-F-007             | 契約違反時の定義済み挙動。shallow 境界への到達として扱う    |
| replace ref で HEAD の親が置換されている                                      | 置換前の親で HEAD~N を解決する                 | REQ-NF-002            | replace refs を無効にする (DR-21)                           |
| コミットが 1 件もない空のリポジトリ                                           | エラー (R-RES-011)                             | REQ-F-014             | HEAD が解決できないため、履歴不足ではなく異常               |
| git リポジトリではない作業ディレクトリ                                        | エラー (R-RES-011)                             | REQ-F-014             | HEAD が解決できない                                         |
| git が作業ディレクトリを信頼しない (`safe.directory`)                         | エラー (R-RES-011)                             | REQ-F-014             | HEAD が解決できない。前提は index 2.2                       |
| HEAD~N の祖先オブジェクトが欠損している                                       | エラー (R-RES-013 または R-RES-015)            | REQ-F-014             | 履歴終端でも shallow 境界でもない失敗は、空ツリーで隠さない |
| partial clone で HEAD~N に至る祖先だけが欠損している                          | エラー (R-RES-015)。取得は起動しない           | REQ-F-014, REQ-NF-002 | 遅延取得を抑止し、shallow 境界と同一視しない                |
| partial clone で push の before だけが欠損している                            | HEAD~N 解決 (R-RES-004)。取得は起動しない      | REQ-F-006, REQ-NF-002 | 抑止による不在は、既存の規則で扱う                          |
| partial clone で pull_request の base、またはオーバーライド値が欠損           | エラー (R-RES-024)。取得は起動しない           | REQ-F-013, REQ-NF-002 | 抑止による不在は、既存の規則で扱う                          |
| 第一親の世代数の取得が失敗                                                    | エラー (R-RES-013)                             | REQ-F-014             | 原因を確認できない場合はフォールバックしない                |

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule                                                 | Notes                                                         |
| -------------- | --------------------------------------------------------- | ------------------------------------------------------------- |
| REQ-F-004      | R-RES-005                                                 | push の通常解決。after は github.sha                          |
| REQ-F-005      | R-RES-003, R-RES-011, R-RES-012                           | before が空・全ゼロ・形式不正の場合の HEAD~N 解決             |
| REQ-F-006      | R-RES-004, R-RES-011, R-RES-012                           | before の検査失敗の場合の HEAD~N 解決 (保証の例外を含む)      |
| REQ-F-007      | R-RES-012 から R-RES-015, §5                              | 履歴不足の分類。第一親の世代数で判定する                      |
| REQ-F-008      | R-RES-006                                                 | pull_request の base と head をそのまま採用し、検査だけを行う |
| REQ-F-009      | R-RES-007, R-RES-012                                      | その他イベント                                                |
| REQ-F-013      | R-RES-002, R-RES-005, R-RES-006, R-RES-021 から R-RES-025 | commit 型の検査と空ツリー SHA の免除範囲                      |
| REQ-F-014      | R-RES-011, R-RES-013, R-RES-015                           | HEAD 解決不能と git 障害のエラー                              |
| REQ-F-017      | R-RES-003, R-RES-023                                      | イベント由来の値の形式検証。push の before はフォールバック   |
| REQ-F-018      | R-RES-001                                                 | イベント名の必須検証                                          |
| REQ-NF-002     | 3.3, §5                                                   | 使用する git 操作と、遅延取得・replace refs の扱い            |
| その他の REQ   | —                                                         | Covered in: `specifications-index.md` §6 の対応表             |

---

## 7. Open Questions

> **Status**: COMPLETE

| # | Question                                                                 | Source | Impact |
| - | ------------------------------------------------------------------------ | ------ | ------ |
| — | None identified - all requirements in this file's scope are unambiguous. | —      | —      |

旧版の Open Questions は、次のとおり解消した。

- オーバーライド時のイベント名の検証は、DR-17 により常に行う (R-RES-001)。
- before に空ツリー SHA を指定したオーバーライドは、REQ-F-013 の免除範囲に従い許可する (R-RES-022)。

---

## 8. Change History

<!-- SemVer: see .claude/rules/deckrd-rule-document-versioning.md -->

| Date       | Version | Description                                                                                        |
| ---------- | ------- | -------------------------------------------------------------------------------------------------- |
| 2026-10-25 | 1.0.0   | Initial specification                                                                              |
| 2026-10-25 | 1.1.0   | Apply requirements v1.2.0: event name first, event SHA format check, commit type check, R-RES- IDs |
