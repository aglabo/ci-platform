---
title: "Implementation Tasks"
module: "composite-action/get-changed-files"
status: Active
created: "2026-10-30 02:11:09"
source: specifications-index.md v2.2.0, specifications-diff.md v2.2.1, implementation.md v2.3.1
---

<!-- textlint-disable ja-technical-writing/sentence-length -->
<!-- textlint-disable ja-technical-writing/max-comma -->
<!-- markdownlint-disable no-duplicate-heading line-length -->

> This document contains implementation tasks derived from specifications.
> Each task corresponds to a single unit test case (`It` block).

## Conventions

- Task ID (`T-XX-YY-ZZ`) は本書内の作業単位の ID とする。テストコードのケース名には、各タスクの `Test ID` (`T-GCF-<略語>-NN`) を埋め込む。略語は `workspaces/module/module.md` の「関数一覧」に従う (DD-IDX-03)。
- テストコードの分類 prefix は、`[正常]` → `[Normal]`、`[異常]` → `[Error]`、`[エッジケース]` → `[Edge]` と読み替える。
- ShellSpec の `It` にはテスト ID をリテラルで書き、`Parameters` は使わない。
- 本 Action のスクリプトが出すエラー (R-DIF-002〜R-DIF-016) は、spec の「エラーの文言」が定める英語の文言まで含めて確かめる (DR-14)。値は §3.3 のエンコード後の形で比べる。
- 内部 Action のスクリプトが出すエラー (RUNF) は、`::error::` の接頭辞と対象 (`commit-count`・`files`・`patterns`) だけを確かめる。文言は内部 Action の仕様に任せる。
- 失敗系は `When call` / `When run` で、終了コードと stderr を確かめる。
- 終了コード 0 を期待するタスク (LCF・MAINF・RUNF) では、stderr が空であることも確かめる。本 Action と内部 Action のスクリプトは、成功時に stderr へ何も出さない。各タスクの Expected には書かず、この規則で扱う。
- 現在のタスクに、書き込み権限に依存するものは無い。書き込めない出力先はディレクトリで作るため、root でも成立する。書き込み権限に依存するタスクを追加する場合に限り、root では `Skip if` で飛ばす。
- fixture・期待値ファイル・環境変数の隔離・所要時間の記録は、implementation.md §1.3「テスト」に従う。特殊文字・シンボリックリンク・大量のパスは index への直接の登録で作り、大量のパスと特殊文字のケースは期待値ファイルとの比較で検証する (DR-15)。
- テストを追加したコミットで、そのテストが使う略語を `module.md` の「テスト対象の略語」表に追記する (テスト ID 検査 D)。
- テストケースを持たない implementation.md の項目は、Task ID を割り当てずに次で扱う。
  - Phase 1 開始前のベースライン全テスト実行
  - 各テストのコミット後のテスト ID 機械検査 B / D と、PR の最後の検査 A / C
  - Phase 3 Commit 3 の `GCF_FIXTURE_TIMING` による所要時間の記録と PR への記録
  - Phase 4 Commit 1 の CI ジョブ (`test-get-changed-files`) の改訂 (R-IDX-001〜R-IDX-007、失敗系の `files`・`count` が空であることの確認を含む)
  - PR 本文への破壊的変更と移行方法の記載 (R-IDX-020)
  - Phase 2 Commit 1 の旧 functional テスト (`T-gcf-*`) の削除と、Phase 3 Commit 2 の `scripts/_libs/__tests__/unit/filter.unit.spec.sh` の削除 (R-DIF-031)
- 対象は SHA-1 のリポジトリ (40 桁の OID) とする。fixture は `git-fixture.sh` が sha1 で作る。
- shallow / partial clone、タグの push、ブランチ削除の push の拒否は `_ca-resolve-sha` の規則であり、`_ca-resolve-sha` のテストが検証する。本書では扱わない。
- 境界値は、境界ごとに必要な 2 つの値で確かめる。上限 (`<= max` を受け付ける) は `=` (max、受け付ける) と `>` (max+1、拒否する)、下限 (`>= min` を受け付ける) は `<` (min-1、拒否する) と `=` (min、受け付ける) とする。境界と Task ID の対応は「Boundary Check」の表に示す (DR-16)。
- 大量のパスの fixture (約 120000 バイト、3000 / 3001 件) は index への直接の登録で作る。所要時間は Phase 3 Commit 3 の記録で確かめ、遅いかどうかはユーザーが判断する。ユーザーが方式の見直しを求めた場合に限り、implementation.md §1.3「所要時間の記録」の手順で実ファイル方式と比べる。
- `action.yml` の値 (env の対応付け、step の構成) は GACT だけが検証する。RUNF は env を自前で組み立てるため、action.yml の値に依存するケース (呼び出し元の env が使われないことなど) を RUNF に置かない (DR-16)。

**関数ごとの実装上の詳細** (ライブラリの読み込み、`gha_error`、`main` の呼び出し順、action.yml の構成) は、implementation.md §1.3 に従う。

---

## Task Summary

| Test Target                           | Scenarios | Cases | Status |
| ------------------------------------- | --------- | ----- | ------ |
| T-01: list_changed_files (LCF)        | 7         | 22    | done   |
| T-02: get-changed-files.sh (MAINF)    | 6         | 21    | done   |
| T-03: action.yml static checks (GACT) | 4         | 23    | done   |
| T-04: step chain of action.yml (RUNF) | 3         | 29    | done   |

---

## T-01: list_changed_files

対象: `list_changed_files <before> <after>` (LCF)。R-DIF-001〜R-DIF-004、DD-DIF-01、DR-06、DR-13、DR-14。テストファイルは `scripts/_libs/__tests__/unit/get-changed-files.unit.spec.sh`。implementation.md Phase 1 Commit 1。同じコミットで `module.md` の「テスト対象の略語」に `LCF` を追記する。

特記の無い限り、`gf_setup` の一時ディレクトリの下に実 git リポジトリを作り、`gf_run_in <repo> list_changed_files <before> <after>` で実行する。「一覧」は stdout を指す。

### [正常] Normal Cases

#### T-01-01: 変更ファイルの一覧を返す

- [x] **T-01-01-01**: 変更と追加のファイルを返す
  - Target: `list_changed_files`
  - Test ID: T-GCF-LCF-01
  - Scenario: Given before で `a.sh` があり、after で `a.sh` が変更され `b.md` が追加されたリポジトリ, When before と after を渡して呼ぶ
  - Expected: Then 終了コードは 0、一覧は `$'a.sh\nb.md'`、stderr は空である (R-DIF-001、R-DIF-004)

- [x] **T-01-01-02**: リネームでは新しいパスだけを返す
  - Target: `list_changed_files`
  - Test ID: T-GCF-LCF-02
  - Scenario: Given `a.sh` を `b.sh` へ `git mv` したコミット, When その前後を渡して呼ぶ
  - Expected: Then 終了コードは 0 で、一覧は `b.sh` だけである (DD-DIF-01)

- [x] **T-01-01-03**: 非 ASCII 文字を含むパスは引用表記にしない
  - Target: `list_changed_files`
  - Test ID: T-GCF-LCF-03
  - Scenario: Given `docs/日本語.md` を追加したコミット, When その前後を渡して呼ぶ
  - Expected: Then 終了コードは 0 で、一覧は `docs/日本語.md` である (DR-06)

