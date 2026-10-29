---
title: get-changed-files
test_scope: GCF
owns:
  - .github/actions/ca-get-changed-files/**
---

## get-changed-files

公開 Composite Action `ca-get-changed-files` の変更ファイル取得を扱うモジュール。
差分範囲の 2 つの SHA の間で変更されたファイルを `git diff` で取得し、そのリストと件数を返す。
Issue #134 で、`before-sha` / `after-sha` 入力を `commit-count` に置き換える。
SHA の解決を `_ca-resolve-sha` (#135)、glob による絞り込みを `_ca-filter-files` (#136) が受け持つ構成に変える。

## 関数一覧

本モジュールの公開関数・テスト対象と、テスト ID に使う略語の一覧とする。
spec と impl はこの一覧を参照し、関数名・シグネチャ・所在を再掲しない。

| テストの略語 | 関数                                       | 所在                                                          | 担当仕様                 |
|--------------|--------------------------------------------|---------------------------------------------------------------|--------------------------|
| LCF          | `list_changed_files <before> <after>`      | `ca-get-changed-files/scripts/_libs/get-changed-files.lib.sh` | specifications-diff.md   |
| MAINF        | `main` (functional テスト)                 | `ca-get-changed-files/scripts/get-changed-files.sh`           | specifications-diff.md   |
| RUNF         | 3 つのスクリプトの連鎖 (functional テスト) | `ca-get-changed-files/action.yml` の step 順                  | specifications-action.md |
| GACT         | `action.yml` と配下の静的検査              | `ca-get-changed-files/action.yml`                             | specifications-action.md |

- 略語は綴り全体で 1 個とする。
- 旧テスト (`T-gcf-*`・`T-rsv-*`・`T-rsl-*`・`T-wrt-*`) は削除し、上の略語で書き直す。
- 下の「テスト対象の略語」表は、テストを追加したコミットで、そのテストが使う略語だけを追記する (テスト ID 検査 D)。

## テスト対象の略語

| 略語 | 対象 |
| ---- | ---- |
|      |      |
