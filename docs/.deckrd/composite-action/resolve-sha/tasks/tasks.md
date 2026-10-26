---
title: "Implementation Tasks"
module: "composite-action/resolve-sha"
status: Active
created: "2026-10-25 19:30:00"
source: specifications-index.md v2.1.1, implementation.md v1.1.3
---

<!-- cspell:words promisorx -->
<!-- textlint-disable ja-technical-writing/sentence-length -->
<!-- textlint-disable ja-technical-writing/max-comma -->
<!-- markdownlint-disable no-duplicate-heading line-length -->

> This document contains implementation tasks derived from specifications.
> Each task corresponds to a single unit test case (`It` block).

## Conventions

- Task ID (`T-XX-YY-ZZ`) は本書内の作業単位の ID とする。テストコードのケース名には、各タスクの `Test ID` (`T-RS-<略語>-NN`) を埋め込む。
- テストコードの分類 prefix は、`[正常]` → `[Normal]`、`[異常]` → `[Error]`、`[エッジケース]` → `[Edge]` と読み替える。
- エラーの検証では、`::error::` の接頭辞、対象、`(got: '<値>')` の部分を確かめる。問題を説明する文言は固定しない。
- git に依存するタスクは、`scripts/__tests__/helpers/git-fixture.sh` のフィクスチャを使う。shallow clone は `file://` の URL から作る。
- 空ツリー SHA は `4b825dc642cb6eb9a060e54bf8d69288fbee4904` を指す。

**関数ごとの実装上の詳細** (IPC の終了コード、NCC の stdout、RE の 2 つの形式、RSH の override 判定、EO のエラー対象) は、implementation.md §1.3 に従う。

---

## Task Summary

| Test Target                    | Scenarios | Cases | Status      |
| ------------------------------ | --------- | ----- | ----------- |
| T-01: VALIDATION_LIB_LOADED    | 3         | 4     | done        |
| T-02: validate_positive_int    | 4         | 14    | done        |
| T-03: write_output             | 4         | 9     | done        |
| T-04: rs_error                 | 4         | 9     | done        |
| T-05: normalize_commit_count   | 3         | 9     | done        |
| T-06: validate_override        | 6         | 16    | done        |
| T-07: is_partial_clone         | 5         | 10    | done        |
| T-08: is_commit                | 4         | 7     | done        |
| T-09: verify_commit            | 3         | 6     | done        |
| T-10: resolve_head_n           | 5         | 17    | done        |
| T-11: resolve_sha              | 6         | 34    | done        |
| T-12: emit_outputs             | 4         | 14    | done        |
| T-13: resolve-sha.sh (MAINF)   | 4         | 17    | done        |
| T-14: action.yml (ACT)         | 3         | 7     | done        |
| T-15: resolve-sha.lib.sh (RLG) | 3         | 4     | done        |

---

## T-01: VALIDATION_LIB_LOADED

対象: `.github/actions/_libs/validation.lib.sh` のロードガード (Test ID 略語: VLG)。テストファイルは `_libs/__tests__/unit/validation-load-guard.unit.spec.sh`。

### [正常] Normal Cases

#### T-01-01: validation.lib.sh を読み込む

- [x] **T-01-01-01**: 1 回目の読み込みでガード変数が設定される
  - Target: `validation.lib.sh`
  - Test ID: T-RS-VLG-01
  - Scenario: Given `VALIDATION_LIB_LOADED` が未設定, When `validation.lib.sh` を source する
  - Expected: Then `VALIDATION_LIB_LOADED` が `1` になり、`validate_symbol` が定義されている

- [x] **T-01-01-02**: 2 回目の読み込みでもエラーにならない
  - Target: `validation.lib.sh`
  - Test ID: T-RS-VLG-02
  - Scenario: Given `validation.lib.sh` を source 済み, When もう一度 source する
  - Expected: Then 終了コードは 0 で、stderr は空である

### [異常] Error Cases

#### T-01-02: 既存関数のエラー出力が変わらない

- [x] **T-01-02-01**: 既存の `validate_symbol` は従来どおりのエラーを出す
  - Target: `validate_symbol`
  - Test ID: T-RS-VLG-03
  - Scenario: Given `validation.lib.sh` を source 済み, When `validate_symbol "a b" field "^[a-z]+$"` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr に `::error::field:` で始まる従来形式のエラーが出る

### [エッジケース] Edge Cases

#### T-01-03: ガード変数が設定済みの状態で読み込む

- [x] **T-01-03-01**: ガード変数が設定済みなら関数を定義せずに戻る
  - Target: `validation.lib.sh`
  - Test ID: T-RS-VLG-04
  - Scenario: Given 新しいシェルで `VALIDATION_LIB_LOADED=1` を設定済み, When `validation.lib.sh` を source する
  - Expected: Then 終了コードは 0 で、`validate_positive_int` は定義されていない

---

## T-02: validate_positive_int

対象: `validate_positive_int <value> <max>` (VPI)。テストファイルは `_libs/__tests__/unit/validate-positive-int.unit.spec.sh`。以下の `<max>` はすべて `1000` とする。

### [正常] Normal Cases

#### T-02-01: 許容範囲の正整数

- [x] **T-02-01-01**: 最小値 1 を受け付ける
  - Target: `validate_positive_int`
  - Test ID: T-RS-VPI-01
  - Scenario: Given value が `"1"`, When `validate_positive_int "1" 1000` を呼ぶ
  - Expected: Then 終了コードは 0 である

- [x] **T-02-01-02**: 上限値 1000 を受け付ける
  - Target: `validate_positive_int`
  - Test ID: T-RS-VPI-02
  - Scenario: Given value が `"1000"`, When `validate_positive_int "1000" 1000` を呼ぶ
  - Expected: Then 終了コードは 0 である

### [異常] Error Cases

#### T-02-02: 形式が正整数ではない

- [x] **T-02-02-01**: 0 を拒否する
  - Target: `validate_positive_int`
  - Test ID: T-RS-VPI-03
  - Scenario: Given value が `"0"`, When `validate_positive_int "0" 1000` を呼ぶ
  - Expected: Then 終了コードは 0 以外である

- [x] **T-02-02-02**: 負数を拒否する
  - Target: `validate_positive_int`
  - Test ID: T-RS-VPI-04
  - Scenario: Given value が `"-1"`, When `validate_positive_int "-1" 1000` を呼ぶ
  - Expected: Then 終了コードは 0 以外である

- [x] **T-02-02-03**: 非数値を拒否する
  - Target: `validate_positive_int`
  - Test ID: T-RS-VPI-05
  - Scenario: Given value が `"abc"`, When `validate_positive_int "abc" 1000` を呼ぶ
  - Expected: Then 終了コードは 0 以外である

- [x] **T-02-02-04**: 先頭ゼロを拒否する
  - Target: `validate_positive_int`
  - Test ID: T-RS-VPI-06
  - Scenario: Given value が `"01"`, When `validate_positive_int "01" 1000` を呼ぶ
  - Expected: Then 終了コードは 0 以外である

- [x] **T-02-02-05**: 前の空白を拒否する
  - Target: `validate_positive_int`
  - Test ID: T-RS-VPI-07
  - Scenario: Given value が `" 2"`, When `validate_positive_int " 2" 1000` を呼ぶ
  - Expected: Then 終了コードは 0 以外である

- [x] **T-02-02-06**: 空文字列を拒否する
  - Target: `validate_positive_int`
  - Test ID: T-RS-VPI-08
  - Scenario: Given value が `""`, When `validate_positive_int "" 1000` を呼ぶ
  - Expected: Then 終了コードは 0 以外である

#### T-02-03: 上限を超える

- [x] **T-02-03-01**: 4 桁で上限を超える値を拒否する
  - Target: `validate_positive_int`
  - Test ID: T-RS-VPI-09
  - Scenario: Given value が `"1001"`, When `validate_positive_int "1001" 1000` を呼ぶ
  - Expected: Then 終了コードは 0 以外である

- [x] **T-02-03-02**: 不正な値でも stderr に何も出さない
  - Target: `validate_positive_int`
  - Test ID: T-RS-VPI-10
  - Scenario: Given value が `"1001"`, When `validate_positive_int "1001" 1000` を呼ぶ
  - Expected: Then stderr と stdout は空である (DR-26)

### [エッジケース] Edge Cases

#### T-02-04: 桁数による上限判定

- [x] **T-02-04-01**: 5 桁の最小値を桁数で拒否する
  - Target: `validate_positive_int`
  - Test ID: T-RS-VPI-11
  - Scenario: Given value が `"10000"`, When `validate_positive_int "10000" 1000` を呼ぶ
  - Expected: Then 終了コードは 0 以外である

- [x] **T-02-04-02**: 20 桁の数字列を拒否する
  - Target: `validate_positive_int`
  - Test ID: T-RS-VPI-12
  - Scenario: Given value が `"12345678901234567890"`, When `validate_positive_int` を呼ぶ
  - Expected: Then 終了コードは 0 以外である

- [x] **T-02-04-03**: 桁あふれで 1 となる値を拒否する
  - Target: `validate_positive_int`
  - Test ID: T-RS-VPI-13
  - Scenario: Given value が `"18446744073709551617"` (2^64+1), When `validate_positive_int` を呼ぶ
  - Expected: Then 終了コードは 0 以外である

- [x] **T-02-04-04**: 桁あふれで負となる値を拒否する
  - Target: `validate_positive_int`
  - Test ID: T-RS-VPI-14
  - Scenario: Given value が `"9223372036854775808"` (符号付き 64 bit の最大値 + 1), When `validate_positive_int` を呼ぶ
  - Expected: Then 終了コードは 0 以外である

---

## T-03: write_output

対象: `write_output <file> <key> <value>` (WO)。テストファイルは `_libs/__tests__/unit/write-output.unit.spec.sh`。

### [正常] Normal Cases

#### T-03-01: 出力先へ追記する

