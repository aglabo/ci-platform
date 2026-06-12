---
title: "Requirements: Ghalint Reusable Workflow"
module: "reusable-workflows/ghalint"
status: Draft
version: 1.0
created: "2026-06-13"
---

<!-- markdownlint-disable line-length -->

## 1. Overview

### 1.1 Purpose

本文書は、GitHub Actions ワークフローポリシー検証ツール ghalint を実行するための
reusable workflow (`ci-qa-ghalint.yml`) を ci-platform リポジトリ内に作成し、
`ci-workflows-qa.yml` における外部リポジトリ (`aglabo/.github`) への依存を
ローカル reusable workflow 呼び出しに置き換えることを目的とする。

### 1.2 Scope

- `ci-qa-ghalint.yml`: `workflow_call` トリガーをもつ ghalint 専用 reusable workflow の作成
- `ci-workflows-qa.yml`: 外部 ghalint workflow 呼び出しをローカル呼び出しに置き換え
- 設定ファイルは `aglabo/.github` リポジトリから `./shared/` にチェックアウトして使用
- 入力パラメータ: `ghalint-version`（バージョン固定）、`config-file`（設定パス指定）
- 失敗時のみレポートをアーティファクトとしてアップロード

**Out of Scope**:

- ghalint の新規ポリシー追加や `configs/ghalint.yaml` の設定変更
- ghalint 以外の QA ツール（actionlint, betterleaks）の変更
- `workflow_dispatch` による手動トリガーのサポート
- セルフホストランナー以外の環境サポート

## 2. Context

- Target Environment: GitHub Actions (ubuntu-slim セルフホストランナー)
- Related Components: `ci-workflows-qa.yml`, `.github/actions/validate-environment`, `.github/actions/setup-tool`, `aglabo/.github`（設定リポジトリ）, `configs/ghalint.yaml`
- Assumptions: `setup-tool` composite action が `suzuki-shunsuke/ghalint` の GitHub Releases からバイナリを取得できる

### System Context Diagram

```text
[ci-workflows-qa.yml]  -->  +-----------------------------+  -->  [ghalint binary]
                            |   ci-qa-ghalint.yml         |
[aglabo/.github]       -->  |   (reusable workflow)       |  -->  [.github/report/]
                            +-----------------------------+
                                         |
                            [configs/ghalint.yaml (shared)]
```

## 3. Design Decisions (Summary)

| ID    | Decision                                                      | Linked Record            |
| ----- | ------------------------------------------------------------- | ------------------------ |
| DR-01 | 外部依存を排除しローカル reusable workflow として実装         | decision-record.md#DR-01 |
| DR-02 | 設定は `aglabo/.github` からチェックアウト（actionlint 踏襲） | decision-record.md#DR-02 |
| DR-03 | 入力パラメータは `ghalint-version` と `config-file` の 2 つ   | decision-record.md#DR-03 |
| DR-04 | ステップ間条件は `steps.<id>.outcome == 'success'` パターン   | decision-record.md#DR-04 |
| DR-05 | 失敗時のみレポートをアーティファクトアップロード              | decision-record.md#DR-05 |

## 4. Functional Requirements

### REQ-F-001: Workflow Call Trigger

- EARS Type: feature-based (WHERE)

```text
GIVEN a caller workflow invokes ci-qa-ghalint.yml
  WHERE the workflow defines on.workflow_call
THEN the system SHALL accept the invocation and execute the ghalint job.
```

**Rationale**: CI パイプラインから呼び出されることのみをサポートし、手動トリガーは対象外とする。

**Acceptance Criteria**:

| AC ID  | Scenario                                 |
| ------ | ---------------------------------------- |
| AC-001 | caller workflow から正常に呼び出せること |

### REQ-F-002: Input Parameter Resolution

- EARS Type: event-driven (WHEN)

```text
GIVEN the workflow is invoked via workflow_call
  WHEN input parameters are provided or omitted
THEN the system SHALL resolve ghalint-version to the provided value or the default version,
     and SHALL resolve config-file to the provided path or the default path
     (./shared/configs/ghalint.yaml).
```

**Rationale**: バージョンと設定パスを呼び出し側から上書き可能にし、デフォルト値で運用できるようにする。

**Acceptance Criteria**:

| AC ID  | Scenario                                           |
| ------ | -------------------------------------------------- |
| AC-002 | デフォルト値でパラメータなし呼び出しが成功すること |
| AC-003 | 明示的なバージョン指定が反映されること             |

### REQ-F-003: Target Repository Checkout

- EARS Type: event-driven (WHEN)

```text
GIVEN the workflow job starts
  WHEN the job begins execution
THEN the system SHALL checkout the target repository with persist-credentials: false.
```

**Rationale**: `persist-credentials: false` により認証情報の漏洩リスクを排除する。

**Acceptance Criteria**:

| AC ID  | Scenario                                     |
| ------ | -------------------------------------------- |
| AC-004 | チェックアウトが成功し後続ステップへ進むこと |

### REQ-F-004: Environment Validation

- EARS Type: event-driven (WHEN)

```text
GIVEN the target repository checkout succeeds
  WHEN the env-validation step is reached
THEN the system SHALL execute validate-environment composite action,
     and SHALL block subsequent steps if validation fails.
```

**Rationale**: 実行環境が要件を満たすことを保証し、不正環境での実行を防止する。

**Acceptance Criteria**:

| AC ID  | Scenario                               |
| ------ | -------------------------------------- |
| AC-005 | 正常環境で validation が pass すること |

### REQ-F-005: Tool Installation

- EARS Type: event-driven (WHEN)

```text
GIVEN the environment validation succeeds
  WHEN the tool-install step is reached
THEN the system SHALL install ghalint binary via setup-tool composite action
     using suzuki-shunsuke/ghalint repository and the resolved ghalint-version.
```

**Rationale**: `setup-tool` action を使うことで、他ツール（actionlint, betterleaks）と一貫したインストール方式を維持する。

**Acceptance Criteria**:

| AC ID  | Scenario                                          |
| ------ | ------------------------------------------------- |
| AC-006 | 指定バージョンの ghalint がインストールされること |

### REQ-F-006: Config Repository Checkout

- EARS Type: event-driven (WHEN)

```text
GIVEN the tool installation succeeds
  WHEN the config-checkout step is reached
THEN the system SHALL checkout aglabo/.github repository into ./shared/
     with fetch-depth: 1 and persist-credentials: false.
```

**Rationale**: 設定を外部リポジトリ `aglabo/.github` で一元管理し、ローカルの `config-file` 入力で上書き可能にする。

**Acceptance Criteria**:

| AC ID  | Scenario                                         |
| ------ | ------------------------------------------------ |
| AC-007 | `./shared/configs/ghalint.yaml` が配置されること |

### REQ-F-007: Lint Execution

- EARS Type: event-driven (WHEN)

```text
GIVEN the config repository checkout succeeds
  WHEN the lint-execute step is reached
THEN the system SHALL execute ghalint with the resolved config-file path,
     SHALL output results to .github/report/ghalint-report.txt,
     and SHALL exit with a non-zero code if any policy violation is detected.
```

**Rationale**: lint 失敗を CI 失敗として明確に伝播させ、ポリシー違反を見逃さない。

**Acceptance Criteria**:

| AC ID  | Scenario                                     |
| ------ | -------------------------------------------- |
| AC-008 | ポリシー違反がない場合にジョブが成功すること |
| AC-009 | ポリシー違反がある場合にジョブが失敗すること |

### REQ-F-008: Report Upload on Failure

- EARS Type: event-driven (WHEN)

```text
GIVEN the lint execution fails (non-zero exit)
  WHEN the report-upload step is reached
THEN the system SHALL upload .github/report/ghalint-report.txt as artifact
     named ghalint-report with retention-days: 30.
```

**Rationale**: 失敗時のみアップロードすることで、成功時のストレージ消費を抑制し、エラー詳細を CI 外から参照可能にする。

**Acceptance Criteria**:

| AC ID  | Scenario                                                |
| ------ | ------------------------------------------------------- |
| AC-010 | lint 失敗時にアーティファクトがアップロードされること   |
| AC-011 | lint 成功時にアーティファクトがアップロードされないこと |

### REQ-F-009: Replace External Dependency in ci-workflows-qa.yml

- EARS Type: event-driven (WHEN)

```text
GIVEN ci-qa-ghalint.yml is created and validated
  WHEN ci-workflows-qa.yml is updated
THEN the system SHALL replace the external aglabo/.github ghalint workflow call
     with a local call to ./.github/workflows/ci-qa-ghalint.yml.
```

**Rationale**: 外部リポジトリへの依存を排除し、ghalint workflow をリポジトリ内で完結して管理する。

**Acceptance Criteria**:

| AC ID  | Scenario                                                 |
| ------ | -------------------------------------------------------- |
| AC-012 | `ci-workflows-qa.yml` がローカル workflow を呼び出すこと |

## 5. Non-Functional Requirements

### REQ-NF-001: Security

Implementation MUST set `permissions: contents: read` at both workflow and job level.
`persist-credentials: false` MUST be set on all checkout steps.

### REQ-NF-002: Consistency

The implementation SHOULD follow the same 7-step pattern as `ci-qa-actionlint.yml`
(target-checkout → env-validation → tool-install → config-checkout → prepare-report → lint-execute → report-upload).

### REQ-NF-003: Maintainability

The workflow SHOULD use explicit SHA-pinned action versions for all `uses:` references.
The `timeout-minutes: 10` MUST be set at job level.

