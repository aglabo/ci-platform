---
title: "Design Specification: ca-get-changed-files (Diff)"
based-on: requirements.md v2.2.0
status: approved
version: 2.2.1
created: "2026-10-29"
---

> Part of split specification. See `specifications-index.md` for full scope.

## 1. Overview

### 1.1 Purpose

本書は、`scripts/get-changed-files.sh` による変更ファイルの取得と、step 出力 `files` の書き出しの規則を定義する。
あわせて、旧ライブラリ `scripts/_libs/filter.lib.sh` の削除を定義する。

### 1.2 Scope

本書は、before / after の SHA を受け取ってから、step 出力 `files` を書き終えるまでの振る舞いを定義する。
SHA の解決は `_ca-resolve-sha`、絞り込みは `_ca-filter-files` の仕様に従う。

---

## 2. Design Principles

### 2.1 Classification Philosophy

本スクリプトは、`git diff` の結果を加工せずに次の段へ渡す。
パスの検査 (引用表記・CR・行数) は `_ca-filter-files` に任せ、本スクリプトでは行わない (DR-02)。
例外はバイト数の上限だけとする。環境変数 1 つ分の上限 (約 131072 バイト) を超えると、絞り込みの段が起動できず、`::error::` が出ないまま失敗する (DR-13)。

入力と出力先の検証は、出力を書く前にすべて終える。検証の失敗では何も書かない (REQ-F-006)。

### 2.2 Design Assumptions

- 2.2 of `specifications-index.md` の前提を満たす。
- `BEFORE_SHA` と `AFTER_SHA` は、`_ca-resolve-sha` が解決した値である。SHA の形式とコミットの実在は検証済みとし、本スクリプトでは検査しない。
- `BEFORE_SHA` は、空ツリー SHA (`4b825dc642cb6eb9a060e54bf8d69288fbee4904`) の場合がある。

### 2.3 External Design Summary

#### Feature Decomposition

| Unit           | Responsibility                                               | REQ Coverage         |
| -------------- | ------------------------------------------------------------ | -------------------- |
| list-changes   | `git diff` で変更ファイルを取得し、バイト数を検査する        | REQ-F-003, REQ-F-006 |
| entry          | 環境変数を読んで検証し、list-changes の一覧を `files` に書く | REQ-F-003, REQ-F-006 |
| legacy-removal | 旧ライブラリ `filter.lib.sh` とそのテストを削除する          | REQ-F-008            |

#### Unit Interaction Map

```text
[BEFORE_SHA / AFTER_SHA / GITHUB_OUTPUT]
                 |
                 v
          +-------------+   (before, after)   +--------------------+
          |    entry    | ------------------> |    list-changes    |
          +-------------+ <------------------ +--------------------+
                 |          (LF 区切りの一覧)            |
                 v                                       v
          [step 出力 files]                   [git -c core.quotePath=false diff]
```

### 2.4 Non-Goals

> **Derivation**: All items below originate from REQUIREMENTS Section "Out of Scope".

- `--diff-filter` の変更 ← REQ: Out of Scope #7
- 3000 件または 120000 バイトを超える差分の取得 ← REQ: Out of Scope #6

### 2.5 Behavioral Design Decisions

| ID        | Decision                                                                                                                                                            | Rationale                                                                                                                                                  | Affected Rules | Status           |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- | ---------------- |
| DD-DIF-01 | `git diff` は `-c core.quotePath=false`、`--name-only`、`--diff-filter=ACMR` だけを指定し、pathspec を渡さない。`<before> <after>` の前に `--end-of-options` を置く | リネーム検出などはリポジトリの設定に任せる。`--name-only` と ACMR では、リネームでも追加でも新しいパスが出る。`-` で始まる値はオプションとして解釈させない | R-DIF-001      | Active           |
| DD-DIF-02 | 一覧のバイト数が 120000 を超えたら、`files` を書く前にエラーとする                                                                                                  | 環境変数の上限を超えると絞り込みの段が起動できず、`::error::` が出ない (REQ-F-006)。上限は filter-files と同じ値                                           | R-DIF-003      | Promoted → DR-13 |

**Status Values:**

- `Active` — Currently in effect within this specification
- `Promoted → DR-xx` — Elevated to formal Decision Record (see Section 2.6)

