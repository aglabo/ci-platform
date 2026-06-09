---
title: "Implementation Tasks"
module: "composite-action/setup-tool"
status: Active
created: "2026-06-07 00:00:00"
source: specifications.md
---

<!-- cspell:words rhysd rwxr invalidrepo fta fcu nrm vld rep ver dir arc url res dwn vfy ext cln sts act -->

<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/max-comma -->
<!-- markdownlint-disable no-duplicate-heading line-length -->

> このドキュメントは specifications.md と implementation.md から導出した実装タスク一覧です。
> 各タスクは単一の BDD テストケース（`it()` ブロック）に 1 対 1 で対応します。
>
> **テスト ID 形式**: `T-<scope>-<kind>-<nn>`
>
> - scope: 対象関数の3文字短縮形
> - kind: `nor`=正常系 / `err`=異常系 / `edg`=エッジケース
> - nn: scope+kind 内での2桁連番（01, 02, …）

---

## Scope 一覧

| scope | 対象関数/対象        | ライブラリ                                 |
| ----- | -------------------- | ------------------------------------------ |
| nrm   | normalize_version    | `.github/actions/_libs/version.lib.sh`     |
| vld   | validate_symbol      | `.github/actions/_libs/validation.lib.sh`  |
| rep   | validate_repo        | `.github/actions/_libs/validation.lib.sh`  |
| ver   | validate_version     | `.github/actions/_libs/validation.lib.sh`  |
| dir   | setup_dirs           | `setup-tool/scripts/_libs/dirs.lib.sh`     |
| arc   | detect_arch          | `setup-tool/scripts/_libs/arch.lib.sh`     |
| url   | build_url            | `setup-tool/scripts/_libs/download.lib.sh` |
| fta   | _fetch_assets        | `setup-tool/scripts/_libs/download.lib.sh` |
| fcu   | _find_checksum_url   | `setup-tool/scripts/_libs/download.lib.sh` |
| res   | resolve_assets       | `setup-tool/scripts/_libs/download.lib.sh` |
| dwn   | download_tool        | `setup-tool/scripts/_libs/download.lib.sh` |
| vfy   | verify_checksum      | `setup-tool/scripts/_libs/download.lib.sh` |
| ext   | extract_install      | `setup-tool/scripts/_libs/install.lib.sh`  |
| cln   | cleanup              | `setup-tool/scripts/_libs/install.lib.sh`  |
| sts   | setup-tool.sh (main) | `setup-tool/scripts/setup-tool.sh`         |
| act   | action.yml           | `.github/actions/setup-tool/action.yml`    |

---

## Task Summary

| scope | 対象               | nor | err | edg | 計 | Status       |
| ----- | ------------------ | --- | --- | --- | -- | ------------ |
| nrm   | normalize_version  | 5   | 9   | 0   | 14 | done         |
| vld   | validate_symbol    | 4   | 4   | 13  | 21 | done         |
| rep   | validate_repo      | 4   | 6   | 6   | 16 | done         |
| ver   | validate_version   | 5   | 5   | 5   | 15 | done         |
| dir   | setup_dirs         | 4   | 1   | 1   | 6  | done         |
| arc   | detect_arch        | 2   | 2   | 0   | 4  | done         |
| url   | build_url          | 1   | 0   | 1   | 2  | done         |
| fta   | _fetch_assets      | 1   | 2   | 0   | 3  | done         |
| fcu   | _find_checksum_url | 1   | 0   | 0   | 1  | done         |
| res   | resolve_assets     | 3   | 5   | 2   | 10 | done         |
| dwn   | download_tool      | 2   | 2   | 0   | 4  | done         |
| vfy   | verify_checksum    | 1   | 4   | 2   | 7  | done         |
| ext   | extract_install    | 2   | 2   | 1   | 5  | done         |
| cln   | cleanup            | 2   | 0   | 1   | 3  | done         |
| sts   | setup-tool.sh      | 12  | 10  | 4   | 26 | 一部 backlog |
| act   | action.yml         | 7   | 0   | 0   | 7  | done         |

> **注**: sts-err-08〜11 はバックログ（tasks.md に定義済み・spec 未実装）。

---

## normalize_version (scope: nrm)

> テストファイル: `.github/actions/_libs/__tests__/unit/normalize-version.unit.spec.sh`

### [正常] Normal Cases

- [x] **T-nrm-nor-01**: `v1.2.3` が `1.2.3` に正規化される
  - Scenario: Given version=`v1.2.3`、When `normalize_version` を呼び出す
  - Expected: Then stdout が `1.2.3` である

- [x] **T-nrm-nor-02**: `V1.2.3`（大文字V）も `1.2.3` に正規化される
  - Scenario: Given version=`V1.2.3`、When `normalize_version` を呼び出す
  - Expected: Then stdout が `1.2.3` である

- [x] **T-nrm-nor-03**: プレフィックスなしの `1.2.3` はそのまま出力される
  - Scenario: Given version=`1.2.3`、When `normalize_version` を呼び出す
  - Expected: Then stdout が `1.2.3` である

- [x] **T-nrm-nor-04**: `1.7`（X.Y 形式）が `1.7.0` に正規化される
  - Scenario: Given version=`1.7`、When `normalize_version` を呼び出す
  - Expected: Then stdout が `1.7.0` である

- [x] **T-nrm-nor-05**: `v1.7`（X.Y 形式・v プレフィックス）が `1.7.0` に正規化される
  - Scenario: Given version=`v1.7`、When `normalize_version` を呼び出す
  - Expected: Then stdout が `1.7.0` である

### [異常] Error Cases

- [x] **T-nrm-err-01**: X.Y.Z 形式でない `latest` で exit 1 で失敗する
  - Scenario: Given version=`latest`、When `normalize_version` を呼び出す
  - Expected: Then exit 1 で終了する

- [x] **T-nrm-err-02**: 空文字を渡したとき exit 1 で失敗する
  - Scenario: Given version=``（空文字）、When `normalize_version` を呼び出す
  - Expected: Then exit 1 で終了する

- [x] **T-nrm-err-03**: prerelease サフィックス付きの `1.2.3-beta` は exit 1 で失敗する
  - Scenario: Given version=`1.2.3-beta`、When `normalize_version` を呼び出す
  - Expected: Then stderr に `Invalid version format` が出力されて exit 1 で終了する

