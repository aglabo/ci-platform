---
title: "Requirements: setup-tool Composite Action"
module: "composite-action/setup-tool"
status: Draft
version: 1.0.4
created: "2026-03-22"
---

<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/max-comma -->
<!-- markdownlint-disable line-length -->

> **Normative Statement**
> This document defines binding requirements.
> Implementations MUST conform to this document.
> RFC 2119 keywords apply to this document only.

## 1. Overview

### 1.1 Purpose

GitHub Actions ワークフローから指定したツールの指定バージョンを GitHub Releases よりダウンロード・検証・インストールし、後続ステップから利用可能にする Composite Action を提供する。

### 1.2 Scope

- GitHub Actions Composite Action (`action.yml`) の作成
- `asset-template` による動的アセット URL 生成（URL 組み立てロジックは `url-builder` ライブラリに委譲）
- `checksum-template` によるチェックサムファイル名の指定（デフォルト: `checksums.txt` + オーバーライド）
- `runner.os` からの OS 自動解決（`Linux`→`linux` 固定、それ以外はエラー）
- `runner.arch` からのアーキテクチャ自動解決（`X64`→`amd64`、`ARM64`→`arm64` の 2 系統のみ、それ以外はエラー）
- SHA256 チェックサム検証 + 署名検証（Linux 限定、`checksum.lib.sh` にライブラリ化）
- `${RUNNER_TEMP}/bin` へのバイナリインストールと PATH 追加
- outputs: `install-path`, `tool-version`

**Out of Scope**:

- パッケージマネージャ経由のインストール (apt, brew 等)
- tar.gz 以外のアーカイブ形式
- macOS / Windows ランナーでの動作保証
- インストール先ディレクトリのカスタマイズ
- URL 組み立てロジックの直接実装（`url-builder` ライブラリに委譲）

## 2. Context

- Target Environment: GitHub Actions runner (Linux ubuntu-latest)
- Related Components:
  - `.github/actions/setup-tool/scripts/setup-directories.sh` (既存)
  - `.github/actions/setup-tool/scripts/download-tool.sh` (既存、url-builder 利用に改修)
  - `.github/actions/setup-tool/scripts/verify-checksum.sh` (既存、checksum ライブラリ利用に改修)
  - `.github/actions/setup-tool/scripts/extract-install.sh` (既存)
  - `.github/actions/setup-tool/scripts/cleanup.sh` (既存)
  - `.github/actions/setup-tool/scripts/_libs/common.lib.sh` (既存、`resolve_os()`, `resolve_arch()` 追加)
  - `.github/actions/setup-tool/scripts/_libs/url-builder.lib.sh` (新規)
  - `.github/actions/setup-tool/scripts/_libs/checksum.lib.sh` (新規)
  - `.github/actions/setup-tool/scripts/_libs/logging.lib.sh` (新規)
  - `.github/actions/setup-tool/scripts/_libs/validation.lib.sh` (新規)
- Assumptions:
  - GitHub Releases の tar.gz 形式アーカイブ（単一バイナリを含む）
  - `sha256sum`、`curl`、`tar` コマンドが Linux ランナーで利用可能
  - checksums ファイルのフォーマットは `<hash>  <filename>` 形式（sha256sum 標準形式）
  - リリースタグは `v{x}.{y}.{z}` 形式（例: `v1.7.10`）
  - `normalize_version()` は `{x}.{y}.{z}` 形式の数字のみを返す（v プレフィックスなし）

### Library Architecture

```text
_libs/common.lib.sh        normalize_version(), resolve_os(), resolve_arch()
_libs/url-builder.lib.sh   build_asset_filename(), build_checksum_filename(),
                           build_download_url(), build_checksum_url()
_libs/checksum.lib.sh      get_expected_checksum(), calc_actual_checksum(),
                           verify_checksum()
_libs/logging.lib.sh       log_info(), log_error(), log_success()
_libs/validation.lib.sh    validate_required_var(), validate_version_format(),
                           validate_template_nonempty(), validate_symbol(),
                           validate_file_exists(), validate_dir_exists()
```

### System Context Diagram

```text
[CI Workflow Job ] --> +------------------------+ --> [GitHub Releases API  ]
[action inputs   ] --> |   setup-tool action    | <-- [tool tar.gz + checksums]
[runner.os (auto)] --> |  (Composite Action)    |
[runner.arch(auto)] --> +------------------------+
                                   |
                                   v
                        [${RUNNER_TEMP}/bin + PATH]
                        (tool binary available to job)
```

