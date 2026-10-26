---
title: "Design Specification: _ca-resolve-sha (Resolution)"
based-on: requirements.md v2.1.1
status: Draft
version: 2.2.3
created: "2026-10-25"
---

> Part of split specification. See `specifications-index.md` for full scope.

## 1. Overview

### 1.1 Purpose

本書は、イベント名・push の ref 種別・partial clone の検査、イベント種別ごとの SHA 解決、HEAD~N 解決、コミット検証、git 障害の分類について振る舞いの規則を定義する。
本書は REQ-F-004 から REQ-F-009、REQ-F-013、REQ-F-014、REQ-F-018 から REQ-F-020 を対象 FR とする。
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
- push の before だけは、検証に失敗しても異常とせずフォールバックする。原因 (不在、破損) は区別しない。

### 2.2 Design Assumptions

- 入力検証は完了している (`specifications-input.md`)。
- 前提は `specifications-index.md` 2.2 に従う。partial clone は、本書の規則で検出してエラーとする。
- checkout の前提は REQ-C-003 に従う。契約違反の場合の挙動も、本書で定義する。
- 解決処理は、作業ディレクトリを変更しない。

### 2.3 External Design Summary

> **Source**: Derived from the external design dialogue (Phase E) and user-confirmed design direction (Phase D).

#### Feature Decomposition

| Unit                | Responsibility                                                                                 | REQ Coverage                                                                           |
| ------------------- | ---------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| event-resolution    | イベント名、push の ref 種別、partial clone を検査し、オーバーライドとイベント値から経路を選ぶ | REQ-F-004, REQ-F-005, REQ-F-006, REQ-F-008, REQ-F-009, REQ-F-018, REQ-F-019, REQ-F-020 |
| head-n-resolution   | HEAD を基準に HEAD~N を解決し、履歴不足を空ツリー SHA に分類する                               | REQ-F-005, REQ-F-006, REQ-F-007, REQ-F-009, REQ-F-014                                  |
| commit-verification | 出力しようとする SHA がコミットとして存在することを確認する                                    | REQ-F-013                                                                              |

<!-- impl-note: event-resolution = resolve_sha (RSH)、head-n-resolution = resolve_head_n (RHN)、commit-verification = verify_commit (VC)。
  partial clone の判定は is_partial_clone (IPC)、push の before の確認はエラーを出さない is_commit (IC) で行う。
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
[Event name / ref / SHAs / N] --> [event name check] --> [push ref check] --> [partial clone check] --> [event-resolution] --> [Triple]
                                         |                     |                    |                       |
                                         v                     v                    v                       +--> [commit-verification]
                                  (empty: error)    (tag / delete: error)   (partial: error)                |
                                                                                                            +--> [head-n-resolution]
