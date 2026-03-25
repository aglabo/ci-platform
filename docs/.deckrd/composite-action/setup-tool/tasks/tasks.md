---
title: "Implementation Tasks"
module: composite-action/setup-tool
status: Active
created: "2026-03-25 00:00:00"
source: validate.spec.md, validate.impl.md
---

<!-- textlint-disable ja-technical-writing/sentence-length, ja-technical-writing/max-comma -->
<!-- markdownlint-disable line-length -->

## Task Summary

| Test Target                         | Scenarios | Cases | Status      |
| ----------------------------------- | --------- | ----- | ----------- |
| T-01: validate_symbol               | 3         | 8     | not started |
| T-02: validate_asset_template       | 2         | 5     | not started |
| T-03: validate_checksum_template    | 3         | 7     | not started |
| T-04: validate-inputs R-000/R-000U  | 3         | 9     | not started |
| T-05: validate-inputs R-001/R-001-N | 3         | 10    | not started |
| T-06: validate-inputs R-002/R-002C  | 2         | 7     | not started |
| T-07: validate-inputs R-003         | 2         | 5     | not started |
| T-08: validate-inputs R-004         | 3         | 8     | not started |
| T-09: validate-inputs R-005         | 1         | 2     | not started |

---

## T-01: validate_symbol

`validation.lib.sh` の `validate_symbol()` 関数の単体検証。
パターン適合時に return 0、不適合時に `::error::` を stderr に出力して return 1 することを確認する。

### [正常] Normal Cases

#### T-01-01: ホワイトリストパターンに適合する値

- [ ] **T-01-01-01**: 小文字英字のみの値を受け付ける
  - Target: `validate_symbol()`
  - Scenario: Given `value="actionlint"`, field_name="tool-name", pattern=`^[a-z][a-z0-9_-]{0,63}$`, When validate_symbol を呼ぶ
  - Expected: Then return 0

- [ ] **T-01-01-02**: 数字・ハイフン・アンダースコアを含む値を受け付ける
  - Target: `validate_symbol()`
  - Scenario: Given `value="my-tool_v2"`, pattern=`^[a-z][a-z0-9_-]{0,63}$`, When validate_symbol を呼ぶ
  - Expected: Then return 0

### [異常] Error Cases

#### T-01-02: ホワイトリストパターンに不適合な値

- [ ] **T-01-02-01**: 空文字を拒否して stderr にエラーを出力する
  - Target: `validate_symbol()`
  - Scenario: Given `value=""`, field_name="tool-name", pattern=`^[a-z][a-z0-9_-]{0,63}$`, When validate_symbol を呼ぶ
  - Expected: Then return 1 かつ stderr に `::error::tool-name:` を含む

- [ ] **T-01-02-02**: 大文字を含む値を拒否する
  - Target: `validate_symbol()`
  - Scenario: Given `value="MyTool"`, pattern=`^[a-z][a-z0-9_-]{0,63}$`, When validate_symbol を呼ぶ
  - Expected: Then return 1 かつ stderr に `::error::` を含む

- [ ] **T-01-02-03**: パターン長超過を拒否する
  - Target: `validate_symbol()`
  - Scenario: Given `value` = 65 文字の小文字英字, pattern=`^[a-z][a-z0-9_-]{0,63}$`, When validate_symbol を呼ぶ
  - Expected: Then return 1

### [エッジケース] Edge Cases

#### T-01-03: 境界値

- [ ] **T-01-03-01**: 最大長ちょうど (64 文字) を受け付ける
  - Target: `validate_symbol()`
  - Scenario: Given `value` = `a` + `a`×63 文字 (計 64 文字), pattern=`^[a-z][a-z0-9_-]{0,63}$`, When validate_symbol を呼ぶ
  - Expected: Then return 0

- [ ] **T-01-03-02**: 1 文字 (最小長) を受け付ける
  - Target: `validate_symbol()`
  - Scenario: Given `value="a"`, pattern=`^[a-z][a-z0-9_-]{0,63}$`, When validate_symbol を呼ぶ
  - Expected: Then return 0

