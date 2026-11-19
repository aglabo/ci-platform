---
title: "Implementation Plan: setup-tool-repo Composite Action (ca-setup-repo)"
based-on: specifications.md v1.3.0
status: Draft
version: 1.2.1
created: "2026-06-18"
---

<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/no-exclamation-question-mark -->
<!-- markdownlint-disable line-length -->

**Note**: 実装ディレクトリは `.github/actions/ca-setup-repo/`（旧称 `setup-tool-repo`）。Commit 見出しの `setup-tool-repo` は当時の scope 名を示す。

## 1. Overview

### 1.1 Purpose

`setup-tool-repo` コンポジットアクションを実装する。
`action.yml` と 4 本の bash スクリプトライブラリで構成し、
仕様書（specifications.md v1.3.0）で定義した 8 ユニットの振る舞いを実現する。

### 1.2 Reference

- Prior Art: `.github/actions/ca-setup-tool/`（同一リポジトリの参考実装）
- Shared libs: `.github/actions/_libs/validation.lib.sh`（`validate_repo()` 再利用）
- Specifications: `docs/.deckrd/composite-action/setup-tool-repo/specifications/specifications.md`

### 1.3 Implementation Units → Files

| Spec Unit                 | 実装場所                                                  |
| ------------------------- | --------------------------------------------------------- |
| validate-inputs           | `scripts/_libs/validate-inputs.lib.sh`                    |
| check-existing-repo       | `scripts/_libs/check-existing.lib.sh`                     |
| checkout-repo             | `action.yml`（uses: ステップ直書き）                      |
| setup-environment         | `action.yml`（uses: ステップ直書き、pnpm → Node.js の順） |
| validate-repo-structure   | `scripts/_libs/validate-repo-structure.lib.sh`            |
| install-packages          | `action.yml`（run: ステップ直書き）                       |
| verify-install + add-path | `scripts/_libs/verify-and-add-path.lib.sh`                |

### 1.4 Directory Structure

```text
.github/actions/ca-setup-repo/
├── action.yml
└── scripts/
    ├── _libs/
    │   ├── validate-inputs.lib.sh
    │   ├── check-existing.lib.sh
    │   ├── validate-repo-structure.lib.sh
    │   ├── verify-and-add-path.lib.sh
    │   └── __tests__/
    │       └── unit/
    │           ├── validate-inputs.unit.spec.sh
    │           ├── check-existing.unit.spec.sh
    │           ├── validate-repo-structure.unit.spec.sh
    │           └── verify-and-add-path.unit.spec.sh
    └── __tests__/
        └── integration/
            └── setup-repo.integration.spec.sh
```

---

## 2. Implementation Plan

### Phase 1: Foundation — action.yml + 入力検証

#### Commit 1: feat(setup-tool-repo): add action.yml skeleton with inputs

- `.github/actions/ca-setup-repo/action.yml` を新規作成
- `inputs:` に `repo`（required）/`path`（required）/`ref`（required）/`node-version`（default: `""`）/`pnpm-version`（default: `""`）を定義（空文字 = バージョン未指定）
- `permissions:` は **宣言しない**（コンポジットアクションでは宣言不可。呼び出し元 job で `contents: read` を設定する旨をコメントで明記）
- `runs.using: composite`、ステップは空（後続フェーズで追加）

#### Commit 2: feat(setup-tool-repo): add validate-inputs.lib.sh

- `scripts/_libs/validate-inputs.lib.sh` を新規作成
- `validate_repo()` 再利用（`.github/actions/_libs/validation.lib.sh`）で `repo` を検証
- `path` の `./` 始まりチェック + セグメント単位の `..` 禁止チェック（R-002）
- `ref` の非空・非空白チェック（R-003）
- 失敗時は `::error::` フォーマットで stderr に出力し exit 1

#### Commit 3: test(setup-tool-repo): add unit tests for validate-inputs

- `scripts/_libs/__tests__/unit/validate-inputs.unit.spec.sh` を新規作成
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
- `.repo` ファイルの形式: `<owner>/<repo>@<ref>`（`ref` は入力値）
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
- `GITHUB_OUTPUT`/`GITHUB_ENV` へは `"${GITHUB_OUTPUT}"` / `"${GITHUB_ENV}"` に追記する（未設定チェックは行わない。GitHub Actions 上では常に設定される）

#### Commit 5: test(setup-tool-repo): add unit tests for check-existing

- `scripts/_libs/__tests__/unit/check-existing.unit.spec.sh` を新規作成
- `BeforeEach` で `GITHUB_OUTPUT`・`GITHUB_ENV` を `mktemp` で生成したファイルに設定（実環境の出力ファイルを汚さないため）
- `AfterEach` で一時ファイルを削除
- 正常系（R-005）: `<path>` 不存在 → ロック取得、`skip=false` を出力、`GITHUB_ENV` に `REPO_LOCK_DIR` が書き込まれる
- 正常系（R-007）: `.repo` が `owner/repo@<ref>` 形式で同一 repo → ロック取得、`skip=true` を出力
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