## 3. Design Decisions (Summary)

| ID    | Decision                                                     | Linked Record            |
| ----- | ------------------------------------------------------------ | ------------------------ |
| DR-01 | asset_template で動的 URL 生成（固定パターン廃止）           | decision-record.md#DR-01 |
| DR-02 | checksum_template デフォルトは `checksums.txt`               | decision-record.md#DR-02 |
| DR-03 | `{os}` は runner.os から自動解決（入力不要）                 | decision-record.md#DR-03 |
| DR-04 | インストール先を `${RUNNER_TEMP}/bin` に固定（セキュリティ） | decision-record.md#DR-04 |
| DR-05 | URL組み立てロジックを `url-builder` ライブラリとして分離     | decision-record.md#DR-05 |
| DR-06 | `sha256sum` を Linux 限定とし、macOS フォールバックなし      | decision-record.md#DR-06 |
| DR-07 | `{arch_suffix}` は runner.arch から自動解決（入力不要）      | decision-record.md#DR-07 |
| DR-08 | スクリプト分離とコーディングスタイルの MUST 化               | decision-record.md#DR-08 |
| DR-09 | 入力バリデーション要件の追加（tool-version, asset-template） | decision-record.md#DR-09 |
| DR-10 | 5ライブラリ構成の確定と `resolve_os/arch` の common への配置 | decision-record.md#DR-10 |

## 4. Functional Requirements

### REQ-F-001: ランナー環境からの OS・アーキテクチャ自動解決

- EARS Type: event-driven

```text
GIVEN GitHub Actions Linux ランナーで action が実行されている状態で
  WHEN action が起動される
THEN the system SHALL runner.os を Linux→linux に変換して `{os}` を解決し、
     runner.arch を X64→amd64、ARM64→arm64 に変換して `{arch_suffix}` を解決する。
     runner.os が Linux 以外、または runner.arch が X64/ARM64 以外の場合は
     エラーコード 1 で終了する。
```

**実装**: `common.lib.sh` の `resolve_os()`, `resolve_arch()` を使用する。

**Rationale**: 対象環境は Linux 固定、アーキテクチャは X64/ARM64 の 2 系統のみ。未対応環境を明示的にエラーとすることで、サイレントな誤動作を防ぐ。`resolve_os/arch` は URL 組み立て以外でも汎用的に使用できるため `common.lib.sh` に配置する。

**Acceptance Criteria**:

| AC ID  | Scenario                                                                          |
| ------ | --------------------------------------------------------------------------------- |
| AC-001 | Linux X64 ランナーで `{os}` が "linux"、`{arch_suffix}` が "amd64" に解決される   |
| AC-002 | Linux ARM64 ランナーで `{os}` が "linux"、`{arch_suffix}` が "arm64" に解決される |
| AC-025 | runner.arch が X64/ARM64 以外（例: X86）の場合にエラーコード 1 で終了する         |

---

### REQ-F-002: url-builder ライブラリによる URL 組み立て

- EARS Type: event-driven

```text
GIVEN tool-name、tool-version、repo、asset-template、checksum-template が提供された状態で
  WHEN url-builder ライブラリが呼び出される
THEN the system SHALL 以下を生成する:
     - asset ファイル名: asset-template 内の {tool_name}, {tool_version}, {os}, {arch_suffix} を解決した文字列
     - checksum ファイル名: checksum-template 内の {tool_name}, {tool_version}, {arch_suffix} を解決した文字列
     - ダウンロード URL: https://github.com/{repo}/releases/download/v{normalized_version}/{asset_filename}
     - チェックサム URL: https://github.com/{repo}/releases/download/v{normalized_version}/{checksum_filename}
     ここで {normalized_version} は normalize_version() による正規化後の値とする。
```

**実装**: `url-builder.lib.sh` の `build_asset_filename()`, `build_checksum_filename()`, `build_download_url()`, `build_checksum_url()` を使用する。`{repo}` は `org/repo` 形式（例: `rhysd/actionlint`）とする。

**Rationale**: URL 組み立てロジックを分離することで単体テスト可能にし、download-tool.sh から再利用できる。`v` プレフィックスは `normalize_version()` で除去後に URL 構築時に付与する。

**Acceptance Criteria**:

| AC ID  | Scenario                                                                                                         |
| ------ | ---------------------------------------------------------------------------------------------------------------- |
| AC-003 | `asset_template="{tool_name}_{tool_version}_linux_{arch_suffix}.tar.gz"` で actionlint の正しい URL が生成される |
| AC-004 | `checksum_template="checksums.txt"` でチェックサム URL が正しく生成される                                        |
| AC-005 | `tool-version=v1.7.10` 入力時、ダウンロード URL に `v1.7.10` が含まれる                                          |

---

### REQ-F-003: checksum-template のデフォルト動作

- EARS Type: feature-based

```text
GIVEN action が起動された状態で
  WHERE checksum-template input が省略されている
THEN the system SHALL checksum-template として `checksums.txt` を使用する。
```

**Rationale**: `checksums.txt` は多くのツールで標準的なファイル名として使われており、省略時の有用なデフォルト。ghalint 形式（`{tool_name}_{tool_version}_checksums.txt`）等は明示指定でオーバーライドする。

**Acceptance Criteria**:

| AC ID  | Scenario                                                                                                                  |
| ------ | ------------------------------------------------------------------------------------------------------------------------- |
| AC-006 | checksum-template を省略した場合、チェックサムファイル名が `checksums.txt` になる                                         |
| AC-007 | `checksum_template="{tool_name}_{tool_version}_checksums.txt"` 指定時、ghalint のチェックサムファイル名が正しく解決される |

---

### REQ-F-004: checksums ファイルのパースと SHA256 照合

- EARS Type: event-driven

```text
GIVEN Linux ランナーで sha256sum コマンドが実行可能な状態で
  WHEN verify-checksum ステップが実行される
THEN the system SHALL 以下を順に実行する:
     1. checksums ファイルを `<hash>  <filename>` 形式（sha256sum 標準形式）としてパースする
     2. 対象ファイル名に一致する行から期待ハッシュ値を取得する
        エントリが存在しない場合はエラーコード 3 で終了する
     3. sha256sum コマンドで実際の SHA256 を計算する
     4. 期待値と照合し、不一致の場合はエラーコード 3 で終了する
```

**実装**: `checksum.lib.sh` の `get_expected_checksum()`, `calc_actual_checksum()`, `verify_checksum()` を使用する。checksums ファイルのフォーマットは `<hash>  <filename>` 形式（sha256sum 標準出力形式）に限定する。

**Rationale**: checksums フォーマットを `sha256sum` 標準形式に固定することで、パース実装をシンプルかつ確実にする。フォーマットが異なるツールはスコープ外とし、将来の拡張は spec フェーズで別途設計する。

**Acceptance Criteria**:

| AC ID  | Scenario                                                                              |
| ------ | ------------------------------------------------------------------------------------- |
| AC-008 | チェックサムが一致する場合にインストールが続行される                                  |
| AC-009 | チェックサムが不一致の場合にエラーコード 3 で停止する                                 |
| AC-010 | checksums ファイルに対象ファイルのエントリが存在しない場合にエラーコード 3 で停止する |

---

### REQ-F-012: バイナリ同一性検証（verify-identity）

- EARS Type: event-driven

```text
GIVEN ダウンロードが完了し、checksums ファイルと署名ファイルが取得された状態で
  WHEN verify-identity ステップが実行される
THEN the system SHALL 以下を順に実行する:
     1. REQ-F-004 に従い SHA256 チェックサムを照合する
     2. 署名検証を実行し、検証失敗の場合はエラーコード 3 で終了する
     いずれかの検証に失敗した場合、後続のインストールステップは実行されない。
```

**実装**: `checksum.lib.sh` を verify-identity の統合エントリポイントとして使用する。SHA256 照合と署名検証を独立した関数として実装し、それぞれ単体でテスト可能にする。

**Rationale**: SHA256 だけでは「正規リリースからの配布」を保証できない（リポジトリ侵害時に checksums.txt も同時改ざん可能）。署名検証を加えることで supply chain attack に対する防御層を増やす。2 つの検証を `verify-identity` として 1 ステップに統合することで、action.yml のフロー管理をシンプルに保つ。

**Note**: 署名検証の信頼アンカー設計（公開鍵配布元・署名対象・鍵ローテーション）は Open Question (Section 10) として spec フェーズで決定する。

**Acceptance Criteria**:

| AC ID  | Scenario                                                                    |
| ------ | --------------------------------------------------------------------------- |
| AC-028 | SHA256 照合・署名検証の両方が成功した場合にインストールが続行される         |
| AC-029 | 署名検証が失敗した場合にエラーコード 3 で停止し、インストールが実行されない |

---

### REQ-F-005: ダウンロード失敗時のエラーハンドリング

- EARS Type: event-driven

```text
GIVEN download-tool ステップが実行されている状態で
  WHEN curl によるダウンロードが失敗する（404、ネットワークエラー等）
THEN the system SHALL エラーコード 2 で終了し、失敗した URL を含むエラーメッセージを出力する。
```

**実装**: エラーメッセージは `logging.lib.sh` の `log_error()` を使用する。

**Acceptance Criteria**:

| AC ID  | Scenario                                                      |
| ------ | ------------------------------------------------------------- |
| AC-011 | 存在しないバージョンを指定した場合にエラーコード 2 で停止する |

---

### REQ-F-006: バイナリのインストールと PATH 追加

- EARS Type: event-driven

```text
GIVEN チェックサム検証が成功した状態で
  WHEN extract-install ステップが実行される
THEN the system SHALL 以下を順に実行する:
     1. tar.gz を TEMP_DIR に展開する
     2. 展開物から tool-name と一致するファイルを特定する
     3. そのファイルを `${RUNNER_TEMP}/bin/<tool-name>` として 755 権限でインストールする
     4. `${RUNNER_TEMP}/bin` を GITHUB_PATH に追加する
     tool-name と一致するファイルが存在しない場合はエラーコード 4 で終了する。
```

**実装**: `extract-install.sh` を関数化し、各ステップを独立してテスト可能にする。

**Rationale**: インストール先バイナリ名を `tool-name` に正規化することで、tar.gz 内のディレクトリ構造（例: `actionlint_1.7.10_linux_amd64/actionlint`）に依存せず確実にインストールできる。インストール先を `${RUNNER_TEMP}/bin` に固定することで、システムディレクトリへの書き込みリスクを排除する。

**Acceptance Criteria**:

| AC ID  | Scenario                                                                                                      |
| ------ | ------------------------------------------------------------------------------------------------------------- |
| AC-012 | インストール後に `${RUNNER_TEMP}/bin/<tool-name>` として後続ステップからツールが実行可能である                |
| AC-013 | 同一ジョブで本 action を複数回呼び出した場合、2回目以降も正常にインストールされる（冪等性）                   |
| AC-026 | tar.gz 内のディレクトリ構造に関わらず、`tool-name` のバイナリが `${RUNNER_TEMP}/bin/<tool-name>` に配置される |
| AC-027 | tar.gz 内に tool-name と一致するファイルが存在しない場合にエラーコード 4 で終了する                           |

---

### REQ-F-007: outputs の提供

- EARS Type: event-driven

```text
GIVEN インストールが正常完了した状態で
  WHEN action が終了する
THEN the system SHALL install-path（`${RUNNER_TEMP}/bin`）と
     tool-version（normalize_version() による正規化後の X.Y.Z 形式、v プレフィックスなし）を
     outputs として提供する。
```

**実装**: tool-version の正規化は `common.lib.sh` の `normalize_version()` を使用する。

```text
```

**Acceptance Criteria**:

| AC ID  | Scenario                                                              |
| ------ | --------------------------------------------------------------------- |
| AC-014 | install-path が `${RUNNER_TEMP}/bin` を返す                           |
| AC-015 | `tool-version=v1.7.10` 入力時、tool-version output が `1.7.10` を返す |
| AC-016 | `tool-version=1.7` 入力時、tool-version output が `1.7.0` を返す      |

---

### REQ-F-008: 一時ファイルのクリーンアップ

- EARS Type: state-driven

```text
GIVEN action のすべてのステップが完了または失敗した状態で
  WHILE cleanup ステップが `if: always()` 条件で実行される
THEN the system SHALL TEMP_DIR を削除し、ランナーの一時領域を解放する。
```

**Acceptance Criteria**:

| AC ID  | Scenario                                         |
| ------ | ------------------------------------------------ |
| AC-017 | 成功時に TEMP_DIR が削除される                   |
| AC-018 | ダウンロード失敗時でもクリーンアップが実行される |

---

### REQ-F-009: セキュリティ制約（インストール先固定）

- EARS Type: unwanted behavior

