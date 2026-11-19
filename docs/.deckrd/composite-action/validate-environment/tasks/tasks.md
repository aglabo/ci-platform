---
title: "Implementation Tasks"
module: "composite-action/validate-environment"
status: Active
created: "2026-11-19T00:00:00+09:00"
source: specifications-index.md v1.0.0, implementation.md v1.0.0
---

<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/max-comma,
  ja-technical-writing/no-doubled-joshi,
  ja-technical-writing/no-mix-dearu-desumasu,
  ja-technical-writing/ja-no-redundant-expression,
  @textlint-ja/no-synonyms
  -->

## Conventions

本書は、現行のスペックファイルを仕様に対応付けたカバレッジ表である。
実装は完了済みで、スペックファイルは変更しない。

- 「Cases」は、各スペックファイルの `It` 行の数である (grep による集計。2026-11-19 時点)。
- 既存のスペックはテスト ID を付与していない。ID の書式は `T-VEN-<target>[-<連番>]` とし、`target` は `module.md` の略語を使う。
- 付与前のため、本書のタスク ID (`T-NN`) とテスト ID (`T-VEN-...`) は別物である。

## Task Summary

| Test Target                 | Scenarios | Cases | Status |
| --------------------------- | --------- | ----- | ------ |
| T-01: validate-git-runner   | 6 files   | 103   | done   |
| T-02: validate-permissions  | 5 files   | 71    | done   |
| T-03: validate-apps         | 15 files  | 250   | done   |
| T-04: action.yml (静的検査) | 0 files   | 0     | gap    |

## T-01: validate-git-runner

対象: `scripts/validate-git-runner.sh`。スペックは `scripts/__tests__/validate-git-runner/` にある。

### [正常] Normal Cases

#### T-01-01: アーキテクチャと OS の検出・正規化

- [x] **T-01-01-01**: 検出と正規化 (`DOS`, `DAR`, `NAR`, `VOS`)
  - Target: `unit/validate-git-runner.architecture.unit.spec.sh` (14)
  - Expected: REQ-F-004, REQ-F-006 の入力変換が正しい
- [x] **T-01-01-02**: 期待値の検証と一致判定 (`VEA`, `ISA`, `VAM`)
  - Target: `functional/validate-git-runner.architecture.functional.spec.sh` (33)
  - Expected: REQ-F-005, REQ-F-006 の受理と拒否が正しい

#### T-01-02: 環境変数の検証

- [x] **T-01-02-01**: `check_env_var` の判定 (`CEV`)
  - Target: `unit/validate-git-runner.environment.unit.spec.sh` (9)
  - Expected: 空・未設定・値の一致を判定できる
- [x] **T-01-02-02**: GitHub Actions 環境・hosted・実行時変数 (`VGA`, `VGH`, `VRV`)
  - Target: `integration/validate-git-runner.integration.spec.sh` (19)
  - Expected: REQ-F-007, REQ-F-008, REQ-F-009 が満たされる

#### T-01-03: 統合

- [x] **T-01-03-01**: オーケストレーターの分岐 (`VGR`)
  - Target: `functional/validate-git-runner.orchestrator.functional.spec.sh` (18)
  - Expected: R-RUN-001 ～ 008 の順序どおりに失敗・成功する
- [x] **T-01-03-02**: E2E
  - Target: `e2e/validate-git-runner.e2e.spec.sh` (10)
  - Expected: 成功・失敗の双方で `status` / `message` が書かれる

### [異常] Error Cases / [エッジケース] Edge Cases

上記の各ファイルが `[Error]` / `[Edge]` のケースを含む。個別のケースへの ID 付与は未了である。

## T-02: validate-permissions

対象: `scripts/validate-permissions.sh`。スペックは `scripts/__tests__/validate-permissions/` にある。

### [正常] Normal Cases

#### T-02-01: 各関数の単体

- [x] **T-02-01-01**: 単体 (`CCU`, `DBB`, `GAP`, `PGW`, `CGT`, `VPM`)
  - Target: `unit/validate-permissions.unit.spec.sh` (36)
  - Expected: REQ-F-010 ～ 014 の規則が満たされる

#### T-02-02: 機能

- [x] **T-02-02-01**: `validate_permissions` の機能 (`VPM`)
  - Target: `functional/validate-permissions.functional.spec.sh` (19)
  - Expected: R-PRM-002 ～ 007 の出力が正しい
- [x] **T-02-02-02**: トークンとスコープ (`CGT`)
  - Target: `functional/validate-token-scopes.functional.spec.sh` (9)
  - Expected: REQ-F-011 が満たされる

#### T-02-03: 統合と E2E

- [x] **T-02-03-01**: 統合
  - Target: `integration/validate-permissions.integration.spec.sh` (3)