- `scripts/_libs/__tests__/unit/validate-repo-structure.unit.spec.sh` を新規作成
- 正常系: `pnpm-lock.yaml` + `bin/` 両方存在 → pass
- 異常系（R-011）: `pnpm-lock.yaml` なし → exit 1
- 異常系（R-012）: `bin/` なし → exit 1

#### Commit 8: feat(setup-tool-repo): add verify-and-add-path.lib.sh

- `scripts/_libs/verify-and-add-path.lib.sh` を新規作成
- `<path>/node_modules/.bin/` 存在確認（R-015）→ 不存在で exit 1
- `<path>/bin/` 配下の候補ファイル（拡張子なし、または `.sh`。`find -L -maxdepth 1 -type f` を正規表現で絞る）の存在確認（R-016）→ なければ exit 1
- 候補ファイルの実行権限確認（R-017）→ shebang（`#!`）があれば自動で `chmod +x`、それでも実行ビットがなければ exit 1
- `<path>/bin`（`path` 入力のまま）を `echo "${_path}/bin" >> "${GITHUB_PATH}"` で追記（R-019）
- skip フラグ = false（`SKIP_REPO` が `true` 以外）の場合: `printf '%s@%s' "${_repo}" "${_ref}" > "${_path}/.repo"` で `<owner>/<repo>@<ref>` を書き込み（R-020。原子的書き込みは行わない）
- skip フラグ = true の場合: `.repo` 書き込みをスキップ（R-020S）
- **ロック解放**（処理の最後に実行）:
  - 環境変数 `REPO_LOCK_DIR`（`check-existing` が `GITHUB_ENV` に書き込んだもの）が設定されていれば `rm -rf "${REPO_LOCK_DIR}"` でロック解放
  - `REPO_LOCK_DIR` が未設定の場合は何もしない

#### Commit 9: test(setup-tool-repo): add unit tests for verify-and-add-path

- `scripts/_libs/__tests__/unit/verify-and-add-path.unit.spec.sh` を新規作成
- 正常系（skip=false）: 全検証通過、`GITHUB_PATH` 追記、`.repo` に `owner/repo@<ref>` 形式で書き込み、ロック解放（`.repo.lock` が削除される）
- 正常系（skip=true）: 全検証通過、`GITHUB_PATH` 追記、`.repo` 書き込みスキップ、ロック解放
- 異常系（R-015）: `node_modules/.bin/` なし → exit 1（ロックは解放されない — 後続の再試行を防ぐ）
- 異常系（R-016）: `bin/` 空ディレクトリ（または候補ファイルなし）→ exit 1
- 異常系（R-017）: `bin/` 配下ファイルに shebang なし・実行権限なし → exit 1
- 自動修復（R-017）: shebang あり・実行権限なし（Windows 環境等）→ `chmod +x` を自動適用してチェック通過（symlink はリンク先を読んで判定）

---

### Phase 4: 統合 — action.yml のステップ結合

#### Commit 10: feat(setup-tool-repo): wire up action.yml steps

- `action.yml` に以下のステップを順序通り追加:
  1. `validate-inputs` — `run:` でライブラリを `.` で読み込み、`validate_inputs "${REPO}" "${PATH_DIR}" "${REF}"` を呼ぶ（env: `REPO`/`PATH_DIR`/`REF`）
  2. `check-existing-repo` — `run:` で `check_existing "${REPO}" "${PATH_DIR}"` を呼ぶ、`id:` を付与
  3. `checkout-repo` — `actions/checkout`（`repository`/`path`/`ref` を inputs から渡す、`persist-credentials: false`）。skip フラグに関わらず実行
  4. `setup-pnpm` — `pnpm/action-setup` + `with: version: ${{ inputs.pnpm-version }}`
  5. `setup-node` — `actions/setup-node` + `with: node-version: ${{ inputs.node-version }}`、`cache: "pnpm"`、`cache-dependency-path: ${{ inputs.path }}/pnpm-lock.yaml`
  6. `validate-repo-structure` — `run:` で `validate_repo_structure "${PATH_DIR}"` + `if: steps.check-existing-repo.outputs.skip != 'true'`
  7. `install-packages` — `run: pnpm install --frozen-lockfile` + `working-directory` + `if: steps.check-existing-repo.outputs.skip != 'true'`
  8. `verify-and-add-path` — `run:` で `verify_and_add_path "${PATH_DIR}" "${REPO}" "${REF}"`（env: `REPO`/`PATH_DIR`/`REF`/`SKIP_REPO`）
- 各外部アクションはコミット SHA でピン留め（`# vX.Y.Z` コメント付き）

#### Commit 11: test(setup-tool-repo): add integration test for action.yml

