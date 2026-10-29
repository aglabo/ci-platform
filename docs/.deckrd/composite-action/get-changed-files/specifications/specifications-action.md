---
title: "Design Specification: ca-get-changed-files (Action)"
based-on: requirements.md v2.1.2
status: approved
version: 1.2.2
created: "2026-10-29"
---

> Part of split specification. See `specifications-index.md` for full scope.

## 1. Overview

### 1.1 Purpose

本書は、`action.yml` の入出力、3 つの step の連鎖、各 step の env の対応付け、内部スクリプトの実行方法を定義する。

### 1.2 Scope

本書は、`action.yml` が満たす振る舞いと、その静的な検査の規則を定義する。
差分の取得 (`get-changed-files.sh`) は specifications-diff.md で定義する。

---

## 2. Design Principles

### 2.1 Classification Philosophy

`action.yml` は判定を持たず、値の受け渡しだけを行う。
入力は加工せずに内部スクリプトへ渡し、内部スクリプトの出力は加工せずに次の段か Action の出力へ渡す (REQ-F-001, REQ-F-004, REQ-F-005)。

内部 Action は `uses:` で参照せず、同じ ref で取得された兄弟ディレクトリのスクリプトを `run` で実行する (DR-05)。
内部 Action の `action.yml` が行っている env の対応付けは、本 Action の `action.yml` に同じ名前で書く。この重複は GACT の静的検査で食い違いを検出する (DR-12)。

### 2.2 Design Assumptions

- 2.2 of `specifications-index.md` の前提を満たす。
- Composite Action の step は、既定で前の step が失敗すると実行されない。各 step に `if:` を書かない限り、この既定に従う。
- Composite Action は `INPUT_*` を自動設定しない。step は、呼び出し元のジョブの `env` を引き継ぐ。

### 2.3 External Design Summary

#### Feature Decomposition

| Unit         | Responsibility                                                    | REQ Coverage                    |
| ------------ | ----------------------------------------------------------------- | ------------------------------- |
| interface    | 入力 `commit-count`・`pattern` と出力 `files`・`count` を宣言する | REQ-F-005, REQ-C-005            |
| step-chain   | resolve-sha → get-changed-files → filter-files の順に実行する     | REQ-F-002, REQ-F-004, REQ-F-006 |
| env-mapping  | 各 step の env を、入力・イベント値・前の step の出力で埋める     | REQ-F-001, REQ-F-002, REQ-C-001 |
| script-paths | 内部スクリプトを `${GITHUB_ACTION_PATH}/..` から実行する          | REQ-F-007                       |

#### Unit Interaction Map

```text
+-----------+     +-------------+     +-------------+
| interface | --> | env-mapping | --> | step-chain  |
+-----------+     +-------------+     +-------------+
                                             |
                                             v
                                      +--------------+
                                      | script-paths |
                                      +--------------+
```

### 2.4 Non-Goals

> **Derivation**: All items below originate from REQUIREMENTS Section "Out of Scope".

- 出力の追加 (`resolution` を含む) ← REQ: Out of Scope #4
- 内部 Action と `_libs/` の変更 ← REQ: Out of Scope #3

### 2.5 Behavioral Design Decisions

| ID        | Decision                                                                         | Rationale                                                                                                                     | Affected Rules       | Status           |
| --------- | -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- | -------------------- | ---------------- |
| DD-ACT-01 | step を 3 つに分け、段間は step 出力で受け渡す                                   | 内部スクリプトはどちらも `main` を定義するため、同じプロセスで読み込めない。step ごとに出力ファイルが分かれ、キーが衝突しない | R-ACT-010〜R-ACT-013 | Promoted → DR-12 |
| DD-ACT-02 | `INPUT_BEFORE_SHA` と `INPUT_AFTER_SHA` は step の env で `""` を明示する        | step は呼び出し元のジョブの env を引き継ぐ。明示しないと、ジョブ env の値でオーバーライドが有効になり得る                     | R-ACT-021            | Active           |
| DD-ACT-03 | env の対応付けの食い違いは、内部 Action の `action.yml` との比較で静的に検査する | 2 か所に書く対応付けのずれを、実行せずに検出する (DR-05 の Negative)                                                          | R-ACT-040            | Promoted → DR-12 |
| DD-ACT-04 | step の `id` は `resolve-sha`・`get-changed-files`・`filter-files` とする        | 段の名前と一致させ、出力の参照元を読み取りやすくする                                                                          | R-ACT-010〜R-ACT-013 | Active           |

