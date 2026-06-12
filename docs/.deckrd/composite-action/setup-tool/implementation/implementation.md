---
title: "Implementation Plan: setup-tool composite action"
based-on: specifications.md v1.3.0
status: Draft
---

<!-- markdownlint-disable line-length -->

## 1. Overview

### 1.1 Purpose

GitHub Actions の composite action として、指定された GitHub リポジトリのリリースから
ツールをダウンロードし、チェックサム検証・アーカイブ展開を行い、
ツールバイナリを実行可能な PATH に配置する。

実装は関数ライブラリ式（4ファイル構成）で新規作成する。
既存スクリプト群（`setup-directories.sh` 等）は参考実装として廃止する。

主要な設計決定:

- GitHub API（`api.github.com`）でアセット一覧を1回取得し、tar.gz の arch 解決と
  checksums.txt の選択を同時に行う（`jq` は `validate-environment` で保証）
- `repo` は `owner/repo` 形式のまま URL に直接埋め込む（分割不要）
- checksums.txt の候補順: `checksums.txt` → `{tool-name}_{version}_checksums.txt`
- ダウンロードした tar.gz は `${TOOL_NAME}.tar.gz` にリネームして後続処理で一貫参照
- スクリプト間 I/F: パラメータ渡し・stdout 返却・`.` でライブラリ読み込み
- 複数値返却規約: 1行 = 1値・空行なしで出力し、呼び出し元は `mapfile` で行単位にキャプチャする

### 1.2 実装品質基準（全コミット共通）

以下を全コミットに適用する規範的制約とする（DR-08）:

- BDD サイクル: テストコミット後・実装コミット前に RED を確認し、実装完了条件は GREEN とする
- `set -euo pipefail`: 全スクリプト・全ライブラリファイルの先頭に設定する（ライブラリは double-source guard の後）
- double-source guard: 新規作成する全ライブラリファイルに付与する
- エラー出力: `::error::<message>` を stderr に出力し、フェーズ別固定 exit code で終了する

### 1.3 Reference

- Prior Art: `.github-aglabo/.github/actions/scripts/`（aglabo 参考実装）
- Prior Art: `.github/actions/setup-tool/scripts/_libs/`（既存 validation.lib.sh / common.lib.sh）
- Specifications: `specifications/specifications.md` v1.3.0

---

## 2. Implementation Plan

### Phase 1: ライブラリ基盤（dirs / arch）

#### Commit 1: test(setup-tool/dirs): add ShellSpec tests for setup_dirs

- `scripts/__tests__/dirs.unit.spec.sh` を作成
- `setup_dirs()` の正常系: BIN_DIR・TEMP_DIR が作成されること
- GITHUB_ENV / GITHUB_PATH への書き込み検証
- テストが RED であることを確認

#### Commit 2: feat(setup-tool/dirs): implement dirs.lib.sh

- `scripts/_libs/dirs.lib.sh` を新規作成
- `setup_dirs()`: `BIN_DIR=${RUNNER_TEMP}/bin`・`TEMP_DIR=$(mktemp -d)` を作成
- `GITHUB_ENV` / `GITHUB_PATH` への書き込みで後続ステップに引き渡す
- double-source guard 付き（Section 1.2 実装品質基準に準拠）
- テストが GREEN であることを確認

#### Commit 3: test(setup-tool/arch): add ShellSpec tests for detect_arch

- `scripts/__tests__/arch.unit.spec.sh` を作成
- `detect_arch()` の正常系: `X64` → `amd64`（1行目）・`x64`（2行目）を stdout 出力
- `detect_arch()` の正常系: `ARM64` → `arm64`（1行目）を stdout 出力
- `detect_arch()` の異常系: 未知の arch → `::error::` を stderr に出力して exit 1
- テストが RED であることを確認

#### Commit 4: feat(setup-tool/arch): implement arch.lib.sh