- [x] **T-01-01-04**: 空白を含むパスをそのまま返す
  - Target: `list_changed_files`
  - Test ID: T-GCF-LCF-04
  - Scenario: Given `my file.sh` を追加したコミット, When その前後を渡して呼ぶ
  - Expected: Then 終了コードは 0 で、一覧は `my file.sh` である

- [x] **T-01-01-05**: before が空ツリー SHA なら after の全ファイルを返す
  - Target: `list_changed_files`
  - Test ID: T-GCF-LCF-05
  - Scenario: Given `a.sh` と `b.sh` を持つ 1 コミットのリポジトリ, When before に `4b825dc642cb6eb9a060e54bf8d69288fbee4904`、after に HEAD を渡して呼ぶ
  - Expected: Then 終了コードは 0 で、一覧は `$'a.sh\nb.sh'` である (spec diff §5)

- [x] **T-01-01-06**: 一覧は git の出力順のまま返す
  - Target: `list_changed_files`
  - Test ID: T-GCF-LCF-06
  - Scenario: Given `z.sh`・`a.sh`・`dir/b.sh` をこの順に index へ直接登録して追加したコミット (DR-15), When その前後を渡して呼ぶ
  - Expected: Then 終了コードは 0 で、一覧は、パスを `LC_ALL=C sort` で並べた期待値ファイルと一致する (R-DIF-004)

- [x] **T-01-01-07**: before と after の間の差分だけを返す
  - Target: `list_changed_files`
  - Test ID: T-GCF-LCF-21
  - Scenario: Given `a.sh` を追加した before、`b.md` を追加した中間のコミット、`a.sh` を変更した after、その後に `c.txt` を追加し `a.sh` を再び変更した HEAD のリポジトリ, When before と after (HEAD ではない) を渡して呼ぶ
  - Expected: Then 終了コードは 0 で、一覧は `$'a.sh\nb.md'` である (`c.txt` を含まず、中間のコミットの `b.md` を含む) (R-DIF-001)

#### T-01-02: 変更が無い差分

- [x] **T-01-02-01**: 同じツリーなら空の一覧で成功する
  - Target: `list_changed_files`
  - Test ID: T-GCF-LCF-07
  - Scenario: Given 1 コミットのリポジトリ, When before と after に同じ HEAD を渡して呼ぶ
  - Expected: Then 終了コードは 0 で、一覧は空である

- [x] **T-01-02-02**: 削除だけの差分は空の一覧になる
  - Target: `list_changed_files`
  - Test ID: T-GCF-LCF-08
  - Scenario: Given `old.sh` だけを削除したコミット, When その前後を渡して呼ぶ
  - Expected: Then 終了コードは 0 で、一覧は空である (`--diff-filter=ACMR`)

- [x] **T-01-02-03**: 型の変更 (通常ファイル → シンボリックリンク) は含めない
  - Target: `list_changed_files`
  - Test ID: T-GCF-LCF-09
  - Scenario: Given `link` を mode `100644` の通常ファイルから mode `120000` のエントリへ index で置き換えたコミット, When その前後を渡して呼ぶ
  - Expected: Then 終了コードは 0 で、一覧は空である (spec diff §5)

### [異常] Error Cases

#### T-01-03: git diff の失敗

- [x] **T-01-03-01**: 不在のコミットでは git の出力の後にエラーを 1 行出す
  - Target: `list_changed_files`
  - Test ID: T-GCF-LCF-10
  - Scenario: Given 1 コミットのリポジトリと、リポジトリに無い 40 桁の SHA, When before にその SHA、after に HEAD を渡して呼ぶ
  - Expected: Then 終了コードは 1、一覧は空、stderr の最後の行は `::error::files: failed to list changed files (got: '<before>..<after>')` で、その前の行は同じリポジトリで同じ `git diff` を直接実行したときの stderr と一致し、空ではない (R-DIF-002、DR-14)

- [x] **T-01-03-02**: エラーの値の `%` と LF をエンコードする
  - Target: `list_changed_files`
  - Test ID: T-GCF-LCF-11
  - Scenario: Given 1 コミットのリポジトリ, When before に `$'a%b\nc'`、after に HEAD を渡して呼ぶ
  - Expected: Then 終了コードは 1 で、stderr の最後の行の値は `a%25b%0Ac..<after>` である (DD-IDX-01、spec index §3.3)

- [x] **T-01-03-03**: エラーの値の CR をエンコードする
  - Target: `list_changed_files`
  - Test ID: T-GCF-LCF-12
  - Scenario: Given 1 コミットのリポジトリ, When before に `$'a\rb'`、after に HEAD を渡して呼ぶ
  - Expected: Then 終了コードは 1 で、stderr の最後の行の値は `a%0Db..<after>` であり、行の中に CR を含まない (DD-IDX-01、spec index §3.3)

- [x] **T-01-03-04**: `-` で始まる before をオプションとして解釈しない
  - Target: `list_changed_files`
  - Test ID: T-GCF-LCF-22
  - Scenario: Given 1 コミットのリポジトリと、一時ディレクトリの下のまだ無いファイル `<out>`, When before に `--output=<out>`、after に HEAD を渡して呼ぶ
  - Expected: Then 終了コードは 1、一覧は空、stderr の最後の行の値は `--output=<out>..<after>` で、`<out>` は作られない (R-DIF-001、R-DIF-002、DD-DIF-01)

#### T-01-04: バイト数の上限

- [x] **T-01-04-01**: 120001 バイトの一覧はエラーにする
  - Target: `list_changed_files`
  - Test ID: T-GCF-LCF-13
  - Scenario: Given 一覧 (LF で連結、末尾の LF なし) が ASCII で 120001 バイトになるパスを index へ直接登録したコミット, When その前後を渡して呼ぶ
  - Expected: Then 終了コードは 1、一覧は空、stderr は `::error::files: exceeds the limit of 120000 bytes (got: '120001')` の 1 行である (R-DIF-003、DR-13)

### [エッジケース] Edge Cases

#### T-01-05: 上限の境界

- [x] **T-01-05-01**: 120000 バイトちょうどの一覧は受け付ける
  - Target: `list_changed_files`
  - Test ID: T-GCF-LCF-14
  - Scenario: Given 一覧がちょうど 120000 バイトになるパスを index へ直接登録したコミット, When その前後を渡して呼ぶ
  - Expected: Then 終了コードは 0 で、一覧は期待値ファイルと一致する (R-DIF-003)

- [x] **T-01-05-02**: UTF-8 のロケールでもバイト数で数える
  - Target: `list_changed_files`
  - Test ID: T-GCF-LCF-15
  - Scenario: Given 非 ASCII 文字を含み、一覧が 120001 バイト (文字数は 120000 未満) になるパスを index へ直接登録したコミット, When 呼び出し元で `LC_ALL=C.UTF-8` にして呼ぶ
  - Expected: Then 終了コードは 1 で、stderr の値は `120001` である (spec diff R-DIF-003 の注記)

#### T-01-06: 引用表記のまま返すパス

- [x] **T-01-06-01**: ダブルクオートを含むパスは引用表記で返す
  - Target: `list_changed_files`
  - Test ID: T-GCF-LCF-16
  - Scenario: Given `a"b.sh` を index へ直接登録したコミット, When その前後を渡して呼ぶ
  - Expected: Then 終了コードは 0 で、一覧は `"a\"b.sh"` である (R-DIF-004、DR-06)

