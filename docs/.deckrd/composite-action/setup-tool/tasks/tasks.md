---
title: "Implementation Tasks"
module: "composite-action/setup-tool"
status: Active
created: "2026-06-07 00:00:00"
source: specifications.md
---

<!-- cspell:words rhysd rwxr invalidrepo -->

<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/max-comma -->
<!-- markdownlint-disable no-duplicate-heading line-length -->

> このドキュメントは specifications.md と implementation.md から導出した実装タスク一覧です。
> 各タスクは単一の BDD テストケース（`it()` ブロック）に対応します。
> 実施順序: **共通ライブラリ（T-01→T-02→T-03→T-04）→ Phase 1〜4（T-05〜T-13）**

---

## Task Summary

| #  | Test Target                             | Scenarios | Cases | Status  |
| -- | --------------------------------------- | --------- | ----- | ------- |
| 1  | T-01: normalize_version                 | 2         | 5     | done    |
| 2  | T-02: validate_symbol                   | 2         | 4     | done    |
| 3  | T-03: validate-environment 移行検証     | 1         | 2     | done    |
| 4  | T-04: setup-tool 共通ライブラリ移行検証 | 1         | 2     | done    |
| 5  | T-05: setup_dirs                        | 4         | 6     | pending |
| 6  | T-06: detect_arch                       | 3         | 4     | pending |
| 7  | T-07: build_url                         | 2         | 2     | pending |
| 8  | T-08: resolve_assets                    | 3         | 7     | pending |
| 9  | T-09: download_tool                     | 2         | 4     | pending |
| 10 | T-10: verify_checksum                   | 3         | 5     | pending |
| 11 | T-11: extract_install                   | 3         | 5     | pending |
| 12 | T-12: cleanup                           | 2         | 3     | pending |
| 13 | T-13: setup-tool.sh                     | 4         | 7     | pending |

---

## T-01: normalize_version

### [正常] Normal Cases

#### T-01-01: v プレフィックスを除去する

- [x] **T-01-01-01**: `v1.2.3` が `1.2.3` に正規化される
  - Target: `normalize_version`
  - Scenario: Given version=`v1.2.3`、When `normalize_version` を呼び出す
  - Expected: Then stdout が `1.2.3` である

- [x] **T-01-01-02**: `V1.2.3`（大文字V）も `1.2.3` に正規化される
  - Target: `normalize_version`
  - Scenario: Given version=`V1.2.3`、When `normalize_version` を呼び出す
  - Expected: Then stdout が `1.2.3` である

- [x] **T-01-01-03**: プレフィックスなしの `1.2.3` はそのまま出力される
  - Target: `normalize_version`
  - Scenario: Given version=`1.2.3`（プレフィックスなし）、When `normalize_version` を呼び出す
  - Expected: Then stdout が `1.2.3` である

### [異常] Error Cases

#### T-01-02: 不正なバージョン形式の場合

- [x] **T-01-02-01**: X.Y.Z 形式でないバージョンで exit 1 で失敗する
  - Target: `normalize_version`
  - Scenario: Given version=`latest`（不正形式）、When `normalize_version` を呼び出す
  - Expected: Then exit 1 で終了する

- [x] **T-01-02-02**: 空文字を渡したとき exit 1 で失敗する
  - Target: `normalize_version`
  - Scenario: Given version=``（空文字）、When `normalize_version` を呼び出す
  - Expected: Then exit 1 で終了する

---

## T-02: validate_symbol

### [正常] Normal Cases

#### T-02-01: 値がパターンに一致する場合

- [x] **T-02-01-01**: 有効な値でパターン一致のとき exit 0 で成功する
  - Target: `validate_symbol`
  - Scenario: Given value=`actionlint`・pattern=`[a-z][a-z0-9_-]*`、When `validate_symbol` を呼び出す
  - Expected: Then exit 0 で正常終了する

- [x] **T-02-01-02**: owner/repo 形式の値がパターンに一致する
  - Target: `validate_symbol`
  - Scenario: Given value=`rhysd/actionlint`・pattern=`[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+`、When `validate_symbol` を呼び出す
  - Expected: Then exit 0 で正常終了する

