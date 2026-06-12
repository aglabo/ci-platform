---
title: "Design Specification: setup-tool composite action"
based-on: requirements.md v1.0
status: Draft
---

<!-- markdownlint-disable line-length -->

## 1. Overview

### 1.1 Purpose

本仕様は `setup-tool` composite action の振る舞いを定義する。
指定された GitHub リポジトリのリリースからツールをダウンロードし、
チェックサム検証・アーカイブ展開を行い、バイナリを実行可能な PATH に配置するまでの
各ユニットの責務・前後条件・エラー処理・ユニット間のインタラクションを規定する。

### 1.2 Scope

本仕様は `setup-tool` composite action の**外部から観測可能な振る舞い**を定義する。
実装詳細（スクリプト内部ロジック・変数名・ファイル構造）は明示的にスコープ外とする。

---

## 2. Design Principles

### 2.1 Classification Philosophy

各処理ユニットは単一責務を持ち、関数として定義する。
ユニット間のインターフェースは関数呼び出しと同じ規則に従う:
入力はパラメータ（位置引数または環境変数）で渡し、結果は stdout で返す。
ファイル分割の有無に関わらず、この呼び出し規則を統一する。

**複数値返却規約**: 複数の値を返す場合は 1行 = 1値 の形式で空行を挟まずに出力する。
呼び出し元は `mapfile` または `read` で行単位にキャプチャする。

```bash
# 出力側（例: resolve_assets の3値出力）
echo "${DOWNLOAD_URL}"
echo "${CHECKSUM_URL}"
echo "${ARCH_SUFFIX}"

# 受け取り側
mapfile -t _results < <(resolve_assets "${API_URL}" "${TOOL_NAME}" "${ARCH_CANDIDATES[@]}")
DOWNLOAD_URL="${_results[0]}"
CHECKSUM_URL="${_results[1]}"
ARCH_SUFFIX="${_results[2]}"
```

<!-- impl-note: 各ユニットは bash 関数として実装し、action.yml の steps から . (ドット演算子) + 関数呼び出しで起動する。
  source は使用しない（POSIX 準拠・プロジェクト規約）。
  例: . "${GITHUB_ACTION_PATH}/scripts/arch.lib.sh" && detect_arch
  分割スクリプトの場合も: bash script.sh <args> の stdout を $() でキャプチャして次ユニットへ渡す。
  GITHUB_ENV への書き込みは「外部への副作用」として明示的に限定する（ユニット間の結果受け渡しには使わない）。-->

### 2.2 Design Assumptions

- `validate-environment` composite action が呼び出し元ワークフローで事前実行済みであること
  （アーキテクチャ・必要ツールの検証は完了済みとみなす）
- GitHub Releases は public リポジトリであり、認証トークンは不要
- ランナーは `curl` および `sha256sum` を利用可能（validate-environment で保証済み）
- URL パターン: `https://github.com/{owner}/{repo}/releases/download/v{version}/{tool-name}_{version}_linux_{arch}.tar.gz`
- スクリプトへのパス解決は `GITHUB_ACTION_PATH` を起点とした相対パスで行う（`dirname`・`realpath` は使用しない）
- `BIN_DIR` は `${RUNNER_TEMP}/bin` 固定、`TEMP_DIR` は `mktemp -d` で動的生成する

<!-- impl-note: 参考実装 C:\Users\atsushifx\workspaces\develop\.github-aglabo\.github\actions\scripts
  - スクリプト呼び出し: "${GITHUB_ACTION_PATH}/../scripts/<name>.sh"
  - 引数パターン: readonly VAR="${1:-${VAR:?Error: VAR required}}"
  - GITHUB_ENV への書き込みで後続ステップに BIN_DIR / TEMP_DIR を引き渡す -->

### 2.3 External Design Summary

> **Source**: Phase D（ユーザー確認済みデザイン）および Phase E（外部設計ダイアローグ）から導出。