```text
GIVEN action が実行されている状態で
  NOT DO インストール先ディレクトリをユーザー入力で変更する
THEN the system SHALL インストール先を常に `${RUNNER_TEMP}/bin` に固定する。
```

**Rationale**: ユーザーが任意パスを指定できると `/usr/local/bin` 等のシステムディレクトリへの書き込みリスクが生じる。

---

### REQ-F-010: 入力値バリデーション

- EARS Type: event-driven

```text
GIVEN action が起動された状態で
  WHEN 以下のいずれかの条件に該当する場合:
     (a) tool-version が X、X.Y、X.Y.Z 形式（v プレフィックス任意）以外
     (b) asset-template が空文字または未指定
     (c) tool-name が ^[a-z][a-z0-9_-]*$ パターン以外の文字を含む
THEN the system SHALL エラーメッセージを出力してエラーコード 1 で終了する。
```

**実装**: `validation.lib.sh` の各関数を使用:

- `validate_version_format()`: (a) の検証、`normalize_version()` と連携
- `validate_template_nonempty()`: (b) の検証
- `validate_symbol()`: (c) の検証、パターン `^[a-z][a-z0-9_-]*$`（先頭英小文字必須、以降は英小文字・数字・ハイフン・アンダースコア）

**Rationale**: GitHub のバイナリ命名規則では数字始まり・記号始まりは存在しないため、`^[a-z][a-z0-9_-]*$` で十分かつ安全。repo バリデーション（org/repo 形式）は REQ-F-011 に一本化。早期バリデーションにより curl 失敗より前に設定ミスを検出できる。

**Acceptance Criteria**:

| AC ID  | Scenario                                                          |
| ------ | ----------------------------------------------------------------- |
| AC-019 | `tool-version=latest` 指定時にエラーコード 1 で停止する           |
| AC-020 | `asset-template` 未指定時にエラーコード 1 で停止する              |
| AC-021 | `tool-name=MyTool`（大文字含む）指定時にエラーコード 1 で停止する |
| AC-022 | `repo=rhysd/actionlint` 指定時にバリデーションを通過する          |

---

### REQ-F-011: `repo` 形式バリデーション

- EARS Type: event-driven

```text
GIVEN action が起動された状態で
  WHEN repo input が `org/repo` 形式（スラッシュ区切り、各部分が ^[a-z][a-z0-9_-]*$ に適合）以外の場合
THEN the system SHALL エラーメッセージを出力してエラーコード 1 で終了する。
```

**実装**: `validation.lib.sh` の `validate_symbol()` を `/` で分割した org 部・repo 部それぞれに適用する。

**Acceptance Criteria**:

| AC ID  | Scenario                                                                     |
| ------ | ---------------------------------------------------------------------------- |
| AC-023 | `repo=rhysd/actionlint` が正常に通過する                                     |
| AC-024 | `repo=ActionLint`（スラッシュなし・大文字）指定時にエラーコード 1 で停止する |

---

## 5. Non-Functional Requirements

### REQ-NF-001: セキュリティ

インストール先は `${RUNNER_TEMP}/bin` に固定し、外部から変更不可能とする。ダウンロードしたすべてのバイナリは SHA256 検証を必須とする。

### REQ-NF-002: 信頼性

ダウンロード失敗（ネットワークエラー、リリース不存在）およびチェックサム不一致の場合、失敗の理由に応じたエラーコードと `::error::` プレフィックスのエラーメッセージで失敗する。

### REQ-NF-003: 保守性（MUST）

各処理フェーズはスクリプト単位で 1 責任となるよう分離し、ライブラリ関数は単体でテスト可能にする。ライブラリは以下の 5 構成:

- `common.lib.sh`: `normalize_version()`, `resolve_os()`, `resolve_arch()`
- `url-builder.lib.sh`: URL・ファイル名組み立て関数群
- `checksum.lib.sh`: チェックサム取得・計算・検証関数群
- `logging.lib.sh`: `log_info()`, `log_error()`, `log_success()`
- `validation.lib.sh`: 入力バリデーション関数群（`validate_symbol()` 含む）

### REQ-NF-004: 互換性（MUST）

`validate-environment` action の実装パターンに必ず準拠すること:

- ステップ内のスクリプト呼び出し: `bash "${GITHUB_ACTION_PATH}/scripts/<name>.sh"`
- パラメータ渡し: `env:` ブロック使用
- シェル指定: `shell: bash` の明示