- [x] **T-01-06-02**: バックスラッシュを含むパスは引用表記で返す
  - Target: `list_changed_files`
  - Test ID: T-GCF-LCF-17
  - Scenario: Given `a\b.sh` を index へ直接登録したコミット, When その前後を渡して呼ぶ
  - Expected: Then 終了コードは 0 で、一覧は `"a\\b.sh"` である

- [x] **T-01-06-03**: タブを含むパスは引用表記で返す
  - Target: `list_changed_files`
  - Test ID: T-GCF-LCF-18
  - Scenario: Given `a<TAB>b.sh` を index へ直接登録したコミット, When その前後を渡して呼ぶ
  - Expected: Then 終了コードは 0 で、一覧は `"a\tb.sh"` である

- [x] **T-01-06-04**: LF を含むパスは引用表記の 1 行で返す
  - Target: `list_changed_files`
  - Test ID: T-GCF-LCF-19
  - Scenario: Given `$'a\nb.sh'` を index へ直接登録したコミット, When その前後を渡して呼ぶ
  - Expected: Then 終了コードは 0 で、一覧は `"a\nb.sh"` の 1 行である (一覧の 1 行が 1 パスに対応する前提。implementation.md §1.3、DR-06)

#### T-01-07: ライブラリの読み込み

- [x] **T-01-07-01**: 2 回読み込んでも呼べる
  - Target: `list_changed_files`
  - Test ID: T-GCF-LCF-20
  - Scenario: Given `get-changed-files.lib.sh` を 2 回 source したシェル, When T-01-01-01 と同じリポジトリで呼ぶ
  - Expected: Then 終了コードは 0 で、2 回目の source は 0 を返して `readonly` の再定義エラーを出さず、一覧は `$'a.sh\nb.md'` である

---

## T-02: get-changed-files.sh

対象: `scripts/get-changed-files.sh` の `main` を、環境変数を設定して実行する (MAINF、functional)。R-DIF-010〜R-DIF-016、AC-009、AC-010、AC-015。テストファイルは `scripts/__tests__/functional/get-changed-files.functional.spec.sh` (旧テストの内容を置き換える)。implementation.md Phase 2 Commit 1。同じコミットで `module.md` に `MAINF` を追記する。

特記の無い限り、`BEFORE_SHA`・`AFTER_SHA` は fixture のコミット、`GITHUB_OUTPUT` は空の一時ファイルとし、スクリプトが読むほかの環境変数とライブラリのロードガード変数 (`*_LIB_LOADED`) は unset する。「files 出力」は出力ファイルの `files` の値を指す。エラー系はすべて、終了コードが 0 以外で、出力ファイルが実行前の内容のまま (空の一時ファイルなら空) であることを確かめる。ただし T-02-04-03 (書き込みの失敗) はエラーだけを確かめる。書き出しの開始後の失敗では、出力が残り得るためである (spec index §3.2)。

### [正常] Normal Cases

#### T-02-01: files を書く

- [x] **T-02-01-01**: 変更と追加のファイルを files に書く
  - Target: `get-changed-files.sh`
  - Test ID: T-GCF-MAINF-01
  - Scenario: Given `a.sh` を変更し `b.md` を追加したコミットの前後, When スクリプトを実行する
  - Expected: Then 終了コードは 0、files 出力は `$'a.sh\nb.md'` で、出力ファイルは `files<<EOF` ブロックだけを持つ (`count` は書かない) (R-DIF-015)

- [x] **T-02-01-02**: 削除されたファイルは files に含めない
  - Target: `get-changed-files.sh`
  - Test ID: T-GCF-MAINF-02
  - Scenario: Given `old.sh` を削除し `new.sh` を追加したコミットの前後, When スクリプトを実行する
  - Expected: Then 終了コードは 0 で、files 出力は `new.sh` だけである (AC-009)

- [x] **T-02-01-03**: 非 ASCII 文字を含むパスをそのまま書く
  - Target: `get-changed-files.sh`
  - Test ID: T-GCF-MAINF-03
  - Scenario: Given `docs/日本語.md` を追加したコミットの前後, When スクリプトを実行する
  - Expected: Then 終了コードは 0 で、files 出力は `docs/日本語.md` である (AC-010)

- [x] **T-02-01-04**: 出力ファイルの既存の内容を残して追記する
  - Target: `get-changed-files.sh`
  - Test ID: T-GCF-MAINF-04
  - Scenario: Given 出力ファイルに `prev=1` の 1 行がある, When T-02-01-01 と同じ差分で実行する
  - Expected: Then 終了コードは 0 で、出力ファイルの 1 行目は `prev=1` のままで、その後に files のブロックがある

#### T-02-02: 空の files

- [x] **T-02-02-01**: 同じツリーなら空の files を書く
  - Target: `get-changed-files.sh`
  - Test ID: T-GCF-MAINF-05
  - Scenario: Given `BEFORE_SHA` と `AFTER_SHA` が同じコミット, When スクリプトを実行する
  - Expected: Then 終了コードは 0 で、files 出力は空文字列である (AC-015、R-DIF-015)

- [x] **T-02-02-02**: 削除だけの差分は空の files を書く
  - Target: `get-changed-files.sh`
  - Test ID: T-GCF-MAINF-06
  - Scenario: Given `old.sh` だけを削除したコミットの前後, When スクリプトを実行する
  - Expected: Then 終了コードは 0 で、files 出力は空文字列である (AC-015)

### [異常] Error Cases

#### T-02-03: 入力と出力先の検証

- [x] **T-02-03-01**: BEFORE_SHA が空
  - Target: `get-changed-files.sh`
  - Test ID: T-GCF-MAINF-07
  - Scenario: Given `BEFORE_SHA=""`, When スクリプトを実行する
  - Expected: Then stderr は `::error::BEFORE_SHA: value must not be empty` の 1 行である (R-DIF-010)

- [x] **T-02-03-02**: AFTER_SHA が空
  - Target: `get-changed-files.sh`
  - Test ID: T-GCF-MAINF-08
  - Scenario: Given `AFTER_SHA=""`, When スクリプトを実行する
  - Expected: Then stderr は `::error::AFTER_SHA: value must not be empty` の 1 行である (R-DIF-011)

- [x] **T-02-03-03**: GITHUB_OUTPUT が空
  - Target: `get-changed-files.sh`
  - Test ID: T-GCF-MAINF-09
  - Scenario: Given `GITHUB_OUTPUT=""`, When スクリプトを実行する
  - Expected: Then stderr は `::error::GITHUB_OUTPUT: value must not be empty` の 1 行である (R-DIF-012)

- [x] **T-02-03-04**: GITHUB_OUTPUT がディレクトリ
  - Target: `get-changed-files.sh`
  - Test ID: T-GCF-MAINF-10
  - Scenario: Given `GITHUB_OUTPUT` が既存のディレクトリ, When スクリプトを実行する
  - Expected: Then stderr は `::error::GITHUB_OUTPUT: is not a writable file (got: '<path>')` の 1 行である (R-DIF-013)

#### T-02-04: 取得と書き込みの失敗

