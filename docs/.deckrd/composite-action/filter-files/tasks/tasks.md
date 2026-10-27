---
title: "Implementation Tasks"
module: "composite-action/filter-files"
status: Active
created: "2026-10-27 17:18:46"
source: specifications-index.md v1.3.2, implementation.md v1.2.1
---

<!-- textlint-disable ja-technical-writing/sentence-length -->
<!-- textlint-disable ja-technical-writing/max-comma -->
<!-- markdownlint-disable no-duplicate-heading line-length -->
<!-- cspell:words dirx axxb -- >

> This document contains implementation tasks derived from specifications.
> Each task corresponds to a single unit test case (`It` block).

## Conventions

- Task ID (`T-XX-YY-ZZ`) は本書内の作業単位の ID とする。テストコードのケース名には、各タスクの `Test ID` (`T-FF-<略語>-NN`) を埋め込む。略語は `workspaces/module/module.md` の「関数一覧」に従う。
- テストコードの分類 prefix は、`[正常]` → `[Normal]`、`[異常]` → `[Error]`、`[エッジケース]` → `[Edge]` と読み替える。
- ShellSpec の `It` にはテスト ID をリテラルで書き、`Parameters` は使わない。
- エラーを検証するときは、`::error::` の接頭辞、対象、`(got: '<値>')` の部分を確かめる。問題を説明する文言は固定しない (エラーメッセージテーブルの文言を参照する。implementation.md §1.3)。R-IN-014〜R-IN-017 (`exceeds the limit of ...`) だけは、spec が定める文言も確かめる。
- 失敗系は `When call` (`set -e` が効かない文脈) で、終了コードと stderr を確かめる。
- 権限に依存するタスク (書き込み権限の無いファイル・ディレクトリ) は、root で実行すると成立しない。root の場合は `Skip if` で飛ばす。
- テストを追加したコミットで、そのテストが使う略語を `module.md` の「テスト対象の略語」表に追記する (テスト ID 検査 D)。
- UTF-8 の検査方式は T-05 (PFL) の最初のコミットで決め、T-06 (PPT) も同じ方式を使う (implementation.md §1.3 W-01)。
- テストケースを持たない implementation.md の項目は、Task ID を割り当てずに次で扱う。
  - Phase 1 開始前のベースライン全テスト実行
  - PR-A の最後 (Phase 1 の後) と PR-B の最後 (Phase 6 の後) のテスト ID 機械検査 A / C
  - Phase 5 Commit 2 の上限入力での実行時間の計測と PR への記録
  - Phase 6 Commit 2 の CI ジョブ (`test-filter-files`) の追加
- 旧 `write_multiline_output` (`ca-get-changed-files/scripts/_libs/filter.lib.sh`) と新 WMO の読み込み順のテストは、#134 で `ca-get-changed-files` へ組み込む際に追加する。本書では Test ID を割り当てない。

**関数ごとの実装上の詳細** (関数間の受け渡し形式、GTR の変換順、FF のサブシェル、EO のエラー対応、MAIN の呼び出し順) は、implementation.md §1.3 に従う。

---

## Task Summary

| Test Target                        | Scenarios | Cases | Status      |
| ---------------------------------- | --------- | ----- | ----------- |
| T-01: validate_output_file (VOF)   | 4         | 9     | not started |
| T-02: write_multiline_output (WMO) | 6         | 21    | not started |
| T-03: ff_error (FE)                | 7         | 13    | not started |
| T-04: check_line_endings (CLE)     | 3         | 9     | not started |
| T-05: parse_filelist (PFL)         | 5         | 19    | not started |
| T-06: parse_patterns (PPT)         | 3         | 12    | not started |
| T-07: check_byte_limit (CBL)       | 3         | 8     | not started |
| T-08: check_line_limit (CLL)       | 3         | 8     | not started |
| T-09: classify_patterns (CP)       | 3         | 12    | not started |
| T-10: glob_to_regex (GTR)          | 7         | 40    | not started |
| T-11: filter_files (FF)            | 3         | 14    | not started |
| T-12: emit_outputs (EO)            | 4         | 13    | not started |
| T-13: filter-files.sh (MAINF)      | 3         | 35    | not started |
| T-14: action.yml (ACT)             | 3         | 7     | not started |

---

## T-01: validate_output_file

対象: `validate_output_file <file>` (VOF)。R-OUT-020〜R-OUT-022、DR-12、DR-13。テストファイルは `_libs/__tests__/unit/validate-output-file.unit.spec.sh`。implementation.md Phase 1 Commit 1。既存の `_rs_check_output_file` に無い、通常ファイルの判定 (T-01-04-01) を含む。

### [正常] Normal Cases

#### T-01-01: 書き込める出力先

- [ ] **T-01-01-01**: 書き込み可能な既存の通常ファイルを受け付ける
  - Target: `validate_output_file`
  - Test ID: T-FF-VOF-01
  - Scenario: Given 書き込み可能な空の一時ファイル, When `validate_output_file "$file"` を呼ぶ
  - Expected: Then 終了コードは 0 で、stdout・stderr は空である (R-OUT-022)

- [ ] **T-01-01-02**: 存在しないパスは、親ディレクトリが書き込めれば受け付ける
  - Target: `validate_output_file`
  - Test ID: T-FF-VOF-02
  - Scenario: Given 書き込み可能な一時ディレクトリの下の、存在しないパス, When `validate_output_file "$dir/out"` を呼ぶ
  - Expected: Then 終了コードは 0 で、`$dir/out` は作られていない (R-OUT-021、DD-OUT-04)

### [異常] Error Cases

#### T-01-02: パスが空

- [ ] **T-01-02-01**: 空のパスは 1 を返す
  - Target: `validate_output_file`
  - Test ID: T-FF-VOF-03
  - Scenario: Given パスが `""`, When `validate_output_file ""` を呼ぶ
  - Expected: Then 終了コードは 1 である (R-OUT-020)

#### T-01-03: 書き込めない出力先

- [ ] **T-01-03-01**: ディレクトリは 2 を返す
  - Target: `validate_output_file`
  - Test ID: T-FF-VOF-04
  - Scenario: Given 既存のディレクトリのパス, When `validate_output_file "$dir"` を呼ぶ
  - Expected: Then 終了コードは 2 である (R-OUT-022)

- [ ] **T-01-03-02**: 親ディレクトリが無ければ 2 を返す
  - Target: `validate_output_file`
  - Test ID: T-FF-VOF-05
  - Scenario: Given `$tmp/no-such-dir/out` (親ディレクトリが存在しない), When `validate_output_file` を呼ぶ
  - Expected: Then 終了コードは 2 で、親ディレクトリも作られていない (R-OUT-021)

- [ ] **T-01-03-03**: 書き込み権限の無い既存ファイルは 2 を返す
  - Target: `validate_output_file`
  - Test ID: T-FF-VOF-06
  - Scenario: Given `chmod 444` した既存ファイル, When `validate_output_file "$file"` を呼ぶ
  - Expected: Then 終了コードは 2 である (R-OUT-022)

- [ ] **T-01-03-04**: 親ディレクトリが書き込めなければ 2 を返す
  - Target: `validate_output_file`
  - Test ID: T-FF-VOF-07
  - Scenario: Given `chmod 555` したディレクトリの下の、存在しないパス, When `validate_output_file` を呼ぶ
  - Expected: Then 終了コードは 2 である (R-OUT-021)

### [エッジケース] Edge Cases

#### T-01-04: 通常ファイル以外と出力の有無

- [ ] **T-01-04-01**: FIFO は 2 を返す
  - Target: `validate_output_file`
  - Test ID: T-FF-VOF-08
  - Scenario: Given `mkfifo` で作った FIFO のパス, When `validate_output_file "$fifo"` を呼ぶ
  - Expected: Then 終了コードは 2 で、呼び出しはブロックしない (R-OUT-022)

- [ ] **T-01-04-02**: 失敗しても何も出力しない
  - Target: `validate_output_file`
  - Test ID: T-FF-VOF-09
  - Scenario: Given 既存のディレクトリのパス, When `validate_output_file "$dir"` を呼ぶ
  - Expected: Then stdout・stderr はともに空である (DR-13)

---

## T-02: write_multiline_output

対象: `write_multiline_output <file> <key> <value>` (WMO)。R-OUT-010〜R-OUT-014、DD-OUT-01〜DD-OUT-06、DR-07、DR-13。テストファイルは `_libs/__tests__/unit/write-multiline-output.unit.spec.sh`。implementation.md Phase 1 Commit 2。特記の無い限り、出力先は空の一時ファイル、キーは `files` とする。

### [正常] Normal Cases

#### T-02-01: 複数行出力を書く

- [ ] **T-02-01-01**: 1 行の値を区切り文字で囲んで書く
  - Target: `write_multiline_output`
  - Test ID: T-FF-WMO-01
  - Scenario: Given 値が `a.sh`, When `write_multiline_output "$file" files "a.sh"` を呼ぶ
  - Expected: Then 出力先の内容は `files<<EOF`、`a.sh`、`EOF` の 3 行である (R-OUT-013)

- [ ] **T-02-01-02**: 複数行の値を 1 行ずつ書く
  - Target: `write_multiline_output`
  - Test ID: T-FF-WMO-02
  - Scenario: Given 値が `$'a.sh\nb.sh'`, When `write_multiline_output` を呼ぶ
  - Expected: Then 出力先の内容は `files<<EOF`、`a.sh`、`b.sh`、`EOF` の 4 行である (R-OUT-013)

- [ ] **T-02-01-03**: 既存の内容を残して追記する
  - Target: `write_multiline_output`
  - Test ID: T-FF-WMO-03
  - Scenario: Given 出力先が `existing=1` の 1 行を持つ, When 値 `a.sh` で `write_multiline_output` を呼ぶ
  - Expected: Then 出力先の 1 行目は `existing=1` のままで、2 行目が `files<<EOF` である

- [ ] **T-02-01-04**: 成功時は 0 を返し、何も出力しない
  - Target: `write_multiline_output`
  - Test ID: T-FF-WMO-04
  - Scenario: Given 値が `a.sh`, When `write_multiline_output` を呼ぶ
  - Expected: Then 終了コードは 0 で、stdout・stderr は空である (DR-13)

#### T-02-02: 受け付けるキーの形式

- [ ] **T-02-02-01**: `-` を含むキーを受け付ける
  - Target: `write_multiline_output`
  - Test ID: T-FF-WMO-05
  - Scenario: Given キーが `my-key`, When `write_multiline_output "$file" my-key "a.sh"` を呼ぶ
  - Expected: Then 終了コードは 0 で、出力先の 1 行目は `my-key<<EOF` である (DD-OUT-06)

- [ ] **T-02-02-02**: `_` で始まるキーを受け付ける
  - Target: `write_multiline_output`
  - Test ID: T-FF-WMO-06
  - Scenario: Given キーが `_k1`, When `write_multiline_output "$file" _k1 "a.sh"` を呼ぶ
  - Expected: Then 終了コードは 0 で、出力先の 1 行目は `_k1<<EOF` である (DD-OUT-06)

### [異常] Error Cases

#### T-02-03: 引数不正 (1 を返し、何も書かない)

- [ ] **T-02-03-01**: 出力先が空
  - Target: `write_multiline_output`
  - Test ID: T-FF-WMO-07
  - Scenario: Given 出力先が `""`, When `write_multiline_output "" files "a.sh"` を呼ぶ
  - Expected: Then 終了コードは 1 で、stdout・stderr は空である (R-OUT-010)

- [ ] **T-02-03-02**: キーに `=` を含む
  - Target: `write_multiline_output`
  - Test ID: T-FF-WMO-08
  - Scenario: Given キーが `a=b`, When `write_multiline_output "$file" "a=b" "a.sh"` を呼ぶ
  - Expected: Then 終了コードは 1 で、出力先は空のままである (R-OUT-010、DD-OUT-06)

- [ ] **T-02-03-03**: キーに `<<` を含む
  - Target: `write_multiline_output`
  - Test ID: T-FF-WMO-09
  - Scenario: Given キーが `a<<b`, When `write_multiline_output "$file" "a<<b" "a.sh"` を呼ぶ
  - Expected: Then 終了コードは 1 で、出力先は空のままである (R-OUT-010)

