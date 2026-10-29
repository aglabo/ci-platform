---
title: "Design Specification: ca-get-changed-files (Index)"
based-on: requirements.md v2.2.0
status: approved
version: 2.2.0
created: "2026-10-29"
---

> Part of split specification. See `specifications-index.md` for full scope.

## 1. Overview

### 1.1 Purpose

本書は、`ca-get-changed-files` 仕様の分割ファイル群の入口とする。
モジュール全体の概要、分割ファイルの一覧、共有規約、評価順序、検証 (CI ジョブ) と移行 (CHANGELOG) の規則を定義する。

FR ごとの詳細な振る舞いは、各分割ファイルで定義する。本書では再掲しない。

### 1.2 Scope

本書は、`ca-get-changed-files` の振る舞い規則のうち、複数の分割ファイルが共有する部分を定義する。
SHA の解決規則は `_ca-resolve-sha`、glob の照合規則は `_ca-filter-files` の仕様に従い、本仕様では再定義しない。
実装の詳細は対象外とする。

### 1.3 Split Files

| File                                                   | Covered REQ                                                      | Summary                                                                                         |
| ------------------------------------------------------ | ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| [specifications-action.md](./specifications-action.md) | REQ-F-001, REQ-F-002, REQ-F-004, REQ-F-005, REQ-F-007, REQ-C-003 | `action.yml` の入出力、3 つの step の連鎖、env の対応付け、内部スクリプトの実行方法を定義する。 |
| [specifications-diff.md](./specifications-diff.md)     | REQ-F-003, REQ-F-006, REQ-F-008                                  | `get-changed-files.sh` による差分の取得、バイト数の上限、エラー、旧ライブラリの削除を定義する。 |

本書は、REQ-NF-001、REQ-NF-002、REQ-C-003、REQ-C-007、REQ-C-008、REQ-C-009 を扱う。

### 1.4 ID Conventions

| 種別     | 書式        | 定義する分割ファイル     |
| -------- | ----------- | ------------------------ |
| 判定規則 | `R-IDX-NNN` | 本書                     |
| 判定規則 | `R-ACT-NNN` | specifications-action.md |
| 判定規則 | `R-DIF-NNN` | specifications-diff.md   |
| 設計判断 | `DD-IDX-NN` | 本書                     |
| 設計判断 | `DD-ACT-NN` | specifications-action.md |
| 設計判断 | `DD-DIF-NN` | specifications-diff.md   |

ID は分割ファイルをまたいで一意とし、廃止した ID は再利用しない。

---

## 2. Design Principles

### 2.1 Classification Philosophy

本 Action は、3 つのプロセスを順に実行するだけの組み立て役とする (DR-01, DR-02)。

1. `_ca-resolve-sha` のスクリプトで差分範囲の SHA を解決する
2. 本 Action のスクリプトで、その範囲の変更ファイルを `git diff` で取得する
3. `_ca-filter-files` のスクリプトで絞り込み、`files` / `count` を出力する

本 Action が自前で持つ判定は、2 の変更ファイルの取得 (specifications-diff.md) だけとする。
1 と 3 の入力検証・解決・照合・出力の規則は、各内部 Action の仕様に従う。本 Action では再実装しない (REQ-F-008)。

一致 0 件・変更なしは正常な結果とする。非ゼロで終了するのは、いずれかの段が失敗した場合に限る (REQ-F-006)。

### 2.2 Design Assumptions

- 呼び出し元は、`actions/checkout` を `fetch-depth: 0` で実行している (REQ-C-003)。partial clone は使わない。
- push で使う場合、呼び出し元はブランチ削除とタグの push を除外している (REQ-C-003)。
- 呼び出し元は、対象リポジトリを作業ディレクトリ (`$GITHUB_WORKSPACE`) に checkout している。
  `actions/checkout` の `path` は使わない (REQ-C-003, DR-10)。`_ca-resolve-sha` と `git diff` は `$PWD` で実行される。