**Status Values:**

- `Active` — Currently in effect within this specification
- `Promoted → DR-xx` — Elevated to formal Decision Record (see Section 2.6)

### 2.6 Related Decision Records

| DR-ID | Title                                                                                      | Phase         | Impact on This Spec                        |
| ----- | ------------------------------------------------------------------------------------------ | ------------- | ------------------------------------------ |
| DR-01 | 差分範囲の SHA 解決を `_ca-resolve-sha` に任せる                                           | req           | resolve-sha の step                        |
| DR-02 | 変更ファイルの絞り込みを `_ca-filter-files` に任せる                                       | req           | filter-files の step                       |
| DR-03 | 入力 `before-sha` / `after-sha` を削除し、`commit-count` に置き換える                      | req           | 入力、R-ACT-021                            |
| DR-04 | 入力名 `pattern` を維持し、意味だけを glob に変える                                        | req           | 入力                                       |
| DR-05 | 内部 Action は `uses:` ではなく、`${GITHUB_ACTION_PATH}/..` のスクリプトを直接実行して使う | req           | R-ACT-030〜R-ACT-032                       |
| DR-08 | 出力は `files` / `count` だけとし、`resolution` は公開しない                               | req           | 出力                                       |
| DR-10 | 対象リポジトリを作業ディレクトリに checkout することを呼び出し元の義務とする               | req (harden)  | R-ACT-003                                  |
| DR-12 | 3 つの step で構成し、env の対応付けの一致を静的に検査する                                 | spec (harden) | R-ACT-010〜R-ACT-013、R-ACT-040、R-ACT-041 |

### 2.7 DD to DR Promotion Criteria

See `specifications-index.md` 2.7.

---

## 3. Behavioral Specification

### 3.1 Input Domain

- Input Type: Action 入力 (`commit-count`・`pattern`) と GitHub のイベントコンテキスト
- Assumptions: 2.2 の前提を満たす。入力の値の検査は、本 Action ではなく内部スクリプトが行う。

### 3.2 Output Semantics

- Output Meaning: filter-files の step が書いた `files`・`count`
- Possible Outcomes:
  - すべての step が成功: `files`・`count` が設定される
  - いずれかの step が失敗: 後続の step は実行されず、Action は失敗する

---

## 4. Decision Rules

**入出力の宣言 (interface):**

| Rule ID   | Step | Condition | Outcome                                                                                                                                                                                                 |
| --------- | ---: | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| R-ACT-001 |    — | 入力      | `commit-count` (required: false, default: "1") と `pattern` (required: false, default: "") だけを宣言する                                                                                               |
| R-ACT-002 |    — | 出力      | `files` は `steps.filter-files.outputs.files`、`count` は `steps.filter-files.outputs.count` を値とする                                                                                                 |
| R-ACT-003 |    — | 説明      | `description` に、`fetch-depth: 0` の必要、partial clone の不可、push のブランチ削除・タグの除外、対象リポジトリを作業ディレクトリに checkout し `path` を使わないことを書く (REQ-C-003, AC-017, DR-10) |

**step の連鎖 (step-chain):**

| Rule ID   | Step | Condition | Outcome                                                                                                           |
| --------- | ---: | --------- | ----------------------------------------------------------------------------------------------------------------- |
| R-ACT-010 |    1 | —         | step `resolve-sha` で `_ca-resolve-sha` のスクリプトを実行する                                                    |
| R-ACT-011 |    2 | —         | step `get-changed-files` で本 Action の `scripts/get-changed-files.sh` を実行する                                 |
| R-ACT-012 |    3 | —         | step `filter-files` で `_ca-filter-files` のスクリプトを実行する                                                  |
| R-ACT-013 |    — | 全 step   | `shell: bash` とし、`if:` と `continue-on-error` を書かない。前の step が失敗した場合、後続の step は実行されない |