- `scripts/_libs/arch.lib.sh` を新規作成
- `detect_arch()`: `runner.arch` → `ARCH_CANDIDATES` を1行1値で stdout に出力
  - `X64` → `amd64`（1行目）・`x64`（2行目）
  - `ARM64` → `arm64`（1行目）
  - 未知 → `::error::` を stderr に出力して exit 1
- 呼び出し元は `mapfile -t ARCH_CANDIDATES < <(detect_arch)` でキャプチャ
- double-source guard 付き
- `resolve_arch()` は実装しない（`resolve_assets()` に統合）
- テストが GREEN であることを確認

---

### Phase 2: ダウンロードライブラリ（download）

#### Commit 5: test(setup-tool/download): add ShellSpec tests for build_url

- `scripts/__tests__/download.unit.spec.sh` を作成
- `build_url()` の正常系: `repo`・`tool-version` → GitHub API URL を stdout 出力
  - 期待値: `https://api.github.com/repos/{repo}/releases/tags/v{version}`
- `tool-version` の `v` プレフィックスは `normalize_version()` で除去済みを前提
- テストが RED であることを確認

#### Commit 6: feat(setup-tool/download): implement build_url in download.lib.sh

- `scripts/_libs/download.lib.sh` を新規作成
- `build_url()`: `repo`・`tool-version` を受け取り GitHub API URL を stdout 出力
- double-source guard 付き
- テストが GREEN であることを確認

#### Commit 7: test(setup-tool/download): add ShellSpec tests for resolve_assets

- `resolve_assets()` のユニットテスト（curl / jq モック使用）
- シグネチャ: `resolve_assets <api_url> <tool_name> <arch_candidate>...`
  （ARCH_CANDIDATES は配列展開 `"${ARCH_CANDIDATES[@]}"` で渡す）
- GitHub API レスポンスからアセット一覧を取得する正常系
- `ARCH_CANDIDATES` に一致する tar.gz の download URL 選択検証
- checksums.txt 候補の選択検証:
  - `checksums.txt` が存在する場合はそちらを採用
  - `{tool-name}_{version}_checksums.txt` にフォールバック
- 候補なし・API 失敗時の exit 2 を検証
- テストが RED であることを確認

#### Commit 8: feat(setup-tool/download): implement resolve_assets in download.lib.sh

- `resolve_assets()`: シグネチャ `resolve_assets <api_url> <tool_name> <arch_candidate>...`
  - 第3引数以降が arch 候補リスト（可変長引数 `"$@"` で受け取る）
- `jq` で `assets[].name` と `assets[].browser_download_url` を抽出
- arch 候補を順に確認し、一致する tar.gz の URL を選択（`ARCH_SUFFIX` も確定）
- checksums.txt 候補を順に確認:
  1. `checksums.txt`
  2. `{tool-name}_{version}_checksums.txt`
- `DOWNLOAD_URL`（1行目）・`CHECKSUM_URL`（2行目）・`ARCH_SUFFIX`（3行目）を1行1値で stdout に出力
- 呼び出し元: `mapfile -t _assets < <(resolve_assets "${API_URL}" "${TOOL_NAME}" "${ARCH_CANDIDATES[@]}")`
- 候補なし・API 失敗時は `::error::` を stderr に出力して exit 2
- テストが GREEN であることを確認

#### Commit 9: test(setup-tool/download): add ShellSpec tests for download_tool

- `download_tool()` のユニットテスト（curl モック使用）
- `DOWNLOAD_URL`・`CHECKSUM_URL`・`TEMP_DIR` を引数で受け取る
- tar.gz 取得・`${TOOL_NAME}.tar.gz` へのリネーム検証
- checksums.txt 取得検証
- curl 失敗時の exit 2 を検証
- テストが RED であることを確認

#### Commit 10: feat(setup-tool/download): implement download_tool in download.lib.sh

