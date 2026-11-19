---
title: "Design Specification: setup-tool-repo Composite Action (ca-setup-repo)"
based-on: requirements.md v1.0.7
status: Draft
version: 1.3.0
created: "2026-06-18"
---

<!-- textlint-disable
  ja-technical-writing/sentence-length -->
<!-- markdownlint-disable line-length -->

> **Normative Statement**
> This document defines behavioral contracts for implementation.
> RFC 2119 keywords apply to this document only.

## 1. Overview

### 1.1 Purpose

`setup-tool-repo` コンポジットアクション（実装: `.github/actions/ca-setup-repo/`）の外部動作契約を定義する。
GitHub Actions ワークフローが Node.js ベースのツール管理リポジトリを
チェックアウト・インストールし、後続ステップからツールを実行可能にするまでの
各ユニットの事前条件・事後条件・エラー規則を規定する。

### 1.2 Scope

本仕様書は各ユニットの **振る舞いルール** と **外部インターフェース契約** を定義する。

実装の詳細（関数名・ファイルパス・クラス構造）は明示的にスコープ外とする。

---

## 2. Design Principles

### 2.1 Design Philosophy

- Fail-fast: 各ユニットは事前条件が満たされない場合、後続処理を実行せず即座に失敗する
- 順序保証: 8 ユニットは定義された順序で実行され、前ユニットの成功が次ユニットの事前条件となる
- 最小副作用: 副作用（GITHUB_PATH への書き込み）は最終ユニット（add-path）のみに集約する（check-existing-repo のロックと `REPO_LOCK_DIR` を除く）
- 公式アクション委譲: Node.js/pnpm のセットアップとリポジトリチェックアウトは公式アクションに委譲する

### 2.2 Design Assumptions

- 呼び出し元リポジトリは既にチェックアウト済みである
- ツールリポジトリはパブリックリポジトリであり、デフォルト `GITHUB_TOKEN` でアクセス可能
- ツールリポジトリのルートに `package.json`、`pnpm-lock.yaml`、`bin/` が存在する
- `bin/` 配下のラッパースクリプトは `node_modules/.bin` を内部で解決する
- ランナーは GitHub Actions の ubuntu runner（Linux x86_64）である

### 2.3 External Design Summary

> **Source**: Phase D（ユーザー確認済み設計方向）および Phase E（外部設計対話）より導出。

#### Feature Decomposition

| Unit                | Responsibility                                                       | REQ Coverage             |
| ------------------- | -------------------------------------------------------------------- | ------------------------ |
| validate-inputs     | repo / path / ref の入力検証                                         | REQ-F-001, REQ-C-005/006 |
| check-existing-repo | path の既存チェックアウト確認（.repo ファイルによる同一性検証）      | REQ-F-001                |
| checkout-repo       | 外部リポジトリのチェックアウト                                       | REQ-F-001                |
| setup-environment   | pnpm / Node.js のセットアップ（pnpm → Node.js、pnpm キャッシュ有効） | REQ-F-005                |
| validate-env        | checkout 後の repo 構造検証（pnpm-lock.yaml / bin/）                 | REQ-C-003/004            |
| install-packages    | pnpm install --frozen-lockfile                                       | REQ-F-002                |
| verify-install      | bin/ + node_modules/.bin/ 存在・実行権限検証                         | REQ-F-003, REQ-C-003     |
| add-path            | bin/ を GITHUB_PATH に追加                                           | REQ-F-004                |

#### Unit Interaction Map

```text
+------------------+     +----------------------+
| validate-inputs  | --> | check-existing-repo  |
+------------------+     +----------------------+
                            |              |
                     same repo        different repo
                     (skip flag)          |
                            |             v
                            |          [exit 1]
                            v
                   +----------------+     (skip flag set)
                   | checkout-repo  | --> [skip: write .repo skipped]
                   +----------------+
                            |
                            v
                   +-------------------+
                   | setup-environment |
                   +-------------------+
                            |
                            v
                   +------------------+
                   |  validate-env    |
                   +------------------+
                            |
                            v
                   +------------------+
                   | install-packages |
                   +------------------+
                            |
                            v
                   +------------------+
                   | verify-install   |
                   +------------------+
                            |
                            v
                   +------------------+
                   |   add-path       |
                   +------------------+
                            |
                            v
               [Subsequent Steps: tools available]
```

#### Data Flow Diagram