- [x] **T-nrm-err-04**: 数字以外の patch を含む `1.2.x` は exit 1 で失敗する
  - Scenario: Given version=`1.2.x`、When `normalize_version` を呼び出す
  - Expected: Then stderr に `Invalid version format` が出力されて exit 1 で終了する

- [x] **T-nrm-err-05**: `v` のみを渡したとき exit 1 で失敗する
  - Scenario: Given version=`v`、When `normalize_version` を呼び出す
  - Expected: Then stderr に `Invalid version format` が出力されて exit 1 で終了する

- [x] **T-nrm-err-06**: 4要素の `1.2.3.4` は exit 1 で失敗する
  - Scenario: Given version=`1.2.3.4`、When `normalize_version` を呼び出す
  - Expected: Then stderr に `Invalid version format` が出力されて exit 1 で終了する

- [x] **T-nrm-err-07**: 末尾ドットの `1.2.` は exit 1 で失敗する
  - Scenario: Given version=`1.2.`、When `normalize_version` を呼び出す
  - Expected: Then stderr に `Invalid version format` が出力されて exit 1 で終了する

- [x] **T-nrm-err-08**: `vv1.2.3` は v 除去後も不正として exit 1 で失敗する
  - Scenario: Given version=`vv1.2.3`、When `normalize_version` を呼び出す
  - Expected: Then stderr に `Invalid version format` が出力されて exit 1 で終了する

- [x] **T-nrm-err-09**: `1` は X.Y.Z 形式でないため exit 1 で失敗する
  - Scenario: Given version=`1`、When `normalize_version` を呼び出す
  - Expected: Then stderr に `Invalid version format` が出力されて exit 1 で終了する

---

## validate_symbol (scope: vld)

> テストファイル: `.github/actions/_libs/__tests__/unit/validation.unit.spec.sh`

### [正常] Normal Cases

- [x] **T-vld-nor-01**: 有効な tool-name `actionlint` でパターン一致のとき exit 0 で成功する
  - Scenario: Given value=`actionlint`・pattern=`^[a-z][a-z0-9_-]*$`、When `validate_symbol` を呼び出す
  - Expected: Then exit 0 で正常終了する

- [x] **T-vld-nor-02**: owner/repo 形式の値がパターンに一致する
  - Scenario: Given value=`rhysd/actionlint`・pattern=`^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$`、When `validate_symbol` を呼び出す
  - Expected: Then exit 0 で正常終了する

- [x] **T-vld-nor-03**: 長さ制限付き tool-name パターンに一致する
  - Scenario: Given value=`actionlint`・pattern=`^[a-z][a-z0-9_-]{0,63}$`、When `validate_symbol` を呼び出す
  - Expected: Then exit 0 で正常終了する

- [x] **T-vld-nor-04**: 数字・ハイフン・アンダースコアを含む tool-name がパターンに一致する
  - Scenario: Given value=`my-tool_v2`・pattern=`^[a-z][a-z0-9_-]{0,63}$`、When `validate_symbol` を呼び出す
  - Expected: Then exit 0 で正常終了する

### [異常] Error Cases

- [x] **T-vld-err-01**: パターン不一致のとき ::error:: を出力して exit 1 で失敗する
  - Scenario: Given value=`invalid value!`（不正文字含む）・pattern=`^[a-z]+$`、When `validate_symbol` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-vld-err-02**: 空文字でパターン不一致のとき exit 1 で失敗する
  - Scenario: Given value=``（空文字）、When `validate_symbol` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-vld-err-03**: エラー出力に field_name が含まれる
  - Scenario: Given value=`INVALID`・field_name=`my-field`・pattern=`^[a-z]+$`、When `validate_symbol` を呼び出す
  - Expected: Then stderr に `my-field` と `::error::` が出力されて exit 1 で終了する

- [x] **T-vld-err-04**: エラー出力に不正な value が含まれる
  - Scenario: Given value=`INVALID`・field_name=`tool-name`・pattern=`^[a-z]+$`、When `validate_symbol` を呼び出す
  - Expected: Then stderr に `INVALID` と `::error::` が出力されて exit 1 で終了する

### [エッジケース] Edge Cases

- [x] **T-vld-edg-01**: 大文字を含む値は小文字開始の tool-name パターンで拒否される
  - Scenario: Given value=`ActionLint`・pattern=`^[a-z][a-z0-9_-]*$`、When `validate_symbol` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-vld-edg-02**: 数字始まりの値は tool-name パターンで拒否される
  - Scenario: Given value=`1tool`・pattern=`^[a-z][a-z0-9_-]*$`、When `validate_symbol` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-vld-edg-03**: アンカー自動付与により部分一致は拒否される
  - Scenario: Given value=`abc!`・pattern=`[a-z]+`、When `validate_symbol` を呼び出す
  - Expected: Then `^[a-z]+$` 相当の完全一致として評価され、exit 1 で終了する

- [x] **T-vld-edg-04**: 64文字の tool-name は長さ境界として成功する
  - Scenario: Given value が64文字・pattern=`^[a-z][a-z0-9_-]{0,63}$`・max_length=0、When `validate_symbol` を呼び出す
  - Expected: Then exit 0 で正常終了する

- [x] **T-vld-edg-05**: 65文字の tool-name はパターン不一致で拒否される
  - Scenario: Given value が65文字・pattern=`^[a-z][a-z0-9_-]{0,63}$`・max_length=0、When `validate_symbol` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-vld-edg-06**: max_length と同じ長さの値は成功する
  - Scenario: Given value=`abcdefghij`・max_length=10、When `validate_symbol` を呼び出す
  - Expected: Then exit 0 で正常終了する

- [x] **T-vld-edg-07**: max_length を超える値は拒否される
  - Scenario: Given value=`abcdefghijk`・max_length=10、When `validate_symbol` を呼び出す
  - Expected: Then stderr に `value too long` と `::error::` が出力されて exit 1 で終了する

- [x] **T-vld-edg-08**: max_length=0 の場合は長さ制限なしで成功する
  - Scenario: Given value=`abcdefghijk`・max_length=0、When `validate_symbol` を呼び出す
  - Expected: Then pattern に一致する限り exit 0 で正常終了する

