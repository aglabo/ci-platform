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

## テスト対象の略語

| 略語 | 対象 |
| ---- | ---- |
|      |      |
