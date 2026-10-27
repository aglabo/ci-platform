---
title: "Requirements: _ca-filter-files"
module: "composite-action/filter-files"
status: approved
version: 1.3.0
created: "2026-10-27"
---

> **Normative Statement**
> This document defines binding requirements.
> Implementations MUST conform to this document.
> RFC 2119 keywords apply to this document only.

## 1. Overview

### 1.1 Purpose

改行区切りのファイルリストを glob パターン (包含・`!` による除外) で絞り込む内部 Composite Action `.github/actions/_ca-filter-files/` を新設する。
これにより、`git diff` に依存しないファイルフィルタを他の Action から再利用可能にする (Issue #136, 親 #134)。

現状の `ca-get-changed-files` の `pattern` 入力は git pathspec として `git diff` に渡されており、次の制約がある。

- 指定できるパターンは 1 つのみ
- ファイルを除外できない
- `git diff` の外では使えず、他の Action のファイルリストに適用できない

### 1.2 Scope

- 内部 Composite Action `_ca-filter-files` (`action.yml`) とスクリプト `filter-files.sh` の新設
- glob パターン (`**` / `*` / `?`、`!` で除外) を使ったファイルリストの絞り込み
- 絞り込み結果 (`files`) と件数 (`count`) の出力
- 複数行出力関数 `write_multiline_output` と出力先の検証関数の `.github/actions/_libs/output.lib.sh` への追加
- ShellSpec テスト (unit / functional) と `_tests_ca_composite-actions.yml` へのテストジョブ追加

**Out of Scope**:

- `ca-get-changed-files` の置き換え (`git diff` から pathspec を外し、`_ca-filter-files` を呼び出す変更。DR-06)
  - get-changed-files モジュールのドキュメント改訂で扱う (REQ-F-004、テストジョブの `*.txt` パターン、T-gcf-nor-02)
- ファイル一覧の取得 (git diff 等)。呼び出し元が行う
- ファイルの実在確認・ファイルシステムの参照
- 正規表現パターンの受け付け (DR-03)
- JSON 配列形式の出力 (例: `files-json`)。将来の拡張候補とする

**Follow-up**: Issue #136 の完了に必要な、本モジュール外の作業 (Issue #136 の Tasks で追跡):

- get-changed-files モジュールのドキュメント改訂と `ca-get-changed-files` の置き換え (DR-06)
- `_tests_ca_composite-actions.yml` の `test-get-changed-files` ジョブの `*.txt` パターンの修正
- 親 Issue #134 の `pattern` に関する記述の更新
- `ca-get-changed-files` を共有ライブラリの `write_multiline_output` (`_libs/output.lib.sh`) に切り替え、`filter.lib.sh` のローカル実装を廃止する。
  get-changed-files の要件を改訂する際に追加する (DR-07)

## 2. Context

- Target Environment: GitHub Actions ubuntu runner の Bash (Composite Action の `run` step)。macOS / Windows runner は対象外とする
- Related Components:
  - `.github/actions/ca-get-changed-files/` (想定される最初の呼び出し元)
  - `.github/actions/_libs/output.lib.sh` (`write_output`、本要件で `write_multiline_output` を追加)
  - `.github/actions/_ca-resolve-sha/` (内部 Action の規約の参照元)
  - `.github/workflows/_tests_ca_composite-actions.yml` (CI テストジョブ)
- Assumptions:
  - 呼び出し元は、絞り込み対象のファイル一覧を取得済みであり、1 行 1 パスの文字列として渡す
  - 入力の形式に関する前提は、呼び出し元の義務として REQ-C-009 に定める (DR-10)

### System Context Diagram

```text
[ca-get-changed-files] --files/patterns--> +---------------------+ --files/count--> [ca-get-changed-files]
   (git diff 結果 +                         |  _ca-filter-files   |                    (後続ステップ)
    pattern 入力)                           |  filter-files.sh    |
[他の composite action] --files/patterns--> +---------------------+ --files/count--> [他の composite action]
                                                      |
                                                      v
                                            [$GITHUB_OUTPUT]
                                            (write_multiline_output)
```

`_ca-filter-files` は文字列入力のみを扱う純粋なフィルタであり、git・ファイルシステムには触れない。

## 3. Design Decisions (Summary)

| ID    | Decision                                                                 | Linked Record                |
| ----- | ------------------------------------------------------------------------ | ---------------------------- |
| DR-01 | ファイルフィルタを git diff から独立した内部 Action に切り出す           | ../decision-records.md#DR-01 |
| DR-02 | glob を独自に正規表現へ変換して照合する                                  | ../decision-records.md#DR-02 |
| DR-03 | パターンは glob のみ受け付け、正規表現は受け付けない                     | ../decision-records.md#DR-03 |
| DR-04 | 包含パターンが 0 件の場合は全ファイルを通す                              | ../decision-records.md#DR-04 |
| DR-05 | 除外パターンは包含パターンより優先する                                   | ../decision-records.md#DR-05 |
| DR-06 | ca-get-changed-files の置き換えは get-changed-files 側で扱う             | ../decision-records.md#DR-06 |
| DR-07 | 複数行出力関数を `_libs` に追加し、区切り文字を一意な文字列にする        | ../decision-records.md#DR-07 |
| DR-08 | パターン行だけ両端の空白を除去し、ファイル行は変えない                   | ../decision-records.md#DR-08 |
| DR-09 | 非ゼロで終了するのは出力不能時と、不正と決めた入力に限る                 | ../decision-records.md#DR-09 |
| DR-10 | 入力の前提を呼び出し元の義務として定める                                 | ../decision-records.md#DR-10 |
| DR-11 | ダブルクオートの解釈は GitHub Actions (YAML) に任せ、Action では外さない | ../decision-records.md#DR-11 |
| DR-12 | 出力先の検証関数を `_libs/output.lib.sh` に追加する                      | ../decision-records.md#DR-12 |
| DR-16 | ファイル数・パターン数・バイト数に上限を設け、超えた入力をエラーにする   | ../decision-records.md#DR-16 |

## 4. Functional Requirements

### REQ-F-001: 入力の行分割

- EARS Type: event-driven

```text
GIVEN files と patterns が改行区切りの文字列として渡されている
  WHEN the action is invoked
THEN the system SHALL first convert every CRLF in files and patterns to LF, after the input check of REQ-F-017,
     SHALL split files and patterns into lines by LF,
     SHALL remove leading and trailing whitespace (space and tab) from each line of patterns
     and ignore the pattern lines that become empty after the removal,
     SHALL NOT modify the lines of files and SHALL ignore only the empty lines of files,
     and SHALL treat each remaining line of files as one file path and each remaining line of patterns as one glob pattern.
```

**Rationale**: 複数のファイル・パターンを 1 つの入力で渡すため (Issue #136)。
files・patterns とも、行へ分ける前に CRLF を LF に変換する。CRLF の入力でも、CR がパスやパターンに残らない。
LF を伴わない CR は改行とみなさず、REQ-F-017 でエラーとする。
files の行は変更しない。照合・出力するパスは入力と同じ文字列であり、両端に空白を持つパスも別のパスに変わらない。
files で無視するのは空行 (長さ 0 の行。YAML の `files: |` が付ける末尾改行を含む) だけとし、空白のみの行は 1 つのパスとして扱う。
これにより、末尾改行で `count` が 1 多くなることを防ぐ。
patterns は両端のスペース・タブを除去し、空になった行を無視する。空行や空白のみの行が空の包含パターンとして数えられることを防ぐ。
パターンの途中にある空白は除去しない。

**Acceptance Criteria**:

| AC ID  | Scenario                                                        |
| ------ | --------------------------------------------------------------- |
| AC-001 | 包含パターンに一致するファイルだけが残る                        |
| AC-012 | files の行は変えず、patterns は両端の空白を除いて空行を無視する |
| AC-014 | CRLF の改行を LF に変換してから行に分ける                       |

### REQ-F-002: 包含パターンと除外パターンの区別

- EARS Type: event-driven

```text
GIVEN REQ-F-001 の処理後に patterns が 1 行以上残っている
  WHEN the action parses patterns
THEN the system SHALL classify a line starting with "!" as an exclude pattern (the pattern is the text after "!"),
     and SHALL classify every other line as an include pattern.
```

**Rationale**: 1 つの入力で包含と除外を表現するため (Issue #136)。空行は REQ-F-001 で除かれるため、ここでは分類しない。

**Acceptance Criteria**:

| AC ID  | Scenario                                                        |
| ------ | --------------------------------------------------------------- |
| AC-002 | 除外パターンに一致するファイルは包含より優先して除かれる        |
| AC-003 | 除外パターンのみの場合は、それ以外の全ファイルが残る            |
| AC-012 | files の行は変えず、patterns は両端の空白を除いて空行を無視する |

### REQ-F-003: 保持条件

- EARS Type: event-driven

```text
GIVEN 包含パターンと除外パターンが分類済みである
  WHEN the action evaluates a file path
THEN the system SHALL keep the file if and only if
     (it matches at least one include pattern OR there are no include patterns)
     AND it matches no exclude pattern.
```

**Rationale**: Issue #136 の保持条件をそのまま規範化する。除外優先は DR-05、包含 0 件の扱いは DR-04。

**Acceptance Criteria**:

| AC ID  | Scenario                                                 |
| ------ | -------------------------------------------------------- |
| AC-001 | 包含パターンに一致するファイルだけが残る                 |
| AC-002 | 除外パターンに一致するファイルは包含より優先して除かれる |
| AC-003 | 除外パターンのみの場合は、それ以外の全ファイルが残る     |

### REQ-F-004: 空パターン

- EARS Type: state-driven

```text
GIVEN patterns が未指定、空文字列、または REQ-F-001 で無視される行のみである
  WHILE no include pattern and no exclude pattern exist
THEN the system SHALL keep all files and SHALL NOT fail.
```

**Rationale**: 包含パターン 0 件 = 全件一致とする REQ-F-003 と整合させる。`ca-get-changed-files` で `pattern` を省略したときの現行挙動 (全件) とも一致する (DR-04)。

**Acceptance Criteria**:

| AC ID  | Scenario                         |
| ------ | -------------------------------- |
| AC-004 | パターンが空なら全ファイルが残る |

### REQ-F-005: `**` の照合規則

- EARS Type: event-driven

```text
GIVEN パターンに "**" が含まれる
  WHEN the action matches a file path against the pattern
THEN the system SHALL let "**" match any number of directory levels.
```

**Rationale**: `src/**` のような階層をまたぐ指定を可能にするため (Issue #136)。0 階層への一致 (`**/` の扱い) は Open Question とする。

**Acceptance Criteria**:

| AC ID  | Scenario                                        |
| ------ | ----------------------------------------------- |
| AC-005 | `**` は任意階層に一致し `*` は `/` に一致しない |

### REQ-F-006: `*` の照合規則

- EARS Type: unwanted behavior

```text
GIVEN パターンに単独の "*" ("**" ではない) が含まれる
  NOT DO let "*" match "/"
THEN the system SHALL let "*" match any sequence of characters except "/".
```

**Rationale**: Bash の `[[ == ]]` や git pathspec では `*` が `/` に一致し、`*.sh` が `dir/a.sh` にも一致してしまう。
照合規則を明確にするため (Issue #136, DR-02)。

**Acceptance Criteria**:

| AC ID  | Scenario                                        |
| ------ | ----------------------------------------------- |
| AC-005 | `**` は任意階層に一致し `*` は `/` に一致しない |

### REQ-F-007: `?` の照合規則

- EARS Type: event-driven

```text
GIVEN パターンに "?" が含まれる
  WHEN the action matches a file path against the pattern
THEN the system SHALL let "?" match exactly one character except "/".
```

**Rationale**: Issue #136 の提案 (`**`・`*`・`?` を照合規則へ変換する) による。

**Acceptance Criteria**:

| AC ID  | Scenario                                        |
| ------ | ----------------------------------------------- |
| AC-005 | `**` は任意階層に一致し `*` は `/` に一致しない |

### REQ-F-008: パス全体への一致

- EARS Type: event-driven

```text
GIVEN パターンとファイルパスがある
  WHEN the action matches the file path against the pattern
THEN the system SHALL treat the pattern as matching only when it matches the entire path, not a substring of it.
```

**Rationale**: `*.sh` が `dir/a.sh` に一致しないという Issue #136 の期待は、パス全体への一致を前提とする。

**Acceptance Criteria**:

| AC ID  | Scenario                                        |
| ------ | ----------------------------------------------- |
| AC-005 | `**` は任意階層に一致し `*` は `/` に一致しない |

### REQ-F-009: glob 以外の構文を解釈しない

- EARS Type: unwanted behavior

```text
GIVEN パターンに "**" "*" "?" 以外の正規表現メタ文字 (例: "." "+" "(" ")" "|" "^" "$") が含まれる
  NOT DO interpret the pattern as a regular expression
THEN the system SHALL match those characters literally.
```

**Rationale**: パターンは glob のみ受け付ける (DR-03)。内部で正規表現へ変換する際、メタ文字が正規表現として働くことを防ぐ。ブラケット `[...]` の扱いは Open Question とする。

**Acceptance Criteria**:

| AC ID  | Scenario                                       |
| ------ | ---------------------------------------------- |
| AC-006 | ドットなどのメタ文字はリテラルとして照合される |

### REQ-F-010: 入力順の保持

- EARS Type: event-driven

```text
GIVEN 複数のファイルが保持条件を満たす
  WHEN the action writes the files output
THEN the system SHALL output the kept file paths, unchanged from the lines of REQ-F-001,
     one per line, in the same order as in the files input.
```

**Rationale**: Issue #136 の期待どおり、呼び出し元が入力順を前提にできる。

**Acceptance Criteria**:

| AC ID  | Scenario                                                        |
| ------ | --------------------------------------------------------------- |
| AC-001 | 包含パターンに一致するファイルだけが残る                        |
| AC-012 | files の行は変えず、patterns は両端の空白を除いて空行を無視する |

### REQ-F-011: 件数の出力

- EARS Type: event-driven

```text
GIVEN 絞り込みが完了している
  WHEN the action writes its outputs
THEN the system SHALL set the count output to the number of file paths in the files output,
     as a decimal integer string without leading zeros or surrounding whitespace.
```

**Rationale**: 呼び出し元が件数で後続処理を分岐できるようにする (Issue #136)。
`count == '0'` のような文字列比較で判定できるよう、書式も定める (harden review GF-03)。

**Acceptance Criteria**:

| AC ID  | Scenario                                 |
| ------ | ---------------------------------------- |
| AC-001 | 包含パターンに一致するファイルだけが残る |
| AC-004 | パターンが空なら全ファイルが残る         |

### REQ-F-012: 純粋なフィルタ

- EARS Type: unwanted behavior

```text
GIVEN any input
  NOT DO access git or the file system to inspect the listed paths (including existence checks)
THEN the system SHALL decide the result from the files and patterns strings only.
```

**Rationale**: ファイル一覧の取得は呼び出し元の責務とし、本 Action は文字列の絞り込みに限定する (ヒアリング Q1)。`$GITHUB_OUTPUT` への書き込みはこの禁止に含まない。

**Acceptance Criteria**:

| AC ID  | Scenario                               |
| ------ | -------------------------------------- |
| AC-007 | 実在しないパスも文字列として照合される |

### REQ-F-013: 衝突しない複数行出力

- EARS Type: unwanted behavior

```text
GIVEN files 出力の値に任意のファイルパス (例: "EOF" という名前のパス) が含まれ得る
  NOT DO use a heredoc delimiter that can collide with a line of the value
THEN the system SHALL compare each delimiter candidate with every line of the value,
     SHALL choose another candidate when they collide,
     and SHALL write the multi-line output only with a delimiter that does not appear as a line in the value.
```

**Rationale**: 既存の `filter.lib.sh` の `write_multiline_output` は区切り文字が固定の `EOF` であり、パスが `EOF` だと出力が壊れる (ヒアリング Q5, DR-07)。
一意な文字列を生成するだけでは「衝突しにくい」に留まり、衝突しないことの保証にならない (codex review)。

**Acceptance Criteria**:

| AC ID  | Scenario                                       |
| ------ | ---------------------------------------------- |
| AC-008 | 区切り文字と同名のパスを含んでも出力が壊れない |
| AC-010 | 区切り文字の候補が値の行と衝突したら選び直す   |

### REQ-F-014: 空の結果

- EARS Type: state-driven

```text
GIVEN REQ-F-001 の処理後に files が 0 行である、またはどのファイルも保持条件を満たさない
  WHILE no file is kept
THEN the system SHALL set the files output so that subsequent steps read it as an empty string,
     SHALL set the count output to "0",
     and SHALL exit with status 0.
```

**Rationale**: 既存の `filter.lib.sh` の `write_multiline_output` は空の値で空行を 1 行書き出すため、後続ステップから見た値を明示する (explore review Q-07)。
対象 0 件は正常な結果であり、`count` の誤計算や `set -e` による異常終了を起こしてはならない (codex review)。

**Acceptance Criteria**:

| AC ID  | Scenario                                         |
| ------ | ------------------------------------------------ |
| AC-009 | 一致するファイルが無ければ空の結果で正常終了する |

### REQ-F-015: 出力できない場合のエラー

- EARS Type: unwanted behavior

```text
GIVEN 環境変数 GITHUB_OUTPUT が未設定・空である、または書き込めないファイルを指している
  NOT DO write any output when the verification fails
THEN the system SHALL verify that the outputs can be written before writing the first output,
     SHALL write no output when the verification fails,
     SHALL print an "::error::" message to stderr,
     and SHALL exit with a non-zero status.
     When a write fails after the verification has succeeded, the system SHALL print an "::error::" message to stderr,
     SHALL NOT write the remaining outputs, and SHALL exit with a non-zero status.
     Outputs already written (e.g. files) MAY remain.
```

**Rationale**: 出力を書き出せないと、後続ステップが `files` と `count` の不整合な値を受け取る。
出力の検証を最初の書き込みの前に済ませる点は `_ca-resolve-sha` の規約に合わせる (explore review Q-04)。検証には共有ライブラリの関数を使う (DR-12)。
検証の成功は、後続の書き込み (容量不足・I/O エラー等) の成功を保証しない。書き込み開始後の失敗では、書き込み済みの出力が残り得る (spec R-OUT-006)。
このため「何も書かない」を保証するのは、検証で失敗した場合に限る。
本 Action が非ゼロで終了するのは、本要件、REQ-F-017、REQ-F-018、spec で失敗と決めた入力 (DR-14) の場合に限る。

**Acceptance Criteria**:

| AC ID  | Scenario                                   |
| ------ | ------------------------------------------ |
| AC-011 | 出力先が無ければ何も書かずにエラー終了する |

### REQ-F-016: ダブルクオートを外さない

- EARS Type: unwanted behavior

```text
GIVEN patterns の行が、REQ-F-001 の処理後にダブルクオート (") を含む
  NOT DO remove or interpret the double quotes by itself
THEN the system SHALL use the input value as passed by GitHub Actions after its YAML interpretation,
     and SHALL treat double quotes remaining in a pattern line as literal characters.
```

**Rationale**: `with:` の値をダブルクオートで囲んだ場合 (例: `patterns: "*.sh"`) は、GitHub Actions が YAML として解釈し、
クオートを外した文字列 (`*.sh`) を Action に渡す。
ブロックスカラー (`patterns: |`) 内の行に書いたクオート (例: `"a b.sh"`) は、YAML の解釈後も文字として残るため、Action はそれをパターンの一部として照合する (DR-11)。
patterns は両端の空白を除去するため、ブロックスカラー内では両端に空白を持つパターンを表現できない (DR-08, DR-11)。
files の行がダブルクオートを含む場合は、git の引用表記をデコードせずに渡した入力とみなし、REQ-F-017 でエラーとする。
files の行は変更しないため、両端の空白もパスの一部として照合される (REQ-F-001)。

**Acceptance Criteria**:

| AC ID  | Scenario                                          |
| ------ | ------------------------------------------------- |
| AC-013 | YAML が外したクオートは無く、行内のクオートは残る |

### REQ-F-017: 改行・引用表記を含む入力のエラー

- EARS Type: unwanted behavior

```text
GIVEN files または patterns が LF を伴わない CR を含む、または files の行がダブルクオート (") を含む
  NOT DO split the input into lines or write any output
THEN the system SHALL check files and patterns before the conversion of REQ-F-001 and before writing the first output,
     SHALL print an "::error::" message to stderr,
     and SHALL exit with a non-zero status.
```

**Rationale**: パスに改行が含まれると、行へ分けた時点で 1 つのパスが複数のパスに分かれ、誤った照合・出力になる。
CRLF と LF だけを改行とみなすため、LF を伴わない CR はパスの一部であり、正規化 (REQ-F-001) の前に検出できる。
CR のみを改行とする入力も、このエラーに含まれる。
パス中の LF は、改行区切りの入力では行の区切りと区別できないため検出できない。REQ-C-009 で呼び出し元の義務とする。
git は既定 (`core.quotePath=true`) で、改行などを含むパスを `"a\nb"` のような引用表記で出力する。
ダブルクオートを含む files の行は、この表記をデコードせずに渡した入力とみなしてエラーとする。
ダブルクオートを含む実パスも受け付けないが、出現は稀であるため、取りこぼしを防ぐ方を優先する。
patterns のダブルクオートは REQ-F-016 に従いリテラルとして扱い、エラーにしない。

**Acceptance Criteria**:

| AC ID  | Scenario                                                      |
| ------ | ------------------------------------------------------------- |
| AC-015 | LF を伴わない CR を含む入力は、何も書かずにエラー終了する     |
| AC-016 | ダブルクオートを含む files の行は、何も書かずにエラー終了する |

### REQ-F-018: 件数とサイズの上限

- EARS Type: unwanted behavior

```text
GIVEN files または patterns の値が 120000 バイトを超える、
      または REQ-F-001 の処理後に、files が 3000 行を超える、または patterns が 1000 行を超える
  NOT DO filter the files or write any output
THEN the system SHALL check the byte size of each value before any other input check,
     SHALL check the number of lines before classifying patterns,
     SHALL perform both checks before writing the first output,
     SHALL print an "::error::" message to stderr,
     and SHALL exit with a non-zero status.
```

**Rationale**: 件数に上限を設け、照合時間と入出力の規模を見積もれるようにする (impl second opinion)。
ファイル数の上限は、GitHub の PR の差分が最大 3000 ファイルであることに合わせる。パターン数の上限は 1000 とする。
上限ちょうどの件数は受け付ける。件数は REQ-F-001 で無視した行を含めない。
上限値はスクリプトの定数として定義する (DR-16)。
バイト数の上限は、Linux の環境変数 1 つ分の上限 (`MAX_ARG_STRLEN`、131072 バイト) に余裕を残すように決める。
バイト数は、改行の変換・行の分割の前の値そのものを、文字数ではなくバイト数で数える。
値が `MAX_ARG_STRLEN` を超えると、step のプロセス自体が起動せず (`Argument list too long`)、本 Action の検査に届かない。
本要件は、120000 バイトまでの入力が確実に処理されることを示す契約であり、すべての超過の検出を保証しない。

**Acceptance Criteria**:

| AC ID  | Scenario                                               |
| ------ | ------------------------------------------------------ |
| AC-017 | 件数が上限を超えた入力は、何も書かずにエラー終了する   |
| AC-018 | サイズが上限を超えた入力は、何も書かずにエラー終了する |

## 5. Non-Functional Requirements

### REQ-NF-001: Testability

すべての REQ-F は、ShellSpec (unit / functional) のテストケースを 1 件以上持たなければならない (MUST)。
`bash ./runners/run-shellspec.sh all` が `not ok` 0 件で完了しなければならない (MUST)。

glob から照合規則への変換は、Action を起動せずに単体で検証できる関数として実装しなければならない (MUST)。
`**/`、ドット、ブラケットなどの境界ケースをテストで網羅しなければならない (MUST, Issue #136 のリスク記載)。
日本語などの非 ASCII 文字を含むパスの照合もテストしなければならない (MUST, explore review G-03)。

### REQ-NF-002: Maintainability

照合規則は本ドキュメントと spec に明示した glob 規則のみとし、シェルのオプション (`globstar`、`extglob` 等) の状態に依存してはならない (MUST NOT)。

## 6. Constraints

### REQ-C-001: スクリプトインジェクション防止

入力は env 経由でのみスクリプトに渡さなければならない (MUST)。`run` 内に `${{ }}` を記述してはならない (MUST NOT)。

### REQ-C-002: 最小権限

Composite Action は `permissions` を宣言できない。
`_ca-filter-files` は、`contents: read` 以外の権限を必要としてはならない (MUST NOT)。

### REQ-C-003: 内部専用

Action 名は `_` プレフィックス (`_ca-filter-files`) とし、内部専用としなければならない (MUST)。

### REQ-C-004: 静的解析

`actionlint` および `ghalint` を通過しなければならない (MUST)。

### REQ-C-005: インターフェース

- 配置先: `.github/actions/_ca-filter-files/`
- 入力 (明示デフォルト):
  - `files` (required: true): ファイルパス、1 行 1 件
  - `patterns` (required: false, default ""): glob パターン、1 行 1 件、`!` で除外
- 出力:
  - `files`: 保持されたファイルパス、1 行 1 件
  - `count`: 保持されたファイル数
- スクリプト: `.github/actions/_ca-filter-files/scripts/filter-files.sh`
- `action.yml` は、各入力を step の `env` で明示的に環境変数へ対応付ける。

上記を満たさなければならない (MUST)。

### REQ-C-006: スクリプト規約

`filter-files.sh` は `_ca-resolve-sha` と同じ規約に従わなければならない (MUST)。

- `set -euo pipefail` を宣言する。
- ライブラリのロードガードを持つ。
- 直接実行されたときだけ main を実行する。source との判別は `_ca-resolve-sha` に合わせ `(return 0 2>/dev/null)` で行う。
- 環境変数を読むのは main のみとする。
- エラーは `::error::` を stderr に出力して非ゼロで終了する。
- 出力先の検証と出力の書き出しは、共有ライブラリ `.github/actions/_libs/output.lib.sh` の関数 (出力先の検証関数、`write_output`、`write_multiline_output`) で行う。

### REQ-C-007: _libs/ の変更方針

`.github/actions/_libs/` の変更は、追加のみとしなければならない (MUST)。

- 追加してよいもの: `output.lib.sh` への `write_multiline_output` と出力先の検証関数 (DR-07, DR-12)
- 既存関数のシグネチャおよび挙動は変更してはならない (MUST NOT)。
- 既存利用元 (`ca-setup-repo`, `ca-setup-tool`, `ca-validate-environment`, `_ca-resolve-sha`) の既存テストは、引き続き PASS しなければならない (MUST)。

### REQ-C-008: CI テストジョブ

`.github/workflows/_tests_ca_composite-actions.yml` に `_ca-filter-files` のテストジョブを追加しなければならない (MUST)。
同ファイルの summary ジョブも更新し、新ジョブを `needs`・結果表示・失敗判定に含めなければならない (MUST)。
同ファイルは保護領域であるため、PR に変更理由を明記しなければならない (MUST)。

### REQ-C-009: 呼び出し元の入力契約

呼び出し元は、`files` に次の条件を満たすパスを渡さなければならない (MUST, DR-10)。
行の区切りに関する条件は `patterns` にも適用する。

- デコード済みの実パスである。git の引用表記 (`core.quotePath` による `"..."` とエスケープ) はデコードしてから渡す。ダブルクオートを含む行は REQ-F-017 でエラーになる
- リポジトリ相対で、区切り文字は `/` である
- 正規化済みであり、先頭の `./` や `/`、`a//b` のような重複した区切りを含まない
- パスは改行 (LF・CR) を含まない。CR は REQ-F-017 で検出するが、LF は行の区切りと区別できないため検出しない
- 行の区切りは LF または CRLF である (`files`・`patterns` とも)。REQ-F-001 で CRLF を LF に変換する。CR のみの改行は REQ-F-017 でエラーになる

本 Action は、REQ-F-017 で検出するもの以外、条件を満たさない入力を検出・補正しない。REQ-F-001 の CRLF の変換以外にパスを正規化せず、その文字列のまま照合する。

## 7. User Stories

| Story ID | Role                                           | Goal                                                       | Reason                                                       | Related Requirements                       |
| -------- | ---------------------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------ | ------------------------------------------ |
| US-001   | 内部の呼び出し元 Action (ca-get-changed-files) | 取得済みのファイル一覧を複数の glob パターンで絞り込みたい | git pathspec の単一パターン制約をなくすため                  | REQ-F-001, REQ-F-002, REQ-F-003, REQ-F-010 |
| US-002   | Composite Action の開発者                      | `!` で特定のファイルを除外したい                           | 生成物やテストデータを処理対象から外すため                   | REQ-F-002, REQ-F-003                       |
| US-003   | Composite Action の開発者                      | `*` と `**` の意味が明確な glob で指定したい               | パターンが意図しない階層のファイルに一致するのを防ぐため     | REQ-F-005, REQ-F-006, REQ-F-007, REQ-F-008 |
| US-004   | 内部の呼び出し元 Action                        | パターン省略時は全ファイルを受け取りたい                   | フィルタ不要な呼び出しでも同じ Action を使えるようにするため | REQ-F-004                                  |
| US-005   | 内部の呼び出し元 Action                        | 件数で後続処理を分岐したい                                 | 対象 0 件のときに処理を省略するため                          | REQ-F-011, REQ-F-014                       |
| US-006   | CI 保守者                                      | どんなパスが含まれても出力が壊れないようにしたい           | 出力の破損で後続ステップが誤動作するのを防ぐため             | REQ-F-013                                  |

## 8. Acceptance Criteria

```gherkin
# AC-001: 包含パターンに一致するファイルだけが残る
# Requirement: REQ-F-001, REQ-F-003, REQ-F-010, REQ-F-011
Scenario: 包含パターンに一致するファイルだけが残る
  Given files が "a.sh", "README.md", "b.sh" の 3 行である
  And   patterns が "*.sh" の 1 行である
  When  the action is invoked
  Then  files 出力は "a.sh", "b.sh" の順の 2 行である
  And   count 出力は "2" である

# AC-002: 除外パターンに一致するファイルは包含より優先して除かれる
# Requirement: REQ-F-002, REQ-F-003
Scenario: 除外パターンに一致するファイルは包含より優先して除かれる
  Given files が "src/a.sh", "src/gen/b.sh" の 2 行である
  And   patterns が "src/**" と "!src/gen/**" の 2 行である
  When  the action is invoked
  Then  files 出力は "src/a.sh" のみである

# AC-003: 除外パターンのみの場合は、それ以外の全ファイルが残る
# Requirement: REQ-F-003
Scenario: 除外パターンのみの場合は、それ以外の全ファイルが残る
  Given files が "a.sh", "a.md", "b.sh" の 3 行である
  And   patterns が "!*.md" の 1 行である
  When  the action is invoked
  Then  files 出力は "a.sh", "b.sh" の順の 2 行である

# AC-004: パターンが空なら全ファイルが残る
# Requirement: REQ-F-004, REQ-F-011
Scenario: パターンが空なら全ファイルが残る
  Given files が "a.sh", "dir/b.md" の 2 行である
  And   patterns が空文字列である
  When  the action is invoked
  Then  files 出力は "a.sh", "dir/b.md" の順の 2 行である
  And   count 出力は "2" である
  And   the action exits with status 0

# AC-005: `**` は任意階層に一致し `*` は `/` に一致しない
# Requirement: REQ-F-005, REQ-F-006, REQ-F-007, REQ-F-008
Scenario: `**` は任意階層に一致し `*` は `/` に一致しない
  Given files が "a.sh", "dir/a.sh", "dir/sub/a.sh" の 3 行である
  When  patterns "*.sh" で the action is invoked
  Then  files 出力は "a.sh" のみである
  When  patterns "dir/**" で the action is invoked
  Then  files 出力は "dir/a.sh", "dir/sub/a.sh" の順の 2 行である
  When  patterns "dir/?.sh" で the action is invoked
  Then  files 出力は "dir/a.sh" のみである

# AC-006: ドットなどのメタ文字はリテラルとして照合される
# Requirement: REQ-F-009
Scenario: ドットなどのメタ文字はリテラルとして照合される
  Given files が "a.sh", "aXsh" の 2 行である
  And   patterns が "a.sh" の 1 行である
  When  the action is invoked
  Then  files 出力は "a.sh" のみである

# AC-007: 実在しないパスも文字列として照合される
# Requirement: REQ-F-012
Scenario: 実在しないパスも文字列として照合される
  Given files がリポジトリに存在しない "no/such/file.sh" の 1 行である
  And   patterns が "**/*.sh" の 1 行である
  When  the action is invoked
  Then  files 出力は "no/such/file.sh" である

# AC-008: 区切り文字と同名のパスを含んでも出力が壊れない
# Requirement: REQ-F-013
Scenario: 区切り文字と同名のパスを含んでも出力が壊れない
  Given files が "EOF", "a.sh" の 2 行である
  And   patterns が空文字列である
  When  the action is invoked
  Then  files 出力は "EOF", "a.sh" の順の 2 行である

# AC-009: 一致するファイルが無ければ空の結果で正常終了する
# Requirement: REQ-F-014
Scenario: 一致するファイルが無ければ空の結果で正常終了する
  Given files が "a.md" の 1 行である
  And   patterns が "*.sh" の 1 行である
  When  the action is invoked
  Then  後続ステップが参照する files 出力は空文字列である
  And   count 出力は "0" である
  And   the action exits with status 0

# AC-010: 区切り文字の候補が値の行と衝突したら選び直す
# Requirement: REQ-F-013
Scenario: 区切り文字の候補が値の行と衝突したら選び直す
  Given files 出力の値が、区切り文字の最初の候補と同じ行を含む
  When  the multi-line output is written
  Then  最初の候補とは異なる区切り文字が使われる
  And   後続ステップが受け取る files 出力は元の値と一致する

# AC-011: 出力先が無ければ何も書かずにエラー終了する
# Requirement: REQ-F-015
Scenario: 出力先が無ければ何も書かずにエラー終了する
  Given 環境変数 GITHUB_OUTPUT が未設定である
  When  the action is invoked
  Then  stderr に "::error::" で始まるメッセージが出力される
  And   the action exits with a non-zero status

# AC-012: files の行は変えず、patterns は両端の空白を除いて空行を無視する
# Requirement: REQ-F-001, REQ-F-002, REQ-F-010, REQ-F-011
Scenario: files の行は変えず、patterns は両端の空白を除いて空行を無視する
  Given files が "  a.sh", "", "my file.sh", "b.md" の行と末尾の改行からなる
  And   patterns が "  *.sh  " と "<TAB>" (<TAB> はタブ文字) の 2 行である
  When  the action is invoked
  Then  files 出力は "  a.sh", "my file.sh" の順の 2 行である
  And   count 出力は "2" である

# AC-014: CRLF の改行を LF に変換してから行に分ける
# Requirement: REQ-F-001
Scenario: CRLF の改行を LF に変換してから行に分ける
  Given files が "a.sh<CR><LF>b.sh<CR><LF>c.md<LF>" である (<CR> は CR、<LF> は LF)
  And   patterns が "*.sh<CR><LF>" である
  When  the action is invoked
  Then  files 出力は "a.sh", "b.sh" の順の 2 行である
  And   files 出力のどの行も CR を含まない

# AC-013: YAML が外したクオートは無く、行内のクオートは残る
# Requirement: REQ-F-016
Scenario: YAML が外したクオートは無く、行内のクオートは残る
  Given 呼び出し元が `patterns: "*.sh"` と書き、Action には `*.sh` が渡されている
  And   files が `a.sh` と `b.md` の 2 行である
  When  the action is invoked
  Then  files 出力は `a.sh` のみである
  When  patterns が `"a.sh"` (クオートを含む文字列) の 1 行で the action is invoked
  Then  files 出力は空文字列である
  And   count 出力は "0" である

# AC-015: LF を伴わない CR を含む入力は、何も書かずにエラー終了する
# Requirement: REQ-F-017
Scenario: LF を伴わない CR を含む入力は、何も書かずにエラー終了する
  Given files が "a<CR>b.sh<LF>c.sh" である (<CR> は CR、<LF> は LF)
  When  the action is invoked
  Then  stderr に "::error::" で始まるメッセージが出力される
  And   出力は 1 つも書かれない
  And   the action exits with a non-zero status

# AC-016: ダブルクオートを含む files の行は、何も書かずにエラー終了する
# Requirement: REQ-F-017
Scenario: ダブルクオートを含む files の行は、何も書かずにエラー終了する
  Given files が `a.sh` と `"a\nb.sh"` (git の引用表記のままの文字列) の 2 行である
  When  the action is invoked
  Then  stderr に "::error::" で始まるメッセージが出力される
  And   出力は 1 つも書かれない
  And   the action exits with a non-zero status

# AC-017: 件数が上限を超えた入力は、何も書かずにエラー終了する
# Requirement: REQ-F-018
Scenario: 件数が上限を超えた入力は、何も書かずにエラー終了する
  Given files が 3000 行、patterns が 1000 行である
  When  the action is invoked
  Then  the action exits with status 0
  When  files が 3001 行で the action is invoked
  Then  stderr に "::error::files: " で始まるメッセージが出力される
  And   出力は 1 つも書かれない
  And   the action exits with a non-zero status
  When  patterns が 1001 行で the action is invoked
  Then  stderr に "::error::patterns: " で始まるメッセージが出力される
  And   出力は 1 つも書かれない
  And   the action exits with a non-zero status

# AC-018: サイズが上限を超えた入力は、何も書かずにエラー終了する
# Requirement: REQ-F-018
Scenario: サイズが上限を超えた入力は、何も書かずにエラー終了する
  Given files の値が 120000 バイトである
  When  the action is invoked
  Then  the action exits with status 0
  When  files の値が 120001 バイトで the action is invoked
  Then  stderr に "::error::files: exceeds the limit of 120000 bytes" で始まるメッセージが出力される
  And   出力は 1 つも書かれない
  And   the action exits with a non-zero status
  When  patterns の値が 120001 バイトで the action is invoked
  Then  stderr に "::error::patterns: exceeds the limit of 120000 bytes" で始まるメッセージが出力される
  And   the action exits with a non-zero status
```

## 9. Open Questions

Owner が spec の項目は、spec で解決した。各行の括弧内に解決先を示す。

| Question                                                                                                                                                  | Type        | Impact Area      | Owner |
| --------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- | ---------------- | ----- |
| `write_multiline_output` の引数・戻り値・出力先の指定方法 (`write_output` との整合) (Resolved in spec: DD-OUT-06, DR-13)                                  | Spec detail | REQ-F-013, C-007 | spec  |
| `**/` が 0 階層に一致するか (`**/a.sh` が `a.sh` に一致するか) (Resolved in spec: DD-MAT-01)                                                              | Spec detail | REQ-F-005        | spec  |
| `*` / `?` が先頭ドットのファイル (隠しファイル) に一致するか (Resolved in spec: DD-MAT-04)                                                                | Spec detail | REQ-F-006, F-007 | spec  |
| ブラケット `[...]` を文字クラスとして扱うか、リテラルとして扱うか (Resolved in spec: DD-MAT-03)                                                           | Spec detail | REQ-F-009        | spec  |
| パス中の特殊文字、CR (CRLF 入力) の扱い (files の行は変更せず CRLF を LF に変換、CR のみはエラー: REQ-F-001, REQ-F-017, REQ-C-009)                        | Spec detail | REQ-F-001, F-013 | spec  |
| `**` が `/` を含まないセグメント内 (例: `a**b`) に現れた場合の扱い (Resolved in spec: DD-MAT-02)                                                          | Spec detail | REQ-F-005        | spec  |
| 不正なパターン (例: `!` のみの行) をエラーとするか (Resolved in spec: DR-14)                                                                              | Spec detail | REQ-F-002        | spec  |
| `files` に重複したパスがある場合、出力と `count` で重複を残すか、1 件にまとめるか (Resolved in spec: specifications-input.md 5 (重複を残す))              | Spec detail | REQ-F-010, F-011 | spec  |
| `?` の「1 文字」はバイト単位か、文字 (UTF-8 のコードポイント) 単位か (Resolved in spec: DD-MAT-05)                                                        | Spec detail | REQ-F-007        | spec  |
| `*`・`**`・`?` の意味を GitHub Actions の `paths` フィルタ構文と一致させるか (除外優先の DR-05 は維持) (Resolved in spec: specifications-matching.md 2.1) | Spec detail | REQ-F-005〜F-007 | spec  |
| 照合方式: 正規表現への変換 (DR-02) と、`/` 区切りのセグメント単位照合の実装量・テスト容易性の比較                                                         | Impl detail | REQ-F-005〜F-009 | impl  |
| 照合をファイルごとのループで行うか、`grep -E` などでまとめて行うか (入力順と REQ-F-001 の行の扱いを保てるか)                                              | Impl detail | REQ-F-010        | impl  |

## 10. Traceability

| REQ ID     | AC IDs                 | Type           |
| ---------- | ---------------------- | -------------- |
| REQ-F-001  | AC-001, AC-012, AC-014 | Functional     |
| REQ-F-002  | AC-002, AC-003, AC-012 | Functional     |
| REQ-F-003  | AC-001, AC-002, AC-003 | Functional     |
| REQ-F-004  | AC-004                 | Functional     |
| REQ-F-005  | AC-005                 | Functional     |
| REQ-F-006  | AC-005                 | Functional     |
| REQ-F-007  | AC-005                 | Functional     |
| REQ-F-008  | AC-005                 | Functional     |
| REQ-F-009  | AC-006                 | Functional     |
| REQ-F-010  | AC-001, AC-012         | Functional     |
| REQ-F-011  | AC-001, AC-004, AC-012 | Functional     |
| REQ-F-012  | AC-007                 | Functional     |
| REQ-F-013  | AC-008, AC-010         | Functional     |
| REQ-F-014  | AC-009                 | Functional     |
| REQ-F-015  | AC-011                 | Functional     |
| REQ-F-016  | AC-013                 | Functional     |
| REQ-F-017  | AC-015, AC-016         | Functional     |
| REQ-F-018  | AC-017, AC-018         | Functional     |
| REQ-NF-001 | N/A                    | Non-Functional |
| REQ-NF-002 | N/A                    | Non-Functional |
| REQ-C-001  | N/A                    | Constraint     |
| REQ-C-002  | N/A                    | Constraint     |
| REQ-C-003  | N/A                    | Constraint     |
| REQ-C-004  | N/A                    | Constraint     |
| REQ-C-005  | N/A                    | Constraint     |
| REQ-C-006  | N/A                    | Constraint     |
| REQ-C-007  | N/A                    | Constraint     |
| REQ-C-008  | N/A                    | Constraint     |
| REQ-C-009  | N/A                    | Constraint     |

## 11. Change History

| Date       | Version | Description                                                                                                                                                                                                                                                                      |
| ---------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-10-27 | 0.1.0   | Initial draft                                                                                                                                                                                                                                                                    |
| 2026-10-27 | 0.1.1   | Apply explore review: add REQ-F-015 and whitespace trimming, clarify REQ-F-014, assumptions, follow-up and open questions                                                                                                                                                        |
| 2026-10-27 | 0.1.2   | Apply harden review: add REQ-C-009 (caller input contract), clarify REQ-F-010, F-011, F-014, link DR-08 to DR-10                                                                                                                                                                 |
| 2026-10-27 | 0.1.3   | Add REQ-F-016: leave double quote interpretation to GitHub Actions (YAML)                                                                                                                                                                                                        |
| 2026-10-27 | 0.1.4   | Apply fix review: terminology, AC-009 wording, AC-012 traceability, open question and REQ-C-009 LF scope                                                                                                                                                                         |
| 2026-10-27 | 0.1.5   | Add follow-up: switch get-changed-files to shared write_multiline_output                                                                                                                                                                                                         |
| 2026-10-27 | 0.1.6   | Add shared output destination check function to _libs (REQ-C-006, REQ-C-007, DR-12)                                                                                                                                                                                              |
| 2026-10-27 | 0.1.7   | Apply spec second opinion: forbid CR in paths (REQ-C-009), rewrite AC-010 without candidate injection                                                                                                                                                                            |
| 2026-10-27 | 0.1.8   | Apply spec fix review: mark spec-owned open questions resolved, point REQ-F-015 to DR-14                                                                                                                                                                                         |
| 2026-10-27 | 1.0.0   | Initial release                                                                                                                                                                                                                                                                  |
| 2026-10-27 | 1.1.0   | Apply req second opinion: limit no-output guarantee to verification failure (F-015), convert CRLF to LF, keep files lines unchanged and trim patterns only (F-001, C-009, AC-012, AC-014), reject lone CR and quoted files lines (F-016, F-017, AC-013, AC-015, AC-016), approve |
| 2026-10-27 | 1.2.0   | Apply impl second opinion: add line count limits for files (3000) and patterns (1000) (REQ-F-018, AC-017, DR-16)                                                                                                                                                                 |
| 2026-10-27 | 1.3.0   | Add byte size limits (120000 bytes) for files and patterns to REQ-F-018, add AC-018 (DR-16)                                                                                                                                                                                      |