- [ ] **T-02-03-04**: キーが数字で始まる
  - Target: `write_multiline_output`
  - Test ID: T-FF-WMO-10
  - Scenario: Given キーが `1abc`, When `write_multiline_output "$file" 1abc "a.sh"` を呼ぶ
  - Expected: Then 終了コードは 1 で、出力先は空のままである (R-OUT-010)

- [ ] **T-02-03-05**: キーが空
  - Target: `write_multiline_output`
  - Test ID: T-FF-WMO-11
  - Scenario: Given キーが `""`, When `write_multiline_output "$file" "" "a.sh"` を呼ぶ
  - Expected: Then 終了コードは 1 で、出力先は空のままである (R-OUT-010)

- [ ] **T-02-03-06**: 値に CR を含む
  - Target: `write_multiline_output`
  - Test ID: T-FF-WMO-12
  - Scenario: Given 値が `$'a\rb.sh'`, When `write_multiline_output "$file" files "$value"` を呼ぶ
  - Expected: Then 終了コードは 1 で、出力先は空のままである (R-OUT-010)

#### T-02-04: 書き込みの失敗

- [ ] **T-02-04-01**: 出力先がディレクトリなら 2 を返す
  - Target: `write_multiline_output`
  - Test ID: T-FF-WMO-13
  - Scenario: Given 出力先が既存のディレクトリ, When `write_multiline_output "$dir" files "a.sh"` を呼ぶ
  - Expected: Then 終了コードは 2 で、stdout・stderr は空である (R-OUT-014)

### [エッジケース] Edge Cases

#### T-02-05: 区切り文字の選択

- [ ] **T-02-05-01**: 値に `EOF` の行があれば `EOF_1` を使う
  - Target: `write_multiline_output`
  - Test ID: T-FF-WMO-14
  - Scenario: Given 値が `$'EOF\na.sh'`, When `write_multiline_output` を呼ぶ
  - Expected: Then 出力先の 1 行目は `files<<EOF_1`、最終行は `EOF_1` である (R-OUT-011、AC-010)

- [ ] **T-02-05-02**: `EOF` と `EOF_1` の行があれば `EOF_2` を使う
  - Target: `write_multiline_output`
  - Test ID: T-FF-WMO-15
  - Scenario: Given 値が `$'EOF\nEOF_1'`, When `write_multiline_output` を呼ぶ
  - Expected: Then 出力先の 1 行目は `files<<EOF_2` である (R-OUT-011)

- [ ] **T-02-05-03**: `EOF_1` の行だけなら `EOF` を使う
  - Target: `write_multiline_output`
  - Test ID: T-FF-WMO-16
  - Scenario: Given 値が `EOF_1`, When `write_multiline_output` を呼ぶ
  - Expected: Then 出力先の 1 行目は `files<<EOF` である (DD-OUT-01)

- [ ] **T-02-05-04**: 行の一部に `EOF` を含むだけなら `EOF` を使う
  - Target: `write_multiline_output`
  - Test ID: T-FF-WMO-17
  - Scenario: Given 値が `xEOF`, When `write_multiline_output` を呼ぶ
  - Expected: Then 出力先の 1 行目は `files<<EOF` である (行全体の一致だけを衝突とする)

- [ ] **T-02-05-05**: 末尾に空白の付いた `EOF` は衝突にしない
  - Target: `write_multiline_output`
  - Test ID: T-FF-WMO-18
  - Scenario: Given 値が `'EOF '` (末尾にスペース), When `write_multiline_output` を呼ぶ
  - Expected: Then 出力先の 1 行目は `files<<EOF` で、2 行目は `EOF ` のまま書かれる

#### T-02-06: 値の形

- [ ] **T-02-06-01**: 空の値は内容の行を書かない
  - Target: `write_multiline_output`
  - Test ID: T-FF-WMO-19
  - Scenario: Given 値が `""`, When `write_multiline_output "$file" files ""` を呼ぶ
  - Expected: Then 終了コードは 0 で、出力先の内容は `files<<EOF`、`EOF` の 2 行だけである (R-OUT-012、DD-OUT-02)

- [ ] **T-02-06-02**: 値の末尾の LF は空行を作らない
  - Target: `write_multiline_output`
  - Test ID: T-FF-WMO-20
  - Scenario: Given 値が `$'a\nb\n'`, When `write_multiline_output` を呼ぶ
  - Expected: Then 出力先の内容は、値 `$'a\nb'` で書いた場合と同じ 4 行である (R-OUT-013、DD-OUT-05)

- [ ] **T-02-06-03**: `<<` を含む行をそのまま書く
  - Target: `write_multiline_output`
  - Test ID: T-FF-WMO-21
  - Scenario: Given 値が `a<<b.sh`, When `write_multiline_output` を呼ぶ
  - Expected: Then 出力先の 2 行目は `a<<b.sh` で、区切り文字は `EOF` である

---

## T-03: ff_error

対象: `ff_error <target> <problem> [<value>]` (FE) と、`filter-files.lib.sh` のロードガード・共有ライブラリの読み込み。specifications-index.md §3.3、DR-15、implementation.md Phase 2 Commit 1 (ロードガードのテストを FE に含める)。テストファイルは `_ca-filter-files/scripts/_libs/__tests__/unit/filter-files.unit.spec.sh` の FE グループ。ロードガードの読み込みは新しい bash プロセスで行い、ガードの状態を例の間で持ち越さない。

### [正常] Normal Cases

#### T-03-01: 値を渡した場合の通常の形式

- [ ] **T-03-01-01**: 通常の形式で stderr に 1 行出す
  - Target: `ff_error`
  - Test ID: T-FF-FE-01
  - Scenario: Given target `files`、problem `bad line`、value `x`, When `ff_error files "bad line" x` を呼ぶ
  - Expected: Then stderr は `::error::files: bad line (got: 'x')` の 1 行である

- [ ] **T-03-01-02**: stdout には何も出さない
  - Target: `ff_error`
  - Test ID: T-FF-FE-02
  - Scenario: Given target `files`、problem `bad line`、value `x`, When `ff_error files "bad line" x` を呼ぶ
  - Expected: Then stdout は空である

- [ ] **T-03-01-03**: 空文字列の値は通常の形式で出す
  - Target: `ff_error`
  - Test ID: T-FF-FE-03
  - Scenario: Given value が `""` (引数として渡す), When `ff_error patterns p ""` を呼ぶ
  - Expected: Then stderr は `(got: '')` で終わる 1 行である

#### T-03-02: 値を省略した場合の空の形式

- [ ] **T-03-02-01**: 空の形式で出す
  - Target: `ff_error`
  - Test ID: T-FF-FE-04
  - Scenario: Given 値の引数を省略, When `ff_error GITHUB_OUTPUT empty` を呼ぶ
  - Expected: Then stderr は `::error::GITHUB_OUTPUT: value must not be empty` の 1 行である

#### T-03-03: filter-files.lib.sh を読み込む

- [ ] **T-03-03-01**: 1 回目の読み込みでガード変数が設定され、依存関数がそろう
  - Target: `filter-files.lib.sh`
  - Test ID: T-FF-FE-05
  - Scenario: Given 新しいシェルでガード変数 (`*_LIB_LOADED`) が未設定, When `filter-files.lib.sh` を source する
  - Expected: Then 終了コードは 0 で、ガード変数が設定され、`ff_error`・`validate_output_file`・`write_multiline_output`・`write_output` が定義されている

- [ ] **T-03-03-02**: 2 回目の読み込みでもエラーにならない
  - Target: `filter-files.lib.sh`
  - Test ID: T-FF-FE-06
  - Scenario: Given `filter-files.lib.sh` を source 済み, When もう一度 source する
  - Expected: Then 終了コードは 0 で、stderr は空である

### [異常] Error Cases

#### T-03-04: ワークフローコマンドの注入

- [ ] **T-03-04-01**: LF とコマンドを含む値を 1 行に収める
  - Target: `ff_error`
  - Test ID: T-FF-FE-07
  - Scenario: Given value が `$'x\n::add-mask::secret'`, When `ff_error files bad "$value"` を呼ぶ
  - Expected: Then stderr は 1 行だけで、`::add-mask::` で始まる行は無い

#### T-03-05: 共有ライブラリを読み込めない

- [ ] **T-03-05-01**: output.lib.sh が見つからなければ読み込みを失敗させる
  - Target: `filter-files.lib.sh`
  - Test ID: T-FF-FE-08
  - Scenario: Given `filter-files.lib.sh` だけを、相対パスの `output.lib.sh` が存在しない一時ディレクトリに複製する, When 複製を source する
  - Expected: Then 終了コードは 0 以外である (`declare -F` による依存関数の確認、fail-first)

### [エッジケース] Edge Cases

#### T-03-06: 値のエンコード

- [ ] **T-03-06-01**: `%` を `%25` にする
  - Target: `ff_error`
  - Test ID: T-FF-FE-09
  - Scenario: Given value が `a%b`, When `ff_error t p "a%b"` を呼ぶ
  - Expected: Then stderr に `(got: 'a%25b')` が含まれる

- [ ] **T-03-06-02**: CR を `%0D` にする
  - Target: `ff_error`
  - Test ID: T-FF-FE-10
  - Scenario: Given value が `$'a\rb'`, When `ff_error t p "$value"` を呼ぶ
  - Expected: Then stderr に `(got: 'a%0Db')` が含まれる

- [ ] **T-03-06-03**: LF を `%0A` にする
  - Target: `ff_error`
  - Test ID: T-FF-FE-11
  - Scenario: Given value が `$'a\nb'`, When `ff_error t p "$value"` を呼ぶ
  - Expected: Then stderr に `(got: 'a%0Ab')` が含まれる

- [ ] **T-03-06-04**: 既にエンコード済みに見える値は `%` から先に置き換える
  - Target: `ff_error`
  - Test ID: T-FF-FE-12
  - Scenario: Given value が `%0A` (文字列), When `ff_error t p "%0A"` を呼ぶ
  - Expected: Then stderr に `(got: '%250A')` が含まれる

#### T-03-07: ガード変数が設定済みの状態で読み込む

- [ ] **T-03-07-01**: ガード変数が設定済みなら関数を定義せずに戻る
  - Target: `filter-files.lib.sh`
  - Test ID: T-FF-FE-13
  - Scenario: Given 新しいシェルでガード変数を設定済み, When `filter-files.lib.sh` を source する
  - Expected: Then 終了コードは 0 で、`ff_error` は定義されていない

---

## T-04: check_line_endings

対象: `check_line_endings <target> <text>` (CLE)。R-IN-011、DD-IN-07。テストファイルは `filter-files.unit.spec.sh` の CLE グループ。implementation.md Phase 3 Commit 1。

### [正常] Normal Cases

#### T-04-01: LF を伴わない CR が無い

- [ ] **T-04-01-01**: LF だけの改行を受け付ける
  - Target: `check_line_endings`
  - Test ID: T-FF-CLE-01
  - Scenario: Given text が `$'a.sh\nb.sh'`, When `check_line_endings files "$text"` を呼ぶ
  - Expected: Then 終了コードは 0 で、stderr は空である

- [ ] **T-04-01-02**: CRLF の改行を受け付ける
  - Target: `check_line_endings`
  - Test ID: T-FF-CLE-02
  - Scenario: Given text が `$'a.sh\r\nb.sh\r\n'`, When `check_line_endings files "$text"` を呼ぶ
  - Expected: Then 終了コードは 0 である (CRLF を検査の対象外とする)

- [ ] **T-04-01-03**: 空文字列を受け付ける
  - Target: `check_line_endings`
  - Test ID: T-FF-CLE-03
  - Scenario: Given text が `""`, When `check_line_endings files ""` を呼ぶ
  - Expected: Then 終了コードは 0 である

### [異常] Error Cases

#### T-04-02: LF を伴わない CR を含む

- [ ] **T-04-02-01**: 行末の CR をエラーにする
  - Target: `check_line_endings`
  - Test ID: T-FF-CLE-04
  - Scenario: Given text が `$'a.sh\r'`, When `check_line_endings files "$text"` を呼ぶ
  - Expected: Then 終了コードは 1 で、stderr は `::error::files:` で始まり `(got: 'a.sh%0D')` を含む 1 行である