- [x] **T-vld-edg-09**: max_length 指定時でも空文字は拒否される
  - Scenario: Given value=``・max_length=10、When `validate_symbol` を呼び出す
  - Expected: Then stderr に `value must not be empty` と `::error::` が出力されて exit 1 で終了する

- [x] **T-vld-edg-10**: アンカーなし pattern は両端補完され完全一致で成功する
  - Scenario: Given value=`abc`・pattern=`[a-z]+`、When `validate_symbol` を呼び出す
  - Expected: Then exit 0 で正常終了する

- [x] **T-vld-edg-11**: `^` のみある pattern は `$` が補完され成功する
  - Scenario: Given value=`abc`・pattern=`^[a-z]+`、When `validate_symbol` を呼び出す
  - Expected: Then exit 0 で正常終了する

- [x] **T-vld-edg-12**: `^` のみある pattern は `$` 補完後に末尾不一致を拒否する
  - Scenario: Given value=`abc!`・pattern=`^[a-z]+`、When `validate_symbol` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-vld-edg-13**: 両端アンカーあり pattern は二重補完されず成功する
  - Scenario: Given value=`abc`・pattern=`^[a-z]+$`、When `validate_symbol` を呼び出す
  - Expected: Then exit 0 で正常終了する

---

## validate_repo (scope: rep)

> テストファイル: `.github/actions/_libs/__tests__/unit/validation.unit.spec.sh`

### [正常] Normal Cases

- [x] **T-rep-nor-01**: 有効な `rhysd/actionlint` でパターン一致のとき exit 0 で成功する
  - Scenario: Given repo_id=`rhysd/actionlint`、When `validate_repo` を呼び出す
  - Expected: Then exit 0 で正常終了する

- [x] **T-rep-nor-02**: 混在ケース `Microsoft/vscode` は exit 0 で成功する
  - Scenario: Given repo_id=`Microsoft/vscode`（先頭大文字 owner）、When `validate_repo` を呼び出す
  - Expected: Then exit 0 で正常終了する

- [x] **T-rep-nor-03**: ハイフン・アンダースコア・ドットを含む `my-org/repo_name.test` は exit 0 で成功する
  - Scenario: Given repo_id=`my-org/repo_name.test`、When `validate_repo` を呼び出す
  - Expected: Then exit 0 で正常終了する

- [x] **T-rep-nor-04**: 最短有効値 `A/b` は exit 0 で成功する
  - Scenario: Given repo_id=`A/b`、When `validate_repo` を呼び出す
  - Expected: Then exit 0 で正常終了する

### [異常] Error Cases

- [x] **T-rep-err-01**: スラッシュがない `invalidrepo` は exit 1 で拒否される
  - Scenario: Given repo_id=`invalidrepo`（スラッシュなし）、When `validate_repo` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-rep-err-02**: スラッシュが 2 個の `owner/repo/extra` は exit 1 で拒否される
  - Scenario: Given repo_id=`owner/repo/extra`、When `validate_repo` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-rep-err-03**: パストラバーサル形式の `../evil/path` は exit 1 で拒否される
  - Scenario: Given repo_id=`../evil/path`、When `validate_repo` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-rep-err-04**: ハイフン始まりの `-owner/repo` は exit 1 で拒否される
  - Scenario: Given repo_id=`-owner/repo`、When `validate_repo` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-rep-err-05**: owner 内のアンダースコアを含む `own_er/repo` は exit 1 で拒否される
  - Scenario: Given repo_id=`own_er/repo`、When `validate_repo` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-rep-err-06**: 空文字は `::error::` を出力して exit 1 で拒否される
  - Scenario: Given repo_id=``（空文字）、When `validate_repo` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

### [エッジケース] Edge Cases

- [x] **T-rep-edg-01**: owner が 39 文字の場合は最大長境界として exit 0 で成功する
  - Scenario: Given repo_id で owner 部分が 39 文字（`{0,38}` の上限）、When `validate_repo` を呼び出す
  - Expected: Then exit 0 で正常終了する

- [x] **T-rep-edg-02**: owner が 40 文字の場合は最大長超過として exit 1 で拒否される
  - Scenario: Given repo_id で owner 部分が 40 文字（`{0,38}` を超過）、When `validate_repo` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-rep-edg-03**: repo が 100 文字の場合は最大長境界として exit 0 で成功する
  - Scenario: Given repo_id で repo 部分が 100 文字（`{1,100}` の上限）、When `validate_repo` を呼び出す
  - Expected: Then exit 0 で正常終了する

- [x] **T-rep-edg-04**: repo が 101 文字の場合は最大長超過として exit 1 で拒否される
  - Scenario: Given repo_id で repo 部分が 101 文字（`{1,100}` を超過）、When `validate_repo` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-rep-edg-05**: 数字始まりの `1owner/repo` は exit 1 で拒否される
  - Scenario: Given repo_id=`1owner/repo`（数字始まり owner）、When `validate_repo` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-rep-edg-06**: `field_name` 省略時のデフォルト値は `repo` であり、エラー stderr に `repo:` が含まれる
  - Scenario: Given repo_id=`bad`・field_name 省略、When `validate_repo` を呼び出す
  - Expected: Then stderr に `repo:` と `::error::` が出力されて exit 1 で終了する

---

## validate_version (scope: ver)

> テストファイル: `.github/actions/_libs/__tests__/unit/validation.unit.spec.sh`

### [正常] Normal Cases

- [x] **T-ver-nor-01**: `1.2.3` は有効な X.Y.Z 形式として exit 0 で成功する
  - Scenario: Given version=`1.2.3`、When `validate_version` を呼び出す
  - Expected: Then exit 0 で正常終了する

- [x] **T-ver-nor-02**: `v1.2.3` は小文字 v プレフィックス付き X.Y.Z として exit 0 で成功する
  - Scenario: Given version=`v1.2.3`、When `validate_version` を呼び出す
  - Expected: Then exit 0 で正常終了する

- [x] **T-ver-nor-03**: `V1.2.3` は大文字 V プレフィックス付き X.Y.Z として exit 0 で成功する
  - Scenario: Given version=`V1.2.3`、When `validate_version` を呼び出す
  - Expected: Then exit 0 で正常終了する

- [x] **T-ver-nor-04**: `1.7` は X.Y 形式として exit 0 で成功する
  - Scenario: Given version=`1.7`、When `validate_version` を呼び出す
  - Expected: Then exit 0 で正常終了する