### [異常] Error Cases

#### T-02-02: 値がパターンに不一致の場合

- [x] **T-02-02-01**: パターン不一致のとき ::error:: を出力して exit 1 で失敗する
  - Target: `validate_symbol`
  - Scenario: Given value=`invalid value!`（不正文字含む）・pattern=`[a-z]+`、When `validate_symbol` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [x] **T-02-02-02**: 空文字でパターン不一致のとき exit 1 で失敗する
  - Target: `validate_symbol`
  - Scenario: Given value=``（空文字）、When `validate_symbol` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

---

## T-03: validate-environment 共通ライブラリ移行検証

> 付加タスク A-2 完了後の検証タスク。validate-environment の既存テストが GREEN を維持することを確認する。

### [正常] Normal Cases

#### T-03-01: 共通ライブラリ移行後も validate-environment の既存テストが通過する

- [x] **T-03-01-01**: validate-apps の既存テストが共通ライブラリ移行後も GREEN である
  - Target: `validate-environment/scripts/validate-apps.sh`
  - Scenario: Given 共通ライブラリ（out_status・write_output）への移行が完了している、When `bash scripts/run-specs.sh .github/actions/validate-environment/scripts/__tests__` を実行する
  - Expected: Then 全テストが GREEN で通過する

- [x] **T-03-01-02**: validate-git-runner の既存テストが共通ライブラリ移行後も GREEN である
  - Target: `validate-environment/scripts/validate-git-runner.sh`
  - Scenario: Given 共通ライブラリ（check_env_var）への移行が完了している、When `bash scripts/run-specs.sh .github/actions/validate-environment/scripts/__tests__` を実行する
  - Expected: Then 全テストが GREEN で通過する

---

## T-04: setup-tool 共通ライブラリ移行検証

> 付加タスク A-3 完了後の検証タスク。setup-tool の既存ライブラリテストが GREEN を維持することを確認する。

### [正常] Normal Cases

#### T-04-01: 共通ライブラリ移行後も setup-tool の既存テストが通過する

- [x] **T-04-01-01**: normalize_version のテストが共通ライブラリ移行後も GREEN である
  - Target: `.github/actions/_libs/version.lib.sh`
  - Scenario: Given normalize_version が共通 version.lib.sh に移行完了している、When `bash scripts/run-specs.sh .github/actions/setup-tool/scripts/__tests__` を実行する
  - Expected: Then 全テストが GREEN で通過する

- [x] **T-04-01-02**: validate_symbol のテストが共通ライブラリ移行後も GREEN である
  - Target: `.github/actions/_libs/validation.lib.sh`
  - Scenario: Given validate_symbol が共通 validation.lib.sh に移行完了している、When `bash scripts/run-specs.sh .github/actions/setup-tool/scripts/__tests__` を実行する
  - Expected: Then 全テストが GREEN で通過する

---

## T-05: setup_dirs

### [正常] Normal Cases

#### T-05-01: RUNNER_TEMP が設定済みの状態で setup_dirs を呼び出す

- [ ] **T-05-01-01**: BIN_DIR が `${RUNNER_TEMP}/bin` として作成される
  - Target: `setup_dirs`
  - Scenario: Given RUNNER_TEMP が設定済み、When `setup_dirs` を呼び出す
  - Expected: Then `${RUNNER_TEMP}/bin` ディレクトリが存在する

- [ ] **T-05-01-02**: TEMP_DIR が `mktemp -d` で動的生成される
  - Target: `setup_dirs`
  - Scenario: Given RUNNER_TEMP が設定済み、When `setup_dirs` を呼び出す
  - Expected: Then TEMP_DIR が空でないパスとして設定されており、ディレクトリが存在する

- [ ] **T-05-01-03**: BIN_DIR が GITHUB_PATH に書き込まれる
  - Target: `setup_dirs`
  - Scenario: Given GITHUB_PATH ファイルが存在する、When `setup_dirs` を呼び出す
  - Expected: Then GITHUB_PATH ファイルに BIN_DIR のパスが追記されている

