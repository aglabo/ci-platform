---
title: "Implementation Plan: setup-tool-repo Composite Action"
based-on: specifications.md v1.0.2
status: Draft
version: 1.0.5
created: "2026-06-18"
---

<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/no-exclamation-question-mark -->
<!-- markdownlint-disable line-length -->

## 1. Overview

### 1.1 Purpose

`setup-tool-repo` コンポジットアクションを実装する。
`action.yml` と 4 本の bash スクリプトライブラリで構成し、
仕様書（specifications.md v1.0.2）で定義した 7 ユニットの振る舞いを実現する。

### 1.2 Reference

- Prior Art: `.github/actions/setup-tool/`（同一リポジトリの参考実装）
- Shared libs: `.github/actions/_libs/validation.lib.sh`（`validate_repo()` 再利用）
- Specifications: `docs/.deckrd/composite-action/setup-tool-repo/specifications/specifications.md`

### 1.3 Implementation Units → Files

| Spec Unit                 | 実装場所                                       |
| ------------------------- | ---------------------------------------------- |
| validate-inputs           | `scripts/_libs/validate-inputs.lib.sh`         |
| check-existing-repo       | `scripts/_libs/check-existing.lib.sh`          |
| setup-environment         | `action.yml`（uses: ステップ直書き）           |
| checkout-repo             | `action.yml`（uses: ステップ直書き）           |
| validate-repo-structure   | `scripts/_libs/validate-repo-structure.lib.sh` |
| install-packages          | `action.yml`（run: ステップ直書き）            |
| verify-install + add-path | `scripts/_libs/verify-and-add-path.lib.sh`     |

### 1.4 Directory Structure

```text
.github/actions/setup-tool-repo/
├── action.yml
└── scripts/
    ├── _libs/
    │   ├── validate-inputs.lib.sh
    │   ├── check-existing.lib.sh
    │   ├── validate-repo-structure.lib.sh
    │   └── verify-and-add-path.lib.sh
    └── __tests__/
        ├── unit/
        │   ├── validate-inputs.unit.spec.sh
        │   ├── check-existing.unit.spec.sh
        │   ├── validate-repo-structure.unit.spec.sh
        │   └── verify-and-add-path.unit.spec.sh
        └── integration/
            └── setup-tool-repo.integration.spec.sh
```

---

## 2. Implementation Plan

### Phase 1: Foundation — action.yml + 入力検証

#### Commit 1: feat(setup-tool-repo): add action.yml skeleton with inputs

- `.github/actions/setup-tool-repo/action.yml` を新規作成
- `inputs:` に `repo`（required）/ `path`（required）/ `ref`（required）/ `node-version`（default: `"22"`）/ `pnpm-version`（default: `"10"`）を定義
- `permissions:` は**宣言しない**（コンポジットアクションでは宣言不可。呼び出し元 job で `contents: read` を設定する旨をコメントで明記）
- `runs.using: composite`、ステップは空（後続フェーズで追加）

#### Commit 2: feat(setup-tool-repo): add validate-inputs.lib.sh

- `scripts/_libs/validate-inputs.lib.sh` を新規作成
- `validate_repo()` 再利用（`.github/actions/_libs/validation.lib.sh`）で `repo` を検証
- `path` の `./` 始まりチェック + セグメント単位の `..` 禁止チェック（R-002）
- `ref` の非空・非空白チェック（R-003）
- 失敗時は `::error::` フォーマットで stderr に出力し exit 1

#### Commit 3: test(setup-tool-repo): add unit tests for validate-inputs

- `scripts/__tests__/unit/validate-inputs.unit.spec.sh` を新規作成
- 正常系: 有効な `repo`/`path`/`ref` ですべて pass
- 異常系（R-001）: `repo` が `owner/repo` 形式でない → exit 1
- 異常系（R-002）: `path` が `./` 始まりでない → exit 1
- 異常系（R-002）: `path` に `..` セグメントを含む → exit 1
- 異常系（R-002）: `path` が絶対パス → exit 1
- 異常系（R-003）: `ref` が空文字列・空白のみ → exit 1
- エッジケース: `./foo..bar`（`..` はセグメント内部）→ pass

---

### Phase 2: 既存チェックアウト検証

#### Commit 4: feat(setup-tool-repo): add check-existing.lib.sh