- [x] **T-03-01-01**: key=value を 1 行書く
  - Target: `write_output`
  - Test ID: T-RS-WO-01
  - Scenario: Given 空の一時ファイル, When `write_output "$file" before_sha abc` を呼ぶ
  - Expected: Then 終了コードは 0 で、ファイルの内容は `before_sha=abc` の 1 行である

- [x] **T-03-01-02**: 既存の内容を残して追記する
  - Target: `write_output`
  - Test ID: T-RS-WO-02
  - Scenario: Given `existing=1` の 1 行を持つ一時ファイル, When `write_output "$file" resolution event` を呼ぶ
  - Expected: Then ファイルは `existing=1`、`resolution=event` の順の 2 行である

### [異常] Error Cases

#### T-03-02: 不正な引数

- [x] **T-03-02-01**: 出力先が空なら終了コード 1
  - Target: `write_output`
  - Test ID: T-RS-WO-03
  - Scenario: Given file が `""`, When `write_output "" key value` を呼ぶ
  - Expected: Then 終了コードは 1 である

- [x] **T-03-02-02**: 値が LF を含むなら終了コード 1
  - Target: `write_output`
  - Test ID: T-RS-WO-04
  - Scenario: Given 値が `$'a\nb'`, When `write_output "$file" key "$value"` を呼ぶ
  - Expected: Then 終了コードは 1 で、ファイルは空のままである

- [x] **T-03-02-03**: 値が単独の CR を含むなら終了コード 1
  - Target: `write_output`
  - Test ID: T-RS-WO-05
  - Scenario: Given 値が `$'a\rb'`, When `write_output "$file" key "$value"` を呼ぶ
  - Expected: Then 終了コードは 1 で、ファイルは空のままである

#### T-03-03: 書き込みの失敗

- [x] **T-03-03-01**: 出力先がディレクトリなら終了コード 2
  - Target: `write_output`
  - Test ID: T-RS-WO-06
  - Scenario: Given file が既存のディレクトリのパス, When `write_output "$dir" key value` を呼ぶ
  - Expected: Then 終了コードは 2 である

- [x] **T-03-03-02**: 出力先の親ディレクトリが無いなら終了コード 2
  - Target: `write_output`
  - Test ID: T-RS-WO-07
  - Scenario: Given file が存在しないディレクトリ配下のパス, When `write_output "$file" key value` を呼ぶ
  - Expected: Then 終了コードは 2 である

- [x] **T-03-03-03**: 失敗時も stderr に何も出さない
  - Target: `write_output`
  - Test ID: T-RS-WO-08
  - Scenario: Given file が既存のディレクトリのパス, When `write_output "$dir" key value` を呼ぶ
  - Expected: Then stderr は空である (DR-26)

### [エッジケース] Edge Cases

#### T-03-04: 空の値

- [x] **T-03-04-01**: 空の値も key= として書く
  - Target: `write_output`
  - Test ID: T-RS-WO-09
  - Scenario: Given 空の一時ファイル, When `write_output "$file" key ""` を呼ぶ
  - Expected: Then 終了コードは 0 で、ファイルの内容は `key=` の 1 行である

---

## T-04: rs_error

対象: `rs_error <target> <problem> [<value>]` (RE)。テストファイルは `scripts/_libs/__tests__/unit/resolve-sha.unit.spec.sh` の RE グループ。

### [正常] Normal Cases

#### T-04-01: 値を渡した場合の通常の形式

- [x] **T-04-01-01**: 通常の形式で stderr に 1 行出す
  - Target: `rs_error`
  - Test ID: T-RS-RE-01
  - Scenario: Given target `commit-count`、problem `invalid`、value `0`, When `rs_error commit-count invalid 0` を呼ぶ
  - Expected: Then stderr は `::error::commit-count: invalid (got: '0')` の 1 行である

- [x] **T-04-01-02**: stdout には何も出さない
  - Target: `rs_error`
  - Test ID: T-RS-RE-02
  - Scenario: Given 任意の引数, When `rs_error commit-count invalid 0` を呼ぶ
  - Expected: Then stdout は空である

- [x] **T-04-01-03**: 空文字列の値は通常の形式で出す
  - Target: `rs_error`
  - Test ID: T-RS-RE-03
  - Scenario: Given value が `""` (引数として渡す), When `rs_error after-sha "one side only" ""` を呼ぶ
  - Expected: Then stderr は `(got: '')` で終わる 1 行である

#### T-04-02: 値を省略した場合の空の形式

- [x] **T-04-02-01**: 空の形式で出す
  - Target: `rs_error`
  - Test ID: T-RS-RE-04
  - Scenario: Given 値の引数を省略, When `rs_error GITHUB_EVENT_NAME empty` を呼ぶ
  - Expected: Then stderr は `::error::GITHUB_EVENT_NAME: value must not be empty` の 1 行である

### [異常] Error Cases

#### T-04-03: ワークフローコマンドの注入

- [x] **T-04-03-01**: LF とコマンドを含む値を 1 行に収める
  - Target: `rs_error`
  - Test ID: T-RS-RE-05
  - Scenario: Given value が `$'x\n::add-mask::secret'`, When `rs_error before-sha bad "$value"` を呼ぶ
  - Expected: Then stderr は 1 行だけで、`::add-mask::` で始まる行は無い

### [エッジケース] Edge Cases

#### T-04-04: 値のエンコード

- [x] **T-04-04-01**: `%` を `%25` にする
  - Target: `rs_error`
  - Test ID: T-RS-RE-06
  - Scenario: Given value が `a%b`, When `rs_error t p "a%b"` を呼ぶ
  - Expected: Then stderr に `(got: 'a%25b')` が含まれる

- [x] **T-04-04-02**: CR を `%0D` にする
  - Target: `rs_error`
  - Test ID: T-RS-RE-07
  - Scenario: Given value が `$'a\rb'`, When `rs_error t p "$value"` を呼ぶ
  - Expected: Then stderr に `(got: 'a%0Db')` が含まれる

- [x] **T-04-04-03**: LF を `%0A` にする
  - Target: `rs_error`
  - Test ID: T-RS-RE-08
  - Scenario: Given value が `$'a\nb'`, When `rs_error t p "$value"` を呼ぶ
  - Expected: Then stderr に `(got: 'a%0Ab')` が含まれる

- [x] **T-04-04-04**: 既にエンコード済みに見える値は `%` から先に置き換える
  - Target: `rs_error`
  - Test ID: T-RS-RE-09
  - Scenario: Given value が `%0A` (文字列), When `rs_error t p "%0A"` を呼ぶ
  - Expected: Then stderr に `(got: '%250A')` が含まれる

---

## T-05: normalize_commit_count

対象: `normalize_commit_count <value>` (NCC)。R-IN-001 から R-IN-003。テストファイルは `scripts/_libs/__tests__/unit/resolve-sha.unit.spec.sh` の NCC グループ。

### [正常] Normal Cases

#### T-05-01: commit-count を確定する

- [x] **T-05-01-01**: 空文字列は既定値 1 にする
  - Target: `normalize_commit_count`
  - Test ID: T-RS-NCC-01
  - Scenario: Given value が `""`, When `normalize_commit_count ""` を呼ぶ
  - Expected: Then stdout は `1` で、終了コードは 0 である (R-IN-001, DD-IN-02)

- [x] **T-05-01-02**: 有効な値はそのまま確定する
  - Target: `normalize_commit_count`
  - Test ID: T-RS-NCC-02
  - Scenario: Given value が `"3"`, When `normalize_commit_count "3"` を呼ぶ
  - Expected: Then stdout は `3` で、終了コードは 0 である

- [x] **T-05-01-03**: 上限値 1000 を確定する
  - Target: `normalize_commit_count`
  - Test ID: T-RS-NCC-03
  - Scenario: Given value が `"1000"`, When `normalize_commit_count "1000"` を呼ぶ
  - Expected: Then stdout は `1000` で、終了コードは 0 である (AC-020)

### [異常] Error Cases

#### T-05-02: 不正な commit-count

- [x] **T-05-02-01**: 0 はエラーになる
  - Target: `normalize_commit_count`
  - Test ID: T-RS-NCC-04
  - Scenario: Given value が `"0"`, When `normalize_commit_count "0"` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::commit-count:` で始まり `(got: '0')` で終わる (R-IN-002)

- [x] **T-05-02-02**: 4 桁で上限を超える値はエラーになる
  - Target: `normalize_commit_count`
  - Test ID: T-RS-NCC-05
  - Scenario: Given value が `"1001"`, When `normalize_commit_count "1001"` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr に `(got: '1001')` が含まれる

- [x] **T-05-02-03**: 先頭ゼロはエラーになる
  - Target: `normalize_commit_count`
  - Test ID: T-RS-NCC-06
  - Scenario: Given value が `"01"`, When `normalize_commit_count "01"` を呼ぶ
  - Expected: Then 終了コードは 0 以外である

- [x] **T-05-02-04**: エラー時は stdout に何も出さない
  - Target: `normalize_commit_count`
  - Test ID: T-RS-NCC-07
  - Scenario: Given value が `"abc"`, When `normalize_commit_count "abc"` を呼ぶ
  - Expected: Then stdout は空である

### [エッジケース] Edge Cases

#### T-05-03: 空文字列以外の未指定に見える値

- [x] **T-05-03-01**: 空白のみの値はエラーになる (既定値を使わない)
  - Target: `normalize_commit_count`
  - Test ID: T-RS-NCC-08
  - Scenario: Given value が `"   "`, When `normalize_commit_count "   "` を呼ぶ
  - Expected: Then 終了コードは 0 以外である

- [x] **T-05-03-02**: 20 桁の数字列はエラーになる
  - Target: `normalize_commit_count`
  - Test ID: T-RS-NCC-09
  - Scenario: Given value が `"18446744073709551617"`, When `normalize_commit_count` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stdout は空である

---

## T-06: validate_override

対象: `validate_override <before> <after>` (VOV)。R-IN-004 から R-IN-007。テストファイルは `scripts/_libs/__tests__/unit/resolve-sha.unit.spec.sh` の VOV グループ。以下の「有効 OID」は 40 桁の小文字 16 進とする (存在は問わない)。

### [正常] Normal Cases

#### T-06-01: オーバーライドの判定

- [x] **T-06-01-01**: 両方が空なら none
  - Target: `validate_override`
  - Test ID: T-RS-VOV-01
  - Scenario: Given before と after がどちらも `""`, When `validate_override "" ""` を呼ぶ
  - Expected: Then stdout は `none` で、終了コードは 0 である (R-IN-005)

- [x] **T-06-01-02**: 両方が有効 OID なら override
  - Target: `validate_override`
  - Test ID: T-RS-VOV-02
  - Scenario: Given before と after が異なる有効 OID, When `validate_override` を呼ぶ
  - Expected: Then stdout は `override` で、終了コードは 0 である (R-IN-007)

### [異常] Error Cases

#### T-06-02: 片方のみの指定

- [x] **T-06-02-01**: before のみ指定はエラーで、対象は after-sha
  - Target: `validate_override`
  - Test ID: T-RS-VOV-03
  - Scenario: Given before が有効 OID、after が `""`, When `validate_override` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::after-sha:` で始まる (R-IN-004)

