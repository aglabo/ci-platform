---
title: "Design Specification: _ca-resolve-sha (Index)"
based-on: requirements.md v2.0.0
status: Draft
version: 2.0.0
created: "2026-10-25"
---

> Part of split specification. See `specifications-index.md` for full scope.

## 1. Overview

### 1.1 Purpose

本書は、`_ca-resolve-sha` 仕様の分割ファイル群の入口とする。
モジュール全体の概要、分割ファイルの一覧、共有インターフェース、共有規約を定義する。

FR ごとの詳細な振る舞いは、各分割ファイルで定義する。本書では再掲しない。

### 1.2 Scope

本書は、`_ca-resolve-sha` の振る舞い規則と分類の意味のうち、複数の分割ファイルが共有する部分を定義する。
実装の詳細は対象外とする。

### 1.3 Split Files

| File                                                           | Covered REQ                                                                                                  | Summary                                                                              |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------ |
| [specifications-input.md](./specifications-input.md)           | REQ-F-001, REQ-F-002, REQ-F-003, REQ-F-011, REQ-F-015, REQ-F-016                                             | 入力の既定値・検証、オーバーライドの採用と拒否を定義する。                           |
| [specifications-resolution.md](./specifications-resolution.md) | REQ-F-004, REQ-F-005, REQ-F-006, REQ-F-007, REQ-F-008, REQ-F-009, REQ-F-013, REQ-F-014, REQ-F-018, REQ-F-019 | イベント名と partial clone の検査、イベント別の SHA 解決、履歴不足の扱いを定義する。 |
| [specifications-output.md](./specifications-output.md)         | REQ-F-010, REQ-F-012                                                                                         | resolution の対応付けと、出力の書き出しを定義する。                                  |

### 1.4 ID Conventions

| 種別     | 書式        | 定義する分割ファイル         |
| -------- | ----------- | ---------------------------- |
| 判定規則 | `R-IN-NNN`  | specifications-input.md      |
| 判定規則 | `R-RES-NNN` | specifications-resolution.md |
| 判定規則 | `R-OUT-NNN` | specifications-output.md     |
| 設計判断 | `DD-IDX-NN` | 本書                         |
| 設計判断 | `DD-IN-NN`  | specifications-input.md      |
| 設計判断 | `DD-RES-NN` | specifications-resolution.md |
| 設計判断 | `DD-OUT-NN` | specifications-output.md     |

ID は分割ファイルをまたいで一意とし、廃止した ID は再利用しない。

---

## 2. Design Principles

### 2.1 Classification Philosophy

本 Action は、二点比較の基準 SHA を返す SHA 解決器として振る舞う。イベント全体の変更網羅は保証しない (DR-13)。

解決結果には、経路を示す `resolution` を付ける。
`resolution` は解決経路を示すだけであり、比較範囲が呼び出し元の目的に適していることは示さない。
全件検査への切り替えなど、経路に応じた判断は呼び出し元が行う。

エラーは握りつぶさず、発生源で検出する。
空ツリーへのフォールバックは、原因が履歴終端または shallow 境界と確認できる場合に限る。

### 2.2 Design Assumptions

- 呼び出し元は、REQ-C-003 の条件で `actions/checkout` を実行済みとする。partial clone は使わない。
- 対象リポジトリは、作業ディレクトリにある checkout 済みリポジトリとする。
- リポジトリのオブジェクト形式は SHA-1 とする (DR-19)。
- イベント由来の SHA は、GitHub のコンテキストが与える完全長 SHA とする (DR-23)。
- replace refs、旧形式の graft ファイル、注釈付きタグの OID の入力は扱わない (DR-23)。
- `GITHUB_EVENT_NAME` は、GitHub Actions ランナーが常に設定する。
- git が作業ディレクトリを信頼している (`safe.directory` の制約を受けない) ものとする。
  信頼されない場合は HEAD を解決できず、HEAD 解決不能のエラーとなる。
- 呼び出し元の workflow / job は、`contents: read` 以外の権限を付与しない (REQ-C-002)。

前提が破れた場合の挙動は、本仕様で定義した範囲を除き保証しない。

