---
title: "Implementation Tasks: Ghalint Reusable Workflow"
module: reusable-workflows/ghalint
status: Active
created: "2026-06-13 00:00:00"
source: specifications.md
---

<!-- markdownlint-disable line-length -->

## Task Summary

| Test Target                  | Scenarios | Cases | Status    |
| ---------------------------- | --------- | ----- | --------- |
| T-01: ru-qa-ghalint.yml      | 4         | 12    | completed |
| T-02: trigger-inputs         | 2         | 4     | completed |
| T-03: step-gating            | 3         | 8     | completed |
| T-04: lint-execute           | 2         | 4     | completed |
| T-05: ci-workflows-qa update | 2         | 3     | completed |

---

## T-01: ru-qa-ghalint.yml

### [正常] Normal Cases

#### T-01-01: workflow_call トリガーとジョブ基本設定

- [x] **T-01-01-01**: workflow_call トリガーのみを定義しています
  - Target: `ru-qa-ghalint.yml`
  - Scenario: Given ru-qa-ghalint.yml を作成しています, When on トリガーを確認します
  - Expected: Then `on.workflow_call` のみが存在し `workflow_dispatch` は存在しません

- [x] **T-01-01-02**: ジョブを ubuntu-slim かつ timeout-minutes: 10 で定義しています
  - Target: `ru-qa-ghalint.yml jobs.qa-ghalint`
  - Scenario: Given ジョブ定義を確認します, When runs-on と timeout-minutes を検査します
  - Expected: Then `runs-on: ubuntu-slim` かつ `timeout-minutes: 10` を設定しています

- [x] **T-01-01-03**: permissions: contents: read を workflow レベルと job レベルの両方に設定しています
  - Target: `ru-qa-ghalint.yml`
  - Scenario: Given permissions 設定を確認します, When workflow レベルと job レベルを検査します
  - Expected: Then 両レベルで `contents: read` のみを設定しています

#### T-01-02: inputs 定義

- [x] **T-01-02-01**: version input をデフォルト値付きで定義しています
  - Target: `ru-qa-ghalint.yml on.workflow_call.inputs`
  - Scenario: Given inputs 定義を確認します, When version を検査します
  - Expected: Then type: string, required: false, default: `1.6.0` を設定しています

- [x] **T-01-02-02**: config input をデフォルト値 `./global/configs/ghalint.yaml` 付きで定義しています
  - Target: `ru-qa-ghalint.yml on.workflow_call.inputs`
  - Scenario: Given inputs 定義を確認します, When config を検査します
  - Expected: Then type: string, required: false, default: `./global/configs/ghalint.yaml` を設定しています

#### T-01-03: ステップ定義とバージョン固定

- [x] **T-01-03-01**: 全 7 ステップを正しい ID で順序どおりに定義しています
  - Target: `ru-qa-ghalint.yml jobs.qa-ghalint.steps`
  - Scenario: Given ステップ一覧を確認します, When ステップ ID と順序を検査します
  - Expected: Then 次の順序で定義しています。
    前半は target-checkout → env-validation → tool-install → config-checkout です。
    後半は prepare-report → lint-execute → report-upload です

- [x] **T-01-03-02**: actions/checkout をバージョンタグで固定しています
  - Target: `ru-qa-ghalint.yml steps.target-checkout, steps.config-checkout`
  - Scenario: Given checkout ステップを確認します, When uses の値を検査します
  - Expected: Then `actions/checkout@v7.0.1` を使用しています

- [x] **T-01-03-03**: actions/upload-artifact をバージョンタグで固定しています
  - Target: `ru-qa-ghalint.yml steps.report-upload`
  - Scenario: Given report-upload ステップを確認します, When uses の値を検査します
  - Expected: Then `actions/upload-artifact@v7.0.2` を使用しています

#### T-01-04: config-checkout と lint-execute の設定