- [x] **T-02-03-02**: E2E
  - Target: `e2e/validate-permissions.e2e.spec.sh` (4)

### [エッジケース] Gap

- [ ] **T-02-GAP-01**: `github_api_post` の `curl -w` 書式の検証 (OQ-01)
  - Target: 既存スペックは API 呼び出しを差し替えており、書式を検証していない
  - Expected: HTTP ステータスが取得できること (対応は別タスク)

## T-03: validate-apps

対象: `scripts/validate-apps.sh`。スペックは `scripts/__tests__/validate-apps/` にある。

### [正常] Normal Cases

#### T-03-01: 抽出と比較 (unit)

- [x] **T-03-01-01**: `is_safe_regex` (`ISR`): `unit/is-safe-regex.unit.spec.sh` (23)
- [x] **T-03-01-02**: `extract_version_number` (`EVN`, `EVR`): `unit/extract-version.unit.spec.sh` (25)
- [x] **T-03-01-03**: `check_version` (`CKV`): `unit/check-version.unit.spec.sh` (19)
- [x] **T-03-01-04**: `check_jq` (`CJQ`): `unit/check-jq.unit.spec.sh` (4)

#### T-03-02: 定義の検証 (unit)

- [x] **T-03-02-01**: `validate_app_format` (`VAF`, `ISC`): `unit/validate-app-format.unit.spec.sh` (36)
- [x] **T-03-02-02**: `validate_app_version` (`VAV`): `unit/validate-app-version.unit.spec.sh` (20)
- [x] **T-03-02-03**: `validate_app_special` (`VAS`, `CGA`): `unit/validate-app-special.unit.spec.sh` (19)

#### T-03-03: 機能 (functional)

- [x] **T-03-03-01**: `get_app_version` (`GAV`): `functional/get-app-version.functional.spec.sh` (6)
- [x] **T-03-03-02**: `handle_validation_error` (`HVE`): `functional/handle-validation-error.functional.spec.sh` (4)
- [x] **T-03-03-03**: `initialize_apps_list` (`IAL`): `functional/initialize-apps-list.functional.spec.sh` (34)
- [x] **T-03-03-04**: `validate_app_exists` (`VAE`): `functional/validate-app-exists.functional.spec.sh` (12)
- [x] **T-03-03-05**: `validate_app_version` (`VAV`): `functional/validate-app-version.functional.spec.sh` (7)

#### T-03-04: 統合と E2E

- [x] **T-03-04-01**: `validate_apps` の統合 (`VAP`): `integration/validate-apps.integration.spec.sh` (26)
- [x] **T-03-04-02**: オーケストレーター (`VAP`): `integration/validate-apps-orchestrator.integration.spec.sh` (10)
- [x] **T-03-04-03**: `main` の E2E (`MAIN`): `e2e/validate-apps.e2e.spec.sh` (5)

## T-04: action.yml (静的検査)

対象: `action.yml`。このモジュールには `action.yml` の静的検査スペックが無い (OQ-07)。

- [ ] **T-04-01-01**: 入力 5 つの既定値が REQ-F-001 と一致する (`ACT`)
- [ ] **T-04-01-02**: 出力 6 つが対応するステップ出力を参照する (`ACT`)
- [ ] **T-04-01-03**: `run:` に `${{ }}` を展開していない (`ACT`、REQ-NF-001)
- [ ] **T-04-01-04**: ステップが `validate-runner` → `validate-permissions` → `validate-apps` の順である (`ACT`)

## Traceability

| REQ ID               | Tasks                                          | Status             |
| -------------------- | ---------------------------------------------- | ------------------ |
| REQ-F-001 ～ 003     | T-04-01-01 ～ T-04-01-04                       | [UNCOVERED]        |
| REQ-F-004 ～ 009     | T-01-01-01, T-01-01-02, T-01-02-02, T-01-03-01 | covered            |
| REQ-F-010 ～ 014     | T-02-01-01, T-02-02-01, T-02-02-02             | covered            |
| REQ-F-012, REQ-F-013 | T-02-GAP-01                                    | [UNCOVERED] (書式) |
| REQ-F-015 ～ 022     | T-03-01-01 ～ T-03-04-03                       | covered            |
| REQ-NF-001           | T-03-01-01, T-04-01-03                         | partial            |

## Category Balance

既存のスペックは分類 (`[Normal]` / `[Error]` / `[Edge]`) を、ケース名の接頭辞で区別している。
分類別の件数は、ID の付与時に集計し直す。

| Test Target  | Normal | Error | Edge | Status |
| ------------ | ------ | ----- | ---- | ------ |
| T-01 ～ T-03 | -      | -     | -    | 未集計 |