- [ ] **T-04-02-02**: 行の途中の CR をエラーにする
  - Target: `check_line_endings`
  - Test ID: T-FF-CLE-05
  - Scenario: Given text が `$'a\rb.sh'`, When `check_line_endings files "$text"` を呼ぶ
  - Expected: Then 終了コードは 1 で、stderr に `(got: 'a%0Db.sh')` が含まれる

- [ ] **T-04-02-03**: 対象が patterns ならその名前で報告する
  - Target: `check_line_endings`
  - Test ID: T-FF-CLE-06
  - Scenario: Given text が `$'*.sh\r'`, When `check_line_endings patterns "$text"` を呼ぶ
  - Expected: Then 終了コードは 1 で、stderr は `::error::patterns:` で始まる

### [エッジケース] Edge Cases

#### T-04-03: 報告する行

- [ ] **T-04-03-01**: CRLF の行の後にある CR の行を報告する
  - Target: `check_line_endings`
  - Test ID: T-FF-CLE-07
  - Scenario: Given text が `$'a.sh\r\nb\rc.sh'`, When `check_line_endings files "$text"` を呼ぶ
  - Expected: Then stderr に `(got: 'b%0Dc.sh')` が含まれ、`a.sh` は含まれない

- [ ] **T-04-03-02**: CR を含む行が複数あっても最初の 1 行だけを報告する
  - Target: `check_line_endings`
  - Test ID: T-FF-CLE-08
  - Scenario: Given text が `$'a\rx\nb\ry'`, When `check_line_endings files "$text"` を呼ぶ
  - Expected: Then stderr は 1 行だけで、`(got: 'a%0Dx')` を含む (DD-IN-05)

- [ ] **T-04-03-03**: CRLF の直前に余分な CR があればエラーにする
  - Target: `check_line_endings`
  - Test ID: T-FF-CLE-09
  - Scenario: Given text が `$'a\r\r\nb'`, When `check_line_endings files "$text"` を呼ぶ
  - Expected: Then 終了コードは 1 である

---

## T-05: parse_filelist

対象: `parse_filelist <text>` (PFL) と内部関数 `_ff_split_lines`。R-IN-013、R-IN-001、R-IN-010、R-IN-012、R-IN-003、DD-IN-09、DR-08、DR-14。テストファイルは `filter-files.unit.spec.sh` の PFL グループ。implementation.md Phase 3 Commit 2。stdout は LF 区切りの行 (末尾に LF を付けない)。

### [正常] Normal Cases

#### T-05-01: 行に分割する

- [ ] **T-05-01-01**: LF で区切った 2 行をそのまま返す
  - Target: `parse_filelist`
  - Test ID: T-FF-PFL-01
  - Scenario: Given text が `$'a.sh\nb.sh'`, When `parse_filelist "$text"` を呼ぶ
  - Expected: Then 終了コードは 0 で、stdout は `$'a.sh\nb.sh'` である (R-IN-001)

- [ ] **T-05-01-02**: CRLF を LF に変換する
  - Target: `parse_filelist`
  - Test ID: T-FF-PFL-02
  - Scenario: Given text が `$'a.sh\r\nb.sh\r\n'`, When `parse_filelist "$text"` を呼ぶ
  - Expected: Then stdout は `$'a.sh\nb.sh'` で、CR を含まない (R-IN-013)

- [ ] **T-05-01-03**: 末尾の LF による空行を出さない
  - Target: `parse_filelist`
  - Test ID: T-FF-PFL-03
  - Scenario: Given text が `$'a.sh\n'`, When `parse_filelist "$text"` を呼ぶ
  - Expected: Then stdout は `a.sh` である (R-IN-003)

- [ ] **T-05-01-04**: 長さ 0 の行を捨てる
  - Target: `parse_filelist`
  - Test ID: T-FF-PFL-04
  - Scenario: Given text が `$'a.sh\n\nb.sh'`, When `parse_filelist "$text"` を呼ぶ
  - Expected: Then stdout は `$'a.sh\nb.sh'` である (R-IN-003)

- [ ] **T-05-01-05**: 同じパスの重複を残す
  - Target: `parse_filelist`
  - Test ID: T-FF-PFL-05
  - Scenario: Given text が `$'a.sh\na.sh'`, When `parse_filelist "$text"` を呼ぶ
  - Expected: Then stdout は `$'a.sh\na.sh'` である

#### T-05-02: 行を変更しない

- [ ] **T-05-02-01**: 先頭の空白を残す
  - Target: `parse_filelist`
  - Test ID: T-FF-PFL-06
  - Scenario: Given text が `'  a.sh'`, When `parse_filelist "$text"` を呼ぶ
  - Expected: Then stdout は `'  a.sh'` である (DD-IN-09)

- [ ] **T-05-02-02**: 末尾のタブを残す
  - Target: `parse_filelist`
  - Test ID: T-FF-PFL-07
  - Scenario: Given text が `$'a.sh\t'`, When `parse_filelist "$text"` を呼ぶ
  - Expected: Then stdout は `$'a.sh\t'` である (DD-IN-09)

- [ ] **T-05-02-03**: 空白だけの行を 1 行のパスとして残す
  - Target: `parse_filelist`
  - Test ID: T-FF-PFL-08
  - Scenario: Given text が `'  '` (スペース 2 個), When `parse_filelist "$text"` を呼ぶ
  - Expected: Then stdout は `'  '` である (R-IN-003)

- [ ] **T-05-02-04**: 途中の空白を残す
  - Target: `parse_filelist`
  - Test ID: T-FF-PFL-09
  - Scenario: Given text が `'my file.sh'`, When `parse_filelist "$text"` を呼ぶ
  - Expected: Then stdout は `'my file.sh'` である

- [ ] **T-05-02-05**: `!` で始まる行をパスとして残す
  - Target: `parse_filelist`
  - Test ID: T-FF-PFL-10
  - Scenario: Given text が `'!a.sh'`, When `parse_filelist "$text"` を呼ぶ
  - Expected: Then stdout は `'!a.sh'` である (`!` の意味は patterns だけ)

### [異常] Error Cases

#### T-05-03: 不正なファイル行

- [ ] **T-05-03-01**: UTF-8 として不正な行をエラーにする
  - Target: `parse_filelist`
  - Test ID: T-FF-PFL-11
  - Scenario: Given text が `$'a.sh\n\xff.sh'`, When `parse_filelist "$text"` を呼ぶ
  - Expected: Then 終了コードは 1 で、stderr は `::error::files:` で始まる 1 行、stdout は空である (R-IN-010)

- [ ] **T-05-03-02**: ダブルクオートを含む行をエラーにする
  - Target: `parse_filelist`
  - Test ID: T-FF-PFL-12
  - Scenario: Given text が `'"b.sh"'`, When `parse_filelist "$text"` を呼ぶ
  - Expected: Then 終了コードは 1 で、stderr は `::error::files:` で始まり `(got: '"b.sh"')` を含む (R-IN-012)

- [ ] **T-05-03-03**: git の引用表記のままの行をエラーにする
  - Target: `parse_filelist`
  - Test ID: T-FF-PFL-13
  - Scenario: Given text が `'"a\nb.sh"'` (バックスラッシュと n の文字列), When `parse_filelist "$text"` を呼ぶ
  - Expected: Then 終了コードは 1 で、stderr は `::error::files:` で始まる (R-IN-012、DD-IN-08)

#### T-05-04: 報告する 1 件の順序 (DR-14)

- [ ] **T-05-04-01**: 前の行のダブルクオートを、後の行の不正な UTF-8 より先に報告する
  - Target: `parse_filelist`
  - Test ID: T-FF-PFL-14
  - Scenario: Given text が `$'"a.sh"\n\xff.sh'`, When `parse_filelist "$text"` を呼ぶ
  - Expected: Then stderr は 1 行で、`(got: '"a.sh"')` を含む

- [ ] **T-05-04-02**: 前の行の不正な UTF-8 を、後の行のダブルクオートより先に報告する
  - Target: `parse_filelist`
  - Test ID: T-FF-PFL-15
  - Scenario: Given text が `$'\xff.sh\n"a.sh"'`, When `parse_filelist "$text"` を呼ぶ
  - Expected: Then stderr は 1 行で、`"a.sh"` を含まない (UTF-8 のエラー)

- [ ] **T-05-04-03**: 同じ行に両方あれば UTF-8 のエラーを報告する
  - Target: `parse_filelist`
  - Test ID: T-FF-PFL-16
  - Scenario: Given text が `$'"\xff.sh"'`, When `parse_filelist "$text"` を呼ぶ
  - Expected: Then stderr は 1 行で、UTF-8 のエラー (テーブルの R-IN-010 の文言) である

### [エッジケース] Edge Cases

#### T-05-05: 空の入力と非 ASCII

- [ ] **T-05-05-01**: 空文字列は 0 行
  - Target: `parse_filelist`
  - Test ID: T-FF-PFL-17
  - Scenario: Given text が `""`, When `parse_filelist ""` を呼ぶ
  - Expected: Then 終了コードは 0 で、stdout は空である

- [ ] **T-05-05-02**: 改行だけの入力は 0 行
  - Target: `parse_filelist`
  - Test ID: T-FF-PFL-18
  - Scenario: Given text が `$'\n\n'`, When `parse_filelist "$text"` を呼ぶ
  - Expected: Then 終了コードは 0 で、stdout は空である

- [ ] **T-05-05-03**: UTF-8 として正しい非 ASCII の行を残す
  - Target: `parse_filelist`
  - Test ID: T-FF-PFL-19
  - Scenario: Given text が `あ.sh`, When `parse_filelist "$text"` を呼ぶ
  - Expected: Then 終了コードは 0 で、stdout は `あ.sh` である

---

## T-06: parse_patterns

対象: `parse_patterns <text>` (PPT)。R-IN-013、R-IN-001、R-IN-010、R-IN-002、R-IN-003、R-IN-008、DR-08、DR-11。テストファイルは `filter-files.unit.spec.sh` の PPT グループ。implementation.md Phase 3 Commit 3。

### [正常] Normal Cases

#### T-06-01: 行に分割し、両端の空白を除く

- [ ] **T-06-01-01**: LF で区切った 2 行をそのまま返す
  - Target: `parse_patterns`
  - Test ID: T-FF-PPT-01
  - Scenario: Given text が `$'*.sh\n!*.md'`, When `parse_patterns "$text"` を呼ぶ
  - Expected: Then 終了コードは 0 で、stdout は `$'*.sh\n!*.md'` である

- [ ] **T-06-01-02**: 両端のスペースを除く
  - Target: `parse_patterns`
  - Test ID: T-FF-PPT-02
  - Scenario: Given text が `'  *.sh  '`, When `parse_patterns "$text"` を呼ぶ
  - Expected: Then stdout は `*.sh` である (R-IN-002)

- [ ] **T-06-01-03**: 末尾のタブを除く
  - Target: `parse_patterns`
  - Test ID: T-FF-PPT-03
  - Scenario: Given text が `$'*.sh\t'`, When `parse_patterns "$text"` を呼ぶ
  - Expected: Then stdout は `*.sh` である (R-IN-002)

- [ ] **T-06-01-04**: 空白だけの行を捨てる
  - Target: `parse_patterns`
  - Test ID: T-FF-PPT-04
  - Scenario: Given text が `$'*.sh\n\t'`, When `parse_patterns "$text"` を呼ぶ
  - Expected: Then stdout は `*.sh` である (R-IN-003)

- [ ] **T-06-01-05**: CRLF を LF に変換する
  - Target: `parse_patterns`
  - Test ID: T-FF-PPT-05
  - Scenario: Given text が `$'*.sh\r\n'`, When `parse_patterns "$text"` を呼ぶ
  - Expected: Then stdout は `*.sh` で、CR を含まない (R-IN-013)

- [ ] **T-06-01-06**: ダブルクオートを文字として残す
  - Target: `parse_patterns`
  - Test ID: T-FF-PPT-06
  - Scenario: Given text が `'"b.sh"'`, When `parse_patterns "$text"` を呼ぶ
  - Expected: Then 終了コードは 0 で、stdout は `'"b.sh"'` である (R-IN-008)

- [ ] **T-06-01-07**: 途中の空白を残す
  - Target: `parse_patterns`
  - Test ID: T-FF-PPT-07
  - Scenario: Given text が `'a b.sh'`, When `parse_patterns "$text"` を呼ぶ
  - Expected: Then stdout は `'a b.sh'` である (R-IN-002)