- [x] **T-ver-nor-05**: `v1.7` は v プレフィックス付き X.Y 形式として exit 0 で成功する
  - Scenario: Given version=`v1.7`、When `validate_version` を呼び出す
  - Expected: Then exit 0 で正常終了する

### [異常] Error Cases

- [x] **T-ver-err-01**: `latest` は非数値形式のため exit 1 で拒否される
  - Scenario: Given version=`latest`、When `validate_version` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-ver-err-02**: 空文字は exit 1 で拒否され stderr に `::error::` が含まれる
  - Scenario: Given version=``（空文字）、When `validate_version` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-ver-err-03**: `1.2.3-beta` はプレリリースサフィックス付きのため exit 1 で拒否される
  - Scenario: Given version=`1.2.3-beta`、When `validate_version` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-ver-err-04**: `1` は単独数字（X.Y 未満）のため exit 1 で拒否される
  - Scenario: Given version=`1`、When `validate_version` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-ver-err-05**: `vv1.2.3` は二重 v プレフィックスのため exit 1 で拒否される
  - Scenario: Given version=`vv1.2.3`、When `validate_version` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

### [エッジケース] Edge Cases

- [x] **T-ver-edg-01**: `1.2.3.4` は 4 要素形式のため exit 1 で拒否される
  - Scenario: Given version=`1.2.3.4`、When `validate_version` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-ver-edg-02**: `1.2.` は末尾ドット付きのため exit 1 で拒否される
  - Scenario: Given version=`1.2.`、When `validate_version` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-ver-edg-03**: `0.0.0` は全ゼロだが有効な X.Y.Z として exit 0 で成功する
  - Scenario: Given version=`0.0.0`、When `validate_version` を呼び出す
  - Expected: Then exit 0 で正常終了する

- [x] **T-ver-edg-04**: `v` はプレフィックスのみ（数字なし）のため exit 1 で拒否される
  - Scenario: Given version=`v`、When `validate_version` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-ver-edg-05**: `field_name` 省略時のデフォルト値は `version` であり、stderr に `version:` が含まれる
  - Scenario: Given version=`bad`・field_name 省略、When `validate_version` を呼び出す
  - Expected: Then stderr に `version:` と `::error::` が出力されて exit 1 で終了する

---

## setup_dirs (scope: dir)

> テストファイル: `setup-tool/scripts/_libs/__tests__/unit/dirs.unit.spec.sh`

### [正常] Normal Cases

- [x] **T-dir-nor-01**: BIN_DIR が `${RUNNER_TEMP}/bin` として作成される
  - Scenario: Given RUNNER_TEMP が設定済み、When `setup_dirs` を呼び出す
  - Expected: Then `${RUNNER_TEMP}/bin` ディレクトリが存在する

- [x] **T-dir-nor-02**: TEMP_DIR が `mktemp -d` で動的生成される
  - Scenario: Given RUNNER_TEMP が設定済み、When `setup_dirs` を呼び出す
  - Expected: Then TEMP_DIR が空でないパスとして設定されており、ディレクトリが存在する

- [x] **T-dir-nor-03**: BIN_DIR が GITHUB_PATH に書き込まれる
  - Scenario: Given GITHUB_PATH ファイルが存在する、When `setup_dirs` を呼び出す
  - Expected: Then GITHUB_PATH ファイルに BIN_DIR のパスが追記されている

- [x] **T-dir-nor-04**: BIN_DIR と TEMP_DIR が GITHUB_ENV に書き込まれる
  - Scenario: Given GITHUB_ENV ファイルが存在する、When `setup_dirs` を呼び出す
  - Expected: Then GITHUB_ENV に `BIN_DIR=...` と `TEMP_DIR=...` が追記されている

### [異常] Error Cases

- [x] **T-dir-err-01**: RUNNER_TEMP 未設定時に exit 1 で失敗する
  - Scenario: Given RUNNER_TEMP が未設定、When `setup_dirs` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

### [エッジケース] Edge Cases

- [x] **T-dir-edg-01**: GITHUB_ENV が未設定でもディレクトリ作成は成功する
  - Scenario: Given GITHUB_ENV が未設定（GITHUB_PATH も未設定）、When `setup_dirs` を呼び出す
  - Expected: Then BIN_DIR・TEMP_DIR は作成され、exit 0 で終了する

---

## detect_arch (scope: arc)

> テストファイル: `setup-tool/scripts/_libs/__tests__/unit/arch.unit.spec.sh`

### [正常] Normal Cases

- [x] **T-arc-nor-01**: RUNNER_ARCH=X64 のとき amd64 と x64 を1行1値で出力する
  - Scenario: Given RUNNER_ARCH=X64、When `detect_arch` を呼び出す
  - Expected: Then stdout の1行目が `amd64`、2行目が `x64` である

- [x] **T-arc-nor-02**: RUNNER_ARCH=ARM64 のとき arm64 を1行で出力する
  - Scenario: Given RUNNER_ARCH=ARM64、When `detect_arch` を呼び出す
  - Expected: Then stdout の1行目が `arm64` のみである

### [異常] Error Cases

- [x] **T-arc-err-01**: 未知の RUNNER_ARCH で ::error:: を出力して exit 1 で失敗する
  - Scenario: Given RUNNER_ARCH=MIPS（未知の値）、When `detect_arch` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-arc-err-02**: RUNNER_ARCH が空文字のとき exit 1 で失敗する
  - Scenario: Given RUNNER_ARCH が空文字、When `detect_arch` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

---

## build_url (scope: url)

> テストファイル: `setup-tool/scripts/_libs/__tests__/unit/download.unit.spec.sh`

### [正常] Normal Cases

- [x] **T-url-nor-01**: owner/repo 形式と normalize_version 適用済み version で正しい API URL が構築される
  - Scenario: Given repo=`rhysd/actionlint`・version=`1.7.7`（v なし）、When `build_url` を呼び出す
  - Expected: Then stdout が `https://api.github.com/repos/rhysd/actionlint/releases/tags/v1.7.7` である

### [エッジケース] Edge Cases