- [ ] **T-01-03-03**: エラーメッセージに入力値とフィールド名が含まれる
  - Target: `validate_symbol()`
  - Scenario: Given `value="Bad!Value"`, field_name="repo", When validate_symbol を呼ぶ
  - Expected: Then stderr に `repo` と `Bad!Value` を含む

---

## T-02: validate_asset_template

`validation.lib.sh` の `validate_asset_template()` 関数の単体検証。

### [正常] Normal Cases

#### T-02-01: 有効な asset-template を受け付ける

- [ ] **T-02-01-01**: `{keyword}` プレースホルダを含む有効なテンプレートを受け付ける
  - Target: `validate_asset_template()`
  - Scenario: Given `value="{tool_name}_{tool_version}_linux_{arch}.tar.gz"`, When validate_asset_template を呼ぶ
  - Expected: Then return 0

- [ ] **T-02-01-02**: プレースホルダなしのリテラル文字列を受け付ける
  - Target: `validate_asset_template()`
  - Scenario: Given `value="tool-linux-amd64.tar.gz"`, When validate_asset_template を呼ぶ
  - Expected: Then return 0

### [異常] Error Cases

#### T-02-02: 無効な asset-template を拒否する

- [ ] **T-02-02-01**: 空文字を拒否する
  - Target: `validate_asset_template()`
  - Scenario: Given `value=""`, When validate_asset_template を呼ぶ
  - Expected: Then return 1

- [ ] **T-02-02-02**: `$()` インジェクション文字を拒否する
  - Target: `validate_asset_template()`
  - Scenario: Given `value="$(evil)"`, When validate_asset_template を呼ぶ
  - Expected: Then return 1

- [ ] **T-02-02-03**: 256 文字超を拒否する
  - Target: `validate_asset_template()`
  - Scenario: Given `value` = 257 文字のホワイトリスト文字列, When validate_asset_template を呼ぶ
  - Expected: Then return 1

---

## T-03: validate_checksum_template

`validation.lib.sh` の `validate_checksum_template()` 関数の単体検証。

### [正常] Normal Cases

#### T-03-01: 有効な checksum-template を受け付ける

- [ ] **T-03-01-01**: `<filename>` メタ変数を含むテンプレートを受け付ける
  - Target: `validate_checksum_template()`
  - Scenario: Given `value="<filename>.sha256"`, When validate_checksum_template を呼ぶ
  - Expected: Then return 0

- [ ] **T-03-01-02**: `<filename>` なしのリテラルを受け付ける
  - Target: `validate_checksum_template()`
  - Scenario: Given `value="checksums.txt"`, When validate_checksum_template を呼ぶ
  - Expected: Then return 0

- [ ] **T-03-01-03**: 空文字を受け付ける (省略扱い・スキップ)
  - Target: `validate_checksum_template()`
  - Scenario: Given `value=""`, When validate_checksum_template を呼ぶ
  - Expected: Then return 0

### [異常] Error Cases

#### T-03-02: 無効な checksum-template を拒否する

- [ ] **T-03-02-01**: `<filename>` が 2 回以上出現する場合を拒否する
  - Target: `validate_checksum_template()`
  - Scenario: Given `value="<filename><filename>.txt"`, When validate_checksum_template を呼ぶ
  - Expected: Then return 1

- [ ] **T-03-02-02**: ホワイトリスト外文字を拒否する
  - Target: `validate_checksum_template()`
  - Scenario: Given `value="checksums$(evil).txt"`, When validate_checksum_template を呼ぶ
  - Expected: Then return 1

### [エッジケース] Edge Cases

#### T-03-03: 境界値・特殊入力

- [ ] **T-03-03-01**: `<<filename>` (部分一致) を拒否する
  - Target: `validate_checksum_template()`
  - Scenario: Given `value="<<filename>.sha256"`, When validate_checksum_template を呼ぶ
  - Expected: Then return 1

