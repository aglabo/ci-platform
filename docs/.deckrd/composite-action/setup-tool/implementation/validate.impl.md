---
id: IMPL-validate
title: "Implementation Plan: Input Validation"
based-on: validate.spec.md v1.4.1
status: Draft
---

<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/max-comma -->
<!-- markdownlint-disable line-length -->
<!-- cspell:words rhysd -->

## SPEC SUMMARY

**対象スペック**: `validate.spec.md` (入力値検証)
**カバー要件**: REQ-F-010 (tool-version/asset-template/tool-name 検証), REQ-F-011 (repo 形式検証)

### 機能概要

`setup-tool` composite action 起動時に全入力値を検証するゲートスクリプト。
検証失敗時は後続処理をブロックし、エラー原因を GitHub Actions アノテーション形式で出力する。

### 検証ルール (決定順序固定・fail-fast)

| Rule    | Step | 条件                                                                     | 結果                                           |
| ------- | ---: | ------------------------------------------------------------------------ | ---------------------------------------------- |
| R-000   |    0 | 全入力の前後空白を除去                                                   | 前処理済み値を以降の検証に使用                 |
| R-000U  |  0.5 | いずれかの入力に ASCII 以外の Unicode 文字 (`\x80` 以上) が含まれる      | exit 1 + `::error::` メッセージ                |
| R-001   |    1 | `tool-version` が 32 文字超、または `normalize_version()` が return 1    | exit 1 + エラーメッセージ                      |
| R-001-N |  1.5 | `normalize_version()` 成功時                                             | 正規化後 X.Y.Z 値を `GITHUB_OUTPUT` へ書き出し |
| R-002   |    2 | `asset-template` がパターン不適合                                        | exit 1 + エラーメッセージ                      |
| R-002C  |  2.5 | `checksum-template` が指定済みかつパターン不適合 / `<filename>` 2 回以上 | exit 1 + エラーメッセージ                      |
| R-003   |    3 | `tool-name` がパターン不適合                                             | exit 1 + エラーメッセージ                      |
| R-004   |    4 | `repo` が形式不適合                                                      | exit 1 + エラーメッセージ                      |
| R-005   |    5 | 全条件を通過                                                             | exit 0                                         |

### 検証パターン

- `tool-name`: `^[a-z][a-z0-9_-]{0,63}$`
- `tool-version`: `normalize_version()` に委譲 (common.lib.sh)
- `asset-template`: `^[A-Za-z0-9._{}/-]{1,256}$`
- `checksum-template`: `^(<filename>)?[A-Za-z0-9._-]{0,255}$`
- `repo`: org 部 `^[a-z][a-z0-9_-]{0,38}$` + `/` + repo 部 `^[a-z][a-z0-9_-]{0,63}$`

---

## CODEBASE CONTEXT

### 既存ファイル (変更不要)

| ファイル                      | 内容                                                                                            |
| ----------------------------- | ----------------------------------------------------------------------------------------------- |
| `scripts/_libs/common.lib.sh` | `normalize_version()` 実装済み。v/V プレフィックス除去・X.Y/X 形式補完・major/minor 1〜3 桁制限 |
| `scripts/download-tool.sh`    | ファイルヘッダー・`set -euo pipefail`・`readonly` 変数宣言のパターン参照                        |
| `scripts/cleanup.sh`          | 同上                                                                                            |

### 参照実装 (パターン参照)

| ファイル                                                                                                     | 参照するパターン                                                     |
| ------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------- |
| `.github/actions/validate-environment/scripts/validate-apps.sh`                                              | `::error::` プレフィックス・fail-fast セマンティクス・guard パターン |
| `.github/actions/validate-environment/scripts/__tests__/validate-apps/unit/validate-app-format.unit.spec.sh` | ShellSpec の `Describe`/`Context`/`It`/`Include` スタイル            |

### `normalize_version()` シグネチャ

```bash
# @arg $1 string Raw version string (v1.2.3 / 1.2 / 1 形式)
# @stdout Normalized version X.Y.Z
# @return 0 on success, 1 on invalid format (stderr にエラー出力)
normalize_version() { ... }  # _libs/common.lib.sh
```

---

## DESIGN DECISIONS

### ASCII 制限ポリシー (仕様決定済み)

R-000U の ASCII 以外 Unicode 拒否は**仕様要求**として確定している (validate.spec.md Section 2.4)。
実装都合ではなく意図的な設計であり、以下の理由により国際化対応は行わない:

- Unicode 同形異字攻撃の排除
- シェル実行の安全性 (マルチバイト文字のエンコーディング一貫性)
- 決定論的な動作保証 (全 CI 環境で同一結果)

この制限の緩和は破壊的変更 (仕様メジャーバージョン更新必須)。

---

## PRIOR ART

- `validate-apps.sh` の fail-fast パターンが直接参照可能
- guard 変数 `_VALIDATION_LIB_LOADED` の命名規則を既存 `_INIT_VARS_LIB_SH` に揃える
- `::error::` プレフィックスは GitHub Actions のアノテーション仕様準拠

---

## CONFIRMED IMPLEMENTATION

### 実装単位