- [x] **T-url-edg-01**: v 付き version を渡しても URL が vv 二重にならない
  - Scenario: Given version=`v1.7.7`（normalize_version 未適用）、When `build_url` を呼び出す
  - Expected: Then stdout の URL に `vv1.7.7` が含まれず、`v1.7.7` のパスとして構築される

---

## _fetch_assets (scope: fta)

> テストファイル: `setup-tool/scripts/_libs/__tests__/unit/download.unit.spec.sh`

### [正常] Normal Cases

- [x] **T-fta-nor-01**: _fetch_assets が asset 一覧を `name\turl` 形式で出力する
  - Scenario: Given curl が有効な JSON レスポンスを返す、When `_fetch_assets` を呼び出す
  - Expected: Then stdout に `actionlint_1.7.7_linux_amd64.tar.gz` が含まれる

### [異常] Error Cases

- [x] **T-fta-err-01**: curl 失敗時に ::error:: を出力して exit 2 で失敗する
  - Scenario: Given curl が失敗する（exit 1）、When `_fetch_assets` を呼び出す
  - Expected: Then stderr に `::error::` が含まれ exit 2 で終了する

- [x] **T-fta-err-02**: curl 成功でも HTTP 404 のとき ::error:: と 404 を出力して exit 2 で失敗する
  - Scenario: Given curl が exit 0 で HTTP 404 JSON を返す、When `_fetch_assets` を呼び出す
  - Expected: Then stderr に `::error::` と `404` が含まれ exit 2 で終了する

---

## _find_checksum_url (scope: fcu)

> テストファイル: `setup-tool/scripts/_libs/__tests__/unit/download.unit.spec.sh`

### [正常] Normal Cases

- [x] **T-fcu-nor-01**: `checksums.txt` を `*_checksums.txt` より優先して返す
  - Scenario: Given _pairs に `checksums.txt` と `actionlint_1.7.7_checksums.txt` の両方が含まれる、When `_find_checksum_url` を呼び出す
  - Expected: Then `checksums.txt` の URL が返される

---

## resolve_assets (scope: res)

> テストファイル: `setup-tool/scripts/_libs/__tests__/unit/download.unit.spec.sh`

### [正常] Normal Cases

- [x] **T-res-nor-01**: ARCH_CANDIDATES の最初の候補に一致する tar.gz URL が1行目に出力される
  - Scenario: Given API レスポンスに `actionlint_1.7.7_linux_amd64.tar.gz` が含まれる、When `resolve_assets` を ARCH_CANDIDATES=`[amd64,x64]` で呼び出す
  - Expected: Then stdout の1行目が amd64 のダウンロード URL、3行目が `amd64` である

- [x] **T-res-nor-02**: `checksums.txt` が存在する場合はそちらが2行目に出力される
  - Scenario: Given アセット一覧に `checksums.txt` が含まれる、When `resolve_assets` を呼び出す
  - Expected: Then stdout の2行目の URL に `checksums.txt` が含まれる

- [x] **T-res-nor-03**: `{tool}_{version}_checksums.txt` 形式にフォールバックする
  - Scenario: Given `checksums.txt` がなく `actionlint_1.7.7_checksums.txt` がある、When `resolve_assets` を呼び出す
  - Expected: Then stdout の2行目の URL に `actionlint_1.7.7_checksums.txt` が含まれる

### [異常] Error Cases

- [x] **T-res-err-01**: 全候補が不一致のとき ::error:: を出力して exit 2 で失敗する
  - Scenario: Given アセット一覧に amd64・x64 どちらも存在しない、When `resolve_assets` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 2 で終了する

- [x] **T-res-err-02**: GitHub API 呼び出し失敗時に exit 2 で失敗する
  - Scenario: Given curl が失敗する（API 接続不可）、When `resolve_assets` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 2 で終了する

- [x] **T-res-err-03**: checksums.txt 候補が両方とも存在しない場合に exit 2 で失敗する
  - Scenario: Given tar.gz は存在するが checksums.txt 系ファイルがない、When `resolve_assets` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 2 で終了する

- [x] **T-res-err-04**: GitHub API レスポンスに assets が空の場合に exit 2 で失敗する
  - Scenario: Given API レスポンスが `{"assets":[]}`、When `resolve_assets` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 2 で終了する

- [x] **T-res-err-05**: GitHub API レスポンスが不正 JSON の場合に exit 2 で失敗する
  - Scenario: Given curl は成功するが JSON として parse できないレスポンス、When `resolve_assets` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 2 で終了する

### [エッジケース] Edge Cases

- [x] **T-res-edg-01**: amd64 がなく x64 がある場合に x64 が ARCH_SUFFIX として採用される
  - Scenario: Given アセット一覧に `linux_amd64.tar.gz` がなく `linux_x64.tar.gz` がある、When `resolve_assets` を ARCH_CANDIDATES=`[amd64,x64]` で呼び出す
  - Expected: Then stdout の3行目が `x64` であり、1行目の URL に `x64` が含まれる

- [x] **T-res-edg-02**: ARM64 候補で arm64 アセットが採用される
  - Scenario: Given アセット一覧に `linux_arm64.tar.gz` がある、When `resolve_assets` を ARCH_CANDIDATES=`[arm64]` で呼び出す
  - Expected: Then stdout の3行目が `arm64` であり、1行目の URL に `arm64` が含まれる

---

## download_tool (scope: dwn)

> テストファイル: `setup-tool/scripts/_libs/__tests__/unit/download.unit.spec.sh`

### [正常] Normal Cases

- [x] **T-dwn-nor-01**: tar.gz が `${TOOL_NAME}.tar.gz` としてリネームされて TEMP_DIR に保存される
  - Scenario: Given DOWNLOAD_URL が有効、TEMP_DIR が存在する、When `download_tool` を呼び出す
  - Expected: Then `${TEMP_DIR}/${TOOL_NAME}.tar.gz` が存在する

- [x] **T-dwn-nor-02**: checksums.txt が TEMP_DIR に保存される
  - Scenario: Given CHECKSUM_URL が有効、When `download_tool` を呼び出す
  - Expected: Then `${TEMP_DIR}/checksums.txt` が存在する

### [異常] Error Cases

- [x] **T-dwn-err-01**: tar.gz のダウンロード失敗時に ::error:: を出力して exit 2 で失敗する
  - Scenario: Given DOWNLOAD_URL が無効、When `download_tool` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 2 で終了する