- [ ] **T-03-03-02**: `<FILENAME>` (大文字) を拒否する (メタ変数は小文字のみ)
  - Target: `validate_checksum_template()`
  - Scenario: Given `value="<FILENAME>.sha256"`, When validate_checksum_template を呼ぶ
  - Expected: Then return 1

---

## T-04: validate-inputs — R-000/R-000U (前処理・ASCII チェック)

`validate-inputs.sh` の前処理ルール R-000 (trim) と R-000U (ASCII 制限) の統合検証。

### [正常] Normal Cases

#### T-04-01: 前後空白を除去して検証を通過する

- [ ] **T-04-01-01**: tool-name の前後空白を除去して受け付ける
  - Target: `validate-inputs.sh` (R-000)
  - Scenario: Given `INPUT_TOOL_NAME="  actionlint  "` (その他入力は有効), When validate-inputs.sh を実行
  - Expected: Then exit 0

- [ ] **T-04-01-02**: tool-version の前後空白を除去して受け付ける
  - Target: `validate-inputs.sh` (R-000)
  - Scenario: Given `INPUT_TOOL_VERSION="  1.7.10  "` (その他入力は有効), When validate-inputs.sh を実行
  - Expected: Then exit 0

### [異常] Error Cases

#### T-04-02: 空白のみの入力を trim 後に拒否する

- [ ] **T-04-02-01**: tool-name が空白のみの場合 trim 後に R-003 で拒否する
  - Target: `validate-inputs.sh` (R-000 → R-003)
  - Scenario: Given `INPUT_TOOL_NAME="   "`, When validate-inputs.sh を実行
  - Expected: Then exit 1 かつ stderr に `::error::tool-name:` を含む

- [ ] **T-04-02-02**: repo が空白のみの場合 trim 後に R-004 で拒否する
  - Target: `validate-inputs.sh` (R-000 → R-004)
  - Scenario: Given `INPUT_REPO="   "` (その他入力は有効), When validate-inputs.sh を実行
  - Expected: Then exit 1 かつ stderr に `::error::repo` を含む

#### T-04-03: ASCII 以外の Unicode を含む入力を拒否する (R-000U)

- [ ] **T-04-03-01**: tool-name に Unicode を含む場合を拒否する
  - Target: `validate-inputs.sh` (R-000U)
  - Scenario: Given `INPUT_TOOL_NAME="ツール"`, When validate-inputs.sh を実行
  - Expected: Then exit 1 かつ stderr に `::error::` を含む

- [ ] **T-04-03-02**: tool-version に Unicode を含む場合を拒否する
  - Target: `validate-inputs.sh` (R-000U)
  - Scenario: Given `INPUT_TOOL_VERSION="1.0.０"` (全角数字), When validate-inputs.sh を実行
  - Expected: Then exit 1

- [ ] **T-04-03-03**: repo に Unicode を含む場合を拒否する
  - Target: `validate-inputs.sh` (R-000U)
  - Scenario: Given `INPUT_REPO="org/リポ"`, When validate-inputs.sh を実行
  - Expected: Then exit 1

---

## T-05: validate-inputs — R-001/R-001-N (tool-version 検証)

### [正常] Normal Cases

#### T-05-01: 有効な tool-version を正規化して受け付ける

- [ ] **T-05-01-01**: `1.7.10` → 正規化後 `1.7.10` で GITHUB_OUTPUT に書き出す
  - Target: `validate-inputs.sh` (R-001, R-001-N)
  - Scenario: Given `INPUT_TOOL_VERSION="1.7.10"` (有効入力セット), When validate-inputs.sh を実行
  - Expected: Then exit 0 かつ GITHUB_OUTPUT に `tool-version=1.7.10` を含む

- [ ] **T-05-01-02**: `v1.7.10` → プレフィックス除去後 `1.7.10` で GITHUB_OUTPUT に書き出す
  - Target: `validate-inputs.sh` (R-001, R-001-N)
  - Scenario: Given `INPUT_TOOL_VERSION="v1.7.10"`, When validate-inputs.sh を実行
  - Expected: Then exit 0 かつ GITHUB_OUTPUT に `tool-version=1.7.10`