| Unit | ファイル (setup-tool/scripts/ 以下)      | 責務                                      |
| ---- | ---------------------------------------- | ----------------------------------------- |
| A    | `_libs/validation.lib.sh`                | 汎用入力検証ヘルパー関数群                |
| B    | `validate-inputs.sh`                     | R-000〜R-005 全ルールのオーケストレーター |
| C    | `__tests__/validate-inputs.unit.spec.sh` | ShellSpec 単体テスト                      |

### Unit A: `_libs/validation.lib.sh`

**提供する関数**:

```bash
# double-source guard
[[ -n "${_VALIDATION_LIB_LOADED:-}" ]] && return 0
_VALIDATION_LIB_LOADED=1

# @arg $1 string Value to validate
# @arg $2 string Field name (for error message)
# @arg $3 string Whitelist regex pattern
# @return 0 on match, 1 on mismatch (stderr: ::error::)
validate_symbol() { ... }

# @arg $1 string asset-template value
# @return 0 on match, 1 on mismatch
validate_asset_template() { ... }  # ^[A-Za-z0-9._{}/-]{1,256}$

# @arg $1 string checksum-template value (may be empty = skip)
# @return 0 on valid or empty, 1 on invalid
validate_checksum_template() { ... }  # ^(<filename>)?[A-Za-z0-9._-]{0,255}$
                                       # <filename> 2回以上 → fail
```

### Unit B: `validate-inputs.sh`

**入力**: 環境変数 (GitHub Actions composite action の `${{ inputs.* }}` から受け取る)

```bash
INPUT_TOOL_NAME         # 必須
INPUT_TOOL_VERSION      # 必須
INPUT_ASSET_TEMPLATE    # 必須
INPUT_CHECKSUM_TEMPLATE # 省略可 (空文字 = 省略)
INPUT_REPO              # 必須 (org/repo 形式)
```

> **注記**: `action.yml` が未作成のため変数名は仮決め。`action.yml` 作成時に整合性確認が必要。

**処理フロー**:

```bash
LC_ALL=C  # Unicode チェックの決定論的動作保証

# R-000: 前後空白除去 (bash パラメータ展開)
trim() { local v="$1"; v="${v#"${v%%[![:space:]]*}"}"; echo "${v%"${v##*[![:space:]]}"}"; }

# R-000U: ASCII 以外 Unicode を拒否
# [[ "$val" =~ [^\x00-\x7F] ]] → exit 1

# R-001: tool-version 検証 (normalize_version の stderr はそのまま伝播)
# if ! normalized=$(normalize_version "$tool_version"); then exit 1; fi

# R-001-N: GITHUB_OUTPUT へ書き出し (GITHUB_OUTPUT 未設定時はエラー終了)
# [[ -z "${GITHUB_OUTPUT:-}" ]] && { echo "::error::GITHUB_OUTPUT is not set" >&2; exit 1; }
# echo "tool-version=${normalized}" >> "$GITHUB_OUTPUT"

# R-002: asset-template 検証
# validate_asset_template "$asset_template" || exit 1

# R-002C: checksum-template 検証 (省略時スキップ)
# [[ -n "$checksum_template" ]] && { validate_checksum_template "$checksum_template" || exit 1; }

# R-003: tool-name 検証
# validate_symbol "$tool_name" "tool-name" '^[a-z][a-z0-9_-]{0,63}$' || exit 1

# R-004: repo 検証 (org/repo 分割後それぞれ validate_symbol)
# validate_symbol "$org" "repo(org)" '^[a-z][a-z0-9_-]{0,38}$' || exit 1
# validate_symbol "$repo_name" "repo(repo)" '^[a-z][a-z0-9_-]{0,63}$' || exit 1

# R-005: 全通過 → exit 0
```

**エラーメッセージ形式**:

```bash
::error::tool-name: invalid value '<value>'. Expected: ^[a-z][a-z0-9_-]{0,63}$
```

### Unit C: `tests/validate-inputs.unit.spec.sh`

**構造**:

```bash
Describe 'validate_inputs'
  Include "$SCRIPT_PATH"  # validate-inputs.sh
  export GITHUB_OUTPUT="/dev/null"

  Describe 'R-000: trim whitespace'
    It 'accepts tool-name with leading/trailing spaces'
    It 'accepts tool-version with spaces'
    It 'rejects tool-name that is spaces-only (trim → empty → R-003 fail)'
    It 'rejects repo that is spaces-only (trim → empty → R-004 fail)'
  End

  Describe 'R-000U: ASCII subset enforcement'
    It 'rejects Unicode in tool-name (例: ツール)'
    It 'rejects Unicode in tool-version'
    It 'rejects Unicode in asset-template'
    It 'rejects Unicode in repo'
    It 'rejects Unicode in checksum-template'
  End

  Describe 'R-001: tool-version validation'
    It 'accepts 1.7.10 → normalizes to 1.7.10'
    It 'accepts v1.7.10 → normalizes to 1.7.10'
    It 'accepts 1.7 → normalizes to 1.7.0'
    It 'accepts 1 → normalizes to 1.0.0'
    It 'rejects latest'
    It 'rejects 1.2.3-beta'
    It 'rejects 1.2.3.4'
    It 'rejects 1000.0.0 (major 4桁以上)'
    It 'rejects 1.1000.0 (minor 4桁以上)'
    It 'rejects version > 32 chars'
  End

  Describe 'R-002: asset-template validation'
    It 'accepts valid template with placeholders'
    It 'rejects empty string'
    It 'rejects $() injection'
    It 'rejects > 256 chars'
  End

  Describe 'R-002C: checksum-template validation'
    It 'accepts <filename>.sha256'
    It 'accepts checksums.txt (no <filename>)'
    It 'passes when empty (skip)'
    It 'rejects <filename><filename>.txt'
    It 'rejects Unicode'
    It 'rejects <<filename> (partial angle bracket prefix)'
    It 'rejects <FILENAME> (uppercase — not a recognized meta variable)'
  End

  Describe 'R-003: tool-name validation'
    It 'accepts actionlint'
    It 'rejects empty string'
    It 'rejects spaces-only'
    It 'rejects MyTool (uppercase)'
    It 'rejects 65-char name'
  End

  Describe 'R-004: repo validation'
    It 'accepts rhysd/actionlint'
    It 'rejects ActionLint (no slash)'
    It 'rejects org/repo/extra (2 slashes)'
    It 'rejects /repo (leading slash)'
    It 'rejects org/ (trailing slash)'
    It 'rejects org//repo (double slash)'
    It 'rejects org > 39 chars'
    It 'rejects repo > 64 chars'
  End

  Describe 'R-005: all pass → exit 0'
    It 'exits 0 with all valid inputs'
    It 'writes normalized tool-version to GITHUB_OUTPUT'
  End
End
```

---

## PHASE PLAN

| Phase   | タイトル                | 内容                                                 |
| ------- | ----------------------- | ---------------------------------------------------- |
| Phase 1 | validation.lib.sh 実装  | ヘルパー関数群 (下位レイヤ) — 単体で完結・テスト可能 |
| Phase 2 | validate-inputs.sh 実装 | オーケストレーター (中位レイヤ) — Phase 1 に依存     |
| Phase 3 | 単体テスト実装          | ShellSpec (上位検証) — Phase 1・2 に依存             |

---

## COMMIT PLAN

### Phase 1: validation.lib.sh

**Commit 1**: `feat(setup-tool/validate): add validation.lib.sh with input validators`

- `scripts/_libs/validation.lib.sh` を新規作成
- `validate_symbol()` — ホワイトリスト正規表現による汎用フィールド検証
- `validate_asset_template()` — asset-template 専用パターン検証
- `validate_checksum_template()` — `<filename>` 出現カウント含む checksum-template 検証
- double-source guard (`_VALIDATION_LIB_LOADED`) 付き

```bash
Implements: IMPL-validate (Phase 1)
Spec: validate.spec.md (R-002, R-002C, R-003, R-004)
Req: REQ-F-010, REQ-F-011
```

### Phase 2: validate-inputs.sh

**Commit 2**: `feat(setup-tool/validate): add validate-inputs.sh orchestrating R-000 to R-005`

- `scripts/validate-inputs.sh` を新規作成
- R-000 → R-000U → R-001/R-001-N → R-002 → R-002C → R-003 → R-004 → R-005 の固定順序で実装
- `GITHUB_OUTPUT` へ正規化バージョン書き出し (R-001-N)
- `LC_ALL=C` による決定論的 Unicode チェック

```bash
Implements: IMPL-validate (Phase 2)
Spec: validate.spec.md (R-000 〜 R-005 全ルール)
Req: REQ-F-010, REQ-F-011
```

### Phase 3: 単体テスト

**Commit 3**: `test(setup-tool/validate): add unit spec covering R-000 to R-005`

- `scripts/__tests__/validate-inputs.unit.spec.sh` を新規作成
- `validate.spec.md` Section 5 のエッジケースを全網羅
- 境界値: tool-name 64/65 文字、org 39/40 文字、tool-version 32 文字上限等

```bash
Test: TEST-validate
Spec: validate.spec.md
Req: REQ-F-010, REQ-F-011
```

---

## Open Questions / Notes

1. **`action.yml` 未作成**: 環境変数名 `INPUT_*` は仮決め。`action.yml` 実装時に整合性を確認すること
2. **checksum-template デフォルト**: 省略時のデフォルト値設定 (`checksums.txt`) は `build-url.spec.md` 側の責務 (本スペック外)
3. **`_libs/__tests__/` のライブラリ単体テスト**: `validation.lib.sh` 専用の分離テストは不要。`validate-inputs.unit.spec.sh` が `Include` 経由で間接テストを兼ねる

---

## Change History

| Date       | Version | Description   |
| ---------- | ------- | ------------- |
| 2026-03-24 | 1.0.0   | Initial draft |
| 2026-03-25 | 1.1.0   | Codex review 反映: normalize_version stderr 伝播・GITHUB_OUTPUT 未設定時エラー化・ASCII 制限をポリシーとして明記・エッジケース追加 (trim後空文字/repo スラッシュ異常/checksum-template 大文字小文字) |