- [ ] **T-05-01-04**: BIN_DIR と TEMP_DIR が GITHUB_ENV に書き込まれる
  - Target: `setup_dirs`
  - Scenario: Given GITHUB_ENV ファイルが存在する、When `setup_dirs` を呼び出す
  - Expected: Then GITHUB_ENV に `BIN_DIR=...` と `TEMP_DIR=...` が追記されている

### [異常] Error Cases

#### T-05-02: RUNNER_TEMP が未設定の状態で setup_dirs を呼び出す

- [ ] **T-05-02-01**: RUNNER_TEMP 未設定時に exit 1 で失敗する
  - Target: `setup_dirs`
  - Scenario: Given RUNNER_TEMP が未設定、When `setup_dirs` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

### [エッジケース] Edge Cases

#### T-05-03: GITHUB_ENV / GITHUB_PATH が未設定の場合

- [ ] **T-05-03-01**: GITHUB_ENV が未設定でもディレクトリ作成は成功する
  - Target: `setup_dirs`
  - Scenario: Given GITHUB_ENV が空または `/dev/null` に設定されている（ローカルテスト環境）、When `setup_dirs` を呼び出す
  - Expected: Then BIN_DIR・TEMP_DIR は作成され、GITHUB_ENV への書き込みは /dev/null に吸収されて exit 0 で終了する

---

## T-06: detect_arch

### [正常] Normal Cases

#### T-06-01: runner.arch が X64 の場合

- [ ] **T-06-01-01**: RUNNER_ARCH=X64 のとき amd64 と x64 を1行1値で出力する
  - Target: `detect_arch`
  - Scenario: Given RUNNER_ARCH=X64、When `detect_arch` を呼び出す
  - Expected: Then stdout の1行目が `amd64`、2行目が `x64` である

#### T-06-02: runner.arch が ARM64 の場合

- [ ] **T-06-02-01**: RUNNER_ARCH=ARM64 のとき arm64 を1行で出力する
  - Target: `detect_arch`
  - Scenario: Given RUNNER_ARCH=ARM64、When `detect_arch` を呼び出す
  - Expected: Then stdout の1行目が `arm64` のみである

### [異常] Error Cases

#### T-06-03: runner.arch が未知の値の場合

- [ ] **T-06-03-01**: 未知の RUNNER_ARCH で ::error:: を出力して exit 1 で失敗する
  - Target: `detect_arch`
  - Scenario: Given RUNNER_ARCH=MIPS（未知の値）、When `detect_arch` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [ ] **T-06-03-02**: RUNNER_ARCH が未設定のとき exit 1 で失敗する
  - Target: `detect_arch`
  - Scenario: Given RUNNER_ARCH が空文字、When `detect_arch` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

---

## T-07: build_url

### [正常] Normal Cases

#### T-07-01: 有効な repo と tool-version で GitHub API URL を構築する

- [ ] **T-07-01-01**: owner/repo 形式と normalize_version 適用済み version で正しい API URL が構築される
  - Target: `build_url`
  - Scenario: Given repo=`rhysd/actionlint`・version=`1.7.7`（normalize_version 適用済み・v なし）、When `build_url` を呼び出す
  - Expected: Then stdout が `https://api.github.com/repos/rhysd/actionlint/releases/tags/v1.7.7` である

### [エッジケース] Edge Cases

#### T-07-02: tool-version に v プレフィックスが残っている場合（normalize_version 未適用の場合）

- [ ] **T-07-02-01**: normalize_version 未適用の v 付き version を渡しても URL が vv 二重にならない
  - Target: `build_url`
  - Scenario: Given version=`v1.7.7`（normalize_version 未適用）、When `build_url` を呼び出す
  - Expected: Then stdout の URL に `vv1.7.7` が含まれず、`v1.7.7` のパスとして構築される

---

## T-08: resolve_assets

### [正常] Normal Cases

#### T-08-01: アセット一覧に X64 向け tar.gz が含まれる場合