- [x] **T-02-04-01**: git diff の失敗
  - Target: `get-changed-files.sh`
  - Test ID: T-GCF-MAINF-11
  - Scenario: Given `BEFORE_SHA` がリポジトリに無い 40 桁の SHA, When スクリプトを実行する
  - Expected: Then stderr の最後の行は `::error::files: failed to list changed files (got: '<before>..<after>')` で、出力ファイルは空である (R-DIF-014、R-DIF-002)

- [x] **T-02-04-02**: 120001 バイトの一覧
  - Target: `get-changed-files.sh`
  - Test ID: T-GCF-MAINF-12
  - Scenario: Given 一覧が 120001 バイトになるパスを index へ直接登録したコミットの前後, When スクリプトを実行する
  - Expected: Then stderr は `::error::files: exceeds the limit of 120000 bytes (got: '120001')` の 1 行で、出力ファイルは空である (R-DIF-014、DR-13)

- [x] **T-02-04-03**: files の書き込みの失敗
  - Target: `get-changed-files.sh`
  - Test ID: T-GCF-MAINF-13
  - Scenario: Given R-DIF-016 専用の内部ヘルパー (通常のケースの `bash` 実行のヘルパーとは分ける) がサブシェルの中でスクリプトを source し、`write_multiline_output` を 2 を返す関数に差し替える (`set -euo pipefail` を ShellSpec の実行シェルに残さない), When そのヘルパーで `main` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::files: failed to write (got: '<GITHUB_OUTPUT のパス>')` の 1 行である (R-DIF-016)

### [エッジケース] Edge Cases

#### T-02-05: 検査の順序

- [x] **T-02-05-01**: BEFORE_SHA と GITHUB_OUTPUT がともに空なら BEFORE_SHA だけを報告する
  - Target: `get-changed-files.sh`
  - Test ID: T-GCF-MAINF-15
  - Scenario: Given `BEFORE_SHA=""`、`GITHUB_OUTPUT=""`, When スクリプトを実行する
  - Expected: Then stderr は `::error::BEFORE_SHA: value must not be empty` の 1 行だけである (R-DIF-010〜R-DIF-012 の順)

- [x] **T-02-05-02**: 出力先の検証は git diff より先に行う
  - Target: `get-changed-files.sh`
  - Test ID: T-GCF-MAINF-16
  - Scenario: Given `GITHUB_OUTPUT` がディレクトリで、`BEFORE_SHA` がリポジトリに無い SHA, When スクリプトを実行する
  - Expected: Then stderr は `::error::GITHUB_OUTPUT: is not a writable file (got: '<path>')` の 1 行だけで、git の出力を含まない (R-DIF-013 → R-DIF-014 の順)

#### T-02-06: 値と出力先の境界

- [x] **T-02-06-01**: GITHUB_OUTPUT が未設定
  - Target: `get-changed-files.sh`
  - Test ID: T-GCF-MAINF-17
  - Scenario: Given `GITHUB_OUTPUT` を unset した環境, When スクリプトを実行する
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::GITHUB_OUTPUT: value must not be empty` の 1 行である (spec diff §5)

- [x] **T-02-06-02**: 存在しない出力先は親ディレクトリが書ければ作って書く
  - Target: `get-changed-files.sh`
  - Test ID: T-GCF-MAINF-18
  - Scenario: Given `GITHUB_OUTPUT` が、書き込める一時ディレクトリの下の存在しないパス, When T-02-01-01 と同じ差分で実行する
  - Expected: Then 終了コードは 0 で、そのパスのファイルに files のブロックがある

- [x] **T-02-06-03**: 行全体が EOF のパスがあれば区切り文字を EOF_1 にする
  - Target: `get-changed-files.sh`
  - Test ID: T-GCF-MAINF-19
  - Scenario: Given `EOF` という名前のファイルを追加したコミットの前後, When スクリプトを実行する
  - Expected: Then 終了コードは 0 で、出力ファイルは `files<<EOF_1` で始まり、files 出力は `EOF` である (spec diff §5)

- [x] **T-02-06-04**: 引用表記のパスはそのまま書く
  - Target: `get-changed-files.sh`
  - Test ID: T-GCF-MAINF-20
  - Scenario: Given `a"b.sh` を index へ直接登録したコミットの前後, When スクリプトを実行する
  - Expected: Then 終了コードは 0 で、files 出力は `"a\"b.sh"` である (パスの検査は絞り込みの段が担う。R-DIF-004)

- [x] **T-02-06-05**: 120000 バイトちょうどの一覧を書く
  - Target: `get-changed-files.sh`
  - Test ID: T-GCF-MAINF-21
  - Scenario: Given 一覧がちょうど 120000 バイトになるパスを index へ直接登録したコミットの前後, When スクリプトを実行する
  - Expected: Then 終了コードは 0 で、files 出力は期待値ファイルと一致する

- [x] **T-02-06-06**: 検証で失敗しても出力ファイルの既存の内容を変えない
  - Target: `get-changed-files.sh`
  - Test ID: T-GCF-MAINF-22
  - Scenario: Given 出力ファイルに `prev=1` の 1 行があり、`BEFORE_SHA=""`, When スクリプトを実行する
  - Expected: Then 終了コードは 0 以外、stderr は `::error::BEFORE_SHA: value must not be empty` の 1 行で、出力ファイルは `prev=1` の 1 行のままである (spec diff「Step 1〜4 で失敗した場合、何も書かない」)

---

## T-03: action.yml

対象: `action.yml` と配下の静的検査 (GACT、unit)。R-ACT-001〜R-ACT-046、R-DIF-032、R-DIF-033、AC-016、AC-017。テストファイルは `scripts/__tests__/unit/action.unit.spec.sh`。implementation.md Phase 3 Commit 1 (T-03-03-04・T-03-03-05・T-03-04-03 は Commit 2)。Commit 1 で `module.md` に `GACT` を追記する。

YAML は読むだけで実行しない。section・step・env の抽出は、本ファイルの内部ヘルパーで行う (implementation.md §1.3 GACT)。

### [正常] Normal Cases

#### T-03-01: 入出力の宣言

- [x] **T-03-01-01**: 入力は commit-count と pattern だけ
  - Target: `action.yml`
  - Test ID: T-GCF-GACT-01
  - Scenario: Given action.yml, When `inputs` の入力名を取り出す
  - Expected: Then 入力名の集合は `commit-count`・`pattern` で、`before-sha`・`after-sha` を含まない (R-ACT-001、R-ACT-043)

- [x] **T-03-01-02**: commit-count は任意で既定値 "1"
  - Target: `action.yml`
  - Test ID: T-GCF-GACT-02
  - Scenario: Given action.yml, When `commit-count` の `required` と `default` を取り出す
  - Expected: Then `required: false`、`default: "1"` である (R-ACT-001)

- [x] **T-03-01-03**: pattern は任意で既定値 ""
  - Target: `action.yml`
  - Test ID: T-GCF-GACT-03
  - Scenario: Given action.yml, When `pattern` の `required` と `default` を取り出す
  - Expected: Then `required: false`、`default: ""` である (R-ACT-001)