- [x] **T-01-04-01**: config-checkout が aglabo/global-configs を ./global/configs/ に fetch-depth: 1 でチェックアウトします
  - Target: `ru-qa-ghalint.yml steps.config-checkout`
  - Scenario: Given config-checkout ステップを確認します, When with パラメータを検査します
  - Expected: Then 次の 4 項目を設定しています。
    `repository: aglabo/global-configs`, `path: global/configs`, `fetch-depth: 1`, `persist-credentials: false`

- [x] **T-01-04-02**: lint-execute が ghalint run --config で実行され終了コードを伝播します
  - Target: `ru-qa-ghalint.yml steps.lint-execute`
  - Scenario: Given lint-execute ステップを確認します, When run コマンドを検査します
  - Expected: Then 次の 2 つを含んでいます。
    `ghalint run --config "${CONFIG_FILE}"` (`CONFIG_FILE: ${{ inputs.config }}`) と `exit "${PIPESTATUS[0]}"`

---

## T-02: trigger-inputs

### [正常] Normal Cases

#### T-02-01: デフォルト値の解決

- [x] **T-02-01-01**: version を省略した場合にデフォルトバージョンを使用します
  - Target: `ru-qa-ghalint.yml inputs.version`
  - Scenario: Given version を指定せず呼び出します, When tool-install を実行します
  - Expected: Then デフォルトバージョンで ghalint をインストールします (R-002a)

- [x] **T-02-01-02**: config を省略した場合に `./global/configs/ghalint.yaml` を使用します
  - Target: `ru-qa-ghalint.yml inputs.config`
  - Scenario: Given config を指定せず呼び出します, When lint-execute を実行します
  - Expected: Then `./global/configs/ghalint.yaml` を config として使用します (R-003a)

#### T-02-02: 明示的なパラメータ指定

- [x] **T-02-02-01**: 明示的に指定した version を tool-install で使用します
  - Target: `ru-qa-ghalint.yml inputs.version`
  - Scenario: Given version を明示的に指定して呼び出します, When tool-install を実行します
  - Expected: Then 指定したバージョンで ghalint をインストールします (R-002)

- [x] **T-02-02-02**: 明示的に指定した config を lint-execute で使用します
  - Target: `ru-qa-ghalint.yml inputs.config`
  - Scenario: Given config を明示的に指定して呼び出します, When lint-execute を実行します
  - Expected: Then 指定したパスを `--config` 引数として使用します (R-003)

---

## T-03: step-gating

### [正常] Normal Cases

#### T-03-01: 成功時のステップ連鎖

- [x] **T-03-01-01**: target-checkout の成功時に env-validation を実行します
  - Target: `ru-qa-ghalint.yml steps.env-validation.if`
  - Scenario: Given target-checkout が成功します, When env-validation の if 条件を確認します
  - Expected: Then `steps.target-checkout.outcome == 'success'` 条件を設定しています (R-004)

- [x] **T-03-01-02**: env-validation に actions-type: read を設定しています
  - Target: `ru-qa-ghalint.yml steps.env-validation`
  - Scenario: Given env-validation ステップを確認します, When with パラメータを検査します
  - Expected: Then `actions-type: read` を設定しています

- [x] **T-03-01-03**: tool-install に suzuki-shunsuke/ghalint を設定しています
  - Target: `ru-qa-ghalint.yml steps.tool-install`
  - Scenario: Given tool-install ステップを確認します, When with パラメータを検査します
  - Expected: Then 次の 2 項目を設定しています (R-006)。
    `repo: suzuki-shunsuke/ghalint` と `tool-version: ${{ inputs.version }}`

### [異常] Error Cases

#### T-03-02: 失敗時のステップブロック

- [x] **T-03-02-01**: target-checkout の失敗時に後続の全ステップをブロックします
  - Target: `ru-qa-ghalint.yml steps.*.if`
  - Scenario: Given target-checkout が失敗します, When 後続ステップの if 条件を確認します
  - Expected: Then env-validation 以降の全ステップをブロックします (R-004a)。
    ブロックは `steps.target-checkout.outcome == 'success'` チェーンによります