## 6. Constraints

### REQ-C-001: Linux 限定

GitHub Actions の Ubuntu ランナー（ubuntu-latest、ubuntu-22.04 等）を対象とする。macOS・Windows ランナーはスコープ外とする。`sha256sum` コマンドに依存するため macOS フォールバックは提供しない。

### REQ-C-002: tar.gz 形式限定

ダウンロード対象は tar.gz 形式のアーカイブのみとする。zip 等の他形式はスコープ外とする。

### REQ-C-003: GitHub Releases 限定

ダウンロード元は GitHub Releases（`https://github.com/{repo}/releases/download/v{tool_version}/`）に限定する。`{repo}` は `org/repo` 形式（例: `rhysd/actionlint`）とする。GitHub Releases の tag は `v{x}.{y}.{z}` 形式（例: `v1.7.10`）を前提とする。`v` プレフィックスなしのタグを使用するツールは本 action のスコープ外とする。

### REQ-C-004: 最小権限

action に必要な GitHub permissions は `contents: read` のみとする。

## 7. User Stories

- US-01: CI ワークフロー作者として、actionlint のバージョンを指定してインストールしたい。なぜなら、ワークフロー品質チェックを再現可能な環境で実行したいから。（→ REQ-F-002, REQ-F-006）
- US-02: CI ワークフロー作者として、betterleaks のような非標準命名のチェックサムにも対応したい。なぜなら、ツールごとに異なるチェックサムファイル名に個別対応したくないから。（→ REQ-F-003）
- US-03: セキュリティ担当者として、ダウンロードしたバイナリが改ざんされていないことを確認したい。なぜなら、supply chain attack を防ぎたいから。（→ REQ-F-004）
- US-04: CI ワークフロー作者として、OS・アーキテクチャを指定せずに action を使いたい。なぜなら、runner 環境に応じた設定ミスを防ぎたいから。（→ REQ-F-001）
- US-05: CI ワークフロー作者として、インストール後のバージョンを後続ステップで参照したい。なぜなら、インストールされたバージョンをログやアーティファクトに記録したいから。（→ REQ-F-007）

## 8. Acceptance Criteria

> 代表的なシナリオを記載する。全 AC の定義は Section 9 Traceability を参照。

```gherkin
# AC-003: asset_template で actionlint の URL が正しく生成される
# Requirement: REQ-F-002
Scenario: 標準テンプレートで actionlint の URL が正しく生成される
  Given tool-name=actionlint, tool-version=1.7.10, repo=rhysd/actionlint
  And   asset-template="{tool_name}_{tool_version}_linux_{arch_suffix}.tar.gz"
  And   runner.os=Linux, runner.arch=X64
  When  url-builder ライブラリが呼び出される
  Then  ダウンロード URL が "https://github.com/rhysd/actionlint/releases/download/v1.7.10/actionlint_1.7.10_linux_amd64.tar.gz" になる

# AC-001: Linux X64 ランナーでの環境変数自動解決
# Requirement: REQ-F-001
Scenario: Linux X64 ランナーで OS・アーキテクチャが自動解決される
  Given runner.os が "Linux" で runner.arch が "X64" である
  When  action が起動される
  Then  {os} が "linux" に、{arch_suffix} が "amd64" に解決される

# AC-008: チェックサムが一致する場合にインストールが続行される
# Requirement: REQ-F-004
Scenario: チェックサムが一致する場合にインストールが続行される
  Given ダウンロード済み tar.gz と checksums.txt が TEMP_DIR に存在する
  When  verify-checksum ステップが実行される
  Then  SHA256 が一致し、後続の extract-install ステップが実行される

# AC-009: チェックサムが不一致の場合にエラーで停止する
# Requirement: REQ-F-004
Scenario: チェックサムが不一致の場合にエラーで停止する
  Given 改ざんされた tar.gz が TEMP_DIR に存在する
  When  verify-checksum ステップが実行される
  Then  エラーコード 3 で action が失敗し、後続ステップは実行されない

# AC-019: tool-version に無効な値を指定した場合
# Requirement: REQ-F-010
Scenario: tool-version に "latest" を指定した場合にエラーで停止する
  Given tool-version="latest" が指定されている
  When  action が起動される
  Then  エラーコード 1 で action が失敗する

# AC-018: ダウンロード失敗時でもクリーンアップが実行される
# Requirement: REQ-F-008
Scenario: ダウンロード失敗時でもクリーンアップが実行される
  Given ネットワークエラーでダウンロードが失敗した
  When  cleanup ステップが if: always() で実行される
  Then  TEMP_DIR が削除される
```