### 2.3 External Design Summary

> **Source**: Derived from the external design dialogue (Phase E) and user-confirmed design direction (Phase D).

#### Feature Decomposition

| Unit                | Responsibility                                                   | REQ Coverage                       |
| ------------------- | ---------------------------------------------------------------- | ---------------------------------- |
| input-validation    | commit-count とオーバーライド入力を、git 操作より先に検証する    | REQ-F-001, 002, 003, 015, 016      |
| event-resolution    | イベント名と partial clone を検査し、経路を選んで SHA を解決する | REQ-F-004, 008, 009, 011, 018, 019 |
| commit-verification | 出力しようとする SHA がコミットとして存在することを確認する      | REQ-F-013                          |
| head-n-resolution   | HEAD を基準に、N 世代前の SHA または空ツリー SHA を求める        | REQ-F-005, 006, 007, 009, 014      |
| resolution-labeling | 経路を `resolution` の 4 値のいずれかに対応付ける                | REQ-F-012                          |
| output-emission     | すべての検証が成功した後に、結果を書き出す                       | REQ-F-010                          |

#### Unit Interaction Map

```text
+------------------+     +------------------+
| input-validation | --> | event-resolution |
+------------------+     +------------------+
                                 |
                  +--------------+--------------+
                  v                             v
        +---------------------+      +-------------------+
        | commit-verification |      | head-n-resolution |
        +---------------------+      +-------------------+
                  |                             |
                  +--------------+--------------+
                                 v
                      +---------------------+
                      | resolution-labeling |
                      +---------------------+
                                 |
                                 v
                        +-----------------+
                        | output-emission |
                        +-----------------+
```

いずれかのユニットでエラーが起きた場合は、後続のユニットを呼び出さずに終了する。

#### Data Flow Diagram

```text
[Inputs + Event env] --> [input-validation] --> [event-resolution] --> [resolution-labeling] --> [output-emission] --> [Outputs]
                               |                      |
                               v                      v
                         [::error:: exit]      [commit-verification / head-n-resolution]
```

### 2.4 Non-Goals

> **Derivation**: All items below originate from REQUIREMENTS Section "Out of Scope".