No reordering is permitted.

**env の対応付け (env-mapping):**

| Rule ID   | Step | 対象 step           | 環境変数                                                                                                                                 | 値                                                                                                                                                                                                                 |
| --------- | ---: | ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| R-ACT-020 |    1 | `resolve-sha`       | `GITHUB_EVENT_NAME`、`GITHUB_REF`、`GITHUB_EVENT_DELETED`、`GITHUB_BEFORE_SHA`、`GITHUB_AFTER_SHA`、`GITHUB_BASE_SHA`、`GITHUB_HEAD_SHA` | `_ca-resolve-sha/action.yml` と同じ式 (`github.event_name`、`github.ref`、`github.event.deleted`、`github.event.before`、`github.sha`、`github.event.pull_request.base.sha`、`github.event.pull_request.head.sha`) |
| R-ACT-021 |    1 | `resolve-sha`       | `INPUT_COMMIT_COUNT`、`INPUT_BEFORE_SHA`、`INPUT_AFTER_SHA`                                                                              | `inputs.commit-count`、`""`、`""` (DD-ACT-02)                                                                                                                                                                      |
| R-ACT-022 |    2 | `get-changed-files` | `BEFORE_SHA`、`AFTER_SHA`                                                                                                                | `steps.resolve-sha.outputs.before_sha`、`steps.resolve-sha.outputs.after_sha`                                                                                                                                      |
| R-ACT-023 |    3 | `filter-files`      | `INPUT_FILES`、`INPUT_PATTERNS`                                                                                                          | `steps.get-changed-files.outputs.files`、`inputs.pattern`                                                                                                                                                          |

- `run` の中に `${{ }}` を書かない (REQ-C-001)。値はすべて env で渡す。
- `_ca-resolve-sha` のスクリプトは、step 出力のキーを `before_sha`・`after_sha`・`resolution` (snake_case) で書く。`resolution` は参照しない (DR-08)。

**スクリプトの実行 (script-paths):**

| Rule ID   | Step | 対象 step           | `run`                                                                      |
| --------- | ---: | ------------------- | -------------------------------------------------------------------------- |
| R-ACT-030 |    1 | `resolve-sha`       | `bash "${GITHUB_ACTION_PATH}/../_ca-resolve-sha/scripts/resolve-sha.sh"`   |
| R-ACT-031 |    2 | `get-changed-files` | `bash "${GITHUB_ACTION_PATH}/scripts/get-changed-files.sh"`                |
| R-ACT-032 |    3 | `filter-files`      | `bash "${GITHUB_ACTION_PATH}/../_ca-filter-files/scripts/filter-files.sh"` |

- `uses:` で内部 Action を参照しない (REQ-F-007)。
- 内部スクリプトは自身の位置から `_libs` を読み込むため、上記のパスで実行できる。

**静的検査 (GACT):**

| Rule ID   | Step | Condition                                                           | Outcome                                                                                                                |
| --------- | ---: | ------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| R-ACT-040 |    — | `resolve-sha` の env (`INPUT_BEFORE_SHA`・`INPUT_AFTER_SHA` を除く) | `_ca-resolve-sha/action.yml` の step env と、変数名と式が一致する                                                      |
| R-ACT-041 |    — | `filter-files` の env                                               | 変数名が `_ca-filter-files/action.yml` の step env と一致する (値は R-ACT-023)                                         |
| R-ACT-042 |    — | すべての `run`                                                      | `${{` を含まない                                                                                                       |
| R-ACT-043 |    — | 入力                                                                | `before-sha`・`after-sha` が無く、R-ACT-001 の `required`・`default` を持つ                                            |
| R-ACT-044 |    — | 出力                                                                | R-ACT-002 の参照先を持つ                                                                                               |
| R-ACT-045 |    — | 内部 Action の参照                                                  | `uses:` を含まない                                                                                                     |
| R-ACT-046 |    — | `description`                                                       | R-ACT-003 の 4 項目 (fetch-depth: 0、partial clone、ブランチ削除・タグ、作業ディレクトリへの checkout) を含む (AC-017) |