- `uses:` で参照された本 Action のリポジトリは、同じ ref で全体が取得され、`${GITHUB_ACTION_PATH}/..` に内部 Action が並ぶ (DR-05)。
- `${GITHUB_ACTION_PATH}` は、ローカル参照 (`uses: ./...`) でも外部参照でも、本 Action のディレクトリを指す。
- 実行環境は GitHub Actions の ubuntu runner の Bash とする。
- 本 Action は、`contents: read` 以外の権限を必要としない (REQ-C-002)。
- 入力 `pattern` は、環境変数 1 つ分の上限 (約 131072 バイト) を超えない (DR-11)。超えた場合は絞り込みの段が起動できず、`::error::` が出ないまま失敗する。
- 変更ファイルのパスは UTF-8 として正しい (DR-11)。ランナーは step 出力を文字列として読むため、不正なバイト列は置き換えられ、後段で検出できないことがある。
- requirements の Assumptions (第一親のツリー差分、フォールバック時の範囲、内部スクリプトの位置と env 名の契約、リネームとコピー、サブモジュール) を満たす。本書では再掲しない。
- `git diff` の `core.quotePath` 以外の設定 (`diff.renames`・`diff.ignoreSubmodules` など) は、リポジトリの設定に従う。
  サブモジュールの更新を `files` に含める前提 (requirements の Assumptions) は、既定の設定のもとで成り立つ。

前提が破れた場合の挙動は、本仕様で定義した範囲を除き保証しない。

### 2.3 External Design Summary

> **Source**: Derived from the external design dialogue (Phase 5) and user-confirmed design direction (Phase 4).

#### Feature Decomposition

| Unit          | Responsibility                                                      | Owner                            | REQ Coverage                          |
| ------------- | ------------------------------------------------------------------- | -------------------------------- | ------------------------------------- |
| action-wiring | 入力を受け、3 つのスクリプトを順に実行し、出力を公開する            | 本 Action (action.yml)           | REQ-F-001, F-002, F-004, F-005, F-007 |
| resolve-sha   | `commit-count` とイベントから before / after の SHA を解決する      | `_ca-resolve-sha`                | REQ-F-001, REQ-F-002                  |
| list-changes  | before / after の間の変更ファイルを取得し、step 出力 `files` に書く | 本 Action (get-changed-files.sh) | REQ-F-003, REQ-F-006                  |
| filter-files  | 変更ファイルを `pattern` で絞り込み、`files` / `count` を書く       | `_ca-filter-files`               | REQ-F-004, REQ-F-005                  |

#### Unit Interaction Map

```text
[commit-count, event env]                [pattern]
          |                                  |
          v                                  v
+-----------------+  before_sha  +--------------------+  files  +-----------------+
|   resolve-sha   | -----------> |    list-changes    | ------> |  filter-files   | --> [files / count]
| (_ca-resolve-sha)|  after_sha  | (get-changed-files)|         | (_ca-filter-files)|
+-----------------+              +--------------------+         +-----------------+
          |                                  |                           |
          v                                  v                           v
   [::error:: exit]                   [::error:: exit]            [::error:: exit]
```

いずれかの段が非ゼロで終了した場合、後続の段は実行されない。

### 2.4 Non-Goals

> **Derivation**: All items below originate from REQUIREMENTS Section "Out of Scope".

- SHA 解決の規則そのもの ← REQ: Out of Scope #1
- glob の照合規則そのもの ← REQ: Out of Scope #2
- 内部 Action と `_libs/` の変更 ← REQ: Out of Scope #3
- 出力の追加 (`resolution` を含む) ← REQ: Out of Scope #4
- `fetch-depth: 0` 要件の緩和 ← REQ: Out of Scope #5
- 3000 件または 120000 バイトを超える差分の取得 ← REQ: Out of Scope #6
- `--diff-filter` の変更 ← REQ: Out of Scope #7

### 2.5 Behavioral Design Decisions