<!-- impl-note: spec review で 2.5 から外した実装上の判断 (ID は廃止し、再利用しない)。
  DD-DIF-03: 上限の値は本 Action のライブラリに定数として持つ。filter-files のライブラリは別プロセスで動くため読み込まない (REQ-C-006)。
  DD-DIF-04: スクリプトの作りは内部 Action に合わせる (dirname と pwd による位置の解決、(return 0) による main のガード)。
  現行の ${BASH_SOURCE[0]%/*} と $0 の比較は使わない。 -->

### 2.6 Related Decision Records

| DR-ID | Title                                                                               | Phase         | Impact on This Spec     |
| ----- | ----------------------------------------------------------------------------------- | ------------- | ----------------------- |
| DR-01 | 差分範囲の SHA 解決を `_ca-resolve-sha` に任せる                                    | req           | R-DIF-030               |
| DR-02 | 変更ファイルの絞り込みを `_ca-filter-files` に任せる                                | req           | pathspec を渡さない     |
| DR-06 | `git diff` は `core.quotePath=false` で実行する                                     | req           | R-DIF-001               |
| DR-07 | `pattern` の有無に関わらず常に `_ca-filter-files` を通し、上限超過はエラーとする    | req           | R-DIF-003               |
| DR-09 | 旧ライブラリ `filter.lib.sh` はファイルごと削除する                                 | req (harden)  | R-DIF-030, R-DIF-031    |
| DR-13 | 変更ファイルの取得の段でも 120000 バイトの上限を検査する                            | spec (harden) | R-DIF-003               |
| DR-14 | エラーは内部 Action と同じ形式・文言で出し、内部のエラーと git の出力は書き換えない | spec (harden) | R-DIF-002、エラーの文言 |

### 2.7 DD to DR Promotion Criteria

See `specifications-index.md` 2.7.

---

## 3. Behavioral Specification

### 3.1 Input Domain

- Input Type: 環境変数 `BEFORE_SHA`・`AFTER_SHA`・`GITHUB_OUTPUT` と、作業ディレクトリのリポジトリ
- Assumptions: 2.2 の前提を満たす。

**環境変数契約:**

| Variable        | 由来                                   | 備考                      |
| --------------- | -------------------------------------- | ------------------------- |
| `BEFORE_SHA`    | `steps.resolve-sha.outputs.before_sha` | 空ツリー SHA の場合がある |
| `AFTER_SHA`     | `steps.resolve-sha.outputs.after_sha`  |                           |
| `GITHUB_OUTPUT` | GitHub Actions ランナー                | step 出力の書き出し先     |

環境変数を読むのは entry だけとする。list-changes は、entry から受け取った before / after だけを入力とする。

<!-- impl-note: entry は main (scripts/get-changed-files.sh) とする。
  list-changes は list_changed_files <before> <after> (scripts/_libs/get-changed-files.lib.sh) とする。
  関数との対応は workspaces/module/module.md の関数一覧を正とする。 -->

### 3.2 Output Semantics

- Output Meaning: step 出力 `files`。`git diff` の出力の行を、そのままの順で LF で連結した値
- 本書の「一覧」は、requirements の「変更ファイルの一覧」を指す。
- Possible Outcomes:
  - 成功: `files` を書き、終了コード 0。変更が無ければ `files` は空
  - 検証の失敗 (入力が空、出力先が不正、`git diff` の失敗、バイト数の超過): 何も書かず、エラーを 1 件出して非ゼロで終了する
  - 書き込みの失敗: エラーを出して非ゼロで終了する

<!-- impl-note: files は共有ライブラリの write_multiline_output <file> files [<line>...] で書く。
  出力先の検証は共有ライブラリの validate_output_file <file> を使う。
  どちらもエラーを出さず終了コードだけを返すため、エラーは main が 3.3 の形式で出す。 -->

---

## 4. Decision Rules

**変更ファイルの取得 (list-changes):**

| Rule ID   | Step | Condition                                                 | Outcome                                                                                                                                       |
| --------- | ---: | --------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| R-DIF-001 |    1 | —                                                         | 作業ディレクトリで `git -c core.quotePath=false diff --name-only --diff-filter=ACMR --end-of-options <before> <after>` を実行する (DD-DIF-01) |
| R-DIF-002 |    1 | `git diff` が非ゼロで終了した                             | エラー (対象 `files`)。一覧を返さずに失敗する                                                                                                 |
| R-DIF-003 |    2 | 一覧 (LF で連結、末尾の LF なし) が 120000 バイトを超える | エラー (対象 `files`)。一覧を返さずに失敗する (DR-13)                                                                                         |
| R-DIF-004 |    3 | —                                                         | 一覧を `git diff` の出力順のまま返す。行の加工 (引用表記の解除、空白の除去、並べ替え、重複の除去) はしない                                    |

- バイト数は文字数ではなくバイト数で数える。120000 バイトちょうどは受け付ける。
- R-DIF-002 では、git 自身の標準エラー出力は抑えずにそのまま出し、その後に `::error::` の 1 行を出す。原因の調査に git のメッセージを使えるようにする。
- 変更が無い場合は空の一覧を返し、成功とする。

**入口 (entry):**

| Rule ID   | Step | Condition                      | Outcome                                                                      |
| --------- | ---: | ------------------------------ | ---------------------------------------------------------------------------- |
| R-DIF-010 |    1 | `BEFORE_SHA` が空              | エラー (対象 `BEFORE_SHA`、空の形式)                                         |
| R-DIF-011 |    2 | `AFTER_SHA` が空               | エラー (対象 `AFTER_SHA`、空の形式)                                          |
| R-DIF-012 |    3 | `GITHUB_OUTPUT` が空           | エラー (対象 `GITHUB_OUTPUT`、空の形式)                                      |
| R-DIF-013 |    3 | `GITHUB_OUTPUT` に書き込めない | エラー (対象 `GITHUB_OUTPUT`)                                                |
| R-DIF-014 |    4 | —                              | 変更ファイルの取得 (R-DIF-001〜R-DIF-004) を行う。失敗したらそのまま失敗する |
| R-DIF-015 |    5 | —                              | 一覧の各行を 1 行として `files` に書く。0 行なら空の値を書く                 |
| R-DIF-016 |    5 | `files` の書き込みに失敗した   | エラー (対象 `files`)                                                        |

No reordering is permitted. 各 Step でエラーが起きた場合は、後続の Step を実行しない。
Step 1〜4 で失敗した場合、`$GITHUB_OUTPUT` には何も書かない。

<!-- impl-note: spec review で規則から外した実装上の作り (R-DIF-020〜R-DIF-022 は廃止し、再利用しない)。
  R-DIF-020: set -euo pipefail、ライブラリのロードガード、(return 0 2>/dev/null) による main のガードを持つ (DD-DIF-04)。
  R-DIF-021: list_changed_files は scripts/_libs/get-changed-files.lib.sh、main は scripts/get-changed-files.sh に置く。
  R-DIF-022: 出力先の検証と書き出しは、共有ライブラリ _libs/output.lib.sh の関数 (validate_output_file、write_multiline_output) で行う。
  共有ライブラリは変更しない。 -->

**旧ライブラリの削除 (legacy-removal):**

| Rule ID   | Step | Condition | Outcome                                                                                                                                                                        |
| --------- | ---: | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| R-DIF-030 |    — | —         | `scripts/_libs/filter.lib.sh` (`resolve_sha_for_event`・`resolve_before_sha`・`write_multiline_output`) をファイルごと削除する (DR-09)                                         |
| R-DIF-032 |    — | 検査      | `ca-get-changed-files/` 配下に `filter.lib.sh` が無く、`resolve_sha_for_event`・`resolve_before_sha`・`write_multiline_output` の定義が無いことを静的に確かめる (GACT、AC-016) |
| R-DIF-033 |    — | 検査      | 本 Action の上限 (120000 バイト) が、`_ca-filter-files` の `files` のバイト数の上限の定数と同じ値であることを静的に確かめる (GACT、DR-13)                                      |
| R-DIF-031 |    — | —         | 旧テスト (`scripts/_libs/__tests__/unit/filter.unit.spec.sh`、`scripts/__tests__/functional/get-changed-files.functional.spec.sh`) を削除し、`T-GCF-*` のテストに置き換える    |

**エラーの文言:**

問題の欄の英語は、実際に出す文字列とする。

| Rule ID   | 対象            | 問題                                                                                      |
| --------- | --------------- | ----------------------------------------------------------------------------------------- |
| R-DIF-002 | `files`         | `failed to list changed files` (値として `<before>..<after>` を埋め込む)                  |
| R-DIF-003 | `files`         | `exceeds the limit of 120000 bytes` (値としてバイト数を埋め込む。filter-files と同じ文言) |
| R-DIF-010 | `BEFORE_SHA`    | 空の形式 (`value must not be empty`)                                                      |
| R-DIF-011 | `AFTER_SHA`     | 空の形式 (`value must not be empty`)                                                      |
| R-DIF-012 | `GITHUB_OUTPUT` | 空の形式 (`value must not be empty`)                                                      |
| R-DIF-013 | `GITHUB_OUTPUT` | `is not a writable file` (値としてパスを埋め込む。filter-files と同じ文言)                |
| R-DIF-016 | `files`         | `failed to write` (値として出力先のパスを埋め込む。filter-files と同じ文言)               |

---

## 5. Edge Cases

| Input                                                     | Classification                                       | REQ       | Rationale                                            |
| --------------------------------------------------------- | ---------------------------------------------------- | --------- | ---------------------------------------------------- |
| before と after が同じツリー                              | `files` は空、成功                                   | REQ-F-003 | R-DIF-004, R-DIF-015                                 |
| before が空ツリー SHA                                     | after の全ファイルを返す                             | REQ-F-003 | R-DIF-001 (2 引数の形)                               |
| 削除だけの差分                                            | `files` は空、成功                                   | REQ-F-003 | `--diff-filter=ACMR`                                 |
| 通常ファイルからシンボリックリンクへの変更 (型の変更 `T`) | `files` に含めない                                   | REQ-F-003 | `--diff-filter=ACMR` は `T` を含まない。改訂前と同じ |
| リネーム (`a.sh` → `b.sh`)                                | `b.sh` だけを返す                                    | REQ-F-003 | DD-DIF-01                                            |
| `docs/日本語.md` の追加                                   | そのまま返す                                         | REQ-F-003 | DR-06                                                |
| `a"b.sh`・`a\b.sh`・タブを含むパスの追加                  | 引用表記のまま返す。絞り込みの段でエラーになる       | REQ-F-006 | R-DIF-004, DR-06                                     |
| 空白を含むパス (`my file.sh`)                             | そのまま返す                                         | REQ-F-003 | `core.quotePath` は空白を引用しない                  |
| 一覧がちょうど 120000 バイト                              | 受け付ける                                           | REQ-F-006 | R-DIF-003                                            |
| 一覧が 120001 バイト                                      | エラー、何も書かない                                 | REQ-F-006 | R-DIF-003                                            |
| `BEFORE_SHA` が不在のコミット (契約違反)                  | `git diff` が失敗し、エラー                          | REQ-F-006 | R-DIF-002                                            |
| `BEFORE_SHA` が `-` で始まる値 (契約違反)                 | オプションとして解釈せず `git diff` が失敗し、エラー | REQ-F-006 | R-DIF-001, R-DIF-002                                 |
| `GITHUB_OUTPUT` が未設定                                  | `git diff` を実行せずにエラー                        | REQ-F-006 | R-DIF-012                                            |
| 一覧に行全体が `EOF` の行がある                           | 区切り文字は `EOF_1` (共有ライブラリの規則)          | REQ-F-003 | `_ca-filter-files` R-OUT-011                         |

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule                                             | Notes                                     |
| -------------- | ----------------------------------------------------- | ----------------------------------------- |
| REQ-F-003      | R-DIF-001, R-DIF-004, R-DIF-015                       | DD-DIF-01                                 |
| REQ-F-006      | R-DIF-002, R-DIF-003, R-DIF-010〜R-DIF-016, R-DIF-033 | DD-DIF-02                                 |
| REQ-F-008      | R-DIF-030〜R-DIF-032                                  |                                           |
| REQ-NF-001     | R-DIF-031                                             | 実 git fixture (非 ASCII を含む) は MAINF |
| REQ-F-007      | —                                                     | Covered in: `specifications-action.md`    |

---

## 7. Open Questions

> **Status**: COMPLETE

None identified - all requirements are unambiguous.

---

## 8. Change History

| Date       | Version | Description                                                                                                                                                                                |
| ---------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 2026-10-29 | 1.0.0   | Initial release                                                                                                                                                                            |
| 2026-10-29 | 1.0.1   | Apply spec second opinion: EOF edge case matches whole lines only; refresh based-on (requirements v2.0.2)                                                                                  |
| 2026-10-29 | 1.0.2   | Cite DR-09 in R-DIF-030; refresh based-on (requirements v2.1.0)                                                                                                                            |
| 2026-10-29 | 1.1.0   | Apply spec explore review: add R-DIF-032 (absence check, AC-016), fix error strings in English, git stderr passes through (R-DIF-002), define 一覧; refresh based-on (requirements v2.1.2) |
| 2026-10-30 | 1.1.1   | Promote DD-DIF-02 to DR-13; reference DR-14 for error wording                                                                                                                              |
| 2026-10-30 | 1.1.2   | Apply spec fix review: unify stage terms, close the sentence in 2.1, cite DR-13                                                                                                            |
| 2026-10-30 | 1.2.0   | Apply spec second opinion: add R-DIF-033 (limit in sync with filter-files), type change edge case                                                                                          |
| 2026-10-30 | 2.2.0   | Unify document versions to 2.2.0 and approve                                                                                                                                               |
| 2026-10-30 | 2.2.1   | Put --end-of-options before <before> <after> in R-DIF-001 / DD-DIF-01, add the option-like before edge case                                                                                |