```text
[inputs: repo, path, ref, node-version, pnpm-version]
           |
           v
[validate-inputs] --fail--> [exit 1: invalid format]
           |
           v
[check-existing-repo]
  <path> exists?
  |              |
  | yes          | no (new checkout)
  v              |
[read .repo]     |
  |              |
  same repo? --> skip flag = true
  |
  different repo --> [exit 1: repo conflict]
           |
           v (skip flag = false, or new)
[checkout-repo: actions/checkout] --fail--> [exit propagated]
  (skip flag に関わらず常に実行)
           |
           v
[setup-environment: pnpm/action-setup -> actions/setup-node (cache: pnpm)]
           |
           v
[validate-env: pnpm-lock.yaml + bin/ 存在確認]
  (skip flag = true の場合は validate-env / install-packages をスキップ)
  |                   |
  | fail              | success
  v                   v
[exit 1]   [install-packages: pnpm install --frozen-lockfile]
             |         |
             | fail    | success
             v         v
          [exit 1]  [verify-install]
                       |         |
                       | fail    | success
                       v         v
                    [exit 1]  [add-path]
                              1. echo >> GITHUB_PATH
                              2. write .repo = <repo>@<ref> (skip if skip flag = true)
                           --> exit 0
```

### 2.4 Non-Goals

> **Derivation**: requirements.md Section 1.2 Out of Scope より。

- プライベートリポジトリへのアクセス ← REQ-C-002
- macOS/Windows ランナーのサポート ← REQ-C-001
- チェックサム検証やセキュリティスキャン（呼び出し元責務）
- npm/yarn など pnpm 以外のパッケージマネージャーのサポート
- 独自のキャッシュ機構の提供（pnpm ストアのキャッシュは `actions/setup-node` の `cache: "pnpm"` に委譲）

### 2.5 Behavioral Design Decisions

| ID    | Decision                                                          | Rationale                                                                                                                                                                                                      | Affected Rules | Status |
| ----- | ----------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- | ------ |
| DD-01 | `ref` は必須パラメータとする                                      | サプライチェーンリスク軽減（DR-05）                                                                                                                                                                            | R-003          | Active |
| DD-02 | パッケージマネージャーは pnpm 固定                                | ツールリポジトリ設計の明確化（DR-02）                                                                                                                                                                          | R-007, R-008   | Active |
| DD-03 | Node.js・pnpm のデフォルトバージョンを持たない（空文字 = 未指定） | 特定バージョンを固定せず、呼び出し元の解決に委ねる。`pnpm/action-setup` は `pnpm-version` が空のとき呼び出し元の `package.json` の `packageManager` を読む。バージョンを固定したい呼び出し元は明示的に指定する | R-005, R-006   | Active |
| DD-04 | PATH 追加は `bin/` のみ（`node_modules/.bin` は追加しない）       | `bin/` が内部解決するため二重追加は不要（DR-04）                                                                                                                                                               | R-013          | Active |
| DD-05 | `path` はセグメント単位で `..` を検出（部分文字列マッチは不可）   | パストラバーサル防止・誤検知回避                                                                                                                                                                               | R-002          | Active |
| DD-06 | `path` は `./` 始まりの相対パスのみ（絶対パス不可）               | actions/checkout との整合性確保                                                                                                                                                                                | R-002          | Active |
| DD-07 | ランナー環境の検証は行わない（`ca-validate-environment` に委譲）  | 責務を既存アクションに統一し、validate-env ユニットはリポジトリ構造の検証のみとする（旧 R-010 は欠番）                                                                                                         | R-011, R-012   | Active |

### 2.6 Related Decision Records

| DR-ID | Title                              | Phase | Impact on This Spec                   |
| ----- | ---------------------------------- | ----- | ------------------------------------- |
| DR-02 | パッケージマネージャーは pnpm 固定 | req   | install-packages ユニットの動作を規定 |
| DR-04 | PATH に追加するのは `bin/` のみ    | req   | add-path ユニットの副作用を限定       |
| DR-05 | `ref` は必須パラメータ             | req   | validate-inputs の必須チェックを規定  |

### 2.7 DD to DR Promotion Criteria

DD-01〜DD-05 は本仕様ローカルな決定であり、現状 DR 昇格の必要はない。
ただし DD-03（バージョン未指定の扱い）は変更時に影響範囲が広いため、
プロジェクト横断的な変更が生じた場合は DR 昇格を検討する。

---

## 3. Behavioral Specification

### 3.1 Input Domain

| Parameter      | Required | Format                                                            | Default |
| -------------- | -------- | ----------------------------------------------------------------- | ------- |
| `repo`         | Yes      | `<owner>/<repo>` 形式（英数字・ハイフン・アンダースコア・ドット） | —       |
| `path`         | Yes      | `./` で始まる相対パス。`..` セグメントを含まない                  | —       |
| `ref`          | Yes      | ブランチ名・タグ名・コミット SHA（非空文字列）                    | —       |
| `node-version` | No       | 任意の Node.js バージョン文字列（空文字 = 未指定）                | `""`    |
| `pnpm-version` | No       | 任意の pnpm バージョン文字列（空文字 = 未指定）                   | `""`    |