- [x] **T-dwn-err-02**: checksums.txt のダウンロード失敗時に ::error:: を出力して exit 2 で失敗する
  - Scenario: Given CHECKSUM_URL が無効、When `download_tool` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 2 で終了する

---

## verify_checksum (scope: vfy)

> テストファイル: `setup-tool/scripts/_libs/__tests__/unit/download.unit.spec.sh`

### [正常] Normal Cases

- [x] **T-vfy-nor-01**: sha256sum が一致するとき exit 0 で成功する
  - Scenario: Given `${TOOL_NAME}.tar.gz` と checksums.txt のハッシュが一致する、When `verify_checksum` を呼び出す
  - Expected: Then exit 0 で正常終了する

### [異常] Error Cases

- [x] **T-vfy-err-01**: 元ファイル名のエントリが grep -w で見つからないとき exit 3 で失敗する
  - Scenario: Given checksums.txt に `{tool}_{ver}_linux_{arch}.tar.gz` のエントリがない、When `verify_checksum` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 3 で終了する

- [x] **T-vfy-err-02**: checksums.txt が存在しないとき exit 3 で失敗する
  - Scenario: Given `${TEMP_DIR}/checksums.txt` が存在しない、When `verify_checksum` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 3 で終了する

- [x] **T-vfy-err-03**: sha256sum が不一致のとき ::error:: を出力して exit 3 で失敗する
  - Scenario: Given ダウンロードファイルが破損（ハッシュ不一致）、When `verify_checksum` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 3 で終了する

- [x] **T-vfy-err-04**: リネーム後の `${TOOL_NAME}.tar.gz` が存在しないとき exit 3 で失敗する
  - Scenario: Given `${TEMP_DIR}/${TOOL_NAME}.tar.gz` が存在しない、When `verify_checksum` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 3 で終了する

### [エッジケース] Edge Cases

- [x] **T-vfy-edg-01**: grep の検索キーがリネーム前の形式（tool_ver_linux_arch.tar.gz）である
  - Scenario: Given checksums.txt に `actionlint_1.7.7_linux_amd64.tar.gz` のエントリがある、When `verify_checksum` を tool=actionlint・ver=1.7.7・arch=amd64 で呼び出す
  - Expected: Then エントリが見つかり検証が成功する

- [x] **T-vfy-edg-02**: sha256sum の対象がリネーム後の ${TOOL_NAME}.tar.gz である
  - Scenario: Given TEMP_DIR に `actionlint.tar.gz`（リネーム後）が存在する、When `verify_checksum` を呼び出す
  - Expected: Then `actionlint.tar.gz` のハッシュが検証対象となる

---

## extract_install (scope: ext)

> テストファイル: `setup-tool/scripts/_libs/__tests__/unit/install.unit.spec.sh`

### [正常] Normal Cases

- [x] **T-ext-nor-01**: バイナリが BIN_DIR に配置される
  - Scenario: Given `${TOOL_NAME}.tar.gz` 内に tool-name と一致するバイナリが存在する、When `extract_install` を呼び出す
  - Expected: Then `${BIN_DIR}/${TOOL_NAME}` が存在する

- [x] **T-ext-nor-02**: 配置されたバイナリのパーミッションが 755 である
  - Scenario: Given バイナリが BIN_DIR に配置された、When パーミッションを確認する
  - Expected: Then ファイルのパーミッションが 755（rwxr-xr-x）である

### [異常] Error Cases

- [x] **T-ext-err-01**: バイナリ不一致のとき ::error:: を出力して exit 4 で失敗する
  - Scenario: Given tar.gz 内に tool-name と一致するファイルがない、When `extract_install` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 4 で終了する

- [x] **T-ext-err-02**: tar 失敗時に ::error:: を出力して exit 4 で失敗する
  - Scenario: Given `${TOOL_NAME}.tar.gz` が破損している、When `extract_install` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 4 で終了する

### [エッジケース] Edge Cases

- [x] **T-ext-edg-01**: 既存バイナリを上書きして exit 0 で成功する（冪等性）
  - Scenario: Given BIN_DIR に既に同名バイナリが存在する、When `extract_install` を呼び出す
  - Expected: Then 上書きされて exit 0 で正常終了する

---

## cleanup (scope: cln)

> テストファイル: `setup-tool/scripts/_libs/__tests__/unit/install.unit.spec.sh`

### [正常] Normal Cases

- [x] **T-cln-nor-01**: TEMP_DIR が削除される
  - Scenario: Given TEMP_DIR が存在する、When `cleanup "${TEMP_DIR}"` を呼び出す
  - Expected: Then TEMP_DIR が存在しない

- [x] **T-cln-nor-02**: 成功メッセージが stdout に出力される
  - Scenario: Given TEMP_DIR が存在する、When `cleanup "${TEMP_DIR}"` を呼び出す
  - Expected: Then stdout に `✓ Cleanup completed` が出力される

### [エッジケース] Edge Cases

- [x] **T-cln-edg-01**: 削除済みの場合も exit 0 で成功する（冪等性）
  - Scenario: Given TEMP_DIR が既に存在しない、When `cleanup "${TEMP_DIR}"` を呼び出す
  - Expected: Then exit 0 で正常終了する

---

## setup-tool.sh (scope: sts)

> テストファイル（Unit）: `setup-tool/scripts/__tests__/unit/setup-tool.unit.spec.sh`
> テストファイル（Functional）: `setup-tool/scripts/__tests__/functional/setup-tool.functional.spec.sh`
> テストファイル（System）: `setup-tool/scripts/__tests__/system/setup-tool.system.spec.sh`

### [正常] Normal Cases — Unit

- [x] **T-sts-nor-01**: 全関数が定義された順序で呼び出される
  - Scenario: Given 全ライブラリ関数がモック化されて正常終了する、When `setup-tool.sh` を実行する
  - Expected: Then normalize_version → setup_dirs → detect_arch → resolve_assets → download_tool → verify_checksum → extract_install の順で呼び出される

- [x] **T-sts-nor-02**: 正常終了時に exit 0 で終了する
  - Scenario: Given 全関数が正常終了する、When `setup-tool.sh` を実行する
  - Expected: Then exit 0 で終了する