| ID        | Decision                                                                                                  | Rationale                                                                                       | Affected Rules         | Status           |
| --------- | --------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- | ---------------------- | ---------------- |
| DD-IDX-01 | エラー形式は内部 Action と同じ 3.3 の形式とする                                                           | 内部スクリプトのエラーをそのまま出すため、本 Action のエラーも同じ形式にそろえる                | 全分割ファイルのエラー | Active           |
| DD-IDX-02 | 内部スクリプトのエラーは書き換えずに出す。対象名は内部の名前 (`commit-count`・`patterns`・`files`) のまま | 書き換えるには出力を捕まえて変換する仕組みが要り、構成が複雑になる (REQ-F-006)                  | 3.3                    | Promoted → DR-14 |
| DD-IDX-03 | テスト ID は `T-GCF-<略語>-NN` とし、旧テスト (`T-gcf-*`・`T-rsv-*`・`T-rsl-*`・`T-wrt-*`) は削除する     | 旧テストは削除する関数とスタブの git を前提にしており、新しい構成では意味を持たない (REQ-C-009) | 3.5, R-DIF-030         | Active           |
| DD-IDX-04 | CHANGELOG の記載は、次のマイナーリリースの release PR で行う。#134 の PR 本文に記載内容を示す             | 本プロジェクトの CHANGELOG はリリース単位で書き、`Unreleased` 節を持たない                      | R-IDX-020〜R-IDX-022   | Active           |

> **Note**: DD-IDX-01〜DD-IDX-04 は、確定した外部設計に由来する。DD-IDX-02 は DR-14 に昇格した。
> 正式な Decision Record へ昇格する場合は `/deckrd dr --add` を使う。

**Status Values:**

- `Active` — Currently in effect within this specification
- `Promoted → DR-xx` — Elevated to formal Decision Record (see Section 2.6)

### 2.6 Related Decision Records

> **Reference**: This section lists formal DRs that affect this specification.
> DRs are maintained in `decision-records.md` and are authoritative.

| DR-ID | Title                                                                                      | Phase         | Impact on This Spec           |
| ----- | ------------------------------------------------------------------------------------------ | ------------- | ----------------------------- |
| DR-01 | 差分範囲の SHA 解決を `_ca-resolve-sha` に任せる                                           | req           | SHA の解決の段                |
| DR-02 | 変更ファイルの絞り込みを `_ca-filter-files` に任せる                                       | req           | 絞り込みの段、出力            |
| DR-03 | 入力 `before-sha` / `after-sha` を削除し、`commit-count` に置き換える                      | req           | 入力、オーバーライドの空指定  |
| DR-04 | 入力名 `pattern` を維持し、意味だけを glob に変える                                        | req           | 入力                          |
| DR-05 | 内部 Action は `uses:` ではなく、`${GITHUB_ACTION_PATH}/..` のスクリプトを直接実行して使う | req           | 内部スクリプトの実行方法      |
| DR-06 | `git diff` は `core.quotePath=false` で実行する                                            | req           | 差分の取得                    |
| DR-07 | `pattern` の有無に関わらず常に `_ca-filter-files` を通し、上限超過はエラーとする           | req           | 絞り込みの段、上限            |
| DR-08 | 出力は `files` / `count` だけとし、`resolution` は公開しない                               | req           | 出力                          |
| DR-09 | 旧ライブラリ `filter.lib.sh` はファイルごと削除する                                        | req (harden)  | R-DIF-030, R-DIF-031          |
| DR-10 | 対象リポジトリを作業ディレクトリに checkout することを呼び出し元の義務とする               | req (harden)  | 2.2、R-ACT-003                |
| DR-11 | `pattern` のサイズと非 UTF-8 のパスは前提とし、検査しない                                  | req (harden)  | 2.2                           |
| DR-12 | 3 つの step で構成し、env の対応付けの一致を静的に検査する                                 | spec (harden) | 3.4、specifications-action.md |
| DR-13 | 変更ファイルの取得の段でも 120000 バイトの上限を検査する                                   | spec (harden) | 5、specifications-diff.md     |
| DR-14 | エラーは内部 Action と同じ形式・文言で出し、内部のエラーと git の出力は書き換えない        | spec (harden) | 3.3                           |

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