- [x] **T-06-02-02**: after のみ指定はエラーで、対象は before-sha
  - Target: `validate_override`
  - Test ID: T-RS-VOV-04
  - Scenario: Given before が `""`、after が有効 OID, When `validate_override` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::before-sha:` で始まる (R-IN-004)

#### T-06-03: 形式の不一致

- [x] **T-06-03-01**: リビジョン式を拒否する
  - Target: `validate_override`
  - Test ID: T-RS-VOV-05
  - Scenario: Given before が `HEAD~1`、after が有効 OID, When `validate_override` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::before-sha:` で始まり `(got: 'HEAD~1')` を含む (R-IN-006)

- [x] **T-06-03-02**: 7 桁の短縮 SHA を拒否する
  - Target: `validate_override`
  - Test ID: T-RS-VOV-06
  - Scenario: Given before が 7 桁の 16 進、after が有効 OID, When `validate_override` を呼ぶ
  - Expected: Then 終了コードは 0 以外である

- [x] **T-06-03-03**: 大文字を含む 40 桁を拒否する
  - Target: `validate_override`
  - Test ID: T-RS-VOV-07
  - Scenario: Given before が大文字を含む 40 桁、after が有効 OID, When `validate_override` を呼ぶ
  - Expected: Then 終了コードは 0 以外である

- [x] **T-06-03-04**: after 側の形式違反は after-sha を対象にする
  - Target: `validate_override`
  - Test ID: T-RS-VOV-08
  - Scenario: Given before が有効 OID、after が `HEAD`, When `validate_override` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::after-sha:` で始まる

- [x] **T-06-03-05**: エラー時は stdout に何も出さない
  - Target: `validate_override`
  - Test ID: T-RS-VOV-09
  - Scenario: Given before が `HEAD~1`、after が有効 OID, When `validate_override` を呼ぶ
  - Expected: Then stdout は空である

### [エッジケース] Edge Cases

#### T-06-04: 境界の組み合わせ

- [x] **T-06-04-01**: 同一の有効 OID の組を受け付ける
  - Target: `validate_override`
  - Test ID: T-RS-VOV-10
  - Scenario: Given before と after が同一の有効 OID, When `validate_override` を呼ぶ
  - Expected: Then stdout は `override` である

- [x] **T-06-04-02**: 片方のみで値も不正なら片方のみのエラーを優先する
  - Target: `validate_override`
  - Test ID: T-RS-VOV-11
  - Scenario: Given before が `HEAD~1`、after が `""`, When `validate_override` を呼ぶ
  - Expected: Then stderr は `::error::after-sha:` で始まる 1 行だけである (R-IN-004 が R-IN-006 より先)

- [x] **T-06-04-03**: 空白のみの値は指定ありとして形式エラーにする
  - Target: `validate_override`
  - Test ID: T-RS-VOV-12
  - Scenario: Given before が `"  "`、after が有効 OID, When `validate_override` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::before-sha:` で始まる

#### T-06-05: OID の長さと文字種の境界

- [x] **T-06-05-01**: 39 桁の小文字 16 進を拒否する
  - Target: `validate_override`
  - Test ID: T-RS-VOV-13
  - Scenario: Given before が 39 桁の小文字 16 進、after が有効 OID, When `validate_override` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::before-sha:` で始まる (R-IN-006)

- [x] **T-06-05-02**: 41 桁の小文字 16 進を拒否する
  - Target: `validate_override`
  - Test ID: T-RS-VOV-14
  - Scenario: Given before が 41 桁の小文字 16 進、after が有効 OID, When `validate_override` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::before-sha:` で始まる (R-IN-006)

- [x] **T-06-05-03**: 16 進でない文字を含む 40 桁を拒否する
  - Target: `validate_override`
  - Test ID: T-RS-VOV-15
  - Scenario: Given before が `g` を 1 文字含む 40 桁、after が有効 OID, When `validate_override` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::before-sha:` で始まる (R-IN-006)

#### T-06-06: 両方の形式が不正

- [x] **T-06-06-01**: 両方とも形式違反なら before-sha を先に報告する
  - Target: `validate_override`
  - Test ID: T-RS-VOV-16
  - Scenario: Given before が `HEAD~1`、after が `HEAD`, When `validate_override` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::before-sha:` で始まる 1 行だけである (R-IN-006。before を先に検査する)

---

## T-07: is_partial_clone

対象: `is_partial_clone` (IPC)。作業ディレクトリのリポジトリを判定する。R-RES-008、R-RES-010。テストファイルは `scripts/_libs/__tests__/unit/resolve-sha.unit.spec.sh` の IPC グループ。

### [正常] Normal Cases

#### T-07-01: partial clone ではない

- [x] **T-07-01-01**: 通常の clone は該当なし
  - Target: `is_partial_clone`
  - Test ID: T-RS-IPC-01
  - Scenario: Given 通常の clone を作業ディレクトリとする, When `is_partial_clone` を呼ぶ
  - Expected: Then 終了コードは 1 である

- [x] **T-07-01-02**: shallow clone は該当なし
  - Target: `is_partial_clone`
  - Test ID: T-RS-IPC-02
  - Scenario: Given `--depth 2` の shallow clone を作業ディレクトリとする, When `is_partial_clone` を呼ぶ
  - Expected: Then 終了コードは 1 である

#### T-07-02: partial clone である

- [x] **T-07-02-01**: promisor remote を持つ clone は該当あり
  - Target: `is_partial_clone`
  - Test ID: T-RS-IPC-03
  - Scenario: Given `--filter=blob:none` の clone を作業ディレクトリとする, When `is_partial_clone` を呼ぶ
  - Expected: Then 終了コードは 0 である

### [異常] Error Cases

#### T-07-03: 設定の参照に失敗する

- [x] **T-07-03-01**: 設定ファイルが壊れていれば終了コード 2
  - Target: `is_partial_clone`
  - Test ID: T-RS-IPC-04
  - Scenario: Given `.git/config` の末尾に不正な行を追記したリポジトリ, When `is_partial_clone` を呼ぶ
  - Expected: Then 終了コードは 2 である (R-RES-010)

- [x] **T-07-03-02**: 判定に失敗しても stderr に何も出さない
  - Target: `is_partial_clone`
  - Test ID: T-RS-IPC-05
  - Scenario: Given `.git/config` が壊れたリポジトリ, When `is_partial_clone` を呼ぶ
  - Expected: Then stderr は空である

- [x] **T-07-03-03**: 設定ファイルを読み取れなければ終了コード 2
  - Target: `is_partial_clone`
  - Test ID: T-RS-IPC-10
  - Scenario: Given `.git/config` の権限を `000` にした通常の clone, When `is_partial_clone` を呼ぶ
  - Expected: Then 終了コードは 2 で、stdout と stderr は空である (R-RES-010。root で実行する場合は権限が効かないため対象外とする)

### [エッジケース] Edge Cases

#### T-07-04: 判定の境界

- [x] **T-07-04-01**: `extensions.partialClone` だけの設定も該当あり
  - Target: `is_partial_clone`
  - Test ID: T-RS-IPC-06
  - Scenario: Given 通常の clone に `extensions.partialClone=origin` だけを設定, When `is_partial_clone` を呼ぶ
  - Expected: Then 終了コードは 0 である

- [x] **T-07-04-02**: git リポジトリでないディレクトリは該当なし
  - Target: `is_partial_clone`
  - Test ID: T-RS-IPC-07
  - Scenario: Given git リポジトリでない一時ディレクトリを作業ディレクトリとする, When `is_partial_clone` を呼ぶ
  - Expected: Then 終了コードは 1 である (後続の検証でエラーになる)

#### T-07-05: 設定キーの境界

- [x] **T-07-05-01**: origin 以外の名前の promisor remote も該当あり
  - Target: `is_partial_clone`
  - Test ID: T-RS-IPC-08
  - Scenario: Given 通常の clone に `remote.upstream.promisor=true` だけを設定, When `is_partial_clone` を呼ぶ
  - Expected: Then 終了コードは 0 である (R-RES-008。remote 名を問わない)

- [x] **T-07-05-02**: promisor に似た別のキーは該当なし
  - Target: `is_partial_clone`
  - Test ID: T-RS-IPC-09
  - Scenario: Given 通常の clone に `remote.origin.promisorx=true` だけを設定, When `is_partial_clone` を呼ぶ
  - Expected: Then 終了コードは 1 である (キーを完全一致で判定する)

---

## T-08: is_commit

対象: `is_commit <sha>` (IC)。エラーを出さないコミット存在の確認。テストファイルは `scripts/_libs/__tests__/unit/resolve-sha.unit.spec.sh` の IC グループ。

### [正常] Normal Cases

#### T-08-01: 存在するコミット

- [x] **T-08-01-01**: 存在するコミットは 0
  - Target: `is_commit`
  - Test ID: T-RS-IC-01
  - Scenario: Given 2 コミットのリポジトリと、その HEAD の OID, When `is_commit "$head"` を呼ぶ
  - Expected: Then 終了コードは 0 である