### [異常] Error Cases

#### T-06-02: 不正なパターン行

- [ ] **T-06-02-01**: UTF-8 として不正な行をエラーにする
  - Target: `parse_patterns`
  - Test ID: T-FF-PPT-08
  - Scenario: Given text が `$'\xff.sh'`, When `parse_patterns "$text"` を呼ぶ
  - Expected: Then 終了コードは 1 で、stderr は `::error::patterns:` で始まる 1 行、stdout は空である (R-IN-010)

### [エッジケース] Edge Cases

#### T-06-03: 境界の入力

- [ ] **T-06-03-01**: 空文字列は 0 行
  - Target: `parse_patterns`
  - Test ID: T-FF-PPT-09
  - Scenario: Given text が `""`, When `parse_patterns ""` を呼ぶ
  - Expected: Then 終了コードは 0 で、stdout は空である (R-IN-007 の前提)

- [ ] **T-06-03-02**: 空白で始まる `!` は除去後に `!` だけになる
  - Target: `parse_patterns`
  - Test ID: T-FF-PPT-10
  - Scenario: Given text が `'  !'`, When `parse_patterns "$text"` を呼ぶ
  - Expected: Then 終了コードは 0 で、stdout は `!` である (エラーを出すのは CP)

- [ ] **T-06-03-03**: `!` の後の空白は除去しない
  - Target: `parse_patterns`
  - Test ID: T-FF-PPT-11
  - Scenario: Given text が `'!  a.sh'`, When `parse_patterns "$text"` を呼ぶ
  - Expected: Then stdout は `'!  a.sh'` である (DD-IN-02)

- [ ] **T-06-03-04**: 2 行目の不正な UTF-8 を報告する
  - Target: `parse_patterns`
  - Test ID: T-FF-PPT-12
  - Scenario: Given text が `$'*.sh\nx\xff'`, When `parse_patterns "$text"` を呼ぶ
  - Expected: Then 終了コードは 1 で、stderr は 1 行、`*.sh` を含まない

---

## T-07: check_byte_limit

対象: `check_byte_limit <target> <text> <max>` (CBL) と定数 `FF_MAX_FILES_BYTES`・`FF_MAX_PATTERNS_BYTES`。R-IN-016、R-IN-017、DD-IN-11、DR-16。テストファイルは `filter-files.unit.spec.sh` の CBL グループ。implementation.md Phase 3 Commit 4。

### [正常] Normal Cases

#### T-07-01: 上限以内

- [ ] **T-07-01-01**: バイト数の上限の定数は 120000
  - Target: `FF_MAX_FILES_BYTES` / `FF_MAX_PATTERNS_BYTES`
  - Test ID: T-FF-CBL-01
  - Scenario: Given `filter-files.lib.sh` を source 済み, When 2 つの定数を参照する
  - Expected: Then どちらも `120000` で、readonly である

- [ ] **T-07-01-02**: 上限ちょうどを受け付ける
  - Target: `check_byte_limit`
  - Test ID: T-FF-CBL-02
  - Scenario: Given text が ASCII 120000 バイト, When `check_byte_limit files "$text" "$FF_MAX_FILES_BYTES"` を呼ぶ
  - Expected: Then 終了コードは 0 で、stderr は空である

- [ ] **T-07-01-03**: 小さい値を受け付ける
  - Target: `check_byte_limit`
  - Test ID: T-FF-CBL-03
  - Scenario: Given text が `a.sh`, When `check_byte_limit files "$text" "$FF_MAX_FILES_BYTES"` を呼ぶ
  - Expected: Then 終了コードは 0 である

### [異常] Error Cases

#### T-07-02: 上限を超える

- [ ] **T-07-02-01**: files が 120001 バイトならエラー
  - Target: `check_byte_limit`
  - Test ID: T-FF-CBL-04
  - Scenario: Given text が ASCII 120001 バイト, When `check_byte_limit files "$text" "$FF_MAX_FILES_BYTES"` を呼ぶ
  - Expected: Then 終了コードは 1 で、stderr は `::error::files: exceeds the limit of 120000 bytes (got: '120001')` である (R-IN-016)

- [ ] **T-07-02-02**: patterns が 120001 バイトならエラー
  - Target: `check_byte_limit`
  - Test ID: T-FF-CBL-05
  - Scenario: Given text が ASCII 120001 バイト, When `check_byte_limit patterns "$text" "$FF_MAX_PATTERNS_BYTES"` を呼ぶ
  - Expected: Then 終了コードは 1 で、stderr は `::error::patterns: exceeds the limit of 120000 bytes` で始まる (R-IN-017)

### [エッジケース] Edge Cases

#### T-07-03: 文字数ではなくバイト数で数える

- [ ] **T-07-03-01**: 日本語 40001 字 (120003 バイト) はエラー
  - Target: `check_byte_limit`
  - Test ID: T-FF-CBL-06
  - Scenario: Given 呼び出し元が `LC_ALL=C.UTF-8` で、text が `あ` の 40001 回の繰り返し, When `check_byte_limit files "$text" "$FF_MAX_FILES_BYTES"` を呼ぶ
  - Expected: Then 終了コードは 1 で、stderr に `(got: '120003')` が含まれる (DD-IN-11)

- [ ] **T-07-03-02**: 日本語 40000 字 (120000 バイト) は受け付ける
  - Target: `check_byte_limit`
  - Test ID: T-FF-CBL-07
  - Scenario: Given 呼び出し元が `LC_ALL=C.UTF-8` で、text が `あ` の 40000 回の繰り返し, When `check_byte_limit files "$text" "$FF_MAX_FILES_BYTES"` を呼ぶ
  - Expected: Then 終了コードは 0 である

- [ ] **T-07-03-03**: 呼び出し元のロケールを変えない
  - Target: `check_byte_limit`
  - Test ID: T-FF-CBL-08
  - Scenario: Given 呼び出し元が `LC_ALL=C.UTF-8`, When `check_byte_limit files a.sh "$FF_MAX_FILES_BYTES"` を呼んだ後に `LC_ALL` を参照する
  - Expected: Then `LC_ALL` は `C.UTF-8` のままである

---

## T-08: check_line_limit

対象: `check_line_limit <target> <lines> <max>` (CLL) と定数 `FF_MAX_FILES`・`FF_MAX_PATTERNS`。R-IN-014、R-IN-015、DD-IN-10、DR-16。テストファイルは `filter-files.unit.spec.sh` の CLL グループ。implementation.md Phase 3 Commit 4。`<lines>` は PFL / PPT の結果の形 (LF 区切り、末尾に LF なし、空行なし)。

### [正常] Normal Cases

#### T-08-01: 上限以内

- [ ] **T-08-01-01**: 件数の上限の定数は 3000 と 1000
  - Target: `FF_MAX_FILES` / `FF_MAX_PATTERNS`
  - Test ID: T-FF-CLL-01
  - Scenario: Given `filter-files.lib.sh` を source 済み, When 2 つの定数を参照する
  - Expected: Then `FF_MAX_FILES` は `3000`、`FF_MAX_PATTERNS` は `1000` で、readonly である

- [ ] **T-08-01-02**: files 3000 行を受け付ける
  - Target: `check_line_limit`
  - Test ID: T-FF-CLL-02
  - Scenario: Given lines が 3000 行, When `check_line_limit files "$lines" "$FF_MAX_FILES"` を呼ぶ
  - Expected: Then 終了コードは 0 で、stderr は空である

- [ ] **T-08-01-03**: patterns 1000 行を受け付ける
  - Target: `check_line_limit`
  - Test ID: T-FF-CLL-03
  - Scenario: Given lines が 1000 行, When `check_line_limit patterns "$lines" "$FF_MAX_PATTERNS"` を呼ぶ
  - Expected: Then 終了コードは 0 である

### [異常] Error Cases

#### T-08-02: 上限を超える

- [ ] **T-08-02-01**: files 3001 行はエラー
  - Target: `check_line_limit`
  - Test ID: T-FF-CLL-04
  - Scenario: Given lines が 3001 行, When `check_line_limit files "$lines" "$FF_MAX_FILES"` を呼ぶ
  - Expected: Then 終了コードは 1 で、stderr は `::error::files: exceeds the limit of 3000 lines (got: '3001')` である (R-IN-014)

- [ ] **T-08-02-02**: patterns 1001 行はエラー
  - Target: `check_line_limit`
  - Test ID: T-FF-CLL-05
  - Scenario: Given lines が 1001 行, When `check_line_limit patterns "$lines" "$FF_MAX_PATTERNS"` を呼ぶ
  - Expected: Then 終了コードは 1 で、stderr は `::error::patterns: exceeds the limit of 1000 lines (got: '1001')` である (R-IN-015)

### [エッジケース] Edge Cases

#### T-08-03: 行数の数え方

- [ ] **T-08-03-01**: 空文字列は 0 行として受け付ける
  - Target: `check_line_limit`
  - Test ID: T-FF-CLL-06
  - Scenario: Given lines が `""`, When `check_line_limit files "" 1` を呼ぶ
  - Expected: Then 終了コードは 0 である

- [ ] **T-08-03-02**: 末尾に LF の無い 1 行を 1 行と数える
  - Target: `check_line_limit`
  - Test ID: T-FF-CLL-07
  - Scenario: Given lines が `a`, When `check_line_limit files a 1` を呼ぶ
  - Expected: Then 終了コードは 0 である

- [ ] **T-08-03-03**: 2 行を 2 行と数える
  - Target: `check_line_limit`
  - Test ID: T-FF-CLL-08
  - Scenario: Given lines が `$'a\nb'`, When `check_line_limit files "$lines" 1` を呼ぶ
  - Expected: Then 終了コードは 1 で、stderr に `(got: '2')` が含まれる

---

## T-09: classify_patterns

対象: `classify_patterns <lines>` (CP)。R-IN-004〜R-IN-009、DD-IN-02〜DD-IN-05、DR-14。テストファイルは `filter-files.unit.spec.sh` の CP グループ。implementation.md Phase 3 Commit 5。stdout は 1 パターン 1 行の `I<TAB>pattern` / `E<TAB>pattern`。

### [正常] Normal Cases

#### T-09-01: 包含と除外に分ける

- [ ] **T-09-01-01**: `!` で始まらない行は包含
  - Target: `classify_patterns`
  - Test ID: T-FF-CP-01
  - Scenario: Given lines が `*.sh`, When `classify_patterns "$lines"` を呼ぶ
  - Expected: Then 終了コードは 0 で、stdout は `$'I\t*.sh'` である (R-IN-006)

- [ ] **T-09-01-02**: `!` で始まる行は除外
  - Target: `classify_patterns`
  - Test ID: T-FF-CP-02
  - Scenario: Given lines が `!*.md`, When `classify_patterns "$lines"` を呼ぶ
  - Expected: Then stdout は `$'E\t*.md'` である (R-IN-004)

- [ ] **T-09-01-03**: 記述順を保つ
  - Target: `classify_patterns`
  - Test ID: T-FF-CP-03
  - Scenario: Given lines が `$'src/**\n!src/gen/**'`, When `classify_patterns "$lines"` を呼ぶ
  - Expected: Then stdout は `$'I\tsrc/**\nE\tsrc/gen/**'` である

- [ ] **T-09-01-04**: ダブルクオートを文字として残す
  - Target: `classify_patterns`
  - Test ID: T-FF-CP-04
  - Scenario: Given lines が `'"b.sh"'`, When `classify_patterns "$lines"` を呼ぶ
  - Expected: Then stdout は `$'I\t"b.sh"'` である (R-IN-008)

### [異常] Error Cases

#### T-09-02: 不正な除外パターン

- [ ] **T-09-02-01**: `!` だけの行はエラー
  - Target: `classify_patterns`
  - Test ID: T-FF-CP-05
  - Scenario: Given lines が `!`, When `classify_patterns "$lines"` を呼ぶ
  - Expected: Then 終了コードは 1 で、stderr は `::error::patterns:` で始まり `(got: '!')` を含む (R-IN-005)

- [ ] **T-09-02-02**: スペースで始まる除外はエラー
  - Target: `classify_patterns`
  - Test ID: T-FF-CP-06
  - Scenario: Given lines が `'! a.sh'`, When `classify_patterns "$lines"` を呼ぶ
  - Expected: Then 終了コードは 1 で、stderr に `(got: '! a.sh')` が含まれる (R-IN-009)