- [x] **T-03-02-02**: report-upload は failure() かつ lint-execute の失敗時のみ実行します
  - Target: `ru-qa-ghalint.yml steps.report-upload.if`
  - Scenario: Given lint-execute が失敗します, When report-upload の if 条件を確認します
  - Expected: Then `failure() && steps.lint-execute.outcome == 'failure'` を設定しています (R-009a)

### [エッジケース] Edge Cases

#### T-03-03: persist-credentials と認証情報保護

- [x] **T-03-03-01**: target-checkout で persist-credentials: false を設定しています
  - Target: `ru-qa-ghalint.yml steps.target-checkout`
  - Scenario: Given target-checkout の with パラメータを確認します
  - Expected: Then `persist-credentials: false` を設定しています (REQ-NF-001)

- [x] **T-03-03-02**: config-checkout で persist-credentials: false を設定しています
  - Target: `ru-qa-ghalint.yml steps.config-checkout`
  - Scenario: Given config-checkout の with パラメータを確認します
  - Expected: Then `persist-credentials: false` を設定しています (REQ-NF-001)

---

## T-04: lint-execute

### [正常] Normal Cases

#### T-04-01: ポリシー違反なし

- [x] **T-04-01-01**: report-upload は lint の成功時に実行しません
  - Target: `ru-qa-ghalint.yml steps.report-upload.if`
  - Scenario: Given lint-execute が exit code 0 で終了します, When report-upload の条件を確認します
  - Expected: Then `failure()` が false のためアーティファクトをアップロードしません (R-009)

- [x] **T-04-01-02**: レポートファイルを正しいパスに出力します
  - Target: `ru-qa-ghalint.yml steps.lint-execute`
  - Scenario: Given lint-execute を実行します, When run コマンドのリダイレクトを確認します
  - Expected: Then `.github/report/ghalint-report.txt` に tee で出力します

### [異常] Error Cases

#### T-04-02: ポリシー違反あり

- [x] **T-04-02-01**: ポリシー違反時に report-upload を実行します
  - Target: `ru-qa-ghalint.yml steps.report-upload`
  - Scenario: Given lint-execute が非ゼロ終了します, When report-upload の条件を評価します
  - Expected: Then `failure() && steps.lint-execute.outcome == 'failure'` が true になります (R-009a)。
    その結果、アーティファクトをアップロードします

- [x] **T-04-02-02**: アーティファクトに正しい名前と保持期間を設定しています
  - Target: `ru-qa-ghalint.yml steps.report-upload`
  - Scenario: Given report-upload を実行します, When with パラメータを確認します
  - Expected: Then 次の 3 項目を設定しています (REQ-F-008)。
    `name: ghalint-report`, `path: .github/report/ghalint-report.txt`, `retention-days: 30`

---

## T-05: ci-workflows-qa update

### [正常] Normal Cases

#### T-05-01: 外部依存の置き換え

- [x] **T-05-01-01**: ci-workflows-qa.yml の ghalint ジョブがローカル workflow を参照しています
  - Target: `ci-workflows-qa.yml jobs.ghalint.uses`
  - Scenario: Given ci-workflows-qa.yml を確認します, When ghalint ジョブの uses を検査します
  - Expected: Then `./.github/workflows/ru-qa-ghalint.yml` を使用しており外部参照は存在しません (REQ-F-009)

- [x] **T-05-01-02**: 外部 aglabo/.github 参照を ci-workflows-qa.yml から削除しています
  - Target: `ci-workflows-qa.yml`
  - Scenario: Given ci-workflows-qa.yml の全内容を確認します
  - Expected: Then `aglabo/.github/.github/workflows/ci-common-lint-ghalint.yml` への参照は存在しません

### [エッジケース] Edge Cases

#### T-05-02: permissions 維持

- [x] **T-05-02-01**: ci-workflows-qa.yml の ghalint ジョブで permissions: contents: read を維持しています
  - Target: `ci-workflows-qa.yml jobs.ghalint.permissions`
  - Scenario: Given ghalint ジョブの permissions を確認します
  - Expected: Then `contents: read` を設定しており他の権限は追加していません (REQ-NF-001)
