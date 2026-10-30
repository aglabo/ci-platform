---
title: filter-files
test_scope: FF
owns:
  - .github/actions/_ca-filter-files/**
  - .github/actions/_libs/__tests__/unit/validate-output-file.unit.spec.sh
  - .github/actions/_libs/__tests__/unit/write-multiline-output.unit.spec.sh
---

## filter-files

内部 Composite Action `_ca-filter-files` のファイルリスト絞り込みを扱うモジュール。
改行区切りのファイルリストと glob パターン (`!` で除外) を受け取り、一致したファイルとその件数を入力順のまま返す。
`ca-get-changed-files` の `pattern` 入力 (git pathspec) を、本 action による glob フィルタに置き換える (Issue #136)。
共有ライブラリ `.github/actions/_libs/output.lib.sh` への追加分 (`validate_output_file`、`write_multiline_output`) のテストも、ファイル単位で所有する。

## 関数一覧

本モジュールの公開関数・テスト対象と、テスト ID に使う略語の一覧とする。
spec と impl はこの一覧を参照し、関数名・シグネチャ・所在を再掲しない。

| テストの略語 | 関数                                              | 所在                                                 | 担当仕様                     |
|--------------|---------------------------------------------------|------------------------------------------------------|------------------------------|
| VOF          | `validate_output_file <file>`                     | `.github/actions/_libs/output.lib.sh`                | specifications-output.md     |
| WMO          | `write_multiline_output <file> <key> [<line>...]` | `.github/actions/_libs/output.lib.sh`                | specifications-output.md     |
| FE           | `ff_error <target> <problem> [<value>]`           | `_ca-filter-files/scripts/_libs/filter-files.lib.sh` | specifications-index.md §3.3 |
| CBL          | `check_byte_limit <target> <text> <max>`          | `.github/actions/_libs/validation.lib.sh`            | specifications-input.md      |
| CLE          | `check_line_endings <target> <text>`              | `_ca-filter-files/scripts/_libs/filter-files.lib.sh` | specifications-input.md      |
| PFL          | `parse_filelist <text>`                           | 同上                                                 | specifications-input.md      |
| PPT          | `parse_patterns <text>`                           | 同上                                                 | specifications-input.md      |
| CLL          | `check_line_limit <target> <lines> <max>`         | 同上                                                 | specifications-input.md      |
| CP           | `check_patterns <lines>`                          | 同上                                                 | specifications-input.md      |
| GTR          | `glob_to_regex <glob>`                            | 同上                                                 | specifications-matching.md   |
| FF           | `filter_files <files> <patterns>`                 | 同上                                                 | specifications-matching.md   |
| EO           | `emit_outputs <file> <kept>`                      | 同上                                                 | specifications-output.md     |
| MAINF        | `main` (functional テスト)                        | `_ca-filter-files/scripts/filter-files.sh`           | specifications-output.md     |
| ACT          | `action.yml` の静的検査                           | `_ca-filter-files/action.yml`                        | specifications-index.md §3.1 |

- 略語は綴り全体で 1 個とする。`main` は functional テストだけで検証するため、略語は `MAINF` とする。
- 次の関数にはテスト ID を割り当てない。
  - `write_output`: 既存の共有関数 (`_ca-resolve-sha` が所有)。EO が `count` の書き出しに使う
  - `_ff_split_lines <text>`: PFL と PPT が共有する内部関数。PFL と PPT のテストで検証する
  - `_ff_read_lines`: FF と EO が共有する内部関数。FF と EO のテストで検証する
  - `_ff_globs_to_regexes`・`_ff_is_kept`: FF の内部関数。FF のテストで検証する
  - `_ff_glob_to_regex_var <name> <glob>`: GTR と FF が共有する内部関数。GTR と FF のテストで検証する
  - `_main_check_raw_inputs`: `filter-files.sh` の内部関数。MAINF のテストで検証する
- 下の「テスト対象の略語」表は、テストを追加したコミットで、そのテストが使う略語だけを追記する (テスト ID 検査 D)。

## テスト対象の略語

| 略語  | 対象                                                                    |
|-------|-------------------------------------------------------------------------|
| WMO   | write_multiline_output (_libs/output.lib.sh)                            |
| VOF   | validate_output_file (_libs/output.lib.sh)                              |
| FE    | ff_error (_ca-filter-files/scripts/_libs/filter-files.lib.sh)           |
| CLE   | check_line_endings (_ca-filter-files/scripts/_libs/filter-files.lib.sh) |
| PFL   | parse_filelist (_ca-filter-files/scripts/_libs/filter-files.lib.sh)     |
| PPT   | parse_patterns (_ca-filter-files/scripts/_libs/filter-files.lib.sh)     |
| CBL   | check_byte_limit (.github/actions/_libs/validation.lib.sh)              |
| CLL   | check_line_limit (_ca-filter-files/scripts/_libs/filter-files.lib.sh)   |
| CP    | check_patterns (_ca-filter-files/scripts/_libs/filter-files.lib.sh)     |
| GTR   | glob_to_regex (_ca-filter-files/scripts/_libs/filter-files.lib.sh)      |
| FF    | filter_files (_ca-filter-files/scripts/_libs/filter-files.lib.sh)       |
| EO    | emit_outputs (_ca-filter-files/scripts/_libs/filter-files.lib.sh)       |
| MAINF | main (_ca-filter-files/scripts/filter-files.sh)                         |
| ACT   | action.yml (_ca-filter-files/action.yml)                                |