#### Feature Decomposition

| Unit            | Responsibility                                                      | REQ Coverage         |
| --------------- | ------------------------------------------------------------------- | -------------------- |
| validate-inputs | repo/tool-name/tool-version の入力値検証                            | REQ-F-001            |
| detect-arch     | runner.arch から arch 候補リスト生成                                | REQ-F-002            |
| setup-dirs      | BIN_DIR/TEMP_DIR 作成・環境変数書き込み                             | REQ-F-005            |
| build-url       | GitHub Releases の tar.gz URL / checksums.txt URL を構築する        | REQ-F-003            |
| resolve-arch    | curl --head -L で候補を順に確認し使用する arch suffix を決定する    | REQ-F-002, REQ-F-003 |
| download        | tar.gz + checksums.txt のダウンロード                               | REQ-F-003            |
| verify-checksum | SHA256 ハッシュ検証                                                 | REQ-F-004            |
| extract-install | tar.gz 展開・tool-name に一致するバイナリを配置・パーミッション付与 | REQ-F-005            |
| cleanup         | 一時ディレクトリ削除（常に実行）                                    | REQ-F-006            |

<!-- impl-note:
  ライブラリ構成（B案）:
  - dirs.lib.sh    → setup-dirs ユニット（BIN_DIR=${RUNNER_TEMP}/bin, TEMP_DIR=$(mktemp -d)）
  - arch.lib.sh    → detect-arch / resolve-arch ユニット
  - download.lib.sh → build-url / download ユニット
  - install.lib.sh  → extract-install / cleanup ユニット

  スクリプト呼び出しパターン（aglabo 参考実装に準拠）:
  - ライブラリ読み込み: . "${GITHUB_ACTION_PATH}/scripts/<name>.lib.sh"  ※ source は使用しない
  - action.yml から分割スクリプト呼び出し: bash "${GITHUB_ACTION_PATH}/scripts/<name>.sh" <args>
  - 各ライブラリ関数の引数: readonly VAR="${1:-${VAR:?Error: VAR required}}"
  - ユニット間の結果受け渡し: stdout を $() でキャプチャ
  - 外部への副作用のみ GITHUB_ENV に書き込む: echo "VAR=value" >> "${GITHUB_ENV}"
-->

#### Unit Interaction Map

```text
+------------------+     +------------------+     +------------------+
|  validate-inputs | --> |  detect-arch     | --> |  setup-dirs      |
+------------------+     +------------------+     +------------------+
                                                          |
                                                          v
                                                  +------------------+
                                                  |  resolve-arch    |
                                                  +------------------+
                                                          |
                                                          v
                                                  +------------------+
                                                  |  build-url       |
                                                  +------------------+
                                                          |
                                                          v
                                                  +------------------+
                                                  |  download        |
                                                  +------------------+
                                                          |
                                                          v
                                                  +------------------+
                                                  |  verify-checksum |
                                                  +------------------+
                                                          |
                                                          v
                                                  +------------------+
                                                  |  extract-install |
                                                  +------------------+
                                                          |
                                              (if: always())
                                                          v
                                                  +------------------+
                                                  |  cleanup         |
                                                  +------------------+
```

#### Data Flow Diagram

```text
[inputs: repo, tool-name, tool-version]
          |
          v
  [validate-inputs] --失敗--> [エラー終了]
          |
          v
  [detect-arch] --> ARCH_CANDIDATES: ["amd64","x64"] or ["arm64"]
          |
          v
  [setup-dirs] --> BIN_DIR, TEMP_DIR (GITHUB_ENV/GITHUB_PATH 書き込み)
          |
          v
  [resolve-arch] --curl --head -L 順次確認--> ARCH_SUFFIX
          |         全候補失敗 --> [::error:: + exit 2]
          v
  [build-url] --> DOWNLOAD_URL, CHECKSUM_URL (stdout)
          |
          v
  [download] --> TEMP_DIR/{tool}.tar.gz, checksums.txt
          |
          v
  [verify-checksum] --不一致--> [エラー終了]
          |
          v
  [extract-install] --> BIN_DIR/{tool-name} (mode: 755, PATH に追加済み)
          |
  (if: always())
          v
  [cleanup] --> TEMP_DIR 削除済み
```

