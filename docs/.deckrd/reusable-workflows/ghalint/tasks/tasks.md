---
title: "Implementation Tasks: Ghalint Reusable Workflow"
module: reusable-workflows/ghalint
status: Active
created: "2026-06-13 00:00:00"
source: specifications.md
---

<!-- markdownlint-disable line-length -->

## Task Summary

| Test Target                  | Scenarios | Cases | Status      |
| ---------------------------- | --------- | ----- | ----------- |
| T-01: ci-qa-ghalint.yml      | 4         | 12    | completed   |
| T-02: trigger-inputs         | 2         | 4     | completed   |
| T-03: step-gating            | 3         | 8     | completed   |
| T-04: lint-execute           | 2         | 4     | completed   |
| T-05: ci-workflows-qa update | 2         | 3     | completed   |

---

## T-01: ci-qa-ghalint.yml

### [正常] Normal Cases

#### T-01-01: workflow_call トリガーとジョブ基本設定

- [x] **T-01-01-01**: workflow_call トリガーのみが定義されている
  - Target: `ci-qa-ghalint.yml`
  - Scenario: Given ci-qa-ghalint.yml が作成された, When on トリガーを確認する
  - Expected: Then `on.workflow_call` のみが存在し `workflow_dispatch` は存在しない

- [x] **T-01-01-02**: ジョブが ubuntu-slim で timeout-minutes: 10 で定義されている
  - Target: `ci-qa-ghalint.yml jobs.qa-ghalint`
  - Scenario: Given ジョブ定義を確認する, When runs-on と timeout-minutes を検査する
  - Expected: Then `runs-on: ubuntu-slim` かつ `timeout-minutes: 10` が設定されている

- [x] **T-01-01-03**: permissions: contents: read が workflow レベルと job レベルの両方に設定されている
  - Target: `ci-qa-ghalint.yml`
  - Scenario: Given permissions 設定を確認する, When workflow レベルと job レベルを検査する
  - Expected: Then 両レベルで `contents: read` のみが設定されている

#### T-01-02: inputs 定義

- [x] **T-01-02-01**: ghalint-version input がデフォルト値付きで定義されている
  - Target: `ci-qa-ghalint.yml on.workflow_call.inputs`
  - Scenario: Given inputs 定義を確認する, When ghalint-version を検査する
  - Expected: Then type: string, required: false, デフォルト値が設定されている

- [x] **T-01-02-02**: config-file input がデフォルト値 `./shared/configs/ghalint.yaml` 付きで定義されている
  - Target: `ci-qa-ghalint.yml on.workflow_call.inputs`
  - Scenario: Given inputs 定義を確認する, When config-file を検査する
  - Expected: Then type: string, required: false, default: `./shared/configs/ghalint.yaml` が設定されている

#### T-01-03: ステップ定義と SHA ピン

- [x] **T-01-03-01**: 全 7 ステップが正しい ID で順序どおりに定義されている
  - Target: `ci-qa-ghalint.yml jobs.qa-ghalint.steps`
  - Scenario: Given ステップ一覧を確認する, When ステップ ID と順序を検査する
  - Expected: Then target-checkout → env-validation → tool-install → config-checkout → prepare-report → lint-execute → report-upload の順で定義されている

- [x] **T-01-03-02**: actions/checkout が SHA ピンされている
  - Target: `ci-qa-ghalint.yml steps.target-checkout, steps.config-checkout`
  - Scenario: Given checkout ステップを確認する, When uses の値を検査する
  - Expected: Then `actions/checkout@9f698171ed81b15d1823a05fc7211befd50c8ae0` が使用されている

- [x] **T-01-03-03**: actions/upload-artifact が SHA ピンされている
  - Target: `ci-qa-ghalint.yml steps.report-upload`
  - Scenario: Given report-upload ステップを確認する, When uses の値を検査する
  - Expected: Then `actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` が使用されている

#### T-01-04: config-checkout と lint-execute の設定