- [ ] **T-08-01-01**: ARCH_CANDIDATES の最初の候補に一致する tar.gz URL が1行目に出力される
  - Target: `resolve_assets`
  - Scenario: Given GitHub API レスポンスに `actionlint_1.7.7_linux_amd64.tar.gz` が含まれる、When `resolve_assets` を ARCH_CANDIDATES=`[amd64,x64]` で呼び出す
  - Expected: Then stdout の1行目が amd64 のダウンロード URL、3行目が `amd64` である

- [ ] **T-08-01-02**: `checksums.txt` が存在する場合はそちらが CHECKSUM_URL として出力される
  - Target: `resolve_assets`
  - Scenario: Given アセット一覧に `checksums.txt` が含まれる、When `resolve_assets` を呼び出す
  - Expected: Then stdout の2行目の URL に `checksums.txt` が含まれる

#### T-08-02: checksums.txt が存在せず tool_version_checksums.txt がある場合

- [ ] **T-08-02-01**: `{tool}_{version}_checksums.txt` 形式にフォールバックする
  - Target: `resolve_assets`
  - Scenario: Given `checksums.txt` がなく `actionlint_1.7.7_checksums.txt` がある、When `resolve_assets` を呼び出す
  - Expected: Then stdout の2行目の URL に `actionlint_1.7.7_checksums.txt` が含まれる

#### T-08-03: ARCH_CANDIDATES の第1候補が存在せず第2候補で一致する場合

- [ ] **T-08-03-01**: amd64 がなく x64 がある場合に x64 が ARCH_SUFFIX として採用される
  - Target: `resolve_assets`
  - Scenario: Given アセット一覧に `linux_amd64.tar.gz` がなく `linux_x64.tar.gz` がある、When `resolve_assets` を ARCH_CANDIDATES=`[amd64,x64]` で呼び出す
  - Expected: Then stdout の3行目が `x64` であり、1行目の URL に `x64` が含まれる

### [異常] Error Cases

#### T-08-04: ARCH_CANDIDATES がすべてアセット一覧に存在しない場合

- [ ] **T-08-04-01**: 全候補が不一致のとき ::error:: を出力して exit 2 で失敗する
  - Target: `resolve_assets`
  - Scenario: Given アセット一覧に amd64・x64 どちらも存在しない、When `resolve_assets` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 2 で終了する

- [ ] **T-08-04-02**: GitHub API 呼び出し失敗時に exit 2 で失敗する
  - Target: `resolve_assets`
  - Scenario: Given curl が失敗する（API 接続不可）、When `resolve_assets` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 2 で終了する

- [ ] **T-08-04-03**: checksums.txt 候補が両方とも存在しない場合に exit 2 で失敗する
  - Target: `resolve_assets`
  - Scenario: Given tar.gz は存在するが checksums.txt 系ファイルがない、When `resolve_assets` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 2 で終了する

---

## T-09: download_tool

### [正常] Normal Cases

#### T-09-01: 有効な URL で tar.gz と checksums.txt をダウンロードする

- [ ] **T-09-01-01**: tar.gz が `${TOOL_NAME}.tar.gz` としてリネームされて TEMP_DIR に保存される
  - Target: `download_tool`
  - Scenario: Given DOWNLOAD_URL が有効、TEMP_DIR が存在する、When `download_tool` を呼び出す
  - Expected: Then `${TEMP_DIR}/${TOOL_NAME}.tar.gz` が存在する

- [ ] **T-09-01-02**: checksums.txt が TEMP_DIR に保存される
  - Target: `download_tool`
  - Scenario: Given CHECKSUM_URL が有効、When `download_tool` を呼び出す
  - Expected: Then `${TEMP_DIR}/checksums.txt` が存在する

### [異常] Error Cases

#### T-09-02: curl ダウンロードが失敗する場合

- [ ] **T-09-02-01**: tar.gz のダウンロード失敗時に ::error:: を出力して exit 2 で失敗する
  - Target: `download_tool`
  - Scenario: Given DOWNLOAD_URL が無効（404）、When `download_tool` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 2 で終了する

- [ ] **T-09-02-02**: checksums.txt のダウンロード失敗時に ::error:: を出力して exit 2 で失敗する
  - Target: `download_tool`
  - Scenario: Given CHECKSUM_URL が無効、When `download_tool` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 2 で終了する