### [異常] Error Cases

#### T-08-02: 存在しない値

- [x] **T-08-02-01**: 存在しない OID は 0 以外
  - Target: `is_commit`
  - Test ID: T-RS-IC-02
  - Scenario: Given リポジトリに存在しない有効形式の OID, When `is_commit` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は空である

- [x] **T-08-02-02**: 空文字列は 0 以外
  - Target: `is_commit`
  - Test ID: T-RS-IC-03
  - Scenario: Given sha が `""`, When `is_commit ""` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は空である

### [エッジケース] Edge Cases

#### T-08-03: コミットではないオブジェクト

- [x] **T-08-03-01**: 空ツリー SHA は 0 以外
  - Target: `is_commit`
  - Test ID: T-RS-IC-04
  - Scenario: Given sha が空ツリー SHA, When `is_commit` を呼ぶ
  - Expected: Then 終了コードは 0 以外である

- [x] **T-08-03-02**: 40 桁の 0 は 0 以外
  - Target: `is_commit`
  - Test ID: T-RS-IC-05
  - Scenario: Given sha が 40 桁の `0`, When `is_commit` を呼ぶ
  - Expected: Then 終了コードは 0 以外である

#### T-08-04: 実在するがコミットではないオブジェクトと作業ディレクトリ

- [x] **T-08-04-01**: 実在するツリーの OID は 0 以外
  - Target: `is_commit`
  - Test ID: T-RS-IC-06
  - Scenario: Given 2 コミットのリポジトリと、その HEAD のツリーの OID (`HEAD^{tree}`), When `is_commit "$tree"` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stdout と stderr は空である

- [x] **T-08-04-02**: git リポジトリでないディレクトリでは 0 以外
  - Target: `is_commit`
  - Test ID: T-RS-IC-07
  - Scenario: Given git リポジトリでない一時ディレクトリを作業ディレクトリとし、有効形式の OID を渡す, When `is_commit` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stdout と stderr は空である

---

## T-09: verify_commit

対象: `verify_commit <sha> <field>` (VC)。R-RES-021、R-RES-024、R-RES-025。テストファイルは `scripts/_libs/__tests__/unit/resolve-sha.unit.spec.sh` の VC グループ。

### [正常] Normal Cases

#### T-09-01: 検証に成功する

- [x] **T-09-01-01**: 存在するコミットは成功し、何も出さない
  - Target: `verify_commit`
  - Test ID: T-RS-VC-01
  - Scenario: Given 存在するコミットの OID, When `verify_commit "$sha" GITHUB_BASE_SHA` を呼ぶ
  - Expected: Then 終了コードは 0 で、stderr は空である (R-RES-025)

### [異常] Error Cases

#### T-09-02: 検証に失敗する

- [x] **T-09-02-01**: 空の値は空の形式でエラー
  - Target: `verify_commit`
  - Test ID: T-RS-VC-02
  - Scenario: Given sha が `""`, When `verify_commit "" GITHUB_HEAD_SHA` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::GITHUB_HEAD_SHA: value must not be empty` である (R-RES-021)

- [x] **T-09-02-02**: 存在しない OID は field を対象にエラー
  - Target: `verify_commit`
  - Test ID: T-RS-VC-03
  - Scenario: Given 存在しない有効形式の OID, When `verify_commit "$sha" before-sha` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::before-sha:` で始まり `(got: '<OID>')` を含む (R-RES-024)

### [エッジケース] Edge Cases

#### T-09-03: 空ツリー SHA は免除しない

- [x] **T-09-03-01**: before 側の空ツリー SHA もエラー
  - Target: `verify_commit`
  - Test ID: T-RS-VC-04
  - Scenario: Given sha が空ツリー SHA, When `verify_commit "$empty_tree" before-sha` を呼ぶ
  - Expected: Then 終了コードは 0 以外である (DR-24、DD-RES-07)

- [x] **T-09-03-02**: after 側の空ツリー SHA もエラー
  - Target: `verify_commit`
  - Test ID: T-RS-VC-05
  - Scenario: Given sha が空ツリー SHA, When `verify_commit "$empty_tree" after-sha` を呼ぶ
  - Expected: Then 終了コードは 0 以外である

- [x] **T-09-03-03**: エラー時は stdout に何も出さない
  - Target: `verify_commit`
  - Test ID: T-RS-VC-06
  - Scenario: Given 存在しない有効形式の OID, When `verify_commit "$sha" before-sha` を呼ぶ
  - Expected: Then stdout は空である

---

## T-10: resolve_head_n

対象: `resolve_head_n <n>` (RHN)。R-RES-011 から R-RES-015。stdout は `<before> <after> <resolution>` の 1 行。テストファイルは `scripts/_libs/__tests__/unit/resolve-sha.unit.spec.sh` の RHN グループ。

### [正常] Normal Cases

#### T-10-01: HEAD~N を解決できる

- [x] **T-10-01-01**: 直線履歴で N=1 を解決する
  - Target: `resolve_head_n`
  - Test ID: T-RS-RHN-01
  - Scenario: Given 5 コミットの直線履歴, When `resolve_head_n 1` を呼ぶ
  - Expected: Then stdout は `<HEAD~1> <HEAD> fallback-head-n` である (R-RES-012)

- [x] **T-10-01-02**: 履歴がちょうど N+1 コミットなら解決する
  - Target: `resolve_head_n`
  - Test ID: T-RS-RHN-02
  - Scenario: Given 5 コミットの直線履歴, When `resolve_head_n 4` を呼ぶ
  - Expected: Then stdout は `<HEAD~4> <HEAD> fallback-head-n` である

- [x] **T-10-01-03**: merge コミットでは第一親をたどる
  - Target: `resolve_head_n`
  - Test ID: T-RS-RHN-03
  - Scenario: Given HEAD が merge コミットで第一親が P1, When `resolve_head_n 1` を呼ぶ
  - Expected: Then before は P1 の OID である (AC-014、DD-RES-05)

- [x] **T-10-01-04**: after は解決した HEAD の完全長 OID である
  - Target: `resolve_head_n`
  - Test ID: T-RS-RHN-04
  - Scenario: Given 3 コミットの直線履歴, When `resolve_head_n 1` を呼ぶ
  - Expected: Then after は `git rev-parse HEAD` の値と一致する 40 桁である

### [異常] Error Cases

#### T-10-02: HEAD を解決できない

- [x] **T-10-02-01**: git リポジトリでない場合はエラー
  - Target: `resolve_head_n`
  - Test ID: T-RS-RHN-05
  - Scenario: Given git リポジトリでない作業ディレクトリ, When `resolve_head_n 1` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::HEAD:` で始まり、stdout は空である (R-RES-011)

- [x] **T-10-02-02**: コミットが無いリポジトリはエラー
  - Target: `resolve_head_n`
  - Test ID: T-RS-RHN-06
  - Scenario: Given `git init` 直後のリポジトリ, When `resolve_head_n 1` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::HEAD:` で始まる (REQ-F-014)

- [x] **T-10-02-03**: git が信頼しない作業ディレクトリはエラー
  - Target: `resolve_head_n`
  - Test ID: T-RS-RHN-17
  - Scenario: Given 1 コミットのリポジトリを、`GIT_TEST_ASSUME_DIFFERENT_OWNER=1` (git が所有者の異なるディレクトリとして扱う) で作業ディレクトリとする, When `resolve_head_n 1` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::HEAD:` で始まる 1 行だけで、stdout は空である (R-RES-011。git が作業ディレクトリを信頼しない場合)

#### T-10-03: 祖先オブジェクトの欠損

- [x] **T-10-03-01**: 履歴があるのに HEAD~N を解決できない場合はエラー
  - Target: `resolve_head_n`
  - Test ID: T-RS-RHN-07
  - Scenario: Given 5 コミットの直線履歴から HEAD~2 のオブジェクトを削除, When `resolve_head_n 3` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::HEAD~N:` で始まり、空ツリー SHA は出力されない (R-RES-013 または R-RES-015、AC-010)

### [エッジケース] Edge Cases

#### T-10-04: 履歴不足を空ツリーに分類する

- [x] **T-10-04-01**: 初回コミットのみで N=1 は empty-tree
  - Target: `resolve_head_n`
  - Test ID: T-RS-RHN-08
  - Scenario: Given 1 コミットのリポジトリ, When `resolve_head_n 1` を呼ぶ
  - Expected: Then stdout は `<空ツリー SHA> <HEAD> empty-tree` である (R-RES-014)

- [x] **T-10-04-02**: 初回コミットのみで N=3 は empty-tree
  - Target: `resolve_head_n`
  - Test ID: T-RS-RHN-09
  - Scenario: Given 1 コミットのリポジトリ, When `resolve_head_n 3` を呼ぶ
  - Expected: Then resolution は `empty-tree` で、終了コードは 0 である (AC-006)

- [x] **T-10-04-03**: 2 コミットで N=3 は empty-tree
  - Target: `resolve_head_n`
  - Test ID: T-RS-RHN-10
  - Scenario: Given 2 コミットのリポジトリ, When `resolve_head_n 3` を呼ぶ
  - Expected: Then resolution は `empty-tree` である (AC-011)

- [x] **T-10-04-04**: depth 3 の shallow clone で N=2 は解決する
  - Target: `resolve_head_n`
  - Test ID: T-RS-RHN-11
  - Scenario: Given 5 コミットの元リポジトリから `file://` で作った depth 3 の shallow clone, When `resolve_head_n 2` を呼ぶ
  - Expected: Then resolution は `fallback-head-n` で、before は HEAD~2 である (AC-012)

- [x] **T-10-04-05**: depth 2 の shallow clone で N=2 は empty-tree
  - Target: `resolve_head_n`
  - Test ID: T-RS-RHN-12
  - Scenario: Given 5 コミットの元リポジトリから `file://` で作った depth 2 の shallow clone, When `resolve_head_n 2` を呼ぶ
  - Expected: Then resolution は `empty-tree` である (AC-012)