```

### 2.4 Non-Goals

> **Derivation**: All items below originate from REQUIREMENTS Section "Out of Scope".

本書に関わる Non-Goals は、`specifications-index.md` 2.4 を参照する。特に次の 3 点は本書の規則に関わる。

- merge-base の計算は行わない ← REQ: Out of Scope #1
- before が after の祖先であるかは検証しない ← REQ: Out of Scope #7
- replace refs、旧形式の graft ファイル、注釈付きタグの OID の入力は扱わない ← REQ: Out of Scope #9

### 2.5 Behavioral Design Decisions

| ID        | Decision                                                                                  | Rationale                                                        | Affected Rules           | Status           |
| --------- | ----------------------------------------------------------------------------------------- | ---------------------------------------------------------------- | ------------------------ | ---------------- |
| DD-RES-01 | push の before が無効な場合は、エラーにせず HEAD~N へフォールバックする                   | force push と新規ブランチで旧 SHA が使えないため                 | R-RES-003, R-RES-004     | Promoted → DR-02 |
| DD-RES-02 | HEAD~N を解決できない場合は、空ツリー SHA を before とする                                | 履歴不足でもエラー終了を避けるため                               | R-RES-014                | Promoted → DR-03 |
| DD-RES-03 | pull_request の base と head は、そのまま採用し検証だけを行う                             | merge-base 計算はスコープ外のため                                | R-RES-006                | Promoted → DR-04 |
| DD-RES-04 | その他イベントは HEAD~N / HEAD で解決する                                                 | 全イベントで解決可能にして再利用性を保つため                     | R-RES-007                | Promoted → DR-06 |
| DD-RES-05 | フォールバックの基準は checkout 済みの HEAD とし、HEAD~N は第一親をたどる                 | before と after を同一履歴上にそろえるため                       | R-RES-011, R-RES-012     | Promoted → DR-09 |
| DD-RES-06 | 履歴不足か異常かは、HEAD~N の解決失敗後に第一親の世代数を数えて分類する                   | 終了コードだけでは root / shallow 境界と欠損を区別できないため   | R-RES-013 から R-RES-015 | Promoted → DR-14 |
| DD-RES-07 | 空ツリー SHA を before とするのは HEAD~N の履歴不足経路だけとし、検証値には免除を設けない | オーバーライドの契約を実在コミットのペアに統一するため           | R-RES-014, R-RES-024     | Promoted → DR-24 |
| DD-RES-08 | イベント名の空・未設定は、オーバーライドの有無に関わらずエラーにする                      | すべての実行で同じ環境の契約を保つため                           | R-RES-001                | Promoted → DR-17 |
| DD-RES-12 | partial clone は、オブジェクトを参照する前に設定から検出してエラーにする                  | 欠損オブジェクトの参照が遅延取得を起動し得るため                 | R-RES-008                | Promoted → DR-23 |
| DD-RES-13 | オーバーライドを指定しない push は、ブランチの作成・更新だけを解決する                    | 削除やタグの push で、意味を持たない基準を正常終了で返さないため | R-RES-009                | Promoted → DR-25 |

> **Note**: すべての DD は、Decision Record へ昇格済みとする。DD-RES-09 から DD-RES-11 は v2.0.0 で廃止した。

**Status Values:**

- `Active` — Currently in effect within this specification
- `Promoted → DR-xx` — Elevated to formal Decision Record (see Section 2.6)

### 2.6 Related Decision Records

> **Reference**: This section lists formal DRs that affect this specification.
> DRs are maintained in `decision-records.md` and are authoritative.

| DR-ID | Title                                                                | Phase  | Impact on This Spec                                   |
| ----- | -------------------------------------------------------------------- | ------ | ----------------------------------------------------- |
| DR-02 | push の before が無効な場合は HEAD~N に fall back する               | req    | R-RES-003、R-RES-004 の分岐                           |
| DR-03 | 履歴不足時は空ツリー SHA を before-sha とする                        | req    | R-RES-014 の結果                                      |
| DR-04 | pull_request は base.sha をそのまま使う                              | req    | R-RES-006 が merge-base を計算しないこと              |
| DR-06 | その他イベントは HEAD~N / HEAD で解決する                            | req    | R-RES-007 でエラーにせず解決する                      |
| DR-09 | フォールバックとその他イベントの基準は checkout 済み HEAD とする     | req    | R-RES-011、R-RES-012 の基準                           |
| DR-10 | 出力 SHA のコミット実在検証と git エラーの区別                       | req    | 検証の失敗と履歴不足を別の結果にする                  |
| DR-12 | checkout の fetch-depth はイベントごとに N+1 / base を含む深さとする | req    | 契約違反時の結果 (R-RES-014) と pull_request のエラー |
| DR-13 | 本 Action は SHA 解決器とし、変更網羅は保証しない                    | req    | 本書の規則が二点比較の基準に限られること              |
| DR-14 | 入力形式・git 障害分類・checkout と出力の契約を厳格化する            | req    | R-RES-013 から R-RES-015 の分類                       |
| DR-17 | GITHUB_EVENT_NAME はオーバーライドの有無に関わらず検証する           | review | R-RES-001 の位置                                      |
| DR-19 | 前提と非保証を明記し、追加の入出力は設けない                         | review | PR 系の他イベントをその他イベントとする               |
| DR-23 | partial clone はエラーとし、対象外の環境を前提として扱う             | review | R-RES-008、R-RES-005 の after の扱い                  |
| DR-24 | オーバーライド値に空ツリー SHA を受け付けない                        | review | 空ツリー SHA を R-RES-014 だけが生成すること          |
| DR-25 | push はブランチの作成・更新に限り、それ以外はエラーとする            | review | R-RES-009 の条件と適用範囲                            |

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

- Input Type: イベント名、ref と削除フラグ、イベントが提供する SHA 群、検証済みの commit-count (N)、オーバーライドの判定結果と値
- Assumptions:
  - 入力検証は完了している (2.2)。
  - イベントが提供する SHA は、空文字列を含む。
  - 未設定の値は、空文字列と同じに扱う。

### 3.2 Output Semantics

- Output Meaning: 二点比較の基準となる (before、after、resolution) の 3 値の組
  - before は、`empty-tree` 経路 (R-RES-014) でのみ空ツリー SHA となる。
  - resolution の値と経路の対応は、`specifications-output.md` 3.2.1 が定義する。
- Possible Outcomes:
  - 成功: 3 値の組を返す。
  - 失敗: エラーを出して非ゼロで終了する。3 値の組は返さない。

### 3.3 Git Operations

解決処理が使う git 操作は、次の 4 種類に限る (REQ-NF-002)。

| 操作                         | 用途                                                    |
| ---------------------------- | ------------------------------------------------------- |
| リポジトリの確認             | 作業ディレクトリを git リポジトリとして開けるか確認する |
| 設定の参照                   | partial clone であるかを判定する                        |
| リビジョンの解決             | HEAD と HEAD~N を、コミットとして完全長 OID へ解決する  |
| コミット存在の確認           | 指定 SHA がコミットとして存在するかを確認する           |
| 第一親をたどった世代数の取得 | HEAD から第一親をたどって到達できるコミットを数える     |

- HEAD~N の「~N」は、第一親を N 世代たどることを指す。merge コミットでは、第二親以降をたどらない。
- 履歴の取得と GitHub API の呼び出しは行わない。
- 設定の参照はオブジェクトを読まないため、partial clone でも遅延取得を起動しない。

<!-- impl-note: git コマンド
  - リポジトリの確認: git rev-parse --git-dir (終了コード 0 以外 = R-RES-026。safe.directory の拒否は 128)
  - 設定の参照: 次のいずれかに当たれば該当あり (R-RES-008)。値で判定し、キーの有無だけでは判定しない。
    - git config --local --get extensions.partialclone (リポジトリの設定だけを見る。git はグローバル等の値を無視する)
    - git config --type=bool --get-regexp '^remote\..*\.promisor$' の値に true がある
    - git config --get-regexp '^remote\..*\.partialclonefilter$' が該当する (promisor が無くても遅延取得を起動し得る)
    各呼び出しの終了コード 0 / 1 以外 (bool として不正な値等) は参照の失敗 (R-RES-010)。
    構文として壊れた .git/config は git rev-parse --git-dir も失敗させるため、R-RES-026 が先に当たる。
  - リビジョンの解決: git rev-parse --verify -q "<rev>^{commit}"
  - コミット存在の確認: git cat-file -e "<sha>^{commit}"
  - 世代数の取得: git rev-list --first-parent --count <head-oid>
  - HEAD は最初に 1 回だけ OID へ解決し (R-RES-011)、HEAD~N の解決と世代数の取得はその OID (<head-oid>~N) を起点にする。
    HEAD を再参照しないため、after・祖先・世代数が同じコミットを基準にそろう。
  WSL の git 2.39.5 で、clone --filter=blob:none は remote.origin.promisor=true を設定し、shallow / 通常 clone は一致しないことを確認済み。 -->

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
- C は第一親の系列だけで数える。merge 履歴では、第二親以降の系列の深さや shallow 境界は、C と分類に影響しない。
- 手順 2 の失敗理由は、終了コードからは判定しない。
- git エラーの場合は、空ツリー SHA へフォールバックしない。

---

## 4. Decision Rules

### 4.1 Event Resolution

Evaluation MUST follow this order:

| Rule ID   | Step | Condition                                                                                                            | Outcome                                                                       |
| --------- | ---: | -------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| R-RES-001 |    1 | `GITHUB_EVENT_NAME` が空または未設定                                                                                 | エラー終了する。オーバーライドの有無は問わない                                |
| R-RES-009 |    2 | オーバーライドの判定結果が `none` でイベントが push であり、ref が `refs/heads/` で始まらないか、削除フラグが `true` | エラー終了する                                                                |
| R-RES-026 |    3 | 作業ディレクトリを git リポジトリとして開けない (git リポジトリでない、git が作業ディレクトリを信頼しない等)         | エラー終了する。オブジェクトと設定は参照しない                                |
| R-RES-010 |    4 | partial clone を判定するための設定の参照に失敗した                                                                   | エラー終了する。partial clone ではないとして進まない                          |
| R-RES-008 |    5 | 作業ディレクトリのリポジトリが partial clone                                                                         | エラー終了する。オブジェクトは参照しない                                      |
| R-RES-002 |    6 | オーバーライドの判定結果が `override`                                                                                | before、after の順に 4.3 で検証し、成功なら (指定値, 指定値, override) を返す |
| R-RES-003 |    7 | イベントが push で、before が空または 40 桁の 0                                                                      | 4.2 の HEAD~N 解決を行う                                                      |
| R-RES-004 |    8 | イベントが push で、before がコミットとして存在しない                                                                | 4.2 の HEAD~N 解決を行う                                                      |
| R-RES-005 |    9 | イベントが push で、before がコミットとして存在する                                                                  | github.sha を 4.3 で検証し、成功なら (before, github.sha, event) を返す       |
| R-RES-006 |   10 | イベントが pull_request                                                                                              | base、head の順に 4.3 で検証し、成功なら (base, head, event) を返す           |
| R-RES-007 |   11 | 上記以外のイベント (workflow_dispatch、pull_request_target、pull_request_review、merge_group 等)                     | 4.2 の HEAD~N 解決を行う                                                      |

No reordering is permitted.

- R-RES-009 は、ブランチの作成・更新だけを許可する許可リストとする。タグの作成・移動・削除と、ブランチの削除が該当する。
- R-RES-009 の削除判定は、削除フラグだけで行う。削除時は ref がデフォルトブランチに戻るため、ref からは削除を判定できない。
- R-RES-009 は削除フラグを先に判定する。タグの削除のように両方の条件に当たる場合は、削除のエラーだけを出す。
- R-RES-009 は、オーバーライド指定時と push 以外のイベントには適用しない。ref がタグの workflow_dispatch 等は R-RES-007 で解決する。
- R-RES-003 から R-RES-005 は、R-RES-009 を通過した push にだけ適用される。
- R-RES-026 は、R-RES-010 と R-RES-008 の前に判定する。git が作業ディレクトリを信頼しない場合、設定の参照は該当なしとなり、
  コミット検証 (4.3) は実在するコミットを「見つからない」と誤って報告するため。
- R-RES-010 と R-RES-008 は、git の設定だけで判定する。設定の参照は「該当あり」「該当なし」「参照の失敗」の 3 つを区別する。
  - 該当ありは R-RES-008、参照の失敗 (bool として不正な値、読み取り権限の不足等) は R-RES-010 でエラーとする。
  - リポジトリの設定ファイルが構文として壊れている場合は、git がリポジトリを開けないため R-RES-026 で先にエラーとなる。
  - 該当なしの場合だけ、partial clone ではないとして次の規則へ進む。
- R-RES-002 が成立した場合、イベント種別は参照しない。
- R-RES-004 の確認では、エラーを出さない。確認の失敗は、原因 (不在、破損) を区別せずフォールバックの条件とする。
- R-RES-005 で github.sha の検証に失敗した場合は、HEAD~N へフォールバックせずエラーにする。R-RES-006 も同様とする。
- R-RES-005 の after は github.sha とし、checkout 済み HEAD とは限らない (DR-23)。

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

- R-RES-011 の対象には、コミットが 1 件もない場合を含む。git リポジトリでない場合と git が作業ディレクトリを信頼しない場合は、
  イベント解決では R-RES-026 で先にエラーとなる。
- R-RES-012 から R-RES-015 では、after に常に R-RES-011 で解決した HEAD の OID を使う。

### 4.3 Commit Verification

Evaluation MUST follow this order:

| Rule ID   | Step | Condition                    | Outcome          |
| --------- | ---: | ---------------------------- | ---------------- |
| R-RES-021 |    1 | 検証対象の値が空             | エラーで失敗する |
| R-RES-024 |    2 | 値がコミットとして存在しない | エラーで失敗する |
| R-RES-025 |    3 | 上記のいずれにも当たらない   | 成功する         |

No reordering is permitted.

- 空ツリー SHA は、before 側・after 側ともコミットではないため R-RES-024 でエラーになる。オーバーライドの before に指定した場合も同様とする (DR-24)。
- 空ツリー SHA を before とするのは R-RES-014 だけであり、その値は本検証を通さない。
- 2 つの値を検証する規則 (R-RES-002、R-RES-006) は、先に失敗した側のエラーだけを出す。
- R-RES-023 は v2.0.0 で廃止した (イベント値の形式検証、DR-23)。
- R-RES-022 は v2.1.0 で廃止した (before 側の空ツリー SHA の検証免除、DR-24)。

**エラーの文言:**

| Rule ID   | 対象                                    | 問題                         |
| --------- | --------------------------------------- | ---------------------------- |
| R-RES-001 | `GITHUB_EVENT_NAME`                     | 値が空 (空の形式を使う)      |
| R-RES-009 | `GITHUB_REF` (ref が空の場合)           | 値が空 (空の形式を使う)      |
| R-RES-009 | `GITHUB_REF` (ref がブランチでない場合) | ブランチの ref ではない      |
| R-RES-009 | `GITHUB_EVENT_DELETED` (削除の場合)     | ref の削除には対応しない     |
| R-RES-026 | `repository`                            | git リポジトリとして開けない |
| R-RES-010 | `repository`                            | 設定を参照できない           |
| R-RES-008 | `repository`                            | partial clone には対応しない |
| R-RES-011 | `HEAD`                                  | コミットとして解決できない   |
| R-RES-013 | `HEAD~N`                                | 世代数を取得できない         |
| R-RES-015 | `HEAD~N`                                | 履歴があるのに解決できない   |
| R-RES-021 | 検証対象の名前 (入力名または環境変数名) | 値が空 (空の形式を使う)      |
| R-RES-024 | 同上                                    | コミットとして見つからない   |

エラーの形式は `specifications-index.md` 3.3 に従う。

---

## 5. Edge Cases

| Input                                                             | Classification                                  | REQ       | Rationale                                                   |
| ----------------------------------------------------------------- | ----------------------------------------------- | --------- | ----------------------------------------------------------- |
| `GITHUB_EVENT_NAME` が空 (オーバーライドなし)                     | エラー (R-RES-001)                              | REQ-F-018 | イベント種別が不明なまま、その他イベントとして扱わない      |
| `GITHUB_EVENT_NAME` が空 (オーバーライドあり)                     | エラー (R-RES-001)                              | REQ-F-018 | オーバーライドの有無に関わらず検証する                      |
| `GITHUB_EVENT_NAME` が未設定                                      | 空と同じ扱い。エラー (R-RES-001)                | REQ-F-018 | 未設定と空を区別しない                                      |
| push でタグを作成・移動 (`refs/tags/*`、オーバーライドなし)       | エラー (R-RES-009)                              | REQ-F-020 | before / after がブランチ更新の前後を表さない               |
| push でタグを削除 (オーバーライドなし)                            | エラー (R-RES-009)                              | REQ-F-020 | 削除フラグが `true`                                         |
| push でブランチを削除 (オーバーライドなし)                        | エラー (R-RES-009)                              | REQ-F-020 | ref はデフォルトブランチに戻るが、削除フラグで検出する      |
| push で削除フラグが `false` または空、ref が `refs/heads/*`       | R-RES-009 を通過                                | REQ-F-020 | `true` 以外は削除とみなさない                               |
| push で ref が空 (オーバーライドなし、削除フラグが `true` 以外)   | エラー (R-RES-009、空の形式)                    | REQ-F-020 | 空の値は index 3.3 の空の形式で報告する                     |
| push で削除フラグが `true`、ref が空 (オーバーライドなし)         | エラー (R-RES-009、削除のエラーだけ)            | REQ-F-020 | 削除フラグを先に判定する                                    |
| push でタグの ref、オーバーライドあり                             | override (R-RES-002)                            | REQ-F-020 | R-RES-009 はオーバーライドに適用しない (DR-25)              |
| workflow_dispatch で ref がタグ                                   | その他イベント (R-RES-007)                      | REQ-F-009 | R-RES-009 は push にだけ適用する                            |
| partial clone (`--filter=blob:none` 等) のリポジトリ              | エラー (R-RES-008)。取得は起動しない            | REQ-F-019 | 設定だけで判定し、オブジェクトを参照しない                  |
| `extensions.partialClone` だけが設定されたリポジトリ              | エラー (R-RES-008)                              | REQ-F-019 | promisor remote が無くても partial clone として扱う         |
| `remote.<name>.partialclonefilter` だけが設定されたリポジトリ     | エラー (R-RES-008)                              | REQ-F-019 | promisor が無くても、その remote から遅延取得し得る         |
| `remote.<name>.promisor` が `false`                               | partial clone ではない (R-RES-008 に当たらない) | REQ-F-019 | git は promisor remote として扱わない                       |
| `extensions.partialClone` がグローバル等の設定だけにある          | partial clone ではない (R-RES-008 に当たらない) | REQ-F-019 | git はリポジトリ以外の設定のこの値を無視する                |
| `remote.<name>.promisor` が bool として不正な値                   | エラー (R-RES-010)                              | REQ-F-019 | 判定できないまま partial clone ではないとして進まない       |
| shallow clone のリポジトリ                                        | partial clone ではない (R-RES-008 に当たらない) | REQ-F-019 | shallow clone は promisor remote を持たない                 |
| リポジトリの設定ファイルが構文として壊れている                    | エラー (R-RES-026)                              | REQ-F-014 | git がリポジトリを開けない                                  |
| リポジトリを開けた後に設定を参照できない                          | エラー (R-RES-010)                              | REQ-F-019 | 判定できないまま partial clone ではないとして進まない       |
| 作業ディレクトリが git リポジトリでない                           | エラー (R-RES-026)                              | REQ-F-014 | 設定とコミットの判定が意味を持たない                        |
| git が作業ディレクトリを信頼しない (`safe.directory`)             | エラー (R-RES-026)                              | REQ-F-014 | 実在するコミットを「見つからない」と誤報告しない            |
| push で before が 40 桁の 0 (新規ブランチ)                        | HEAD~N 解決 (R-RES-003)                         | REQ-F-005 | 旧 SHA が無い                                               |
| push で before が空文字列                                         | HEAD~N 解決 (R-RES-003)                         | REQ-F-005 | 旧 SHA が無い                                               |
| push で before がコミットとして存在しない                         | HEAD~N 解決 (R-RES-004)                         | REQ-F-006 | force push で旧 SHA が失われている                          |
| push で before が shallow 範囲外                                  | HEAD~N 解決 (R-RES-004)                         | REQ-F-006 | 取得済みの履歴に存在しない                                  |
| push で before と github.sha が同一のコミット                     | 通常解決 (R-RES-005)。resolution は event       | REQ-F-004 | 差分が空になるだけで、解決としては正常                      |
| push で before が存在し、github.sha が空                          | エラー (R-RES-021)                              | REQ-F-013 | 通常解決の after は検証が必要。フォールバックはしない       |
| push で before が存在し、github.sha がコミットとして存在しない    | エラー (R-RES-024)                              | REQ-F-013 | 不在コミットを出力しない                                    |
| pull_request で base または head が空                             | エラー (R-RES-021)                              | REQ-F-013 | 空のイベント値は異常                                        |
| pull_request で base または head が不在                           | エラー (R-RES-024)                              | REQ-F-013 | checkout の契約違反を発生源で検出する                       |
| pull_request_target、pull_request_review、merge_group             | その他イベント (R-RES-007)                      | REQ-F-009 | pull_request と同一視しない (DR-06, DR-19)                  |
| オーバーライドの after が空ツリー SHA                             | エラー (R-RES-024)                              | REQ-F-013 | 空ツリー SHA はコミットではない                             |
| オーバーライドの before が空ツリー SHA                            | エラー (R-RES-024)                              | REQ-F-013 | オーバーライドは実在コミットのペアに限る (DR-24)            |
| オーバーライドの一方がコミットとして存在しない                    | エラー (R-RES-024)                              | REQ-F-013 | オーバーライド値にも検証を適用する                          |
| HEAD が merge コミット                                            | HEAD~N は第一親をたどる (R-RES-012)             | REQ-F-009 | 第二親以降は基準にしない                                    |
| 履歴が初回コミットのみで N が 1 以上                              | empty-tree (R-RES-014)                          | REQ-F-007 | 世代数 1 は N 以下                                          |
| 履歴が 2 コミットで N が 3                                        | empty-tree (R-RES-014)                          | REQ-F-007 | 一部の不足も履歴不足として扱う                              |
| 履歴がちょうど N+1 コミット                                       | fallback-head-n (R-RES-012)                     | REQ-F-009 | N 世代たどれるため履歴不足ではない                          |
| shallow clone の深さが N                                          | empty-tree (R-RES-014)                          | REQ-F-007 | 契約違反時の定義済み挙動。shallow 境界への到達として扱う    |
| HEAD が merge コミットで、第一親の系列が shallow 境界に達する     | empty-tree (R-RES-014)                          | REQ-F-007 | 第一親の系列の世代数が N 以下                               |
| HEAD が merge コミットで、第二親の系列だけが shallow 境界に達する | fallback-head-n (R-RES-012)                     | REQ-F-007 | 第二親の系列は HEAD~N の解決にも世代数にも関与しない        |
| コミットが 1 件もない空のリポジトリ                               | エラー (R-RES-011)                              | REQ-F-014 | HEAD が解決できないため、履歴不足ではなく異常               |
| git リポジトリではない作業ディレクトリ                            | エラー (R-RES-011)                              | REQ-F-014 | HEAD が解決できない                                         |
| HEAD~N の祖先オブジェクトが欠損している                           | エラー (R-RES-013 または R-RES-015)             | REQ-F-014 | 履歴終端でも shallow 境界でもない失敗は、空ツリーで隠さない |

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule                                                        | Notes                                                         |
| -------------- | ---------------------------------------------------------------- | ------------------------------------------------------------- |
| REQ-F-004      | R-RES-005                                                        | push の通常解決。after は github.sha                          |
| REQ-F-005      | R-RES-003, R-RES-011, R-RES-012                                  | before が空・全ゼロの場合の HEAD~N 解決                       |
| REQ-F-006      | R-RES-004, R-RES-011, R-RES-012                                  | before が存在しない場合の HEAD~N 解決                         |
| REQ-F-007      | R-RES-012 から R-RES-015, 3.4, §5                                | 履歴不足の分類。第一親の系列の世代数だけで判定する            |
| REQ-F-008      | R-RES-006                                                        | pull_request の base と head をそのまま採用し、検証だけを行う |
| REQ-F-009      | R-RES-007, R-RES-012                                             | その他イベント                                                |
| REQ-F-013      | R-RES-002, R-RES-005, R-RES-006, R-RES-021, R-RES-024, R-RES-025 | コミットの実在検証。空ツリー SHA は免除しない                 |
| REQ-F-014      | R-RES-011, R-RES-013, R-RES-015, R-RES-026                       | HEAD 解決不能と git 障害のエラー                              |
| REQ-F-018      | R-RES-001                                                        | イベント名の必須検証                                          |
| REQ-F-019      | R-RES-008, R-RES-010                                             | partial clone の拒否。判定不能も拒否する                      |
| REQ-F-020      | R-RES-009, §5                                                    | push の ref 種別の検証。オーバーライド指定時は適用しない      |
| REQ-NF-002     | 3.3                                                              | 使用する git 操作                                             |
| その他の REQ   | —                                                                | Covered in: `specifications-index.md` §6 の対応表             |

---

## 7. Open Questions

> **Status**: COMPLETE

| # | Question                                                                 | Source | Impact |
| - | ------------------------------------------------------------------------ | ------ | ------ |
| — | None identified - all requirements in this file's scope are unambiguous. | —      | —      |

---

## 8. Change History

<!-- SemVer: see .claude/rules/deckrd-rule-document-versioning.md -->

| Date       | Version | Description                                                                                                                                                     |
| ---------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-10-25 | 1.0.0   | Initial specification                                                                                                                                           |
| 2026-10-25 | 1.1.0   | Apply requirements v1.2.0: event name first, event SHA format check, commit type check, R-RES- IDs                                                              |
| 2026-10-25 | 2.0.0   | Apply requirements v2.0.0: remove format/type checks (R-RES-023), add partial clone rule R-RES-008                                                              |
| 2026-10-25 | 2.1.0   | Apply requirements v2.1.0: add R-RES-009 (push ref check), R-RES-010 (config read failure), retire R-RES-022 (empty tree exemption), first-parent shallow cases |
| 2026-10-26 | 2.2.0   | Add R-RES-026 (repository cannot be opened, incl. safe.directory) before R-RES-010                                                                              |
| 2026-10-26 | 2.2.1   | Detect partial clone by value (requirements v2.1.1): promisor true, partialclonefilter, local extensions.partialClone; add edge cases                           |
| 2026-10-26 | 2.2.2   | Clarify that a syntactically broken .git/config fails at R-RES-026, not R-RES-010                                                                               |
| 2026-10-26 | 2.2.3   | Empty GITHUB_REF on push uses the empty error form (R-RES-009); add edge cases                                                                                  |