- Input Type: 呼び出し元が指定する 2 つの入力と、実行環境が提供するイベント値・出力先
- Assumptions: 2.2 の前提を満たす。

**Action 入力:**

| Input          | required | 既定値 | 意味                                                                              |
| -------------- | -------- | ------ | --------------------------------------------------------------------------------- |
| `commit-count` | false    | "1"    | HEAD~N の N。検証と解決は `_ca-resolve-sha` が行う                                |
| `pattern`      | false    | ""     | glob パターン。1 行 1 個。`!` で始まる行は除外。空なら全件 (空の定義は REQ-F-004) |

- `commit-count` が範囲に効くのは、`before` が使えない push とその他イベントだけとする。push の通常解決と pull_request の範囲は変えない。
- pull_request の範囲は base 先頭と head の二点比較であり、PR が持ち込んだ変更と一致するとは限らない (`_ca-resolve-sha` DR-04, DR-13)。

入力から環境変数への対応付けは specifications-action.md で定義する。

### 3.2 Output Semantics

- Output Meaning: 差分範囲で追加・コピー・変更・リネームされ、`pattern` で保持されたファイルのパスと件数
- Possible Outcomes:
  - 成功: `files` と `count` が設定され、終了コードは 0 となる。変更なし・一致 0 件でも成功とする。
  - いずれかの段の検証の失敗: その段がエラーを 1 件出し、Action は非ゼロで終了する。`files` / `count` は設定されない。
  - 書き出し開始後の書き込み失敗: Action は非ゼロで終了する。`files` だけが設定された状態が残り得る (`_ca-filter-files` DR-09)。

**Action 出力:**

| Output  | 意味                                                                     |
| ------- | ------------------------------------------------------------------------ |
| `files` | 保持されたファイルパス。1 行 1 件、`git diff` の出力順。0 件なら空文字列 |
| `count` | 保持されたファイル数。先頭ゼロ・前後の空白を含まない 10 進整数文字列     |

- 呼び出し元は、本 Action が非ゼロで終了した場合の出力を利用してはならない (REQ-F-006)。

### 3.3 Shared Conventions

**エラー形式 (DD-IDX-01):**

- エラーは `::error::<対象>: <問題> (got: '<値>')` の形式で、標準エラー出力へ 1 行で出す。
- 対象は、入力名・環境変数名・出力名のいずれかとする。
- 値が空の場合は、`::error::<対象>: value must not be empty` の形式とする。
- エラーを出した後は、非ゼロの終了コードで終了する。
- `<値>` は、`%` を `%25`、CR を `%0D`、LF を `%0A` に置き換えて埋め込む。

この形式は、`_ca-resolve-sha` / `_ca-filter-files` の形式に合わせる。分割ファイルでは形式を再定義しない。

内部スクリプトのエラーは書き換えずに出す (DR-14)。このため、公開入力 `pattern` の不正は対象 `patterns`、変更ファイルの一覧の不正は対象 `files` として報告される。

### 3.4 Evaluation Order

評価は次の順で行う。

| Step | 処理                                                                                   | 定義                                                |
| ---: | -------------------------------------------------------------------------------------- | --------------------------------------------------- |
|    1 | `commit-count` とイベント値から before / after の SHA を解決する                       | `_ca-resolve-sha` の仕様、specifications-action.md  |
|    2 | before / after の間の変更ファイルを取得し、バイト数を検査して step 出力 `files` に書く | specifications-diff.md                              |
|    3 | 変更ファイルを `pattern` で絞り込み、`files`・`count` を書く                           | `_ca-filter-files` の仕様、specifications-action.md |
|    4 | Step 3 の `files`・`count` を Action の出力として公開する                              | specifications-action.md                            |