- [x] **T-03-01-04**: 出力は filter-files の step の出力を値とする
  - Target: `action.yml`
  - Test ID: T-GCF-GACT-04
  - Scenario: Given action.yml, When `outputs` の名前と値を取り出す
  - Expected: Then `files` は `${{ steps.filter-files.outputs.files }}`、`count` は `${{ steps.filter-files.outputs.count }}` で、ほかの出力は無い (R-ACT-002、R-ACT-044)

#### T-03-02: step の構成

- [x] **T-03-02-01**: step は 3 つで、id の順は resolve-sha → get-changed-files → filter-files
  - Target: `action.yml`
  - Test ID: T-GCF-GACT-05
  - Scenario: Given action.yml, When `runs.steps` の `id` を順に取り出す
  - Expected: Then `resolve-sha`・`get-changed-files`・`filter-files` の 3 行である (R-ACT-010〜R-ACT-012、DD-ACT-04)

- [x] **T-03-02-02**: 各 step は決められたスクリプトを実行する
  - Target: `action.yml`
  - Test ID: T-GCF-GACT-06
  - Scenario: Given action.yml, When 各 step の `run` を取り出す
  - Expected: Then 順に R-ACT-030・R-ACT-031・R-ACT-032 の `bash "${GITHUB_ACTION_PATH}/..."` と一致する

- [x] **T-03-02-03**: resolve-sha の step の env
  - Target: `action.yml`
  - Test ID: T-GCF-GACT-07
  - Scenario: Given action.yml, When resolve-sha の step の env を `KEY: value` の行で取り出す
  - Expected: Then R-ACT-020 の 7 行と、`INPUT_COMMIT_COUNT: ${{ inputs.commit-count }}`・`INPUT_BEFORE_SHA: ""`・`INPUT_AFTER_SHA: ""` の集合と過不足なく一致する (R-ACT-020、R-ACT-021、DD-ACT-02)

- [x] **T-03-02-04**: get-changed-files の step の env
  - Target: `action.yml`
  - Test ID: T-GCF-GACT-08
  - Scenario: Given action.yml, When get-changed-files の step の env を取り出す
  - Expected: Then `BEFORE_SHA: ${{ steps.resolve-sha.outputs.before_sha }}`・`AFTER_SHA: ${{ steps.resolve-sha.outputs.after_sha }}` の 2 行と一致する (R-ACT-022)

- [x] **T-03-02-05**: filter-files の step の env
  - Target: `action.yml`
  - Test ID: T-GCF-GACT-09
  - Scenario: Given action.yml, When filter-files の step の env を取り出す
  - Expected: Then `INPUT_FILES: ${{ steps.get-changed-files.outputs.files }}`・`INPUT_PATTERNS: ${{ inputs.pattern }}` の 2 行と一致する (R-ACT-023)

- [x] **T-03-02-06**: description に fetch-depth: 0 の必要が書かれている
  - Target: `action.yml`
  - Test ID: T-GCF-GACT-10
  - Scenario: Given action.yml, When `description` を取り出す
  - Expected: Then `fetch-depth: 0` を含む。大文字・小文字を区別して照合する (R-ACT-003、R-ACT-046、AC-017)

- [x] **T-03-02-07**: description に partial clone の不可が書かれている
  - Target: `action.yml`
  - Test ID: T-GCF-GACT-11
  - Scenario: Given action.yml, When `description` を取り出す
  - Expected: Then `partial clone` を含む。大文字・小文字を区別して照合する (R-ACT-003、R-ACT-046、AC-017)

- [x] **T-03-02-08**: description にブランチ削除とタグの push の除外が書かれている
  - Target: `action.yml`
  - Test ID: T-GCF-GACT-12
  - Scenario: Given action.yml, When `description` を取り出す
  - Expected: Then 単語 `deleted` と単語 `tag` の両方を含む。単語は `grep -w` 相当の単語境界で照合し、`tags` などの一部としての一致は数えない (R-ACT-003、R-ACT-046、AC-017)

- [x] **T-03-02-09**: description に作業ディレクトリへの checkout と path 不使用が書かれている
  - Target: `action.yml`
  - Test ID: T-GCF-GACT-13
  - Scenario: Given action.yml, When `description` を取り出す
  - Expected: Then `GITHUB_WORKSPACE` と単語 `path` の両方を含む。`path` は単語境界で照合する (R-ACT-003、R-ACT-046、AC-017)

### [異常] Error Cases

#### T-03-03: 禁止された書き方と旧ライブラリ

- [x] **T-03-03-01**: run に `${{` を含まない
  - Target: `action.yml`
  - Test ID: T-GCF-GACT-14
  - Scenario: Given action.yml, When すべての step の `run` を取り出す
  - Expected: Then どの `run` も `${{` を含まない (R-ACT-042、REQ-C-001)

- [x] **T-03-03-02**: 内部 Action を uses で参照しない
  - Target: `action.yml`
  - Test ID: T-GCF-GACT-15
  - Scenario: Given action.yml, When `runs` の section を走査する
  - Expected: Then `uses:` の行が無い (R-ACT-045、REQ-F-007)

- [x] **T-03-03-03**: 全 step が shell: bash で、if と continue-on-error を持たない
  - Target: `action.yml`
  - Test ID: T-GCF-GACT-16
  - Scenario: Given action.yml, When 各 step のキーを取り出す
  - Expected: Then 3 つの step すべてが `shell: bash` を持ち、`if:`・`continue-on-error:` を持たない (R-ACT-013)

- [x] **T-03-03-04**: filter.lib.sh が無い
  - Target: `ca-get-changed-files/`
  - Test ID: T-GCF-GACT-17
  - Scenario: Given `ca-get-changed-files/` 配下, When `filter.lib.sh` を探す
  - Expected: Then 見つからない (R-DIF-030、R-DIF-032、AC-016)

- [x] **T-03-03-05**: 旧関数の定義が無い
  - Target: `ca-get-changed-files/`
  - Test ID: T-GCF-GACT-18
  - Scenario: Given `ca-get-changed-files/` 配下の `.sh` ファイル (テストを除く), When 関数定義の行を探す
  - Expected: Then `resolve_sha_for_event`・`resolve_before_sha`・`write_multiline_output` の定義が無い (R-DIF-032、AC-016)
    - 定義の行は ERE `^[[:space:]]*(function[[:space:]]+)?<name>[[:space:]]*\(\)` で判定する (`name()`・`name ()`・`function name()` を定義とみなす)

- [x] **T-03-03-06**: オーバーライドの入力は空文字列のリテラルで渡す
  - Target: `action.yml`
  - Test ID: T-GCF-GACT-19
  - Scenario: Given action.yml, When resolve-sha の step の env から `INPUT_BEFORE_SHA` と `INPUT_AFTER_SHA` の値を取り出す
  - Expected: Then 2 つとも値は `""` で、`${{` を含まない。どちらかの行が無い場合も失敗とする (DD-ACT-02、R-ACT-021、REQ-F-002)

- [x] **T-03-03-07**: 削除した SHA 入力を参照しない
  - Target: `action.yml`
  - Test ID: T-GCF-GACT-20
  - Scenario: Given action.yml, When ファイル全体から `inputs.before-sha` と `inputs.after-sha` を探す
  - Expected: Then どちらの参照も無い (R-ACT-043、DR-03)

### [エッジケース] Edge Cases

#### T-03-04: 内部 Action との一致

