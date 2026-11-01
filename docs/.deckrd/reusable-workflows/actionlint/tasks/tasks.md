---
title: "Implementation Tasks"
module: reusable-workflows/actionlint
status: Active
created: "2026-06-12 00:00:00"
source: specifications.md
---

<!-- cspell:words jactionlint jdx -->
<!-- textlint-disable
  ja-technical-writing/sentence-length,
  -->
<!-- markdownlint-disable line-length -->

各 task は単一ユニットテストケース（`it()` ブロック）に対応する。

テスト手法: `jactionlint`（CI）と `yq` 属性検査（ローカル開発者検証専用、ワークフロー内では使用しない）

`yq:` 行はテスト作成者向けの実装ヒントであり、ワークフローステップではない。

---

## Task Summary

| Test Target                  | Scenario Groups            | Case Count | Status      |
| ---------------------------- | -------------------------- | ---------: | ----------- |
| T-01: Workflow structure     | Normal / Error / Edge case |         11 | in progress |
| T-02: Step chain             | Normal / Error / Edge case |         12 | in progress |
| T-03: Failure propagation    | Error / Edge case          |          7 | in progress |
| T-04: YAML static validation | Normal                     |          4 | in progress |
| T-05: Config file and report | Normal / Error / Edge case |         10 | in progress |
| **Total**                    | 17 scenario groups         |     **44** |             |

---

## T-01: Workflow Structure

### [正常] Normal Cases

#### T-01-01: Inputs and triggers are correctly defined

- [x] **T-01-01-01**: `version` が `required: false`、`type: string`、`default: "2.4.0"` で宣言されていること
  - Target: `ru-qa-actionlint.yml` `.on.workflow_call.inputs.version`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When inputs を検査する
  - Expected: `required: false`、`type: string`、`default: "2.4.0"` がすべて設定されている
  - `yq: yq '.on.workflow_call.inputs.version' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-01-01-02**: `config` が `required: false`、`type: string`、`default: "./shared/configs/jactionlint.yaml"` で宣言されていること
  - Target: `ru-qa-actionlint.yml` `.on.workflow_call.inputs.config`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When inputs を検査する
  - Expected: `required: false`、`type: string`、`default: "./shared/configs/jactionlint.yaml"` がすべて設定されている
  - `yq: yq '.on.workflow_call.inputs.config' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-01-01-03**: top-level permissions が `contents: read` のみであること
  - Target: `ru-qa-actionlint.yml` `.permissions`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When top-level permissions を検査する
  - Expected: `permissions.contents == 'read'` かつ他のキーが存在しない
  - `yq: yq '.permissions' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-01-01-04**: job-level permissions が `contents: read` のみであること
  - Target: `ru-qa-actionlint.yml` `.jobs.qa-actionlint.permissions`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When job-level permissions を検査する
  - Expected: `jobs.qa-actionlint.permissions.contents == 'read'` かつ他のキーが存在しない
  - `yq: yq '.jobs.qa-actionlint.permissions' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-01-01-05**: `timeout-minutes` が `10` に固定されていること
  - Target: `ru-qa-actionlint.yml` `.jobs.qa-actionlint.timeout-minutes`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When job timeout を検査する
  - Expected: `jobs.qa-actionlint.timeout-minutes == 10`
  - `yq: yq '.jobs.qa-actionlint.timeout-minutes' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-01-01-06**: `runs-on` が `ubuntu-slim` であること
  - Target: `ru-qa-actionlint.yml` `.jobs.qa-actionlint.runs-on`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When runner を検査する
  - Expected: `jobs.qa-actionlint.runs-on == 'ubuntu-slim'`
  - `yq: yq '.jobs.qa-actionlint.runs-on' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-01-01-07**: ワークフローに `name` フィールドが設定されていること
  - Target: `ru-qa-actionlint.yml` `.name`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When name フィールドを検査する
  - Expected: `.name` が非空文字列
  - `yq: yq '.name' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-01-01-08**: `version` と `config` に `description` フィールドが設定されていること
  - Target: `ru-qa-actionlint.yml` `.on.workflow_call.inputs`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When input descriptions を検査する
  - Expected: 両入力の `description` が非空文字列
  - `yq: yq '.on.workflow_call.inputs | to_entries[] | {(.key): .value.description}' .github/workflows/ru-qa-actionlint.yml`

### [異常] Error Cases

#### T-01-02: Workflow does not expose outputs or unsupported triggers

- [x] **T-01-02-01**: `on.workflow_call.outputs` が存在しないか空であること
  - Target: `ru-qa-actionlint.yml` `.on.workflow_call.outputs`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When outputs を検査する
  - Expected: `on.workflow_call.outputs` が null または空
  - `yq: yq '.on.workflow_call.outputs' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-01-02-02**: `workflow_dispatch` トリガーが存在しないこと
  - Target: `ru-qa-actionlint.yml` `.on`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When トリガーを検査する
  - Expected: `.on` に `workflow_dispatch` キーが存在しない
  - `yq: yq '.on | keys' .github/workflows/ru-qa-actionlint.yml`