- merge-base 計算 ← REQ: Out of Scope #1
- `ca-get-changed-files` 側の置き換え (別タスク) ← REQ: Out of Scope #2
- ファイルフィルタリング (#136) ← REQ: Out of Scope #3
- イベント全体の変更網羅の保証 ← REQ: Out of Scope #4
- 共有ライブラリの既存関数のシグネチャおよび挙動の変更 ← REQ: Out of Scope #5
- SHA-256 オブジェクト形式のリポジトリ ← REQ: Out of Scope #6
- before-sha が after-sha の祖先であることの検証 ← REQ: Out of Scope #7
- 対象リポジトリのパス入力と、近似経路での `::notice::` 出力 ← REQ: Out of Scope #8
- replace refs、旧形式の graft ファイル、注釈付きタグの OID の入力 ← REQ: Out of Scope #9
- partial clone のリポジトリ (エラーとする) ← REQ: Out of Scope #10

### 2.5 Behavioral Design Decisions

| ID        | Decision                                              | Rationale                                                     | Affected Rules             | Status |
| --------- | ----------------------------------------------------- | ------------------------------------------------------------- | -------------------------- | ------ |
| DD-IDX-01 | エラー形式を 3.3 の形式に統一する                     | 既存の検証関数と形式をそろえ、REQ の Open Question を解消する | 全分割ファイルのエラー規則 | Active |
| DD-IDX-02 | 出力値は 1 行のみを許可し、改行を含む値はエラーとする | 出力ファイルへの値の注入を防ぐ                                | R-OUT-005                  | Active |

> **Note**: DD-IDX-01 と DD-IDX-02 は、REQUIREMENTS の記述ではなく、確定した外部設計に由来する。
> 正式な Decision Record へ昇格する場合は `/deckrd dr --add` を使う。

DD-IDX-01 は、後続の内部 Action (#136) も採用し得るため、昇格を検討する価値がある。

**Status Values:**

- `Active` — Currently in effect within this specification
- `Promoted → DR-xx` — Elevated to formal Decision Record (see Section 2.6)

### 2.6 Related Decision Records

> **Reference**: This section lists formal DRs that affect this specification.
> DRs are maintained in `decision-records.md` and are authoritative.

| DR-ID | Title                                                                | Phase  | Impact on This Spec                     |
| ----- | -------------------------------------------------------------------- | ------ | --------------------------------------- |
| DR-01 | SHA 解決ロジックを内部 Composite Action に切り出す                   | req    | モジュール全体の存在理由と分割の前提    |
| DR-02 | push の before が無効な場合は HEAD~N に fall back する               | req    | push のフォールバック経路               |
| DR-03 | 履歴不足時は空ツリー SHA を before-sha とする                        | req    | `empty-tree` の発生条件                 |
| DR-04 | pull_request は base.sha をそのまま使う                              | req    | pull_request 経路と基準の限界           |
| DR-05 | commit-count の検証は常に先頭で行う (fail-first)                     | req    | 全体の評価順序の第 1 段                 |
| DR-06 | その他イベントは HEAD~N / HEAD で解決する                            | req    | その他イベントの扱い                    |
| DR-07 | 明示オーバーライド入力 before-sha / after-sha を継承する             | req    | 共有インターフェースの入力              |
| DR-08 | 解決経路を resolution 出力で通知する                                 | req    | 共有インターフェースの出力              |
| DR-09 | フォールバックとその他イベントの基準は checkout 済み HEAD とする     | req    | HEAD を基準とする経路の共通前提         |
| DR-10 | 出力 SHA のコミット実在検証と git エラーの区別                       | req    | エラーとフォールバックの境界            |
| DR-11 | スコープとインターフェースの明確化                                   | req    | 権限の責務と環境変数契約                |
| DR-12 | checkout の fetch-depth はイベントごとに N+1 / base を含む深さとする | req    | checkout 契約                           |
| DR-13 | 本 Action は SHA 解決器とし、変更網羅は保証しない                    | req    | 分類の方針と Non-Goals                  |
| DR-14 | 入力形式・git 障害分類・checkout と出力の契約を厳格化する            | req    | 上限値、形式検証、出力の契約            |
| DR-17 | GITHUB_EVENT_NAME はオーバーライドの有無に関わらず検証する           | review | 全体の評価順序 (イベント名の検証の位置) |
| DR-18 | 書き出し中の I/O 失敗による部分出力は、呼び出し元の契約で扱う        | review | 失敗時の出力の意味                      |
| DR-19 | 前提と非保証を明記し、追加の入出力は設けない                         | review | 前提と Non-Goals                        |
| DR-23 | partial clone はエラーとし、対象外の環境を前提として扱う             | review | partial clone の拒否と前提              |

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

- Input Type: 呼び出し元が指定する 3 つの入力と、実行環境が提供するイベント情報
- Assumptions: 2.2 の前提を満たす。

**Action 入力:**

| Input          | 既定値 | 意味                                                           |
| -------------- | ------ | -------------------------------------------------------------- |
| `commit-count` | "1"    | HEAD から遡る世代数 N。許容範囲は 1 から 1000 の正整数とする。 |
| `before-sha`   | ""     | 明示オーバーライドの基準 SHA。after-sha と対で指定する。       |
| `after-sha`    | ""     | 明示オーバーライドの対象 SHA。before-sha と対で指定する。      |

検証規則は [specifications-input.md](./specifications-input.md) で定義する。

**環境変数契約:**

| Variable             | 由来                    | 備考                                                    |
| -------------------- | ----------------------- | ------------------------------------------------------- |
| `GITHUB_EVENT_NAME`  | イベント名              | 必須。検証規則は resolution 分割ファイルが定義する。    |
| `GITHUB_BEFORE_SHA`  | `github.event.before`   | push の通常解決で使う。                                 |
| `GITHUB_AFTER_SHA`   | `github.sha`            | push の通常解決で使う。本仕様では `github.sha` と呼ぶ。 |
| `GITHUB_BASE_SHA`    | `pull_request.base.sha` | pull_request で使う。                                   |
| `GITHUB_HEAD_SHA`    | `pull_request.head.sha` | pull_request で使う。                                   |
| `INPUT_COMMIT_COUNT` | 入力 `commit-count`     | 検証規則は input 分割ファイルが定義する。               |
| `INPUT_BEFORE_SHA`   | 入力 `before-sha`       | 同上                                                    |
| `INPUT_AFTER_SHA`    | 入力 `after-sha`        | 同上                                                    |

- 値は環境変数経由でのみ受け取る (REQ-C-001)。
- Composite Action は `INPUT_*` を自動設定しない。`action.yml` は、入力とイベントコンテキストの値を上表の環境変数へ明示的に対応付ける (REQ-C-006)。
  対応付けが欠けた入力は空として届き、既定値で解決されるため、静かに無視される。

<!-- impl-note: original "git 実行環境の契約 (GIT_NO_LAZY_FETCH=1 / GIT_NO_REPLACE_OBJECTS=1、ラッパー rs_git)"
  DR-20 / DR-21 の削除に伴い廃止した。partial clone はオブジェクト参照前に検出してエラーとする (DR-23)。 -->

### 3.2 Output Semantics

- Output Meaning: 二点比較の基準となる SHA と、その解決経路
- Possible Outcomes:
  - 成功: 3 つの出力がすべて設定され、終了コードは 0 となる。
  - 検証の失敗: 出力を 1 つも書き出さず、エラーを出して非ゼロで終了する。
  - 書き出し開始後の I/O 失敗: エラーを出して非ゼロで終了する。先に書いた出力が残り得る (DR-18)。

**Action 出力:**

| Output       | 意味                                                                        |
| ------------ | --------------------------------------------------------------------------- |
| `before-sha` | 比較の基準側の SHA。空ツリー SHA となる場合がある。                         |
| `after-sha`  | 比較の対象側の SHA。常にコミットとして存在する。                            |
| `resolution` | 解決経路。`override`、`event`、`fallback-head-n`、`empty-tree` のいずれか。 |

- 呼び出し元は、非ゼロ終了したステップの出力を利用してはならない (DR-14, DR-18)。
  `if: always()` などで失敗後に出力を参照すると、部分出力を受け取り得る。
- 本 Action の責務は、空ツリー SHA を基準として返すことまでとする。空ツリー SHA との差分の計算は、呼び出し元の責務とする。

### 3.3 Shared Conventions

**エラー形式 (DD-IDX-01):**

- エラーは `::error::<対象>: <問題> (got: '<値>')` の形式で、標準エラー出力へ 1 行で出す。
- 対象は、入力名・環境変数名・コンポーネント名のいずれかとする。
- 値が空の場合は、`::error::<対象>: value must not be empty` の形式とする。
- エラーを出した後は、非ゼロの終了コードで終了する。

各分割ファイルのエラー規則は、この形式に従う。分割ファイルでは形式を再定義しない。

### 3.4 External Dependencies

**呼び出し元の checkout 契約:**

checkout の深さと取得対象は REQ-C-003 に従う。本仕様での帰結は次のとおりとする。

- push とその他イベントで `fetch-depth` が N+1 未満の場合は、履歴不足として `empty-tree` を返す。
- pull_request で base または head が取得されていない場合は、エラーとする。
- partial clone (`filter` を指定した checkout) の場合は、エラーとする。
- push で checkout したコミットが `github.sha` と異なる場合、通常解決とフォールバックとで after が異なり得る。この差は許容する (DR-23)。

### 3.5 Function List

<!-- impl-note: public function list and test ID abbreviations
  テスト ID は T-RS-<略称>-NN とする。略称はレイヤサフィックスを除いたベース略称とする。

  | 略称 | 関数                                                                      | 所在                             | 担当分割ファイル    |
  | ---- | ------------------------------------------------------------------------- | -------------------------------- | ------------------- |
  | VPI  | validate_positive_int <value> <field> <max>                               | _libs/validation.lib.sh          | input               |
  | NCC  | normalize_commit_count <value>                                            | scripts/_libs/resolve-sha.lib.sh | input               |
  | VOV  | validate_override <before> <after>                                        | scripts/_libs/resolve-sha.lib.sh | input               |
  | IPC  | is_partial_clone                                                          | scripts/_libs/resolve-sha.lib.sh | resolution          |
  | IC   | is_commit <sha>                                                           | scripts/_libs/resolve-sha.lib.sh | resolution          |
  | VC   | verify_commit <sha> <field>                                               | scripts/_libs/resolve-sha.lib.sh | resolution          |
  | RHN  | resolve_head_n <n>                                                        | scripts/_libs/resolve-sha.lib.sh | resolution          |
  | RSH  | resolve_sha <event> <n> <ov_before> <ov_after> <ev_before> <ev_after> <base> <head> | scripts/_libs/resolve-sha.lib.sh | resolution |
  | WO   | write_output <key> <value>                                                | _libs/output.lib.sh              | output              |
  | EO   | emit_outputs <before> <after> <resolution>                                | scripts/_libs/resolve-sha.lib.sh | output              |
  | MAIN | main (scripts/resolve-sha.sh)                                             | scripts/resolve-sha.sh           | output (functional) |

  - 空ツリー SHA の定数は、モジュール専用ライブラリに置く。他モジュールが必要とした時点で共有ライブラリへ昇格する。
  - 共有ライブラリへの追加は、WO、VPI、validation.lib.sh のロードガードの 3 点のみとする (REQ-C-008)。
  - MAIN の functional テストは、レイヤサフィックス F を付けた MAINF となる。
  - 戻り値の規約: 内部の解決処理は "<before> <after> <resolution>" を空白区切りの 1 行で標準出力へ返す。
    呼び出し側は `if ! out=$(...); then exit 1; fi` で失敗を検知し、`read -r` で分解する。
  - 環境変数を読むのは MAIN のみとし、他の関数は引数だけを入力とする。
  - v1.1.0 の RG (rs_git)、IFO (is_full_oid) は廃止した。オーバーライドの形式判定は VOV の内部で行う。
-->

---

## 4. Decision Rules

個別の判定規則は、各分割ファイルで定義する。本書は、分割ファイルをまたぐ全体の評価順序だけを定める。

Evaluation MUST follow this order:

| Step | 実施する処理                           | 定義する分割ファイル                                           |
| ---: | -------------------------------------- | -------------------------------------------------------------- |
|    1 | commit-count の検証                    | [specifications-input.md](./specifications-input.md)           |
|    2 | オーバーライドの組み合わせと形式の検証 | [specifications-input.md](./specifications-input.md)           |
|    3 | イベント名の検証                       | [specifications-resolution.md](./specifications-resolution.md) |
|    4 | partial clone の検出                   | [specifications-resolution.md](./specifications-resolution.md) |
|    5 | 経路の選択、コミット検証、SHA の解決   | [specifications-resolution.md](./specifications-resolution.md) |
|    6 | resolution の対応付けと出力の書き出し  | [specifications-output.md](./specifications-output.md)         |

No reordering is permitted.

いずれかの段階が失敗した場合は、後続の段階を実行しない (DR-05, DR-17)。

---

## 5. Edge Cases

分割ファイルにまたがる境界条件だけを記す。FR 固有の境界条件は各分割ファイルで扱う。

| Input                                           | Classification                 | REQ                  | Rationale                                                  |
| ----------------------------------------------- | ------------------------------ | -------------------- | ---------------------------------------------------------- |
| 不正な commit-count と空の `GITHUB_EVENT_NAME`  | commit-count のエラーのみ      | REQ-F-003            | commit-count の検証が最初に完了する                        |
| 有効なオーバーライドと空の `GITHUB_EVENT_NAME`  | イベント名のエラー             | REQ-F-018            | イベント名はオーバーライドの有無に関わらず検証する (DR-17) |
| 有効なオーバーライドと partial clone            | partial clone のエラー         | REQ-F-019            | オーバーライドでもオブジェクトを参照するため               |
| いずれかの検証が失敗した                        | 出力なし・非ゼロ終了           | REQ-F-003, REQ-F-010 | 検証の失敗では書き出しを開始しない                         |
| 書き出しの途中で I/O 障害が起きた               | 非ゼロ終了。部分出力が残り得る | REQ-F-010            | 防げない失敗は呼び出し元の契約で扱う (DR-18)               |
| `action.yml` が入力の環境変数への対応付けを欠く | 入力は空として扱われる         | REQ-C-006            | 静かに既定値で解決されるため、`action.yml` の契約で防ぐ    |

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule                                  | Notes                                |
| -------------- | ------------------------------------------ | ------------------------------------ |
| REQ-F-001      | Covered in: `specifications-input.md`      |                                      |
| REQ-F-002      | Covered in: `specifications-input.md`      | エラー形式は 3.3 に従う              |
| REQ-F-003      | Covered in: `specifications-input.md`      | 全体の順序は §4 に従う               |
| REQ-F-004      | Covered in: `specifications-resolution.md` |                                      |
| REQ-F-005      | Covered in: `specifications-resolution.md` |                                      |
| REQ-F-006      | Covered in: `specifications-resolution.md` |                                      |
| REQ-F-007      | Covered in: `specifications-resolution.md` |                                      |
| REQ-F-008      | Covered in: `specifications-resolution.md` |                                      |
| REQ-F-009      | Covered in: `specifications-resolution.md` |                                      |
| REQ-F-010      | Covered in: `specifications-output.md`     | 失敗時の出力の意味は 3.2 に従う      |
| REQ-F-011      | Covered in: `specifications-input.md`      |                                      |
| REQ-F-012      | Covered in: `specifications-output.md`     |                                      |
| REQ-F-013      | Covered in: `specifications-resolution.md` |                                      |
| REQ-F-014      | Covered in: `specifications-resolution.md` |                                      |
| REQ-F-015      | Covered in: `specifications-input.md`      |                                      |
| REQ-F-016      | Covered in: `specifications-input.md`      |                                      |
| REQ-F-018      | Covered in: `specifications-resolution.md` | 評価順序は §4 に従う                 |
| REQ-F-019      | Covered in: `specifications-resolution.md` | 評価順序は §4 に従う                 |
| REQ-NF-001     | 3.5 (impl-note)                            | テスト ID の略称を定義する           |
| REQ-NF-002     | 2.2, 3.4                                   | ローカルの git 操作と partial clone  |
| REQ-C-001      | 3.1                                        | 値は環境変数経由でのみ受け取る       |
| REQ-C-002      | 2.2                                        | 権限の責務は呼び出し元が負う         |
| REQ-C-003      | 3.4                                        | checkout 契約の帰結を記す            |
| REQ-C-004      | —                                          | Action 名の規約。impl / tasks で扱う |
| REQ-C-005      | —                                          | 静的解析の通過。impl / tasks で扱う  |
| REQ-C-006      | 3.1, 3.2                                   | 入力・出力・環境変数の対応付け       |
| REQ-C-007      | —                                          | スクリプト規約。impl / tasks で扱う  |
| REQ-C-008      | 3.5 (impl-note)                            | 共有ライブラリは追加のみとする       |

---

## 7. Open Questions

> **Status**: COMPLETE

| # | Question                                            | Source | Impact |
| - | --------------------------------------------------- | ------ | ------ |
| - | None identified - all requirements are unambiguous. | -      | -      |

REQUIREMENTS の Open Question (エラーメッセージの形式) は、DD-IDX-01 で解消した。
個別の文言は、各分割ファイルのエラー規則が定める。

---

## 8. Change History

| Date       | Version | Description                                                                                        |
| ---------- | ------- | -------------------------------------------------------------------------------------------------- |
| 2026-10-25 | 1.0.0   | Initial specification                                                                              |
| 2026-10-25 | 1.1.0   | Apply requirements v1.2.0 and DR-15..DR-22: git environment contract, commit type check, ID scheme |
| 2026-10-25 | 2.0.0   | Apply requirements v2.0.0 and DR-23: remove git environment contract, add partial clone rejection  |