## 9. Traceability

| REQ ID     | AC IDs                         | Type           |
| ---------- | ------------------------------ | -------------- |
| REQ-F-001  | AC-001, AC-002, AC-025         | Functional     |
| REQ-F-002  | AC-003, AC-004, AC-005         | Functional     |
| REQ-F-003  | AC-006, AC-007                 | Functional     |
| REQ-F-004  | AC-008, AC-009, AC-010         | Functional     |
| REQ-F-005  | AC-011                         | Functional     |
| REQ-F-006  | AC-012, AC-013, AC-026, AC-027 | Functional     |
| REQ-F-007  | AC-014, AC-015, AC-016         | Functional     |
| REQ-F-008  | AC-017, AC-018                 | Functional     |
| REQ-F-009  | —                              | Functional     |
| REQ-F-010  | AC-019, AC-020, AC-021, AC-022 | Functional     |
| REQ-F-011  | AC-023, AC-024                 | Functional     |
| REQ-NF-001 | —                              | Non-Functional |
| REQ-NF-002 | —                              | Non-Functional |
| REQ-NF-003 | —                              | Non-Functional |
| REQ-NF-004 | —                              | Non-Functional |
| REQ-C-001  | —                              | Constraint     |
| REQ-C-002  | —                              | Constraint     |
| REQ-C-003  | —                              | Constraint     |
| REQ-C-004  | —                              | Constraint     |
| REQ-F-012  | AC-028, AC-029                 | Functional     |

## 10. Open Questions

| Question                                                                                                                  | Type     | Impact Area | Owner | Status                                                   |
| ------------------------------------------------------------------------------------------------------------------------- | -------- | ----------- | ----- | -------------------------------------------------------- |
| ~~GitHub Releases の tag が `v` プレフィックスなし形式のツールへの対応方針（現在は `v{tool_version}` 固定）~~             | スコープ | REQ-C-003   | —     | クローズ: `v{x}.{y}.{z}` 固定とし、非対応は Out of Scope |
| 署名検証の信頼アンカー設計: 公開鍵の配布元・固定方法、署名対象（asset 本体か checksums.txt か）、鍵ローテーション時の扱い | 設計     | REQ-F-004   | TBD   | Open                                                     |

## 11. Change History

| Date       | Version | Description                                                                                                                                                                                                                                                                         |
| ---------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-03-22 | 1.0.0   | Initial release                                                                                                                                                                                                                                                                     |
| 2026-03-22 | 1.1.0   | review(explore)反映: url-builder ライブラリ分離、Linux 限定明記、checksum デフォルト `checksums.txt`、arch_suffix 自動解決追加、ダウンロードエラー要件追加                                                                                                                          |
| 2026-03-22 | 1.2.0   | review(harden)反映: REQ-NF-003/004 MUST昇格、REQ-F-010/011 新規追加、5ライブラリ構成確定（checksum.lib.sh追加、resolve_os/arch をcommonへ）、validate_symbol() パターン確定                                                                                                         |
| 2026-03-22 | 1.3.0   | review(fix)反映: input 参照をケバブケースに統一（asset-template/checksum-template）、REQ-F-010(c) から repo 除外し REQ-F-011 に一本化、REQ-F-007 に normalize_version() 参照追加、AC-005 説明明確化、Section 8 注記追加、Typo 修正                                                  |
| 2026-03-22 | 1.4.0   | codex-review 反映: OS=Linux 固定・arch=X64/ARM64 限定の明示エラー化（AC-025 追加）、checksums フォーマットを `<hash>  <filename>` 形式に固定、単一バイナリ前提をREQ-F-006に追加、`v{x}.{y}.{z}` タグ固定・非対応を Out of Scope 明記、署名検証 Open Question 追加、Assumptions 強化 |
| 2026-03-22 | 1.5.0   | spec 構造設計に向けた要件精緻化: REQ-F-006 にインストール先バイナリ名 `<tool-name>` 正規化・エラーコード 4・AC-026/027 追加、REQ-F-004 を checksum parsing 専用に整理、REQ-F-012（verify-identity）新規追加（SHA256 + 署名検証の統合ステップ・AC-028/029）                          |