- `scripts/_libs/check-existing.lib.sh` を新規作成
- `.repo` ファイルの形式: `<owner>/<repo>@<commit-sha>`
- **ロック取得**（処理の最初に実行）:
  - `<path>` が存在しない場合は `mkdir -p <path>` してからロック取得
  - `mkdir "<path>/.repo.lock"` でアトミックにロックを取得（R-005 前処理）
  - 取得失敗（同一 `path` で別プロセスが実行中）: `::error::` 出力 → exit 1
  - ロックディレクトリパスを `REPO_LOCK_DIR=<path>/.repo.lock` として `GITHUB_ENV` に書き込み（`verify-and-add-path.sh` が解放するため）
- `<path>` ディレクトリが存在しない場合（新規）: skip フラグ = false を `GITHUB_OUTPUT` に書き込み（R-005）
- `<path>` が存在するが `<path>/.repo` がない場合: exit 1（R-006）
- `.repo` から `<owner>/<repo>` 部分を抽出し、入力 `repo` と比較（R-007/R-008）
  - 一致: skip フラグ = true を `GITHUB_OUTPUT` に書き込み（R-007）
  - 不一致: exit 1（R-008）
- `GITHUB_OUTPUT`/`GITHUB_ENV` は未設定時 `:?` でエラーにする（HARDEN-01）

#### Commit 5: test(setup-tool-repo): add unit tests for check-existing

- `scripts/__tests__/unit/check-existing.unit.spec.sh` を新規作成
- `BeforeEach` で `GITHUB_OUTPUT`・`GITHUB_ENV` を `mktemp` で生成したファイルに設定（`:?` 検証を通過させるため）
- `AfterEach` で一時ファイルを削除
- 正常系（R-005）: `<path>` 不存在 → ロック取得、`skip=false` を出力、`GITHUB_ENV` に `REPO_LOCK_DIR` が書き込まれる
- 正常系（R-007）: `.repo` が `owner/repo@<sha>` 形式で同一 repo → ロック取得、`skip=true` を出力
- 異常系（R-006）: `<path>` 存在するが `.repo` なし → ロック取得後に exit 1
- 異常系（R-008）: `.repo` の repo 部分が別 repo → ロック取得後に exit 1
- 異常系（ロック競合）: `<path>/.repo.lock` が既に存在する → ロック取得失敗 → exit 1

---

### Phase 3: リポジトリ構造検証 + インストール後検証

#### Commit 6: feat(setup-tool-repo): add validate-repo-structure.lib.sh

- `scripts/_libs/validate-repo-structure.lib.sh` を新規作成
- `<path>/pnpm-lock.yaml` の存在確認（R-011）→ 不存在で exit 1
- `<path>/bin/` ディレクトリの存在確認（R-012）→ 不存在で exit 1
- 注意:
  skip フラグの処理は不要。`action.yml` の `if: steps.check-existing-repo.outputs.skip != 'true'` 条件でステップごとスキップされるため、
  このスクリプト自体は常に検証のみを行う

#### Commit 7: test(setup-tool-repo): add unit tests for validate-repo-structure

- `scripts/__tests__/unit/validate-repo-structure.unit.spec.sh` を新規作成
- 正常系: `pnpm-lock.yaml` + `bin/` 両方存在 → pass
- 異常系（R-011）: `pnpm-lock.yaml` なし → exit 1
- 異常系（R-012）: `bin/` なし → exit 1

#### Commit 8: feat(setup-tool-repo): add verify-and-add-path.lib.sh

- `scripts/_libs/verify-and-add-path.lib.sh` を新規作成
- `<path>/node_modules/.bin/` 存在確認（R-015）→ 不存在で exit 1
- `<path>/bin/` 配下ファイル存在確認（R-016）→ なければ exit 1
- `<path>/bin/` 配下ファイルの実行権限確認（R-017）→ shebang（`#!`）があれば自動で `chmod +x`、それでも実行ビットがなければ exit 1
- `<path>/bin/` の絶対パスを `echo >> "${GITHUB_PATH:?GITHUB_PATH is not set}"` で追記（R-019）
- skip フラグ = false の場合: `git -C <path> rev-parse HEAD` で commit SHA を解決し、`<owner>/<repo>@<commit-sha>` 形式で `<path>/.repo` に書き込み（R-020、**HARDEN-04**: `mktemp` + `mv` で原子的に書き込む）
- skip フラグ = true の場合: `.repo` 書き込みをスキップ（R-020S）
- **ロック解放**（処理の最後に必ず実行）:
  - `GITHUB_ENV` から `REPO_LOCK_DIR` を読み取り `rmdir "${REPO_LOCK_DIR}"` でロック解放
  - `REPO_LOCK_DIR` が未設定または存在しない場合は無視（`|| true`）

#### Commit 9: test(setup-tool-repo): add unit tests for verify-and-add-path