- [x] **T-03-04-01**: resolve-sha の env が _ca-resolve-sha と一致する
  - Target: `action.yml`
  - Test ID: T-GCF-GACT-21
  - Scenario: Given action.yml と `_ca-resolve-sha/action.yml`, When 両者の step の env (`INPUT_BEFORE_SHA`・`INPUT_AFTER_SHA` を除く) を `KEY: value` で比べる
  - Expected: Then 変数名と式が過不足なく一致する (R-ACT-040、DR-12)

- [x] **T-03-04-02**: filter-files の env の名前が _ca-filter-files と一致する
  - Target: `action.yml`
  - Test ID: T-GCF-GACT-22
  - Scenario: Given action.yml と `_ca-filter-files/action.yml`, When 両者の step の env の変数名を比べる
  - Expected: Then 変数名の集合が一致する (R-ACT-041、DR-12)

- [x] **T-03-04-03**: バイト数の上限が filter-files と同じ値
  - Target: `get-changed-files.lib.sh`
  - Test ID: T-GCF-GACT-23
  - Scenario: Given `get-changed-files.lib.sh` と `_ca-filter-files/scripts/_libs/filter-files.lib.sh`, When 両ファイルから上限の定数 (`GCF_MAX_FILES_BYTES`・`FF_MAX_FILES_BYTES`) を読む
  - Expected: Then 両者は同じ値 (`120000`) である (R-DIF-033、DR-13)

---

## T-04: step chain of action.yml

対象: 3 つのスクリプトを action.yml と同じ順・パス・env で実行する連鎖 (RUNF、functional)。AC-001〜AC-008、AC-010〜AC-014、AC-018、REQ-C-008 (全ゼロの before)。テストファイルは `scripts/__tests__/functional/action.functional.spec.sh`。implementation.md Phase 3 Commit 3。同じコミットで `module.md` に `RUNF` を追記する。
RUNF は action.yml を読まず、env を自前で組み立てる。env の対応付けそのものは GACT (T-03-02、T-03-03、T-03-04) が検証する。

`ca-get-changed-files`・`_ca-resolve-sha`・`_ca-filter-files`・`_libs` を一時ディレクトリにコピーし、`GITHUB_ACTION_PATH` をコピー先の `ca-get-changed-files` にする。作業ディレクトリは `.github/actions` を持たない fixture リポジトリとする。イベントの環境変数は implementation.md §1.3 RUNF に従い、ライブラリのロードガード変数 (`*_LIB_LOADED`) は unset する。特記の無い限り、イベントは push (`GITHUB_REF=refs/heads/main`、`GITHUB_EVENT_DELETED=false`)、`INPUT_COMMIT_COUNT="1"` (action.yml の既定値)、`pattern` は空とする。「files 出力」「count 出力」は filter-files の step の出力を指す。

エラー系では、次をすべて確かめる。

- 連鎖の終了コードが 0 以外で、stderr に `::error::<対象>:` の行がある
- 失敗した step 自身の `$GITHUB_OUTPUT` が空である
- それより後の step の `$GITHUB_OUTPUT` が作られていない
- filter-files の step の出力に `files`・`count` が無い

### [正常] Normal Cases

#### T-04-01: 受け入れ基準

- [x] **T-04-01-01**: push で before..after の変更ファイルを返す
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-01
  - Scenario: Given `GITHUB_BEFORE_SHA` から `GITHUB_AFTER_SHA` までに `a.sh` が変更され `b.md` が追加されたリポジトリ, When 連鎖を実行する
  - Expected: Then 終了コードは 0 で、files 出力は `$'a.sh\nb.md'`、count 出力は `2` である (AC-001)

- [x] **T-04-01-02**: pull_request で base..head の変更ファイルを返す
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-02
  - Scenario: Given `a.sh` と `shared.sh` を持つコミットから分岐し、head 側で `a.sh` を変更して `b.md` を追加し、分岐後に base 側だけで `shared.sh` を変更し `base-only.sh` を追加した履歴。`GITHUB_EVENT_NAME=pull_request`、`GITHUB_BASE_SHA` は base の先頭、`GITHUB_HEAD_SHA` は head の先頭, When 連鎖を実行する
  - Expected: Then 終了コードは 0 で、files 出力は `$'a.sh\nb.md\nshared.sh'` である。base 側だけで変更した `shared.sh` は含まれ、base 側だけで追加した `base-only.sh` は (base → head では削除になるため) 含まれない (AC-002 の局所的な確認、spec index §3.1 の二点比較、`_ca-resolve-sha` DR-04)

- [x] **T-04-01-03**: その他イベントで HEAD~N..HEAD の変更ファイルを返す
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-03
  - Scenario: Given `GITHUB_EVENT_NAME=workflow_dispatch`、`INPUT_COMMIT_COUNT="2"`、直近 2 コミットで `a.sh` と `c.sh` を変更し、それより前に `old.sh` だけを変更したリポジトリ, When 連鎖を実行する
  - Expected: Then 終了コードは 0 で、files 出力は `a.sh` と `c.sh` を含み、`old.sh` を含まない (AC-003)

- [x] **T-04-01-04**: commit-count が既定値なら HEAD~1..HEAD を返す
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-04
  - Scenario: Given `GITHUB_EVENT_NAME=workflow_dispatch`、`INPUT_COMMIT_COUNT="1"`、ちょうど 2 コミット (N+1) の履歴のリポジトリ, When 連鎖を実行する
  - Expected: Then 終了コードは 0 で、files 出力は `git diff --name-only --diff-filter=ACMR HEAD~1 HEAD` の結果と一致する (AC-004)

- [x] **T-04-01-05**: 履歴が 1 コミットなら HEAD の全ファイルを返す
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-05
  - Scenario: Given `GITHUB_EVENT_NAME=workflow_dispatch` と、`a.sh`・`b.sh` を持つ 1 コミットだけのリポジトリ, When 連鎖を実行する
  - Expected: Then 終了コードは 0 で、files 出力は `$'a.sh\nb.sh'` である (AC-013)

- [x] **T-04-01-06**: 複数行の pattern と除外で絞り込む
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-06
  - Scenario: Given 変更ファイルが `src/a.sh`・`src/gen/b.sh`・`README.md`、`pattern=$'src/**\n!src/gen/**'`, When 連鎖を実行する
  - Expected: Then 終了コードは 0 で、files 出力は `src/a.sh`、count 出力は `1` である (AC-006)

- [x] **T-04-01-07**: pattern が空なら全件を返す
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-07
  - Scenario: Given 変更ファイルが `a.sh`・`dir/b.md`、`pattern=""`, When 連鎖を実行する
  - Expected: Then 終了コードは 0 で、files 出力は `$'a.sh\ndir/b.md'`、count 出力は `2` である (AC-007)

- [x] **T-04-01-08**: 一致 0 件は空の files と count "0" で成功する
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-08
  - Scenario: Given 変更ファイルが `a.sh`、`pattern='*.yml'`, When 連鎖を実行する
  - Expected: Then 終了コードは 0、files 出力は空文字列、count 出力は `0` である (AC-008)

- [x] **T-04-01-09**: 作業ディレクトリに内部 Action が無くても動く
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-09
  - Scenario: Given `.github/actions` を持たない作業ディレクトリと、コピー先を指す `GITHUB_ACTION_PATH`, When 連鎖を実行する
  - Expected: Then 3 つの step がすべて成功し、終了コードは 0 である (AC-014、R-ACT-030〜R-ACT-032)