- `download_tool()`: `DOWNLOAD_URL`・`CHECKSUM_URL`・`TEMP_DIR` を引数で受け取る
- tar.gz を curl で取得し `${TOOL_NAME}.tar.gz` にリネームして `TEMP_DIR` に保存
- checksums.txt を curl で取得し `TEMP_DIR/checksums.txt` として保存
- 失敗時は `::error::` を stderr に出力して exit 2
- テストが GREEN であることを確認

#### Commit 11: test(setup-tool/download): add ShellSpec tests for verify_checksum

- `verify_checksum()` のユニットテスト
- checksums.txt の検索キーは元ファイル名形式:
  `{tool-name}_{version}_linux_{arch}.tar.gz`
- sha256sum の対象は `${TOOL_NAME}.tar.gz`（リネーム後）
- 正常系・エントリなし（exit 3）・ハッシュ不一致（exit 3）の各ケースを検証
- テストが RED であることを確認

#### Commit 12: feat(setup-tool/download): implement verify_checksum in download.lib.sh

- `verify_checksum()`: `tool-name`・`tool-version`・`ARCH_SUFFIX`・`TEMP_DIR` を受け取る
- 元ファイル名（`{tool-name}_{version}_linux_{arch}.tar.gz`）で `grep -w` 検索
- sha256sum の対象は `TEMP_DIR/${TOOL_NAME}.tar.gz`（リネーム後）
- エントリなし・ハッシュ不一致時は `::error::` を stderr に出力して exit 3
- テストが GREEN であることを確認

---

### Phase 3: インストールライブラリ（install）

#### Commit 13: test(setup-tool/install): add ShellSpec tests for extract_install

- `scripts/__tests__/install.unit.spec.sh` を作成
- `extract_install()` の正常系: tar.gz 展開・`tool-name` 一致バイナリを BIN_DIR に配置
- パーミッション 755 の検証
- `tool-name` 一致バイナリなし → exit 4 を検証
- tar 失敗 → exit 4 を検証
- テストが RED であることを確認

#### Commit 14: feat(setup-tool/install): implement extract_install in install.lib.sh

- `scripts/_libs/install.lib.sh` を新規作成
- `extract_install()`: `tool-name`・`TEMP_DIR`・`BIN_DIR` を引数で受け取る
- `tar -xzf "${TOOL_NAME}.tar.gz" -C "${TEMP_DIR}"` で展開
- `tool-name` に一致するバイナリを `install -m 755` で `BIN_DIR` に配置
- 一致なし・失敗時は `::error::` を stderr に出力して exit 4
- double-source guard 付き
- テストが GREEN であることを確認

#### Commit 15: test(setup-tool/install): add ShellSpec tests for cleanup

- `cleanup()` のユニットテスト
- `TEMP_DIR` 存在時の削除検証
- `TEMP_DIR` 削除済み時の冪等動作（exit 0）を検証
- テストが RED であることを確認

#### Commit 16: feat(setup-tool/install): implement cleanup in install.lib.sh

- `cleanup()`: `TEMP_DIR` をパラメータで受け取り `rm -rf` で削除（冪等）
- 成功時は `✓ Cleanup completed` を stdout に出力
- テストが GREEN であることを確認

---

### Phase 4: オーケストレーションスクリプトと action.yml 統合

#### Commit 17: test(setup-tool): add ShellSpec tests for setup-tool.sh

- `scripts/__tests__/setup-tool.unit.spec.sh` を作成
- 各ライブラリ関数をモック化して呼び出し順序を検証
- 正常系: 全関数が順に呼び出されること
- 異常系: 各フェーズ失敗時に適切な exit code で終了すること
- `trap 'cleanup "${TEMP_DIR}"' EXIT` による cleanup の保証を検証
  （TEMP_DIR を引数として渡すパターンであることを明示）
- テストが RED であることを確認

#### Commit 18: feat(setup-tool): implement setup-tool.sh