- `scripts/__tests__/unit/verify-and-add-path.unit.spec.sh` を新規作成
- 正常系（skip=false）: 全検証通過、`GITHUB_PATH` 追記、`.repo` に `owner/repo@<sha>` 形式で書き込み、ロック解放（`.repo.lock` が削除される）
- 正常系（skip=true）: 全検証通過、`GITHUB_PATH` 追記、`.repo` 書き込みスキップ、ロック解放
- 異常系（R-015）: `node_modules/.bin/` なし → exit 1（ロックは解放されない — 後続の再試行を防ぐ）
- 異常系（R-016）: `bin/` 空ディレクトリ → exit 1
- 異常系（R-017）: `bin/` 配下ファイルに shebang なし・実行権限なし → exit 1
- 自動修復（R-017）: shebang あり・実行権限なし（Windows 環境等）→ `chmod +x` を自動適用してチェック通過（symlink はリンク先を読んで判定）

---

### Phase 4: 統合 — action.yml のステップ結合

#### Commit 10: feat(setup-tool-repo): wire up action.yml steps

- `action.yml` に以下のステップを順序通り追加:
  1. `validate-inputs` — `run: bash "${{ github.action_path }}/scripts/_libs/validate-inputs.lib.sh"` + env
  2. `check-existing-repo` — `run: bash "${{ github.action_path }}/scripts/_libs/check-existing.lib.sh"` + env、`id:` を付与
  3. `actions/setup-node` — `uses:` + `with: node-version: ${{ inputs.node-version }}`
  4. `pnpm/action-setup` — `uses:` + `with: version: ${{ inputs.pnpm-version }}`
  5. `actions/checkout` — `uses:` + `with: repository/path/ref` を inputs から渡す
  6. `validate-repo-structure` — `run: bash` + env + `if: steps.check-existing-repo.outputs.skip != 'true'`
  7. `pnpm install --frozen-lockfile` — `run: pnpm install --frozen-lockfile` + `working-directory` + `if: steps.check-existing-repo.outputs.skip != 'true'`
  8. `verify-and-add-path` — `run: bash` + env（`SKIP_REPO` / `REPO` / `PATH_DIR`）
- 各外部アクションはコミット SHA でピン留め（`# vX.Y.Z` コメント付き）

#### Commit 11: test(setup-tool-repo): add integration test for action.yml

- `scripts/__tests__/integration/setup-tool-repo.integration.spec.sh` を新規作成
- 正常系: 全スクリプトが連続して pass する統合確認（モック環境）
- 異常系: `validate-inputs` 失敗時に後続スクリプトが呼ばれないことを確認
- 異常系: `check-existing` で repo コンフリクト時に exit 1

#### Commit 12: ci(setup-tool-repo): add actionlint and ghalint validation

- `actionlint -config-file ./configs/actionlint.yaml .github/actions/setup-tool-repo/action.yml` が通ることを確認
- `ghalint run --config ./configs/ghalint.yaml` が通ることを確認
- 検証エラーがあれば `action.yml` を修正する

---

## 3. Technical Notes

### ライブラリ規約（既存 setup-tool に準拠）

- `set -euo pipefail` をすべてのスクリプトおよびライブラリ（`_libs/*.lib.sh`）の先頭に**必ず**記載する（HARDEN-03）
- double-source guard（`[ -n "${LIB_LOADED:-}" ] && return 0`）
- エラー出力: `echo "::error::<message>" >&2`
- 正常出力: `echo "✓ <message>"`

### GITHUB_PATH / GITHUB_OUTPUT への書き込み（HARDEN-01）

`GITHUB_OUTPUT` および `GITHUB_PATH` への書き込みを行うすべてのスクリプトは、
書き込み前に `:?` 演算子で未設定チェックを**必ず**実施しなければならない。
`:-/dev/null` フォールバックは**使用禁止**とする。

```bash
echo "<path>/bin" >> "${GITHUB_PATH:?GITHUB_PATH is not set}"
echo "skip=true" >> "${GITHUB_OUTPUT:?GITHUB_OUTPUT is not set}"
```

対象スクリプト:

- `check-existing.lib.sh`（`GITHUB_OUTPUT` に skip フラグ、`GITHUB_ENV` に `REPO_LOCK_DIR` を書き込む）
- `verify-and-add-path.lib.sh`（`GITHUB_PATH` に `${PATH_DIR}/bin/` を追記する）

**テスト環境での対応（HARDEN-01）**: ShellSpec ユニットテストでは `GITHUB_OUTPUT`・`GITHUB_PATH` が未設定のため、
`BeforeEach` で `mktemp` を使って一時ファイルを作成しこれらの変数に設定する。