### 2.4 Non-Goals

> **Derivation**: 以下はすべて REQUIREMENTS Section "Out of Scope" に由来する。

- zip など tar.gz 以外のアーカイブ形式への対応 ← REQ: Out of Scope #1
- macOS・Windows runner への対応 ← REQ: Out of Scope #2
- チェックサム検証のスキップオプション ← REQ: Out of Scope #3
- GitHub Releases 以外のダウンロード元への対応 ← REQ: Out of Scope #4

### 2.5 Behavioral Design Decisions

| ID    | Decision                                                                                                 | Rationale                                                       | Affected Rules | Status           |
| ----- | -------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- | -------------- | ---------------- |
| DD-01 | arch 候補を複数持ち curl --head で存在確認する                                                           | リリースごとに `ARCH_SUFFIX` が統一されていないため             | R-004, R-004b  | Active           |
| DD-02 | X64 の `ARCH_CANDIDATES` は ["amd64", "x64"] の順で試行する                                              | amd64 が一般的なため先に試行する                                | R-004          | Active           |
| DD-03 | validate-environment の前提はコメント記載のみ                                                            | 責務分離・action の単純化のため                                 | R-001          | Active           |
| DD-04 | 認証トークンなし（public repo のみ対応）                                                                 | スコープを明確に限定するため                                    | R-004, R-005   | Active           |
| DD-05 | 関数ライブラリ式・複数ファイル構成（4ファイル）                                                          | 可読性・テスト容易性・責務分離のため                            | 全ユニット     | Active           |
| DD-06 | スクリプト間インターフェースを関数呼び出しと同規則に統一する                                             | 実装形態（関数/スクリプト）によらず呼び出し規則を一貫させるため | 全ユニット     | Active           |
| DD-07 | tool-version は X.Y.Z 形式の明示的なバージョン文字列のみ受け付ける。デフォルト値は action.yml が保持する | 再現可能なビルド保証（REQ-NF-002）・呼び出し元の利便性のため    | R-001          | Promoted → DR-07 |
| DD-08 | checksums.txt のエントリ検索は grep -w による完全一致とする                                              | aglabo 参考実装との一貫性・単純さのため                         | R-006          | Promoted → DR-07 |
| DD-09 | repo の有効形式を [a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+ パターンとして定義                                     | テスト可能性（REQ-NF-004）のため                                | R-001          | Promoted → DR-06 |

### 2.6 Related Decision Records

| DR-ID | Title                                                           | Phase         | Impact on This Spec                             |
| ----- | --------------------------------------------------------------- | ------------- | ----------------------------------------------- |
| DR-01 | アーキテクチャは runner.arch から自動検出                       | req           | detect-arch / resolve-arch の設計根拠           |
| DR-02 | チェックサム検証は必須（スキップ不可）                          | req           | verify-checksum は常に実行                      |
| DR-03 | Linux (tar.gz) のみ対応                                         | req           | extract-install の対象形式を限定                |
| DR-04 | repo は owner/repo 形式で呼び出し元が明示                       | req           | validate-inputs の検証ルールを規定              |
| DR-05 | 関数ライブラリ式の新規実装                                      | req           | 全ユニットの実装方針を規定                      |
| DR-06 | 関数ライブラリ式実装・入力検証ルール・スクリプト間 I/F の規範化 | review-harden | R-001 の検証パターン確定・スクリプト間 I/F 統一 |
| DR-07 | バージョン形式と checksums.txt 検索方式の確定                   | review-harden | R-001 の version 検証・R-006 の検索ロジック確定 |

### 2.7 DD to DR Promotion Criteria

> **Purpose**: DD → DR 昇格の判断基準。昇格は人間の判断による。

**昇格を検討する条件:**

1. **複数仕様への影響** — 複数のモジュールや仕様に影響する決定
2. **アーキテクチャ上の重要性** — 将来の設計選択を制約する決定
3. **重要な代替案の存在** — 複数の有効な選択肢が存在した
4. **ステークホルダーへの可視性** — 外部レビューが必要な決定

**DD のままにする条件:**

- 本仕様のみに局所的な決定
- 代替案が存在しない
- 理由が文脈から自明

---

## 3. Behavioral Specification

### 3.1 Input Domain

- 入力: `repo`（`owner/repo` 形式）、`tool-name`（英数字・ハイフン）、`tool-version`（`X.Y.Z` 形式の明示的なバージョン文字列）
- `tool-version` は呼び出し元が明示的に指定する。`latest`・`stable` などの特殊形式は受け付けない
- `tool-version` のデフォルト値は `action.yml` の `inputs.tool-version.default` として定義する
- 前提: `validate-environment` action が事前に実行済みであること

<!-- impl-note: tool-version は "v" プレフィックスを normalize_version() で除去してから使用する -->

### 3.2 Output Semantics

- 成功: `tool-name` バイナリが PATH から実行可能な状態になる
- 失敗: 各ユニットがエラーメッセージを所定の形式で出力しステップを非ゼロ終了する
- 常時: cleanup ユニットが実行され、一時ディレクトリが削除される

#### エラー出力規則

既存の `validate-environment` action および `setup-tool` 参考スクリプトに統一した形式を採用する。

| 種別             | 形式                 | 出力先          |
| ---------------- | -------------------- | --------------- |
| エラーメッセージ | `::error::<message>` | stderr（`>&2`） |
| 成功メッセージ   | `✓ <message>`        | stdout          |
| 進捗メッセージ   | `<message>`          | stdout          |

exit code は処理フェーズごとに固定値を割り当てる:

| exit code | 意味                       | 対応ユニット                             |
| --------- | -------------------------- | ---------------------------------------- |
| 0         | 成功                       | 全ユニット                               |
| 1         | 入力検証エラー・一般エラー | validate-inputs, detect-arch, setup-dirs |
| 2         | ダウンロード失敗           | resolve-arch, download                   |
| 3         | チェックサム検証失敗       | verify-checksum                          |
| 4         | 展開・配置失敗             | extract-install                          |

<!-- impl-note: エラー出力は既存の validation.lib.sh の validate_symbol() と同じく
  echo "::error::${field}: ${message}" >&2; return 1 パターンを使用する -->

---

## 4. Decision Rules

評価はこの順序で実施しなければならない。順序の変更は禁止する。

| Rule ID | Step | Condition / Action                                                                                                                                                                                                               | Outcome                                                        |
| ------- | ---: | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| R-001   |    1 | WHEN action が呼び出されたとき: repo が `[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+` に一致し、tool-name が非空、tool-version が `X.Y.Z` 形式（`latest` 等の特殊形式は不正）か。tool-version 未指定時は action.yml のデフォルト値を使用する | 不正 → `::error::` を stderr に出力して exit 1                 |
| R-002   |    2 | WHEN R-001 が成功したとき: runner.arch が X64 か ARM64 か                                                                                                                                                                        | X64→["amd64","x64"] / ARM64→["arm64"] / 未知→exit 1            |
| R-003   |    3 | WHEN R-002 が成功したとき: BIN_DIR（`${RUNNER_TEMP}/bin`）と TEMP_DIR（`mktemp -d`）を作成し GITHUB_ENV/GITHUB_PATH に書き込む                                                                                                   | 失敗 → `::error::` を stderr に出力して exit 1                 |
| R-004   |    4 | WHEN R-003 が成功したとき: ARCH_CANDIDATES を順に curl --head -L で確認し、結果を stdout に出力する                                                                                                                              | 最初の 200 → ARCH_SUFFIX を stdout 出力 / 全失敗 → exit 2      |
| R-004b  |    5 | WHEN R-004 が成功したとき: `ARCH_SUFFIX`・`repo`・`tool-name`・`tool-version` を入力として受け取り tar.gz URL と checksums.txt URL を stdout に出力する                                                                          | URL 文字列を stdout 出力                                       |
| R-005   |    6 | WHEN R-004b が成功したとき: URL をパラメータとして受け取り tar.gz + checksums.txt をダウンロードする                                                                                                                             | 失敗 → `::error::` を stderr に出力して exit 2                 |
| R-006   |    7 | WHEN R-005 が成功したとき: sha256sum でハッシュを検証する（checksums.txt を `grep -w` で完全一致検索）                                                                                                                           | エントリなし・不一致 → `::error::` を stderr に出力して exit 3 |
| R-007   |    8 | WHEN R-006 が成功したとき: tar.gz を展開し `tool-name` に一致するバイナリを BIN_DIR に 755 で配置する                                                                                                                            | 一致なし・失敗 → `::error::` を stderr に出力して exit 4       |
| R-008   |    9 | WHEN action の全ステップが終了したとき（成功・失敗を問わず）: TEMP_DIR が存在する場合はこれを削除する                                                                                                                            | 冪等（既に削除済みでも exit 0）                                |

---

## 5. Edge Cases

| 入力・状態                                           | 振る舞い                                                  | REQ       | Rationale                                 |
| ---------------------------------------------------- | --------------------------------------------------------- | --------- | ----------------------------------------- |
| repo が `[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+` に不一致   | `::error::` を stderr に出力して exit 1（R-001）          | REQ-F-001 | 後続の URL 構築が不正になるため           |
| tool-version に "v" プレフィックスあり               | 正規化して除去してから処理を継続                          | REQ-F-001 | バージョン文字列の統一のため              |
| tool-version が "latest" など X.Y.Z 形式でない       | `::error::` を stderr に出力して exit 1（R-001）          | REQ-F-001 | 再現可能なビルドのため固定バージョン必須  |
| runner.arch が X64/ARM64 以外                        | `::error::` を stderr に出力して exit 1（R-002）          | REQ-F-002 | 未知 arch への対応は Out of Scope         |
| `ARCH_CANDIDATES`[0] が 404、[1] が 200              | [1] の `ARCH_SUFFIX` を採用して処理を継続                 | REQ-F-002 | DD-01・DD-02 の根拠                       |
| `ARCH_CANDIDATES` の全候補が 404                     | `::error::` を stderr に出力して exit 2（R-004）          | REQ-F-003 | ダウンロード不可のため                    |
| checksums.txt に対象ファイル名のエントリなし         | `::error::` を stderr に出力して exit 3（R-006）          | REQ-F-004 | 検証が不可能なため                        |
| BIN_DIR に同名バイナリが既に存在                     | 上書きして処理を継続                                      | REQ-F-005 | 冪等性（REQ-NF-002）のため                |
| tar.gz 内に tool-name と一致するバイナリが存在しない | `::error::` を stderr に出力して exit 4（R-007）          | REQ-F-005 | インストール対象が特定できないため        |
| TEMP_DIR が cleanup 時に既に削除済み                 | 正常終了（冪等）                                          | REQ-F-006 | cleanup は always() で実行されるため      |
| extract-install が失敗した後の cleanup               | cleanup は実行され TEMP_DIR を削除する                    | REQ-F-006 | if: always() による保証                   |
| `curl --head -L` がタイムアウトする（全候補）        | 全候補失敗とみなし `::error::` を出力して exit 2（R-004） | REQ-F-003 | curl のデフォルトタイムアウト動作に委ねる |

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule            | Notes                                                  |
| -------------- | -------------------- | ------------------------------------------------------ |
| REQ-F-001      | R-001                | 入力値検証。repo は owner/repo 形式を検証              |
| REQ-F-002      | R-002, R-004         | arch 検出は候補生成（R-002）+ 存在確認（R-004）の2段階 |
| REQ-F-003      | R-004, R-004b, R-005 | arch 解決（R-004）→ URL 構築（R-004b）→ DL（R-005）    |
| REQ-F-004      | R-006                | SHA256 検証は必須・スキップ不可                        |
| REQ-F-005      | R-003, R-007         | setup-dirs（R-003）と extract-install（R-007）         |
| REQ-F-006      | R-008                | if: always() で常に実行。冪等                          |
| REQ-NF-001     | R-006, R-007         | SHA256 検証必須・パーミッション 755                    |
| REQ-NF-002     | R-003, R-007, R-008  | 再実行時も同じ結果を保証                               |
| REQ-NF-003     | DD-05                | 関数ライブラリ式・4ファイル構成                        |
| REQ-NF-004     | DD-05                | 関数単位でのユニットテスト可能                         |
| REQ-C-001      | 全ルール             | Linux ubuntu runner のみを対象                         |
| REQ-C-002      | R-007                | tar.gz のみ展開対象                                    |
| REQ-C-003      | R-006                | チェックサム検証はスキップ不可                         |
| REQ-C-004      | R-005                | URL パターンを固定                                     |
| REQ-C-005      | DD-05                | 関数ライブラリ式・複数ファイル構成                     |

---

## 7. Open Questions

> **Status**: COMPLETE

| #     | Question                                                               | Source        | Impact                                                           |
| ----- | ---------------------------------------------------------------------- | ------------- | ---------------------------------------------------------------- |
| ~~1~~ | ~~tool-version に "latest" などの動的な値を許容するか~~                | ~~REQ-F-001~~ | ~~解決済み: X.Y.Z 形式のみ受け付ける（DR-07）~~                  |
| ~~2~~ | ~~checksums.txt のファイル名パターンがリリースごとに異なる場合の対処~~ | ~~REQ-F-004~~ | ~~解決済み: grep -w による完全一致検索（DR-07）~~                |
| ~~3~~ | ~~resolve-arch の HTTP タイムアウト・リトライ回数の上限~~              | ~~REQ-F-003~~ | ~~解決済み: curl デフォルト動作に委ねる（Edge Cases 参照）~~     |
| ~~4~~ | ~~エラー出力の統一規則が未定義~~                                       | ~~全ルール~~  | ~~解決済み: Section 3.2 エラー出力規則に統一フォーマットを定義~~ |
| ~~5~~ | ~~build-url の Decision Rules への対応が欠落~~                         | ~~REQ-F-003~~ | ~~解決済み: R-004b として独立ルールを追加~~                      |
| ~~6~~ | ~~tar.gz 内バイナリ名が tool-name と一致しない場合の振る舞いが未定義~~ | ~~REQ-F-005~~ | ~~解決済み: R-007 および Edge Cases に追記~~                     |

---

## 8. Change History

| Date       | Version | Description                                                                                            |
| ---------- | ------- | ------------------------------------------------------------------------------------------------------ |
| 2026-06-07 | 1.0.0   | Initial specification                                                                                  |
| 2026-06-07 | 1.1.0   | explore レビュー反映: エラー出力規則・build-url・バイナリ探索ロジック追加                              |
| 2026-06-07 | 1.2.0   | harden レビュー反映: WHEN 条件明示・入力検証パターン確定・スクリプト間 I/F 統一・DR-06/07 追加         |
| 2026-06-07 | 1.3.0   | fix レビュー反映: 用語統一・ASCII 図に build-url 追加・DD Affected Rules 修正・Open Questions COMPLETE |