- [ ] **T-09-02-03**: タブで始まる除外はエラー
  - Target: `classify_patterns`
  - Test ID: T-FF-CP-07
  - Scenario: Given lines が `$'!\ta.sh'`, When `classify_patterns "$lines"` を呼ぶ
  - Expected: Then 終了コードは 1 で、stderr は `::error::patterns:` で始まる (R-IN-009)

### [エッジケース] Edge Cases

#### T-09-03: 境界の入力

- [ ] **T-09-03-01**: 先頭の `!` は 1 つだけ除く
  - Target: `classify_patterns`
  - Test ID: T-FF-CP-08
  - Scenario: Given lines が `!!a.sh`, When `classify_patterns "$lines"` を呼ぶ
  - Expected: Then stdout は `$'E\t!a.sh'` である (R-IN-004)

- [ ] **T-09-03-02**: 空の入力はパターン無し
  - Target: `classify_patterns`
  - Test ID: T-FF-CP-09
  - Scenario: Given lines が `""`, When `classify_patterns ""` を呼ぶ
  - Expected: Then 終了コードは 0 で、stdout は空である (R-IN-007)

- [ ] **T-09-03-03**: 不正な行が 2 つあれば最初の行だけを報告する
  - Target: `classify_patterns`
  - Test ID: T-FF-CP-10
  - Scenario: Given lines が `$'!\n! a.sh'`, When `classify_patterns "$lines"` を呼ぶ
  - Expected: Then stderr は 1 行だけで、`(got: '!')` を含む (DD-IN-05)

- [ ] **T-09-03-04**: パターン内のタブを変えない
  - Target: `classify_patterns`
  - Test ID: T-FF-CP-11
  - Scenario: Given lines が `$'a\tb'`, When `classify_patterns "$lines"` を呼ぶ
  - Expected: Then stdout は `$'I\ta\tb'` で、最初のタブより後は `$'a\tb'` である

- [ ] **T-09-03-05**: パターン内のバックスラッシュを変えない
  - Target: `classify_patterns`
  - Test ID: T-FF-CP-12
  - Scenario: Given lines が `'a\'` (末尾がバックスラッシュ), When `classify_patterns "$lines"` を呼ぶ
  - Expected: Then stdout は `$'I\ta\\'` である

---

## T-10: glob_to_regex

対象: `glob_to_regex <glob>` (GTR)。R-MAT-001〜R-MAT-009、DD-MAT-01〜DD-MAT-06、DR-02、DR-17。テストファイルは `filter-files.unit.spec.sh` の GTR グループ。implementation.md Phase 4 Commit 1。特記の無い限り、各タスクは `LC_ALL=C.UTF-8` のもとで `[[ "$path" =~ $(glob_to_regex "$glob") ]]` を評価し、一致・不一致を確かめる。

### [正常] Normal Cases

#### T-10-01: `*` は `/` 以外の 0 文字以上

- [ ] **T-10-01-01**: `*.sh` は `a.sh` に一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-01
  - Scenario: Given glob `*.sh`, When path `a.sh` と照合する
  - Expected: Then 一致する (R-MAT-006)

- [ ] **T-10-01-02**: `*.sh` は `dir/a.sh` に一致しない
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-02
  - Scenario: Given glob `*.sh`, When path `dir/a.sh` と照合する
  - Expected: Then 一致しない (R-MAT-006)

#### T-10-02: `**` は階層をまたぐ

- [ ] **T-10-02-01**: `**` は `a.sh` に一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-03
  - Scenario: Given glob `**`, When path `a.sh` と照合する
  - Expected: Then 一致する (R-MAT-002)

- [ ] **T-10-02-02**: `**` は `dir/sub/a.sh` に一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-04
  - Scenario: Given glob `**`, When path `dir/sub/a.sh` と照合する
  - Expected: Then 一致する (R-MAT-002)

- [ ] **T-10-02-03**: `**/a.sh` は 0 階層の `a.sh` に一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-05
  - Scenario: Given glob `**/a.sh`, When path `a.sh` と照合する
  - Expected: Then 一致する (R-MAT-003、DD-MAT-01)

- [ ] **T-10-02-04**: `**/a.sh` は 1 階層の `x/a.sh` に一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-06
  - Scenario: Given glob `**/a.sh`, When path `x/a.sh` と照合する
  - Expected: Then 一致する (R-MAT-003)

- [ ] **T-10-02-05**: `**/a.sh` は 2 階層の `x/y/a.sh` に一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-07
  - Scenario: Given glob `**/a.sh`, When path `x/y/a.sh` と照合する
  - Expected: Then 一致する (R-MAT-003)

- [ ] **T-10-02-06**: `dir/**` は `dir/a.sh` に一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-08
  - Scenario: Given glob `dir/**`, When path `dir/a.sh` と照合する
  - Expected: Then 一致する (R-MAT-004)

- [ ] **T-10-02-07**: `dir/**` は `dir/sub/a.sh` に一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-09
  - Scenario: Given glob `dir/**`, When path `dir/sub/a.sh` と照合する
  - Expected: Then 一致する (R-MAT-004)

- [ ] **T-10-02-08**: `a/**/b.sh` は `a/b.sh` に一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-10
  - Scenario: Given glob `a/**/b.sh`, When path `a/b.sh` と照合する
  - Expected: Then 一致する (R-MAT-003)

- [ ] **T-10-02-09**: `a/**/b.sh` は `a/x/y/b.sh` に一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-11
  - Scenario: Given glob `a/**/b.sh`, When path `a/x/y/b.sh` と照合する
  - Expected: Then 一致する (R-MAT-003)

#### T-10-03: `?` は `/` 以外の 1 文字

- [ ] **T-10-03-01**: `dir/?.sh` は `dir/a.sh` に一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-12
  - Scenario: Given glob `dir/?.sh`, When path `dir/a.sh` と照合する
  - Expected: Then 一致する (R-MAT-007)

- [ ] **T-10-03-02**: `dir/?.sh` は `dir/ab.sh` に一致しない
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-13
  - Scenario: Given glob `dir/?.sh`, When path `dir/ab.sh` と照合する
  - Expected: Then 一致しない (R-MAT-007)

#### T-10-04: パス全体への一致

- [ ] **T-10-04-01**: 同じ文字列のパスに一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-14
  - Scenario: Given glob `a.sh`, When path `a.sh` と照合する
  - Expected: Then 一致する (R-MAT-001)

- [ ] **T-10-04-02**: パスの一部だけの一致は一致としない
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-15
  - Scenario: Given glob `src`, When path `src/a.sh` と照合する
  - Expected: Then 一致しない (R-MAT-001)

- [ ] **T-10-04-03**: 変換結果は全体一致のアンカーで囲まれる
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-16
  - Scenario: Given glob `*.sh`, When `glob_to_regex '*.sh'` を呼ぶ
  - Expected: Then 終了コードは 0 で、stdout は `^` で始まり `$` で終わる (matching §3.2 impl-note)

### [異常] Error Cases

#### T-10-05: 正規表現・ブラケットとして解釈しない

- [ ] **T-10-05-01**: `.` は任意の 1 文字に一致しない
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-17
  - Scenario: Given glob `a.sh`, When path `aXsh` と照合する
  - Expected: Then 一致しない (R-MAT-008、AC-006)

- [ ] **T-10-05-02**: ブラケットは文字クラスにならない
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-18
  - Scenario: Given glob `[ab].sh`, When path `a.sh` と照合する
  - Expected: Then 一致しない (DD-MAT-03)

- [ ] **T-10-05-03**: ブラケットは文字そのものに一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-19
  - Scenario: Given glob `[ab].sh`, When path `[ab].sh` と照合する
  - Expected: Then 一致する (DD-MAT-03)

- [ ] **T-10-05-04**: `+` と括弧は文字そのものに一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-20
  - Scenario: Given glob `a+(b).sh`, When path `a+(b).sh` と照合する
  - Expected: Then 一致する (R-MAT-008)