No reordering is permitted. 各 Step が非ゼロで終了した場合は、後続の Step を実行しない。

### 3.5 Function List

<!-- impl-note: public function list and test ID abbreviations
  関数の一覧 (テストの略語・シグネチャ・所在・担当分割ファイル) は、
  workspaces/module/module.md の「関数一覧」を正とし、本書では再掲しない。
  テスト ID は T-GCF-<略語>-NN とし、略語は綴り全体で 1 個とする (DD-IDX-03)。

  - LCF: list_changed_files (scripts/_libs/get-changed-files.lib.sh)
  - MAINF: main の functional テスト (scripts/get-changed-files.sh、実 git fixture)
  - RUNF: 3 つのスクリプトを action.yml と同じ順に実行する functional テスト (AC-014、配置のコピー)
  - GACT: action.yml と配下の静的検査 (R-ACT-040〜R-ACT-046、R-DIF-032、R-DIF-033)
  - 環境変数を読むのは main のみとし、list_changed_files は引数だけを入力とする。
  - 実 git fixture は _ca-resolve-sha の helpers/git-fixture.sh を読み取り専用で使う (所有範囲の外のため変更しない)。
-->

---

## 4. Decision Rules

**CI テストジョブ (`test-get-changed-files`、REQ-C-007):**

| Rule ID   | Step | Condition                                  | Outcome                                                                                                                                                                                                                                       |
| --------- | ---: | ------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| R-IDX-001 |    1 | ジョブの準備                               | checkout は `fetch-depth: 0`、`permissions` は `contents: read`、`uses: ./.github/actions/ca-get-changed-files` で参照する                                                                                                                    |
| R-IDX-002 |    2 | イベントが pull_request で、`pattern` が空 | `files` が `git -c core.quotePath=false diff --name-only --diff-filter=ACMR <base> <head>` の結果と一致し、`count` がその行数と一致することを確かめる                                                                                         |
| R-IDX-003 |    3 | イベントが push でも pull_request でもない | 一時コミット (`temp/ci-test-changed-files.txt` と `temp/ci-test-changed-files.md` を追加) を作り、HEAD~1..HEAD の範囲で次を確かめる                                                                                                           |
| R-IDX-004 |    3 | (R-IDX-003 の各ケース)                     | `pattern` 空 → `files` は 2 つのパスの 2 行、`count` は `2` (複数行の受け渡し)。`temp/**` → `files` は 2 行、`count` は `2`。`**/*.txt` → `files` は `temp/ci-test-changed-files.txt`、`count` は `1`。`*.yml` → `files` は空、`count` は `0` |
| R-IDX-005 |    4 | 失敗系                                     | `commit-count: "0"` を `continue-on-error: true` で実行し、step の outcome が `failure` であることを確かめる                                                                                                                                  |
| R-IDX-007 |    4 | 失敗系                                     | `pattern` を `!` だけの 1 行として `continue-on-error: true` で実行し、step の outcome が `failure` であることを確かめる (AC-018)                                                                                                             |
| R-IDX-006 |    5 | 後始末                                     | 一時コミットを `git reset --hard HEAD~1` で取り消す                                                                                                                                                                                           |

- Rule ID は追加の順に採番し、表は Step の順に並べる。このため R-IDX-007 は R-IDX-006 の前にある。
- 検証は `test-resolve-sha` ジョブの書き方 (イベントによる `if:`、`continue-on-error`、Verify ステップでの outcome と outputs の env 経由の検査) に合わせる。
- `before-sha` / `after-sha` を渡すステップと、git pathspec を前提とした `*.txt` のステップは削除する。
- summary ジョブは既に `test-get-changed-files` を含む。ジョブ名を変えない限り変更しない。
- `.github/workflows/*.yml` は保護領域のため、PR に変更理由を明記する。

**移行の記載 (REQ-C-008、DD-IDX-04):**

