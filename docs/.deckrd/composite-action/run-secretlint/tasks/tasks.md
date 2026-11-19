---
title: "Implementation Tasks"
module: "composite-action/run-secretlint"
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

- Task ID (`T-XX-YY-ZZ`) は本書内の作業単位の ID とする。テストコードのケース名には、各タスクの `Test ID` (`T-RSL-<略語>-NN`) を埋め込む。
- テストコードの分類 prefix は、`[正常]` → `[Normal]`、`[異常]` → `[Error]` と読み替える。
- ACT のケース名には分類 prefix が無い。本書では、正の契約を [正常]、禁止事項の検査を [異常] に分けた。
- VER と RUN の一部は、`Parameters` で生成する。ケース ID はパラメータの第 1 列に持つ。
- 欠番 (RUN-02・06〜08、ACT-03) は再利用しない。
- 本書は実装済みのテストを記録する。テストファイルは変更しない。

---

## Task Summary

| Test Target                       | Scenarios | Cases | Status |
| --------------------------------- | --------- | ----- | ------ |
| T-01: validate_secretlint_version | 2         | 19    | done   |
| T-02: run-secretlint.sh (main)    | 2         | 5     | done   |
| T-03: action.yml                  | 2         | 13    | done   |

---

## T-01: validate_secretlint_version

対象: `validate_secretlint_version` (Test ID 略語: VER)。unit: `scripts/__tests__/unit/inputs.unit.spec.sh`。

### [正常] Normal Cases

#### T-01-01: Normal cases

- [x] **T-01-01-01**: 14.0.0 を受理する
  - Test ID: T-RSL-VER-01

- [x] **T-01-01-02**: 14.10.100 を受理する
  - Test ID: T-RSL-VER-08

- [x] **T-01-01-03**: 14.0.1 を受理する
  - Test ID: T-RSL-VER-10

- [x] **T-01-01-04**: 15.0.0 を受理する
  - Test ID: T-RSL-VER-11

- [x] **T-01-01-05**: 100.0.0 を受理する
  - Test ID: T-RSL-VER-12

### [異常] Error Cases

#### T-01-02: Error cases

- [x] **T-01-02-01**: 14.0 を拒否する
  - Test ID: T-RSL-VER-02

- [x] **T-01-02-02**: v14.0.0 を拒否する
  - Test ID: T-RSL-VER-03

- [x] **T-01-02-03**: 空を拒否する
  - Test ID: T-RSL-VER-04

- [x] **T-01-02-04**: latest を拒否する
  - Test ID: T-RSL-VER-05

- [x] **T-01-02-05**: 14.0.0; id を拒否する
  - Test ID: T-RSL-VER-06

- [x] **T-01-02-06**: 14.0.0-beta.1 を拒否する
  - Test ID: T-RSL-VER-07

- [x] **T-01-02-07**: 複数行 (14.0.0 と 15.0.0) を拒否する
  - Test ID: T-RSL-VER-09

- [x] **T-01-02-08**: 13.9.9 を拒否する
  - Test ID: T-RSL-VER-13

- [x] **T-01-02-09**: 13.0.0 を拒否する
  - Test ID: T-RSL-VER-14

- [x] **T-01-02-10**: 0.0.0 を拒否する
  - Test ID: T-RSL-VER-15

- [x] **T-01-02-11**: 9.9.9 を拒否する
  - Test ID: T-RSL-VER-16

- [x] **T-01-02-12**: 014.0.0 を拒否する
  - Test ID: T-RSL-VER-17

- [x] **T-01-02-13**: 00.1.2 を拒否する
  - Test ID: T-RSL-VER-18

- [x] **T-01-02-14**: エラー文が X.Y.Z と最小の major (14 or later) を示す
  - Test ID: T-RSL-VER-19

## T-02: run-secretlint.sh (main)

対象: `run-secretlint.sh (main)` (Test ID 略語: RUN)。functional: `scripts/__tests__/functional/run-secretlint.functional.spec.sh`。`pnpm` をスタブに差し替える。

### [正常] Normal Cases

#### T-02-01: Normal cases

- [x] **T-02-01-01**: pnpm dlx secretlint@version だけを引数なしで実行する
  - Test ID: T-RSL-RUN-01

- [x] **T-02-01-02**: 設定ファイルのオプションを secretlint に渡さない (テストの prefix は [Function])
  - Test ID: T-RSL-RUN-09

### [異常] Error Cases

#### T-02-02: Error cases

- [x] **T-02-02-01**: 終了コード 1 (検出あり) をそのまま伝搬する
  - Test ID: T-RSL-RUN-03

- [x] **T-02-02-02**: 終了コード 2 (ツールエラー) をそのまま伝搬する
  - Test ID: T-RSL-RUN-04

- [x] **T-02-02-03**: 不正な値では ::error:: を出し、pnpm を呼ばない
  - Test ID: T-RSL-RUN-05

## T-03: action.yml

対象: `action.yml` (Test ID 略語: ACT)。unit: `scripts/__tests__/unit/action.unit.spec.sh`。

### [正常] Normal Cases

#### T-03-01: Normal cases

- [x] **T-03-01-01**: inputs は pnpm-version と secretlint-version だけである
  - Test ID: T-RSL-ACT-01

- [x] **T-03-01-02**: secretlint-version は任意で、既定が X.Y.Z である
  - Test ID: T-RSL-ACT-02

- [x] **T-03-01-03**: pnpm-version は任意で、既定が空である
  - Test ID: T-RSL-ACT-10

- [x] **T-03-01-04**: composite で bash の run ステップは 1 つ (pnpm ステップに run が無い)
  - Test ID: T-RSL-ACT-04

- [x] **T-03-01-05**: secretlint の前に pnpm をセットアップする
  - Test ID: T-RSL-ACT-11

- [x] **T-03-01-06**: pnpm-version を pnpm のセットアップへ渡す
  - Test ID: T-RSL-ACT-12

- [x] **T-03-01-07**: 入力を env 経由でスクリプトへ渡す
  - Test ID: T-RSL-ACT-05

### [異常] Error Cases

#### T-03-02: Error cases

- [x] **T-03-02-01**: uses: は pnpm/action-setup@v6.1.1 だけである
  - Test ID: T-RSL-ACT-06

- [x] **T-03-02-02**: リポジトリをチェックアウトしない
  - Test ID: T-RSL-ACT-13

- [x] **T-03-02-03**: Node.js をセットアップしない
  - Test ID: T-RSL-ACT-14

- [x] **T-03-02-04**: contents / id-token の write 権限が無い
  - Test ID: T-RSL-ACT-07

- [x] **T-03-02-05**: secretlintrc や config の入力が無い
  - Test ID: T-RSL-ACT-08

- [x] **T-03-02-06**: run の中に式展開が無い
  - Test ID: T-RSL-ACT-09

---

## Category Balance

| Test Target                       | Normal | Error | Edge | Status |
| --------------------------------- | ------ | ----- | ---- | ------ |
| T-01: validate_secretlint_version | 5      | 14    | 0    | OK     |
| T-02: run-secretlint.sh (main)    | 2      | 3     | 0    | OK     |
| T-03: action.yml                  | 7      | 6     | 0    | OK     |