### [異常] Error Cases

#### T-04-02: 何も公開せずに失敗する

- [x] **T-04-02-01**: commit-count が 0
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-10
  - Scenario: Given `GITHUB_EVENT_NAME=workflow_dispatch`、`INPUT_COMMIT_COUNT="0"`, When 連鎖を実行する
  - Expected: Then resolve-sha の step が失敗し、stderr に `::error::commit-count:` の行がある (AC-005)

- [x] **T-04-02-02**: commit-count が -1
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-11
  - Scenario: Given `GITHUB_EVENT_NAME=workflow_dispatch`、`INPUT_COMMIT_COUNT="-1"`, When 連鎖を実行する
  - Expected: Then resolve-sha の step が失敗し、stderr に `::error::commit-count:` の行がある (AC-005)

- [x] **T-04-02-03**: commit-count が abc
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-12
  - Scenario: Given `GITHUB_EVENT_NAME=workflow_dispatch`、`INPUT_COMMIT_COUNT="abc"`, When 連鎖を実行する
  - Expected: Then resolve-sha の step が失敗し、stderr に `::error::commit-count:` の行がある (AC-005)

- [x] **T-04-02-04**: ダブルクオートを含むパスがある差分
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-13
  - Scenario: Given `a"b.sh` を index へ直接登録したコミット, When 連鎖を実行する
  - Expected: Then filter-files の step が失敗し、stderr に `::error::files:` の行がある (AC-011)

- [x] **T-04-02-05**: 3001 件の差分
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-14
  - Scenario: Given 3001 個のパス (一覧は 120000 バイト以下) を index へ直接登録したコミット, When 連鎖を実行する
  - Expected: Then filter-files の step が失敗し、stderr に `::error::files:` の行がある (AC-012、DR-07)

- [x] **T-04-02-06**: 120001 バイトの差分
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-15
  - Scenario: Given 一覧が 120001 バイトになるパスを index へ直接登録したコミット, When 連鎖を実行する
  - Expected: Then get-changed-files の step が失敗して filter-files の step は実行されず、stderr に `::error::files: exceeds the limit of 120000 bytes` の行がある (AC-012、DR-13)

- [x] **T-04-02-07**: pattern が "!" だけの 1 行
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-16
  - Scenario: Given 変更ファイルが `a.sh`、`pattern='!'`, When 連鎖を実行する
  - Expected: Then filter-files の step が失敗し、stderr に `::error::patterns:` の行がある (AC-018)

- [x] **T-04-02-08**: pattern が 101 行
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-17
  - Scenario: Given 変更ファイルが `a.sh`、`pattern` が 101 行の glob, When 連鎖を実行する
  - Expected: Then filter-files の step が失敗し、stderr に `::error::patterns:` の行がある (AC-018)

- [x] **T-04-02-09**: pattern が 120001 バイト
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-18
  - Scenario: Given 変更ファイルが `a.sh`、`pattern` が 100 行以下で合計 120001 バイトの glob (どれも `a.sh` に一致しない), When 連鎖を実行する
  - Expected: Then filter-files の step が失敗し、stderr に `::error::patterns:` の行がある (REQ-F-006、`_ca-filter-files` REQ-F-018)

- [x] **T-04-02-10**: commit-count が上限を 1 超える 1001
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-19
  - Scenario: Given `GITHUB_EVENT_NAME=workflow_dispatch`、`INPUT_COMMIT_COUNT="1001"`, When 連鎖を実行する
  - Expected: Then resolve-sha の step が失敗し、stderr に `::error::commit-count:` の行がある (AC-005、`_ca-resolve-sha` REQ-F-002)

### [エッジケース] Edge Cases

#### T-04-03: 段をまたぐ境界

- [x] **T-04-03-01**: 非 ASCII のパスを pattern で絞り込める
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-20
  - Scenario: Given 変更ファイルが `docs/日本語.md` と `a.sh`、`pattern='docs/**'`, When 連鎖を実行する
  - Expected: Then 終了コードは 0 で、files 出力は `docs/日本語.md`、count 出力は `1` である (AC-010、DR-06)

- [x] **T-04-03-02**: 変更が無くても不正な pattern はエラーにする
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-21
  - Scenario: Given `GITHUB_EVENT_NAME=workflow_dispatch` で HEAD が空コミット (HEAD~1 と同じツリー)、`pattern='!'`, When 連鎖を実行する
  - Expected: Then filter-files の step が失敗し、stderr に `::error::patterns:` の行がある (spec index §5)

- [x] **T-04-03-03**: 除外されるパスに引用表記があってもエラーにする
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-22
  - Scenario: Given 変更ファイルが `a.sh` と index へ直接登録した `a"b.md`、`pattern='*.sh'`, When 連鎖を実行する
  - Expected: Then filter-files の step が失敗し、stderr に `::error::files:` の行がある (spec index §5、DR-07)

- [x] **T-04-03-04**: push の before が全ゼロなら HEAD~1..HEAD を返す
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-23
  - Scenario: Given 3 コミットのリポジトリと、`GITHUB_BEFORE_SHA` が 40 桁のゼロ、`GITHUB_AFTER_SHA` が HEAD の push の環境, When 連鎖を実行する
  - Expected: Then 終了コードは 0 で、files 出力は `git diff --name-only --diff-filter=ACMR HEAD~1 HEAD` の結果と一致する (REQ-C-008 の移行項目 4、REQ-F-002)

- [x] **T-04-03-05**: 3000 件ちょうどの差分は受け付ける
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-24
  - Scenario: Given 3000 個のパス (一覧は 120000 バイト以下) を index へ直接登録したコミット, When 連鎖を実行する
  - Expected: Then 終了コードは 0、files 出力は期待値ファイルと一致し、count 出力は `3000` である (AC-012 の `=` 側、DR-07)

- [x] **T-04-03-06**: 120000 バイトちょうどの差分は両方の段で受け付ける
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-25
  - Scenario: Given 一覧がちょうど 120000 バイト (3000 行以下) になるパスを index へ直接登録したコミット, When 連鎖を実行する
  - Expected: Then 終了コードは 0 で、files 出力は期待値ファイルと一致する。get-changed-files の段と filter-files の段の上限が同じ値であることを実行で確かめる (AC-012 の `=` 側、R-DIF-033、DR-13)

- [x] **T-04-03-07**: pattern が 100 行ちょうどなら受け付ける
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-26
  - Scenario: Given 変更ファイルが `a.sh`・`b.md`、`pattern` が 99 行の一致しない glob と `*.sh` の計 100 行, When 連鎖を実行する
  - Expected: Then 終了コードは 0、files 出力は `a.sh`、count 出力は `1` である (AC-018 の `=` 側)

- [x] **T-04-03-08**: pattern が 120000 バイトちょうどなら受け付ける
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-27
  - Scenario: Given 変更ファイルが `a.sh`、`pattern` が 100 行以下で合計 120000 バイトの glob (最後の行は `*.sh`), When 連鎖を実行する
  - Expected: Then 終了コードは 0、files 出力は `a.sh`、count 出力は `1` である (T-04-02-09 の `=` 側)

