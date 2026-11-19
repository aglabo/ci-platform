---
title: resolve-config
test_scope: RC
owns:
  - .github/actions/_ca-resolve-config/**
---

## resolve-config

内部 Composite Action `_ca-resolve-config` を扱うモジュール。
品質ツール (textlint / markdownlint / jactionlint / ghalint / betterleaks) が読む設定ファイルを 1 つに決める。
候補は、明示入力 `config`、リポジトリ内の `local-config`、チェックアウト済みの `global-config` を指す。
決めたファイルの絶対パスと、その出所 (`input` / `local` / `global`) を出力する。

パスの検査は共有ライブラリ `.github/actions/_libs/path.lib.sh` の `validate_path` に任せる。
`validate_path` のテスト `_libs/__tests__/unit/path.unit.spec.sh` は `test_scope: PA` で書かれている。
本モジュールの `test_scope` とは異なるため、本モジュールは所有しない。

## テスト対象の略語

テストコードは、ユニットのグループ名に ID を宣言していない。
略語は、ケース ID の第 2 セグメントから導出する。
functional のケースは、略語の代わりにシナリオ番号 (`01`〜`05`) を使う。

| 略語  | 対象                                                       |
| ----- | ---------------------------------------------------------- |
| `RC`  | `resolve_config` (`resolve-config.lib.sh`)                 |
| `ACT` | `action.yml` (静的検査)                                    |
| `01`  | `resolve-config.sh`: 設定ファイルが解決できる              |
| `02`  | `resolve-config.sh`: 解決できずエラーになる                |
| `03`  | `resolve-config.sh`: source で読み込む                     |
| `04`  | `resolve-config.sh`: `INPUT_CONFIG` が不在で local は存在  |
| `05`  | `resolve-config.sh`: パスに空白を含む                      |