### [エッジケース] Edge Cases

#### T-01-03: Input defaults are explicitly declared

- [x] **T-01-03-01**: `version` と `config` が `workflow_call` で非空デフォルトを持つこと
  - Target: `ru-qa-actionlint.yml` `.on.workflow_call.inputs`
  - Scenario: Given inputs が省略された状態で `workflow_call` が呼ばれる、When デフォルト値を検査する
  - Expected: 両入力のデフォルト値が非空文字列
  - `yq: yq '.on.workflow_call.inputs | to_entries[] | .value.default' .github/workflows/ru-qa-actionlint.yml`

---

## T-02: Step Chain

### [正常] Normal Cases

#### T-02-01: Each step exists with the correct ID, action reference, and gate condition

- [x] **T-02-01-01**: `target-checkout` が `actions/checkout` を使用し、`if` 条件なし、`persist-credentials: false` を設定すること
  - Target: `ru-qa-actionlint.yml` step `target-checkout`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When `target-checkout` ステップを検査する
  - Expected: `uses` に `actions/checkout` を含み、`if` キーなし、`with.persist-credentials: false`
  - `yq: yq '.jobs.qa-actionlint.steps[] | select(.id == "target-checkout")' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-02-01-01b**: `target-checkout` が step `id` として `target-checkout` を明示していること
  - Target: `ru-qa-actionlint.yml` step `target-checkout`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When 最初の step の `id` を検査する
  - Expected: `steps[0].id == 'target-checkout'`
  - `yq: yq '.jobs.qa-actionlint.steps[0].id' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-02-01-02**: `env-validation` が `./.github/actions/validate-environment` を使用し、`if: steps.target-checkout.outcome == 'success'` でゲートされること
  - Target: `ru-qa-actionlint.yml` step `env-validation`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When `env-validation` ステップを検査する
  - Expected: `uses: ./.github/actions/validate-environment`、`with.actions-type: read`、`if: steps.target-checkout.outcome == 'success'`
  - `yq: yq '.jobs.qa-actionlint.steps[] | select(.id == "env-validation")' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-02-01-03**: `tool-install` が `aglabo/ci-platform/.github/actions/ca-setup-tool@v0.4.1` を使用し、`repo: jdx/jactionlint`、`if: steps.env-validation.outcome == 'success'` でゲートされること
  - Target: `ru-qa-actionlint.yml` step `tool-install`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When `tool-install` ステップを検査する
  - Expected: `uses: aglabo/ci-platform/.github/actions/ca-setup-tool@v0.4.1`、`with.repo: jdx/jactionlint`、`if: steps.env-validation.outcome == 'success'`
  - `yq: yq '.jobs.qa-actionlint.steps[] | select(.id == "tool-install")' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-02-01-03b**: `tool-install` が `tool-version: ${{ inputs.version }}` を渡すこと
  - Target: `ru-qa-actionlint.yml` step `tool-install`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When `tool-install` の `tool-version` を検査する
  - Expected: `with.tool-version == '${{ inputs.version }}'`
  - `yq: yq '.jobs.qa-actionlint.steps[] | select(.id == "tool-install") | .with.tool-version' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-02-01-04**: `config-checkout` が `actions/checkout` を使用し、`repository: aglabo/.github`、`path: shared`、`fetch-depth: 1`、`persist-credentials: false`、`if: steps.tool-install.outcome == 'success'` を持つこと
  - Target: `ru-qa-actionlint.yml` step `config-checkout`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When `config-checkout` ステップを検査する
  - Expected: `with.repository: aglabo/.github`、`with.path: shared`、`with.fetch-depth: 1`、`with.persist-credentials: false`、`if: steps.tool-install.outcome == 'success'`
  - `yq: yq '.jobs.qa-actionlint.steps[] | select(.id == "config-checkout")' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-02-01-05**: `lint-execute` が `jactionlint --config-file` コマンドを実行し、`if: steps.prepare-report.outcome == 'success'` でゲートされること
  - Target: `ru-qa-actionlint.yml` step `lint-execute`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When `lint-execute` ステップを検査する
  - Expected: `run` に `jactionlint --config-file` と `tee .github/report/jactionlint-report.txt` を含み、`if: steps.prepare-report.outcome == 'success'`
  - `yq: yq '.jobs.qa-actionlint.steps[] | select(.id == "lint-execute")' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-02-01-06**: ステップ実行順が `target-checkout → env-validation → tool-install → config-checkout → prepare-report → lint-execute` であること
  - Target: `ru-qa-actionlint.yml` `.jobs.qa-actionlint.steps`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When ステップ順序を検査する
  - Expected: steps 配列内の ID が上記順序に従う
  - `yq: yq '.jobs.qa-actionlint.steps[].id' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-02-01-07**: `report-upload` が `actions/upload-artifact` を使用していること
  - Target: `ru-qa-actionlint.yml` step `report-upload`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When `report-upload` の `uses` を検査する
  - Expected: `uses` に `actions/upload-artifact` を含む
  - `yq: yq '.jobs.qa-actionlint.steps[] | select(.id == "report-upload") | .uses' .github/workflows/ru-qa-actionlint.yml`