---

## 5. Edge Cases

| Input                                                           | Classification                                                   | REQ       | Rationale                   |
| --------------------------------------------------------------- | ---------------------------------------------------------------- | --------- | --------------------------- |
| `commit-count` 未指定                                           | `INPUT_COMMIT_COUNT` は `"1"`                                    | REQ-F-001 | R-ACT-001, R-ACT-021        |
| `commit-count: "02"`                                            | 加工せずに渡し、SHA の解決の段でエラー                           | REQ-F-001 | 検証は `_ca-resolve-sha`    |
| 呼び出し元のジョブ env に `INPUT_BEFORE_SHA`・`INPUT_AFTER_SHA` | step env の `""` が優先し、オーバーライドは無効                  | REQ-F-002 | DD-ACT-02                   |
| 呼び出し元のジョブ env に `INPUT_PATTERNS`                      | step env の `inputs.pattern` が優先する                          | REQ-F-004 | R-ACT-023                   |
| 呼び出し元が `before-sha` を渡す (削除済みの入力)               | ランナーが未定義の入力として警告する。値は使われない             | REQ-C-005 | R-ACT-043                   |
| 作業ディレクトリに `.github/actions/_ca-*` が無い               | `${GITHUB_ACTION_PATH}/..` から実行するため影響しない            | REQ-F-007 | R-ACT-030〜R-ACT-032 (RUNF) |
| resolve-sha の step が失敗                                      | get-changed-files・filter-files の step は実行されない           | REQ-F-006 | R-ACT-013                   |
| 変更なしで `files` が空                                         | filter-files の step は空の `INPUT_FILES` を受け、`count` は `0` | REQ-F-005 | `_ca-filter-files` の空入力 |

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule                       | Notes                                |
| -------------- | ------------------------------- | ------------------------------------ |
| REQ-F-001      | R-ACT-001, R-ACT-021            |                                      |
| REQ-F-002      | R-ACT-010, R-ACT-020〜R-ACT-022 | DD-ACT-02                            |
| REQ-F-004      | R-ACT-012, R-ACT-023            |                                      |
| REQ-F-005      | R-ACT-002                       |                                      |
| REQ-F-006      | R-ACT-013                       | 段ごとのエラーは各スクリプトの規則   |
| REQ-F-007      | R-ACT-030〜R-ACT-032, R-ACT-045 | AC-014 は RUNF                       |
| REQ-C-001      | R-ACT-042                       |                                      |
| REQ-C-002      | —                               | `permissions` は呼び出し元が宣言する |
| REQ-C-004      | —                               | actionlint / ghalint                 |
| REQ-C-005      | R-ACT-001, R-ACT-002, R-ACT-043 |                                      |
| REQ-C-003      | R-ACT-003, R-ACT-046            |                                      |
| REQ-C-006      | R-ACT-040, R-ACT-041            | 内部 Action は読むだけで変更しない   |
| REQ-F-003      | —                               | Covered in: `specifications-diff.md` |

---

## 7. Open Questions

> **Status**: COMPLETE

None identified - all requirements are unambiguous.

---

## 8. Change History

| Date       | Version | Description                                                                                                          |
| ---------- | ------- | -------------------------------------------------------------------------------------------------------------------- |
| 2026-10-29 | 1.0.0   | Initial release                                                                                                      |
| 2026-10-29 | 1.0.1   | Refresh based-on (requirements v2.0.2)                                                                               |
| 2026-10-29 | 1.1.0   | R-ACT-003: description also states the workspace checkout obligation (DR-10); refresh based-on (requirements v2.1.0) |
| 2026-10-29 | 1.2.0   | Add R-ACT-046: static check of the description (AC-017); refresh based-on (requirements v2.1.2)                      |
| 2026-10-30 | 1.2.1   | Promote DD-ACT-01 / DD-ACT-03 to DR-12                                                                               |
| 2026-10-30 | 1.2.2   | Apply spec fix review: cite DR-12, unify stage terms                                                                 |