---

## T-10: verify_checksum

### [正常] Normal Cases

#### T-10-01: ハッシュが一致する場合

- [ ] **T-10-01-01**: sha256sum が一致するとき exit 0 で成功する
  - Target: `verify_checksum`
  - Scenario: Given `${TOOL_NAME}.tar.gz` と checksums.txt のハッシュが一致する、When `verify_checksum` を呼び出す
  - Expected: Then exit 0 で正常終了する

### [異常] Error Cases

#### T-10-02: checksums.txt にエントリが存在しない場合

- [ ] **T-10-02-01**: 元ファイル名のエントリが grep -w で見つからないとき exit 3 で失敗する
  - Target: `verify_checksum`
  - Scenario: Given checksums.txt に `{tool}_{ver}_linux_{arch}.tar.gz` のエントリがない、When `verify_checksum` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 3 で終了する

#### T-10-03: ハッシュが一致しない場合

- [ ] **T-10-03-01**: sha256sum が不一致のとき ::error:: を出力して exit 3 で失敗する
  - Target: `verify_checksum`
  - Scenario: Given ダウンロードファイルが破損（ハッシュ不一致）、When `verify_checksum` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 3 で終了する

### [エッジケース] Edge Cases

#### T-10-04: 検索キーが元ファイル名形式であることの確認

- [ ] **T-10-04-01**: grep の検索キーがリネーム前の形式（tool_ver_linux_arch.tar.gz）である
  - Target: `verify_checksum`
  - Scenario: Given checksums.txt に `actionlint_1.7.7_linux_amd64.tar.gz` のエントリがある、When `verify_checksum` を tool=actionlint・ver=1.7.7・arch=amd64 で呼び出す
  - Expected: Then エントリが見つかり検証が成功する

- [ ] **T-10-04-02**: sha256sum の対象がリネーム後の ${TOOL_NAME}.tar.gz である
  - Target: `verify_checksum`
  - Scenario: Given TEMP_DIR に `actionlint.tar.gz`（リネーム後）が存在する、When `verify_checksum` を呼び出す
  - Expected: Then `actionlint.tar.gz` のハッシュが検証対象となる

---

## T-11: extract_install

### [正常] Normal Cases

#### T-11-01: tool-name に一致するバイナリが tar.gz 内に存在する場合

- [ ] **T-11-01-01**: バイナリが BIN_DIR に配置される
  - Target: `extract_install`
  - Scenario: Given `${TOOL_NAME}.tar.gz` 内に tool-name と一致するバイナリが存在する、When `extract_install` を呼び出す
  - Expected: Then `${BIN_DIR}/${TOOL_NAME}` が存在する

- [ ] **T-11-01-02**: 配置されたバイナリのパーミッションが 755 である
  - Target: `extract_install`
  - Scenario: Given バイナリが BIN_DIR に配置された、When パーミッションを確認する
  - Expected: Then ファイルのパーミッションが 755（rwxr-xr-x）である

### [異常] Error Cases

#### T-11-02: tar.gz 内に tool-name に一致するバイナリが存在しない場合

- [ ] **T-11-02-01**: バイナリ不一致のとき ::error:: を出力して exit 4 で失敗する
  - Target: `extract_install`
  - Scenario: Given tar.gz 内に tool-name と一致するファイルがない、When `extract_install` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 4 で終了する

#### T-11-03: tar 展開が失敗する場合

- [ ] **T-11-03-01**: tar 失敗時に ::error:: を出力して exit 4 で失敗する
  - Target: `extract_install`
  - Scenario: Given `${TOOL_NAME}.tar.gz` が破損している、When `extract_install` を呼び出す
  - Expected: Then `::error::` が stderr に出力されて exit 4 で終了する

### [エッジケース] Edge Cases

#### T-11-04: BIN_DIR に同名バイナリが既に存在する場合

- [ ] **T-11-04-01**: 既存バイナリを上書きして exit 0 で成功する（冪等性）
  - Target: `extract_install`
  - Scenario: Given BIN_DIR に既に同名バイナリが存在する、When `extract_install` を呼び出す
  - Expected: Then 上書きされて exit 0 で正常終了する