### [異常] Error Cases

#### T-02-02: Lint step does not suppress failures

- [x] **T-02-02-01**: `lint-execute` に `continue-on-error: true` がないこと
  - Target: `ru-qa-actionlint.yml` step `lint-execute`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When `lint-execute` の `continue-on-error` を検査する
  - Expected: `continue-on-error` キーが存在しないか `false`
  - `yq: yq '.jobs.qa-actionlint.steps[] | select(.id == "lint-execute") | .continue-on-error' .github/workflows/ru-qa-actionlint.yml`

### [エッジケース] Edge Cases

#### T-02-03: If-conditions use only immediate-upstream outcome gates

- [x] **T-02-03-01**: 各下流ステップが直前ステップの `outcome` のみにゲートされ、`always()`、`failure()`、`||` を含まないこと（`report-upload` を除く）
  - Target: `ru-qa-actionlint.yml` steps `env-validation` ～ `lint-execute`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When 各ステップの `if` 条件を検査する
  - Expected: 各 `if` 式が `steps.<prev>.outcome == 'success'` パターンのみ
  - `yq: yq '.jobs.qa-actionlint.steps[] | select(.id != "target-checkout" and .id != "report-upload") | {(.id): .if}' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-02-03-02**: `tool-install`、`config-checkout`、`prepare-report`、`lint-execute` のいずれにも `continue-on-error: true` がないこと
  - Target: `ru-qa-actionlint.yml` steps
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When 各ステップの `continue-on-error` を検査する
  - Expected: 対象ステップ全てで `continue-on-error` が存在しないか `false`
  - `yq: yq '.jobs.qa-actionlint.steps[] | select(.id == "tool-install" or .id == "config-checkout" or .id == "prepare-report" or .id == "lint-execute") | .continue-on-error' .github/workflows/ru-qa-actionlint.yml`

---

## T-03: Failure Propagation

### [異常] Error Cases

#### T-03-01: Upstream failures block all downstream steps via chained gates

- [x] **T-03-01-01**: 全下流 `if` 式が完全な failure-propagation チェーンを形成すること
  - Target: `ru-qa-actionlint.yml` steps `env-validation` ～ `lint-execute`
  - Scenario: Given 上流ステップが失敗する、When 下流ステップの評価を検査する
  - Expected: 各ステップが直前の outcome gate を持ち、失敗時に以降のステップがすべてスキップされる
  - `yq: yq '.jobs.qa-actionlint.steps[] | {(.id): .if}' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-03-01-02**: `config-checkout` に `continue-on-error` がなく、アクセス不能な config-repo でジョブが失敗すること
  - Target: `ru-qa-actionlint.yml` step `config-checkout`
  - Scenario: Given `aglabo/.github` にアクセスできない、When `config-checkout` を実行する
  - Expected: `continue-on-error` が存在せず、ステップ失敗がジョブ全体の失敗につながる
  - `yq: yq '.jobs.qa-actionlint.steps[] | select(.id == "config-checkout") | .continue-on-error' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-03-01-03**: lint コマンドが config パスを使用し、設定ファイルが存在しない場合に即時失敗すること
  - Target: `ru-qa-actionlint.yml` step `lint-execute` の `run` コマンド
  - Scenario: Given `config` が存在しないパスを指す、When `lint-execute` を実行する
  - Expected: step `env.CONFIG_FILE` が `${{ inputs.config }}` で、`run` コマンドが `"${CONFIG_FILE}"` を使い、`exit ${PIPESTATUS[0]}` で失敗を伝播する
  - `yq: yq '.jobs.qa-actionlint.steps[] | select(.id == "lint-execute") | {"env": .env, "run": .run}' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-03-01-04**: `env-validation` に `continue-on-error` がないこと
  - Target: `ru-qa-actionlint.yml` step `env-validation`
  - Scenario: Given 環境検証が失敗する、When `env-validation` の抑制設定を検査する
  - Expected: `continue-on-error` が存在しないか `false`
  - `yq: yq '.jobs.qa-actionlint.steps[] | select(.id == "env-validation") | .continue-on-error' .github/workflows/ru-qa-actionlint.yml`

