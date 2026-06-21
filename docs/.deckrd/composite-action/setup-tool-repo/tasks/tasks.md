---
title: "Implementation Tasks: setup-tool-repo Composite Action"
module: composite-action/setup-tool-repo
status: Active
created: "2026-06-18"
source: specifications.md v1.0.2 / implementation.md v1.0.5
---

## Task Summary

| Test Target                   | Scenarios | Cases | Status |
| ----------------------------- | --------- | ----- | ------ |
| T-01: validate-inputs         | 5         | 10    | done   |
| T-02: check-existing          | 6         | 6     | done   |
| T-03: validate-repo-structure | 2         | 3     | done   |
| T-04: verify-and-add-path     | 6         | 9     | done   |
| T-05: action.yml integration  | 2         | 4     | done   |

---

## T-01: validate-inputs

> Target: `scripts/_libs/validate-inputs.lib.sh`
> Spec: R-001, R-002, R-003

### [正常] Normal Cases

#### T-01-01: 有効な入力パラメータ

- [x] **T-01-01-01**: 有効な repo/path/ref を渡すと exit 0 で終了する
  - Target: `validate-inputs.lib.sh`
  - Scenario: Given 有効な `owner/repo`・`./tools/agla`・`v1.0.0`, When 検証を実行する
  - Expected: Then exit 0 で終了する

### [異常] Error Cases

#### T-01-02: repo パラメータ検証（R-001）

- [x] **T-01-02-01**: repo にスラッシュがない場合 exit 1 になる
  - Target: `validate-inputs.lib.sh`
  - Scenario: Given `repo="agla-doc-tools"`, When 検証を実行する
  - Expected: Then `::error::` を stderr に出力し exit 1 で終了する

- [x] **T-01-02-02**: repo に複数スラッシュがある場合 exit 1 になる
  - Target: `validate-inputs.lib.sh`
  - Scenario: Given `repo="owner/repo/extra"`, When 検証を実行する
  - Expected: Then `::error::` を stderr に出力し exit 1 で終了する

#### T-01-03: path パラメータ検証（R-002）

- [x] **T-01-03-01**: path が `./` 始まりでない場合 exit 1 になる
  - Target: `validate-inputs.lib.sh`
  - Scenario: Given `path="tools/agla"`（`./` なし）, When 検証を実行する
  - Expected: Then `::error::` を stderr に出力し exit 1 で終了する

- [x] **T-01-03-02**: path に `..` セグメントが含まれる場合 exit 1 になる
  - Target: `validate-inputs.lib.sh`
  - Scenario: Given `path="./foo/../bar"`, When 検証を実行する
  - Expected: Then `::error::` を stderr に出力し exit 1 で終了する

- [x] **T-01-03-03**: path が絶対パスの場合 exit 1 になる
  - Target: `validate-inputs.lib.sh`
  - Scenario: Given `path="/tmp/tools"`, When 検証を実行する
  - Expected: Then `::error::` を stderr に出力し exit 1 で終了する

#### T-01-04: ref パラメータ検証（R-003）

- [x] **T-01-04-01**: ref が空文字列の場合 exit 1 になる
  - Target: `validate-inputs.lib.sh`
  - Scenario: Given `ref=""`, When 検証を実行する
  - Expected: Then `::error::` を stderr に出力し exit 1 で終了する

- [x] **T-01-04-02**: ref が空白のみの文字列の場合 exit 1 になる（バグ修正）
  - Target: `validate-inputs.lib.sh`
  - Scenario: Given `ref="  "`（空白 2 文字）, When 検証を実行する
  - Expected: Then `::error::` を stderr に出力し exit 1 で終了する（R-003）

### [エッジケース] Edge Cases

#### T-01-05: path の `..` セグメント判定境界（R-002）

- [x] **T-01-05-01**: `./foo..bar` はセグメント内部の `..` なので pass する
  - Target: `validate-inputs.lib.sh`
  - Scenario: Given `path="./foo..bar"`（`..` はセグメント全体ではない）, When 検証を実行する
  - Expected: Then exit 0 で終了する（不正とみなさない）