- `scripts/setup-tool.sh` を新規作成
- 各ライブラリを `.` で読み込み、処理の流れを制御:
  1. `normalize_version()`: tool-version の v プレフィックスを除去（`version.lib.sh`）
  2. `validate_inputs()`: `repo`・`tool-name`・正規化済み `tool-version` の入力検証
     （`validation.lib.sh` の `validate_symbol()` を使用・`setup-tool.sh` 内にインライン定義）
  3. `setup_dirs()`: BIN_DIR・TEMP_DIR 作成・GITHUB_ENV/PATH 書き込み（`dirs.lib.sh`）
  4. `mapfile -t ARCH_CANDIDATES < <(detect_arch)`: runner.arch → 候補配列にキャプチャ（`arch.lib.sh`）
  5. `mapfile -t _assets < <(resolve_assets "${API_URL}" "${TOOL_NAME}" "${ARCH_CANDIDATES[@]}")`: DOWNLOAD_URL（[0]）・CHECKSUM_URL（[1]）・ARCH_SUFFIX（[2]）を配列にキャプチャ（`download.lib.sh`）
  6. `download_tool`: tar.gz + checksums.txt を TEMP_DIR に取得・リネーム（`download.lib.sh`）
  7. `verify_checksum`: sha256sum 検証（`download.lib.sh`）
  8. `extract_install`: tar.gz 展開・BIN_DIR にバイナリ配置（`install.lib.sh`）
- `TEMP_DIR` はスクリプトスコープのグローバル変数として保持
- `trap 'cleanup "${TEMP_DIR}"' EXIT` で TEMP_DIR を引数として渡し、成功・失敗問わず削除
- テストが GREEN であることを確認

#### Commit 19: chore(setup-tool): remove deprecated scripts

- WHEN Commit 18（`setup-tool.sh`）のテストが GREEN になった後に実施する
- 廃止予定スクリプトを削除:
  - `scripts/setup-directories.sh`
  - `scripts/download-tool.sh`
  - `scripts/verify-checksum.sh`
  - `scripts/extract-install.sh`
  - `scripts/cleanup.sh`
- 各機能は新規ライブラリ（`dirs.lib.sh`・`download.lib.sh`・`install.lib.sh`）に移行済み

#### Commit 20: feat(setup-tool): implement action.yml

- `.github/actions/setup-tool/action.yml` を新規作成（廃止スクリプト削除後）
- `inputs` を定義:
  - `repo`: `owner/repo` 形式（required: true）
  - `tool-name`: ツール名（required: true）
  - `tool-version`: `X.Y.Z` 形式（required: false・`default:` に固定バージョンを設定）
- `runs.using: "composite"` で `setup-tool.sh` を1回呼び出すだけのシンプルな構成
- `inputs` は `env:` 経由でスクリプトに渡す
- `validate-environment`（`additional_apps: [jq]` 含む）が事前実行済みであることをコメントで明示
- aglabo の `setup-actionlint/action.yml` 構造に準拠

---

## 3. Additional Tasks

### 付加タスク A: 共通ライブラリへの移行と validate-environment 側修正

調査の結果、`validate-environment` と `setup-tool` に重複する機能が存在する。
共通ライブラリを `.github/actions/_libs/` に新設し、両 action から参照する構成に移行する。

#### 共通化対象関数

| 関数                              | 現在の所在                                            | 共通化後                                  |
| --------------------------------- | ----------------------------------------------------- | ----------------------------------------- |
| `normalize_version()`             | `setup-tool/scripts/_libs/common.lib.sh`              | `.github/actions/_libs/version.lib.sh`    |
| `validate_symbol()`               | `setup-tool/scripts/_libs/validation.lib.sh`          | `.github/actions/_libs/validation.lib.sh` |
| `out_status()` / `write_output()` | `validate-environment/scripts/` 各所                  | `.github/actions/_libs/output.lib.sh`     |
| `check_env_var()`                 | `validate-environment/scripts/validate-git-runner.sh` | `.github/actions/_libs/env.lib.sh`        |

#### 共通ライブラリ配置