- [x] **T-sts-nor-03**: 混合ケース owner/repo（Microsoft/vscode）は入力検証を通過して exit 0 で終了する
  - Scenario: Given repo=`Microsoft/vscode`・全関数モック、When `setup-tool.sh` を実行する
  - Expected: Then exit 0 で終了する

### [正常] Normal Cases — Functional

- [x] **T-sts-nor-04**: `${BIN_DIR}/actionlint` が存在し実行可能である（統合）
  - Scenario: Given 有効なフィクスチャと curl モックを設定した状態で、When `setup-tool.sh` を REPO=`rhysd/actionlint` TOOL_VERSION=`1.7.7` RUNNER_ARCH=`X64` で実行する
  - Expected: Then `${BIN_DIR}/actionlint` が存在し、実行可能（chmod 755）である

- [x] **T-sts-nor-05**: 統合テスト exit 0 で終了する
  - Scenario: Given 同上
  - Expected: Then exit 0 で正常終了する

- [x] **T-sts-nor-06**: cleanup 後に TEMP_DIR が削除されている（統合）
  - Scenario: Given 全フロー正常終了後、When TEMP_DIR のパスを確認する
  - Expected: Then TEMP_DIR が存在しない（trap による cleanup が実行済み）

- [x] **T-sts-nor-07**: BIN_DIR が `${RUNNER_TEMP}/bin` として作成されている（統合）
  - Scenario: Given RUNNER_TEMP が設定済みで main が正常終了した状態で、When `${RUNNER_TEMP}/bin` を確認する
  - Expected: Then `${RUNNER_TEMP}/bin` ディレクトリが存在する

- [x] **T-sts-nor-08**: `v1.7.7` を指定しても正常終了する（統合）
  - Scenario: Given TOOL_VERSION=`v1.7.7` と有効なフィクスチャ、When `setup-tool.sh` を実行する
  - Expected: Then normalize_version により `1.7.7` として扱われ、exit 0 で正常終了する

- [x] **T-sts-nor-09**: RUNNER_ARCH=ARM64 のとき arm64 アセットを取得してインストールする（統合）
  - Scenario: Given `linux_arm64.tar.gz` のフィクスチャと curl モックを設定した状態で、When RUNNER_ARCH=`ARM64` で `setup-tool.sh` を実行する
  - Expected: Then `${BIN_DIR}/actionlint` が存在し、exit 0 で正常終了する

### [正常] Normal Cases — System

- [x] **T-sts-nor-10**: `actionlint.tar.gz` が TEMP_DIR にダウンロードされる（システム）
  - Scenario: Given 実際の GitHub Releases URL、When `download_tool` を実行する
  - Expected: Then `${TEMP_DIR}/actionlint.tar.gz` が存在しサイズが 0 より大きい

- [x] **T-sts-nor-11**: `checksums.txt` が TEMP_DIR にダウンロードされる（システム）
  - Scenario: Given 実際の GitHub Releases checksum URL、When `download_tool` を実行する
  - Expected: Then `${TEMP_DIR}/checksums.txt` が存在しサイズが 0 より大きい

- [x] **T-sts-nor-12**: 実際にダウンロードした tar.gz の SHA256 が一致する（システム）
  - Scenario: Given 実際にダウンロードした `actionlint.tar.gz` と `checksums.txt`、When `verify_checksum` を実行する
  - Expected: Then exit 0 で正常終了する

- [x] **T-sts-nor-13**: tar.gz が展開され actionlint バイナリが BIN_DIR に存在する（システム）
  - Scenario: Given 実際にダウンロードした tar.gz が TEMP_DIR にある、When `extract_install` を実行する
  - Expected: Then `${BIN_DIR}/actionlint` が存在する

- [x] **T-sts-nor-14**: actionlint が BIN_DIR にインストールされ実行可能である（システム）
  - Scenario: Given tar.gz が展開済み、When `extract_install` を実行する
  - Expected: Then `${BIN_DIR}/actionlint` が存在し実行可能（chmod 755）である

- [x] **T-sts-nor-15**: インストールされた actionlint が `--version` で実行できる（システム）
  - Scenario: Given actionlint が BIN_DIR にインストール済み、When `${BIN_DIR}/actionlint --version` を実行する
  - Expected: Then exit 0 で終了し、stdout に version 情報が出力される

### [異常] Error Cases — Unit

- [x] **T-sts-err-01**: repo が owner/repo 形式でないとき exit 1 で終了する
  - Scenario: Given REPO=`invalidrepo`（スラッシュなし）、When `setup-tool.sh` を実行する
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-sts-err-02**: tool-version が X.Y.Z 形式でないとき exit 1 で終了する
  - Scenario: Given TOOL_VERSION=`latest`（不正形式）、When `setup-tool.sh` を実行する
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-sts-err-03**: パストラバーサル形式の repo は exit 1 で拒否される
  - Scenario: Given REPO=`../evil/path`、When `setup-tool.sh` を実行する
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-sts-err-04**: スラッシュが2個ある repo は exit 1 で拒否される
  - Scenario: Given REPO=`owner/repo/extra`、When `setup-tool.sh` を実行する
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-sts-err-05**: ハイフン始まりのオーナーは exit 1 で拒否される
  - Scenario: Given REPO=`-owner/repo`、When `setup-tool.sh` を実行する
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-sts-err-06**: resolve_assets 失敗時に exit 2 で終了する
  - Scenario: Given resolve_assets が exit 2 で失敗するようにモック化されている、When `setup-tool.sh` を実行する
  - Expected: Then exit 2 で終了する

- [x] **T-sts-err-07**: verify_checksum 失敗時に exit 3 で終了する
  - Scenario: Given verify_checksum が exit 3 で失敗するようにモック化されている、When `setup-tool.sh` を実行する
  - Expected: Then exit 3 で終了する

- [ ] **T-sts-err-08** *(backlog)*: setup_dirs 失敗時に exit 1 で終了する
  - Scenario: Given setup_dirs が exit 1 で失敗するようにモック化されている、When `setup-tool.sh` を実行する
  - Expected: Then exit 1 で終了する

- [ ] **T-sts-err-09** *(backlog)*: detect_arch 失敗時に exit 1 で終了する
  - Scenario: Given detect_arch が exit 1 で失敗するようにモック化されている、When `setup-tool.sh` を実行する
  - Expected: Then exit 1 で終了する

