---
title: "Design Specification: Action Orchestration"
based-on: requirements.md v1.0.5
status: Draft
---

<!-- textlint-disable ja-technical-writing/sentence-length, ja-technical-writing/max-comma -->
<!-- markdownlint-disable line-length -->

> Part of split specification. See `specifications-index.md` for full scope.

## 1. Overview

### 1.1 Purpose

`action.yml` が全ステップを制御し、入力受け取りから出力提供・クリーンアップまでの全体フローを定義する振る舞いルールを定義する。

### 1.2 Scope

本仕様は `setup-tool` Composite Action の **ステップ実行順序** と **オーケストレーションセマンティクス** を定義する。各ステップ内部の処理は個別 spec ファイルを参照。実装詳細はスコープ外とする。

---

## 2. Design Principles

### 2.1 Classification Philosophy

各処理フェーズはスクリプト単位で 1 責任に分離する。ステップ間のデータ受け渡しは `GITHUB_ENV` を経由し、後続ステップはそこから環境変数を読み取る。クリーンアップは `if: always()` で常に実行し、成功・失敗を問わず一時ファイルを削除する。

### 2.2 Design Assumptions

- スクリプト呼び出しは `bash "${GITHUB_ACTION_PATH}/scripts/<name>.sh"` 形式に統一する（REQ-NF-004）
- パラメータ渡しは `env:` ブロック経由で行い、スクリプト内では環境変数として受け取る（REQ-NF-004）
- `shell: bash` を全ステップで明示する（REQ-NF-004）
- `permissions: contents: read` のみ設定する（REQ-C-004）
- 参照実装は `.github/actions/validate-environment/action.yml` に準拠する（REQ-NF-004）

### 2.3 External Design Summary

> **Source**: Derived from the external design dialogue (Phase E) and user-confirmed design direction (Phase D).

#### Feature Decomposition

| Unit              | Responsibility                                                | REQ Coverage         |
| ----------------- | ------------------------------------------------------------- | -------------------- |
| inputs 定義       | action の入力パラメータ（必須・省略可能・デフォルト値）を宣言 | REQ-F-001〜REQ-F-012 |
| outputs 定義      | `install-path`, `tool-version` を宣言                         | REQ-F-007            |
| validate-inputs   | 入力値バリデーションを実行                                    | REQ-F-010, REQ-F-011 |
| resolve-env       | runner.os/arch から {os}/{arch_suffix} を解決                 | REQ-F-001            |
| setup-directories | TEMP_DIR / BIN_DIR を作成し GITHUB_ENV に書き込む             | REQ-F-006, REQ-F-008 |
| build-urls        | asset URL / checksum URL を生成し GITHUB_ENV に書き込む       | REQ-F-002, REQ-F-003 |
| download-tool     | tar.gz と checksums ファイルをダウンロード                    | REQ-F-005            |
| verify-identity   | SHA256 照合を実行                                             | REQ-F-004, REQ-F-012 |
| extract-install   | tar.gz 展開・バイナリ配置・PATH 追加                          | REQ-F-006, REQ-F-009 |
| set-outputs       | GITHUB_OUTPUT に install-path / tool-version を書き込む       | REQ-F-007            |
| cleanup           | TEMP_DIR を削除（if: always()）                               | REQ-F-008            |

#### Unit Interaction Map

```text
[action inputs]
       |
       v
[validate-inputs] --失敗--> exit 1
       |
       v
[resolve-env] --失敗--> exit 1
       |   (GITHUB_ENV: OS_NAME, ARCH_SUFFIX)
       v
[setup-directories]
       |   (GITHUB_ENV: BIN_DIR, TEMP_DIR)
       v
[build-urls]
       |   (GITHUB_ENV: DOWNLOAD_URL, CHECKSUM_URL, ASSET_FILENAME, CHECKSUM_FILENAME)
       v
[download-tool] --失敗(exit 2)--> [cleanup(always)]
       |
       v
[verify-identity] --失敗(exit 3)--> [cleanup(always)]
       |
       v
[extract-install] --失敗(exit 4)--> [cleanup(always)]
       |
       v
[set-outputs]
       |   (GITHUB_OUTPUT: install-path, tool-version)
       v
[cleanup(always)]
```