---

## T-12: cleanup

### [正常] Normal Cases

#### T-12-01: TEMP_DIR が存在する状態で cleanup を呼び出す

- [ ] **T-12-01-01**: TEMP_DIR が削除される
  - Target: `cleanup`
  - Scenario: Given TEMP_DIR が存在する、When `cleanup "${TEMP_DIR}"` を呼び出す
  - Expected: Then TEMP_DIR が存在しない

- [ ] **T-12-01-02**: 成功メッセージが stdout に出力される
  - Target: `cleanup`
  - Scenario: Given TEMP_DIR が存在する、When `cleanup "${TEMP_DIR}"` を呼び出す
  - Expected: Then stdout に `✓ Cleanup completed` が出力される

### [エッジケース] Edge Cases

#### T-12-02: TEMP_DIR が既に削除済みの場合

- [ ] **T-12-02-01**: 削除済みの場合も exit 0 で成功する（冪等性）
  - Target: `cleanup`
  - Scenario: Given TEMP_DIR が既に存在しない、When `cleanup "${TEMP_DIR}"` を呼び出す
  - Expected: Then exit 0 で正常終了する

---

## T-13: setup-tool.sh

### [正常] Normal Cases

#### T-13-01: 全関数が正常終了する場合

- [ ] **T-13-01-01**: 全関数が定義された順序で呼び出される
  - Target: `setup-tool.sh`
  - Scenario: Given 全ライブラリ関数がモック化されて正常終了する、When `setup-tool.sh` を実行する
  - Expected: Then normalize_version → validate_inputs → setup_dirs → detect_arch → resolve_assets → download_tool → verify_checksum → extract_install の順で呼び出される

- [ ] **T-13-01-02**: 正常終了時に exit 0 で終了する
  - Target: `setup-tool.sh`
  - Scenario: Given 全関数が正常終了する、When `setup-tool.sh` を実行する
  - Expected: Then exit 0 で終了する

### [異常] Error Cases

#### T-13-02: 入力検証が失敗する場合

- [ ] **T-13-02-01**: repo が owner/repo 形式でないとき exit 1 で終了する
  - Target: `setup-tool.sh`
  - Scenario: Given REPO=`invalidrepo`（スラッシュなし）、When `setup-tool.sh` を実行する
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

- [ ] **T-13-02-02**: tool-version が X.Y.Z 形式でないとき exit 1 で終了する
  - Target: `setup-tool.sh`
  - Scenario: Given TOOL_VERSION=`latest`（不正形式）、When `setup-tool.sh` を実行する
  - Expected: Then `::error::` が stderr に出力されて exit 1 で終了する

#### T-13-03: 中間ステップが失敗する場合

- [ ] **T-13-03-01**: resolve_assets 失敗時に exit 2 で終了する
  - Target: `setup-tool.sh`
  - Scenario: Given resolve_assets が exit 2 で失敗するようにモック化されている、When `setup-tool.sh` を実行する
  - Expected: Then exit 2 で終了する

- [ ] **T-13-03-02**: verify_checksum 失敗時に exit 3 で終了する
  - Target: `setup-tool.sh`
  - Scenario: Given verify_checksum が exit 3 で失敗するようにモック化されている、When `setup-tool.sh` を実行する
  - Expected: Then exit 3 で終了する

### [エッジケース] Edge Cases

#### T-13-04: cleanup が必ず実行されることの確認

- [ ] **T-13-04-01**: 中間ステップ失敗後も trap により cleanup が実行される
  - Target: `setup-tool.sh`
  - Scenario: Given download_tool が exit 2 で失敗する、When `setup-tool.sh` を実行する
  - Expected: Then `cleanup "${TEMP_DIR}"` が EXIT trap により実行される

---

<!--
Task ID Format: T-<TestTarget>-<Scenario>-<Case>
- TestTarget: 2-digit (01, 02, ...)
- Scenario: 2-digit (01, 02, ...)
- Case: 2-digit (01, 02, ...)
-->