```bash
BeforeEach '
  _tmp_output=$(mktemp)
  _tmp_path=$(mktemp)
  _tmp_env=$(mktemp)
  export GITHUB_OUTPUT="$_tmp_output"
  export GITHUB_PATH="$_tmp_path"
  export GITHUB_ENV="$_tmp_env"
'
AfterEach 'rm -f "$_tmp_output" "$_tmp_path" "$_tmp_env"'
```

### .repo ファイル形式

```bash
<owner>/<repo>@<commit-sha>
```

- `<commit-sha>`: `git -C <path> rev-parse HEAD` で取得した 40 文字の SHA
- `check-existing.sh` は `@` より前の部分（`<owner>/<repo>`）のみを入力 `repo` と比較する
- `verify-and-add-path.sh` が全ステップ成功後に書き込む（skip=true の場合はスキップ）

**書き込みは原子的に行わなければならない（HARDEN-04）**:
`echo` による直接書き込みは禁止。`mktemp` で一時ファイルに書き込み、`mv` でアトミックに置換する。

```bash
_tmp=$(mktemp)
echo "${REPO}@${_sha}" > "$_tmp"
mv "$_tmp" "${PATH_DIR}/.repo"
```

### 外部アクションのピン留め（HARDEN-02）

`action.yml` で使用するすべての外部アクションは、バージョンタグではなく**コミット SHA でピン留めしなければならない**。
バージョンタグのみ（例: `@v4`）の参照は禁止する。

```yaml
# 正しい例
uses: actions/setup-node@6044e13b5dc448c55e2357c09f80417699197238 # v6.2.0
uses: pnpm/action-setup@41ff72655975bd51cab0327fa583b6e92b6d3061 # v4.2.0

# 禁止例
uses: actions/setup-node@v6
```

適用対象: `actions/setup-node`、`pnpm/action-setup`、`actions/checkout`

### 楽観的ロック設計

同一 `path` への並列実行を防ぐため、`check-existing.sh` 開始時に `mkdir` によるディレクトリロックを取得する。

```text
check-existing.sh
  mkdir <path>/.repo.lock   ← アトミック取得（失敗なら exit 1）
  echo "REPO_LOCK_DIR=..." >> $GITHUB_ENV   ← verify-and-add-path.sh に引き継ぎ
  [.repo 確認 → skip フラグ出力]

[中間ステップ: setup-node / pnpm / checkout / validate / install]

verify-and-add-path.sh
  [検証 → GITHUB_PATH 追記 → .repo 書き込み]
  rmdir "${REPO_LOCK_DIR}"   ← ロック解放
```

**ロックが解放されないケース**: `verify-and-add-path.sh` が失敗した場合、`.repo.lock` は残存する。
これは意図的な設計であり、壊れた状態の `path` への後続アクセスを防ぐ。
手動復旧が必要な場合は `rmdir <path>/.repo.lock` を実行する。

### skip フラグの伝播

`check-existing.lib.sh` が `GITHUB_OUTPUT` に `skip=true/false` を書き込み、
`action.yml` の後続ステップが `if: steps.check-existing-repo.outputs.skip != 'true'` で参照する。

---

## 4. Change History

| Date       | Version | Description                                                                                                                                                 |
| ---------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-06-18 | 1.0.0   | Initial implementation plan                                                                                                                                 |
| 2026-06-18 | 1.0.1   | Codex review 反映: .repo を owner/repo@sha 形式に変更、permissions削除、GITHUB_OUTPUT/PATH の :? 検証に変更                                                 |
| 2026-06-18 | 1.0.2   | review explore 反映: Commit 5 に GITHUB_OUTPUT モック設定を追記、Commit 6 に skip フラグ不要の注記追加、Commit 12 を actionlint/ghalint 検証に変更          |
| 2026-06-18 | 1.0.3   | review harden 反映: HARDEN-01〜04 を SHALL として昇格（:? 検証必須、SHA ピン留め必須、set -euo pipefail 全ライブラリ必須、.repo 原子的書き込み必須）        |
| 2026-06-18 | 1.0.4   | 楽観的ロック設計追加: check-existing.sh で mkdir によるロック取得、GITHUB_ENV 経由で verify-and-add-path.sh にロック解放を委譲                              |
| 2026-06-18 | 1.0.5   | review fix: Commit タイトルのファイル名を .lib.sh に統一、HARDEN-01 対象に GITHUB_ENV 追加、Commit 5/Technical Notes の BeforeEach に GITHUB_ENV モック追加 |