- [x] **T-01-05-02**: `../outside` は `./` で始まらないため exit 1 になる
  - Target: `validate-inputs.lib.sh`
  - Scenario: Given `path="../outside"`（`..` 始まりで `./` 始まりでない）, When 検証を実行する
  - Expected: Then `::error::` を stderr に出力し exit 1 で終了する（R-002）

---

## T-02: check-existing

> Target: `scripts/_libs/check-existing.lib.sh`
> Spec: R-005, R-006, R-007, R-008
> 前提: 全テストケースで `BeforeEach` により `GITHUB_OUTPUT`・`GITHUB_ENV` を `mktemp` で生成した一時ファイルに設定し、`AfterEach` で削除する

### [正常] Normal Cases

#### T-02-01: path が存在しない場合（新規チェックアウト）

- [x] **T-02-01-01**: path が存在しない場合 skip=false を GITHUB_OUTPUT に書き込む
  - Target: `check-existing.lib.sh`
  - Scenario: Given `GITHUB_OUTPUT`・`GITHUB_ENV` が `mktemp` ファイルに設定された状態で `path` ディレクトリが存在しない, When check-existing を実行する
  - Expected: Then ロックを取得し `skip=false` を `GITHUB_OUTPUT` に書き込み、`REPO_LOCK_DIR` を `GITHUB_ENV` に書き込む（R-005）

#### T-02-02: .repo が一致する場合（スキップ）

- [x] **T-02-02-01**: .repo の repo 部分が入力 repo と一致する場合 skip=true を書き込む
  - Target: `check-existing.lib.sh`
  - Scenario: Given `GITHUB_OUTPUT`・`GITHUB_ENV` が `mktemp` ファイルに設定された状態で `<path>/.repo` に `owner/repo@abc123` が存在し入力 `repo="owner/repo"`, When check-existing を実行する
  - Expected: Then `skip=true` を `GITHUB_OUTPUT` に書き込む（R-007）

### [異常] Error Cases

#### T-02-03: .repo が存在しない場合（R-006）

- [x] **T-02-03-01**: path は存在するが .repo がない場合 exit 1 になる
  - Target: `check-existing.lib.sh`
  - Scenario: Given `GITHUB_OUTPUT`・`GITHUB_ENV` が `mktemp` ファイルに設定された状態で `path` ディレクトリが存在するが `.repo` が存在しない, When check-existing を実行する
  - Expected: Then `::error::` を stderr に出力し exit 1 で終了する（R-006）

#### T-02-04: .repo の repo 部分が不一致の場合（R-008）

- [x] **T-02-04-01**: .repo に別 repo が記録されている場合 exit 1 になる
  - Target: `check-existing.lib.sh`
  - Scenario: Given `GITHUB_OUTPUT`・`GITHUB_ENV` が `mktemp` ファイルに設定された状態で `<path>/.repo` に `other/repo@abc123` があり入力 `repo="owner/repo"`, When check-existing を実行する
  - Expected: Then `::error::` を stderr に出力し exit 1 で終了する（R-008）

#### T-02-05: ロック競合

- [x] **T-02-05-01**: .repo.lock が既に存在する場合 exit 1 になる
  - Target: `check-existing.lib.sh`
  - Scenario: Given `GITHUB_OUTPUT`・`GITHUB_ENV` が `mktemp` ファイルに設定された状態で `<path>/.repo.lock` ディレクトリが既に存在する, When check-existing を実行する
  - Expected: Then `::error::` を stderr に出力し exit 1 で終了する（ロック競合）

#### T-02-06: skip=true 時に REPO_LOCK_DIR が GITHUB_ENV に設定される

- [x] **T-02-06-01**: .repo が同一 repo の場合 skip=true とともに REPO_LOCK_DIR が GITHUB_ENV に書き込まれる
  - Target: `check-existing.lib.sh`
  - Scenario: Given `GITHUB_OUTPUT`・`GITHUB_ENV` が `mktemp` ファイルに設定された状態で `<path>/.repo` に `owner/repo@abc123` が存在し入力 `repo="owner/repo"`, When check-existing を実行する
  - Expected: Then `skip=true` を `GITHUB_OUTPUT` に書き込み、かつ `REPO_LOCK_DIR` を `GITHUB_ENV` に書き込む（R-007・ロック取得はスキップを問わず必須）