| Rule ID   | Step | Condition                         | Outcome                                                                                                                                            |
| --------- | ---: | --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| R-IDX-020 |    1 | #134 の PR を作るとき             | PR 本文に、R-IDX-022 の破壊的変更と移行方法を記載する                                                                                              |
| R-IDX-021 |    2 | 次のマイナーリリースの release PR | `CHANGELOG.md` の該当バージョンに、R-IDX-022 の項目を記載する                                                                                      |
| R-IDX-022 |    — | 記載する項目                      | REQ-C-008 の 5 項目 (SHA 入力の削除と代替なし、pathspec から glob、push の削除・タグとその他イベント、全ゼロ `before` の範囲、非 ASCII と特殊パス) |

---

## 5. Edge Cases

横断的なエッジケースのみを示す。個別のエッジケースは各分割ファイルで定義する。

| Input                                               | Classification                                                                   | REQ                  | Rationale                     |
| --------------------------------------------------- | -------------------------------------------------------------------------------- | -------------------- | ----------------------------- |
| `commit-count` が `0`                               | SHA の解決の段でエラー。後続は実行しない                                         | REQ-F-001, REQ-F-006 | 3.4、`_ca-resolve-sha`        |
| 変更なし (before と after が同じツリー)             | `files` は空、`count` は `0`、成功                                               | REQ-F-005            | specifications-diff.md        |
| 変更なしで `pattern` が `!` だけの行                | 絞り込みの段でエラー (対象 `patterns`)。パターンの検査は一覧の件数に関わらず行う | REQ-F-006            | `_ca-filter-files` の入力検査 |
| 除外されるパスの中に `"` を含むパスがある           | 絞り込みの段でエラー (対象 `files`)。検査は絞り込みの前に全件に対して行う        | REQ-F-006            | DR-06、DR-07                  |
| 3001 件・120000 バイト以下の差分                    | 絞り込みの段でエラー (対象 `files`)                                              | REQ-F-006            | `_ca-filter-files` の行数上限 |
| 120001 バイト以上の差分                             | 変更ファイルの取得の段でエラー (対象 `files`)                                    | REQ-F-006            | specifications-diff.md        |
| `pattern` に不正なパターン (`!` のみの行など)       | 絞り込みの段でエラー (対象 `patterns`)                                           | REQ-F-006            | DD-IDX-02                     |
| `pattern` が 101 行、または 120000 バイト超         | 絞り込みの段でエラー (対象 `patterns`)                                           | REQ-F-006            | `_ca-filter-files` REQ-F-018  |
| 呼び出し元のジョブ env に `INPUT_BEFORE_SHA` がある | オーバーライドは有効にならない                                                   | REQ-F-002            | specifications-action.md      |

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule                      | Notes                                     |
| -------------- | ------------------------------ | ----------------------------------------- |
| REQ-F-001      | —                              | Covered in: `specifications-action.md`    |
| REQ-F-002      | —                              | Covered in: `specifications-action.md`    |
| REQ-F-003      | —                              | Covered in: `specifications-diff.md`      |
| REQ-F-004      | —                              | Covered in: `specifications-action.md`    |
| REQ-F-005      | —                              | Covered in: `specifications-action.md`    |
| REQ-F-006      | 3.2, 3.3, 3.4                  | 段ごとの規則は各分割ファイル              |
| REQ-F-007      | —                              | Covered in: `specifications-action.md`    |
| REQ-F-008      | —                              | Covered in: `specifications-diff.md`      |
| REQ-NF-001     | 3.5, 6.1, R-IDX-001〜R-IDX-007 | LCF / MAINF / RUNF / GACT と CI ジョブ    |
| REQ-NF-002     | 3.2                            | 互換性の例外は requirements の REQ-NF-002 |
| REQ-C-003      | 2.2                            | description の検査は R-ACT-046            |
| REQ-C-007      | R-IDX-001〜R-IDX-007           |                                           |
| REQ-C-008      | R-IDX-020〜R-IDX-022           | DD-IDX-04                                 |
| REQ-C-009      | DD-IDX-03                      |                                           |

### 6.1 AC と検証手段