- [ ] **T-05-01-03**: `1.7` → `1.7.0` に補完して書き出す
  - Target: `validate-inputs.sh` (R-001, R-001-N)
  - Scenario: Given `INPUT_TOOL_VERSION="1.7"`, When validate-inputs.sh を実行
  - Expected: Then exit 0 かつ GITHUB_OUTPUT に `tool-version=1.7.0`

- [ ] **T-05-01-04**: `1` → `1.0.0` に補完して書き出す
  - Target: `validate-inputs.sh` (R-001, R-001-N)
  - Scenario: Given `INPUT_TOOL_VERSION="1"`, When validate-inputs.sh を実行
  - Expected: Then exit 0 かつ GITHUB_OUTPUT に `tool-version=1.0.0`

### [異常] Error Cases

#### T-05-02: 無効な tool-version を拒否する

- [ ] **T-05-02-01**: `latest` (非数値) を拒否する
  - Target: `validate-inputs.sh` (R-001)
  - Scenario: Given `INPUT_TOOL_VERSION="latest"`, When validate-inputs.sh を実行
  - Expected: Then exit 1 かつ stderr にエラー

- [ ] **T-05-02-02**: `1.2.3-beta` (英字修飾子) を拒否する
  - Target: `validate-inputs.sh` (R-001)
  - Scenario: Given `INPUT_TOOL_VERSION="1.2.3-beta"`, When validate-inputs.sh を実行
  - Expected: Then exit 1

- [ ] **T-05-02-03**: `1.2.3.4` (4 セグメント) を拒否する
  - Target: `validate-inputs.sh` (R-001)
  - Scenario: Given `INPUT_TOOL_VERSION="1.2.3.4"`, When validate-inputs.sh を実行
  - Expected: Then exit 1

- [ ] **T-05-02-04**: `1000.0.0` (major 4桁以上) を拒否する
  - Target: `validate-inputs.sh` (R-001)
  - Scenario: Given `INPUT_TOOL_VERSION="1000.0.0"`, When validate-inputs.sh を実行
  - Expected: Then exit 1

### [エッジケース] Edge Cases

#### T-05-03: 境界値

- [ ] **T-05-03-01**: 32 文字ちょうどの tool-version を受け付ける
  - Target: `validate-inputs.sh` (R-001)
  - Scenario: Given `INPUT_TOOL_VERSION` = 32 文字以内の有効バージョン文字列, When validate-inputs.sh を実行
  - Expected: Then exit 0

- [ ] **T-05-03-02**: GITHUB_OUTPUT 未設定時にエラー終了する
  - Target: `validate-inputs.sh` (R-001-N)
  - Scenario: Given 有効な全入力、かつ `GITHUB_OUTPUT` 未設定, When validate-inputs.sh を実行
  - Expected: Then exit 1 かつ stderr に `::error::GITHUB_OUTPUT is not set`

---

## T-06: validate-inputs — R-002/R-002C (asset-template / checksum-template)

### [正常] Normal Cases

#### T-06-01: 有効な asset-template と checksum-template を受け付ける

- [ ] **T-06-01-01**: 有効な asset-template を受け付ける
  - Target: `validate-inputs.sh` (R-002)
  - Scenario: Given `INPUT_ASSET_TEMPLATE="{tool_name}_{tool_version}_linux_amd64.tar.gz"` (有効入力セット), When validate-inputs.sh を実行
  - Expected: Then exit 0

- [ ] **T-06-01-02**: checksum-template 省略時 (空文字) に検証をスキップして通過する
  - Target: `validate-inputs.sh` (R-002C)
  - Scenario: Given `INPUT_CHECKSUM_TEMPLATE=""` (その他入力は有効), When validate-inputs.sh を実行
  - Expected: Then exit 0

### [異常] Error Cases

#### T-06-02: 無効な asset-template / checksum-template を拒否する