- [ ] **T-10-05-05**: 末尾の `\` は文字そのものに一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-21
  - Scenario: Given glob `a\` (末尾がバックスラッシュ), When path `a\` と照合する
  - Expected: Then 一致する (R-MAT-008)

- [ ] **T-10-05-06**: 末尾の `\` は省略できない
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-22
  - Scenario: Given glob `a\` (末尾がバックスラッシュ), When path `a` と照合する
  - Expected: Then 一致しない (R-MAT-008)

- [ ] **T-10-05-07**: ダブルクオートは文字そのもの
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-23
  - Scenario: Given glob `"b.sh"`, When path `b.sh` と照合する
  - Expected: Then 一致しない (R-MAT-008、REQ-F-016)

- [ ] **T-10-05-08**: `|` は選択にならない
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-24
  - Scenario: Given glob `a|b`, When path `a` と照合する
  - Expected: Then 一致しない (R-MAT-008)

### [エッジケース] Edge Cases

#### T-10-06: `**` の境界

- [ ] **T-10-06-01**: `dir/**` は `dir` に一致しない
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-25
  - Scenario: Given glob `dir/**`, When path `dir` と照合する
  - Expected: Then 一致しない (`/` の後に 1 文字以上が必要、R-MAT-004)

- [ ] **T-10-06-02**: `dir/**` は `dirx/a.sh` に一致しない
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-26
  - Scenario: Given glob `dir/**`, When path `dirx/a.sh` と照合する
  - Expected: Then 一致しない (R-MAT-004)

- [ ] **T-10-06-03**: `**/**` は `a.sh` に一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-27
  - Scenario: Given glob `**/**`, When path `a.sh` と照合する
  - Expected: Then 一致する (`**/` の後の `**` は R-MAT-005)

- [ ] **T-10-06-04**: `**/**` は `x/y/a.sh` に一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-28
  - Scenario: Given glob `**/**`, When path `x/y/a.sh` と照合する
  - Expected: Then 一致する

- [ ] **T-10-06-05**: `a/**/**/b` は `a/b` に一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-29
  - Scenario: Given glob `a/**/**/b`, When path `a/b` と照合する
  - Expected: Then 一致する (`**/` の連続はそれぞれ 0 階層以上)

- [ ] **T-10-06-06**: `a/**/**/b` は `a/x/y/b` に一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-30
  - Scenario: Given glob `a/**/**/b`, When path `a/x/y/b` と照合する
  - Expected: Then 一致する

- [ ] **T-10-06-07**: `/` の直後ではない `**/` は `ax/b` に一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-31
  - Scenario: Given glob `a**/b`, When path `ax/b` と照合する
  - Expected: Then 一致する (R-MAT-005 の `**` と文字 `/`)

- [ ] **T-10-06-08**: `/` の直後ではない `**/` は `a/x/b` に一致しない
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-32
  - Scenario: Given glob `a**/b`, When path `a/x/b` と照合する
  - Expected: Then 一致しない (R-MAT-005)

- [ ] **T-10-06-09**: `/` に挟まれない `**` は `axxb` に一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-33
  - Scenario: Given glob `a**b`, When path `axxb` と照合する
  - Expected: Then 一致する (DD-MAT-02)

- [ ] **T-10-06-10**: `/` に挟まれない `**` は `/` をまたがない
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-34
  - Scenario: Given glob `a**b`, When path `ax/xb` と照合する
  - Expected: Then 一致しない (DD-MAT-02)

- [ ] **T-10-06-11**: `***.sh` は `a.sh` に一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-35
  - Scenario: Given glob `***.sh`, When path `a.sh` と照合する
  - Expected: Then 一致する (`**` と `*` の最長一致)

- [ ] **T-10-06-12**: `***.sh` は `d/a.sh` に一致しない
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-36
  - Scenario: Given glob `***.sh`, When path `d/a.sh` と照合する
  - Expected: Then 一致しない

#### T-10-07: 文字の境界

- [ ] **T-10-07-01**: `?` は UTF-8 の 1 文字に一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-37
  - Scenario: Given glob `?.sh`, When path `あ.sh` と照合する
  - Expected: Then 一致する (DD-MAT-05)

- [ ] **T-10-07-02**: `*` は先頭の `.` に一致する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-38
  - Scenario: Given glob `*`, When path `.env` と照合する
  - Expected: Then 一致する (DD-MAT-04)

- [ ] **T-10-07-03**: `*` は `dir/.env` に一致しない
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-39
  - Scenario: Given glob `*`, When path `dir/.env` と照合する
  - Expected: Then 一致しない (DD-MAT-04)

- [ ] **T-10-07-04**: 大文字・小文字を区別する
  - Target: `glob_to_regex`
  - Test ID: T-FF-GTR-40
  - Scenario: Given glob `*.SH`, When path `a.sh` と照合する
  - Expected: Then 一致しない (DD-MAT-06)

---

## T-11: filter_files

対象: `filter_files <files> <include> <exclude>` (FF)。R-MAT-009〜R-MAT-013、DR-04、DR-05、DR-17、REQ-F-012、REQ-NF-002。テストファイルは `filter-files.unit.spec.sh` の FF グループ。implementation.md Phase 4 Commit 2。引数はいずれも LF 区切りの文字列 (0 件は空文字列) とし、stdout に保持行を出す。

### [正常] Normal Cases

#### T-11-01: 保持条件

- [ ] **T-11-01-01**: 包含パターンに一致するファイルだけを残す
  - Target: `filter_files`
  - Test ID: T-FF-FF-01
  - Scenario: Given files `$'a.sh\nREADME.md\nb.sh'`、include `*.sh`、exclude `""`, When `filter_files` を呼ぶ
  - Expected: Then 終了コードは 0 で、stdout は `$'a.sh\nb.sh'` である (R-MAT-012、AC-001)

- [ ] **T-11-01-02**: 除外は包含より優先する
  - Target: `filter_files`
  - Test ID: T-FF-FF-02
  - Scenario: Given files `$'src/a.sh\nsrc/gen/b.sh'`、include `src/**`、exclude `src/gen/**`, When `filter_files` を呼ぶ
  - Expected: Then stdout は `src/a.sh` である (R-MAT-011、DR-05)

- [ ] **T-11-01-03**: 除外だけなら残りの全件を残す
  - Target: `filter_files`
  - Test ID: T-FF-FF-03
  - Scenario: Given files `$'a.sh\na.md\nb.sh'`、include `""`、exclude `*.md`, When `filter_files` を呼ぶ
  - Expected: Then stdout は `$'a.sh\nb.sh'` である (R-MAT-010、DR-04)

- [ ] **T-11-01-04**: パターンが無ければ全件を残す
  - Target: `filter_files`
  - Test ID: T-FF-FF-04
  - Scenario: Given files `$'a.sh\ndir/b.md'`、include `""`、exclude `""`, When `filter_files` を呼ぶ
  - Expected: Then stdout は `$'a.sh\ndir/b.md'` である (R-MAT-010)

- [ ] **T-11-01-05**: 包含が複数でも出力はファイルの入力順
  - Target: `filter_files`
  - Test ID: T-FF-FF-05
  - Scenario: Given files `$'b.md\na.sh\nc.md'`、include `$'*.sh\n*.md'`、exclude `""`, When `filter_files` を呼ぶ
  - Expected: Then stdout は `$'b.md\na.sh\nc.md'` である (REQ-F-010)

### [異常] Error Cases

#### T-11-02: 残らないファイル

- [ ] **T-11-02-01**: どれにも一致しなければ空を返す
  - Target: `filter_files`
  - Test ID: T-FF-FF-06
  - Scenario: Given files `a.md`、include `*.sh`、exclude `""`, When `filter_files` を呼ぶ
  - Expected: Then 終了コードは 0 で、stdout は空である (R-MAT-013、AC-009)

- [ ] **T-11-02-02**: 包含に名指しされても除外に一致すれば捨てる
  - Target: `filter_files`
  - Test ID: T-FF-FF-07
  - Scenario: Given files `src/gen/b.sh`、include `src/gen/b.sh`、exclude `src/gen/**`, When `filter_files` を呼ぶ
  - Expected: Then stdout は空である (R-MAT-011)

### [エッジケース] Edge Cases

#### T-11-03: 入力の形と実行環境に依存しない

- [ ] **T-11-03-01**: 重複を残す
  - Target: `filter_files`
  - Test ID: T-FF-FF-08
  - Scenario: Given files `$'a.sh\na.sh'`、include `*.sh`、exclude `""`, When `filter_files` を呼ぶ
  - Expected: Then stdout は `$'a.sh\na.sh'` である

- [ ] **T-11-03-02**: files が空なら空を返す
  - Target: `filter_files`
  - Test ID: T-FF-FF-09
  - Scenario: Given files `""`、include `*.sh`、exclude `""`, When `filter_files` を呼ぶ
  - Expected: Then 終了コードは 0 で、stdout は空である

- [ ] **T-11-03-03**: シェルのオプションが有効でも結果が変わらない
  - Target: `filter_files`
  - Test ID: T-FF-FF-10
  - Scenario: Given `shopt -s globstar extglob nocasematch nocaseglob` を有効にし、files `$'a.sh\nREADME.md\nb.sh'`、include `*.sh`、exclude `""`, When `filter_files` を呼ぶ
  - Expected: Then stdout は `$'a.sh\nb.sh'` である (REQ-NF-002)

- [ ] **T-11-03-04**: `nocasematch` が有効でも大文字・小文字を区別する
  - Target: `filter_files`
  - Test ID: T-FF-FF-11
  - Scenario: Given `shopt -s nocasematch` を有効にし、files `a.sh`、include `*.SH`、exclude `""`, When `filter_files` を呼ぶ
  - Expected: Then stdout は空である (R-MAT-009、DD-MAT-06)

- [ ] **T-11-03-05**: 呼び出し元のシェルのオプションを変えない
  - Target: `filter_files`
  - Test ID: T-FF-FF-12
  - Scenario: Given `shopt -s nocasematch` を有効にした呼び出し元, When `filter_files a.sh '*.sh' ''` を呼んだ後に `shopt -q nocasematch` を評価する
  - Expected: Then `nocasematch` は有効のままである (サブシェル本体)

- [ ] **T-11-03-06**: 呼び出し元のロケールが C でも UTF-8 の 1 文字で照合する
  - Target: `filter_files`
  - Test ID: T-FF-FF-13
  - Scenario: Given 呼び出し元が `LC_ALL=C`、files `あ.sh`、include `?.sh`、exclude `""`, When `filter_files` を呼ぶ
  - Expected: Then stdout は `あ.sh` で、呼び出し後の `LC_ALL` は `C` のままである (DD-MAT-05)

- [ ] **T-11-03-07**: ファイルシステムを参照せず文字列だけで判定する
  - Target: `filter_files`
  - Test ID: T-FF-FF-14
  - Scenario: Given git リポジトリ外の一時ディレクトリを作業ディレクトリにし、実在する `exists.md` を作り、files `$'no/such/file.sh\nexists.md'`、include `**/*.sh`、exclude `""`, When `filter_files` を呼ぶ
  - Expected: Then stdout は `no/such/file.sh` である (REQ-F-012、AC-007)

---

## T-12: emit_outputs

対象: `emit_outputs <file> <kept>` (EO)。R-OUT-001〜R-OUT-006、DD-OUT-03、DR-09。テストファイルは `filter-files.unit.spec.sh` の EO グループ。implementation.md Phase 5 Commit 1。特記の無い限り、出力先は空の一時ファイル。

### [正常] Normal Cases

#### T-12-01: files と count を書く

- [ ] **T-12-01-01**: 保持行を files に、件数を count に書く
  - Target: `emit_outputs`
  - Test ID: T-FF-EO-01
  - Scenario: Given kept が `$'a.sh\nb.sh'`, When `emit_outputs "$file" "$kept"` を呼ぶ
  - Expected: Then 出力先は `files<<EOF`、`a.sh`、`b.sh`、`EOF`、`count=2` の 5 行である (R-OUT-003、R-OUT-005)

- [ ] **T-12-01-02**: files を count より先に書く
  - Target: `emit_outputs`
  - Test ID: T-FF-EO-02
  - Scenario: Given kept が `a.sh`, When `emit_outputs "$file" "$kept"` を呼ぶ
  - Expected: Then `files<<` の行は `count=` の行より前にある (DD-OUT-03)

- [ ] **T-12-01-03**: 成功時は 0 を返し、stdout に何も出さない
  - Target: `emit_outputs`
  - Test ID: T-FF-EO-03
  - Scenario: Given kept が `a.sh`, When `emit_outputs "$file" "$kept"` を呼ぶ
  - Expected: Then 終了コードは 0 で、stdout・stderr は空である

#### T-12-02: 0 件

- [ ] **T-12-02-01**: 0 件なら files は空、count は 0
  - Target: `emit_outputs`
  - Test ID: T-FF-EO-04
  - Scenario: Given kept が `""`, When `emit_outputs "$file" ""` を呼ぶ
  - Expected: Then 出力先は `files<<EOF`、`EOF`、`count=0` の 3 行である (R-OUT-004、AC-009)

### [異常] Error Cases

#### T-12-03: 出力できない

- [ ] **T-12-03-01**: 出力先が空ならエラー
  - Target: `emit_outputs`
  - Test ID: T-FF-EO-05
  - Scenario: Given 出力先が `""`, When `emit_outputs "" a.sh` を呼ぶ
  - Expected: Then 終了コードは 1 で、stderr は `::error::GITHUB_OUTPUT: value must not be empty` である (R-OUT-001)

- [ ] **T-12-03-02**: 出力先がディレクトリならエラー
  - Target: `emit_outputs`
  - Test ID: T-FF-EO-06
  - Scenario: Given 出力先が既存のディレクトリ, When `emit_outputs "$dir" a.sh` を呼ぶ
  - Expected: Then 終了コードは 1 で、stderr は `::error::GITHUB_OUTPUT:` で始まり `(got: '<dir>')` を含み、ディレクトリ内に何も作られない (R-OUT-002)

- [ ] **T-12-03-03**: 親ディレクトリが無ければエラー
  - Target: `emit_outputs`
  - Test ID: T-FF-EO-07
  - Scenario: Given 出力先が `$tmp/no-such-dir/out`, When `emit_outputs` を呼ぶ
  - Expected: Then 終了コードは 1 で、stderr は `::error::GITHUB_OUTPUT:` で始まる (R-OUT-002)

- [ ] **T-12-03-04**: files の書き込みに失敗したら count を書かない
  - Target: `emit_outputs`
  - Test ID: T-FF-EO-08
  - Scenario: Given `write_multiline_output` を 2 を返すスタブに差し替える, When `emit_outputs "$file" a.sh` を呼ぶ
  - Expected: Then 終了コードは 1 で、stderr は `::error::files:` で始まり出力先のパスを含み、出力先に `count=` は無い (R-OUT-006)

- [ ] **T-12-03-05**: count の書き込みに失敗したら files は残る
  - Target: `emit_outputs`
  - Test ID: T-FF-EO-09
  - Scenario: Given `write_output` を 2 を返すスタブに差し替える, When `emit_outputs "$file" a.sh` を呼ぶ
  - Expected: Then 終了コードは 1 で、stderr は `::error::count:` で始まり、出力先には `files<<EOF` が残る (R-OUT-006、DR-09)

### [エッジケース] Edge Cases

#### T-12-04: 値と出力先の境界

- [ ] **T-12-04-01**: 保持行に `EOF` があれば区切り文字を選び直す
  - Target: `emit_outputs`
  - Test ID: T-FF-EO-10
  - Scenario: Given kept が `$'EOF\na.sh'`, When `emit_outputs "$file" "$kept"` を呼ぶ
  - Expected: Then 出力先の 1 行目は `files<<EOF_1` で、`count=2` がある (AC-008)

- [ ] **T-12-04-02**: count は先頭ゼロ・空白の無い 10 進整数
  - Target: `emit_outputs`
  - Test ID: T-FF-EO-11
  - Scenario: Given kept が 1000 行, When `emit_outputs "$file" "$kept"` を呼ぶ
  - Expected: Then 出力先の最終行は `count=1000` である (R-OUT-005)

- [ ] **T-12-04-03**: 既存の内容を残して追記する
  - Target: `emit_outputs`
  - Test ID: T-FF-EO-12
  - Scenario: Given 出力先が `existing=1` の 1 行を持つ, When `emit_outputs "$file" a.sh` を呼ぶ
  - Expected: Then 出力先の 1 行目は `existing=1` のままである

- [ ] **T-12-04-04**: 存在しない出力先は書き出しで作られる
  - Target: `emit_outputs`
  - Test ID: T-FF-EO-13
  - Scenario: Given 書き込み可能なディレクトリの下の、存在しないパス, When `emit_outputs "$dir/out" a.sh` を呼ぶ
  - Expected: Then 終了コードは 0 で、`$dir/out` に `count=1` がある (R-OUT-021)

---

## T-13: filter-files.sh

対象: `scripts/filter-files.sh` の `main` を、環境変数を設定して実行する (MAINF、functional)。AC-001〜AC-018、specifications-index.md §3.4・§5、DD-IDX-02、DR-14。テストファイルは `_ca-filter-files/scripts/__tests__/functional/filter-files.functional.spec.sh`。implementation.md Phase 5 Commit 2。

特記の無い限り、`GITHUB_OUTPUT` は空の一時ファイル、`INPUT_PATTERNS` は空文字列とする。「files 出力」「count 出力」は出力ファイルから読み取った値を指す。エラー系はすべて、終了コードが 0 以外で、stderr が `::error::` で始まる 1 行であり、出力ファイルが空であることを確かめる。

### [正常] Normal Cases

#### T-13-01: 受け入れ基準

- [ ] **T-13-01-01**: 包含パターンに一致するファイルだけが残る
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-01
  - Scenario: Given `INPUT_FILES=$'a.sh\nREADME.md\nb.sh'`、`INPUT_PATTERNS='*.sh'`, When スクリプトを実行する
  - Expected: Then 終了コードは 0 で、files 出力は `$'a.sh\nb.sh'`、count 出力は `2` である (AC-001)

- [ ] **T-13-01-02**: 除外は包含より優先する
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-02
  - Scenario: Given `INPUT_FILES=$'src/a.sh\nsrc/gen/b.sh'`、`INPUT_PATTERNS=$'src/**\n!src/gen/**'`, When スクリプトを実行する
  - Expected: Then files 出力は `src/a.sh` である (AC-002)

- [ ] **T-13-01-03**: 除外だけなら残りの全件が残る
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-03
  - Scenario: Given `INPUT_FILES=$'a.sh\na.md\nb.sh'`、`INPUT_PATTERNS='!*.md'`, When スクリプトを実行する
  - Expected: Then files 出力は `$'a.sh\nb.sh'` である (AC-003)

- [ ] **T-13-01-04**: パターンが空なら全件を残す
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-04
  - Scenario: Given `INPUT_FILES=$'a.sh\ndir/b.md'`、`INPUT_PATTERNS=""`, When スクリプトを実行する
  - Expected: Then 終了コードは 0 で、files 出力は `$'a.sh\ndir/b.md'`、count 出力は `2` である (AC-004)

- [ ] **T-13-01-05**: `*` は `/` に一致しない
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-05
  - Scenario: Given `INPUT_FILES=$'a.sh\ndir/a.sh\ndir/sub/a.sh'`、`INPUT_PATTERNS='*.sh'`, When スクリプトを実行する
  - Expected: Then files 出力は `a.sh` である (AC-005)

- [ ] **T-13-01-06**: `**` は任意階層に一致する
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-06
  - Scenario: Given `INPUT_FILES=$'a.sh\ndir/a.sh\ndir/sub/a.sh'`、`INPUT_PATTERNS='dir/**'`, When スクリプトを実行する
  - Expected: Then files 出力は `$'dir/a.sh\ndir/sub/a.sh'` である (AC-005)

- [ ] **T-13-01-07**: `?` は 1 文字に一致する
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-07
  - Scenario: Given `INPUT_FILES=$'a.sh\ndir/a.sh\ndir/sub/a.sh'`、`INPUT_PATTERNS='dir/?.sh'`, When スクリプトを実行する
  - Expected: Then files 出力は `dir/a.sh` である (AC-005)

- [ ] **T-13-01-08**: ドットはリテラルとして照合される
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-08
  - Scenario: Given `INPUT_FILES=$'a.sh\naXsh'`、`INPUT_PATTERNS='a.sh'`, When スクリプトを実行する
  - Expected: Then files 出力は `a.sh` である (AC-006)

- [ ] **T-13-01-09**: 実在しないパスも文字列として照合される
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-09
  - Scenario: Given `INPUT_FILES='no/such/file.sh'`、`INPUT_PATTERNS='**/*.sh'`, When スクリプトを実行する
  - Expected: Then files 出力は `no/such/file.sh` である (AC-007)

- [ ] **T-13-01-10**: 区切り文字と同名のパスを含んでも出力が壊れない
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-10
  - Scenario: Given `INPUT_FILES=$'EOF\na.sh'`、`INPUT_PATTERNS=""`, When スクリプトを実行する
  - Expected: Then 出力ファイルの区切り文字は `EOF` 以外で、files 出力は `$'EOF\na.sh'` である (AC-008、AC-010)

- [ ] **T-13-01-11**: 一致が無ければ空の結果で正常終了する
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-11
  - Scenario: Given `INPUT_FILES='a.md'`、`INPUT_PATTERNS='*.sh'`, When スクリプトを実行する
  - Expected: Then 終了コードは 0 で、files 出力は空文字列、count 出力は `0` である (AC-009)

- [ ] **T-13-01-12**: files の行は変えず、patterns は両端の空白を除いて空行を無視する
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-12
  - Scenario: Given `INPUT_FILES=$'  a.sh\n\nmy file.sh\nb.md\n'`、`INPUT_PATTERNS=$'  *.sh  \n\t'`, When スクリプトを実行する
  - Expected: Then files 出力は `$'  a.sh\nmy file.sh'`、count 出力は `2` である (AC-012)

- [ ] **T-13-01-13**: CRLF の改行を LF に変換してから行に分ける
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-13
  - Scenario: Given `INPUT_FILES=$'a.sh\r\nb.sh\r\nc.md\n'`、`INPUT_PATTERNS=$'*.sh\r\n'`, When スクリプトを実行する
  - Expected: Then files 出力は `$'a.sh\nb.sh'` で、どの行も CR を含まない (AC-014)

- [ ] **T-13-01-14**: YAML が外したクオートの無いパターンで照合する
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-14
  - Scenario: Given `INPUT_FILES=$'a.sh\nb.md'`、`INPUT_PATTERNS='*.sh'`, When スクリプトを実行する
  - Expected: Then files 出力は `a.sh` である (AC-013)

- [ ] **T-13-01-15**: 行内のクオートは文字として残る
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-15
  - Scenario: Given `INPUT_FILES=$'a.sh\nb.md'`、`INPUT_PATTERNS='"a.sh"'`, When スクリプトを実行する
  - Expected: Then 終了コードは 0 で、files 出力は空文字列、count 出力は `0` である (AC-013)

- [ ] **T-13-01-16**: 件数の上限ちょうどは受け付ける
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-16
  - Scenario: Given `INPUT_FILES` が 3000 行、`INPUT_PATTERNS` が 1000 行 (どちらもバイト数の上限以内), When スクリプトを実行する
  - Expected: Then 終了コードは 0 である (AC-017)

- [ ] **T-13-01-17**: サイズの上限ちょうどは受け付ける
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-17
  - Scenario: Given `INPUT_FILES` が 120000 バイト (3000 行以内), When スクリプトを実行する
  - Expected: Then 終了コードは 0 である (AC-018)

### [異常] Error Cases

#### T-13-02: 何も書かずにエラー終了する

- [ ] **T-13-02-01**: 出力先が未設定
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-18
  - Scenario: Given `GITHUB_OUTPUT` を unset、`INPUT_FILES='a.sh'`, When スクリプトを実行する
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::GITHUB_OUTPUT:` で始まる (AC-011)