#### repo フォーマット規則

- `owner` 部: 英字始まり、英数字・ハイフン、最大 39 文字
- `repo` 部: 英数字・ハイフン・アンダースコア・ドット、最大 100 文字
- スラッシュはちょうど 1 つ

#### path フォーマット規則

- `./` で始まる相対パスのみ許可（例: `./tools/agla`）
- 絶対パス（`/` 始まり）は不可
- `..` セグメントを含んではならない
  - セグメント単位で判定: パスを `/` で分割し、いずれかのセグメントが `..` と等しい場合は不正
  - 例: `./foo/../bar`（不正）、`./foo..bar`（正当 — `..` はセグメント全体ではない）

### 3.2 Output Semantics

**成功時（exit 0）:**

- `<path>/bin`（`path` 入力のまま。`./` 始まりの相対パス）が `GITHUB_PATH` ファイルに追記されている
- 後続ステップの `PATH` に `<path>/bin` が含まれる
- 新規チェックアウト時は `<path>/.repo` に `<repo>@<ref>` が書き込まれ、`<path>/.repo.lock` は解放される

**失敗時（exit 非ゼロ）:**

- `::error::` プレフィックスのエラーメッセージが stderr に出力される
- `GITHUB_PATH` への書き込みは行われない
- 失敗したユニットの exit code が伝播する（exit 1 固定）

---

## 4. Decision Rules

評価は以下の順序で実行しなければならない。順序の変更は禁止する。

### Unit 1: validate-inputs

| Rule ID | Step | Condition                                                       | Outcome             |
| ------- | ---: | --------------------------------------------------------------- | ------------------- |
| R-001   |    1 | `repo` が `owner/repo` 形式でない                               | エラー出力 → exit 1 |
| R-002   |    2 | `path` が `./` で始まらない、またはパスセグメントに `..` を含む | エラー出力 → exit 1 |
| R-003   |    3 | `ref` が空文字列（空白のみを含む）                              | エラー出力 → exit 1 |
| R-004   |    4 | 全パラメータが有効                                              | Unit 2 へ進む       |

### Unit 2: check-existing-repo

`<path>` ディレクトリの存在と `.repo` ファイルを確認し、同一リポジトリの再利用またはコンフリクトを検出する。
`<path>/.repo.lock` をアトミックな `mkdir` で取得し（既に存在すれば exit 1）、`REPO_LOCK_DIR` を `GITHUB_ENV` に書き込む。ロックは Unit 8 の成功時に解放される。

| Rule ID | Step | Condition                                         | Outcome                         |
| ------- | ---: | ------------------------------------------------- | ------------------------------- |
| R-005   |    1 | `<path>` ディレクトリが存在しない                 | skip フラグ = false → Unit 3 へ |
| R-006   |    2 | `<path>` が存在するが `<path>/.repo` が存在しない | エラー出力 → exit 1             |
| R-007   |    3 | `<path>/.repo` の内容が入力 `repo` と一致する     | skip フラグ = true → Unit 3 へ  |
| R-008   |    4 | `<path>/.repo` の内容が入力 `repo` と異なる       | エラー出力 → exit 1             |

### Unit 3: checkout-repo

`actions/checkout` は skip フラグに関わらず実行される（`persist-credentials: false`）。

| Rule ID | Step | Condition                                  | Outcome                  |
| ------- | ---: | ------------------------------------------ | ------------------------ |
| R-021   |    1 | `actions/checkout` が成功                  | Unit 4 へ進む            |
| R-021E  |    1 | `actions/checkout` が失敗（repo 不存在等） | エラー伝播 → exit 非ゼロ |

### Unit 4: setup-environment

| Rule ID | Step | Condition                   | Outcome                                       |
| ------- | ---: | --------------------------- | --------------------------------------------- |
| R-022   |    1 | `pnpm-version` 未指定       | 空文字を渡し、`packageManager` の解決に委ねる |
| R-023   |    2 | `pnpm/action-setup` が成功  | 次ステップへ進む                              |
| R-023E  |    2 | `pnpm/action-setup` が失敗  | エラー伝播 → exit 非ゼロ                      |
| R-024   |    3 | `node-version` 未指定       | 空文字を渡し、バージョンを明示しない          |
| R-025   |    4 | `actions/setup-node` が成功 | Unit 5 へ進む（`cache: "pnpm"` を有効化）     |
| R-025E  |    4 | `actions/setup-node` が失敗 | エラー伝播 → exit 非ゼロ                      |