- [x] **T-01-04-01**: config-checkout が aglabo/.github を ./shared/ に fetch-depth: 1 でチェックアウトする
  - Target: `ci-qa-ghalint.yml steps.config-checkout`
  - Scenario: Given config-checkout ステップを確認する, When with パラメータを検査する
  - Expected: Then `repository: aglabo/.github`, `path: shared`, `fetch-depth: 1`, `persist-credentials: false` が設定されている

- [x] **T-01-04-02**: lint-execute が ghalint run --config で実行され終了コードを伝播する
  - Target: `ci-qa-ghalint.yml steps.lint-execute`
  - Scenario: Given lint-execute ステップを確認する, When run コマンドを検査する
  - Expected: Then `ghalint run --config "${{ inputs.config-file }}"` かつ `exit "${PIPESTATUS[0]}"` が含まれている

---

## T-02: trigger-inputs

### [正常] Normal Cases

#### T-02-01: デフォルト値の解決

- [x] **T-02-01-01**: ghalint-version を省略した場合にデフォルトバージョンが使用される
  - Target: `ci-qa-ghalint.yml inputs.ghalint-version`
  - Scenario: Given ghalint-version を指定せず呼び出す, When tool-install が実行される
  - Expected: Then デフォルトバージョンで ghalint がインストールされる (R-002a)

- [x] **T-02-01-02**: config-file を省略した場合に `./shared/configs/ghalint.yaml` が使用される
  - Target: `ci-qa-ghalint.yml inputs.config-file`
  - Scenario: Given config-file を指定せず呼び出す, When lint-execute が実行される
  - Expected: Then `./shared/configs/ghalint.yaml` が config-file として使用される (R-003a)

#### T-02-02: 明示的なパラメータ指定

- [x] **T-02-02-01**: 明示的に指定した ghalint-version が tool-install で使用される
  - Target: `ci-qa-ghalint.yml inputs.ghalint-version`
  - Scenario: Given ghalint-version を明示的に指定して呼び出す, When tool-install が実行される
  - Expected: Then 指定したバージョンで ghalint がインストールされる (R-002)

- [x] **T-02-02-02**: 明示的に指定した config-file が lint-execute で使用される
  - Target: `ci-qa-ghalint.yml inputs.config-file`
  - Scenario: Given config-file を明示的に指定して呼び出す, When lint-execute が実行される
  - Expected: Then 指定したパスが `--config` 引数として使用される (R-003)

---

## T-03: step-gating

### [正常] Normal Cases

#### T-03-01: 成功時のステップ連鎖

- [x] **T-03-01-01**: target-checkout 成功時に env-validation が実行される
  - Target: `ci-qa-ghalint.yml steps.env-validation.if`
  - Scenario: Given target-checkout が成功する, When env-validation の if 条件を確認する
  - Expected: Then `steps.target-checkout.outcome == 'success'` 条件が設定されている (R-004)

- [x] **T-03-01-02**: env-validation に actions-type: read が設定されている
  - Target: `ci-qa-ghalint.yml steps.env-validation`
  - Scenario: Given env-validation ステップを確認する, When with パラメータを検査する
  - Expected: Then `actions-type: read` が設定されている

- [x] **T-03-01-03**: tool-install に suzuki-shunsuke/ghalint が設定されている
  - Target: `ci-qa-ghalint.yml steps.tool-install`
  - Scenario: Given tool-install ステップを確認する, When with パラメータを検査する
  - Expected: Then `repo: suzuki-shunsuke/ghalint` かつ `tool-version: ${{ inputs.ghalint-version }}` が設定されている (R-006)

### [異常] Error Cases

#### T-03-02: 失敗時のステップブロック

- [x] **T-03-02-01**: target-checkout 失敗時に後続全ステップがブロックされる
  - Target: `ci-qa-ghalint.yml steps.*.if`
  - Scenario: Given target-checkout が失敗する, When 後続ステップの if 条件を確認する
  - Expected: Then env-validation 以降の全ステップが `steps.target-checkout.outcome == 'success'` チェーンによりブロックされる (R-004a)

