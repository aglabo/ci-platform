---
id: TASKS
module: composite-action/get-changed-files
status: approved
refs: [IMPL]
---

# Tasks: ca-get-changed-files

## Implementation Tasks

### T-01: filter.lib.sh の実装（BDD）

**対象ファイル:**

- `scripts/_libs/filter.lib.sh`
- `scripts/__tests__/unit/filter.unit.spec.sh`

**テストケース:**

#### resolve_before_sha()

- `[nrm-01]` 正常 SHA → そのまま返す
- `[nrm-02]` ゼロ SHA（40桁）→ empty-tree SHA を返す
- `[edg-01]` 空文字 → empty-tree SHA を返す
- `[edg-02]` 短いゼロ列 → そのまま返す（40桁のみフォールバック対象）

#### write_multiline_output()

- `[nrm-01]` 単行値 → `key<<EOF\nvalue\nEOF\n` 形式で出力
- `[nrm-02]` 複数行値 → 全行を含む形式で出力
- `[edg-01]` 空値 → `key<<EOF\n\nEOF\n` 形式で出力

### T-02: get-changed-files.sh の実装（BDD）

**対象ファイル:**

- `scripts/get-changed-files.sh`
- `scripts/__tests__/functional/get-changed-files.functional.spec.sh`

**テストケース:**

- `[nrm-01]` 正常な BEFORE/AFTER SHA → 変更ファイル一覧を出力
- `[nrm-02]` pattern 指定あり → フィルターされたファイルのみ出力
- `[nrm-03]` pattern 空（デフォルト）→ 全ファイルを出力
- `[edg-01]` ゼロ SHA → empty-tree と diff して正常動作
- `[err-01]` BEFORE_SHA 未設定 → エラー終了

### T-03: action.yml の作成

**対象ファイル:**

- `action.yml`

**内容:** SPEC 記載の action.yml 構造に従って作成（BDD サイクル対象外、ドキュメント作成）

## Execution Order

1. T-01: filter.lib.sh（bdd-coder で実装）
2. T-02: get-changed-files.sh（bdd-coder で実装）
3. T-03: action.yml（直接作成）

## BDD Coder Handoff

T-01, T-02 は bdd-coder エージェントに委譲する。
引き継ぎ情報:

- 作業種別: 新機能追加
- テストフレームワーク: ShellSpec
- テストコマンド: `bash ./scripts/run-specs.sh <spec-path> --format tap --no-color`
- プロジェクトルート: `/c/Users/atsushifx/workspaces/develop/ci-platform`