#### Data Flow Diagram

```text
[action inputs]
       |
       v
 env: ブロック経由
       |
       v
[各スクリプト] --> GITHUB_ENV --> [後続スクリプト]
                --> GITHUB_PATH --> [後続ステップの PATH]
                --> GITHUB_OUTPUT --> [呼び出し元 workflow]
```

### 2.4 Non-Goals

> **Derivation**: All items below originate from REQUIREMENTS Section "Out of Scope".

- パッケージマネージャ経由インストール ← REQ: Out of Scope
- macOS / Windows ランナーでの動作 ← REQ: Out of Scope
- インストール先ディレクトリのカスタマイズ ← REQ: Out of Scope
- tar.gz 以外のアーカイブ形式 ← REQ: Out of Scope (REQ-C-002)

### 2.5 Behavioral Design Decisions

| ID    | Decision                                                      | Rationale                                                          | Affected Rules | Status |
| ----- | ------------------------------------------------------------- | ------------------------------------------------------------------ | -------------- | ------ |
| DD-01 | パラメータ渡しを `env:` ブロック経由に統一する                | validate-environment パターンへの準拠と、スクリプトの再利用性向上  | R-001          | Active |
| DD-02 | クリーンアップを `if: always()` で実行する                    | 失敗時も一時ファイルを確実に削除しランナーのディスクを解放する     | R-009          | Active |
| DD-03 | set-outputs を extract-install から分離した独立ステップとする | 出力の責務を明確に分離し、extract-install の単体テストを簡潔に保つ | R-008          | Active |

### 2.6 Related Decision Records

| DR-ID | Title                                                       | Phase | Impact on This Spec                                         |
| ----- | ----------------------------------------------------------- | ----- | ----------------------------------------------------------- |
| DR-08 | スクリプト分離とコーディングスタイルの MUST 化              | req   | bash "`${GITHUB_ACTION_PATH}/scripts/<name>.sh`" 形式の根拠 |
| DR-10 | 5 ライブラリ構成の確定と resolve_os/arch の common への配置 | req   | resolve-env ステップが common.lib.sh を使用する根拠         |
| DR-04 | インストール先を `${RUNNER_TEMP}/bin` に固定                | req   | setup-directories / extract-install の設計制約              |

### 2.7 DD to DR Promotion Criteria

> **Purpose**: Guidelines for determining when a DD should be promoted to a formal DR.
> Promotion is a **human judgment** — these criteria inform, not automate.

DD-01 は validate-environment との共通パターンとして DR 昇格の候補。

---

## 3. Behavioral Specification

### 3.1 Input Domain

**必須入力**:

| パラメータ       | 型     | 説明                                            |
| ---------------- | ------ | ----------------------------------------------- |
| `tool-name`      | string | インストールするツールの識別子                  |
| `tool-version`   | string | バージョン（v プレフィックス任意、X/X.Y/X.Y.Z） |
| `repo`           | string | `org/repo` 形式の GitHub リポジトリ識別子       |
| `asset-template` | string | アセットファイル名のテンプレート                |

**省略可能入力**:

| パラメータ          | デフォルト値      | 説明                               |
| ------------------- | ----------------- | ---------------------------------- |
| `checksum-template` | `"checksums.txt"` | チェックサムファイル名テンプレート |

### 3.2 Output Semantics

| 出力名         | 値                                                              |
| -------------- | --------------------------------------------------------------- |
| `install-path` | `${RUNNER_TEMP}/bin`（固定）                                    |
| `tool-version` | normalize_version() 適用後の X.Y.Z 形式（v プレフィックスなし） |

---

## 4. Decision Rules

Evaluation MUST follow this order:

| Rule ID | Step | Condition / Action                                    | Outcome                                               |
| ------- | ---: | ----------------------------------------------------- | ----------------------------------------------------- |
| R-001   |    1 | validate-inputs ステップを実行する                    | 失敗: exit 1                                          |
| R-002   |    2 | resolve-env ステップを実行する（runner.os/arch 解決） | 失敗: exit 1（OS/arch 未対応）                        |
| R-003   |    3 | setup-directories ステップを実行する                  | TEMP_DIR / BIN_DIR を GITHUB_ENV に設定               |
| R-004   |    4 | build-urls ステップを実行する                         | URL / ファイル名を GITHUB_ENV に設定                  |
| R-005   |    5 | download-tool ステップを実行する                      | 失敗: exit 2                                          |
| R-006   |    6 | verify-identity ステップを実行する（SHA256 照合）     | 失敗: exit 3                                          |
| R-007   |    7 | extract-install ステップを実行する                    | 失敗: exit 4                                          |
| R-008   |    8 | set-outputs ステップを実行する                        | GITHUB_OUTPUT に install-path/tool-version を書き込む |
| R-009   |    9 | cleanup ステップを `if: always()` で実行する          | 成功・失敗問わず TEMP_DIR を削除                      |

No reordering is permitted.

<!-- impl-note: action.yml の各ステップは `bash "${GITHUB_ACTION_PATH}/scripts/<name>.sh"` 形式で呼び出す -->
<!-- impl-note: env: ブロックで TOOL_NAME, TOOL_VERSION, REPO, ASSET_TEMPLATE, CHECKSUM_TEMPLATE, BIN_DIR, TEMP_DIR, DOWNLOAD_URL, CHECKSUM_URL, ASSET_FILENAME, CHECKSUM_FILENAME を各ステップに渡す -->
<!-- impl-note: permissions: contents: read のみ設定（REQ-C-004） -->

---

## 5. Edge Cases

| Input / 状況                                 | Classification    | REQ       | Rationale                                      |
| -------------------------------------------- | ----------------- | --------- | ---------------------------------------------- |
| runner.os が Linux 以外（例: macOS）         | R-002 失敗        | REQ-F-001 | Linux 限定の明示エラー化（AC-025）             |
| runner.arch が X64/ARM64 以外（例: X86）     | R-002 失敗        | REQ-F-001 | 未対応アーキテクチャの明示エラー化             |
| download-tool 失敗（404/ネットワークエラー） | R-005 失敗 exit 2 | REQ-F-005 | cleanup は if: always() で実行されることを保証 |
| verify-identity 失敗（改ざん検出）           | R-006 失敗 exit 3 | REQ-F-004 | 後続の extract-install は実行されない          |
| 同一ジョブで action を 2 回呼び出す          | 全ステップ正常    | REQ-F-006 | setup-directories/extract-install は冪等       |

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule | Notes                                           |
| -------------- | --------- | ----------------------------------------------- |
| REQ-F-001      | R-002     | runner.os/arch 自動解決・未対応時 exit 1        |
| REQ-F-005      | R-005     | ダウンロード失敗時 exit 2                       |
| REQ-F-007      | R-008     | outputs（install-path / tool-version）提供      |
| REQ-F-008      | R-009     | if: always() クリーンアップ                     |
| REQ-F-009      | R-007     | インストール先固定（extract-install 経由）      |
| REQ-F-002      | R-004     | Detailed in: `build-url.spec.md`                |
| REQ-F-003      | R-004     | Detailed in: `build-url.spec.md`                |
| REQ-F-004      | R-006     | Detailed in: `verify-identity.spec.md`          |
| REQ-F-006      | R-007     | Detailed in: `extract-install.spec.md`          |
| REQ-F-010      | R-001     | Detailed in: `validate.spec.md`                 |
| REQ-F-011      | R-001     | Detailed in: `validate.spec.md`                 |
| REQ-F-012      | R-006     | verify-identity ステップとして REQ-F-004 を包含 |

---

## 7. Open Questions

> **Status**: COMPLETE

None identified — all requirements are unambiguous.

---

## 8. Change History

| Date       | Version | Description           |
| ---------- | ------- | --------------------- |
| 2026-03-23 | 1.0.0   | Initial specification |
