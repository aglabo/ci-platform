---
title: resolve-sha
test_scope: RS
owns:
  - .github/actions/_ca-resolve-sha/**
  - .github/actions/_libs/__tests__/unit/validation-load-guard.unit.spec.sh
  - .github/actions/_libs/__tests__/unit/validate-positive-int.unit.spec.sh
  - .github/actions/_libs/__tests__/unit/write-output.unit.spec.sh
---

## resolve-sha

内部 Composite Action `_ca-resolve-sha` の差分基準 SHA 解決を扱うモジュール。
`ca-get-changed-files` の base/head SHA 解決ロジックを切り出し、入力検証・イベント別の SHA 解決・出力の書き出しを提供する。
共有ライブラリ `.github/actions/_libs/` への追加分 (ロードガード、`validate_positive_int`、`write_output`) のテストは、ファイル単位で本モジュールが所有する。

## テスト対象の略語

| 略語   | 対象                                |
| ------ | ----------------------------------- |
| `VLG`  | `validation.lib.sh` のロードガード  |
| `VPI`  | `validate_positive_int`             |
| `WO`   | `write_output`                      |
| `RE`   | `rs_error`                          |
| `NCC`  | `normalize_commit_count`            |
| `VOV`  | `validate_override`                 |
| `IPC`  | `is_partial_clone`                  |
| `IC`   | `is_commit`                         |
| `VC`   | `verify_commit`                     |
| `RHN`  | `resolve_head_n`                    |
| `RSH`  | `resolve_sha`                       |
| `EO`   | `emit_outputs`                      |
| `RLG`  | `resolve-sha.lib.sh` のロードガード |
| `MAIN` | `resolve-sha.sh` の `main`          |
| `ACT`  | `action.yml`                        |
| `GF`   | テストフィクスチャ `git-fixture.sh` |
