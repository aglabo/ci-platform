---
title: "Implementation Tasks"
module: "composite-action/resolve-config"
status: Active
created: "2026-11-19 00:00:00"
source: specifications.md v1.0.0, implementation.md v1.0.0
---

<!-- textlint-disable ja-technical-writing/sentence-length -->
<!-- textlint-disable ja-technical-writing/max-comma -->
<!-- markdownlint-disable no-duplicate-heading line-length -->

> This document contains implementation tasks derived from specifications.
> Each task corresponds to a single unit test case (`It` block).

## Conventions

- Task ID (`T-XX-YY-ZZ`) は本書内の作業単位の ID とする。テストコードのケース名には、各タスクの `Test ID` (`T-RC-...`) を埋め込む。
- テストコードの分類 prefix は、`[正常]` → `[Normal]`、`[異常]` → `[Error]`、`[エッジケース]` → `[Edge]` と読み替える。
- 既存のテストは、ユニットのグループ名に ID を宣言していない。ケース ID の第 2 セグメントが略語になる (module.md 参照)。
- functional のケースは、略語の代わりにシナリオ番号 (`01`〜`05`) を使う。
- 本書は実装済みのテストを記録する。テストファイルは変更しない。

---

## Task Summary

| Test Target                    | Scenarios | Cases | Status |
| ------------------------------ | --------- | ----- | ------ |
| T-01: resolve_config           | 3         | 28    | done   |
| T-02: resolve-config.sh (main) | 3         | 14    | done   |
| T-03: action.yml               | 2         | 5     | done   |

---

## T-01: resolve_config

対象: `resolve_config` (Test ID 略語: RC)。unit: `scripts/_libs/__tests__/unit/resolve-config.unit.spec.sh`。

### [正常] Normal Cases

#### T-01-01: Normal cases

- [x] **T-01-01-01**: config (相対) が存在すれば source=input
  - Test ID: T-RC-RC-0101

- [x] **T-01-01-02**: config (workspace 内の絶対パス) が存在すれば source=input
  - Test ID: T-RC-RC-0102

- [x] **T-01-01-03**: local のみ存在すれば source=local
  - Test ID: T-RC-RC-0103

- [x] **T-01-01-04**: global のみ存在すれば source=global
  - Test ID: T-RC-RC-0104

- [x] **T-01-01-05**: local と global が両方存在すれば local を優先する
  - Test ID: T-RC-RC-0105

- [x] **T-01-01-06**: workspace 内ファイルへの symlink は受理する
  - Test ID: T-RC-RC-0106

- [x] **T-01-01-07**: GITHUB_WORKSPACE 自体が symlink でも workspace 内の file は受理する
  - Test ID: T-RC-RC-0107

### [異常] Error Cases

#### T-01-02: Error cases

- [x] **T-01-02-01**: config が不在なら local が存在してもフォールバックしない
  - Test ID: T-RC-RC-0201

- [x] **T-01-02-02**: 3 つとも不在ならエラー
  - Test ID: T-RC-RC-0202

- [x] **T-01-02-03**: config が .. で workspace 外 (実在) ならエラー
  - Test ID: T-RC-RC-0203

- [x] **T-01-02-04**: config が workspace 外の絶対パス (実在) ならエラー
  - Test ID: T-RC-RC-0204

- [x] **T-01-02-05**: local_config が .. で workspace 外ならエラー
  - Test ID: T-RC-RC-0205

- [x] **T-01-02-06**: global_config が .. で workspace 外ならエラー
  - Test ID: T-RC-RC-0206

- [x] **T-01-02-07**: GITHUB_WORKSPACE 未設定ならエラー
  - Test ID: T-RC-RC-0207

- [x] **T-01-02-08**: config が workspace 外ファイルへの symlink ならエラー
  - Test ID: T-RC-RC-0208

- [x] **T-01-02-09**: local_config が workspace 外ファイルへの symlink ならエラー (フォールバックしない)
  - Test ID: T-RC-RC-0209

- [x] **T-01-02-10**: symlink ディレクトリ経由で workspace 外ファイルならエラー
  - Test ID: T-RC-RC-0210

- [x] **T-01-02-11**: 2 段 symlink (ws 内 -> ws 内 -> 外部) ならエラー
  - Test ID: T-RC-RC-0211

- [x] **T-01-02-12**: GITHUB_WORKSPACE が symlink でも外部を指す symlink ならエラー
  - Test ID: T-RC-RC-0212

- [x] **T-01-02-13**: 空白を含むパスは (実在しても) 拒否する
  - Test ID: T-RC-RC-0213