- [ ] **T-13-02-02**: LF を伴わない CR を含む
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-19
  - Scenario: Given `INPUT_FILES=$'a\rb.sh\nc.sh'`, When スクリプトを実行する
  - Expected: Then stderr は `::error::files:` で始まり、出力ファイルは空である (AC-015)

- [ ] **T-13-02-03**: ダブルクオートを含む files の行
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-20
  - Scenario: Given `INPUT_FILES` が `a.sh` と `"a\nb.sh"` (文字通り) の 2 行, When スクリプトを実行する
  - Expected: Then stderr は `::error::files:` で始まり、出力ファイルは空である (AC-016)

- [ ] **T-13-02-04**: files が 3001 行
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-21
  - Scenario: Given `INPUT_FILES` が 3001 行, When スクリプトを実行する
  - Expected: Then stderr は `::error::files: ` で始まり、出力ファイルは空である (AC-017)

- [ ] **T-13-02-05**: patterns が 1001 行
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-22
  - Scenario: Given `INPUT_FILES='a.sh'`、`INPUT_PATTERNS` が 1001 行, When スクリプトを実行する
  - Expected: Then stderr は `::error::patterns: ` で始まり、出力ファイルは空である (AC-017)

- [ ] **T-13-02-06**: files が 120001 バイト
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-23
  - Scenario: Given `INPUT_FILES` が 120001 バイト, When スクリプトを実行する
  - Expected: Then stderr は `::error::files: exceeds the limit of 120000 bytes` で始まり、出力ファイルは空である (AC-018)

- [ ] **T-13-02-07**: patterns が 120001 バイト
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-24
  - Scenario: Given `INPUT_FILES='a.sh'`、`INPUT_PATTERNS` が 120001 バイト, When スクリプトを実行する
  - Expected: Then stderr は `::error::patterns: exceeds the limit of 120000 bytes` で始まる (AC-018)

- [ ] **T-13-02-08**: 出力先がディレクトリ
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-25
  - Scenario: Given `GITHUB_OUTPUT` が既存のディレクトリのパス、`INPUT_FILES='a.sh'`, When スクリプトを実行する
  - Expected: Then stderr は `::error::GITHUB_OUTPUT:` で始まり、ディレクトリ内に何も作られない (R-OUT-002)

- [ ] **T-13-02-09**: `!` だけのパターン
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-26
  - Scenario: Given `INPUT_FILES='a.sh'`、`INPUT_PATTERNS='!'`, When スクリプトを実行する
  - Expected: Then stderr は `::error::patterns:` で始まり、出力ファイルは空である (R-IN-005)

### [エッジケース] Edge Cases

#### T-13-03: 段階をまたぐ境界

- [ ] **T-13-03-01**: 不正なパターンと使えない出力先では、パターンのエラーを出す
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-27
  - Scenario: Given `INPUT_PATTERNS='!'`、`GITHUB_OUTPUT` を unset, When スクリプトを実行する
  - Expected: Then stderr は `::error::patterns:` で始まる 1 行だけである (DD-IDX-02、index §5)

- [ ] **T-13-03-02**: files が未指定なら 0 件で正常終了する
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-28
  - Scenario: Given `INPUT_FILES` を unset, When スクリプトを実行する
  - Expected: Then 終了コードは 0 で、files 出力は空文字列、count 出力は `0` である (index §5)

- [ ] **T-13-03-03**: files が 0 行でも不正なパターンはエラー
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-29
  - Scenario: Given `INPUT_FILES=""`、`INPUT_PATTERNS='! a.sh'`, When スクリプトを実行する
  - Expected: Then stderr は `::error::patterns:` で始まり、出力ファイルは空である (index §5)

- [ ] **T-13-03-04**: git の引用表記のままの 1 行はエラー
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-30
  - Scenario: Given `INPUT_FILES='"a\nb.sh"'` (文字通り), When スクリプトを実行する
  - Expected: Then stderr は `::error::files:` で始まり、出力ファイルは空である (index §5)

- [ ] **T-13-03-05**: バイト数の超過と CR があればバイト数のエラーだけを出す
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-31
  - Scenario: Given `INPUT_FILES` が 120001 バイトで、先頭行に LF を伴わない CR を含む, When スクリプトを実行する
  - Expected: Then stderr は `::error::files: exceeds the limit of 120000 bytes` で始まる 1 行だけである (DR-14)

- [ ] **T-13-03-06**: files の CR と不正なパターンがあれば files のエラーだけを出す
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-32
  - Scenario: Given `INPUT_FILES=$'a\rb.sh'`、`INPUT_PATTERNS='!'`, When スクリプトを実行する
  - Expected: Then stderr は `::error::files:` で始まる 1 行だけである (DR-14、MAIN の呼び出し順)