### [エッジケース] Edge Cases

#### T-03-02: Edge inputs and output suppression

- [x] **T-03-02-01**: `version` のデフォルトが `"2.4.0"` であること
  - Target: `ru-qa-actionlint.yml` `.on.workflow_call.inputs.version.default`
  - Scenario: Given inputs を省略して呼び出す、When デフォルト値を検査する
  - Expected: `default == "2.4.0"`
  - `yq: yq '.on.workflow_call.inputs.version.default' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-03-02-02**: `config` のデフォルトが `"./shared/configs/jactionlint.yaml"` であること
  - Target: `ru-qa-actionlint.yml` `.on.workflow_call.inputs.config.default`
  - Scenario: Given inputs を省略して呼び出す、When デフォルト値を検査する
  - Expected: `default == "./shared/configs/jactionlint.yaml"`
  - `yq: yq '.on.workflow_call.inputs.config.default' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-03-02-03**: workflow および job レベルで outputs が存在しないこと
  - Target: `ru-qa-actionlint.yml` `.on.workflow_call.outputs` および `.jobs.qa-actionlint.outputs`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When outputs を検査する
  - Expected: 両方とも null または未定義
  - `yq: yq '{wf_outputs: .on.workflow_call.outputs, job_outputs: .jobs.qa-actionlint.outputs}' .github/workflows/ru-qa-actionlint.yml`

---

## T-04: YAML Static Validation

### [正常] Normal Cases

#### T-04-01: jactionlint and structural invariants

- [x] **T-04-01-01**: `jactionlint` が `ru-qa-actionlint.yml` に対してエラーなしで終了すること
  - Target: `ru-qa-actionlint.yml` 全体
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When jactionlint で検証する
  - Expected: `jactionlint` の exit code が 0
  - `run: jactionlint --config-file ./configs/jactionlint.yaml .github/workflows/ru-qa-actionlint.yml`

- [x] **T-04-01-02**: workflow が正確に 1 つの job `qa-actionlint` を持ち、必須ステップ ID をすべて含むこと
  - Target: `ru-qa-actionlint.yml` `.jobs`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When job と step 構造を検査する
  - Expected: job が `qa-actionlint` のみ、step IDs に `target-checkout`、`env-validation`、`tool-install`、`config-checkout`、`prepare-report`、`lint-execute`、`report-upload` が全て含まれる
  - `yq: yq '.jobs | keys' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-04-01-03**: 全ステップ ID が一意であること
  - Target: `ru-qa-actionlint.yml` `.jobs.qa-actionlint.steps[].id`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When ステップ ID を検査する
  - Expected: 重複する ID が存在しない
  - `yq: yq '.jobs.qa-actionlint.steps[].id' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-04-01-04**: job が `ubuntu-slim` 上で動作すること
  - Target: `ru-qa-actionlint.yml` `.jobs.qa-actionlint.runs-on`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When runner を検査する
  - Expected: `runs-on == 'ubuntu-slim'`
  - `yq: yq '.jobs.qa-actionlint.runs-on' .github/workflows/ru-qa-actionlint.yml`

---

## T-05: Config File and Report

### [正常] Normal Cases

#### T-05-01: config-checkout is fixed and config is caller-overridable

- [x] **T-05-01-01**: `config-checkout` の `repository` が `aglabo/.github` に固定されていること（入力パラメータではない）
  - Target: `ru-qa-actionlint.yml` step `config-checkout`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When `config-checkout` の `repository` を検査する
  - Expected: `with.repository: aglabo/.github`（リテラル値、`${{ inputs.* }}` 参照でない）
  - `yq: yq '.jobs.qa-actionlint.steps[] | select(.id == "config-checkout") | .with.repository' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-05-01-02**: `config-checkout` の `fetch-depth` が `1` であること
  - Target: `ru-qa-actionlint.yml` step `config-checkout`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When `config-checkout` の `fetch-depth` を検査する
  - Expected: `with.fetch-depth: 1`
  - `yq: yq '.jobs.qa-actionlint.steps[] | select(.id == "config-checkout") | .with.fetch-depth' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-05-01-03**: `lint-execute` が `env.CONFIG_FILE` (`${{ inputs.config }}`) を使用して設定ファイルパスを参照すること
  - Target: `ru-qa-actionlint.yml` step `lint-execute`
  - Scenario: Given `config` 入力が指定された状態で呼び出す、When `lint-execute` の `run` を検査する
  - Expected: `env.CONFIG_FILE == '${{ inputs.config }}'` かつ `run` に `"${CONFIG_FILE}"` が含まれる
  - `yq: yq '.jobs.qa-actionlint.steps[] | select(.id == "lint-execute") | {"env": .env, "run": .run}' .github/workflows/ru-qa-actionlint.yml`