- [x] **T-03-02-02**: report-upload は failure() かつ lint-execute 失敗時のみ実行される
  - Target: `ci-qa-ghalint.yml steps.report-upload.if`
  - Scenario: Given lint-execute が失敗する, When report-upload の if 条件を確認する
  - Expected: Then `failure() && steps.lint-execute.outcome == 'failure'` が設定されている (R-009a)

### [エッジケース] Edge Cases

#### T-03-03: persist-credentials と認証情報保護

- [x] **T-03-03-01**: target-checkout で persist-credentials: false が設定されている
  - Target: `ci-qa-ghalint.yml steps.target-checkout`
  - Scenario: Given target-checkout の with パラメータを確認する
  - Expected: Then `persist-credentials: false` が設定されている (REQ-NF-001)

- [x] **T-03-03-02**: config-checkout で persist-credentials: false が設定されている
  - Target: `ci-qa-ghalint.yml steps.config-checkout`
  - Scenario: Given config-checkout の with パラメータを確認する
  - Expected: Then `persist-credentials: false` が設定されている (REQ-NF-001)

---

## T-04: lint-execute

### [正常] Normal Cases

#### T-04-01: ポリシー違反なし

- [x] **T-04-01-01**: report-upload は lint 成功時に実行されない
  - Target: `ci-qa-ghalint.yml steps.report-upload.if`
  - Scenario: Given lint-execute が exit code 0 で終了する, When report-upload の条件を確認する
  - Expected: Then `failure()` が false のためアーティファクトはアップロードされない (R-009)

- [x] **T-04-01-02**: レポートファイルが正しいパスに出力される
  - Target: `ci-qa-ghalint.yml steps.lint-execute`
  - Scenario: Given lint-execute が実行される, When run コマンドのリダイレクトを確認する
  - Expected: Then `.github/report/ghalint-report.txt` に tee で出力される

### [異常] Error Cases

#### T-04-02: ポリシー違反あり

- [x] **T-04-02-01**: ポリシー違反時に report-upload が実行される
  - Target: `ci-qa-ghalint.yml steps.report-upload`
  - Scenario: Given lint-execute が非ゼロ終了する, When report-upload の条件を評価する
  - Expected: Then `failure() && steps.lint-execute.outcome == 'failure'` が true となりアーティファクトがアップロードされる (R-009a)

- [x] **T-04-02-02**: アーティファクトに正しい名前と保持期間が設定されている
  - Target: `ci-qa-ghalint.yml steps.report-upload`
  - Scenario: Given report-upload が実行される, When with パラメータを確認する
  - Expected: Then `name: ghalint-report`, `path: .github/report/ghalint-report.txt`, `retention-days: 30` が設定されている (REQ-F-008)

---

## T-05: ci-workflows-qa update

### [正常] Normal Cases

#### T-05-01: 外部依存の置き換え

- [x] **T-05-01-01**: ci-workflows-qa.yml の ghalint ジョブがローカル workflow を参照している
  - Target: `ci-workflows-qa.yml jobs.ghalint.uses`
  - Scenario: Given ci-workflows-qa.yml を確認する, When ghalint ジョブの uses を検査する
  - Expected: Then `./.github/workflows/ci-qa-ghalint.yml` が使用されており外部参照は存在しない (REQ-F-009)

- [x] **T-05-01-02**: 外部 aglabo/.github 参照が ci-workflows-qa.yml から削除されている
  - Target: `ci-workflows-qa.yml`
  - Scenario: Given ci-workflows-qa.yml の全内容を確認する
  - Expected: Then `aglabo/.github/.github/workflows/ci-common-lint-ghalint.yml` への参照が存在しない

### [エッジケース] Edge Cases

#### T-05-02: permissions 維持

- [x] **T-05-02-01**: ci-workflows-qa.yml の ghalint ジョブで permissions: contents: read が維持されている
  - Target: `ci-workflows-qa.yml jobs.ghalint.permissions`
  - Scenario: Given ghalint ジョブの permissions を確認する
  - Expected: Then `contents: read` が設定されており他の権限は追加されていない (REQ-NF-001)