- [x] **T-04-03-09**: commit-count が上限の 1000 なら受け付ける
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-28
  - Scenario: Given `GITHUB_EVENT_NAME=workflow_dispatch`、`INPUT_COMMIT_COUNT="1000"`、`a.sh`・`b.sh` を持つ 3 コミットのリポジトリ, When 連鎖を実行する
  - Expected: Then 終了コードは 0 で、履歴が N+1 に満たないため before は空ツリーとなり、files 出力は HEAD の全ファイルである (T-04-02-10 の `=` 側、REQ-F-002)

- [x] **T-04-03-10**: commit-count が空文字列なら既定値 1 として扱う
  - Target: `action.yml` の step 連鎖
  - Test ID: T-GCF-RUNF-29
  - Scenario: Given `GITHUB_EVENT_NAME=workflow_dispatch`、`INPUT_COMMIT_COUNT=""`、ちょうど 2 コミットの履歴のリポジトリ, When 連鎖を実行する
  - Expected: Then 終了コードは 0 で、files 出力は `git diff --name-only --diff-filter=ACMR HEAD~1 HEAD` の結果と一致する (`_ca-resolve-sha` DD-IN-02: 明示的な空文字列は既定値 1)

---

## Coverage Check

| Source                                         | Task IDs                                                               |
| ---------------------------------------------- | ---------------------------------------------------------------------- |
| R-DIF-001 / DD-DIF-01                          | T-01-01-01..07, T-01-03-04                                             |
| R-DIF-002 / DR-14 / DD-IDX-01                  | T-01-03-01..04, T-02-04-01                                             |
| R-DIF-003 / DR-13                              | T-01-04-01, T-01-05-01, T-01-05-02, T-02-04-02, T-02-06-05, T-04-02-06 |
| R-DIF-004 / DR-06                              | T-01-01-03, T-01-01-06, T-01-06-01..04, T-02-06-04                     |
| R-DIF-010〜R-DIF-012                           | T-02-03-01..03, T-02-05-01, T-02-06-01, T-02-06-06                     |
| R-DIF-013                                      | T-02-03-04, T-02-05-02                                                 |
| R-DIF-014                                      | T-02-04-01, T-02-04-02, T-02-05-02                                     |
| R-DIF-015                                      | T-02-01-01..04, T-02-02-01, T-02-02-02, T-02-06-02, T-02-06-03         |
| R-DIF-016                                      | T-02-04-03                                                             |
| R-DIF-030 / R-DIF-032 / DR-09                  | T-03-03-04, T-03-03-05                                                 |
| R-DIF-031                                      | (テストの削除と置き換え。T-02 / T-03 のファイルそのもの)               |
| R-DIF-033                                      | T-03-04-03, T-04-03-06                                                 |
| R-ACT-001 / R-ACT-043 / DR-03                  | T-03-01-01..03, T-03-03-07                                             |
| R-ACT-002 / R-ACT-044                          | T-03-01-04                                                             |
| R-ACT-003 / R-ACT-046                          | T-03-02-06..09                                                         |
| R-ACT-010〜R-ACT-012                           | T-03-02-01                                                             |
| R-ACT-013                                      | T-03-03-03                                                             |
| R-ACT-020〜R-ACT-023 / DD-ACT-02               | T-03-02-03..05, T-03-03-06, T-03-04-01, T-03-04-02                     |
| R-ACT-030〜R-ACT-032                           | T-03-02-02, T-04-01-09                                                 |
| R-ACT-040 / R-ACT-041 / DR-12                  | T-03-04-01, T-03-04-02                                                 |
| R-ACT-042                                      | T-03-03-01                                                             |
| R-ACT-045                                      | T-03-03-02                                                             |
| AC-001                                         | T-04-01-01                                                             |
| AC-002                                         | T-04-01-02 (実イベントは CI ジョブ R-IDX-002)                          |
| AC-003                                         | T-04-01-03                                                             |
| AC-004                                         | T-04-01-04                                                             |
| AC-005                                         | T-04-02-01..03, T-04-02-10                                             |
| `_ca-resolve-sha` DD-IN-02 (空の commit-count) | T-04-03-10                                                             |
| AC-006                                         | T-04-01-06                                                             |
| AC-007                                         | T-04-01-07                                                             |
| AC-008                                         | T-04-01-08                                                             |
| AC-009                                         | T-02-01-02                                                             |
| AC-010                                         | T-02-01-03, T-04-03-01                                                 |
| AC-011                                         | T-04-02-04                                                             |
| AC-012                                         | T-01-04-01, T-04-02-05, T-04-02-06, T-04-03-05, T-04-03-06             |
| AC-013                                         | T-04-01-05, T-04-03-09                                                 |
| AC-014                                         | T-04-01-09                                                             |
| AC-015                                         | T-02-02-01, T-02-02-02                                                 |
| AC-016                                         | T-03-03-04, T-03-03-05                                                 |
| AC-017                                         | T-03-02-06..09                                                         |
| AC-018                                         | T-04-02-07, T-04-02-08, T-04-03-07                                     |
| REQ-F-006 (pattern のバイト数)                 | T-04-02-09, T-04-03-08                                                 |
| spec index §5 (横断)                           | T-04-03-02, T-04-03-03                                                 |
| REQ-C-008 (全ゼロの before)                    | T-04-03-04                                                             |
| [UNCOVERED]                                    | —                                                                      |

## Boundary Check

| 境界                                               | 受け付ける側 (`=`)                 | 拒否する側 (`<` / `>`)                             |
| -------------------------------------------------- | ---------------------------------- | -------------------------------------------------- |
| 変更ファイルの一覧のバイト数 <= 120000 (本 Action) | T-01-05-01, T-02-06-05, T-04-03-06 | `>` T-01-04-01, T-01-05-02, T-02-04-02, T-04-02-06 |
| 変更ファイルの件数 <= 3000 (filter-files)          | T-04-03-05                         | `>` T-04-02-05                                     |
| pattern の行数 <= 100 (filter-files)               | T-04-03-07                         | `>` T-04-02-08                                     |
| pattern のバイト数 <= 120000 (filter-files)        | T-04-03-08                         | `>` T-04-02-09                                     |
| commit-count >= 1 (resolve-sha)                    | T-04-01-04                         | `<` T-04-02-01                                     |
| commit-count <= 1000 (resolve-sha)                 | T-04-03-09                         | `>` T-04-02-10                                     |
| 履歴 >= N+1 で HEAD~N を使う (resolve-sha)         | T-04-01-04 (2 コミット、N=1)       | `<` T-04-01-05 (1 コミット、N=1。空ツリー)         |
| 変更ファイルの件数 >= 0 (空は成功)                 | T-01-02-01, T-02-02-01, T-04-01-08 | (下限は 0 のため `<` は無い)                       |

列は値が境界のどちら側かで分け、ケースの分類 (正常・異常・エッジケース) とは独立とする。たとえば T-01-05-02 はエッジケースだが、120001 バイトを拒否するので拒否する側に置く。

## Category Balance

| Test Target | Normal | Error | Edge | Status |
| ----------- | ------ | ----- | ---- | ------ |
| T-01        | 10     | 5     | 7    | [OK]   |
| T-02        | 6      | 7     | 8    | [OK]   |
| T-03        | 13     | 7     | 3    | [OK]   |
| T-04        | 9      | 10    | 10   | [OK]   |