#### T-05-02: Report preparation and lint output

- [x] **T-05-02-01**: `prepare-report` が `mkdir -p .github/report` を実行し、`if: steps.config-checkout.outcome == 'success'` でゲートされること
  - Target: `ru-qa-actionlint.yml` step `prepare-report`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When `prepare-report` ステップを検査する
  - Expected: `run: mkdir -p .github/report`、`if: steps.config-checkout.outcome == 'success'`
  - `yq: yq '.jobs.qa-actionlint.steps[] | select(.id == "prepare-report")' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-05-02-02**: `lint-execute` の `run` が `tee .github/report/jactionlint-report.txt` を含むこと
  - Target: `ru-qa-actionlint.yml` step `lint-execute`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When `lint-execute` の出力先を検査する
  - Expected: `run` に `tee .github/report/jactionlint-report.txt` が含まれる
  - `yq: yq '.jobs.qa-actionlint.steps[] | select(.id == "lint-execute") | .run' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-05-02-03**: `lint-execute` の `run` が `exit ${PIPESTATUS[0]}` で終了コードを伝播すること
  - Target: `ru-qa-actionlint.yml` step `lint-execute`
  - Scenario: Given jactionlint がエラーを検出する、When `lint-execute` を実行する
  - Expected: `run` に `exit ${PIPESTATUS[0]}` が含まれ、非ゼロ終了コードが伝播される
  - `yq: yq '.jobs.qa-actionlint.steps[] | select(.id == "lint-execute") | .run' .github/workflows/ru-qa-actionlint.yml`

### [異常] Error Cases

#### T-05-03: Report upload on failure

- [x] **T-05-03-01**: `report-upload` が `if: failure() && steps.lint-execute.outcome == 'failure'` で存在すること
  - Target: `ru-qa-actionlint.yml` step `report-upload`
  - Scenario: Given `lint-execute` が失敗する、When `report-upload` の条件を検査する
  - Expected: `if: failure() && steps.lint-execute.outcome == 'failure'`
  - `yq: yq '.jobs.qa-actionlint.steps[] | select(.id == "report-upload") | .if' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-05-03-02**: `report-upload` が `name: jactionlint-report`、`path: .github/report/jactionlint-report.txt`、`retention-days: 30` を持つこと
  - Target: `ru-qa-actionlint.yml` step `report-upload`
  - Scenario: Given `lint-execute` が失敗する、When `report-upload` の with を検査する
  - Expected: `with.name: jactionlint-report`、`with.path: .github/report/jactionlint-report.txt`、`with.retention-days: 30`
  - `yq: yq '.jobs.qa-actionlint.steps[] | select(.id == "report-upload") | .with' .github/workflows/ru-qa-actionlint.yml`

### [エッジケース] Edge Cases

#### T-05-04: config-checkout persist-credentials and upload-report on success suppression

- [x] **T-05-04-01**: `config-checkout` の `persist-credentials` が `false` であること
  - Target: `ru-qa-actionlint.yml` step `config-checkout`
  - Scenario: Given `ru-qa-actionlint.yml` が存在する、When `config-checkout` の認証情報設定を検査する
  - Expected: `with.persist-credentials: false`
  - `yq: yq '.jobs.qa-actionlint.steps[] | select(.id == "config-checkout") | .with.persist-credentials' .github/workflows/ru-qa-actionlint.yml`

- [x] **T-05-04-02**: lint 成功時（exit code 0）に `report-upload` がスキップされること
  - Target: `ru-qa-actionlint.yml` step `report-upload` の `if` 条件
  - Scenario: Given `lint-execute` が exit code 0 で成功する、When `report-upload` の条件を評価する
  - Expected: `if` 条件が `failure()` を含むため、成功時は `report-upload` が実行されない
  - `yq: yq '.jobs.qa-actionlint.steps[] | select(.id == "report-upload") | .if' .github/workflows/ru-qa-actionlint.yml`