### REQ-NF-004: Traceability

Step IDs MUST follow the naming convention established in `ci-qa-actionlint.yml`:
`target-checkout`, `env-validation`, `tool-install`, `config-checkout`, `prepare-report`, `lint-execute`, `report-upload`.

## 6. Constraints

### REQ-C-001: Runner

The job MUST run on `ubuntu-slim` (self-hosted runner).

### REQ-C-002: Step Condition Pattern

Step conditions MUST use `if: steps.<id>.outcome == 'success'` pattern.
The `outputs.status != 'error'` pattern is PROHIBITED.

### REQ-C-003: Workflow Trigger

The workflow MUST support `workflow_call` trigger only.
`workflow_dispatch` is out of scope.

### REQ-C-004: ghalint Config Source

The default configuration MUST be sourced from `aglabo/.github` repository,
checked out into `./shared/`. The `config-file` input MAY override the path.

## 7. User Stories

- As a CI pipeline maintainer, I want a local ghalint reusable workflow, so that I can eliminate the external dependency on `aglabo/.github` and manage all workflow QA tools consistently within the repository.
- As a workflow author, I want ghalint to run automatically on every CI call, so that policy violations are caught before merge.
- As a CI pipeline maintainer, I want to specify the ghalint version as an input parameter, so that version upgrades can be applied without modifying the workflow file itself.
- As a developer investigating a CI failure, I want the ghalint report artifact to be available on failure, so that I can review policy violations without re-running the job.
- As a repository administrator, I want `ci-workflows-qa.yml` to use only local workflow references, so that all CI dependencies are version-controlled within this repository.

## 8. Acceptance Criteria

```gherkin
# AC-001: Normal invocation from caller workflow
# Requirement: REQ-F-001
Scenario: Normal invocation from caller workflow
  Given ci-workflows-qa.yml calls ci-qa-ghalint.yml via workflow_call
  When  the ghalint job executes
  Then  all 7 steps complete in sequence without error

# AC-008: Lint passes when no policy violations exist
# Requirement: REQ-F-007
Scenario: Lint passes when no policy violations exist
  Given all workflow files conform to ghalint policies
  When  ghalint executes with the resolved config-file
  Then  ghalint exits with code 0 and the job succeeds

# AC-009: Lint fails when policy violations exist
# Requirement: REQ-F-007
Scenario: Lint fails when policy violations exist
  Given at least one workflow file violates a ghalint policy
  When  ghalint executes with the resolved config-file
  Then  ghalint exits with a non-zero code and the job fails

# AC-010: Report artifact uploaded on failure
# Requirement: REQ-F-008
Scenario: Report artifact uploaded on failure
  Given the lint-execute step exits with a non-zero code
  When  the report-upload step evaluates its condition
  Then  ghalint-report.txt is uploaded as artifact ghalint-report with 30-day retention

# AC-011: Report artifact not uploaded on success
# Requirement: REQ-F-008
Scenario: Report artifact not uploaded on success
  Given the lint-execute step exits with code 0
  When  the report-upload step evaluates its condition
  Then  no artifact is uploaded
```

## 9. Traceability

| REQ ID     | AC IDs         | Type           |
| ---------- | -------------- | -------------- |
| REQ-F-001  | AC-001         | Functional     |
| REQ-F-002  | AC-002, AC-003 | Functional     |
| REQ-F-003  | AC-004         | Functional     |
| REQ-F-004  | AC-005         | Functional     |
| REQ-F-005  | AC-006         | Functional     |
| REQ-F-006  | AC-007         | Functional     |
| REQ-F-007  | AC-008, AC-009 | Functional     |
| REQ-F-008  | AC-010, AC-011 | Functional     |
| REQ-F-009  | AC-012         | Functional     |
| REQ-NF-001 | —              | Non-Functional |
| REQ-NF-002 | —              | Non-Functional |
| REQ-NF-003 | —              | Non-Functional |
| REQ-NF-004 | —              | Non-Functional |
| REQ-C-001  | —              | Constraint     |
| REQ-C-002  | —              | Constraint     |
| REQ-C-003  | —              | Constraint     |
| REQ-C-004  | —              | Constraint     |

## 10. Open Questions

| Question                                                                           | Type    | Impact Area         | Owner |
| ---------------------------------------------------------------------------------- | ------- | ------------------- | ----- |
| ghalint のデフォルトバージョン番号（`suzuki-shunsuke/ghalint` 最新安定版）は何か？ | Version | REQ-F-005           | TBD   |
| `aglabo/.github` の `shared/configs/ghalint.yaml` が存在するか確認が必要           | Config  | REQ-F-006, REQ-C-04 | TBD   |

## 11. Change History

| Date       | Version | Description     |
| ---------- | ------- | --------------- |
| 2026-06-13 | 1.0.0   | Initial release |