requirements の AC を確かめる手段を示す。略語は module.md の関数一覧に従う。

| AC                     | 検証手段                    | 備考                                 |
| ---------------------- | --------------------------- | ------------------------------------ |
| AC-001                 | RUNF (push の fixture)      |                                      |
| AC-002                 | CI ジョブ (R-IDX-002)       | pull_request の実イベント            |
| AC-003, AC-004         | RUNF、CI ジョブ (R-IDX-003) |                                      |
| AC-005                 | RUNF、CI ジョブ (R-IDX-005) |                                      |
| AC-006〜AC-008         | RUNF                        | 照合規則は `_ca-filter-files` が担う |
| AC-009, AC-010, AC-015 | MAINF                       | 実 git fixture                       |
| AC-011                 | RUNF                        | 引用表記の行は絞り込みの段でエラー   |
| AC-012                 | LCF (バイト数)、RUNF (行数) |                                      |
| AC-013                 | RUNF                        | 1 コミットの fixture                 |
| AC-014                 | RUNF                        | 配置のコピー                         |
| AC-016                 | GACT (R-DIF-032)            | 静的検査                             |
| AC-017                 | GACT (R-ACT-046)            | 静的検査                             |
| AC-018                 | RUNF、CI ジョブ (R-IDX-007) |                                      |

---

## 7. Open Questions

> **Status**: COMPLETE

requirements の Open Questions のうち、Owner が spec の項目は次のとおり解決した。

| Question                                  | Resolution                                                                                |
| ----------------------------------------- | ----------------------------------------------------------------------------------------- |
| AC-014 の検証方法                         | 配置をコピーした functional テスト (RUNF) で検証する。外部からの `uses:` での検証はしない |
| step の構成と段間の受け渡し               | 3 step。段間は step 出力で受け渡す (specifications-action.md)                             |
| 内部 action.yml との env の食い違いの検査 | GACT の静的検査で比較する (specifications-action.md)                                      |
| `test-get-changed-files` ジョブの改訂方法 | R-IDX-001〜R-IDX-007                                                                      |
| 既存テスト ID の扱い                      | 削除し、`T-GCF-*` で書き直す (DD-IDX-03)                                                  |

---

## 8. Change History

| Date       | Version | Description                                                                                                                                                                                                                                    |
| ---------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-10-29 | 1.0.0   | Initial release                                                                                                                                                                                                                                |
| 2026-10-29 | 1.0.1   | Apply spec second opinion: state pattern size and UTF-8 path assumptions (2.2), commit-count scope and PR range (3.1); refresh based-on (requirements v2.0.2)                                                                                  |
| 2026-10-29 | 1.0.2   | Refresh based-on (requirements v2.1.0): workspace checkout is a caller obligation (2.2, DR-10), add DR-09..DR-11                                                                                                                               |
| 2026-10-29 | 1.1.0   | Apply spec explore review: add R-IDX-007 (invalid pattern in CI), 6.1 AC-to-verification table, pattern limit edge case, assumptions (GITHUB_ACTION_PATH, requirements assumptions), unify stage terms; refresh based-on (requirements v2.1.2) |
| 2026-10-30 | 1.2.0   | Apply spec harden review: R-IDX-002 condition and count check, promote DD-IDX-02 to DR-14, add DR-12..DR-14                                                                                                                                    |
| 2026-10-30 | 1.2.1   | Apply spec fix review: unify stage terms, explicit R-IDX-004 outcomes, rule order note, move GITHUB_ACTION_PATH assumption, cite DR-14, GACT scope, R-IDX range, REQ-C-003 in split files                                                      |
| 2026-10-30 | 1.3.0   | Apply spec second opinion: R-IDX-003/004 use two files to exercise the multi-line handoff, git settings assumption, edge cases ("!" with no changes, quoted path among excluded files)                                                         |
| 2026-10-30 | 2.2.0   | Unify document versions to 2.2.0 and approve                                                                                                                                                                                                   |