- [ ] **T-sts-err-10** *(backlog)*: download_tool 失敗時に exit 2 で終了する
  - Scenario: Given download_tool が exit 2 で失敗するようにモック化されている、When `setup-tool.sh` を実行する
  - Expected: Then exit 2 で終了する

- [ ] **T-sts-err-11** *(backlog)*: extract_install 失敗時に exit 4 で終了する
  - Scenario: Given extract_install が exit 4 で失敗するようにモック化されている、When `setup-tool.sh` を実行する
  - Expected: Then exit 4 で終了する

### [異常] Error Cases — Functional

- [x] **T-sts-err-12**: curl 失敗時に `${BIN_DIR}/actionlint` が作成されず exit 2 で終了する（統合）
  - Scenario: Given curl が常に失敗するようにモックされている、When `setup-tool.sh` を実行する
  - Expected: Then `${BIN_DIR}/actionlint` が存在せず、exit 2 で終了する

- [x] **T-sts-err-13**: checksum 不一致時に `${BIN_DIR}/actionlint` が作成されず exit 3 で終了する（統合）
  - Scenario: Given checksums.txt のハッシュが tar.gz と一致しない、When `setup-tool.sh` を実行する
  - Expected: Then `${BIN_DIR}/actionlint` が存在せず、`::error::` が stderr に出力されて exit 3 で終了する

- [x] **T-sts-err-14**: tar.gz 破損時に `${BIN_DIR}/actionlint` が作成されず exit 4 で終了する（統合）
  - Scenario: Given ダウンロードされる tar.gz が破損している、When `setup-tool.sh` を実行する
  - Expected: Then `${BIN_DIR}/actionlint` が存在せず、`::error::` が stderr に出力されて exit 4 で終了する

### [エッジケース] Edge Cases — Unit

- [x] **T-sts-edg-01**: 中間ステップ失敗後も trap により cleanup が実行される
  - Scenario: Given download_tool が exit 2 で失敗する、When `setup-tool.sh` を実行する
  - Expected: Then `cleanup "${TEMP_DIR}"` が EXIT trap により実行される

### [エッジケース] Edge Cases — Functional

- [x] **T-sts-edg-02**: `checksums.txt` がなく `{tool}_{version}_checksums.txt` がある場合も正常終了する（統合）
  - Scenario: Given アセット一覧に `checksums.txt` がなく `actionlint_1.7.7_checksums.txt` がある、When `setup-tool.sh` を実行する
  - Expected: Then versioned checksums URL が選択され、exit 0 で正常終了する

- [x] **T-sts-edg-03**: download_tool 失敗後も TEMP_DIR が削除される（統合）
  - Scenario: Given download_tool 相当の curl が失敗する、When `setup-tool.sh` を実行する
  - Expected: Then exit 2 で終了し、TEMP_DIR が存在しない

- [x] **T-sts-edg-04**: verify_checksum 失敗後も TEMP_DIR が削除される（統合）
  - Scenario: Given checksum 不一致で verify_checksum が失敗する、When `setup-tool.sh` を実行する
  - Expected: Then exit 3 で終了し、TEMP_DIR が存在しない

### [エッジケース] Edge Cases — System

- [x] **T-sts-edg-05**: CI または明示フラグがないローカル環境では skip できる（システム）
  - Scenario: Given 実ネットワークテスト実行フラグが未設定、When system spec を実行する
  - Expected: Then 実ネットワーク依存ケースは skip され、ローカル実行で不安定に失敗しない

---

## action.yml (scope: act)

> テストファイル: `setup-tool/scripts/__tests__/integration/action.integration.spec.sh`

### [正常] Normal Cases

- [x] **T-act-nor-01**: inputs.repo が action.yml に定義されている
  - Scenario: Given action.yml、When YAML を検査する
  - Expected: Then `inputs.repo` が存在する

- [x] **T-act-nor-02**: tool-version に固定デフォルト値が定義されている
  - Scenario: Given action.yml、When YAML を検査する
  - Expected: Then `inputs.tool-version.default` が `X.Y.Z` 形式で定義されている

- [x] **T-act-nor-03**: `runs.using` が `composite` である
  - Scenario: Given action.yml、When YAML を検査する
  - Expected: Then `runs.using` が `composite` である

- [x] **T-act-nor-04**: setup-tool.sh が1ステップで呼び出される
  - Scenario: Given action.yml、When `runs.steps` を検査する
  - Expected: Then `scripts/setup-tool.sh` を呼び出す step が存在する

- [x] **T-act-nor-05**: TOOL_REPO env 変数が inputs.repo を渡している
  - Scenario: Given action.yml、When env 定義を検査する
  - Expected: Then `TOOL_REPO` が `${{ inputs.repo }}` 相当で定義されている

- [x] **T-act-nor-06**: TOOL_VERSION env 変数が inputs.tool-version を渡している
  - Scenario: Given action.yml、When env 定義を検査する
  - Expected: Then `TOOL_VERSION` が `${{ inputs.tool-version }}` 相当で定義されている

- [x] **T-act-nor-07**: action.yml から参照される setup-tool.sh が実在する
  - Scenario: Given action.yml の run コマンド、When 参照先スクリプトの存在を検査する
  - Expected: Then 参照先が存在する

---

## 既知の設計制約（テストスコープ外）

以下は現在の実装が前提としている制約であり、追加テストの対象ではなくドキュメントとして管理する。

| 制約                 | 影響関数                           | 内容                                                                                           |
| -------------------- | ---------------------------------- | ---------------------------------------------------------------------------------------------- |
| アーカイブ形式       | `download_tool`, `extract_install` | `.tar.gz` 形式のみサポート。`.zip` や `.tar.xz` は対象外                                       |
| バイナリ配置         | `extract_install`                  | アーカイブルート直下に `${tool_name}` が存在することを前提とする。サブディレクトリ配置は未対応 |
| チェックサムファイル | `_find_checksum_url`               | `checksums.txt` または `{tool}_{version}_checksums.txt` のみ。`{tool}.sha` 等は将来拡張扱い    |

<!--
Task ID Format: T-<scope>-<kind>-<nn>
  scope: 3-char abbreviation of target function/script
  kind:  nor=normal / err=error / edg=edge
  nn:    2-digit sequence within scope+kind
-->