### [エッジケース] Edge Cases

#### T-01-03: Edge cases

- [x] **T-01-03-01**: config がディレクトリならエラー
  - Test ID: T-RC-RC-0301

- [x] **T-01-03-02**: 3 引数がすべて空ならエラー
  - Test ID: T-RC-RC-0302

- [x] **T-01-03-03**: workspace 内で完結する .. を含むパスも拒否する
  - Test ID: T-RC-RC-0303

- [x] **T-01-03-04**: コマンド置換文字列を評価しない
  - Test ID: T-RC-RC-0304

- [x] **T-01-03-05**: ロードガードにより 2 回目の source は何も再定義しない
  - Test ID: T-RC-RC-0305

- [x] **T-01-03-06**: 接頭辞が同じ兄弟ディレクトリ (ws-evil) への symlink はエラー
  - Test ID: T-RC-RC-0306

- [x] **T-01-03-07**: dangling symlink は file not found
  - Test ID: T-RC-RC-0307

- [x] **T-01-03-08**: workspace 内の symlink チェーンは受理する
  - Test ID: T-RC-RC-0308

## T-02: resolve-config.sh (main)

対象: `resolve-config.sh (main)` (Test ID 略語: 01〜05)。functional: `scripts/__tests__/functional/resolve-config.functional.spec.sh`。

### [正常] Normal Cases

#### T-02-01: Normal cases

- [x] **T-02-01-01**: INPUT_CONFIG が存在すると source=input
  - Test ID: T-RC-01-01

- [x] **T-02-01-02**: local のみ存在すると source=local
  - Test ID: T-RC-01-02

- [x] **T-02-01-03**: global のみ存在すると source=global
  - Test ID: T-RC-01-03

- [x] **T-02-01-04**: local と global が両方存在すると local が優先
  - Test ID: T-RC-01-04

- [x] **T-02-01-05**: ::notice:: 行に source と path が 1 行出る
  - Test ID: T-RC-01-05

- [x] **T-02-01-06**: GITHUB_OUTPUT のキーは config-file と source のみ
  - Test ID: T-RC-01-06

### [異常] Error Cases

#### T-02-02: Error cases

- [x] **T-02-02-01**: INPUT_CONFIG が存在しないとエラー
  - Test ID: T-RC-02-01

- [x] **T-02-02-02**: どの設定ファイルも存在しないとエラー
  - Test ID: T-RC-02-02

- [x] **T-02-02-03**: '..' を含むパスを拒否する
  - Test ID: T-RC-02-03

- [x] **T-02-02-04**: INPUT_CONFIG に空白があると拒否する
  - Test ID: T-RC-05-01

- [x] **T-02-02-05**: INPUT_LOCAL_CONFIG に空白があると拒否する
  - Test ID: T-RC-05-02

- [x] **T-02-02-06**: INPUT_GLOBAL_CONFIG に空白があると拒否する
  - Test ID: T-RC-05-03

### [エッジケース] Edge Cases

#### T-02-03: Edge cases

- [x] **T-02-03-01**: source しても main が走らない
  - Test ID: T-RC-03-01

- [x] **T-02-03-02**: local にフォールバックせずエラー
  - Test ID: T-RC-04-01

## T-03: action.yml

対象: `action.yml` (Test ID 略語: ACT)。unit: `scripts/__tests__/unit/action.unit.spec.sh`。

### [正常] Normal Cases

#### T-03-01: Normal cases

- [x] **T-03-01-01**: inputs は config / local-config / global-config の 3 つである
  - Test ID: T-RC-ACT-01

- [x] **T-03-01-02**: 3 つの input はいずれも required=false かつ default が空文字である
  - Test ID: T-RC-ACT-02

- [x] **T-03-01-03**: outputs は config-file / source をそれぞれ step 出力に写像する
  - Test ID: T-RC-ACT-03

### [異常] Error Cases

#### T-03-02: Error cases

- [x] **T-03-02-01**: run の中に式展開が無い
  - Test ID: T-RC-ACT-04

- [x] **T-03-02-02**: 入力と GITHUB_WORKSPACE は env 経由で渡し、run は GITHUB_ACTION_PATH から実行する
  - Test ID: T-RC-ACT-05

---

## Category Balance

| Test Target                    | Normal | Error | Edge | Status |
| ------------------------------ | ------ | ----- | ---- | ------ |
| T-01: resolve_config           | 7      | 13    | 8    | OK     |
| T-02: resolve-config.sh (main) | 6      | 6     | 2    | OK     |
| T-03: action.yml               | 3      | 2     | 0    | OK     |