- [ ] **T-06-02-01**: asset-template が空文字の場合を拒否する
  - Target: `validate-inputs.sh` (R-002)
  - Scenario: Given `INPUT_ASSET_TEMPLATE=""`, When validate-inputs.sh を実行
  - Expected: Then exit 1 かつ stderr に `::error::asset-template:`

- [ ] **T-06-02-02**: asset-template に `$()` が含まれる場合を拒否する
  - Target: `validate-inputs.sh` (R-002)
  - Scenario: Given `INPUT_ASSET_TEMPLATE="$(evil).tar.gz"`, When validate-inputs.sh を実行
  - Expected: Then exit 1

- [ ] **T-06-02-03**: asset-template が 256 文字超の場合を拒否する
  - Target: `validate-inputs.sh` (R-002)
  - Scenario: Given `INPUT_ASSET_TEMPLATE` = 257 文字のホワイトリスト文字列, When validate-inputs.sh を実行
  - Expected: Then exit 1

- [ ] **T-06-02-04**: checksum-template に `<filename>` が 2 回含まれる場合を拒否する
  - Target: `validate-inputs.sh` (R-002C)
  - Scenario: Given `INPUT_CHECKSUM_TEMPLATE="<filename><filename>.txt"`, When validate-inputs.sh を実行
  - Expected: Then exit 1 かつ stderr に `::error::checksum-template:`

- [ ] **T-06-02-05**: checksum-template に Unicode が含まれる場合を R-000U で拒否する
  - Target: `validate-inputs.sh` (R-000U → R-002C)
  - Scenario: Given `INPUT_CHECKSUM_TEMPLATE="チェックサム.txt"`, When validate-inputs.sh を実行
  - Expected: Then exit 1

---

## T-07: validate-inputs — R-003 (tool-name 検証)

### [正常] Normal Cases

#### T-07-01: 有効な tool-name を受け付ける

- [ ] **T-07-01-01**: 小文字英字のみの tool-name を受け付ける
  - Target: `validate-inputs.sh` (R-003)
  - Scenario: Given `INPUT_TOOL_NAME="actionlint"` (有効入力セット), When validate-inputs.sh を実行
  - Expected: Then exit 0

- [ ] **T-07-01-02**: 64 文字ちょうどの tool-name を受け付ける
  - Target: `validate-inputs.sh` (R-003)
  - Scenario: Given `INPUT_TOOL_NAME` = `a` + `a`×63 文字 (計 64 文字), When validate-inputs.sh を実行
  - Expected: Then exit 0

### [異常] Error Cases

#### T-07-02: 無効な tool-name を拒否する

- [ ] **T-07-02-01**: 空文字 tool-name を拒否する
  - Target: `validate-inputs.sh` (R-003)
  - Scenario: Given `INPUT_TOOL_NAME=""`, When validate-inputs.sh を実行
  - Expected: Then exit 1 かつ stderr に `::error::tool-name:`

- [ ] **T-07-02-02**: 大文字を含む tool-name (`MyTool`) を拒否する
  - Target: `validate-inputs.sh` (R-003)
  - Scenario: Given `INPUT_TOOL_NAME="MyTool"`, When validate-inputs.sh を実行
  - Expected: Then exit 1

- [ ] **T-07-02-03**: 65 文字の tool-name (最大長超過) を拒否する
  - Target: `validate-inputs.sh` (R-003)
  - Scenario: Given `INPUT_TOOL_NAME` = `a`×65 文字, When validate-inputs.sh を実行
  - Expected: Then exit 1

---

## T-08: validate-inputs — R-004 (repo 検証)

### [正常] Normal Cases

#### T-08-01: 有効な repo を受け付ける

- [ ] **T-08-01-01**: `org/repo` 形式の repo を受け付ける
  - Target: `validate-inputs.sh` (R-004)
  - Scenario: Given `INPUT_REPO="rhysd/actionlint"` (有効入力セット), When validate-inputs.sh を実行
  - Expected: Then exit 0

### [異常] Error Cases

#### T-08-02: スラッシュ構造が不正な repo を拒否する