---

## T-03: validate-repo-structure

> Target: `scripts/_libs/validate-repo-structure.lib.sh`
> Spec: R-011, R-012

### [正常] Normal Cases

#### T-03-01: pnpm-lock.yaml と bin/ が両方存在する

- [x] **T-03-01-01**: pnpm-lock.yaml と bin/ が存在する場合 exit 0 で終了する
  - Target: `validate-repo-structure.lib.sh`
  - Scenario: Given `<path>/pnpm-lock.yaml` と `<path>/bin/` が両方存在する, When 検証を実行する
  - Expected: Then exit 0 で終了する

### [異常] Error Cases

#### T-03-02: pnpm-lock.yaml が存在しない（R-011）

- [x] **T-03-02-01**: pnpm-lock.yaml が存在しない場合 exit 1 になる
  - Target: `validate-repo-structure.lib.sh`
  - Scenario: Given `<path>/pnpm-lock.yaml` が存在しない, When 検証を実行する
  - Expected: Then `::error::` を stderr に出力し exit 1 で終了する（R-011）

#### T-03-03: bin/ ディレクトリが存在しない（R-012）

- [x] **T-03-03-01**: bin/ が存在しない場合 exit 1 になる
  - Target: `validate-repo-structure.lib.sh`
  - Scenario: Given `<path>/bin/` ディレクトリが存在しない, When 検証を実行する
  - Expected: Then `::error::` を stderr に出力し exit 1 で終了する（R-012）

---

## T-04: verify-and-add-path

> Target: `scripts/_libs/verify-and-add-path.lib.sh`
> Spec: R-015, R-016, R-017, R-019, R-020, R-020S

### [正常] Normal Cases

#### T-04-01: skip=false（新規チェックアウト）

- [x] **T-04-01-01**: 全検証通過・skip=false の場合 GITHUB_PATH 追記・.repo 書き込み・ロック解放を行う
  - Target: `verify-and-add-path.lib.sh`
  - Scenario: Given `node_modules/.bin/`・`bin/` が存在し実行権限あり・`SKIP_REPO=false`・`REPO_LOCK_DIR` に `.repo.lock` パスが設定済み, When verify-and-add-path を実行する
  - Expected: Then `<path>/bin/` を `GITHUB_PATH` に追記し、`<path>/.repo` に `owner/repo@<sha>` を書き込み、**`<path>/.repo.lock` ディレクトリが存在しない**ことを確認する（R-019, R-020）

#### T-04-02: skip=true（既存チェックアウト再利用）

- [x] **T-04-02-01**: skip=true の場合 .repo 書き込みをスキップしてロックを解放する
  - Target: `verify-and-add-path.lib.sh`
  - Scenario: Given 全検証通過・`SKIP_REPO=true`, When verify-and-add-path を実行する
  - Expected: Then `GITHUB_PATH` 追記を行い、`.repo` 書き込みはスキップし、**`<path>/.repo.lock` ディレクトリが存在しない**ことを確認する（R-020S）

### [異常] Error Cases

#### T-04-03: post-install 検証の失敗ケース（R-015, R-016, R-017）

- [x] **T-04-03-01**: node_modules/.bin/ が存在しない場合 exit 1 になりロックが残存する
  - Target: `verify-and-add-path.lib.sh`
  - Scenario: Given `<path>/node_modules/.bin/` が存在しない・`REPO_LOCK_DIR` に `.repo.lock` パスが設定済み, When verify-and-add-path を実行する
  - Expected: Then `::error::` を stderr に出力し exit 1 で終了し、**`<path>/.repo.lock` ディレクトリが残存している**ことを確認する（R-015、ロック意図的残存）

- [x] **T-04-03-02**: bin/ が空ディレクトリの場合 exit 1 になりロックが残存する
  - Target: `verify-and-add-path.lib.sh`
  - Scenario: Given `<path>/bin/` が空ディレクトリ・`REPO_LOCK_DIR` に `.repo.lock` パスが設定済み, When verify-and-add-path を実行する
  - Expected: Then `::error::` を stderr に出力し exit 1 で終了し、**`<path>/.repo.lock` ディレクトリが残存している**ことを確認する（R-016、ロック意図的残存）