- [x] **T-10-04-06**: merge で第一親の系列が shallow 境界に達する場合は empty-tree
  - Target: `resolve_head_n`
  - Test ID: T-RS-RHN-13
  - Scenario: Given HEAD が merge コミットの depth 2 の shallow clone, When `resolve_head_n 2` を呼ぶ
  - Expected: Then resolution は `empty-tree` である (resolution §5)

- [x] **T-10-04-07**: merge で第二親の系列だけが shallow 境界に達する場合は解決する
  - Target: `resolve_head_n`
  - Test ID: T-RS-RHN-14
  - Scenario: Given 第一親の系列が 3 世代、第二親の系列がより長い merge を HEAD とする depth 3 の shallow clone, When `resolve_head_n 2` を呼ぶ
  - Expected: Then resolution は `fallback-head-n` で、before は第一親を 2 世代たどったコミットである (resolution §5)

### [異常] Error Cases (git の出力をモックする)

#### T-10-05: 世代数の分類で異常を検出する

本物のリポジトリでは「HEAD~N を解決できないが世代数は取得できて N を超える」状態や「世代数が数値でない」状態を作れないため、テスト内で `git` を関数でモックする。モックは `rev-parse` の HEAD の解決だけを成功させ、`<head>~N` の解決を失敗させる。

- [x] **T-10-05-01**: 世代数が N を超えるのに HEAD~N を解決できない場合はエラー
  - Target: `resolve_head_n`
  - Test ID: T-RS-RHN-15
  - Scenario: Given `git rev-list --first-parent --count` が `5` を返すモック, When `resolve_head_n 2` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::HEAD~N:` で始まる 1 行だけで、stdout は空である (R-RES-015)

- [x] **T-10-05-02**: 世代数が数値でなければエラー
  - Target: `resolve_head_n`
  - Test ID: T-RS-RHN-16
  - Scenario: Given `git rev-list --first-parent --count` が終了コード 0 で `abc` を返すモック, When `resolve_head_n 2` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::HEAD~N:` で始まる 1 行だけで、stdout は空である (R-RES-013)

---

## T-11: resolve_sha

対象: `resolve_sha <event> <n> <ov_before> <ov_after> <ev_before> <ev_after> <base> <head> <ref> <deleted>` (RSH)。R-RES-001 から R-RES-010。stdout は `<before> <after> <resolution>` の 1 行。テストファイルは `scripts/_libs/__tests__/unit/resolve-sha.unit.spec.sh` の RSH グループ。

特記の無い限り、ref は `refs/heads/main`、deleted は `false`、N は 1、オーバーライドは両方空、作業ディレクトリは 5 コミットの直線履歴とする。

### [正常] Normal Cases

#### T-11-01: イベント別の経路

- [x] **T-11-01-01**: push で before が存在すれば event
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-01
  - Scenario: Given event `push`、ev_before が HEAD~2、ev_after が HEAD, When `resolve_sha` を呼ぶ
  - Expected: Then stdout は `<HEAD~2> <HEAD> event` である (R-RES-005、AC-001)

- [x] **T-11-01-02**: pull_request は base と head をそのまま使う
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-02
  - Scenario: Given event `pull_request`、base が HEAD~3、head が HEAD~1, When `resolve_sha` を呼ぶ
  - Expected: Then stdout は `<HEAD~3> <HEAD~1> event` である (R-RES-006、AC-002)

- [x] **T-11-01-03**: workflow_dispatch は HEAD~N で解決する
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-03
  - Scenario: Given event `workflow_dispatch`, When `resolve_sha` を呼ぶ
  - Expected: Then stdout は `<HEAD~1> <HEAD> fallback-head-n` である (R-RES-007、AC-003)

- [x] **T-11-01-04**: pull_request_target はその他イベントとして扱う
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-04
  - Scenario: Given event `pull_request_target`、base と head に存在しない OID, When `resolve_sha` を呼ぶ
  - Expected: Then resolution は `fallback-head-n` である (R-RES-007、DR-06)

#### T-11-02: push のフォールバック

- [x] **T-11-02-01**: before が空なら HEAD~N
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-05
  - Scenario: Given event `push`、N=2、ev_before が `""`, When `resolve_sha` を呼ぶ
  - Expected: Then stdout は `<HEAD~2> <HEAD> fallback-head-n` である (R-RES-003、AC-005)

- [x] **T-11-02-02**: before が 40 桁の 0 なら HEAD~N
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-06
  - Scenario: Given event `push`、N=2、ev_before が 40 桁の `0`, When `resolve_sha` を呼ぶ
  - Expected: Then resolution は `fallback-head-n` である (R-RES-003、AC-005)

- [x] **T-11-02-03**: before が存在しないなら HEAD~N
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-07
  - Scenario: Given event `push`、N=2、ev_before が存在しない有効形式の OID, When `resolve_sha` を呼ぶ
  - Expected: Then resolution は `fallback-head-n` で、stderr は空である (R-RES-004、AC-005)

#### T-11-03: オーバーライド

- [x] **T-11-03-01**: 両方指定なら override
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-08
  - Scenario: Given event `push`、ov_before が HEAD~2、ov_after が HEAD, When `resolve_sha` を呼ぶ
  - Expected: Then stdout は `<HEAD~2> <HEAD> override` である (R-RES-002、AC-007)

### [異常] Error Cases

#### T-11-04: 検査の段階でのエラー

- [x] **T-11-04-01**: イベント名が空ならエラー
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-09
  - Scenario: Given event `""`, When `resolve_sha` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::GITHUB_EVENT_NAME: value must not be empty`、stdout は空である (R-RES-001)

- [x] **T-11-04-02**: オーバーライドがあってもイベント名が空ならエラー
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-10
  - Scenario: Given event `""`、オーバーライドが両方とも存在するコミット, When `resolve_sha` を呼ぶ
  - Expected: Then stderr は `::error::GITHUB_EVENT_NAME:` で始まる (DR-17、DD-RES-08)

- [x] **T-11-04-03**: タグの作成・移動の push はエラー
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-11
  - Scenario: Given event `push`、ref `refs/tags/v1.0.0`、deleted `false`, When `resolve_sha` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::GITHUB_REF:` で始まる (R-RES-009、AC-019)

- [x] **T-11-04-04**: タグの削除は削除のエラーを出す
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-12
  - Scenario: Given event `push`、ref `refs/tags/v1.0.0`、deleted `true`, When `resolve_sha` を呼ぶ
  - Expected: Then stderr は `::error::GITHUB_EVENT_DELETED:` で始まる 1 行だけである (R-RES-009、削除を先に判定)

- [x] **T-11-04-05**: ブランチの削除はエラー
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-13
  - Scenario: Given event `push`、ref `refs/heads/main`、deleted `true`, When `resolve_sha` を呼ぶ
  - Expected: Then stderr は `::error::GITHUB_EVENT_DELETED:` で始まる (R-RES-009、AC-019)

- [x] **T-11-04-06**: partial clone はエラー
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-14
  - Scenario: Given 作業ディレクトリが `--filter=blob:none` の clone、event `workflow_dispatch`, When `resolve_sha` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::repository:` で始まる (R-RES-008)

- [x] **T-11-04-07**: オーバーライドがあっても partial clone はエラー
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-15
  - Scenario: Given 作業ディレクトリが partial clone、オーバーライドが両方とも有効 OID, When `resolve_sha` を呼ぶ
  - Expected: Then stderr は `::error::repository:` で始まる (index §5)

- [x] **T-11-04-08**: 設定ファイルが壊れていればエラー
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-16
  - Scenario: Given `.git/config` が壊れたリポジトリ、event `workflow_dispatch`, When `resolve_sha` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::repository:` で始まる (R-RES-010)

#### T-11-05: コミット検証でのエラー

- [x] **T-11-05-01**: オーバーライドの before が存在しなければエラー
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-17
  - Scenario: Given ov_before が存在しない有効形式の OID、ov_after が HEAD, When `resolve_sha` を呼ぶ
  - Expected: Then stderr は `::error::before-sha:` で始まる (R-RES-024、AC-009)

- [x] **T-11-05-02**: オーバーライドの after が存在しなければエラー
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-18
  - Scenario: Given ov_before が HEAD、ov_after が存在しない有効形式の OID, When `resolve_sha` を呼ぶ
  - Expected: Then stderr は `::error::after-sha:` で始まる (R-RES-024)