- [ ] **T-08-02-01**: スラッシュなし (`ActionLint`) を拒否する
  - Target: `validate-inputs.sh` (R-004)
  - Scenario: Given `INPUT_REPO="ActionLint"`, When validate-inputs.sh を実行
  - Expected: Then exit 1

- [ ] **T-08-02-02**: スラッシュ 2 個 (`org/repo/extra`) を拒否する
  - Target: `validate-inputs.sh` (R-004)
  - Scenario: Given `INPUT_REPO="org/repo/extra"`, When validate-inputs.sh を実行
  - Expected: Then exit 1

- [ ] **T-08-02-03**: 先頭スラッシュ (`/repo`) を拒否する
  - Target: `validate-inputs.sh` (R-004)
  - Scenario: Given `INPUT_REPO="/actionlint"`, When validate-inputs.sh を実行
  - Expected: Then exit 1

- [ ] **T-08-02-04**: 末尾スラッシュ (`org/`) を拒否する
  - Target: `validate-inputs.sh` (R-004)
  - Scenario: Given `INPUT_REPO="rhysd/"`, When validate-inputs.sh を実行
  - Expected: Then exit 1

- [ ] **T-08-02-05**: 二重スラッシュ (`org//repo`) を拒否する
  - Target: `validate-inputs.sh` (R-004)
  - Scenario: Given `INPUT_REPO="rhysd//actionlint"`, When validate-inputs.sh を実行
  - Expected: Then exit 1

### [エッジケース] Edge Cases

#### T-08-03: 文字数境界値

- [ ] **T-08-03-01**: org 部 39 文字ちょうどを受け付ける
  - Target: `validate-inputs.sh` (R-004)
  - Scenario: Given `INPUT_REPO` = `a`×39 文字 + `/actionlint`, When validate-inputs.sh を実行
  - Expected: Then exit 0

- [ ] **T-08-03-02**: org 部 40 文字超を拒否する
  - Target: `validate-inputs.sh` (R-004)
  - Scenario: Given `INPUT_REPO` = `a`×40 文字 + `/actionlint`, When validate-inputs.sh を実行
  - Expected: Then exit 1

---

## T-09: validate-inputs — R-005 (全通過)

### [正常] Normal Cases

#### T-09-01: 全有効入力で exit 0 かつ GITHUB_OUTPUT に書き出す

- [ ] **T-09-01-01**: 全入力が有効な場合 exit 0 で終了する
  - Target: `validate-inputs.sh` (R-005)
  - Scenario: Given 全入力が有効 (tool-name=actionlint, tool-version=1.7.10, asset-template=valid, repo=rhysd/actionlint), When validate-inputs.sh を実行
  - Expected: Then exit 0

- [ ] **T-09-01-02**: 正規化済み tool-version が GITHUB_OUTPUT に書き出される
  - Target: `validate-inputs.sh` (R-001-N, R-005)
  - Scenario: Given 全入力が有効かつ GITHUB_OUTPUT が設定済みファイル, When validate-inputs.sh を実行
  - Expected: Then GITHUB_OUTPUT ファイルに `tool-version=1.7.10` を含む

---

## Traceability

| Task ID | Rule           | Spec Section            | REQ                  |
| ------- | -------------- | ----------------------- | -------------------- |
| T-01    | —              | validate.spec.md §3, §4 | REQ-F-010, REQ-F-011 |
| T-02    | R-002          | validate.spec.md §4     | REQ-F-010(b)         |
| T-03    | R-002C         | validate.spec.md §4     | REQ-F-010(b)         |
| T-04    | R-000, R-000U  | validate.spec.md §4     | REQ-F-010            |
| T-05    | R-001, R-001-N | validate.spec.md §4     | REQ-F-010(a)         |
| T-06    | R-002, R-002C  | validate.spec.md §4     | REQ-F-010(b)         |
| T-07    | R-003          | validate.spec.md §4     | REQ-F-010(c)         |
| T-08    | R-004          | validate.spec.md §4     | REQ-F-011            |
| T-09    | R-005          | validate.spec.md §4     | REQ-F-010, REQ-F-011 |