```bash
.github/actions/_libs/
├── version.lib.sh      # normalize_version()（setup-tool の common.lib.sh から移行）
├── validation.lib.sh   # validate_symbol()（setup-tool の validation.lib.sh から移行）
├── output.lib.sh       # out_status() / write_output()（validate-environment から抽出）
└── env.lib.sh          # check_env_var()（validate-environment から抽出）
```

各 action からのパス解決: `. "${GITHUB_ACTION_PATH}/../_libs/<name>.lib.sh"`

#### 実施順序

付加タスク A（A-1〜A-3）は **Phase 1 の前に実施する**。
Phase 1〜4 の新規ライブラリが最初から共通ライブラリを参照できるため、
後からの切り替えリファクタリングが不要になる。

実施順序: **A-1 → A-2 → A-3 → Phase 1 → Phase 2 → Phase 3 → Phase 4**

#### 付加タスク A のコミット分解

#### Commit A-1: feat(actions/libs): create shared library structure

- `.github/actions/_libs/` ディレクトリを作成
- `version.lib.sh`: `setup-tool/scripts/_libs/common.lib.sh` の `normalize_version()` を移行
- `validation.lib.sh`: `setup-tool/scripts/_libs/validation.lib.sh` の `validate_symbol()` を移行
- `output.lib.sh`: `validate-environment` 各スクリプトの `out_status()` / `write_output()` を抽出・統合
- `env.lib.sh`: `validate-git-runner.sh` の `check_env_var()` を移行
- 各ライブラリに double-source guard を付与

#### Commit A-2: refactor(validate-environment): migrate to shared libs

- `validate-apps.sh`・`validate-git-runner.sh`・`validate-permissions.sh` の重複関数を削除
- `. "${GITHUB_ACTION_PATH}/../_libs/<name>.lib.sh"` で共通ライブラリを読み込む形に変更
- 既存テストが引き続き GREEN であることを確認

#### Commit A-3: refactor(setup-tool): migrate to shared libs

- WHEN A-1・A-2 が完了し共通ライブラリの動作が確認された後に実施する
- `setup-tool/scripts/_libs/common.lib.sh` を削除（`version.lib.sh` に移行済み）
- `setup-tool/scripts/_libs/validation.lib.sh` を削除（共通 `validation.lib.sh` に移行済み）
- `setup-tool` の各ライブラリで共通ライブラリを読み込む形に変更
- 既存テストが引き続き GREEN であることを確認

---

## 4. Change History

| Date       | Version | Description                                                                                                                   |
| ---------- | ------- | ----------------------------------------------------------------------------------------------------------------------------- |
| 2026-06-07 | 1.0     | Initial implementation plan                                                                                                   |
| 2026-06-07 | 1.1     | Phase 4 改訂: setup-tool.sh オーケストレーター追加・action.yml を1ステップに簡略化                                            |
| 2026-06-07 | 1.2     | explore レビュー反映: 複数値返却規約（1行1値・mapfile キャプチャ）・normalize_version 呼び出し順序を明示                      |
| 2026-06-07 | 1.3     | 付加タスク A 追加: 共通ライブラリ（.github/actions/_libs/）新設・validate-environment 側リファクタリング                      |
| 2026-06-07 | 1.4     | explore レビュー残件反映: validate_inputs 帰属明示・cleanup の trap 引数渡し・廃止スクリプト削除コミット追加                  |
| 2026-06-07 | 1.5     | explore レビュー2回目反映: 付加タスク A 実施順序確定（Phase 1 前）・Commit 17 trap 記述修正・ARCH_CANDIDATES 配列渡し方法明示 |
| 2026-06-07 | 1.6     | harden レビュー反映: 実装品質基準（DR-08）追記・Commit 3 出力形式修正・A-3/Commit 19 に WHEN 条件追加                         |
| 2026-06-07 | 1.7     | fix レビュー反映: Section 順序修正・用語統一（パラメータ→引数・正常系テスト→正常系）・見出し階層統一・クォート修正            |