- [x] **T-11-05-03**: オーバーライドの before が空ツリー SHA ならエラー
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-19
  - Scenario: Given ov_before が空ツリー SHA、ov_after が HEAD, When `resolve_sha` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::before-sha:` で始まる (DR-24、AC-009)

- [x] **T-11-05-04**: オーバーライドの after が空ツリー SHA ならエラー
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-20
  - Scenario: Given ov_before が HEAD、ov_after が空ツリー SHA, When `resolve_sha` を呼ぶ
  - Expected: Then stderr は `::error::after-sha:` で始まる (AC-009)

- [x] **T-11-05-05**: push の通常解決で github.sha が空ならエラー
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-21
  - Scenario: Given event `push`、ev_before が HEAD~1、ev_after が `""`, When `resolve_sha` を呼ぶ
  - Expected: Then stderr は `::error::GITHUB_AFTER_SHA: value must not be empty` で、HEAD~N へフォールバックしない (R-RES-021)

- [x] **T-11-05-06**: push の通常解決で github.sha が存在しなければエラー
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-22
  - Scenario: Given event `push`、ev_before が HEAD~1、ev_after が存在しない有効形式の OID, When `resolve_sha` を呼ぶ
  - Expected: Then stderr は `::error::GITHUB_AFTER_SHA:` で始まる (R-RES-024)

- [x] **T-11-05-07**: pull_request の base が空ならエラー
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-23
  - Scenario: Given event `pull_request`、base が `""`、head が HEAD, When `resolve_sha` を呼ぶ
  - Expected: Then stderr は `::error::GITHUB_BASE_SHA: value must not be empty` である (R-RES-021)

- [x] **T-11-05-08**: pull_request の head が空ならエラー
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-24
  - Scenario: Given event `pull_request`、base が HEAD~1、head が `""`, When `resolve_sha` を呼ぶ
  - Expected: Then stderr は `::error::GITHUB_HEAD_SHA: value must not be empty` である

- [x] **T-11-05-09**: pull_request の base が存在しなければエラー
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-25
  - Scenario: Given event `pull_request`、base が存在しない有効形式の OID、head が HEAD, When `resolve_sha` を呼ぶ
  - Expected: Then stderr は `::error::GITHUB_BASE_SHA:` で始まる (R-RES-024)

- [x] **T-11-05-10**: pull_request の head が存在しなければエラー
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-26
  - Scenario: Given event `pull_request`、base が HEAD~1、head が存在しない有効形式の OID, When `resolve_sha` を呼ぶ
  - Expected: Then stderr は `::error::GITHUB_HEAD_SHA:` で始まる

### [エッジケース] Edge Cases

#### T-11-06: 適用範囲と順序の境界

- [x] **T-11-06-01**: オーバーライドがあればタグの push でも解決する
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-27
  - Scenario: Given event `push`、ref `refs/tags/v1.0.0`、オーバーライドが HEAD~1 と HEAD, When `resolve_sha` を呼ぶ
  - Expected: Then resolution が `override` となる (オーバーライド時に R-RES-009 を適用しない、DR-25)

- [x] **T-11-06-02**: push 以外のイベントは ref がタグでも解決する
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-28
  - Scenario: Given event `workflow_dispatch`、ref `refs/tags/v1.0.0`, When `resolve_sha` を呼ぶ
  - Expected: Then resolution は `fallback-head-n` である (R-RES-007)

- [x] **T-11-06-03**: 削除フラグが空のブランチ push は通過する
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-29
  - Scenario: Given event `push`、ref `refs/heads/main`、deleted `""`、ev_before が `""`, When `resolve_sha` を呼ぶ
  - Expected: Then resolution は `fallback-head-n` である (削除とみなすのは `true` だけ)

- [x] **T-11-06-04**: before と github.sha が同一でも event
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-30
  - Scenario: Given event `push`、ev_before と ev_after がどちらも HEAD, When `resolve_sha` を呼ぶ
  - Expected: Then stdout は `<HEAD> <HEAD> event` である

- [x] **T-11-06-05**: pull_request で base と head が両方不在なら base のエラーだけを出す
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-31
  - Scenario: Given event `pull_request`、base と head が存在しない有効形式の OID, When `resolve_sha` を呼ぶ
  - Expected: Then stderr は `::error::GITHUB_BASE_SHA:` で始まる 1 行だけである

- [x] **T-11-06-06**: オーバーライドの両方が不在なら before のエラーだけを出す
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-32
  - Scenario: Given ov_before と ov_after が存在しない有効形式の OID, When `resolve_sha` を呼ぶ
  - Expected: Then stderr は `::error::before-sha:` で始まる 1 行だけである

- [x] **T-11-06-07**: その他イベントで履歴が不足すれば empty-tree
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-33
  - Scenario: Given 作業ディレクトリが 1 コミットのリポジトリ、event `workflow_dispatch`、N=3, When `resolve_sha` を呼ぶ
  - Expected: Then stdout は `<空ツリー SHA> <HEAD> empty-tree` である (AC-006)

- [x] **T-11-06-08**: push で before が無効かつ履歴が不足すれば empty-tree
  - Target: `resolve_sha`
  - Test ID: T-RS-RSH-34
  - Scenario: Given 作業ディレクトリが 1 コミットのリポジトリ、event `push`、N=3、ev_before が 40 桁の `0`, When `resolve_sha` を呼ぶ
  - Expected: Then resolution は `empty-tree` である (AC-006)

---

## T-12: emit_outputs

対象: `emit_outputs <file> <before> <after> <resolution>` (EO)。R-OUT-001 から R-OUT-008。テストファイルは `scripts/_libs/__tests__/unit/resolve-sha.unit.spec.sh` の EO グループ。以下の before / after は有効 OID とする。

### [正常] Normal Cases

#### T-12-01: 3 つの出力を書く

- [x] **T-12-01-01**: 3 行を書いて成功する
  - Target: `emit_outputs`
  - Test ID: T-RS-EO-01
  - Scenario: Given 空の出力ファイル、resolution `event`, When `emit_outputs` を呼ぶ
  - Expected: Then 終了コードは 0 で、ファイルに `before_sha=`、`after_sha=`、`resolution=event` の 3 行がある (R-OUT-007)

- [x] **T-12-01-02**: 既存の内容を残して追記する
  - Target: `emit_outputs`
  - Test ID: T-RS-EO-02
  - Scenario: Given `existing=1` の 1 行を持つ出力ファイル, When `emit_outputs` を呼ぶ
  - Expected: Then ファイルの 1 行目は `existing=1` のままで、その後に 3 行が続く

### [異常] Error Cases

#### T-12-02: 事前検査の失敗

- [x] **T-12-02-01**: 出力先が空ならエラー
  - Target: `emit_outputs`
  - Test ID: T-RS-EO-03
  - Scenario: Given file が `""`, When `emit_outputs "" ...` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::GITHUB_OUTPUT: value must not be empty` である (R-OUT-003)

- [x] **T-12-02-02**: 出力先が書き込めなければエラーで、何も書かない
  - Target: `emit_outputs`
  - Test ID: T-RS-EO-04
  - Scenario: Given file が既存のディレクトリのパス, When `emit_outputs` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::GITHUB_OUTPUT:` で始まる (R-OUT-004)

- [x] **T-12-02-03**: before が LF を含めばエラーで、何も書かない
  - Target: `emit_outputs`
  - Test ID: T-RS-EO-05
  - Scenario: Given 空の出力ファイル、before が `$'a\nb'`, When `emit_outputs` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::before_sha:` で始まり、ファイルは空のままである (R-OUT-005)

- [x] **T-12-02-04**: after が単独の CR を含めばエラーで、何も書かない
  - Target: `emit_outputs`
  - Test ID: T-RS-EO-06
  - Scenario: Given 空の出力ファイル、after が `$'a\rb'`, When `emit_outputs` を呼ぶ
  - Expected: Then stderr は `::error::after_sha:` で始まり、ファイルは空のままである (R-OUT-005)

- [x] **T-12-02-05**: resolution が 4 値以外ならエラーで、何も書かない
  - Target: `emit_outputs`
  - Test ID: T-RS-EO-07
  - Scenario: Given 空の出力ファイル、resolution `bogus`, When `emit_outputs` を呼ぶ
  - Expected: Then stderr は `::error::resolution:` で始まり、ファイルは空のままである (R-OUT-006)

#### T-12-03: 書き出し中の失敗

- [x] **T-12-03-01**: 2 回目の書き込みが失敗したら直ちに止まり、1 件目が残る
  - Target: `emit_outputs`
  - Test ID: T-RS-EO-08
  - Scenario: Given 2 回目の呼び出しで終了コード 2 を返すよう `write_output` を差し替え, When `emit_outputs` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::after_sha:` で始まり、ファイルには `before_sha=` の 1 行だけがある (R-OUT-008、DR-18)

### [エッジケース] Edge Cases

#### T-12-04: resolution の 4 値

- [x] **T-12-04-01**: override を書く
  - Target: `emit_outputs`
  - Test ID: T-RS-EO-09
  - Scenario: Given resolution `override`, When `emit_outputs` を呼ぶ
  - Expected: Then ファイルに `resolution=override` がある

- [x] **T-12-04-02**: fallback-head-n を書く
  - Target: `emit_outputs`
  - Test ID: T-RS-EO-10
  - Scenario: Given resolution `fallback-head-n`, When `emit_outputs` を呼ぶ
  - Expected: Then ファイルに `resolution=fallback-head-n` がある

- [x] **T-12-04-03**: empty-tree と空ツリー SHA の before を書く
  - Target: `emit_outputs`
  - Test ID: T-RS-EO-11
  - Scenario: Given before が空ツリー SHA、resolution `empty-tree`, When `emit_outputs` を呼ぶ
  - Expected: Then ファイルに `before_sha=<空ツリー SHA>` と `resolution=empty-tree` がある

- [x] **T-12-04-04**: 大文字の resolution は拒否する
  - Target: `emit_outputs`
  - Test ID: T-RS-EO-12
  - Scenario: Given resolution `EVENT`, When `emit_outputs` を呼ぶ
  - Expected: Then 終了コードは 0 以外で、ファイルは空のままである (R-OUT-006)

- [x] **T-12-04-05**: 1 件目の値の改行も事前検査で止める
  - Target: `emit_outputs`
  - Test ID: T-RS-EO-13
  - Scenario: Given resolution が `$'event\n'`, When `emit_outputs` を呼ぶ
  - Expected: Then ファイルは空のままである (R-OUT-005 は最初の書き込み前に評価する)

- [x] **T-12-04-06**: 成功時は stderr に何も出さない
  - Target: `emit_outputs`
  - Test ID: T-RS-EO-14
  - Scenario: Given 空の出力ファイル、resolution `event`, When `emit_outputs` を呼ぶ
  - Expected: Then stderr は空である

---

## T-13: resolve-sha.sh (MAINF)

対象: `scripts/resolve-sha.sh` の `main` を、環境変数を設定して実行する (functional)。テストファイルは `scripts/__tests__/functional/resolve-sha.functional.spec.sh`。

特記の無い限り、作業ディレクトリは 5 コミットの直線履歴、`GITHUB_OUTPUT` は空の一時ファイル、`GITHUB_REF=refs/heads/main`、`GITHUB_EVENT_DELETED=false` とする。

### [正常] Normal Cases

#### T-13-01: 経路ごとに 3 つの出力を書く

- [x] **T-13-01-01**: workflow_dispatch で commit-count 未設定なら HEAD~1
  - Target: `resolve-sha.sh`
  - Test ID: T-RS-MAINF-01
  - Scenario: Given `GITHUB_EVENT_NAME=workflow_dispatch`、`INPUT_COMMIT_COUNT` は未設定, When スクリプトを実行する
  - Expected: Then 終了コードは 0 で、出力ファイルに `before_sha=<HEAD~1>`、`after_sha=<HEAD>`、`resolution=fallback-head-n` がある (AC-003、REQ-F-001)

- [x] **T-13-01-02**: push の通常解決
  - Target: `resolve-sha.sh`
  - Test ID: T-RS-MAINF-02
  - Scenario: Given `GITHUB_EVENT_NAME=push`、`GITHUB_BEFORE_SHA` が HEAD~2、`GITHUB_AFTER_SHA` が HEAD, When スクリプトを実行する
  - Expected: Then 出力ファイルに `resolution=event` と 3 行がそろう (AC-001)

- [x] **T-13-01-03**: pull_request
  - Target: `resolve-sha.sh`
  - Test ID: T-RS-MAINF-03
  - Scenario: Given `GITHUB_EVENT_NAME=pull_request`、`GITHUB_BASE_SHA` が HEAD~3、`GITHUB_HEAD_SHA` が HEAD, When スクリプトを実行する
  - Expected: Then 出力ファイルに `before_sha=<HEAD~3>` と `resolution=event` がある (AC-002)

- [x] **T-13-01-04**: オーバーライド
  - Target: `resolve-sha.sh`
  - Test ID: T-RS-MAINF-04
  - Scenario: Given `INPUT_BEFORE_SHA` が HEAD~2、`INPUT_AFTER_SHA` が HEAD、`GITHUB_EVENT_NAME=workflow_dispatch`, When スクリプトを実行する
  - Expected: Then 出力ファイルに `resolution=override` がある (AC-007)

### [異常] Error Cases

#### T-13-02: 検証の失敗では出力しない

- [x] **T-13-02-01**: 不正な commit-count
  - Target: `resolve-sha.sh`
  - Test ID: T-RS-MAINF-05
  - Scenario: Given `INPUT_COMMIT_COUNT=0`、`GITHUB_EVENT_NAME=push`, When スクリプトを実行する
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::commit-count:` で始まり、出力ファイルは空である (AC-004)