- [ ] **T-13-03-07**: 3000 行と末尾の改行は受け付ける
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-33
  - Scenario: Given `INPUT_FILES` が 3000 行で、末尾に LF が付く, When スクリプトを実行する
  - Expected: Then 終了コードは 0 で、count 出力は `3000` である (R-IN-003、R-IN-014)

- [ ] **T-13-03-08**: patterns が未指定なら全件が残る
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-34
  - Scenario: Given `INPUT_FILES=$'a.sh\nb.md'`、`INPUT_PATTERNS` を unset, When スクリプトを実行する
  - Expected: Then 終了コードは 0 で、count 出力は `2` である (R-IN-007、REQ-C-006 の `${VAR:-}`)

- [ ] **T-13-03-09**: 既存の出力ファイルの内容を残す
  - Target: `filter-files.sh`
  - Test ID: T-FF-MAINF-35
  - Scenario: Given `GITHUB_OUTPUT` が `existing=1` の 1 行を持つファイル、`INPUT_FILES='a.sh'`, When スクリプトを実行する
  - Expected: Then 出力ファイルの 1 行目は `existing=1` のままである

---

## T-14: action.yml

対象: `_ca-filter-files/action.yml` の静的検査 (ACT)。REQ-C-001、REQ-C-005、specifications-index.md §3.1。テストファイルは `_ca-filter-files/scripts/__tests__/unit/action.unit.spec.sh`。implementation.md Phase 6 Commit 1。

### [正常] Normal Cases

#### T-14-01: 入出力と環境変数の対応付け

- [ ] **T-14-01-01**: 2 つの入力が環境変数に対応付けられている
  - Target: `action.yml`
  - Test ID: T-FF-ACT-01
  - Scenario: Given action.yml, When step の `env` から環境変数名を抽出する
  - Expected: Then `INPUT_FILES` と `INPUT_PATTERNS` がある (REQ-C-005)

- [ ] **T-14-01-02**: outputs は files と count の 2 つである
  - Target: `action.yml`
  - Test ID: T-FF-ACT-02
  - Scenario: Given action.yml, When `outputs` の名前を抽出する
  - Expected: Then `files` と `count` の 2 つだけである

- [ ] **T-14-01-03**: outputs の値は実在する step ID を参照している
  - Target: `action.yml`
  - Test ID: T-FF-ACT-03
  - Scenario: Given action.yml, When outputs の `value` が参照する step ID を抽出する
  - Expected: Then その ID を持つ step が action.yml に存在する

- [ ] **T-14-01-04**: 環境変数は run を持つ同じ step にある
  - Target: `action.yml`
  - Test ID: T-FF-ACT-04
  - Scenario: Given action.yml, When 2 つの環境変数を持つ step を特定する
  - Expected: Then その step は `run` で `scripts/filter-files.sh` を実行している

### [異常] Error Cases

#### T-14-02: スクリプトインジェクションの防止

- [ ] **T-14-02-01**: run の中に式展開が無い
  - Target: `action.yml`
  - Test ID: T-FF-ACT-05
  - Scenario: Given action.yml, When `run` の内容を抽出する
  - Expected: Then `${{` を含まない (REQ-C-001)

### [エッジケース] Edge Cases

#### T-14-03: 入力の必須指定と既定値

- [ ] **T-14-03-01**: files は必須
  - Target: `action.yml`
  - Test ID: T-FF-ACT-06
  - Scenario: Given action.yml, When `inputs.files` を確認する
  - Expected: Then `required: true` である (index §3.1)

- [ ] **T-14-03-02**: patterns の既定値は空を明示する
  - Target: `action.yml`
  - Test ID: T-FF-ACT-07
  - Scenario: Given action.yml, When `inputs.patterns` を確認する
  - Expected: Then `required: false` で、`default: ""` である (index §3.1、CLAUDE.md の明示的デフォルト値)

---

## Coverage Check

| Source                                 | Task IDs                                                                               |
| -------------------------------------- | -------------------------------------------------------------------------------------- |
| R-IN-001                               | T-05-01-01, T-06-01-01                                                                 |
| R-IN-002 / DR-08                       | T-06-01-02, T-06-01-03, T-06-01-07, T-06-03-02, T-06-03-03, T-13-01-12                 |
| R-IN-003 / DD-IN-09                    | T-05-01-03, T-05-01-04, T-05-02-01..05, T-05-05-01, T-05-05-02, T-06-01-04, T-13-03-07 |
| R-IN-004 / DD-IN-02                    | T-09-01-02, T-09-03-01                                                                 |
| R-IN-005 / DD-IN-03                    | T-09-02-01, T-13-02-09, T-13-03-01                                                     |
| R-IN-006                               | T-09-01-01, T-09-01-03                                                                 |
| R-IN-007 / DR-04                       | T-06-03-01, T-09-03-02, T-13-03-08                                                     |
| R-IN-008 / DR-11                       | T-06-01-06, T-09-01-04, T-13-01-15                                                     |
| R-IN-009 / DD-IN-04                    | T-09-02-02, T-09-02-03, T-13-03-03                                                     |
| R-IN-010 / DD-IN-06                    | T-05-03-01, T-05-04-02, T-05-04-03, T-06-02-01, T-06-03-04                             |
| R-IN-011 / DD-IN-07                    | T-04-01-01..03, T-04-02-01..03, T-04-03-01..03, T-13-02-02                             |
| R-IN-012 / DD-IN-08                    | T-05-03-02, T-05-03-03, T-05-04-01, T-13-02-03, T-13-03-04                             |
| R-IN-013 / DD-IN-01                    | T-05-01-02, T-06-01-05, T-13-01-13                                                     |
| R-IN-014 / R-IN-015 / DD-IN-10 / DR-16 | T-08-01-01..03, T-08-02-01, T-08-02-02, T-08-03-01..03, T-13-02-04, T-13-02-05         |
| R-IN-016 / R-IN-017 / DD-IN-11 / DR-16 | T-07-01-01..03, T-07-02-01, T-07-02-02, T-07-03-01..03, T-13-02-06, T-13-02-07         |
| DD-IN-05 / DR-14 (最初の 1 件)         | T-04-03-02, T-05-04-01..03, T-09-03-03, T-13-03-05, T-13-03-06                         |
| R-MAT-001                              | T-10-04-01..03                                                                         |
| R-MAT-002                              | T-10-02-01, T-10-02-02                                                                 |
| R-MAT-003 / DD-MAT-01                  | T-10-02-03..05, T-10-02-08, T-10-02-09, T-10-06-05, T-10-06-06                         |
| R-MAT-004                              | T-10-02-06, T-10-02-07, T-10-06-01, T-10-06-02                                         |
| R-MAT-005 / DD-MAT-02                  | T-10-06-03, T-10-06-04, T-10-06-07..12                                                 |
| R-MAT-006 / DD-MAT-04                  | T-10-01-01, T-10-01-02, T-10-07-02, T-10-07-03                                         |
| R-MAT-007 / DD-MAT-05                  | T-10-03-01, T-10-03-02, T-10-07-01, T-11-03-06                                         |
| R-MAT-008 / DD-MAT-03 / DR-03          | T-10-05-01..08                                                                         |
| R-MAT-009 / DD-MAT-06 / REQ-NF-002     | T-10-07-04, T-11-03-03..05                                                             |
| R-MAT-010                              | T-11-01-03, T-11-01-04                                                                 |
| R-MAT-011 / DR-05                      | T-11-01-02, T-11-02-02                                                                 |
| R-MAT-012 / R-MAT-013                  | T-11-01-01, T-11-01-05, T-11-02-01                                                     |
| REQ-F-010 (入力順・重複)               | T-05-01-05, T-11-01-05, T-11-03-01                                                     |
| REQ-F-012 / DR-17                      | T-11-03-07, T-13-01-09                                                                 |
| R-OUT-001                              | T-12-03-01, T-13-02-01                                                                 |
| R-OUT-002                              | T-12-03-02, T-12-03-03, T-13-02-08                                                     |
| R-OUT-003 / DD-OUT-03                  | T-12-01-01, T-12-01-02                                                                 |
| R-OUT-004                              | T-12-02-01, T-13-01-11                                                                 |
| R-OUT-005                              | T-12-01-01, T-12-04-02                                                                 |
| R-OUT-006 / DR-09                      | T-12-03-04, T-12-03-05                                                                 |
| R-OUT-010 / DD-OUT-06                  | T-02-02-01, T-02-02-02, T-02-03-01..06                                                 |
| R-OUT-011 / DD-OUT-01                  | T-02-05-01..05, T-12-04-01                                                             |
| R-OUT-012 / DD-OUT-02                  | T-02-06-01                                                                             |
| R-OUT-013 / DD-OUT-05                  | T-02-01-01..03, T-02-06-02, T-02-06-03                                                 |
| R-OUT-014                              | T-02-04-01                                                                             |
| R-OUT-020                              | T-01-02-01                                                                             |
| R-OUT-021 / DD-OUT-04                  | T-01-01-02, T-01-03-02, T-01-03-04, T-12-04-04                                         |
| R-OUT-022                              | T-01-01-01, T-01-03-01, T-01-03-03, T-01-04-01                                         |
| DR-13 (共有関数は何も出力しない)       | T-01-04-02, T-02-01-04, T-02-03-01, T-02-04-01                                         |
| index §3.3 / DR-15 (エラー形式)        | T-03-01-01..03, T-03-02-01, T-03-06-01..04                                             |
| index §3.3 (注入防止)                  | T-03-04-01                                                                             |
| index §3.4 / DD-IDX-02 (評価順序)      | T-13-03-01, T-13-03-05, T-13-03-06                                                     |
| index §5 (横断的なエッジケース)        | T-13-03-01..04                                                                         |
| REQ-C-006 (ロードガード、fail-first)   | T-03-03-01, T-03-03-02, T-03-05-01, T-03-07-01                                         |
| REQ-C-001 / REQ-C-005 (action.yml)     | T-14-01-01..04, T-14-02-01, T-14-03-01, T-14-03-02                                     |
| AC-001                                 | T-13-01-01                                                                             |
| AC-002                                 | T-13-01-02                                                                             |
| AC-003                                 | T-13-01-03                                                                             |
| AC-004                                 | T-13-01-04                                                                             |
| AC-005                                 | T-13-01-05..07                                                                         |
| AC-006                                 | T-13-01-08                                                                             |
| AC-007                                 | T-13-01-09                                                                             |
| AC-008 / AC-010                        | T-13-01-10, T-02-05-01                                                                 |
| AC-009                                 | T-13-01-11                                                                             |
| AC-011                                 | T-13-02-01                                                                             |
| AC-012                                 | T-13-01-12                                                                             |
| AC-013                                 | T-13-01-14, T-13-01-15                                                                 |
| AC-014                                 | T-13-01-13                                                                             |
| AC-015                                 | T-13-02-02                                                                             |
| AC-016                                 | T-13-02-03                                                                             |
| AC-017                                 | T-13-01-16, T-13-02-04, T-13-02-05                                                     |
| AC-018                                 | T-13-01-17, T-13-02-06, T-13-02-07                                                     |
| [UNCOVERED]                            | —                                                                                      |

## Category Balance

| Test Target | Normal | Error | Edge | Status |
| ----------- | ------ | ----- | ---- | ------ |
| T-01        | 2      | 5     | 2    | [OK]   |
| T-02        | 6      | 7     | 8    | [OK]   |
| T-03        | 6      | 2     | 5    | [OK]   |
| T-04        | 3      | 3     | 3    | [OK]   |
| T-05        | 10     | 6     | 3    | [OK]   |
| T-06        | 7      | 1     | 4    | [OK]   |
| T-07        | 3      | 2     | 3    | [OK]   |
| T-08        | 3      | 2     | 3    | [OK]   |
| T-09        | 4      | 3     | 5    | [OK]   |
| T-10        | 16     | 8     | 16   | [OK]   |
| T-11        | 5      | 2     | 7    | [OK]   |
| T-12        | 4      | 5     | 4    | [OK]   |
| T-13        | 17     | 9     | 9    | [OK]   |
| T-14        | 4      | 1     | 2    | [OK]   |