### Unit 5: validate-env

checkout 完了後にリポジトリ構造を検証する。skip フラグ = true の場合、Unit 5 と Unit 6 はスキップされる。
ランナー OS の確認は行わない（DD-07。R-010 は欠番）。

| Rule ID | Step | Condition                              | Outcome             |
| ------- | ---: | -------------------------------------- | ------------------- |
| R-011   |    1 | `<path>/pnpm-lock.yaml` が存在しない   | エラー出力 → exit 1 |
| R-012   |    2 | `<path>/bin/` ディレクトリが存在しない | エラー出力 → exit 1 |
| R-013   |    3 | 全構造検証通過                         | Unit 6 へ進む       |

### Unit 6: install-packages

| Rule ID | Step | Condition                               | Outcome                  |
| ------- | ---: | --------------------------------------- | ------------------------ |
| R-014   |    1 | `pnpm install --frozen-lockfile` が成功 | Unit 7 へ進む            |
| R-014E  |    1 | `pnpm install --frozen-lockfile` が失敗 | エラー伝播 → exit 非ゼロ |

### Unit 7: verify-install

候補ファイルは `<path>/bin/` 直下の通常ファイルのうち、拡張子なしまたは `.sh` のもの（シンボリックリンクは辿る）。

| Rule ID | Step | Condition                                    | Outcome                       |
| ------- | ---: | -------------------------------------------- | ----------------------------- |
| R-015   |    1 | `<path>/node_modules/.bin/` が存在しない     | エラー出力 → exit 1           |
| R-016   |    2 | `<path>/bin/` 配下に候補ファイルが存在しない | エラー出力 → exit 1           |
| R-017   |    3 | 候補ファイルに shebang あり・実行権限なし    | `chmod +x` を自動適用して続行 |
| R-017E  |    3 | 候補ファイルに shebang なし・実行権限なし    | エラー出力 → exit 1           |
| R-018   |    4 | 全検証通過                                   | Unit 8 へ進む                 |

### Unit 8: add-path

全ステップが成功した後、PATH を追加し `.repo` ファイルを作成して、ロックを解放する。

| Rule ID | Step | Condition                                                        | Outcome             |
| ------- | ---: | ---------------------------------------------------------------- | ------------------- |
| R-019   |    1 | `<path>/bin`（`path` 入力のまま）を `GITHUB_PATH` に追記         | 次ステップへ進む    |
| R-019E  |    1 | `GITHUB_PATH` への追記が失敗                                     | エラー出力 → exit 1 |
| R-020   |    2 | skip フラグ = false: `<path>/.repo` に `<repo>@<ref>` を書き込む | ロック解放 → exit 0 |
| R-020S  |    2 | skip フラグ = true: `.repo` の書き込みをスキップ                 | ロック解放 → exit 0 |
| R-020E  |    2 | `.repo` ファイルの書き込みが失敗                                 | エラー出力 → exit 1 |

---

## 5. Edge Cases