- [x] **T-13-02-02**: 3 つの不正が同時にあれば commit-count のエラーだけを出す
  - Target: `resolve-sha.sh`
  - Test ID: T-RS-MAINF-06
  - Scenario: Given `INPUT_COMMIT_COUNT=0`、`INPUT_BEFORE_SHA` のみ有効 OID、`GITHUB_EVENT_NAME=""`, When スクリプトを実行する
  - Expected: Then stderr は `::error::commit-count:` で始まる 1 行だけで、出力ファイルは空である (AC-022、REQ-F-003)

- [x] **T-13-02-03**: イベント名が空
  - Target: `resolve-sha.sh`
  - Test ID: T-RS-MAINF-07
  - Scenario: Given `GITHUB_EVENT_NAME=""`, When スクリプトを実行する
  - Expected: Then stderr は `::error::GITHUB_EVENT_NAME:` で始まり、出力ファイルは空である (AC-016)

- [x] **T-13-02-04**: イベント名が未設定
  - Target: `resolve-sha.sh`
  - Test ID: T-RS-MAINF-08
  - Scenario: Given `GITHUB_EVENT_NAME` を unset, When スクリプトを実行する
  - Expected: Then 終了コードは 0 以外で、出力ファイルは空である (AC-016)

- [x] **T-13-02-05**: partial clone ではエラーにし、git fetch を起動しない
  - Target: `resolve-sha.sh`
  - Test ID: T-RS-MAINF-09
  - Scenario: Given 作業ディレクトリが partial clone、`GITHUB_EVENT_NAME=workflow_dispatch`、`GIT_TRACE` をファイルに出力, When スクリプトを実行する
  - Expected: Then 終了コードは 0 以外で、`GIT_TRACE` の出力に `fetch` の実行が無く、出力ファイルは空である (AC-018)

- [x] **T-13-02-06**: タグの push
  - Target: `resolve-sha.sh`
  - Test ID: T-RS-MAINF-10
  - Scenario: Given `GITHUB_EVENT_NAME=push`、`GITHUB_REF=refs/tags/v1.0.0`, When スクリプトを実行する
  - Expected: Then stderr は `::error::GITHUB_REF:` で始まり、出力ファイルは空である (AC-019)

#### T-13-03: 出力先の異常