- [x] **T-04-03-03**: bin/ 配下ファイルに実行権限がない場合 exit 1 になりロックが残存する
  - Target: `verify-and-add-path.lib.sh`
  - Scenario: Given `<path>/bin/` に実行権限なしのファイルが存在する・`REPO_LOCK_DIR` に `.repo.lock` パスが設定済み, When verify-and-add-path を実行する
  - Expected: Then `::error::` を stderr に出力し exit 1 で終了し、**`<path>/.repo.lock` ディレクトリが残存している**ことを確認する（R-017、ロック意図的残存）

### [エッジケース] Edge Cases

#### T-04-05: node_modules/.bin/ が空ディレクトリでも pass する（R-015）

- [x] **T-04-05-01**: node_modules/.bin/ が空ディレクトリの場合 exit 0 で終了する
  - Target: `verify-and-add-path.lib.sh`
  - Scenario: Given `<path>/node_modules/.bin/` が空ディレクトリ（ファイルなし）・`<path>/bin/` に実行権限ありファイルが存在する, When verify-and-add-path を実行する
  - Expected: Then exit 0 で終了する（R-015 はディレクトリ存在のみ確認し、内容は問わない）

#### T-04-06: bin/ 配下にシンボリックリンクのみ存在する場合（R-017）

- [x] **T-04-06-01**: bin/ 配下に実行権限を持つシンボリックリンクのみの場合 exit 0 で終了する
  - Target: `verify-and-add-path.lib.sh`
  - Scenario: Given `<path>/bin/` に実行権限を持つシンボリックリンクのみが存在する（実体も実行権限あり）, When verify-and-add-path を実行する
  - Expected: Then exit 0 で終了する（R-017 はシンボリックリンクの実体の権限を確認）

- [x] **T-04-06-02**: bin/ 配下のシンボリックリンクの実体に実行権限がない場合 exit 1 になる
  - Target: `verify-and-add-path.lib.sh`
  - Scenario: Given `<path>/bin/` に実行権限のないシンボリックリンクのみが存在する（実体の実行権限なし）, When verify-and-add-path を実行する
  - Expected: Then `::error::` を stderr に出力し exit 1 で終了する（R-017）

---

## T-05: action.yml integration

> Target: `.github/actions/setup-tool-repo/action.yml`
> Spec: R-001〜R-020（全ユニット統合）

### [正常] Normal Cases

#### T-05-01: 正常系統合フロー

- [x] **T-05-01-01**: 全スクリプトが連続して pass する（モック環境）
  - Target: `setup-tool-repo.integration.spec.sh`
  - Scenario: Given 有効な入力・pnpm-lock.yaml と bin/ が存在・node_modules/.bin/ が存在, When 全スクリプトを順に実行する
  - Expected: Then 各スクリプトが exit 0 で終了し GITHUB_PATH に bin/ が追記される

- [x] **T-05-01-02**: actionlint と ghalint による action.yml 検証が pass する
  - Target: `.github/actions/setup-tool-repo/action.yml`
  - Scenario: Given action.yml が完成した状態, When `actionlint -config-file ./configs/actionlint.yaml` および `ghalint run --config ./configs/ghalint.yaml` をコマンドラインで実行する
  - Expected: Then 検証エラーなしで exit 0 で終了する（ShellSpec 外のコマンド検証 — Commit 12 で手動確認）

### [異常] Error Cases

#### T-05-02: 異常系統合フロー

- [x] **T-05-02-01**: validate-inputs 失敗時に後続スクリプトが呼ばれない
  - Target: `setup-tool-repo.integration.spec.sh`
  - Scenario: Given 不正な `repo` 形式, When validate-inputs スクリプトを実行する
  - Expected: Then exit 1 で終了し check-existing 以降のスクリプトが実行されない

- [x] **T-05-02-02**: check-existing で repo コンフリクト時に exit 1 になる
  - Target: `setup-tool-repo.integration.spec.sh`
  - Scenario: Given `<path>/.repo` に別 repo が記録されている, When check-existing スクリプトを実行する
  - Expected: Then `::error::` を stderr に出力し exit 1 で終了する