- `scripts/__tests__/integration/setup-repo.integration.spec.sh` を新規作成
- 正常系: 全スクリプトが連続して pass する統合確認（モック環境）
- 異常系: `validate-inputs` 失敗時に後続スクリプトが呼ばれないことを確認
- 異常系: `check-existing` で repo コンフリクト時に exit 1

#### Commit 12: ci(setup-tool-repo): add actionlint and ghalint validation

- `pnpm run lint:gha:actions .github/actions/ca-setup-repo/action.yml`（jactionlint）が通ることを確認
- `pnpm run lint:gha:workflows`（ghalint）が通ることを確認
- 検証エラーがあれば `action.yml` を修正する

---

## 3. Technical Notes

### ライブラリ規約（ca-setup-tool に準拠）

- ライブラリ（`_libs/*.lib.sh`）は `set -euo pipefail` を設定しない。`source` した呼び出し元シェルの設定を変えないため、各関数が戻り値（0 / 1）で結果を返す（HARDEN-03 は撤回）
- double-source guard（`[ -n "${LIB_LOADED:-}" ] && return 0`）
- エラー出力: `echo "::error::<message>" >&2`
- 正常出力: `echo "✓ <message>"`

### GITHUB_PATH / GITHUB_OUTPUT への書き込み（HARDEN-01）

`GITHUB_OUTPUT`・`GITHUB_ENV`・`GITHUB_PATH` への書き込みは、`${VAR}` を直接参照して追記する。
`:-/dev/null` フォールバックは **使用禁止** とする。
`:?` による未設定チェックは行わない（GitHub Actions 上では常に設定される。未設定時の書き込みはシェルの
リダイレクトエラーで失敗する）。

```bash
echo "${_path}/bin" >> "${GITHUB_PATH}"
echo "skip=true" >> "${GITHUB_OUTPUT}"
```

対象スクリプト:

- `check-existing.lib.sh`（`GITHUB_OUTPUT` に skip フラグ、`GITHUB_ENV` に `REPO_LOCK_DIR` を書き込む）
- `verify-and-add-path.lib.sh`（`GITHUB_PATH` に `${PATH_DIR}/bin` を追記する）

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
<owner>/<repo>@<ref>
```

- `<ref>`: 入力 `ref`（ブランチ・タグ・コミット SHA のいずれか。SHA への解決は行わない）
- `check_existing` は `@` より前の部分（`<owner>/<repo>`）のみを入力 `repo` と比較する
- `verify_and_add_path` が全ステップ成功後に `printf '%s@%s'` で書き込む（skip=true の場合はスキップ）

**.repo の書き込み（HARDEN-04 を撤回）**:
排他は `check_existing` が取得するロック（`.repo.lock`）で保証する。
そのため `mktemp` と `mv` は使わず、`printf` で直接書き込む。

### 外部アクションのピン留め（HARDEN-02）

`action.yml` で使用するすべての外部アクションは、バージョンタグではなく **コミット SHA でピン留めしなければならない**。
バージョンタグのみ（例: `@v4`）の参照は禁止する。

```yaml
# 正しい例
uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
uses: pnpm/action-setup@73e46992e05b19abd31f2f3c20e0e7370d762115 # v6.1.1
uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0

# 禁止例
uses: actions/setup-node@v6
```

適用対象: `actions/setup-node`、`pnpm/action-setup`、`actions/checkout`

### 楽観的ロック設計

同一 `path` への並列実行を防ぐため、`check_existing` 開始時に `mkdir` によるディレクトリロックを取得する。

```text
check-existing.lib.sh
  mkdir <path>/.repo.lock   ← アトミック取得（失敗なら exit 1）
  echo "REPO_LOCK_DIR=..." >> $GITHUB_ENV   ← verify-and-add-path.lib.sh に引き継ぎ
  [.repo 確認 → skip フラグ出力]

[中間ステップ: checkout / pnpm / node / validate / install]

verify-and-add-path.lib.sh
  [検証 → GITHUB_PATH 追記 → .repo 書き込み]
  rm -rf "${REPO_LOCK_DIR}"   ← ロック解放
```

**ロックが解放されないケース**: `verify-and-add-path.sh` が失敗した場合、`.repo.lock` は残存する。
これは意図的な設計であり、壊れた状態の `path` への後続アクセスを防ぐ。
手動復旧が必要な場合は `rm -rf <path>/.repo.lock` を実行する。

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
| 2026-10-27 | 1.1.0   | 既定値を node-version `"24"`・pnpm-version `"12.15.0"` に更新                                                                                               |
| 2026-11-18 | 1.2.0   | node-version・pnpm-version の既定値を廃止 (空文字 = 未指定)                                                                                                 |
| 2026-11-19 | 1.2.1   | ca-setup-repo の現行実装に整合: パス・テスト配置、ステップ順 checkout→pnpm→node、`.repo` は `repo@ref`、HARDEN-01/03/04 の記述修正、SHA ピン例の更新        |