- [x] **T-13-03-01**: `GITHUB_OUTPUT` が未設定
  - Target: `resolve-sha.sh`
  - Test ID: T-RS-MAINF-11
  - Scenario: Given `GITHUB_OUTPUT` を unset、`GITHUB_EVENT_NAME=workflow_dispatch`, When スクリプトを実行する
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::GITHUB_OUTPUT:` で始まる (AC-021)

- [x] **T-13-03-02**: `GITHUB_OUTPUT` が書き込めない
  - Target: `resolve-sha.sh`
  - Test ID: T-RS-MAINF-12
  - Scenario: Given `GITHUB_OUTPUT` が既存のディレクトリのパス, When スクリプトを実行する
  - Expected: Then 終了コードは 0 以外で、stderr は `::error::GITHUB_OUTPUT:` で始まる (AC-021)

### [エッジケース] Edge Cases

#### T-13-04: 段階をまたぐ境界

- [x] **T-13-04-01**: 有効なオーバーライドでもイベント名が空ならエラー
  - Target: `resolve-sha.sh`
  - Test ID: T-RS-MAINF-13
  - Scenario: Given オーバーライドが HEAD~1 と HEAD、`GITHUB_EVENT_NAME=""`, When スクリプトを実行する
  - Expected: Then stderr は `::error::GITHUB_EVENT_NAME:` で始まる (index §5、AC-016)

- [x] **T-13-04-02**: 有効なオーバーライドならタグの push でも解決する
  - Target: `resolve-sha.sh`
  - Test ID: T-RS-MAINF-14
  - Scenario: Given オーバーライドが HEAD~1 と HEAD、`GITHUB_EVENT_NAME=push`、`GITHUB_REF=refs/tags/v1.0.0`, When スクリプトを実行する
  - Expected: Then 終了コードは 0 で、`resolution=override` がある (AC-019)

- [x] **T-13-04-03**: commit-count に LF が含まれてもエラーは 1 行
  - Target: `resolve-sha.sh`
  - Test ID: T-RS-MAINF-15
  - Scenario: Given `INPUT_COMMIT_COUNT=$'1\n::add-mask::x'`, When スクリプトを実行する
  - Expected: Then stderr は 1 行で、`%0A` を含む (index §3.3、§5)

- [x] **T-13-04-04**: 履歴不足では empty-tree で成功する
  - Target: `resolve-sha.sh`
  - Test ID: T-RS-MAINF-16
  - Scenario: Given 作業ディレクトリが 2 コミットのリポジトリ、`INPUT_COMMIT_COUNT=1000`、`GITHUB_EVENT_NAME=workflow_dispatch`, When スクリプトを実行する
  - Expected: Then 終了コードは 0 で、`before_sha=<空ツリー SHA>` と `resolution=empty-tree` がある (AC-020、AC-011)

- [x] **T-13-04-05**: 既存の出力ファイルの内容を残す
  - Target: `resolve-sha.sh`
  - Test ID: T-RS-MAINF-17
  - Scenario: Given `GITHUB_OUTPUT` が `existing=1` の 1 行を持つファイル、`GITHUB_EVENT_NAME=workflow_dispatch`, When スクリプトを実行する
  - Expected: Then 出力ファイルの 1 行目は `existing=1` のままである

---

## T-14: action.yml (ACT)

対象: `_ca-resolve-sha/action.yml` の静的検査 (DR-27)。テストファイルは `scripts/__tests__/unit/action.unit.spec.sh`。

### [正常] Normal Cases

#### T-14-01: 入出力と環境変数の対応付け

- [x] **T-14-01-01**: REQ-C-006 の 10 個の環境変数がそろっている
  - Target: `action.yml`
  - Test ID: T-RS-ACT-01
  - Scenario: Given action.yml, When step の `env` から環境変数名を抽出する
  - Expected: Then `GITHUB_EVENT_NAME`、`GITHUB_REF`、`GITHUB_EVENT_DELETED`、`GITHUB_BEFORE_SHA`、`GITHUB_AFTER_SHA`、`GITHUB_BASE_SHA`、`GITHUB_HEAD_SHA`、`INPUT_COMMIT_COUNT`、`INPUT_BEFORE_SHA`、`INPUT_AFTER_SHA` がすべてある

- [x] **T-14-01-02**: outputs は kebab-case の 3 つである
  - Target: `action.yml`
  - Test ID: T-RS-ACT-02
  - Scenario: Given action.yml, When `outputs` の名前を抽出する
  - Expected: Then `before-sha`、`after-sha`、`resolution` の 3 つだけである

- [x] **T-14-01-03**: outputs の値は実在する step ID を参照している
  - Target: `action.yml`
  - Test ID: T-RS-ACT-03
  - Scenario: Given action.yml, When outputs の `value` が参照する step ID を抽出する
  - Expected: Then その ID を持つ step が action.yml に存在する

- [x] **T-14-01-04**: 環境変数は run を持つ同じ step にある
  - Target: `action.yml`
  - Test ID: T-RS-ACT-04
  - Scenario: Given action.yml, When 10 個の環境変数を持つ step を特定する
  - Expected: Then その step は `run` で `scripts/resolve-sha.sh` を実行している

### [異常] Error Cases

#### T-14-02: スクリプトインジェクションの防止

- [x] **T-14-02-01**: run の中に式展開が無い
  - Target: `action.yml`
  - Test ID: T-RS-ACT-05
  - Scenario: Given action.yml, When `run` の内容を抽出する
  - Expected: Then `${{` を含まない (REQ-C-001)

### [エッジケース] Edge Cases

#### T-14-03: 入力の既定値

- [x] **T-14-03-01**: commit-count の既定値は "1"
  - Target: `action.yml`
  - Test ID: T-RS-ACT-06
  - Scenario: Given action.yml, When `inputs.commit-count` を確認する
  - Expected: Then `required: false` で、`default: "1"` である (REQ-C-006)

- [x] **T-14-03-02**: before-sha / after-sha の既定値は空
  - Target: `action.yml`
  - Test ID: T-RS-ACT-07
  - Scenario: Given action.yml, When `inputs.before-sha` と `inputs.after-sha` を確認する
  - Expected: Then どちらも `required: false` で、`default: ""` である (REQ-C-006)

---

## T-15: resolve-sha.lib.sh のロードガード

対象: `scripts/_libs/resolve-sha.lib.sh` のロードガードと共有ライブラリの読み込み (RLG)。implementation.md Phase 2 Commit 1 (骨格のロードガード) とコーディング規約の fail-first に基づく。テストファイルは `scripts/_libs/__tests__/unit/resolve-sha.unit.spec.sh` の RLG グループ。読み込みは新しい bash プロセスで行い、ガードの状態を例の間で持ち越さない。

### [正常] Normal Cases

#### T-15-01: resolve-sha.lib.sh を読み込む

- [x] **T-15-01-01**: 1 回目の読み込みでガード変数が設定される
  - Target: `resolve-sha.lib.sh`
  - Test ID: T-RS-RLG-01
  - Scenario: Given `RESOLVE_SHA_LIB_LOADED` が未設定, When `resolve-sha.lib.sh` を source する
  - Expected: Then 終了コードは 0 で、`RESOLVE_SHA_LIB_LOADED` が `1` になり、`rs_error` と `validate_positive_int` が定義されている

- [x] **T-15-01-02**: 2 回目の読み込みでもエラーにならない
  - Target: `resolve-sha.lib.sh`
  - Test ID: T-RS-RLG-02
  - Scenario: Given `resolve-sha.lib.sh` を source 済み, When もう一度 source する
  - Expected: Then 終了コードは 0 で、stderr は空である

### [異常] Error Cases

#### T-15-02: 共有ライブラリを読み込めない

- [x] **T-15-02-01**: validation.lib.sh が見つからなければ読み込みを失敗させる
  - Target: `resolve-sha.lib.sh`
  - Test ID: T-RS-RLG-03
  - Scenario: Given `resolve-sha.lib.sh` だけを、`../../../_libs/validation.lib.sh` が存在しない一時ディレクトリに複製する, When 複製を source する
  - Expected: Then 終了コードは 0 以外である (読み込み失敗のまま後続の関数を使わせない)

### [エッジケース] Edge Cases

#### T-15-03: ガード変数が設定済みの状態で読み込む

- [x] **T-15-03-01**: ガード変数が設定済みなら関数を定義せずに戻る
  - Target: `resolve-sha.lib.sh`
  - Test ID: T-RS-RLG-04
  - Scenario: Given 新しいシェルで `RESOLVE_SHA_LIB_LOADED=1` を設定済み, When `resolve-sha.lib.sh` を source する
  - Expected: Then 終了コードは 0 で、`normalize_commit_count` は定義されていない

---

## Coverage Check

| Source                                                           | Task IDs                                                                                                                   |
| ---------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| R-IN-001 / DD-IN-02                                              | T-05-01-01                                                                                                                 |
| R-IN-002 (形式・上限・桁数)                                      | T-02-02-01..06, T-02-03-01, T-02-04-01..04, T-05-02-01..03, T-05-03-02                                                     |
| R-IN-003 / DD-IN-01 / DR-05                                      | T-05-01-02, T-13-02-02                                                                                                     |
| R-IN-004 / DD-IN-03 / DR-07                                      | T-06-02-01, T-06-02-02, T-06-04-02                                                                                         |
| R-IN-005                                                         | T-06-01-01                                                                                                                 |
| R-IN-006 / DD-IN-04                                              | T-06-03-01..04, T-06-04-03, T-06-05-01..03, T-06-06-01                                                                     |
| R-IN-007                                                         | T-06-01-02, T-06-04-01                                                                                                     |
| input §5 (空白のみ、1000、10000、20 桁)                          | T-05-03-01, T-05-01-03, T-02-04-01, T-02-04-02                                                                             |
| R-RES-001 / DD-RES-08 / DR-17                                    | T-11-04-01, T-11-04-02, T-13-02-03, T-13-02-04, T-13-04-01                                                                 |
| R-RES-002                                                        | T-11-03-01, T-13-01-04                                                                                                     |
| R-RES-003 / DD-RES-01 / DR-02                                    | T-11-02-01, T-11-02-02, T-11-06-08                                                                                         |
| R-RES-004 (不在、shallow 範囲外は同じ同値類)                     | T-11-02-03                                                                                                                 |
| R-RES-005                                                        | T-11-01-01, T-11-06-04, T-13-01-02                                                                                         |
| R-RES-006 / DD-RES-03 / DR-04                                    | T-11-01-02, T-11-06-05, T-13-01-03                                                                                         |
| R-RES-007 / DD-RES-04 / DR-06 / DR-19                            | T-11-01-03, T-11-01-04, T-11-06-02                                                                                         |
| R-RES-008 / DD-RES-12 / DR-23                                    | T-07-02-01, T-07-04-01, T-07-05-01, T-07-05-02, T-11-04-06, T-11-04-07, T-13-02-05                                         |
| R-RES-009 / DD-RES-13 / DR-25                                    | T-11-04-03..05, T-11-06-01..03, T-13-02-06, T-13-04-02                                                                     |
| R-RES-010                                                        | T-07-03-01, T-07-03-02, T-07-03-03, T-11-04-08                                                                             |
| R-RES-011                                                        | T-10-02-01, T-10-02-02, T-10-02-03                                                                                         |
| R-RES-012 / DD-RES-05 / DR-09                                    | T-10-01-01..04                                                                                                             |
| R-RES-013 / R-RES-015 / DD-RES-06 / DR-14                        | T-10-03-01, T-10-05-01, T-10-05-02                                                                                         |
| R-RES-014 / DD-RES-02 / DR-03                                    | T-10-04-01..03, T-10-04-05, T-11-06-07, T-13-04-04                                                                         |
| R-RES-021                                                        | T-09-02-01, T-11-05-05, T-11-05-07, T-11-05-08                                                                             |
| R-RES-024 / DD-RES-07 / DR-24                                    | T-08-03-01, T-08-04-01, T-08-04-02, T-09-02-02, T-09-03-01, T-09-03-02, T-11-05-01..04, T-11-05-06, T-11-05-09, T-11-05-10 |
| R-RES-025                                                        | T-08-01-01, T-09-01-01                                                                                                     |
| resolution §3.4 (第一親・shallow)                                | T-10-04-04..07                                                                                                             |
| R-OUT-001 / DD-OUT-01 / DR-08                                    | T-12-04-01..03                                                                                                             |
| R-OUT-002 / DD-OUT-02                                            | T-13-02-01..06                                                                                                             |
| R-OUT-003                                                        | T-12-02-01, T-13-03-01                                                                                                     |
| R-OUT-004                                                        | T-12-02-02, T-13-03-02                                                                                                     |
| R-OUT-005                                                        | T-12-02-03, T-12-02-04, T-12-04-05                                                                                         |
| R-OUT-006                                                        | T-12-02-05, T-12-04-04                                                                                                     |
| R-OUT-007                                                        | T-12-01-01, T-12-01-02                                                                                                     |
| R-OUT-008 / DD-OUT-03 / DR-18                                    | T-12-03-01                                                                                                                 |
| index §3.3 / DD-IDX-01 (エラー形式)                              | T-04-01-01..03, T-04-02-01, T-04-04-01..04                                                                                 |
| index §3.3 (注入防止)                                            | T-04-03-01, T-13-04-03                                                                                                     |
| index §5 (段階をまたぐ境界)                                      | T-13-02-02, T-13-04-01..03, T-11-04-07                                                                                     |
| DD-IDX-02 (出力値は 1 行)                                        | T-03-02-02, T-03-02-03, T-12-02-03, T-12-02-04                                                                             |
| DR-26 (共有関数はエラーを出さない)                               | T-02-03-02, T-03-03-03, T-07-03-02                                                                                         |
| DR-26 (WO の終了コードと追記)                                    | T-03-01-02, T-03-02-01..03, T-03-03-01, T-03-03-02                                                                         |
| DR-27 / REQ-C-001 / REQ-C-006 (action.yml)                       | T-14-01-01..04, T-14-02-01, T-14-03-01, T-14-03-02                                                                         |
| index §5 (action.yml の対応付けの欠落)                           | T-14-01-01, T-14-01-04                                                                                                     |
| REQ-C-008 (ロードガード、既存関数の不変)                         | T-01-01-01, T-01-01-02, T-01-02-01, T-01-03-01                                                                             |
| impl Phase 2 Commit 1 (RS ライブラリのロードガード) / fail-first | T-15-01-01, T-15-01-02, T-15-02-01, T-15-03-01                                                                             |
| AC-018 (fetch を起動しない)                                      | T-13-02-05                                                                                                                 |
| AC-021 (出力先の異常)                                            | T-13-03-01, T-13-03-02                                                                                                     |
| [UNCOVERED]                                                      | —                                                                                                                          |

## Category Balance

| Test Target | Normal | Error | Edge | Status |
| ----------- | ------ | ----- | ---- | ------ |
| T-01        | 2      | 1     | 1    | [OK]   |
| T-02        | 2      | 8     | 4    | [OK]   |
| T-03        | 2      | 6     | 1    | [OK]   |
| T-04        | 4      | 1     | 4    | [OK]   |
| T-05        | 3      | 4     | 2    | [OK]   |
| T-06        | 2      | 7     | 7    | [OK]   |
| T-07        | 3      | 3     | 4    | [OK]   |
| T-08        | 1      | 2     | 4    | [OK]   |
| T-09        | 1      | 2     | 3    | [OK]   |
| T-10        | 4      | 6     | 7    | [OK]   |
| T-11        | 8      | 18    | 8    | [OK]   |
| T-12        | 2      | 6     | 6    | [OK]   |
| T-13        | 4      | 8     | 5    | [OK]   |
| T-14        | 4      | 1     | 2    | [OK]   |
| T-15        | 2      | 1     | 1    | [OK]   |