| Input / Situation                              | Outcome            | Rule  | Rationale                                                  |
| ---------------------------------------------- | ------------------ | ----- | ---------------------------------------------------------- |
| `repo="agla-doc-tools"`（スラッシュなし）      | exit 1             | R-001 | owner/repo 形式のみ許可                                    |
| `repo="owner/repo/extra"`（スラッシュ複数）    | exit 1             | R-001 | スラッシュはちょうど 1 つ                                  |
| `path="tools/agla"`（`./` なし）               | exit 1             | R-002 | `./` で始まる相対パスのみ許可                              |
| `path="/tmp/tools"`（絶対パス）                | exit 1             | R-002 | 絶対パスは不可、`./` 始まりのみ                            |
| `path="./foo/../bar"`（`..` セグメントを含む） | exit 1             | R-002 | パストラバーサル防止（セグメント単位で判定）               |
| `path="./foo..bar"`（`..` がセグメント内部）   | 続行               | R-002 | セグメント全体が `..` でないため正当                       |
| `path="../outside"`（`..` 始まり）             | exit 1             | R-002 | `./` で始まらない形式                                      |
| `ref=""`（空文字列）                           | exit 1             | R-003 | ref は必須                                                 |
| `ref="  "`（空白のみ）                         | exit 1             | R-003 | 空白のみは空文字列と同等                                   |
| `pnpm-lock.yaml` が存在しない                  | exit 1             | R-011 | pnpm リポジトリのみ対応                                    |
| checkout 後に `bin/` が存在しない              | exit 1             | R-012 | validate-env でリポジトリ構造を確認                        |
| `node_modules/.bin/` が空ディレクトリ          | 続行               | R-015 | ディレクトリ存在のみ確認（内容は verify-install の責務外） |
| `bin/` が空ディレクトリ                        | exit 1             | R-016 | 実行可能ファイルが存在しない                               |
| `bin/` 配下にシンボリックリンクのみ存在        | 続行（条件付き）   | R-017 | リンク先の shebang を確認し、あれば `chmod +x` を自動適用  |
| `bin/` 配下が `.sh` 以外の拡張子付きのみ       | exit 1             | R-016 | 候補は拡張子なしまたは `.sh` のファイルのみ                |
| `path` が存在し `.repo` がない                 | exit 1             | R-006 | 管理外ディレクトリとみなして失敗                           |
| `path` が存在し `.repo` が同一 repo            | スキップ（exit 0） | R-007 | 再チェックアウト不要                                       |
| `path` が存在し `.repo` が別 repo              | exit 1             | R-008 | repo コンフリクト                                          |
| `path` が存在しない（新規）                    | 通常フロー         | R-005 | 新規チェックアウト                                         |

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule(s)                             | Notes                                              |
| -------------- | ---------------------------------------- | -------------------------------------------------- |
| REQ-F-001      | R-001, R-002, R-003, R-005〜R-008, R-021 | バリデーション・既存チェック・チェックアウトを含む |
| REQ-F-002      | R-014                                    | pnpm install --frozen-lockfile                     |
| REQ-F-003      | R-015, R-016, R-017, R-018               | post-install 3項目検証                             |
| REQ-F-004      | R-019, R-020                             | bin/ を GITHUB_PATH に追記、.repo ファイル作成     |
| REQ-F-005      | R-022〜R-025                             | Node.js / pnpm セットアップ                        |
| REQ-NF-001     | R-014（--frozen-lockfile）               | 再現性のあるインストール                           |
| REQ-NF-002     | —                                        | action.yml の permissions 定義で対応               |
| REQ-NF-003     | 全 E 系ルール                            | 各ユニット失敗時の即時終了                         |
| REQ-NF-004     | —                                        | double-source guard・戻り値規約に準拠              |
| REQ-C-001      | —                                        | ランナー検証は ca-validate-environment に委譲      |
| REQ-C-002      | —                                        | token 入力パラメータを持たない                     |
| REQ-C-003      | R-012                                    | validate-env で bin/存在を確認                     |
| REQ-C-004      | R-011                                    | validate-env で pnpm-lock.yaml 存在を確認          |
| REQ-C-005      | R-001                                    | repo の owner/repo 形式検証                        |
| REQ-C-006      | R-002                                    | path の ./始まり・.. セグメント禁止                |

<!-- impl-note:
  validate-inputs の repo フォーマット検証は .github/actions/_libs/validation.lib.sh の validate_repo() を再利用できる。
  path の .. チェックは validate_symbol() では困難なため、個別のパターンマッチで実装すること。 -->

---

## 7. Open Questions

> **Status**: COMPLETE

| # | Question                                                                          | Source     | Impact                                                    |
| - | --------------------------------------------------------------------------------- | ---------- | --------------------------------------------------------- |
| 1 | OQ-004: pnpm ストアのキャッシュ提供 → **Closed**（setup-node の `cache: "pnpm"`） | REQ OQ-004 | setup-environment ユニットで `cache: "pnpm"` を有効化済み |

---

## 8. Change History

| Date       | Version | Description                                                                                                                                                                |
| ---------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-06-18 | 1.0.0   | Initial specification                                                                                                                                                      |
| 2026-06-18 | 1.0.1   | Codex review 反映: validate-env ユニット追加、path を相対パス限定、.. セグメント判定明確化                                                                                 |
| 2026-06-18 | 1.0.2   | check-existing-repo ユニット追加、.repo ファイル作成を add-path の最終ステップに追加                                                                                       |
| 2026-10-27 | 1.1.0   | DD-03 変更: 既定値を Node.js `"24"`・pnpm `"12.15.0"` に更新 (packageManager と一致)                                                                                       |
| 2026-11-18 | 1.2.0   | DD-03 変更: Node.js・pnpm の既定値を廃止 (空文字 = 未指定)。R-009/R-010・入力表を更新                                                                                      |
| 2026-11-19 | 1.3.0   | ca-setup-repo の現行実装に整合: 実行順 checkout→pnpm→node、ルール ID 重複解消（R-021〜R-025 新設、R-010 欠番）、R-017E 追加、bin/PATH・.repo の書式を修正、OQ-004 クローズ |
